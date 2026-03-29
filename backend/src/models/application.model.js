const { query } = require('../config/database');

class ApplicationModel {
    // Apply for a job
    static async create(applicationData) {
        const { student_id, job_id, cover_letter } = applicationData;
        
        const result = await query(
            `INSERT INTO applications (student_id, job_id, cover_letter, status)
             VALUES ($1, $2, $3, 'pending')
             RETURNING application_id, student_id, job_id, status, applied_date`,
            [student_id, job_id, cover_letter]
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
            `SELECT a.*, j.title, j.location, j.type, c.company_name
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             WHERE a.student_id = $1
             ORDER BY a.applied_date DESC`,
            [student_id]
        );
        return result.rows;
    }

    // Update application status
    static async updateStatus(application_id, status, feedback = null) {
        const result = await query(
            `UPDATE applications 
             SET status = $1, company_feedback = $2, updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $3
             RETURNING *`,
            [status, feedback, application_id]
        );
        return result.rows[0];
    }

    // Get applications for a job (company view)
    static async getByJob(job_id) {
        const result = await query(
            `SELECT a.*, u.full_name, u.email, s.program, s.university_id, u2.name as university_name,
                    j.title as job_title
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN students s ON a.student_id = s.student_id
             JOIN users u ON s.student_id = u.user_id
             LEFT JOIN universities u2 ON s.university_id = u2.university_id
             WHERE a.job_id = $1
             ORDER BY a.applied_date DESC`,
            [job_id]
        );
        return result.rows;
    }

    // Get all applications for a company across all jobs
    static async getByCompany(company_id) {
        const result = await query(
            `SELECT a.*, u.full_name, u.email, s.program, s.university_id, u2.name as university_name,
                    j.title as job_title
             FROM applications a
             JOIN jobs j ON a.job_id = j.job_id
             JOIN students s ON a.student_id = s.student_id
             JOIN users u ON s.student_id = u.user_id
             LEFT JOIN universities u2 ON s.university_id = u2.university_id
             WHERE j.company_id = $1
             ORDER BY a.applied_date DESC`,
            [company_id]
        );
        return result.rows;
    }
}

module.exports = ApplicationModel;
