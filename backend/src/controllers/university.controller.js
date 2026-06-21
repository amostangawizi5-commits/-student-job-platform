const { pool, query } = require('../config/database');
const JobModel = require('../models/job.model');
const { sendApplicationStatusEmail } = require('../services/email.service');
const { syncStudentOfferSelectionState } = require('./application.controller');

const normalizeText = (value) =>
    `${value || ''}`
        .trim()
        .replace(/\s+/g, ' ')
        .toLowerCase();

const cleanTextValue = (value) => `${value || ''}`.trim();

const getQueryRunner = (db = query) => {
    if (typeof db === 'function') {
        return db;
    }

    return db.query.bind(db);
};

const getUniversityScope = async (userId) => {
    const profileResult = await query(
        `SELECT
            up.college_name,
            up.university_id,
            matched.university_id AS resolved_university_id,
            matched.name AS resolved_university_name
         FROM university_profiles up
         LEFT JOIN LATERAL (
            SELECT university_id, name
            FROM universities
            WHERE university_id = up.university_id
               OR (
                    up.university_id IS NULL
                    AND LOWER(TRIM(COALESCE(name, ''))) = LOWER(TRIM(COALESCE(up.college_name, '')))
               )
            ORDER BY CASE WHEN university_id = up.university_id THEN 0 ELSE 1 END
            LIMIT 1
         ) matched ON true
         WHERE up.user_id = $1
         LIMIT 1`,
        [userId]
    );

    const profile = profileResult.rows[0];
    const universityName = `${profile?.resolved_university_name || profile?.college_name || ''}`.trim();
    const universityId = profile?.university_id || profile?.resolved_university_id || null;

    return {
        collegeName: `${profile?.college_name || ''}`.trim(),
        universityName,
        universityId,
        universityIdText: universityId == null ? '' : `${universityId}`.trim()
    };
};

const getUniversityCoordinatorProfile = async (userId, db = query) => {
    const runQuery = getQueryRunner(db);
    const profileResult = await runQuery(
        `SELECT
            college_name,
            coordinator_name,
            coordinator_phone,
            coordinator_email,
            address,
            region,
            district
         FROM university_profiles
         WHERE user_id = $1
         LIMIT 1`,
        [userId]
    );

    return profileResult.rows[0] || null;
};

const matchesStudentToUniversityScope = (student, scope) => {
    if (!student) return false;

    if (scope.universityIdText) {
        return cleanTextValue(student.university_id) === scope.universityIdText;
    }

    const scopeName = scope.universityName || scope.collegeName;
    return normalizeText(student.university_name) === normalizeText(scopeName);
};

const getUniversityStudentsOverview = async (req, res) => {
    try {
        const scope = await getUniversityScope(req.user.user_id);
        const collegeName = scope.universityName || scope.collegeName;

        if (!collegeName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const result = await query(
            `SELECT
                u.user_id,
                u.email,
                u.role,
                u.full_name,
                u.phone,
                u.is_verified,
                u.is_active,
                u.created_at,
                s.program,
                s.university_id,
                s.registration_number,
                uni.name AS university_name,
                s.gpa,
                s.expected_graduation_year
             FROM users u
             JOIN students s ON u.user_id = s.student_id
             LEFT JOIN universities uni ON s.university_id = uni.university_id
             WHERE u.role IN ('student', '')
               AND (
                    ($1 <> '' AND s.university_id::text = $1)
                    OR (
                        $1 = ''
                        AND LOWER(TRIM(COALESCE(uni.name, ''))) = LOWER(TRIM($2))
                    )
               )
             ORDER BY
                LOWER(COALESCE(NULLIF(u.full_name, ''), u.email)),
                u.created_at DESC`,
            [scope.universityIdText, collegeName]
        );

        return res.json({
            success: true,
            data: {
                university_id: scope.universityId,
                university_name: collegeName,
                students: result.rows,
            }
        });
    } catch (error) {
        console.error('Get university students overview error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load university students.'
        });
    }
};

const getUniversityPlacedStudents = async (req, res) => {
    try {
        const scope = await getUniversityScope(req.user.user_id);
        const collegeName = scope.universityName || scope.collegeName;

        if (!collegeName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const result = await query(
            `SELECT DISTINCT ON (a.student_id)
                a.application_id,
                a.student_id,
                a.status,
                a.applied_date,
                a.accepted_at,
                a.updated_date,
                a.response_letter_sent_at,
                a.student_confirmation_status,
                a.student_confirmed_at AS confirmed_at,
                a.company_feedback,
                a.reporting_start_date,
                a.reporting_end_date,
                u.full_name AS student_name,
                u.email,
                u.phone,
                s.registration_number,
                s.program,
                s.university_id,
                COALESCE(uni.name, $2) AS university_name,
                c.company_name,
                j.title,
                j.type,
                COALESCE(NULLIF(j.location, ''), NULLIF(c.location, '')) AS placement_location,
                c.location AS company_location,
                c.department AS placement_department,
                cu.phone AS company_phone
             FROM applications a
             JOIN students s ON a.student_id = s.student_id
             JOIN users u ON a.student_id = u.user_id
             JOIN training j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             JOIN users cu ON c.company_id = cu.user_id
             LEFT JOIN universities uni ON s.university_id = uni.university_id
             WHERE u.role IN ('student', '')
               AND a.status = 'accepted'
               AND (
                    ($1 <> '' AND s.university_id::text = $1)
                    OR (
                        $1 = ''
                        AND LOWER(TRIM(COALESCE(uni.name, ''))) = LOWER(TRIM($2))
                    )
               )
             ORDER BY
                a.student_id,
                COALESCE(a.student_confirmed_at, a.accepted_at, a.updated_date, a.response_letter_sent_at, a.applied_date) DESC`,
            [scope.universityIdText, collegeName]
        );

        return res.json({
            success: true,
            data: {
                university_id: scope.universityId,
                university_name: collegeName,
                placements: result.rows
            }
        });
    } catch (error) {
        console.error('Get university placed students error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load placed students.'
        });
    }
};

const getUniversityCompanyContacts = async (req, res) => {
    try {
        const result = await query(
            `SELECT
                c.company_id,
                c.company_name,
                c.industry,
                c.location,
                c.website_url,
                c.description,
                c.logo_url,
                u.email,
                u.phone
             FROM companies c
             JOIN users u ON c.company_id = u.user_id
             WHERE u.role = 'company'
               AND COALESCE(u.is_active, true) = true
             ORDER BY LOWER(COALESCE(NULLIF(c.company_name, ''), u.email))`
        );

        const companies = result.rows;
        const companyIds = companies
            .map((company) => `${company.company_id || ''}`.trim())
            .filter((companyId) => companyId.length > 0);
        const companyJobs = await JobModel.getByCompanyIds(companyIds);
        const jobsByCompanyId = new Map();

        for (const job of companyJobs) {
            const companyId = `${job.company_id || ''}`.trim();
            if (!companyId) {
                continue;
            }

            const currentJobs = jobsByCompanyId.get(companyId) || [];
            currentJobs.push({
                job_id: job.job_id,
                title: `${job.title || ''}`.trim(),
                location: `${job.location || ''}`.trim(),
                type: `${job.type || ''}`.trim(),
                status: `${job.status || 'open'}`.trim().toLowerCase(),
                available_slots: Number.parseInt(
                    `${job.required_applicants ?? 0}`,
                    10
                ) || 0,
                application_deadline: job.application_deadline,
                created_at: job.created_at
            });
            jobsByCompanyId.set(companyId, currentJobs);
        }

        return res.json({
            success: true,
            data: companies.map((company) => {
                const companyId = `${company.company_id || ''}`.trim();
                return {
                    ...company,
                    is_registered: true,
                    open_jobs: jobsByCompanyId.get(companyId) || []
                };
            }),
        });
    } catch (error) {
        console.error('Get university company contacts error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load company contacts.'
        });
    }
};

const reserveCompanyJobSlotForUniversityAssignment = async (req, res) => {
    try {
        const { companyId, jobId } = req.params;
        const reservedJob = await JobModel.reserveSlot(jobId, companyId);

        if (!reservedJob) {
            return res.status(400).json({
                success: false,
                message:
                    'This job no longer has available slots for assignment.'
            });
        }

        return res.json({
            success: true,
            message: 'Job slot reserved successfully.',
            data: {
                ...reservedJob,
                available_slots:
                    Number.parseInt(
                        `${reservedJob.required_applicants ?? 0}`,
                        10
                    ) || 0
            }
        });
    } catch (error) {
        console.error('Reserve company job slot error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to reserve job slot.'
        });
    }
};

const assignStudentToCompanyJob = async (req, res) => {
    const client = await pool.connect();

    try {
        const { companyId, jobId } = req.params;
        const {
            student_id,
            student_email,
            placement_department,
            placement_location,
            company_phone,
            start_date,
            end_date,
            coordinator_notes
        } = req.body || {};

        const studentId = cleanTextValue(student_id);
        const studentEmail = cleanTextValue(student_email);
        const placementDepartment = cleanTextValue(placement_department);
        const placementLocation = cleanTextValue(placement_location);
        const companyPhone = cleanTextValue(company_phone);
        const coordinatorNotes = cleanTextValue(coordinator_notes);
        const startDate = cleanTextValue(start_date);
        const endDate = cleanTextValue(end_date);

        if (!studentId && !studentEmail) {
            return res.status(400).json({
                success: false,
                message: 'Student ID or student email is required.'
            });
        }

        if (!placementDepartment || !startDate || !endDate) {
            return res.status(400).json({
                success: false,
                message:
                    'Placement department, start date, and end date are required.'
            });
        }

        const startDateValue = new Date(startDate);
        const endDateValue = new Date(endDate);
        if (
            Number.isNaN(startDateValue.getTime()) ||
            Number.isNaN(endDateValue.getTime())
        ) {
            return res.status(400).json({
                success: false,
                message: 'Invalid placement dates provided.'
            });
        }

        if (endDateValue < startDateValue) {
            return res.status(400).json({
                success: false,
                message: 'End date cannot be earlier than start date.'
            });
        }

        const scope = await getUniversityScope(req.user.user_id);
        const collegeName = scope.universityName || scope.collegeName;
        if (!collegeName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const coordinatorProfile = await getUniversityCoordinatorProfile(
            req.user.user_id
        );

        const studentResult = await query(
            `SELECT
                u.user_id,
                u.email,
                u.full_name,
                u.phone,
                s.registration_number,
                s.program,
                s.university_id,
                uni.name AS university_name
             FROM users u
             JOIN students s ON u.user_id = s.student_id
             LEFT JOIN universities uni ON s.university_id = uni.university_id
             WHERE u.role IN ('student', '')
               AND (
                    ($1 <> '' AND u.user_id::text = $1)
                    OR ($2 <> '' AND LOWER(TRIM(COALESCE(u.email, ''))) = LOWER(TRIM($2)))
               )
             ORDER BY
                CASE WHEN $1 <> '' AND u.user_id::text = $1 THEN 0 ELSE 1 END,
                u.created_at DESC
             LIMIT 1`,
            [studentId, studentEmail]
        );

        const student = studentResult.rows[0];
        if (!student) {
            return res.status(404).json({
                success: false,
                message: 'Student not found.'
            });
        }

        if (!matchesStudentToUniversityScope(student, scope)) {
            return res.status(403).json({
                success: false,
                message:
                    'You can only assign placements to students from your university.'
            });
        }

        const jobResult = await query(
            `SELECT
                j.job_id,
                j.company_id,
                j.title,
                j.status,
                j.required_applicants,
                j.application_deadline,
                COALESCE(NULLIF(c.company_name, ''), 'Organization') AS company_name,
                COALESCE(NULLIF(c.location, ''), NULLIF(j.location, '')) AS company_location,
                c.website_url AS company_website_url,
                c.logo_url,
                c.stamp_url,
                c.signature_url,
                c.region,
                c.district,
                c.department,
                cu.email AS company_email,
                cu.phone AS company_user_phone,
                cu.full_name AS company_contact_name
             FROM training j
             JOIN companies c ON j.company_id = c.company_id
             JOIN users cu ON c.company_id = cu.user_id
             WHERE j.job_id = $1
               AND j.company_id = $2
             LIMIT 1`,
            [jobId, companyId]
        );

        const job = jobResult.rows[0];
        if (!job) {
            return res.status(404).json({
                success: false,
                message: 'Company job not found.'
            });
        }

        await client.query('BEGIN');

        const deadline = job.application_deadline
            ? new Date(job.application_deadline)
            : null;
        const isDeadlineActive =
            deadline && !Number.isNaN(deadline.getTime())
                ? deadline >= new Date()
                : false;
        const shouldReserveSlot =
            cleanTextValue(job.status).toLowerCase() === 'open' &&
            isDeadlineActive &&
            (Number.parseInt(`${job.required_applicants ?? 0}`, 10) || 0) > 0;

        let reservedJob = null;
        if (shouldReserveSlot) {
            reservedJob = await JobModel.reserveSlot(jobId, companyId, client);
            if (!reservedJob) {
                await client.query('ROLLBACK');
                return res.status(400).json({
                    success: false,
                    message:
                        'This job no longer has available slots for assignment.'
                });
            }
        }

        const existingApplicationResult = await client.query(
            `SELECT
                application_id
             FROM applications
             WHERE student_id = $1
               AND job_id = $2
             ORDER BY COALESCE(updated_date, accepted_at, applied_date) DESC NULLS LAST
             LIMIT 1
             FOR UPDATE`,
            [student.user_id, jobId]
        );

        let applicationId = cleanTextValue(
            existingApplicationResult.rows[0]?.application_id
        );

        if (!applicationId) {
            const insertedApplication = await client.query(
                `INSERT INTO applications (
                    student_id,
                    job_id,
                    cover_letter,
                    status,
                    supportive_document_url,
                    supportive_document_name,
                    supportive_document_verified
                 )
                 VALUES ($1, $2, $3, 'assigned', NULL, NULL, NULL)
                 RETURNING application_id`,
                [
                    student.user_id,
                    jobId,
                    'Assigned through university placement coordination.'
                ]
            );
            applicationId = cleanTextValue(
                insertedApplication.rows[0]?.application_id
            );
        }

        const feedbackMessage =
            coordinatorNotes ||
            `Assigned through university placement coordination by ${cleanTextValue(coordinatorProfile?.coordinator_name) || cleanTextValue(req.user.full_name) || collegeName}.`;

        const updatedApplicationResult = await client.query(
            `UPDATE applications
             SET
                status = CASE
                    WHEN status = 'accepted' THEN status
                    ELSE 'assigned'
                END,
                company_feedback = $2,
                reporting_start_date = $3::date,
                reporting_end_date = $4::date,
                student_confirmation_status = CASE
                    WHEN status = 'accepted' THEN student_confirmation_status
                    ELSE NULL::varchar
                END,
                student_confirmed_at = CASE
                    WHEN status = 'accepted' THEN student_confirmed_at
                    ELSE NULL::timestamp
                END,
                student_confirmation_expires_at = CASE
                    WHEN status = 'accepted' THEN student_confirmation_expires_at
                    ELSE NULL::timestamp
                END,
                student_confirmation_released_at = CASE
                    WHEN status = 'accepted' THEN student_confirmation_released_at
                    ELSE NULL::timestamp
                END,
                updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $1
             RETURNING application_id, response_letter_url, status`,
            [
                applicationId,
                feedbackMessage,
                startDate,
                endDate
            ]
        );

        await syncStudentOfferSelectionState(student.user_id, client);

        const updatedApplication = updatedApplicationResult.rows[0] || {};
        const isAlreadyAccepted = updatedApplication.status === 'accepted';
        const studentNotificationTitle = isAlreadyAccepted
            ? 'You have been accepted!'
            : 'Placement assigned';
        const studentNotificationMessage = isAlreadyAccepted
            ? `Congratulations! You have been accepted for the position of ${cleanTextValue(job.title)} at ${cleanTextValue(job.company_name)}. Your acceptance response letter is ready in My Applications for download.`
            : `${cleanTextValue(coordinatorProfile?.coordinator_name) || cleanTextValue(req.user.full_name) || collegeName} assigned you to ${cleanTextValue(job.company_name)} for ${cleanTextValue(job.title)}. The company must accept the assignment before your response letter is available.`;
        const companyNotificationTitle = isAlreadyAccepted
            ? 'Student already accepted for placement'
            : 'University assigned a student to your organization';
        const companyNotificationMessage = isAlreadyAccepted
            ? `${cleanTextValue(student.full_name) || cleanTextValue(student.email)} is already accepted for ${cleanTextValue(job.title)}.`
            : `${cleanTextValue(coordinatorProfile?.coordinator_name) || collegeName} assigned ${cleanTextValue(student.full_name) || cleanTextValue(student.email)} to your organization for ${cleanTextValue(job.title)}. Review the assigned application and accept it to generate the response letter.`;

        await client.query(
            `INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
             VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP)`,
            [
                student.user_id,
                studentNotificationTitle,
                studentNotificationMessage,
                isAlreadyAccepted ? 'accepted' : 'assigned'
            ]
        );

        await client.query(
            `INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
             VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP)`,
            [
                companyId,
                companyNotificationTitle,
                companyNotificationMessage,
                'university_manual_assignment'
            ]
        );

        await client.query('COMMIT');

        try {
            await sendApplicationStatusEmail({
                to: cleanTextValue(student.email),
                studentName: cleanTextValue(student.full_name),
                title: studentNotificationTitle,
                message: studentNotificationMessage
            });
        } catch (emailError) {
            console.error('University assignment email error:', emailError);
        }

        return res.json({
            success: true,
            message:
                'Placement assigned successfully. Company acceptance is required before the response letter is available.',
            data: {
                ...updatedApplication,
                reserved_slot: shouldReserveSlot,
                available_slots:
                    Number.parseInt(
                        `${reservedJob?.required_applicants ?? job.required_applicants ?? 0}`,
                        10
                    ) || 0
            }
        });
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (rollbackError) {
            console.error(
                'University assignment rollback error:',
                rollbackError
            );
        }

        console.error('Assign student to company job error:', error);
        const isApplicationStatusConstraintError =
            error?.constraint === 'applications_status_check';
        return res.status(isApplicationStatusConstraintError ? 400 : 500).json({
            success: false,
            message: isApplicationStatusConstraintError
                ? 'Assignment could not be saved because the application status schema is out of date. Restart the API server to apply the latest database schema update.'
                : error.message || 'Failed to save assignment.'
        });
    } finally {
        client.release();
    }
};

module.exports = {
    getUniversityStudentsOverview,
    getUniversityPlacedStudents,
    getUniversityCompanyContacts,
    reserveCompanyJobSlotForUniversityAssignment,
    assignStudentToCompanyJob,
};
