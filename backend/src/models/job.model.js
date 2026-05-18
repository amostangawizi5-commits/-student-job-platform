// src/models/job.model.js
const { query } = require('../config/database');

class JobModel {
    static async closeExpiredtraining() {
        await query(
            `UPDATE training
             SET status = 'closed', updated_at = CURRENT_TIMESTAMP
             WHERE status = 'open' AND application_deadline < CURRENT_TIMESTAMP`
        );
    }

    // Create a new job
    static async create(jobData) {
        const {
            company_id,
            title,
            type,
            target_candidates,
            description,
            location,
            salary_range,
            required_applicants,
            application_deadline,
            eligible_programs,
            minimum_gpa,
            minimum_academic_year,
            eligibility_notes,
            eligibility_match_mode = 'all',
            status = 'open'
        } = jobData;

        const result = await query(
            `INSERT INTO training (
                company_id, title, type, target_candidates, description, 
                location, salary_range, required_applicants, application_deadline,
                eligible_programs, minimum_gpa, minimum_academic_year, eligibility_notes,
                eligibility_match_mode, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)
            RETURNING job_id, title, type, status, created_at, required_applicants, application_deadline`,
            [
                company_id,
                title,
                type,
                target_candidates,
                description,
                location,
                salary_range,
                required_applicants,
                application_deadline,
                eligible_programs,
                minimum_gpa,
                minimum_academic_year,
                eligibility_notes,
                eligibility_match_mode,
                status
            ]
        );
        
        return result.rows[0];
    }

    // Get all training with filters
    static async getAll(filters = {}) {
        await this.closeExpiredtraining();

        let sql = `
            SELECT 
                j.*,
                COALESCE(
                    NULLIF(c.company_name, ''),
                    NULLIF(u.full_name, ''),
                    NULLIF(u.email, ''),
                    'Organization'
                ) AS company_name,
                c.logo_url,
                COALESCE(NULLIF(c.location, ''), NULLIF(j.location, '')) AS company_location,
                (
                    SELECT json_agg(json_build_object('skill_id', s.skill_id, 'name', s.name))
                    FROM job_skills js
                    JOIN skills s ON js.skill_id = s.skill_id
                    WHERE js.job_id = j.job_id
                ) as required_skills
            FROM training j
            LEFT JOIN companies c ON j.company_id = c.company_id
            LEFT JOIN users u ON j.company_id = u.user_id
            WHERE 1 = 1
        `;
        
        const values = [];
        let paramCount = 1;
        
        if (filters.view === 'history') {
            sql += ` AND j.status = 'closed'`;
        } else {
            sql += ` AND j.status = 'open' AND j.application_deadline >= CURRENT_TIMESTAMP`;
        }

        // Add filters
        if (filters.type && filters.type !== 'all') {
            sql += ` AND j.type = $${paramCount}`;
            values.push(filters.type);
            paramCount++;
        }
        
        if (filters.location && filters.location !== 'all') {
            sql += ` AND j.location ILIKE $${paramCount}`;
            values.push(`%${filters.location}%`);
            paramCount++;
        }
        
        if (filters.search) {
            sql += ` AND (
                j.title ILIKE $${paramCount}
                OR j.description ILIKE $${paramCount}
                OR COALESCE(j.location, '') ILIKE $${paramCount}
                OR COALESCE(c.company_name, '') ILIKE $${paramCount}
                OR COALESCE(u.full_name, '') ILIKE $${paramCount}
                OR COALESCE(u.email, '') ILIKE $${paramCount}
                OR COALESCE(c.location, '') ILIKE $${paramCount}
                OR COALESCE(j.type, '') ILIKE $${paramCount}
            )`;
            values.push(`%${filters.search}%`);
            paramCount++;
        }
        
        // Order by newest first
        sql += ` ORDER BY j.created_at DESC`;
        
        // Add limit
        if (filters.limit) {
            sql += ` LIMIT $${paramCount}`;
            values.push(filters.limit);
        }
        
        const result = await query(sql, values);
        return result.rows;
    }

    // Get job by ID with company details
    static async getById(jobId) {
        await this.closeExpiredtraining();

        const result = await query(
            `SELECT 
                j.*,
                COALESCE(
                    NULLIF(c.company_name, ''),
                    NULLIF(u.full_name, ''),
                    NULLIF(u.email, ''),
                    'Organization'
                ) AS company_name,
                c.logo_url,
                c.description as company_description,
                c.industry,
                COALESCE(NULLIF(c.location, ''), NULLIF(j.location, '')) as company_location,
                (
                    SELECT json_agg(json_build_object('skill_id', s.skill_id, 'name', s.name, 'category', s.category))
                    FROM job_skills js
                    JOIN skills s ON js.skill_id = s.skill_id
                    WHERE js.job_id = j.job_id
                ) as required_skills
            FROM training j
            LEFT JOIN companies c ON j.company_id = c.company_id
            LEFT JOIN users u ON j.company_id = u.user_id
            WHERE j.job_id = $1`,
            [jobId]
        );
        
        return result.rows[0];
    }

    // Get training by company
    static async getByCompany(companyId) {
        await this.closeExpiredtraining();

        const result = await query(
            `SELECT 
                j.*,
                (
                    SELECT json_agg(json_build_object('skill_id', s.skill_id, 'name', s.name))
                    FROM job_skills js
                    JOIN skills s ON js.skill_id = s.skill_id
                    WHERE js.job_id = j.job_id
                ) as required_skills,
                (
                    SELECT COUNT(*) FROM applications WHERE job_id = j.job_id
                ) as applications_count
            FROM training j
            WHERE j.company_id = $1
              AND j.status = 'open'
              AND j.application_deadline >= CURRENT_TIMESTAMP
            ORDER BY j.created_at DESC`,
            [companyId]
        );
        
        return result.rows;
    }

    // Update job
    static async update(jobId, updateData) {
        const fields = [];
        const values = [];
        let index = 1;
        
        for (const [key, value] of Object.entries(updateData)) {
            if (value !== undefined) {
                fields.push(`${key} = $${index}`);
                values.push(value);
                index++;
            }
        }
        
        values.push(jobId);
        
        const result = await query(
            `UPDATE training SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP 
             WHERE job_id = $${index} RETURNING *`,
            values
        );
        
        return result.rows[0];
    }

    // Delete job
    static async delete(jobId) {
        const result = await query(
            'DELETE FROM training WHERE job_id = $1 RETURNING job_id',
            [jobId]
        );
        return result.rows[0];
    }

    // Get job skills
    static async addtrainingkill(jobId, skillId) {
        await query(
            'INSERT INTO job_skills (job_id, skill_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [jobId, skillId]
        );
    }

    // Remove job skill
    static async removetrainingkill(jobId, skillId) {
        await query(
            'DELETE FROM job_skills WHERE job_id = $1 AND skill_id = $2',
            [jobId, skillId]
        );
    }

    static async replacetrainingkills(jobId, skillIds = []) {
        await query('DELETE FROM job_skills WHERE job_id = $1', [jobId]);

        for (const skillId of skillIds) {
            await this.addtrainingkill(jobId, skillId);
        }
    }
}

module.exports = JobModel;
