const ApplicationModel = require('../models/application.model');
const NotificationModel = require('../models/notification.model');
const { pool, query } = require('../config/database');
const { sendApplicationStatusEmail } = require('../services/email.service');
const {
    uploadAsset,
    deleteAssetByUrl,
    readAssetBuffer,
    resolveAssetDownloadUrl
} = require('../services/file-storage.service');
const { buildAcceptanceLetterPdf } = require('../services/acceptance-letter.service');

const MULTI_OFFER_CONFIRMATION_WINDOW_HOURS = 48;
const OFFER_CONFIRMATION_PENDING = 'pending';
const OFFER_CONFIRMATION_CONFIRMED = 'confirmed';
const OFFER_CONFIRMATION_EXPIRED = 'expired';
const OFFER_CONFIRMATION_CONFIRMED_ELSEWHERE = 'confirmed_elsewhere';

function getQueryRunner(db = query) {
    if (typeof db === 'function') {
        return db;
    }

    return db.query.bind(db);
}

function formatDate(dateValue) {
    if (!dateValue) return null;
    const parsed = new Date(dateValue);
    if (Number.isNaN(parsed.getTime())) return null;

    return parsed.toLocaleString('en-GB', {
        weekday: 'short',
        day: '2-digit',
        month: 'short',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function formatReportingDate(dateValue) {
    if (!dateValue) return null;
    const parsed = new Date(dateValue);
    if (Number.isNaN(parsed.getTime())) return null;

    return parsed.toLocaleDateString('en-GB', {
        weekday: 'long',
        day: '2-digit',
        month: 'long',
        year: 'numeric'
    });
}

function cleanTextValue(value) {
    return typeof value === 'string' ? value.trim() : '';
}

async function getAccessibleCompanyIdsForUser(userId) {
    const normalizedUserId = cleanTextValue(`${userId || ''}`);
    if (!normalizedUserId) {
        return [];
    }

    const result = await query(
        `WITH current_company AS (
            SELECT company_id, company_name
            FROM companies
            WHERE company_id::text = $1
            LIMIT 1
         )
         SELECT DISTINCT matched.company_id::text AS company_id
         FROM current_company current
         JOIN companies matched
           ON LOWER(REGEXP_REPLACE(BTRIM(COALESCE(matched.company_name, '')), '\\s+', ' ', 'g')) =
              LOWER(REGEXP_REPLACE(BTRIM(COALESCE(current.company_name, '')), '\\s+', ' ', 'g'))
         WHERE BTRIM(COALESCE(current.company_name, '')) <> ''
         UNION
         SELECT $1 AS company_id`,
        [normalizedUserId]
    );

    const ids = result.rows
        .map((row) => cleanTextValue(row.company_id))
        .filter((companyId) => companyId !== '');

    return [...new Set(ids)];
}

function companyIdIsAccessible(companyId, accessibleCompanyIds) {
    const normalizedCompanyId = cleanTextValue(`${companyId || ''}`);
    if (!normalizedCompanyId) {
        return false;
    }

    return (Array.isArray(accessibleCompanyIds) ? accessibleCompanyIds : [])
        .some((accessibleCompanyId) => `${accessibleCompanyId}` === normalizedCompanyId);
}

function isLocalUploadUrl(value) {
    return cleanTextValue(value).startsWith('/uploads/');
}

function hideMissingLocalAssetReferences(application) {
    if (!application) {
        return application;
    }

    const normalized = { ...application };
    for (const field of ['cover_letter', 'supportive_document_url', 'response_letter_url']) {
        const fileUrl = cleanTextValue(normalized[field]);
        if (isLocalUploadUrl(fileUrl) && !resolveAssetDownloadUrl(fileUrl)) {
            normalized[field] = null;
        }
    }

    return normalized;
}

function hideMissingLocalAssetReferencesForList(applications) {
    return Array.isArray(applications)
        ? applications.map(hideMissingLocalAssetReferences)
        : [];
}

function parseCompanyLocationParts(locationValue) {
    const location = cleanTextValue(locationValue);
    if (!location) {
        return { area: '', district: '', region: '' };
    }

    const parts = location
        .split(',')
        .map((part) => part.trim())
        .filter(Boolean);

    if (parts.length === 0) {
        return { area: location, district: '', region: '' };
    }

    if (parts.length === 1) {
        return { area: location, district: '', region: parts[0] };
    }

    return {
        area: location,
        district: parts[0],
        region: parts[parts.length - 1]
    };
}

function normalizeText(value) {
    return `${value || ''}`.trim().toLowerCase();
}

function normalizeConfirmationStatus(value) {
    const normalized = normalizeText(value);
    return normalized || OFFER_CONFIRMATION_PENDING;
}

function isOfferInactiveForSelection(status) {
    return (
        status === OFFER_CONFIRMATION_EXPIRED ||
        status === OFFER_CONFIRMATION_CONFIRMED_ELSEWHERE
    );
}

function deriveAcademicYear(studentProfile) {
    const studentType = normalizeText(studentProfile?.student_type);
    if (studentType === '') {
        return 4;
    }

    const expectedGraduationYear = Number.parseInt(
        `${studentProfile?.expected_graduation_year ?? ''}`,
        10
    );
    if (Number.isNaN(expectedGraduationYear)) {
        return null;
    }

    const currentYear = new Date().getFullYear();
    const remainingYears = expectedGraduationYear - currentYear;

    if (remainingYears <= 0) return 3;
    if (remainingYears === 1) return 2;
    return 1;
}

function matchesTargetCandidates(targetCandidates, academicYear) {
    if (!Array.isArray(targetCandidates) || targetCandidates.length === 0) {
        return true;
    }

    if (academicYear == null) {
        return false;
    }

    return targetCandidates.some((target) => {
        switch (normalizeText(target)) {
            case 'first_year':
                return academicYear === 1;
            case 'second_year':
                return academicYear === 2;
            case 'third_year':
            case 'third_year_plus':
            case 'current_students':
                return academicYear >= 3;
            default:
                return false;
        }
    });
}

function normalizeTargetBucket(target) {
    switch (normalizeText(target)) {
        case 'first_year':
            return 'first_year';
        case 'second_year':
            return 'second_year';
        case 'third_year':
        case 'third_year_plus':
        case 'current_students':
            return 'third_year_plus';
        default:
            return '';
    }
}

function isUnrestrictedTargetCandidates(targetCandidates) {
    if (!Array.isArray(targetCandidates) || targetCandidates.length === 0) {
        return true;
    }

    const normalizedTargets = new Set(
        targetCandidates
            .map((target) => normalizeTargetBucket(target))
            .filter(Boolean)
    );

    return (
        normalizedTargets.has('first_year') &&
        normalizedTargets.has('second_year') &&
        normalizedTargets.has('third_year_plus')
    );
}

function buildEligibilityCriteria(job, studentProfile) {
    const academicYear = deriveAcademicYear(studentProfile);
    const studentProgram = normalizeText(studentProfile?.program);
    const studentGpa = Number.parseFloat(`${studentProfile?.gpa ?? ''}`);
    const studentSkillIds = Array.isArray(studentProfile?.skill_ids)
        ? studentProfile.skill_ids
              .map((skillId) => `${skillId || ''}`.trim())
              .filter(Boolean)
        : [];

    const criteria = [];

    if (!isUnrestrictedTargetCandidates(job.target_candidates)) {
        criteria.push({
            passed: matchesTargetCandidates(job.target_candidates, academicYear),
            reason: 'This opportunity is not open for your current academic year.',
            option: 'your academic year must match the target candidate years'
        });
    }

    const minimumAcademicYear = Number.parseInt(
        `${job.minimum_academic_year ?? ''}`,
        10
    );
    if (!Number.isNaN(minimumAcademicYear) && minimumAcademicYear > 0) {
        criteria.push({
            passed: academicYear != null && academicYear >= minimumAcademicYear,
            reason: `This opportunity requires students from year ${minimumAcademicYear} and above.`,
            option: `be in year ${minimumAcademicYear} or above`
        });
    }

    const eligiblePrograms = Array.isArray(job.eligible_programs)
        ? job.eligible_programs
              .map((program) => `${program}`.trim())
              .filter(Boolean)
        : [];
    if (eligiblePrograms.length > 0) {
        const matchesProgram = eligiblePrograms.some((program) => {
            const normalizedProgram = normalizeText(program);
            return (
                normalizedProgram &&
                studentProgram &&
                (
                    studentProgram.includes(normalizedProgram) ||
                    normalizedProgram.includes(studentProgram)
                )
            );
        });

        criteria.push({
            passed: matchesProgram,
            reason: `This opportunity is only for: ${eligiblePrograms.join(', ')}.`,
            option: `study one of these programs: ${eligiblePrograms.join(', ')}`
        });
    }

    const minimumGpa = Number.parseFloat(`${job.minimum_gpa ?? ''}`);
    if (!Number.isNaN(minimumGpa)) {
        criteria.push({
            passed: !Number.isNaN(studentGpa) && studentGpa >= minimumGpa,
            reason: Number.isNaN(studentGpa)
                ? `A minimum GPA of ${minimumGpa.toFixed(2)} is required.`
                : `Your GPA does not meet the minimum requirement of ${minimumGpa.toFixed(2)}.`,
            option: `have a GPA of at least ${minimumGpa.toFixed(2)}`
        });
    }

    const requiredSkills = Array.isArray(job.required_skills)
        ? job.required_skills
        : [];
    for (const skill of requiredSkills) {
        const skillId = `${skill.skill_id ?? ''}`.trim();
        const skillName = `${skill.name || ''}`.trim();
        if (!skillId || !skillName) {
            continue;
        }

        criteria.push({
            passed: studentSkillIds.includes(skillId),
            reason: `You need the ${skillName} skill before applying.`,
            option: `have the ${skillName} skill`
        });
    }

    return {
        academicYear,
        criteria
    };
}

function evaluateJobEligibility(job, studentProfile) {
    const { academicYear, criteria } = buildEligibilityCriteria(job, studentProfile);
    if (criteria.length === 0) {
        return {
            isEligible: true,
            reasons: [],
            academicYear
        };
    }

    const matchMode = `${job.eligibility_match_mode || 'all'}`.trim().toLowerCase() === 'any'
        ? 'any'
        : 'all';
    const passedCriteria = criteria.filter((criterion) => criterion.passed);
    const failedCriteria = criteria.filter((criterion) => !criterion.passed);

    if (matchMode === 'any') {
        if (passedCriteria.length > 0) {
            return {
                isEligible: true,
                reasons: [],
                academicYear
            };
        }

        return {
            isEligible: false,
            reasons: [
                'You must match at least one of the company requirements below.',
                ...criteria.map((criterion) => `Requirement option: ${criterion.option}`)
            ],
            academicYear
        };
    }

    return {
        isEligible: failedCriteria.length === 0,
        reasons: failedCriteria.map((criterion) => criterion.reason),
        academicYear
    };
}

async function ensureStudentProfileExists({ userId, role }) {
    if (!userId || !['student', ''].includes(`${role}`)) {
        return;
    }

    const studentType = role === '' ? '' : 'current';

    await query(
        `INSERT INTO students (student_id, student_type)
         VALUES ($1, $2)
         ON CONFLICT (student_id) DO NOTHING`,
        [userId, studentType]
    );
}

async function getApplicationWithOwnership(applicationId) {
    const result = await query(
        `SELECT
            a.*,
            j.title as job_title,
            j.company_id,
            c.company_name,
            c.company_id as company_id,
            c.location as company_location,
            c.website_url as company_website_url,
            c.logo_url,
            c.stamp_url,
            c.signature_url,
            c.department as company_department,
            s.program,
            s.registration_number as student_registration_number,
            u2.name as university_name,
            u2.name as college_name,
            u.email as student_email,
            u.full_name as student_name,
            cu.email as company_email,
            cu.full_name as company_contact_name,
            cu.phone as company_phone
         FROM applications a
         JOIN training j ON a.job_id = j.job_id
         JOIN companies c ON j.company_id = c.company_id
         JOIN students s ON a.student_id = s.student_id
         JOIN users u ON a.student_id = u.user_id
         JOIN users cu ON c.company_id = cu.user_id
         LEFT JOIN universities u2 ON s.university_id = u2.university_id
         WHERE a.application_id = $1`,
        [applicationId]
    );

    return result.rows[0] || null;
}

async function getJobWithOwnership(jobId) {
    const result = await query(
        `SELECT
            j.job_id,
            j.company_id,
            j.title
         FROM training j
         WHERE j.job_id = $1
         LIMIT 1`,
        [jobId]
    );

    return result.rows[0] || null;
}

async function syncStudentOfferSelectionState(studentId, db = query) {
    if (!studentId) {
        return;
    }

    const runQuery = getQueryRunner(db);
    const { rows } = await runQuery(
        `SELECT
            application_id,
            accepted_at,
            student_confirmation_status,
            student_confirmation_expires_at
         FROM applications
         WHERE student_id = $1
           AND status = 'accepted'
         ORDER BY COALESCE(accepted_at, updated_date, applied_date) DESC, application_id DESC`,
        [studentId]
    );

    if (rows.length === 0) {
        return;
    }

    const activeOffers = rows.filter((offer) => {
        const offerStatus = normalizeConfirmationStatus(
            offer.student_confirmation_status
        );
        return !isOfferInactiveForSelection(offerStatus);
    });

    if (activeOffers.length === 0) {
        return;
    }

    const now = new Date();
    const nowIso = now.toISOString();
    const confirmedOffer = activeOffers.find(
        (offer) =>
            normalizeConfirmationStatus(offer.student_confirmation_status) ===
            OFFER_CONFIRMATION_CONFIRMED
    );

    if (confirmedOffer) {
        const otherOfferIds = activeOffers
            .filter(
                (offer) =>
                    `${offer.application_id}` !== `${confirmedOffer.application_id}`
            )
            .map((offer) => offer.application_id);

        await runQuery(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmation_released_at = COALESCE(
                    student_confirmation_released_at,
                    CURRENT_TIMESTAMP
                ),
                student_confirmation_expires_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE student_id = $1
               AND status = 'accepted'
               AND application_id::text = ANY($3::text[])`,
            [
                studentId,
                OFFER_CONFIRMATION_CONFIRMED_ELSEWHERE,
                otherOfferIds.map((offerId) => `${offerId}`)
            ]
        );

        await runQuery(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmed_at = COALESCE(
                    student_confirmed_at,
                    CURRENT_TIMESTAMP
                ),
                student_confirmation_expires_at = NULL,
                student_confirmation_released_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $1`,
            [confirmedOffer.application_id, OFFER_CONFIRMATION_CONFIRMED]
        );
        return;
    }

    if (activeOffers.length === 1) {
        await runQuery(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmation_expires_at = NULL,
                student_confirmation_released_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $1`,
            [activeOffers[0].application_id, OFFER_CONFIRMATION_PENDING]
        );
        return;
    }

    const parsedExpiries = activeOffers
        .map((offer) => {
            const rawValue = `${offer.student_confirmation_expires_at || ''}`.trim();
            if (!rawValue) {
                return null;
            }

            const parsed = new Date(rawValue);
            return Number.isNaN(parsed.getTime()) ? null : parsed;
        });
    const hasMissingExpiry = parsedExpiries.some((value) => value === null);
    const nextExpiry = hasMissingExpiry
        ? new Date(
              now.getTime() +
                  MULTI_OFFER_CONFIRMATION_WINDOW_HOURS * 60 * 60 * 1000
          )
        : parsedExpiries
              .filter(Boolean)
              .sort((left, right) => left.getTime() - right.getTime())[0];

    const expiryIso = nextExpiry.toISOString();

    if (hasMissingExpiry) {
        await runQuery(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmation_expires_at = $3,
                student_confirmation_released_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE student_id = $1
               AND status = 'accepted'
               AND COALESCE(student_confirmation_status, '') <> $4`,
            [
                studentId,
                OFFER_CONFIRMATION_PENDING,
                expiryIso,
                OFFER_CONFIRMATION_CONFIRMED
            ]
        );
    }

    if (now > nextExpiry) {
        await runQuery(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmation_expires_at = $3,
                student_confirmation_released_at = COALESCE(
                    student_confirmation_released_at,
                    CURRENT_TIMESTAMP
                ),
                updated_date = CURRENT_TIMESTAMP
             WHERE student_id = $1
               AND status = 'accepted'
               AND COALESCE(student_confirmation_status, '') NOT IN ($2, $4)`,
            [
                studentId,
                OFFER_CONFIRMATION_EXPIRED,
                expiryIso,
                OFFER_CONFIRMATION_CONFIRMED
            ]
        );
    } else {
        await runQuery(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmation_expires_at = $3,
                student_confirmation_released_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE student_id = $1
               AND status = 'accepted'
               AND COALESCE(student_confirmation_status, '') <> $4`,
            [
                studentId,
                OFFER_CONFIRMATION_PENDING,
                expiryIso,
                OFFER_CONFIRMATION_CONFIRMED
            ]
        );
    }
}

async function syncOfferSelectionStateForStudents(studentIds, db = query) {
    const uniqueStudentIds = [...new Set(
        (Array.isArray(studentIds) ? studentIds : [])
            .map((studentId) => `${studentId || ''}`.trim())
            .filter(Boolean)
    )];

    for (const studentId of uniqueStudentIds) {
        await syncStudentOfferSelectionState(studentId, db);
    }
}

async function canAccessApplication(user, application) {
    if (!user || !application) {
        return false;
    }

    if (user.role === 'admin') {
        return true;
    }

    if (['student', ''].includes(`${user.role}`)) {
        return `${application.student_id}` === `${user.user_id}`;
    }

    if (user.role === 'company' || user.role === 'university') {
        const accessibleCompanyIds = await getAccessibleCompanyIdsForUser(
            user.user_id
        );
        return companyIdIsAccessible(
            application.company_id,
            accessibleCompanyIds
        );
    }

    return false;
}

async function streamPdfAsset(res, { fileUrl, fileName, disposition = 'attachment' }) {
    const fileBuffer = await readAssetBuffer(fileUrl);
    const safeFileName = `${fileName || 'document.pdf'}`.replace(/"/g, '');

    res.setHeader('Content-Type', 'application/pdf');
    res.setHeader('Content-Length', `${fileBuffer.length}`);
    res.setHeader(
        'Content-Disposition',
        `${disposition}; filename="${safeFileName}"`
    );

    return res.send(fileBuffer);
}

function logAssetReadError(label, error) {
    if (error?.code === 'ASSET_NOT_FOUND' || error?.code === 'ENOENT') {
        console.warn(`${label} file is missing:`, error.path || error.fileUrl || error.message);
        return;
    }

    console.error(`${label} file read error:`, error);
}

function redirectToStoredAsset(res, fileUrl) {
    const target = `${resolveAssetDownloadUrl(fileUrl) || ''}`.trim();
    if (!target) {
        return false;
    }

    res.redirect(target);
    return true;
}

// Apply for a job
const applyForJob = async (req, res) => {
    let uploadedCoverLetter = null;
    let uploadedSupportiveDocument = null;
    try {
        const { job_id, cover_letter } = req.body;
        const student_id = req.user.user_id;
        const uploadedFiles = req.files || {};
        const coverLetterFile = Array.isArray(uploadedFiles.cover_letter_file)
            ? uploadedFiles.cover_letter_file[0]
            : null;
        const supportiveDocument = Array.isArray(uploadedFiles.supportive_document)
            ? uploadedFiles.supportive_document[0]
            : null;

        await ensureStudentProfileExists({
            userId: student_id,
            role: req.user.role
        });

        const jobData = await query(
            `SELECT
                training.job_id,
                training.company_id,
                training.title,
                training.status,
                training.application_deadline,
                training.target_candidates,
                training.eligible_programs,
                training.minimum_gpa,
                training.minimum_academic_year,
                training.eligibility_match_mode,
                (
                    SELECT json_agg(
                        json_build_object(
                            'skill_id', s.skill_id,
                            'name', s.name
                        )
                    )
                    FROM job_skills js
                    JOIN skills s ON js.skill_id = s.skill_id
                    WHERE js.job_id = training.job_id
                ) AS required_skills
             FROM training
             WHERE job_id = $1`,
            [job_id]
        );

        if (jobData.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Job not found'
            });
        }

        const job = jobData.rows[0];
        const deadline = job.application_deadline
            ? new Date(job.application_deadline)
            : null;
        const isExpired = deadline && !Number.isNaN(deadline.getTime())
            ? deadline < new Date()
            : false;

        if (job.status !== 'open' || isExpired) {
            if (isExpired && job.status === 'open') {
                await query(
                    `UPDATE training
                     SET status = 'closed', updated_at = CURRENT_TIMESTAMP
                     WHERE job_id = $1`,
                    [job_id]
                );
            }

            return res.status(400).json({
                success: false,
                message: 'This job is closed and no longer accepting applications'
            });
        }

        // Check if already applied
        const alreadyApplied = await ApplicationModel.hasApplied(student_id, job_id);
        if (alreadyApplied) {
            return res.status(400).json({
                success: false,
                message: 'You have already applied for this job'
            });
        }

        const hasAppliedToOrganization =
            await ApplicationModel.hasAppliedToOrganization(
                student_id,
                job.company_id
            );
        if (!hasAppliedToOrganization) {
            const distinctOrganizationCount =
                await ApplicationModel.getDistinctOrganizationCount(student_id);
            if (distinctOrganizationCount >= 5) {
                return res.status(400).json({
                    success: false,
                    message:
                        'You can only apply to up to 5 organizations.'
                });
            }
        }

        const studentProfileResult = await query(
            `SELECT
                s.student_id,
                s.student_type,
                s.program,
                s.expected_graduation_year,
                s.gpa,
                COALESCE(
                    ARRAY(
                        SELECT ss.skill_id::text
                        FROM student_skills ss
                        WHERE ss.student_id = s.student_id
                    ),
                    ARRAY[]::text[]
                ) AS skill_ids
             FROM students s
             WHERE s.student_id = $1
             LIMIT 1`,
            [student_id]
        );

        const studentProfile = studentProfileResult.rows[0];
        const eligibility = evaluateJobEligibility(job, studentProfile);
        if (!eligibility.isEligible) {
            return res.status(403).json({
                success: false,
                message: eligibility.reasons[0] || 'You are not eligible for this opportunity.',
                data: {
                    reasons: eligibility.reasons,
                    academic_year: eligibility.academicYear
                }
            });
        }

        if (coverLetterFile) {
            uploadedCoverLetter = await uploadAsset({
                buffer: coverLetterFile.buffer,
                mimeType: coverLetterFile.mimetype,
                originalName: coverLetterFile.originalname,
                localSubdir: 'application-cover-letters',
                fileNamePrefix: 'cover-letter',
                cloudinaryFolder: 'student-job-platform/application-cover-letters',
                cloudinaryResourceType: 'raw'
            });
        }

        if (!uploadedCoverLetter && !cleanTextValue(cover_letter)) {
            return res.status(400).json({
                success: false,
                message: 'Cover letter is required.'
            });
        }

        if (supportiveDocument) {
            uploadedSupportiveDocument = await uploadAsset({
                buffer: supportiveDocument.buffer,
                mimeType: supportiveDocument.mimetype,
                originalName: supportiveDocument.originalname,
                localSubdir: 'application-support-documents',
                fileNamePrefix: 'supportive-document',
                cloudinaryFolder: 'student-job-platform/application-support-documents',
                cloudinaryResourceType: 'raw'
            });

        }

        const application = await ApplicationModel.create({
            student_id,
            job_id,
            cover_letter: uploadedCoverLetter?.secureUrl || cleanTextValue(cover_letter),
            supportive_document_url: uploadedSupportiveDocument?.secureUrl || null,
            supportive_document_name: supportiveDocument?.originalname || null
        });

        // Notify company about new application request (non-blocking)
        try {
            const companyNotificationData = await query(
                `SELECT j.company_id, j.title AS job_title, u.full_name AS student_name
                 FROM training j
                 JOIN users u ON u.user_id = $2
                 WHERE j.job_id = $1`,
                [job_id, student_id]
            );

            if (companyNotificationData.rows.length > 0) {
                const details = companyNotificationData.rows[0];
                await NotificationModel.create({
                    user_id: details.company_id,
                    title: '📥 New Application Request',
                    message: `**${details.student_name || 'A student'}** applied for **${details.job_title}**. Open Applications to review this request.`,
                    type: 'application'
                });
            }
        } catch (notificationError) {
            console.error('Company notification error:', notificationError);
        }

        res.status(201).json({
            success: true,
            message: 'Application submitted successfully!',
            data: application
        });
    } catch (error) {
        if (uploadedSupportiveDocument?.secureUrl) {
            await deleteAssetByUrl({
                fileUrl: uploadedSupportiveDocument.secureUrl,
                resourceType: 'raw'
            }).catch(() => false);
        }
        console.error('Apply error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to submit application',
            error: error.message
        });
    }
};

const reviewSupportiveDocument = async (req, res) => {
    try {
        const { application_id } = req.params;
        const { supportive_document_verified, verification_notes } = req.body;

        const app = await getApplicationWithOwnership(application_id);
        if (!app) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        const accessibleCompanyIds = await getAccessibleCompanyIdsForUser(
            req.user.user_id
        );
        if (!companyIdIsAccessible(app.company_id, accessibleCompanyIds)) {
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to review this application'
            });
        }

        if (!app.supportive_document_url) {
            return res.status(400).json({
                success: false,
                message: 'This application was submitted without a supportive document to review'
            });
        }

        if (typeof supportive_document_verified !== 'boolean') {
            return res.status(400).json({
                success: false,
                message: 'Please choose whether the supportive document is authentic or not'
            });
        }

        const updated = await ApplicationModel.reviewSupportiveDocument(
            application_id,
            supportive_document_verified,
            cleanTextValue(verification_notes) || null
        );

        await NotificationModel.create({
            user_id: app.student_id,
            title: supportive_document_verified
                ? 'Support Document Verified'
                : 'Support Document Needs Attention',
            message: supportive_document_verified
                ? `Your supportive document for **${app.job_title}** at **${app.company_name}** was verified by the company.`
                : `Your supportive document for **${app.job_title}** at **${app.company_name}** was marked as not authentic. Check your application updates for details.`,
            type: 'application'
        });

        return res.json({
            success: true,
            message: supportive_document_verified
                ? 'Supportive document marked as authentic'
                : 'Supportive document marked as not authentic',
            data: updated
        });
    } catch (error) {
        console.error('Review supportive document error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to review supportive document',
            error: error.message
        });
    }
};

// Get my applications
const getMyApplications = async (req, res) => {
    try {
        const student_id = req.user.user_id;
        await syncStudentOfferSelectionState(student_id);
        const applications = await ApplicationModel.getByStudent(student_id);
        
        res.json({
            success: true,
            data: hideMissingLocalAssetReferencesForList(applications)
        });
    } catch (error) {
        console.error('Get applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch applications',
            error: error.message
        });
    }
};

// Get applications for a job (Company only)
const getJobApplications = async (req, res) => {
    try {
        const { job_id } = req.params;
        const training = await getJobWithOwnership(job_id);

        if (!training) {
            return res.status(404).json({
                success: false,
                message: 'Training post not found'
            });
        }

        const accessibleCompanyIds = await getAccessibleCompanyIdsForUser(
            req.user.user_id
        );
        if (!companyIdIsAccessible(training.company_id, accessibleCompanyIds)) {
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to access applications for this training post'
            });
        }

        let applications = await ApplicationModel.getByJob(job_id);
        await syncOfferSelectionStateForStudents(
            applications.map((application) => application.student_id)
        );
        applications = await ApplicationModel.getByJob(job_id);
        
        res.json({
            success: true,
            data: hideMissingLocalAssetReferencesForList(applications)
        });
    } catch (error) {
        console.error('Get job applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch applications',
            error: error.message
        });
    }
};

// Get all company applications
const getCompanyApplications = async (req, res) => {
    try {
        const accessibleCompanyIds = await getAccessibleCompanyIdsForUser(
            req.user.user_id
        );
        let applications = await ApplicationModel.getByCompanyIds(
            accessibleCompanyIds
        );
        await syncOfferSelectionStateForStudents(
            applications.map((application) => application.student_id)
        );
        applications = await ApplicationModel.getByCompanyIds(
            accessibleCompanyIds
        );

        res.json({
            success: true,
            data: hideMissingLocalAssetReferencesForList(applications)
        });
    } catch (error) {
        console.error('Get company applications error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch company applications',
            error: error.message
        });
    }
};

const confirmApplicationSelection = async (req, res) => {
    const client = await pool.connect();

    try {
        const { application_id } = req.params;
        const studentId = req.user.user_id;

        await client.query('BEGIN');

        const applicationResult = await client.query(
            `SELECT
                a.application_id,
                a.student_id,
                a.status,
                a.student_confirmation_status,
                a.student_confirmation_expires_at,
                j.title AS job_title,
                c.company_name
             FROM applications a
             JOIN training j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             WHERE a.application_id = $1
             LIMIT 1`,
            [application_id]
        );

        const application = applicationResult.rows[0];
        if (!application) {
            await client.query('ROLLBACK');
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (`${application.student_id}` !== `${studentId}`) {
            await client.query('ROLLBACK');
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to confirm this placement'
            });
        }

        await syncStudentOfferSelectionState(studentId, client);

        const refreshedResult = await client.query(
            `SELECT
                a.application_id,
                a.status,
                a.student_confirmation_status,
                a.student_confirmation_expires_at,
                j.title AS job_title,
                c.company_name
             FROM applications a
             JOIN training j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             WHERE a.application_id = $1
             LIMIT 1`,
            [application_id]
        );

        const refreshed = refreshedResult.rows[0];
        if (!refreshed || refreshed.status !== 'accepted') {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message: 'Only accepted applications can be confirmed'
            });
        }

        const confirmationStatus = normalizeConfirmationStatus(
            refreshed.student_confirmation_status
        );
        if (confirmationStatus === OFFER_CONFIRMATION_EXPIRED) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message:
                    'This offer expired because it was not confirmed within 48 hours.'
            });
        }

        if (confirmationStatus === OFFER_CONFIRMATION_CONFIRMED_ELSEWHERE) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message: 'You already confirmed another organization.'
            });
        }

        const confirmedElsewhereResult = await client.query(
            `SELECT application_id
             FROM applications
             WHERE student_id = $1
               AND status = 'accepted'
               AND application_id <> $2
               AND student_confirmation_status = $3
             LIMIT 1`,
            [studentId, application_id, OFFER_CONFIRMATION_CONFIRMED]
        );

        if (confirmedElsewhereResult.rows.length > 0) {
            await client.query('ROLLBACK');
            return res.status(400).json({
                success: false,
                message: 'You already confirmed another organization.'
            });
        }

        await client.query(
            `UPDATE applications
             SET
                student_confirmation_status = $2,
                student_confirmed_at = CURRENT_TIMESTAMP,
                student_confirmation_expires_at = NULL,
                student_confirmation_released_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $1`,
            [application_id, OFFER_CONFIRMATION_CONFIRMED]
        );

        await client.query(
            `UPDATE applications
             SET
                student_confirmation_status = $3,
                student_confirmation_released_at = CURRENT_TIMESTAMP,
                student_confirmation_expires_at = NULL,
                updated_date = CURRENT_TIMESTAMP
             WHERE student_id = $1
               AND status = 'accepted'
               AND application_id <> $2
               AND COALESCE(student_confirmation_status, '') <> $4`,
            [
                studentId,
                application_id,
                OFFER_CONFIRMATION_CONFIRMED_ELSEWHERE,
                OFFER_CONFIRMATION_CONFIRMED
            ]
        );

        await client.query('COMMIT');

        await NotificationModel.create({
            user_id: studentId,
            title: 'Placement confirmed',
            message: `You confirmed ${refreshed.company_name} for ${refreshed.job_title}.`,
            type: 'student_company_confirmed'
        });

        return res.json({
            success: true,
            message: `You confirmed ${refreshed.company_name} successfully.`,
            data: {
                application_id,
                student_confirmation_status: OFFER_CONFIRMATION_CONFIRMED
            }
        });
    } catch (error) {
        try {
            await client.query('ROLLBACK');
        } catch (rollbackError) {
            console.error('Confirm placement rollback error:', rollbackError);
        }

        console.error('Confirm placement error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to confirm placement',
            error: error.message
        });
    } finally {
        client.release();
    }
};

const downloadResponseLetter = async (req, res) => {
    try {
        const { application_id } = req.params;
        const application = await getApplicationWithOwnership(application_id);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (!(await canAccessApplication(req.user, application))) {
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to access this response letter'
            });
        }

        if (!application.response_letter_url) {
            return res.status(404).json({
                success: false,
                message: 'Response letter is not available for this application'
            });
        }

        try {
            return await streamPdfAsset(res, {
                fileUrl: application.response_letter_url,
                fileName: application.response_letter_name || 'response_letter.pdf',
                disposition: 'attachment'
            });
        } catch (fileError) {
            logAssetReadError('Response letter', fileError);
            if (redirectToStoredAsset(res, application.response_letter_url)) {
                return;
            }
            return res.status(404).json({
                success: false,
                message:
                    'Response letter file could not be found. Please ask the company to generate it again.'
            });
        }
    } catch (error) {
        console.error('Download response letter error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to download response letter',
            error: error.message
        });
    }
};

const downloadSupportiveDocument = async (req, res) => {
    try {
        const { application_id } = req.params;
        const application = await getApplicationWithOwnership(application_id);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (!(await canAccessApplication(req.user, application))) {
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to access this supportive document'
            });
        }

        if (!application.supportive_document_url) {
            return res.status(404).json({
                success: false,
                message: 'Supportive document is not available for this application'
            });
        }

        try {
            return await streamPdfAsset(res, {
                fileUrl: application.supportive_document_url,
                fileName:
                    application.supportive_document_name || 'supportive_document.pdf',
                disposition: 'inline'
            });
        } catch (fileError) {
            logAssetReadError('Supportive document', fileError);
            if (redirectToStoredAsset(res, application.supportive_document_url)) {
                return;
            }
            return res.status(404).json({
                success: false,
                message:
                    'Supportive document file could not be found. Please ask the student to upload it again.'
            });
        }
    } catch (error) {
        console.error('Download supportive document error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to download supportive document',
            error: error.message
        });
    }
};

const downloadCoverLetter = async (req, res) => {
    try {
        const { application_id } = req.params;
        const application = await getApplicationWithOwnership(application_id);

        if (!application) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        if (!(await canAccessApplication(req.user, application))) {
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to access this cover letter'
            });
        }

        const coverLetterUrl = cleanTextValue(application.cover_letter);
        if (!coverLetterUrl) {
            return res.status(404).json({
                success: false,
                message: 'Cover letter is not available for this application'
            });
        }

        const isFileUrl =
            coverLetterUrl.startsWith('http://') ||
            coverLetterUrl.startsWith('https://') ||
            coverLetterUrl.startsWith('/');

        if (!isFileUrl) {
            return res.status(400).json({
                success: false,
                message: 'This application uses a text cover letter, not an uploaded PDF'
            });
        }

        try {
            return await streamPdfAsset(res, {
                fileUrl: coverLetterUrl,
                fileName: 'cover_letter.pdf',
                disposition: 'inline'
            });
        } catch (fileError) {
            logAssetReadError('Cover letter', fileError);
            if (redirectToStoredAsset(res, coverLetterUrl)) {
                return;
            }
            return res.status(404).json({
                success: false,
                message:
                    'Cover letter file could not be found. Please ask the student to upload it again.'
            });
        }
    } catch (error) {
        console.error('Download cover letter error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to download cover letter',
            error: error.message
        });
    }
};

// Update application status (Company only)
const updateApplicationStatus = async (req, res) => {
    let uploadedResponseLetter = null;
    try {
        const { application_id } = req.params;
        const {
            status,
            feedback,
            _date,
            _venue,
            reporting_start_date,
            reporting_end_date,
            organization_name,
            student_registration_number,
            college_name,
            section_department,
            officer_name,
            officer_designation,
            officer_phone,
            officer_email,
            officer_region,
            officer_district,
            officer_area,
            letter_date
        } = req.body;

        const Venue = cleanTextValue(_venue);
        const feedbackText = cleanTextValue(feedback);
        const reportingStart = reporting_start_date ? new Date(reporting_start_date) : null;
        const reportingEnd = reporting_end_date ? new Date(reporting_end_date) : null;

        if (status === '') {
            if (!_date || !Venue) {
                return res.status(400).json({
                    success: false,
                    message: ' date and venue are required before sending  updates'
                });
            }
        }

        if (status === 'accepted') {
            if (!reporting_start_date || !reporting_end_date) {
                return res.status(400).json({
                    success: false,
                    message: 'Reporting start date and end date are required before accepting an applicant'
                });
            }

            if (
                !reportingStart ||
                Number.isNaN(reportingStart.getTime()) ||
                !reportingEnd ||
                Number.isNaN(reportingEnd.getTime())
            ) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid reporting dates provided'
                });
            }

            if (reportingEnd < reportingStart) {
                return res.status(400).json({
                    success: false,
                    message: 'Reporting end date cannot be earlier than reporting start date'
                });
            }
        }
        
        // Get application details with job and company info
        const app = await getApplicationWithOwnership(application_id);

        if (!app) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        const accessibleCompanyIds = await getAccessibleCompanyIdsForUser(
            req.user.user_id
        );
        if (!companyIdIsAccessible(app.company_id, accessibleCompanyIds)) {
            return res.status(403).json({
                success: false,
                message: 'You are not allowed to update this application'
            });
        }

        if (app.supportive_document_url && app.supportive_document_verified === null) {
            return res.status(400).json({
                success: false,
                message: 'Review the supportive document before sending an application response'
            });
        }

        if (
            app.supportive_document_url &&
            app.supportive_document_verified === false &&
            status !== 'rejected'
        ) {
            return res.status(400).json({
                success: false,
                message: 'A document marked as not authentic can only be rejected'
            });
        }

        if (status === 'accepted') {
            const inferredLocation = parseCompanyLocationParts(app.company_location);
            const organizationName = cleanTextValue(organization_name) || app.company_name;
            const registrationNumber =
                cleanTextValue(student_registration_number) ||
                cleanTextValue(app.student_registration_number) ||
                'N/A';
            const collegeName =
                cleanTextValue(college_name) ||
                cleanTextValue(app.college_name) ||
                cleanTextValue(app.university_name) ||
                'College of Informatics and Virtual Education';
            const sectionDepartment =
                cleanTextValue(section_department) ||
                cleanTextValue(app.company_department) ||
                cleanTextValue(app.job_title) ||
                'Administration';
            const officerName =
                cleanTextValue(officer_name) ||
                cleanTextValue(app.company_contact_name) ||
                cleanTextValue(app.company_name) ||
                'Authorized Officer';
            const officerDesignation =
                cleanTextValue(officer_designation) ||
                (cleanTextValue(app.company_department)
                    ? `${cleanTextValue(app.company_department)} Officer`
                    : 'Authorized Officer');
            const officerPhone =
                cleanTextValue(officer_phone) ||
                cleanTextValue(app.company_phone) ||
                'N/A';
            const officerEmail =
                cleanTextValue(officer_email) ||
                cleanTextValue(app.company_email) ||
                'N/A';
            const officerRegion =
                cleanTextValue(officer_region) || inferredLocation.region || 'N/A';
            const officerDistrict =
                cleanTextValue(officer_district) || inferredLocation.district || 'N/A';
            const officerArea =
                cleanTextValue(officer_area) || inferredLocation.area || 'N/A';
            const letterDate = cleanTextValue(letter_date);

            let acceptanceLetterBuffer;
            try {
                acceptanceLetterBuffer = await buildAcceptanceLetterPdf({
                    organizationName,
                    studentName: app.student_name,
                    registrationNumber,
                    collegeName,
                    universityName: app.university_name || '',
                    sectionDepartment,
                    officerName,
                    officerDesignation,
                    officerPhone,
                    officerEmail,
                    officerRegion,
                    officerDistrict,
                    officerArea,
                    startDate: reporting_start_date,
                    endDate: reporting_end_date,
                    letterDate,
                    companyLogoUrl: app.logo_url,
                    footerCompanyName: organizationName || app.company_name,
                    footerLocation: app.company_location,
                    footerPhone: app.company_phone,
                    footerEmail: app.company_email,
                    footerWebsite: app.company_website_url,
                    stampImageUrl: app.stamp_url,
                    signatureImageUrl: app.signature_url
                });
            } catch (pdfError) {
                console.error('Acceptance letter build error:', {
                    application_id,
                    company_id: app.company_id,
                    student_id: app.student_id,
                    companyLogoUrl: app.logo_url,
                    stampImageUrl: app.stamp_url,
                    signatureImageUrl: app.signature_url,
                    error: pdfError.message
                });
                throw pdfError;
            }

            uploadedResponseLetter = await uploadAsset({
                buffer: acceptanceLetterBuffer,
                mimeType: 'application/pdf',
                originalName: `${app.student_name || 'student'}-acceptance-letter.pdf`,
                localSubdir: 'response-letters',
                fileNamePrefix: 'response-letter',
                cloudinaryFolder: 'student-job-platform/response-letters',
                cloudinaryResourceType: 'raw'
            });
        }
        
        // Update application status
        const updated = await ApplicationModel.updateStatus(
            application_id,
            status,
            feedbackText || null,
            {
                response_letter_url: uploadedResponseLetter?.secureUrl || null,
                response_letter_name: uploadedResponseLetter
                    ? `${app.student_name || 'student'}-acceptance-letter.pdf`
                    : null,
                reporting_start_date: reporting_start_date || null,
                reporting_end_date: reporting_end_date || null
            }
        );

        await syncStudentOfferSelectionState(app.student_id);

        if (
            uploadedResponseLetter?.secureUrl &&
            app.response_letter_url &&
            app.response_letter_url !== uploadedResponseLetter.secureUrl
        ) {
            await deleteAssetByUrl({
                fileUrl: app.response_letter_url,
                resourceType: 'raw'
            });
        }
        
        // Send notification to student based on status
        let title = '';
        let message = '';
        let notificationType = status;
        
        switch (status) {
            case 'shortlisted':
                title = ' You have been shortlisted!';
                message = `Congratulations! You have been shortlisted for the position of **${app.job_title}** at **${app.company_name}**. The company will contact you soon for the next steps. Keep an eye on your email!`;
                break;
            case '':
                title = ' Scheduled!';
                {
                    const DateLabel =
                        formatDate(_date) ||
                        formatDate(updated?.updated_date) ||
                        formatDate(new Date());
                    message =
                        `Great news! You have been selected for an  for **${app.job_title}** at **${app.company_name}**.\n` +
                        ` Date: ${DateLabel}\n` +
                        ` Venue: ${Venue}\n` +
                        `Please report to the venue above on time and check your email for any extra instructions. Good luck!`;
                }
                break;
            case 'accepted':
                title = ' You have been accepted!';
                {
                    const reportingStartLabel =
                        formatReportingDate(reporting_start_date) ||
                        formatReportingDate(reportingStart);
                    const reportingEndLabel =
                        formatReportingDate(reporting_end_date) ||
                        formatReportingDate(reportingEnd);
                    message =
                        `Congratulations! You have been accepted for the position of **${app.job_title}** at **${app.company_name}**.\n` +
                        `Reporting Period: ${reportingStartLabel} to ${reportingEndLabel}\n` +
                        `Your acceptance response letter is ready in My Applications for download. Welcome aboard!`;
                }
                break;
            case 'rejected':
                title = ' Application Update';
                if (feedbackText !== '') {
                    message = `Thank you for applying for **${app.job_title}** at **${app.company_name}**. After careful review, we regret to inform you that your application was not successful. Feedback: "${feedbackText}". Keep improving your skills and apply again!`;
                } else {
                    message = `Thank you for applying for **${app.job_title}** at **${app.company_name}**. After careful review, we regret to inform you that your application was not successful. Don't give up! Keep learning and apply for other opportunities.`;
                }
                break;
            default:
                title = 'Application Update';
                message = `Your application for **${app.job_title}** at **${app.company_name}** has been updated to **${status}**.`;
        }
        
        // Create notification for student
        await NotificationModel.create({
            user_id: app.student_id,
            title: title,
            message: message,
            type: notificationType
        });

        try {
            await sendApplicationStatusEmail({
                to: app.student_email,
                studentName: app.student_name,
                title,
                message
            });
        } catch (emailError) {
            console.error('Application status email error:', emailError);
        }
        
        console.log(`Notification sent to student ${app.student_id} for status: ${status}`);
        
        res.json({
            success: true,
            message: `Application ${status === 'accepted' ? 'accepted' : status === 'rejected' ? 'rejected' : 'updated'} successfully`,
            data: updated
        });
    } catch (error) {
        if (uploadedResponseLetter?.secureUrl) {
            await deleteAssetByUrl({
                fileUrl: uploadedResponseLetter.secureUrl,
                resourceType: 'raw'
            }).catch(() => false);
        }
        console.error('Update status error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update status',
            error: error.message
        });
    }
};

module.exports = {
    applyForJob,
    reviewSupportiveDocument,
    getMyApplications,
    getJobApplications,
    getCompanyApplications,
    confirmApplicationSelection,
    getOrganizationApplications: getCompanyApplications,
    downloadCoverLetter,
    downloadSupportiveDocument,
    downloadResponseLetter,
    updateApplicationStatus,
    syncStudentOfferSelectionState
};
