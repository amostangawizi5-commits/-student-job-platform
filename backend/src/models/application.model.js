const { query } = require('../config/database');

class ApplicationModel {
    // Apply for a job
    static async create(applicationData) {
        const {
            student_id,
            job_id,
            cover_letter,
            supportive_document_url,
            supportive_document_name
        } = applicationData;
        
        const result = await query(
            `INSERT INTO applications (
                student_id,
                job_id,
                cover_letter,
                status,
                supportive_document_url,
                supportive_document_name,
                supportive_document_verified
             )
             VALUES ($1, $2, $3, 'pending', $4, $5, NULL)
             RETURNING
                application_id,
                student_id,
                job_id,
                status,
                applied_date,
                supportive_document_url,
                supportive_document_name,
                supportive_document_verified`,
            [
                student_id,
                job_id,
                cover_letter,
                supportive_document_url,
                supportive_document_name
            ]
        );
        
        return result.rows[0];
    }

    // Check if already applied
    static async hasApplied(student_id, job_id) {
        const result = await query(
            'SELECT * FROM applications WHERE student_id = $1 AND job_id = $2',
            [student_id, job_id]
        );
        return result.rows.length > 0;
    }

    // Get applications by student
    static async getByStudent(student_id) {
        const result = await query(
            `SELECT
                a.*,
                j.title,
                j.location,
                j.type,
                c.company_name,
                s.resume_url,
                aw.award_id,
                aw.title AS award_title,
                aw.award_type AS award_award_type,
                aw.category AS award_category,
                aw.description AS award_description,
                aw.reason AS award_reason,
                aw.highlights AS award_highlights,
                aw.prize_type AS award_prize_type,
                aw.prize_value AS award_prize_value,
                aw.prize_description AS award_prize_description,
                aw.rating AS award_rating,
                aw.award_date AS award_date,
                aw.award_status AS award_status,
                aw.announce_on_homepage AS award_announce_on_homepage,
                aw.is_student_of_month AS award_is_student_of_month,
                aw.certificate_name AS award_certificate_name
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN students s ON a.student_id = s.student_id
             JOIN companies c ON j.company_id = c.company_id
             LEFT JOIN awards aw ON aw.application_id = a.application_id
             WHERE a.student_id = $1
             ORDER BY a.applied_date DESC`,
            [student_id]
        );
        return result.rows;
    }

    static async reviewSupportiveDocument(
        application_id,
        supportive_document_verified,
        verification_notes = null
    ) {
        const result = await query(
            `UPDATE applications
             SET
                supportive_document_verified = $1,
                supportive_document_verification_notes = $2,
                supportive_document_reviewed_at = CURRENT_TIMESTAMP,
                updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $3
             RETURNING *`,
            [supportive_document_verified, verification_notes, application_id]
        );
        return result.rows[0];
    }

    // Update application status
    static async updateStatus(
        application_id,
        status,
        feedback = null,
        {
            response_letter_url = null,
            response_letter_name = null
        } = {}
    ) {
        const result = await query(
            `UPDATE applications 
             SET
                status = $1,
                company_feedback = $2,
                response_letter_url = COALESCE($3, response_letter_url),
                response_letter_name = COALESCE($4, response_letter_name),
                response_letter_sent_at = CASE
                    WHEN $3 IS NOT NULL THEN CURRENT_TIMESTAMP
                    ELSE response_letter_sent_at
                END,
                updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $5
             RETURNING *`,
            [
                status,
                feedback,
                response_letter_url,
                response_letter_name,
                application_id
            ]
        );
        return result.rows[0];
    }

    // Get applications for a job (company view)
    static async getByJob(job_id) {
        const result = await query(
            `SELECT
                    a.*,
                    u.full_name,
                    u.email,
                    s.program,
                    s.registration_number AS student_registration_number,
                    s.university_id,
                    u2.name as university_name,
                    u2.name as college_name,
                    j.title as job_title,
                    c.company_name,
                    c.location AS company_location,
                    c.stamp_url,
                    c.signature_url,
                    s.resume_url,
                    aw.award_id,
                    aw.title AS award_title,
                    aw.award_type AS award_award_type,
                    aw.category AS award_category,
                    aw.description AS award_description,
                    aw.reason AS award_reason,
                    aw.highlights AS award_highlights,
                    aw.prize_type AS award_prize_type,
                    aw.prize_value AS award_prize_value,
                    aw.prize_description AS award_prize_description,
                    aw.rating AS award_rating,
                    aw.award_date AS award_date,
                    aw.award_status AS award_status,
                    aw.announce_on_homepage AS award_announce_on_homepage,
                    aw.is_student_of_month AS award_is_student_of_month,
                    aw.certificate_name AS award_certificate_name
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             JOIN students s ON a.student_id = s.student_id
             JOIN users u ON s.student_id = u.user_id
             LEFT JOIN universities u2 ON s.university_id = u2.university_id
             LEFT JOIN awards aw ON aw.application_id = a.application_id
             WHERE a.job_id = $1
             ORDER BY a.applied_date DESC`,
            [job_id]
        );
        return result.rows;
    }

    // Get all applications for a company across all jobs
    static async getByCompany(company_id) {
        const result = await query(
            `SELECT
                    a.*,
                    u.full_name,
                    u.email,
                    s.program,
                    s.registration_number AS student_registration_number,
                    s.university_id,
                    u2.name as university_name,
                    u2.name as college_name,
                    j.title as job_title,
                    c.company_name,
                    c.location AS company_location,
                    c.stamp_url,
                    c.signature_url,
                    s.resume_url,
                    aw.award_id,
                    aw.title AS award_title,
                    aw.award_type AS award_award_type,
                    aw.category AS award_category,
                    aw.description AS award_description,
                    aw.reason AS award_reason,
                    aw.highlights AS award_highlights,
                    aw.prize_type AS award_prize_type,
                    aw.prize_value AS award_prize_value,
                    aw.prize_description AS award_prize_description,
                    aw.rating AS award_rating,
                    aw.award_date AS award_date,
                    aw.award_status AS award_status,
                    aw.announce_on_homepage AS award_announce_on_homepage,
                    aw.is_student_of_month AS award_is_student_of_month,
                    aw.certificate_name AS award_certificate_name
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             JOIN students s ON a.student_id = s.student_id
             JOIN users u ON s.student_id = u.user_id
             LEFT JOIN universities u2 ON s.university_id = u2.university_id
             LEFT JOIN awards aw ON aw.application_id = a.application_id
             WHERE j.company_id = $1
             ORDER BY a.applied_date DESC`,
            [company_id]
        );
        return result.rows;
    }
}

module.exports = ApplicationModel;
