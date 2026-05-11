const { pool, query } = require('../config/database');
const crypto = require('crypto');
const { sendPasswordResetEmail } = require('../services/email.service');
const NotificationModel = require('../models/notification.model');
const { getAuditLogs, logAuditEvent } = require('../services/audit-log.service');

const ADMIN_APPROVED_DB_STATUSES = ['shortlisted', '', 'accepted'];

const normalizeAdminApplicationStatus = (status) => {
    const normalizedStatus = `${status || ''}`.trim().toLowerCase();

    if (ADMIN_APPROVED_DB_STATUSES.includes(normalizedStatus)) {
        return 'approved';
    }

    if (['pending', 'rejected'].includes(normalizedStatus)) {
        return normalizedStatus;
    }

    return normalizedStatus || 'pending';
};

const getAdminApplicationFilterStatuses = (status) => {
    const normalizedStatus = normalizeAdminApplicationStatus(status);

    switch (normalizedStatus) {
        case 'approved':
            return ADMIN_APPROVED_DB_STATUSES;
        case 'pending':
            return ['pending'];
        case 'rejected':
            return ['rejected'];
        default:
            return [];
    }
};

const mapAdminDecisionToDbStatus = (status) => {
    const normalizedStatus = normalizeAdminApplicationStatus(status);
    if (normalizedStatus === 'approved') {
        return 'shortlisted';
    }
    return normalizedStatus;
};

const PASSWORD_RESET_TABLE_SQL = `
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
        token_id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        used_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
`;

const ensurePasswordResetTable = async () => {
    await query(PASSWORD_RESET_TABLE_SQL);
};

const hashResetToken = (token) => {
    return crypto.createHash('sha256').update(token).digest('hex');
};

const normalizeBaseUrl = (value) => `${value || ''}`.trim().replace(/\/+$/, '');

const getRequestBaseUrl = (req) => {
    const origin = normalizeBaseUrl(req.headers.origin);
    if (origin) {
        return origin;
    }

    const forwardedProto = `${req.headers['x-forwarded-proto'] || ''}`
        .split(',')[0]
        .trim();
    const forwardedHost = `${req.headers['x-forwarded-host'] || req.headers.host || ''}`
        .split(',')[0]
        .trim();

    if (!forwardedHost) {
        return '';
    }

    const protocol =
        forwardedProto ||
        req.protocol ||
        (process.env.NODE_ENV === 'production' ? 'https' : 'http');

    return normalizeBaseUrl(`${protocol}://${forwardedHost}`);
};

const getPasswordResetBaseUrl = (req) => {
    const requestBaseUrl = getRequestBaseUrl(req);
    if (requestBaseUrl) {
        return requestBaseUrl;
    }

    const configuredBaseUrl = normalizeBaseUrl(
        process.env.RESET_PASSWORD_BASE_URL || process.env.PUBLIC_API_URL
    );
    if (configuredBaseUrl) {
        return configuredBaseUrl;
    }

    return normalizeBaseUrl(`http://localhost:${process.env.PORT || 5000}`);
};

const shouldExposeResetDebugData = () => {
    const flag = `${process.env.EXPOSE_RESET_DEBUG_LINKS || ''}`
        .trim()
        .toLowerCase();

    if (['1', 'true', 'yes', 'on'].includes(flag)) {
        return true;
    }

    return process.env.NODE_ENV !== 'production';
};

// Get all users
const getAllUsers = async (req, res) => {
    try {
        const result = await query(`
            SELECT u.user_id, u.email, u.role, u.full_name, u.phone, 
                   u.is_verified, u.is_active, u.created_at,
                   s.program, s.university_id, u2.name as university_name,
                   c.company_name, c.industry, c.location
            FROM users u
            LEFT JOIN students s ON u.user_id = s.student_id
            LEFT JOIN universities u2 ON s.university_id = u2.university_id
            LEFT JOIN companies c ON u.user_id = c.company_id
            WHERE u.role != 'admin'
            ORDER BY u.created_at DESC
        `);
        
        res.json({ success: true, data: result.rows });
    } catch (error) {
        console.error('Get users error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Get user by ID
const getUserById = async (req, res) => {
    try {
        const { id } = req.params;
        const result = await query(`
            SELECT u.*, s.program, s.university_id, u2.name as university_name,
                   c.company_name, c.industry, c.location, c.company_size
            FROM users u
            LEFT JOIN students s ON u.user_id = s.student_id
            LEFT JOIN universities u2 ON s.university_id = u2.university_id
            LEFT JOIN companies c ON u.user_id = c.company_id
            WHERE u.user_id = $1
        `, [id]);
        
        if (result.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }
        
        res.json({ success: true, data: result.rows[0] });
    } catch (error) {
        console.error('Get user error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Update user role
const updateUserRole = async (req, res) => {
    let client;
    try {
        const { id } = req.params;
        const { role } = req.body;
        const allowedRoles = new Set(['student', 'organizations', 'university', 'admin']);
 
        if (!allowedRoles.has(role)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid role selected'
            });
        }

        client = await pool.connect();
        await client.query('BEGIN');

        const result = await client.query(
            `UPDATE users
             SET role = $1,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $2
             RETURNING user_id, full_name, email, role`,
            [role, id]
        );

        if (result.rows.length === 0) {
            await client.query('ROLLBACK');
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const updatedUser = result.rows[0];

        if (role === 'company') {
            await client.query(
                `INSERT INTO companies (
                    company_id,
                    company_name,
                    industry,
                    company_size,
                    location,
                    description
                ) VALUES ($1, $2, NULL, NULL, NULL, NULL)
                ON CONFLICT (company_id) DO UPDATE
                SET company_name = COALESCE(
                    NULLIF(companies.company_name, ''),
                    EXCLUDED.company_name
                )`,
                [
                    updatedUser.user_id,
                    `${updatedUser.full_name || updatedUser.email || 'Company'}`
                        .trim(),
                ]
            );
        }

        if (role === 'student') {
            await client.query(
                `INSERT INTO students (student_id, student_type)
                 VALUES ($1, $2)
                 ON CONFLICT (student_id) DO UPDATE
                 SET student_type = EXCLUDED.student_type`,
                [updatedUser.user_id, 'current']
            );
        }

        await client.query('COMMIT');
        await logAuditEvent({
            category: 'admin_action',
            eventType: 'Role changed',
            message: `${updatedUser.full_name || updatedUser.email} role changed to ${role}`,
            actorUserId: req.user.user_id,
            actorName: req.user.email,
            userInvolved: updatedUser.user_id,
            userInvolvedName: updatedUser.full_name || updatedUser.email
        });

        res.json({
            success: true,
            message:
                'User role updated successfully. If the user is logged in, the new access will apply on the next request.',
            data: updatedUser
        });
    } catch (error) {
        if (client) {
            await client.query('ROLLBACK').catch(() => {});
        }
        console.error('Update role error:', error);
        res.status(500).json({ success: false, message: error.message });
    } finally {
        client?.release();
    }
};

// Verify user
const verifyUser = async (req, res) => {
    try {
        const { id } = req.params;
        const userResult = await query(
            `SELECT user_id, full_name, email, is_verified
             FROM users
             WHERE user_id = $1
             LIMIT 1`,
            [id]
        );

        if (userResult.rows.length === 0) {
            return res.status(404).json({ success: false, message: 'User not found' });
        }

        const user = userResult.rows[0];
        await query('UPDATE users SET is_verified = true WHERE user_id = $1', [id]);

        if (user.is_verified !== true) {
            await NotificationModel.create({
                user_id: user.user_id,
                title: 'Account verified',
                message:
                    'Your account has been verified by admin. You can continue using the app.',
                type: 'account'
            });
        }

        await logAuditEvent({
            category: 'admin_action',
            eventType: 'User verified',
            message: `${user.full_name || user.email || id} was verified`,
            actorUserId: req.user.user_id,
            actorName: req.user.email,
            userInvolved: id,
            userInvolvedName: user.full_name || user.email || id
        });
        res.json({ success: true, message: 'User verified successfully' });
    } catch (error) {
        console.error('Verify user error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Suspend user
const suspendUser = async (req, res) => {
    try {
        const { id } = req.params;
        await query(
            `UPDATE users
             SET is_active = false,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $1`,
            [id]
        );
        await logAuditEvent({
            category: 'admin_action',
            eventType: 'User blocked',
            message: `User ${id} was blocked`,
            actorUserId: req.user.user_id,
            actorName: req.user.email,
            userInvolved: id,
            userInvolvedName: id
        });
        res.json({ success: true, message: 'User suspended successfully' });
    } catch (error) {
        console.error('Suspend user error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Activate user
const activateUser = async (req, res) => {
    try {
        const { id } = req.params;
        await query(
            `UPDATE users
             SET is_active = true,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $1`,
            [id]
        );
        await logAuditEvent({
            category: 'admin_action',
            eventType: 'User unblocked',
            message: `User ${id} was activated`,
            actorUserId: req.user.user_id,
            actorName: req.user.email,
            userInvolved: id,
            userInvolvedName: id
        });
        res.json({ success: true, message: 'User activated successfully' });
    } catch (error) {
        console.error('Activate user error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Delete user
const deleteUser = async (req, res) => {
    try {
        const { id } = req.params;
        await query('DELETE FROM users WHERE user_id = $1', [id]);
        await logAuditEvent({
            category: 'admin_action',
            eventType: 'User deleted',
            message: `User ${id} was deleted`,
            actorUserId: req.user.user_id,
            actorName: req.user.email,
            userInvolved: id,
            userInvolvedName: id
        });
        res.json({ success: true, message: 'User deleted successfully' });
    } catch (error) {
        console.error('Delete user error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Get all applications (for admin)
const getAllApplications = async (req, res) => {
    try {
        const { status } = req.query;
        const values = [];
        let whereClause = '';

        if (status) {
            const filteredStatuses = getAdminApplicationFilterStatuses(status);
            if (filteredStatuses.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid application status filter'
                });
            }

            values.push(filteredStatuses);
            whereClause = 'WHERE a.status = ANY($1::text[])';
        }

        const result = await query(
            `SELECT a.application_id, a.student_id, a.job_id,
                    CASE
                        WHEN a.status = ANY($${values.length + 1}::text[]) THEN 'approved'
                        ELSE a.status
                    END AS status,
                    a.status AS workflow_status,
                    a.cover_letter,
                    a.company_feedback, a.applied_date, a.updated_date,
                    u.full_name AS user_name, u.email,
                    j.title AS job_title, s.resume_url,
                    c.company_name
             FROM applications a
             JOIN users u ON a.student_id = u.user_id
             LEFT JOIN students s ON a.student_id = s.student_id
             JOIN training j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             ${whereClause}
             ORDER BY a.applied_date DESC`,
            [...values, ADMIN_APPROVED_DB_STATUSES]
        );

        res.json({ success: true, data: result.rows });
    } catch (error) {
        console.error('Get admin applications error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Update application status (admin)
const updateAdminApplicationStatus = async (req, res) => {
    try {
        const { applicationId } = req.params;
        const { status, notify_user } = req.body;
        const allowedStatuses = new Set(['pending', 'approved', 'rejected']);
        const normalizedStatus = normalizeAdminApplicationStatus(status);

        if (!allowedStatuses.has(normalizedStatus)) {
            return res.status(400).json({
                success: false,
                message: 'Invalid application status'
            });
        }

        const dbStatus = mapAdminDecisionToDbStatus(normalizedStatus);

        const applicationDetails = await query(
            `SELECT a.application_id, a.student_id, u.full_name AS user_name, u.email,
                    j.title AS job_title, c.company_name
             FROM applications a
             JOIN users u ON a.student_id = u.user_id
             JOIN training j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             WHERE a.application_id = $1`,
            [applicationId]
        );

        if (applicationDetails.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        const result = await query(
            `UPDATE applications
             SET status = $1, updated_date = CURRENT_TIMESTAMP
             WHERE application_id = $2
             RETURNING application_id, status`,
            [dbStatus, applicationId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'Application not found'
            });
        }

        const details = applicationDetails.rows[0];

        if (notify_user === true) {
            await NotificationModel.create({
                user_id: details.student_id,
                title: normalizedStatus === 'approved'
                    ? 'Application approved'
                    : normalizedStatus === 'rejected'
                        ? 'Application rejected'
                        : 'Application updated',
                message: normalizedStatus === 'approved'
                    ? `Your application for ${details.job_title} at ${details.company_name} was approved by admin review.`
                    : normalizedStatus === 'rejected'
                        ? `Your application for ${details.job_title} at ${details.company_name} was rejected by admin review.`
                        : `Your application for ${details.job_title} was updated.`,
                type: normalizedStatus === 'approved'
                    ? 'accepted'
                    : normalizedStatus === 'rejected'
                        ? 'rejected'
                        : 'application'
            });
        }

        await logAuditEvent({
            category: 'admin_action',
            eventType: `Application ${normalizedStatus}`,
            message: `${details.user_name || 'Applicant'} application for ${details.job_title} was ${normalizedStatus}`,
            actorUserId: req.user.user_id,
            actorName: req.user.email,
            userInvolved: details.student_id,
            userInvolvedName: details.user_name || details.email
        });

        res.json({
            success: true,
            message: `Application ${normalizedStatus} successfully`,
            data: {
                ...result.rows[0],
                status: normalizedStatus,
                workflow_status: result.rows[0].status,
                notified_user: notify_user === true
            }
        });
    } catch (error) {
        console.error('Update admin application status error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Reset user password
const resetUserPassword = async (req, res) => {
    try {
        const { id } = req.params;
        await ensurePasswordResetTable();

        const userResult = await query(
            'SELECT user_id, role, full_name, email FROM users WHERE user_id = $1',
            [id]
        );

        if (userResult.rows.length === 0) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const user = userResult.rows[0];
        const allowedRoles = new Set(['student', '', 'company', 'university']);

        if (!allowedRoles.has(user.role)) {
            return res.status(403).json({
                success: false,
                message: 'Password reset is allowed only for student, company, and university accounts'
            });
        }

        if (!user.email) {
            return res.status(400).json({
                success: false,
                message: 'This account does not have a valid email address'
            });
        }

        await query(
            `UPDATE password_reset_tokens
             SET used_at = NOW()
             WHERE user_id = $1 AND used_at IS NULL`,
            [id]
        );

        const rawToken = crypto.randomBytes(32).toString('hex');
        const tokenHash = hashResetToken(rawToken);
        const expiryMinutes = Number(
            process.env.PASSWORD_RESET_TOKEN_TTL_MINUTES || 60
        );

        await query(
            `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
             VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 minute'))`,
            [id, tokenHash, expiryMinutes]
        );

        const resetLink = `${getPasswordResetBaseUrl(req)}/api/auth/reset-password?token=${rawToken}`;
        let emailResult = { skipped: true };
        try {
            emailResult = await sendPasswordResetEmail({
                to: user.email,
                userName: user.full_name,
                resetLink,
                expiryLabel: `${expiryMinutes} minute${expiryMinutes === 1 ? '' : 's'}`,
                initiatedBy: 'admin'
            });
        } catch (emailError) {
            console.error('Password reset email error:', emailError);
            return res.status(503).json({
                success: false,
                message: 'Unable to send password reset email right now.',
                ...(shouldExposeResetDebugData()
                    ? {
                        debugResetLink: resetLink,
                        debugResetToken: rawToken
                    }
                    : {})
            });
        }

        if (emailResult.skipped) {
            return res.status(503).json({
                success: false,
                message: 'Password reset email is not configured on the server.',
                ...(shouldExposeResetDebugData()
                    ? {
                        debugResetLink: resetLink,
                        debugResetToken: rawToken
                    }
                    : {})
            });
        }
        const message = `Reset link sent successfully to ${user.email}`;

        res.json({
            success: true,
            message,
            data: {
                email_sent: true,
                email: user.email,
                expires_in_minutes: expiryMinutes
            }
        });
    } catch (error) {
        console.error('Reset user password error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Get all training (for admin)
const getAlltraining = async (req, res) => {
  try {
    const result = await query(`
      SELECT j.*, c.company_name
      FROM training j
      JOIN companies c ON j.company_id = c.company_id
      ORDER BY j.created_at DESC
    `);
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get training error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// ===== NEW STUDENT ENDPOINTS =====

// Get all students for admin
const getAllAdminStudents = async (req, res) => {
  try {
    const result = await query(`
      SELECT u.user_id, u.email, u.role, u.full_name, u.phone, 
             u.is_verified, u.is_active, u.created_at,
             s.program, s.university_id, u2.name as university_name,
             s.gpa, s.expected_graduation_year
      FROM users u
      JOIN students s ON u.user_id = s.student_id
      LEFT JOIN universities u2 ON s.university_id = u2.university_id
      WHERE u.role IN ('student', '')
      ORDER BY u.created_at DESC
    `);
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get students error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Students with university (chuo)
const getStudentsWithUniversity = async (req, res) => {
  try {
    const result = await query(`
      SELECT u.user_id, u.email, u.role, u.full_name, u.phone, 
             u.is_verified, u.is_active, u.created_at,
             s.program, s.university_id, u2.name as university_name,
             s.gpa, s.expected_graduation_year
      FROM users u
      JOIN students s ON u.user_id = s.student_id
      JOIN universities u2 ON s.university_id = u2.university_id
      WHERE u.role IN ('student', '')
      ORDER BY u.created_at DESC
    `);
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get students with university error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Students with awards (zawadi) - via approved applications
const getStudentsWithAwards = async (req, res) => {
  try {
    const result = await query(`
      SELECT DISTINCT u.user_id, u.email, u.role, u.full_name, u.phone, 
             u.is_verified, u.is_active, u.created_at,
             s.program, s.university_id, u2.name as university_name,
             s.gpa, s.expected_graduation_year
      FROM users u
      JOIN students s ON u.user_id = s.student_id
      LEFT JOIN universities u2 ON s.university_id = u2.university_id
      JOIN applications a ON a.student_id = u.user_id
      WHERE u.role IN ('student', '')
        AND a.status IN ('shortlisted', '', 'accepted')
      ORDER BY u.created_at DESC
    `);
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get students with awards error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Students without field (no approved placement)
const getStudentsNoField = async (req, res) => {
  try {
    const result = await query(`
      SELECT u.user_id, u.email, u.role, u.full_name, u.phone, 
             u.is_verified, u.is_active, u.created_at,
             s.program, s.university_id, u2.name as university_name,
             s.gpa, s.expected_graduation_year
      FROM users u
      JOIN students s ON u.user_id = s.student_id
      LEFT JOIN universities u2 ON s.university_id = u2.university_id
      WHERE u.role IN ('student', '')
        AND NOT EXISTS (
          SELECT 1 FROM applications a 
          WHERE a.student_id = u.user_id 
            AND a.status IN ('shortlisted', '', 'accepted')
        )
      ORDER BY u.created_at DESC
    `);
    
    res.json({ success: true, data: result.rows });
  } catch (error) {
    console.error('Get students no field error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
};

// Delete job (admin)
const deleteJob = async (req, res) => {
    try {
        const { id } = req.params;
        await query('DELETE FROM training WHERE job_id = $1', [id]);
        res.json({ success: true, message: 'Job deleted successfully' });
    } catch (error) {
        console.error('Delete job error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Get dashboard stats
const getStats = async (req, res) => {
    try {
        const totalUsers = await query('SELECT COUNT(*) FROM users WHERE role != \'admin\'');
        const totalStudents = await query('SELECT COUNT(*) FROM users WHERE role = \'student\' OR role = \'\'');
        const totalCompanies = await query('SELECT COUNT(*) FROM users WHERE role = \'company\'');
        const totalUniversities = await query('SELECT COUNT(*) FROM users WHERE role = \'university\'');
        const totaltraining = await query('SELECT COUNT(*) FROM training');
        const totalApplications = await query('SELECT COUNT(*) FROM applications');
        const pendingApplications = await query('SELECT COUNT(*) FROM applications WHERE status = \'pending\'');
        const approvedApplications = await query(
            'SELECT COUNT(*) FROM applications WHERE status = ANY($1::text[])',
            [ADMIN_APPROVED_DB_STATUSES]
        );
        const rejectedApplications = await query('SELECT COUNT(*) FROM applications WHERE status = \'rejected\'');
        
        res.json({
            success: true,
            data: {
                total_users: parseInt(totalUsers.rows[0].count),
                total_students: parseInt(totalStudents.rows[0].count),
                total_companies: parseInt(totalCompanies.rows[0].count),
                total_universities: parseInt(totalUniversities.rows[0].count),
                total_training: parseInt(totaltraining.rows[0].count),
                total_applications: parseInt(totalApplications.rows[0].count),
                pending_applications: parseInt(pendingApplications.rows[0].count),
                approved_applications: parseInt(approvedApplications.rows[0].count),
                rejected_applications: parseInt(rejectedApplications.rows[0].count)
            }
        });
    } catch (error) {
        console.error('Get stats error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

const getLogs = async (req, res) => {
    try {
        const logs = await getAuditLogs();
        res.json({ success: true, data: logs });
    } catch (error) {
        console.error('Get logs error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = {
    getAllUsers,
    getUserById,
    updateUserRole,
    verifyUser,
    suspendUser,
    activateUser,
    deleteUser,
    resetUserPassword,
    getAllApplications,
    updateAdminApplicationStatus,
    getAlltraining,
    getAllAdminStudents,
    getStudentsWithUniversity,
    getStudentsWithAwards,
    getStudentsNoField,
    deleteJob,
    getStats,
    getLogs
};
