// src/controllers/job.controller.js
const JobModel = require('../models/job.model');

class JobValidationError extends Error {}

function formatNumberWithCommas(value) {
    return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function normalizeSalaryRange(rawValue) {
    if (rawValue === undefined) return undefined;
    if (rawValue === null) return null;

    const value = `${rawValue}`.trim();
    if (!value) return null;

    const cleaned = value.replace(/^TZS\s*/i, '');
    const parts = cleaned
        .split('-')
        .map(part => part.replace(/,/g, '').trim())
        .filter(Boolean);

    if (parts.length === 0 || parts.length > 2 || parts.some(part => !/^\d+$/.test(part))) {
        throw new JobValidationError('Salary range must contain Tanzanian shilling amounts only');
    }

    const amounts = parts.map(part => parseInt(part, 10));
    if (amounts.some(amount => amount <= 0)) {
        throw new JobValidationError('Salary range must be greater than zero');
    }

    if (amounts.length === 2 && amounts[1] < amounts[0]) {
        throw new JobValidationError('Maximum salary must be greater than minimum salary');
    }

    if (amounts.length === 1) {
        return `TZS ${formatNumberWithCommas(amounts[0])}`;
    }

    return `TZS ${formatNumberWithCommas(amounts[0])} - ${formatNumberWithCommas(amounts[1])}`;
}

function normalizeRequiredApplicants(rawValue, { required = false } = {}) {
    if (rawValue === undefined || rawValue === null || `${rawValue}`.trim() === '') {
        if (required) {
            throw new JobValidationError('Required applicants is mandatory');
        }
        return undefined;
    }

    const value = parseInt(`${rawValue}`.trim(), 10);
    if (!Number.isInteger(value) || value <= 0) {
        throw new JobValidationError('Required applicants must be a whole number greater than zero');
    }

    return value;
}

function normalizeStringArray(rawValue) {
    const values = Array.isArray(rawValue)
        ? rawValue
        : `${rawValue || ''}`
              .split(',')
              .map((item) => item.trim())
              .filter(Boolean);

    return [...new Set(values.map((item) => `${item}`.trim()).filter(Boolean))];
}

function normalizeSkillIds(rawValue) {
    if (rawValue === undefined || rawValue === null) return [];
    if (!Array.isArray(rawValue)) {
        throw new JobValidationError('Skills must be provided as an array');
    }

    return normalizeStringArray(rawValue);
}

function normalizeEligiblePrograms(rawValue) {
    if (rawValue === undefined) return undefined;
    return normalizeStringArray(rawValue);
}

function normalizeMinimumGpa(rawValue) {
    if (rawValue === undefined) return undefined;
    if (rawValue === null || `${rawValue}`.trim() === '') return null;

    const value = Number.parseFloat(`${rawValue}`.trim());
    if (Number.isNaN(value) || value < 0 || value > 5) {
        throw new JobValidationError('Minimum GPA must be a number between 0.0 and 5.0');
    }

    return Number(value.toFixed(2));
}

function normalizeMinimumAcademicYear(rawValue) {
    if (rawValue === undefined) return undefined;
    if (rawValue === null || `${rawValue}`.trim() === '') return null;

    const value = Number.parseInt(`${rawValue}`.trim(), 10);
    if (!Number.isInteger(value) || value < 1 || value > 6) {
        throw new JobValidationError('Minimum academic year must be between 1 and 6');
    }

    return value;
}

function normalizeOptionalText(rawValue) {
    if (rawValue === undefined) return undefined;
    const value = `${rawValue || ''}`.trim();
    return value ? value : null;
}

function normalizeJobText(rawValue, fieldName, { required = false } = {}) {
    if (rawValue === undefined || rawValue === null) {
        if (required) {
            throw new JobValidationError(`${fieldName} is required`);
        }
        return undefined;
    }

    const value = `${rawValue}`.trim();
    if (!value && required) {
        throw new JobValidationError(`${fieldName} is required`);
    }

    return value || null;
}

function normalizeEligibilityMatchMode(rawValue) {
    if (rawValue === undefined) return undefined;

    const value = `${rawValue || ''}`.trim().toLowerCase();
    if (!value) return 'all';

    if (!['all', 'any'].includes(value)) {
        throw new JobValidationError('Eligibility mode must be either "all" or "any"');
    }

    return value;
}

function normalizeApplicationDeadline(rawValue, { required = false } = {}) {
    if (rawValue === undefined || rawValue === null || `${rawValue}`.trim() === '') {
        if (required) {
            throw new JobValidationError('Application deadline is required');
        }
        return undefined;
    }

    const parsed = new Date(rawValue);
    if (Number.isNaN(parsed.getTime())) {
        throw new JobValidationError('Application deadline must include a valid date and time');
    }

    if (parsed <= new Date()) {
        throw new JobValidationError('Application deadline must be in the future');
    }

    return parsed.toISOString();
}

function sanitizeJobPayload(payload, { requireCoreFields = false } = {}) {
    const source = payload && typeof payload === 'object' ? payload : {};
    const sanitized = {};
    const allowedFields = [
        'title',
        'type',
        'target_candidates',
        'description',
        'location',
        'salary_range',
        'required_applicants',
        'application_deadline',
        'eligible_programs',
        'minimum_gpa',
        'minimum_academic_year',
        'eligibility_notes',
        'eligibility_match_mode',
        'status'
    ];

    for (const field of allowedFields) {
        if (source[field] !== undefined) {
            sanitized[field] = source[field];
        }
    }

    for (const [field, label] of [
        ['title', 'Job title'],
        ['type', 'Job type'],
        ['description', 'Job description'],
        ['location', 'Job location']
    ]) {
        if (source[field] !== undefined || requireCoreFields) {
            sanitized[field] = normalizeJobText(source[field], label, {
                required: true
            });
        }
    }

    if (source.target_candidates !== undefined) {
        const targetCandidates = normalizeStringArray(source.target_candidates);
        if (requireCoreFields && targetCandidates.length === 0) {
            throw new JobValidationError('Select at least one target candidate group');
        }
        sanitized.target_candidates = targetCandidates;
    }

    const normalizedSalaryRange = normalizeSalaryRange(source.salary_range);
    if (normalizedSalaryRange !== undefined) {
        sanitized.salary_range = normalizedSalaryRange;
    }

    const normalizedRequiredApplicants = normalizeRequiredApplicants(
        source.required_applicants,
        { required: requireCoreFields }
    );
    if (normalizedRequiredApplicants !== undefined) {
        sanitized.required_applicants = normalizedRequiredApplicants;
    }

    const normalizedDeadline = normalizeApplicationDeadline(
        source.application_deadline,
        { required: requireCoreFields }
    );
    if (normalizedDeadline !== undefined) {
        sanitized.application_deadline = normalizedDeadline;
    }

    const normalizedEligiblePrograms = normalizeEligiblePrograms(
        source.eligible_programs
    );
    if (normalizedEligiblePrograms !== undefined) {
        sanitized.eligible_programs = normalizedEligiblePrograms;
    }

    const normalizedMinimumGpa = normalizeMinimumGpa(source.minimum_gpa);
    if (normalizedMinimumGpa !== undefined) {
        sanitized.minimum_gpa = normalizedMinimumGpa;
    }

    const normalizedMinimumAcademicYear = normalizeMinimumAcademicYear(
        source.minimum_academic_year
    );
    if (normalizedMinimumAcademicYear !== undefined) {
        sanitized.minimum_academic_year = normalizedMinimumAcademicYear;
    }

    const normalizedEligibilityNotes = normalizeOptionalText(
        source.eligibility_notes
    );
    if (normalizedEligibilityNotes !== undefined) {
        sanitized.eligibility_notes = normalizedEligibilityNotes;
    }

    const normalizedEligibilityMatchMode = normalizeEligibilityMatchMode(
        source.eligibility_match_mode
    );
    if (normalizedEligibilityMatchMode !== undefined) {
        sanitized.eligibility_match_mode = normalizedEligibilityMatchMode;
    }

    if (source.status !== undefined) {
        const status = `${source.status}`.trim().toLowerCase();
        if (!['open', 'closed'].includes(status)) {
            throw new JobValidationError('Job status must be either "open" or "closed"');
        }
        sanitized.status = status;
    }

    return sanitized;
}

function sendJobValidationError(res, error) {
    return res.status(400).json({
        success: false,
        message: error.message || 'Invalid job data'
    });
}

// Get all training (with filters)
const getAlltraining = async (req, res) => {
    try {
        const { type, location, search, limit = 50, view = 'open' } = req.query;
        
        const filters = {
            type,
            location,
            search,
            view,
            limit: parseInt(limit)
        };
        const training = await JobModel.getAll(filters);
        
        res.json({
            success: true,
            data: training,
            count: training.length
        });
    } catch (error) {
        console.error('Get training error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch training',
            error: error.message
        });
    }
};

// Get job by ID
const getJobById = async (req, res) => {
    try {
        const { id } = req.params;
        const job = await JobModel.getById(id);
        
        if (!job) {
            return res.status(404).json({
                success: false,
                message: 'Job not found'
            });
        }
        
        res.json({
            success: true,
            data: job
        });
    } catch (error) {
        console.error('Get job error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch job',
            error: error.message
        });
    }
};

// Create job (Company only)
const createJob = async (req, res) => {
    try {
        const skillIds = normalizeSkillIds(req.body?.skills);
        const jobData = {
            ...sanitizeJobPayload(req.body, { requireCoreFields: true }),
            company_id: req.user.user_id
        };
        
        let job;
        try {
            job = await JobModel.create(jobData);

            // Add skills after the post is created. If a supplied skill is
            // invalid, remove the post again so the request remains atomic.
            for (const skillId of skillIds) {
                await JobModel.addtrainingkill(job.job_id, skillId);
            }
        } catch (error) {
            if (job?.job_id) {
                try {
                    await JobModel.delete(job.job_id);
                } catch (cleanupError) {
                    console.error('Create job cleanup error:', cleanupError);
                }
            }

            if (error?.code === '23503') {
                throw new JobValidationError('One or more selected skills are invalid');
            }
            throw error;
        }
        
        res.status(201).json({
            success: true,
            message: 'Job created successfully',
            data: job
        });
    } catch (error) {
        if (error instanceof JobValidationError) {
            return sendJobValidationError(res, error);
        }
        console.error('Create job error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to create job',
            error: error.message
        });
    }
};

// Update job
const updateJob = async (req, res) => {
    try {
        const { id } = req.params;
        const job = await JobModel.getById(id);
        
        if (!job) {
            return res.status(404).json({
                success: false,
                message: 'Job not found'
            });
        }
        
        // Check if user owns this job
        if (`${job.company_id}` !== `${req.user.user_id}` && req.user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'You do not have permission to update this job'
            });
        }
        
        const updatedJob = await JobModel.update(
            id,
            sanitizeJobPayload(req.body)
        );

        if (Array.isArray(req.body.skills)) {
            const skillIds = req.body.skills
                .map((skillId) => Number.parseInt(`${skillId}`, 10))
                .filter((skillId) => Number.isInteger(skillId));
            await JobModel.replacetrainingkills(id, skillIds);
        }
        
        res.json({
            success: true,
            message: 'Job updated successfully',
            data: updatedJob
        });
    } catch (error) {
        if (error instanceof JobValidationError) {
            return sendJobValidationError(res, error);
        }
        console.error('Update job error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to update job',
            error: error.message
        });
    }
};

// Delete job
const deleteJob = async (req, res) => {
    try {
        const { id } = req.params;
        const job = await JobModel.getById(id);
        
        if (!job) {
            return res.status(404).json({
                success: false,
                message: 'Job not found'
            });
        }
        
        // Check if user owns this job
        if (`${job.company_id}` !== `${req.user.user_id}` && req.user.role !== 'admin') {
            return res.status(403).json({
                success: false,
                message: 'You do not have permission to delete this job'
            });
        }
        
        await JobModel.delete(id);
        
        res.json({
            success: true,
            message: 'Job deleted successfully'
        });
    } catch (error) {
        console.error('Delete job error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to delete job',
            error: error.message
        });
    }
};

// Get training by company
const getCompanytraining = async (req, res) => {
    try {
        const companyId = req.user.user_id;
        const training = await JobModel.getByCompany(companyId);
        
        res.json({
            success: true,
            data: training
        });
    } catch (error) {
        console.error('Get company training error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to fetch company training',
            error: error.message
        });
    }
};

module.exports = {
    getAlltraining,
    getJobById,
    createJob,
    updateJob,
    deleteJob,
    getCompanytraining
};
