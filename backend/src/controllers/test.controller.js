const crypto = require('crypto');
const { pool, query } = require('../config/database');
const { sendTestInvitationEmail } = require('../services/email.service');

const QUESTION_TYPES = new Set([
    'short_answer',
    'multiple_choice',
    'paragraph',
    'code'
]);

const normalizeText = (value) => `${value || ''}`.trim();

const normalizeQuestionType = (value) => {
    const normalized = normalizeText(value).toLowerCase().replace(/[\s-]+/g, '_');
    if (normalized === 'short') return 'short_answer';
    if (normalized === 'mcq' || normalized === 'multiple') return 'multiple_choice';
    if (QUESTION_TYPES.has(normalized)) return normalized;
    return '';
};

const asNumber = (value, fallback = 0) => {
    const parsed = Number(value);
    return Number.isFinite(parsed) ? parsed : fallback;
};

const normalizeDeadlineInput = (value) => {
    const deadline = normalizeText(value);
    if (/^\d{4}-\d{2}-\d{2}$/.test(deadline)) {
        return `${deadline}T23:59:59.999+03:00`;
    }
    return deadline;
};

const isOrganizationRequest = (req) => req.user?.role === 'company';

const ensureOrganizationJobAccess = async (req, jobId, client = pool) => {
    if (!isOrganizationRequest(req)) {
        return { companyId: null, jobId: normalizeText(jobId) || null };
    }

    const normalizedJobId = normalizeText(jobId);
    if (!normalizedJobId) {
        const error = new Error('Training post is required for organization tests.');
        error.statusCode = 400;
        throw error;
    }

    const result = await client.query(
        `SELECT job_id, company_id
         FROM training
         WHERE job_id = $1 AND company_id = $2
         LIMIT 1`,
        [normalizedJobId, req.user.user_id]
    );

    if (result.rows.length === 0) {
        const error = new Error('You are not allowed to manage tests for this training post.');
        error.statusCode = 403;
        throw error;
    }

    return { companyId: req.user.user_id, jobId: normalizedJobId };
};

const ensureOrganizationTestAccess = async (req, testId, client = pool) => {
    const result = await client.query(
        `SELECT id, title, duration, deadline, company_id, job_id
         FROM tests
         WHERE id = $1
         LIMIT 1`,
        [testId]
    );
    const test = result.rows[0];
    if (!test) return null;

    if (isOrganizationRequest(req) && `${test.company_id}` !== `${req.user.user_id}`) {
        const error = new Error('You are not allowed to manage this test.');
        error.statusCode = 403;
        throw error;
    }

    return test;
};

const buildFrontendBaseUrl = (req) => {
    const configured = normalizeText(
        process.env.TEST_FRONTEND_BASE_URL ||
            process.env.PUBLIC_APP_URL ||
            process.env.FRONTEND_BASE_URL
    ).replace(/\/+$/, '');

    if (configured) return configured;

    const origin = normalizeText(req.headers.origin).replace(/\/+$/, '');
    if (origin) return origin;

    return 'http://localhost:3000';
};

const createInvitationToken = () => crypto.randomBytes(24).toString('hex');

const parseAnswersPayload = (payload) => {
    const rawAnswers = payload?.answers || {};

    if (Array.isArray(rawAnswers)) {
        return rawAnswers.reduce((acc, item) => {
            const questionId = normalizeText(item?.question_id || item?.questionId);
            if (questionId) acc[questionId] = normalizeText(item?.answer_text ?? item?.answer);
            return acc;
        }, {});
    }

    if (rawAnswers && typeof rawAnswers === 'object') {
        return Object.entries(rawAnswers).reduce((acc, [questionId, answer]) => {
            acc[questionId] = normalizeText(answer);
            return acc;
        }, {});
    }

    return {};
};

const similarityScore = (answer, expected) => {
    const normalizedAnswer = normalizeText(answer).toLowerCase();
    const normalizedExpected = normalizeText(expected).toLowerCase();

    if (!normalizedAnswer || !normalizedExpected) return 0;
    if (normalizedAnswer === normalizedExpected) return 1;
    if (
        normalizedAnswer.includes(normalizedExpected) ||
        normalizedExpected.includes(normalizedAnswer)
    ) {
        return 0.85;
    }

    const answerWords = new Set(normalizedAnswer.split(/\W+/).filter(Boolean));
    const expectedWords = new Set(normalizedExpected.split(/\W+/).filter(Boolean));
    if (answerWords.size === 0 || expectedWords.size === 0) return 0;

    let overlap = 0;
    for (const word of answerWords) {
        if (expectedWords.has(word)) overlap += 1;
    }

    return overlap / Math.max(answerWords.size, expectedWords.size);
};

const gradeAnswer = (question, answerText) => {
    const marks = asNumber(question.marks);
    const answer = normalizeText(answerText);
    const expected = normalizeText(question.correct_answer);

    if (question.question_type === 'multiple_choice') {
        return answer.toLowerCase() === expected.toLowerCase() ? marks : 0;
    }

    if (question.question_type === 'short_answer') {
        const similarity = similarityScore(answer, expected);
        if (similarity >= 0.8) return marks;
        if (similarity >= 0.55) return Number((marks * 0.5).toFixed(2));
        return 0;
    }

    return null;
};

const getTestQuestions = async (testId, client = pool) => {
    const result = await client.query(
        `SELECT id, test_id, question_text, question_type, marks, correct_answer,
                COALESCE(question_options, ARRAY[]::text[]) AS question_options
         FROM questions
         WHERE test_id = $1
         ORDER BY created_at ASC, id ASC`,
        [testId]
    );

    return result.rows;
};

const mapQuestionForStudent = (question) => ({
    id: question.id,
    test_id: question.test_id,
    question_text: question.question_text,
    question_type: question.question_type,
    marks: Number(question.marks),
    question_options: question.question_options || []
});

const formatScoreValue = (value) => {
    const number = Number(value);
    if (!Number.isFinite(number)) return '0';
    return Number.isInteger(number) ? `${number}` : number.toFixed(2).replace(/\.?0+$/, '');
};

const getAttemptScoreSummary = async (attemptId, client = pool) => {
    const result = await client.query(
        `SELECT ta.id AS attempt_id,
                ta.student_id,
                ta.test_id,
                ta.status AS attempt_status,
                ta.total_score,
                ta.submitted_at,
                t.title,
                t.pass_mark,
                t.job_id,
                t.company_id,
                COALESCE(SUM(q.marks), 0) AS total_marks,
                CASE
                    WHEN COALESCE(SUM(q.marks), 0) = 0 THEN 0
                    ELSE ROUND((COALESCE(ta.total_score, 0) / SUM(q.marks)) * 100, 2)
                END AS score_percent,
                COUNT(a.id) FILTER (
                    WHERE q.question_type IN ('paragraph', 'code')
                      AND a.score_awarded IS NULL
                )::int AS ungraded_count
         FROM test_attempts ta
         JOIN tests t ON t.id = ta.test_id
         LEFT JOIN questions q ON q.test_id = ta.test_id
         LEFT JOIN answers a
                ON a.attempt_id = ta.id
               AND a.question_id = q.id
         WHERE ta.id = $1
         GROUP BY ta.id, t.id`,
        [attemptId]
    );

    return result.rows[0] || null;
};

const createNotification = async (client, notificationData) => {
    const { user_id, title, message, type } = notificationData;
    await client.query(
        `INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
         VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP)`,
        [user_id, title, message, type]
    );
};

const syncAttemptSelectionAndNotify = async ({
    client,
    attemptId,
    notifyStudent = false,
    notifyPending = true
}) => {
    const summary = await getAttemptScoreSummary(attemptId, client);
    if (!summary || summary.attempt_status !== 'completed') {
        return summary;
    }

    const scorePercent = asNumber(summary.score_percent);
    const passMark = asNumber(summary.pass_mark);
    const totalScore = asNumber(summary.total_score);
    const totalMarks = asNumber(summary.total_marks);
    const hasUngradedAnswers = asNumber(summary.ungraded_count) > 0;
    const passed = !hasUngradedAnswers && scorePercent >= passMark;
    const applicationStatus = passed ? 'shortlisted' : 'rejected';

    if (!hasUngradedAnswers) {
        await client.query(
            `UPDATE students
             SET status = $1
             WHERE student_id = $2`,
            [applicationStatus, summary.student_id]
        );

        if (summary.job_id) {
            await client.query(
                `UPDATE applications
                 SET status = $1,
                     updated_date = CURRENT_TIMESTAMP
                 WHERE job_id = $2
                   AND student_id = $3
                   AND status <> 'accepted'`,
                [applicationStatus, summary.job_id, summary.student_id]
            );
        }
    }

    if (notifyStudent && (!hasUngradedAnswers || notifyPending)) {
        const resultLabel = hasUngradedAnswers
            ? 'Some answers are waiting for manual grading.'
            : passed
              ? 'You reached the pass mark and have been  for the next step.'
              : 'You did not reach the pass mark for this test.';

        await createNotification(client, {
            user_id: summary.student_id,
            title: 'Online test score',
            message:
                `Your answers for "${summary.title}" were submitted successfully. ` +
                `You scored ${formatScoreValue(totalScore)}/${formatScoreValue(totalMarks)} ` +
                `(${formatScoreValue(scorePercent)}%). ${resultLabel}`,
            type: 'test_score'
        });
    }

    return {
        ...summary,
        selection_status: hasUngradedAnswers
            ? 'pending'
            : passed
              ? 'selected'
              : 'not_selected'
    };
};

const createTest = async (req, res) => {
    let client;
    try {
        const title = normalizeText(req.body?.title);
        const duration = Math.round(asNumber(req.body?.duration));
        const passMark = asNumber(req.body?.pass_mark);
        const deadline = normalizeDeadlineInput(req.body?.deadline);
        const requestedJobId = normalizeText(req.body?.job_id);
        const questions = Array.isArray(req.body?.questions)
            ? req.body.questions
            : [];

        if (!title || duration <= 0 || passMark < 0 || passMark > 100 || !deadline) {
            return res.status(400).json({
                success: false,
                message: 'Title, duration, pass mark, and deadline are required.'
            });
        }

        if (questions.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Add at least one question.'
            });
        }

        client = await pool.connect();
        await client.query('BEGIN');
        const ownership = await ensureOrganizationJobAccess(
            req,
            requestedJobId,
            client
        );

        const testResult = await client.query(
            `INSERT INTO tests (title, duration, pass_mark, deadline, company_id, job_id)
             VALUES ($1, $2, $3, $4, $5, $6)
             RETURNING id, title, duration, pass_mark, deadline, company_id, job_id, created_at`,
            [
                title,
                duration,
                passMark,
                deadline,
                ownership.companyId,
                ownership.jobId
            ]
        );
        const test = testResult.rows[0];

        for (const [index, rawQuestion] of questions.entries()) {
            const questionText = normalizeText(rawQuestion.question_text);
            const questionType = normalizeQuestionType(rawQuestion.question_type);
            const marks = asNumber(rawQuestion.marks);
            const correctAnswer = normalizeText(rawQuestion.correct_answer);
            const options = Array.isArray(rawQuestion.question_options)
                ? rawQuestion.question_options.map(normalizeText).filter(Boolean)
                : Array.isArray(rawQuestion.options)
                  ? rawQuestion.options.map(normalizeText).filter(Boolean)
                  : [];

            if (!questionText || !questionType || marks <= 0) {
                throw new Error(`Question ${index + 1} is incomplete.`);
            }

            if (questionType === 'multiple_choice' && (!correctAnswer || options.length < 2)) {
                throw new Error(
                    `Question ${index + 1} needs at least two options and a correct answer.`
                );
            }

            await client.query(
                `INSERT INTO questions (
                    test_id,
                    question_text,
                    question_type,
                    marks,
                    correct_answer,
                    question_options
                 )
                 VALUES ($1, $2, $3, $4, $5, $6::text[])`,
                [test.id, questionText, questionType, marks, correctAnswer || null, options]
            );
        }

        await client.query('COMMIT');

        return res.status(201).json({
            success: true,
            message: 'Test saved successfully.',
            data: test
        });
    } catch (error) {
        if (client) await client.query('ROLLBACK').catch(() => {});
        console.error('Create test error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to create test.'
        });
    } finally {
        client?.release();
    }
};

const listTests = async (req, res) => {
    try {
        const values = [];
        const clauses = [];
        if (isOrganizationRequest(req)) {
            values.push(req.user.user_id);
            clauses.push(`t.company_id = $${values.length}`);
        }
        if (req.query.job_id) {
            values.push(normalizeText(req.query.job_id));
            clauses.push(`t.job_id = $${values.length}`);
        }
        const whereClause = clauses.length ? `WHERE ${clauses.join(' AND ')}` : '';

        const result = await query(
            `SELECT t.id, t.title, t.duration, t.pass_mark, t.deadline, t.created_at,
                    t.company_id, t.job_id,
                    COUNT(DISTINCT q.id)::int AS question_count,
                    COUNT(DISTINCT ta.id)::int AS invited_count,
                    COUNT(DISTINCT CASE WHEN ta.status = 'completed' THEN ta.id END)::int AS completed_count
             FROM tests t
             LEFT JOIN questions q ON q.test_id = t.id
             LEFT JOIN test_attempts ta ON ta.test_id = t.id
             ${whereClause}
             GROUP BY t.id
             ORDER BY t.created_at DESC`,
            values
        );

        return res.json({ success: true, data: result.rows });
    } catch (error) {
        console.error('List tests error:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

const getTest = async (req, res) => {
    try {
        const testResult = await query(
            `SELECT id, title, duration, pass_mark, deadline, created_at
             FROM tests
             WHERE id = $1`,
            [req.params.testId]
        );

        if (testResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Test not found.' });
        }
        await ensureOrganizationTestAccess(req, req.params.testId);

        const questions = await getTestQuestions(req.params.testId);
        return res.json({
            success: true,
            data: { ...testResult.rows[0], questions }
        });
    } catch (error) {
        console.error('Get test error:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

const inviteStudents = async (req, res) => {
    let client;
    try {
        const testId = req.params.testId;
        const studentIds = Array.isArray(req.body?.student_ids)
            ? req.body.student_ids.map(normalizeText).filter(Boolean)
            : [];

        if (studentIds.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'Select at least one student.'
            });
        }

        const test = await ensureOrganizationTestAccess(req, testId);
        if (!test) {
            return res.status(404).json({ success: false, message: 'Test not found.' });
        }
        const studentsResult = await query(
            `SELECT DISTINCT u.user_id, u.full_name, u.email
             FROM users u
             JOIN students s ON s.student_id = u.user_id
             ${isOrganizationRequest(req)
                ? `JOIN applications a
                     ON a.student_id = u.user_id
                    AND a.job_id = $2
                    AND a.job_id = $3`
                : ''}
             WHERE u.user_id = ANY($1::uuid[])
             ORDER BY u.full_name ASC NULLS LAST, u.email ASC`,
            isOrganizationRequest(req)
                ? [studentIds, test.job_id, test.job_id]
                : [studentIds]
        );

        client = await pool.connect();
        await client.query('BEGIN');

        const invitedStudentIds = studentsResult.rows
            .map((student) => student.user_id)
            .filter(Boolean);
        if (test.job_id && invitedStudentIds.length > 0) {
            await client.query(
                `UPDATE applications
                 SET status = 'assigned',
                     updated_date = CURRENT_TIMESTAMP
                 WHERE job_id = $1
                   AND student_id = ANY($2::uuid[])
                   AND status <> 'accepted'`,
                [test.job_id, invitedStudentIds]
            );
        }

        const frontendBaseUrl = buildFrontendBaseUrl(req);
        const invitations = [];

        for (const student of studentsResult.rows) {
            const existing = await client.query(
                `SELECT id, unique_link
                 FROM test_attempts
                 WHERE test_id = $1 AND student_id = $2
                 LIMIT 1`,
                [testId, student.user_id]
            );

            let token = existing.rows[0]?.unique_link;
            if (!token) {
                token = createInvitationToken();
                await client.query(
                    `INSERT INTO test_attempts (student_id, test_id, unique_link)
                     VALUES ($1, $2, $3)`,
                    [student.user_id, testId, token]
                );
            }

            const link = `${frontendBaseUrl}/?test_token=${encodeURIComponent(token)}`;
            invitations.push({
                student_id: student.user_id,
                student_name: student.full_name,
                email: student.email,
                link
            });
        }

        await client.query('COMMIT');

        const emailResults = [];
        for (const invitation of invitations) {
            try {
                const result = await sendTestInvitationEmail({
                    to: invitation.email,
                    studentName: invitation.student_name,
                    testTitle: test.title,
                    testLink: invitation.link,
                    duration: test.duration,
                    deadline: test.deadline
                });
                emailResults.push({ ...invitation, email_status: result });
            } catch (error) {
                emailResults.push({
                    ...invitation,
                    email_status: { skipped: true, error: error.message }
                });
            }
        }

        return res.json({
            success: true,
            message: 'Test invitations prepared.',
            data: {
                invited_count: invitations.length,
                invitations: emailResults
            }
        });
    } catch (error) {
        if (client) await client.query('ROLLBACK').catch(() => {});
        console.error('Invite students error:', error);
        return res.status(500).json({ success: false, message: error.message });
    } finally {
        client?.release();
    }
};

const getResults = async (req, res) => {
    try {
        await ensureOrganizationTestAccess(req, req.params.testId);
        const result = await query(
            `WITH attempt_scores AS (
                SELECT ta.id AS attempt_id,
                       ta.student_id,
                       ta.test_id,
                       ta.unique_link,
                       ta.started_at,
                       ta.submitted_at,
                       ta.total_score,
                       ta.status AS attempt_status,
                       u.full_name AS student_name,
                       u.email,
                       a.application_id,
                       a.status AS application_status,
                       s.status AS student_selection_status,
                       t.title,
                       t.pass_mark,
                       COALESCE(SUM(q.marks), 0) AS total_marks,
                       CASE
                           WHEN COALESCE(SUM(q.marks), 0) = 0 THEN 0
                           ELSE ROUND((COALESCE(ta.total_score, 0) / SUM(q.marks)) * 100, 2)
                       END AS score_percent,
                       COUNT(ans.id) FILTER (
                           WHERE q.question_type IN ('paragraph', 'code')
                             AND ans.score_awarded IS NULL
                       )::int AS ungraded_count
                FROM test_attempts ta
                JOIN tests t ON t.id = ta.test_id
                JOIN users u ON u.user_id = ta.student_id
                JOIN students s ON s.student_id = ta.student_id
                LEFT JOIN applications a
                       ON a.student_id = ta.student_id
                      AND a.job_id = t.job_id
                LEFT JOIN questions q ON q.test_id = ta.test_id
                LEFT JOIN answers ans
                       ON ans.attempt_id = ta.id
                      AND ans.question_id = q.id
                WHERE ta.test_id = $1
                GROUP BY ta.id, u.full_name, u.email, a.application_id, a.status,
                         s.status, t.title, t.pass_mark, t.job_id, t.company_id
             )
             SELECT *,
                    CASE
                        WHEN application_status = 'accepted' THEN 'accepted'
                        WHEN attempt_status = 'completed' AND ungraded_count > 0 THEN 'pending'
                        WHEN attempt_status = 'completed' AND score_percent >= pass_mark THEN 'selected'
                        WHEN attempt_status = 'completed' THEN 'not_selected'
                        ELSE COALESCE(NULLIF(application_status, ''), student_selection_status, 'pending')
                    END AS selection_status
             FROM attempt_scores
             ORDER BY score_percent DESC, submitted_at ASC NULLS LAST, student_name ASC`,
            [req.params.testId]
        );

        return res.json({ success: true, data: result.rows });
    } catch (error) {
        console.error('Get test results error:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

const getAttemptAnswersForAdmin = async (req, res) => {
    try {
        if (isOrganizationRequest(req)) {
            const accessResult = await query(
                `SELECT t.id
                 FROM test_attempts ta
                 JOIN tests t ON t.id = ta.test_id
                 WHERE ta.id = $1 AND t.company_id = $2
                 LIMIT 1`,
                [req.params.attemptId, req.user.user_id]
            );
            if (accessResult.rows.length === 0) {
                return res.status(403).json({
                    success: false,
                    message: 'You are not allowed to view this attempt.'
                });
            }
        }

        const attemptResult = await query(
            `SELECT ta.id AS attempt_id,
                    ta.status AS attempt_status,
                    ta.total_score,
                    u.full_name AS student_name,
                    u.email,
                    t.title AS test_title
             FROM test_attempts ta
             JOIN users u ON u.user_id = ta.student_id
             JOIN tests t ON t.id = ta.test_id
             WHERE ta.id = $1
             LIMIT 1`,
            [req.params.attemptId]
        );

        if (attemptResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'Attempt not found.' });
        }

        const answersResult = await query(
            `SELECT q.id AS question_id,
                    q.question_text,
                    q.question_type,
                    q.marks,
                    q.correct_answer,
                    a.id AS answer_id,
                    a.answer_text,
                    a.score_awarded
             FROM test_attempts ta
             JOIN questions q ON q.test_id = ta.test_id
             LEFT JOIN answers a
                    ON a.attempt_id = ta.id
                   AND a.question_id = q.id
             WHERE ta.id = $1
             ORDER BY q.created_at ASC, q.id ASC`,
            [req.params.attemptId]
        );

        return res.json({
            success: true,
            data: {
                attempt: attemptResult.rows[0],
                answers: answersResult.rows
            }
        });
    } catch (error) {
        console.error('Get attempt answers error:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

const getAttemptByToken = async (token, client = pool) => {
    const result = await client.query(
        `SELECT ta.id AS attempt_id,
                ta.student_id,
                ta.test_id,
                ta.started_at,
                ta.submitted_at,
                ta.total_score,
                ta.status AS attempt_status,
                t.title,
                t.duration,
                t.pass_mark,
                t.deadline,
                u.full_name AS student_name,
                u.email
         FROM test_attempts ta
         JOIN tests t ON t.id = ta.test_id
         JOIN users u ON u.user_id = ta.student_id
         WHERE ta.unique_link = $1
         LIMIT 1`,
        [token]
    );

    return result.rows[0] || null;
};

const getMyAttempts = async (req, res) => {
    try {
        const studentId = req.user?.user_id;
        const result = await query(
            `SELECT
                ta.id AS online_test_attempt_id,
                ta.test_id AS online_test_id,
                t.title AS online_test_title,
                ta.unique_link AS online_test_token,
                ta.status AS online_test_status,
                t.deadline AS online_test_deadline,
                ta.submitted_at AS online_test_submitted_at,
                t.job_id,
                t.company_id,
                c.company_name
             FROM test_attempts ta
             JOIN tests t ON t.id = ta.test_id
             LEFT JOIN companies c ON c.company_id = t.company_id
             WHERE ta.student_id = $1
             ORDER BY ta.created_at DESC, ta.id DESC`,
            [studentId]
        );

        return res.json({ success: true, data: result.rows });
    } catch (error) {
        console.error('Get my test attempts error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to fetch test invitations.'
        });
    }
};

const getPublicAttempt = async (req, res) => {
    try {
        const token = normalizeText(req.params.token);
        const attempt = await getAttemptByToken(token);

        if (!attempt) {
            return res.status(404).json({ success: false, message: 'Test link not found.' });
        }

        const questions = await getTestQuestions(attempt.test_id);
        const answers = await query(
            `SELECT question_id, answer_text, score_awarded
             FROM answers
             WHERE attempt_id = $1`,
            [attempt.attempt_id]
        );

        if (!attempt.started_at && attempt.attempt_status === 'pending') {
            await query(
                `UPDATE test_attempts
                 SET started_at = NOW(), status = 'in_progress', updated_at = NOW()
                 WHERE id = $1`,
                [attempt.attempt_id]
            );
            attempt.started_at = new Date().toISOString();
            attempt.attempt_status = 'in_progress';
        }

        return res.json({
            success: true,
            data: {
                attempt,
                questions: questions.map(mapQuestionForStudent),
                answers: answers.rows
            }
        });
    } catch (error) {
        console.error('Get public attempt error:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

const upsertAttemptAnswers = async ({
    client,
    attemptId,
    testId,
    answers,
    shouldGrade
}) => {
    const questions = await getTestQuestions(testId, client);
    const questionById = new Map(questions.map((question) => [question.id, question]));

    for (const [questionId, answerText] of Object.entries(answers)) {
        const question = questionById.get(questionId);
        if (!question) continue;

        const score = shouldGrade ? gradeAnswer(question, answerText) : null;
        await client.query(
            `INSERT INTO answers (attempt_id, question_id, answer_text, score_awarded)
             VALUES ($1, $2, $3, $4)
             ON CONFLICT (attempt_id, question_id) DO UPDATE
             SET answer_text = EXCLUDED.answer_text,
                 score_awarded = EXCLUDED.score_awarded,
                 updated_at = NOW()`,
            [attemptId, questionId, answerText, score]
        );
    }
};

const saveAttempt = async (req, res) => {
    let client;
    try {
        const token = normalizeText(req.params.token);
        const answers = parseAnswersPayload(req.body);
        client = await pool.connect();
        await client.query('BEGIN');

        const attempt = await getAttemptByToken(token, client);
        if (!attempt) {
            await client.query('ROLLBACK');
            return res.status(404).json({ success: false, message: 'Test link not found.' });
        }

        if (attempt.submitted_at) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message: 'This test has already been submitted.'
            });
        }

        await upsertAttemptAnswers({
            client,
            attemptId: attempt.attempt_id,
            testId: attempt.test_id,
            answers,
            shouldGrade: false
        });

        await client.query(
            `UPDATE test_attempts
             SET status = 'in_progress',
                 started_at = COALESCE(started_at, NOW()),
                 updated_at = NOW()
             WHERE id = $1`,
            [attempt.attempt_id]
        );

        await client.query('COMMIT');
        return res.json({ success: true, message: 'Progress saved.' });
    } catch (error) {
        if (client) await client.query('ROLLBACK').catch(() => {});
        console.error('Save attempt error:', error);
        return res.status(500).json({ success: false, message: error.message });
    } finally {
        client?.release();
    }
};

const submitAttempt = async (req, res) => {
    let client;
    try {
        const token = normalizeText(req.params.token);
        const answers = parseAnswersPayload(req.body);
        client = await pool.connect();
        await client.query('BEGIN');

        const attempt = await getAttemptByToken(token, client);
        if (!attempt) {
            await client.query('ROLLBACK');
            return res.status(404).json({ success: false, message: 'Test link not found.' });
        }

        if (attempt.submitted_at) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message: 'This test has already been submitted.'
            });
        }

        if (new Date(attempt.deadline).getTime() < Date.now()) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message: 'The test deadline has passed.'
            });
        }

        await upsertAttemptAnswers({
            client,
            attemptId: attempt.attempt_id,
            testId: attempt.test_id,
            answers,
            shouldGrade: true
        });

        const totalResult = await client.query(
            `SELECT COALESCE(SUM(score_awarded), 0) AS total_score
             FROM answers
             WHERE attempt_id = $1`,
            [attempt.attempt_id]
        );
        const totalScore = totalResult.rows[0]?.total_score || 0;

        await client.query(
            `UPDATE test_attempts
             SET status = 'completed',
                 submitted_at = NOW(),
                 total_score = $2,
                 updated_at = NOW()
             WHERE id = $1`,
            [attempt.attempt_id, totalScore]
        );

        const summary = await syncAttemptSelectionAndNotify({
            client,
            attemptId: attempt.attempt_id,
            notifyStudent: true,
            notifyPending: true
        });

        await client.query('COMMIT');
        return res.json({
            success: true,
            message: 'Test submitted successfully',
            data: {
                total_score: Number(totalScore),
                score_percent: Number(summary?.score_percent || 0),
                selection_status: summary?.selection_status || 'pending'
            }
        });
    } catch (error) {
        if (client) await client.query('ROLLBACK').catch(() => {});
        console.error('Submit attempt error:', error);
        return res.status(500).json({ success: false, message: error.message });
    } finally {
        client?.release();
    }
};

const gradeAnswerManually = async (req, res) => {
    let client;
    try {
        const score = asNumber(req.body?.score_awarded, -1);
        if (score < 0) {
            return res.status(400).json({
                success: false,
                message: 'Score must be zero or greater.'
            });
        }

        client = await pool.connect();
        await client.query('BEGIN');

        if (isOrganizationRequest(req)) {
            const accessResult = await client.query(
                `SELECT ans.id
                 FROM answers ans
                 JOIN test_attempts ta ON ta.id = ans.attempt_id
                 JOIN tests t ON t.id = ta.test_id
                 WHERE ans.id = $1 AND t.company_id = $2
                 LIMIT 1`,
                [req.params.answerId, req.user.user_id]
            );
            if (accessResult.rows.length === 0) {
                await client.query('ROLLBACK');
                return res.status(403).json({
                    success: false,
                    message: 'You are not allowed to grade this answer.'
                });
            }
        }

        const result = await client.query(
            `UPDATE answers
             SET score_awarded = $1, updated_at = NOW()
             WHERE id = $2
             RETURNING attempt_id`,
            [score, req.params.answerId]
        );

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({ success: false, message: 'Answer not found.' });
        }

        await client.query(
            `UPDATE test_attempts
             SET total_score = (
                    SELECT COALESCE(SUM(score_awarded), 0)
                    FROM answers
                    WHERE attempt_id = $1
                 ),
                 updated_at = NOW()
             WHERE id = $1`,
            [result.rows[0].attempt_id]
        );

        await syncAttemptSelectionAndNotify({
            client,
            attemptId: result.rows[0].attempt_id,
            notifyStudent: true,
            notifyPending: false
        });

        await client.query('COMMIT');
        return res.json({ success: true, message: 'Score updated.' });
    } catch (error) {
        if (client) await client.query('ROLLBACK').catch(() => {});
        console.error('Manual answer grading error:', error);
        return res.status(500).json({ success: false, message: error.message });
    } finally {
        client?.release();
    }
};

const applyAutoSelection = async (req, res) => {
    let client;
    try {
        const minimumScore = asNumber(req.body?.minimum_score);
        const topN = Math.max(0, Math.round(asNumber(req.body?.top_n)));

        if (minimumScore < 0 || minimumScore > 100) {
            return res.status(400).json({
                success: false,
                message: 'Minimum score must be between 0 and 100.'
            });
        }

        client = await pool.connect();
        await client.query('BEGIN');
        const test = await ensureOrganizationTestAccess(req, req.params.testId, client);
        if (!test) {
            await client.query('ROLLBACK');
            return res.status(404).json({ success: false, message: 'Test not found.' });
        }

        const results = await client.query(
            `SELECT ta.student_id,
                    ta.status AS attempt_status,
                    CASE
                        WHEN COALESCE(SUM(q.marks), 0) = 0 THEN 0
                        ELSE ROUND((COALESCE(ta.total_score, 0) / SUM(q.marks)) * 100, 2)
                    END AS score_percent
             FROM test_attempts ta
             LEFT JOIN questions q ON q.test_id = ta.test_id
             WHERE ta.test_id = $1
             GROUP BY ta.id
             ORDER BY score_percent DESC, ta.submitted_at ASC NULLS LAST`,
            [req.params.testId]
        );

        let selectedSlots = topN;
        const updates = [];

        for (const row of results.rows) {
            const score = asNumber(row.score_percent);
            const completed = row.attempt_status === 'completed';
            let status = 'pending';

            if (!completed) {
                updates.push({
                    student_id: row.student_id,
                    score_percent: score,
                    status,
                    selection_status: 'pending'
                });
                continue;
            }

            if (completed && score >= minimumScore && selectedSlots > 0) {
                status = 'shortlisted';
                selectedSlots -= 1;
            } else {
                status = 'rejected';
            }

            await client.query(
                `UPDATE students
                 SET status = $1
                 WHERE student_id = $2`,
                [status, row.student_id]
            );

            if (test.job_id) {
                await client.query(
                    `UPDATE applications
                     SET status = $1,
                        updated_date = CURRENT_TIMESTAMP,
                        accepted_at = CASE
                             WHEN $1 = 'accepted' THEN CURRENT_TIMESTAMP
                             ELSE accepted_at
                         END
                     WHERE job_id = $2
                       AND student_id = $3`,
                    [status, test.job_id, row.student_id]
                );
            }
            updates.push({
                student_id: row.student_id,
                score_percent: score,
                status,
                selection_status: status === 'shortlisted'
                    ? 'selected'
                    : status === 'rejected'
                      ? 'not_selected'
                      : 'pending'
            });
        }

        await client.query('COMMIT');
        return res.json({
            success: true,
            message: 'Auto-selection applied successfully.',
            data: updates
        });
    } catch (error) {
        if (client) await client.query('ROLLBACK').catch(() => {});
        console.error('Apply auto-selection error:', error);
        return res.status(500).json({ success: false, message: error.message });
    } finally {
        client?.release();
    }
};

module.exports = {
    createTest,
    listTests,
    getTest,
    inviteStudents,
    getResults,
    getAttemptAnswersForAdmin,
    getMyAttempts,
    getPublicAttempt,
    saveAttempt,
    submitAttempt,
    gradeAnswerManually,
    applyAutoSelection
};
