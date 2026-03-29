// src/models/job.model.js
const { query } = require('../config/database');

class JobModel {
    static async closeExpiredJobs() {
        await query(
            `UPDATE jobs
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
            status = 'open'
        } = jobData;

        const result = await query(
            `INSERT INTO jobs (
                company_id, title, type, target_candidates, description, 
                location, salary_range, required_applicants, application_deadline, status
            ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
            RETURNING job_id, title, type, status, created_at, required_applicants, application_deadline`,
            [company_id, title, type, target_candidates, description, 
             location, salary_range, required_applicants, application_deadline, status]
        );
        
        return result.rows[0];
    }

    // Get all jobs with filters
    static async getAll(filters = {}) {
        await this.closeExpiredJobs();

        let sql = `
            SELECT 
                j.*,
                c.company_name,
                c.logo_url,
                c.location as company_location,
                (
                    SELECT json_agg(json_build_object('skill_id', s.skill_id, 'name', s.name))
                    FROM job_skills js
                    JOIN skills s ON js.skill_id = s.skill_id
                    WHERE js.job_id = j.job_id
                ) as required_skills
            FROM jobs j
            JOIN companies c ON j.company_id = c.company_id
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
            sql += ` AND (j.title ILIKE $${paramCount} OR j.description ILIKE $${paramCount})`;
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
        await this.closeExpiredJobs();

        const result = await query(
            `SELECT 
                j.*,
                c.company_name,
                c.logo_url,
                c.description as company_description,
                c.industry,
                c.location as company_location,
                (
                    SELECT json_agg(json_build_object('skill_id', s.skill_id, 'name', s.name, 'category', s.category))
                    FROM job_skills js
                    JOIN skills s ON js.skill_id = s.skill_id
                    WHERE js.job_id = j.job_id
                ) as required_skills
            FROM jobs j
            JOIN companies c ON j.company_id = c.company_id
            WHERE j.job_id = $1`,
            [jobId]
        );
        
        return result.rows[0];
    }

    // Get jobs by company
    static async getByCompany(companyId) {
        await this.closeExpiredJobs();

        const result = await query(
            `SELECT 
                j.*,
                (
                    SELECT COUNT(*) FROM applications WHERE job_id = j.job_id
                ) as applications_count
            FROM jobs j
            WHERE j.company_id = $1
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
            `UPDATE jobs SET ${fields.join(', ')}, updated_at = CURRENT_TIMESTAMP 
             WHERE job_id = $${index} RETURNING *`,
            values
        );
        
        return result.rows[0];
    }

    // Delete job
    static async delete(jobId) {
        const result = await query(
            'DELETE FROM jobs WHERE job_id = $1 RETURNING job_id',
            [jobId]
        );
        return result.rows[0];
    }

    // Get job skills
    static async addJobSkill(jobId, skillId) {
        await query(
            'INSERT INTO job_skills (job_id, skill_id) VALUES ($1, $2) ON CONFLICT DO NOTHING',
            [jobId, skillId]
        );
    }

    // Remove job skill
    static async removeJobSkill(jobId, skillId) {
        await query(
            'DELETE FROM job_skills WHERE job_id = $1 AND skill_id = $2',
            [jobId, skillId]
        );
    }
}

module.exports = JobModel;
