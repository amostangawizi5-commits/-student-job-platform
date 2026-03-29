// src/controllers/auth.controller.js
const UserModel = require('../models/user.model');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const {
    sendPasswordResetEmail,
    sendPasswordChangedEmail
} = require('../services/email.service');
const { logAuditEvent } = require('../services/audit-log.service');

// Generate JWT Token
const generateToken = (userId, email, role) => {
    return jwt.sign(
        { user_id: userId, email, role },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
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

const getPasswordResetBaseUrl = () => {
    const candidate =
        process.env.RESET_PASSWORD_BASE_URL ||
        process.env.PUBLIC_API_URL ||
        `http://localhost:${process.env.PORT || 5000}`;

    return `${candidate}`.trim().replace(/\/+$/, '');
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

const prefersJsonResponse = (req) => {
    const contentType = `${req.headers['content-type'] || ''}`.toLowerCase();
    const accept = `${req.headers.accept || ''}`.toLowerCase();
    return contentType.includes('application/json') || accept.includes('application/json');
};

const sendResetResponse = (
    req,
    res,
    {
        statusCode = 200,
        success,
        title,
        subtitle,
        token = '',
        isSuccess = false
    }
) => {
    if (prefersJsonResponse(req)) {
        return res.status(statusCode).json({
            success,
            title,
            message: subtitle
        });
    }

    return res.status(statusCode).send(
        renderResetPasswordPage({
            title,
            subtitle,
            token,
            isSuccess
        })
    );
};

const renderResetPasswordPage = ({
    title,
    subtitle,
    token = '',
    isSuccess = false
}) => {
    const primaryBlue = '#1e3a8a';
    const primaryDark = '#0f172a';
    const accentGold = '#fbbf24';
    const statusColor = isSuccess ? '#059669' : primaryBlue;
    const buttonMarkup = isSuccess
        ? ''
        : `
            <form method="POST" action="/api/auth/reset-password" onsubmit="handleResetSubmit(event)" style="display: grid; gap: 16px;">
                <input type="hidden" name="token" value="${token}">
                <label style="display: grid; gap: 6px; font-weight: 600; color: #1f2937;">
                    New password
                    <div style="display: flex; align-items: center; border: 1px solid #cbd5e1; border-radius: 12px; background: #fff; overflow: hidden;">
                        <input
                            id="password"
                            type="password"
                            name="password"
                            minlength="6"
                            required
                            style="flex: 1; padding: 14px 16px; border: none; outline: none; font-size: 14px;"
                        >
                        <button
                            type="button"
                            onclick="togglePassword('password', this)"
                            style="border: none; border-left: 1px solid #e5e7eb; background: #eff6ff; color: ${primaryBlue}; padding: 14px 16px; font-weight: 700; cursor: pointer;"
                        >
                            Show
                        </button>
                    </div>
                </label>
                <label style="display: grid; gap: 6px; font-weight: 600; color: #1f2937;">
                    Confirm password
                    <div style="display: flex; align-items: center; border: 1px solid #cbd5e1; border-radius: 12px; background: #fff; overflow: hidden;">
                        <input
                            id="confirmPassword"
                            type="password"
                            name="confirmPassword"
                            minlength="6"
                            required
                            style="flex: 1; padding: 14px 16px; border: none; outline: none; font-size: 14px;"
                        >
                        <button
                            type="button"
                            onclick="togglePassword('confirmPassword', this)"
                            style="border: none; border-left: 1px solid #e5e7eb; background: #eff6ff; color: ${primaryBlue}; padding: 14px 16px; font-weight: 700; cursor: pointer;"
                        >
                            Show
                        </button>
                    </div>
                </label>
                <button
                    id="reset-submit-button"
                    type="submit"
                    style="padding: 14px 16px; border: none; border-radius: 12px; background: linear-gradient(135deg, ${primaryBlue}, ${primaryDark}); color: #fff; font-weight: 700; cursor: pointer; letter-spacing: 0.02em;"
                >
                    Reset password
                </button>
                <p id="reset-submit-status" style="display: none; margin: 0; color: #475569; font-size: 13px;">
                    Updating your password...
                </p>
            </form>
        `;

    return `
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Reset Password</title>
        </head>
        <body style="margin: 0; font-family: Arial, sans-serif; background: linear-gradient(180deg, #eaf1ff 0%, #f8fafc 45%, #eef2ff 100%); color: #0f172a;">
            <div style="min-height: 100vh; display: grid; place-items: center; padding: 24px;">
                <div style="width: 100%; max-width: 440px; background: white; border-radius: 24px; box-shadow: 0 24px 60px rgba(15, 23, 42, 0.16); overflow: hidden; border: 1px solid rgba(30, 58, 138, 0.08);">
                    <div style="padding: 24px 28px; background: linear-gradient(135deg, ${primaryBlue}, ${primaryDark}); color: white;">
                        <div style="display: inline-flex; align-items: center; gap: 12px;">
                            <div style="width: 52px; height: 52px; border-radius: 16px; background: rgba(251, 191, 36, 0.18); color: ${accentGold}; display: grid; place-items: center; font-size: 18px; font-weight: 800;">
                                IGS
                            </div>
                            <div>
                                <div style="font-size: 13px; letter-spacing: 0.08em; text-transform: uppercase; color: rgba(255,255,255,0.75);">Student Job Platform</div>
                                <div style="font-size: 22px; font-weight: 700; margin-top: 4px;">${title}</div>
                            </div>
                        </div>
                    </div>
                    <div style="padding: 28px;">
                        <div style="width: 56px; height: 56px; border-radius: 18px; background: rgba(30, 58, 138, 0.1); color: ${statusColor}; display: grid; place-items: center; font-size: 24px; font-weight: 700; margin-bottom: 18px;">
                            ${isSuccess ? '✓' : '🔒'}
                        </div>
                        <p style="margin: 0 0 22px; color: #475569; line-height: 1.7;">${subtitle}</p>
                        ${!isSuccess ? '<p style="margin: 0 0 18px; color: #64748b; font-size: 13px;">Use at least 6 characters. You can tap Show to confirm what you typed.</p>' : ''}
                        ${buttonMarkup}
                    </div>
                </div>
            </div>
            <script>
                function togglePassword(id, button) {
                    var input = document.getElementById(id);
                    if (!input) return;
                    var show = input.type === 'password';
                    input.type = show ? 'text' : 'password';
                    button.textContent = show ? 'Hide' : 'Show';
                }

                function handleResetSubmit(event) {
                    var form = event.target;
                    if (!form || typeof form.checkValidity !== 'function') {
                        return true;
                    }

                    if (!form.checkValidity()) {
                        return true;
                    }

                    var button = document.getElementById('reset-submit-button');
                    var status = document.getElementById('reset-submit-status');
                    if (button) {
                        button.disabled = true;
                        button.textContent = 'Updating...';
                        button.style.opacity = '0.8';
                        button.style.cursor = 'progress';
                    }
                    if (status) {
                        status.style.display = 'block';
                    }
                    return true;
                }
            </script>
        </body>
        </html>
    `;
};

// Register User
const register = async (req, res) => {
    try {
        const userData = req.body;
        const allowedRoles = new Set(['student', 'graduate', 'company']);

        if (!allowedRoles.has(userData.role)) {
            return res.status(403).json({
                success: false,
                message: 'This account type cannot be registered from the app'
            });
        }
        
        // Check if email already exists
        const emailExists = await UserModel.emailExists(userData.email);
        if (emailExists) {
            return res.status(400).json({ 
                success: false, 
                message: 'Email already registered' 
            });
        }
        
        // Create user
        const newUser = await UserModel.create(userData);
        
        // Generate token
        const token = generateToken(newUser.user_id, newUser.email, newUser.role);
        
        res.status(201).json({
            success: true,
            message: 'Registration successful',
            data: {
                user: newUser,
                token
            }
        });
        
    } catch (error) {
        console.error('Registration error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Registration failed', 
            error: error.message 
        });
    }
};

// Login User
const login = async (req, res) => {
    try {
        const { email, password } = req.body;
        
        // Find user by email
        const user = await UserModel.findByEmail(email);
        if (!user) {
            await logAuditEvent({
                category: 'error',
                eventType: 'Login failed',
                message: `Failed login attempt for ${email || 'unknown email'}`
            });
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
        
        // Check if account is active
        if (!user.is_active) {
            await logAuditEvent({
                category: 'error',
                eventType: 'Login blocked',
                message: `Blocked login attempt for ${user.full_name || user.email}`,
                userInvolved: user.user_id,
                userInvolvedName: user.full_name || user.email
            });
            return res.status(403).json({ 
                success: false, 
                message: 'Account is deactivated. Please contact support.' 
            });
        }
        
        // Verify password
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);
        if (!isPasswordValid) {
            await logAuditEvent({
                category: 'error',
                eventType: 'Login failed',
                message: `Incorrect password attempt for ${user.email}`,
                userInvolved: user.user_id,
                userInvolvedName: user.full_name || user.email
            });
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
        
        // Generate token
        const token = generateToken(user.user_id, user.email, user.role);
        
        // Get full profile
        const userProfile = await UserModel.findById(user.user_id);

        await logAuditEvent({
            category: 'login',
            eventType: 'User login',
            message: `${userProfile.full_name || user.email} signed in as ${userProfile.role}`,
            actorUserId: user.user_id,
            actorName: userProfile.full_name || user.email,
            userInvolved: user.user_id,
            userInvolvedName: userProfile.full_name || user.email
        });
        
        res.json({
            success: true,
            message: 'Login successful',
            data: {
                user: userProfile,
                token
            }
        });
        
    } catch (error) {
        console.error('Login error:', error);
        await logAuditEvent({
            category: 'error',
            eventType: 'System error',
            message: `Login controller error: ${error.message}`
        });
        res.status(500).json({ 
            success: false, 
            message: 'Login failed', 
            error: error.message 
        });
    }
};

// Get Current User Profile
const getProfile = async (req, res) => {
    try {
        const userId = req.user.user_id; // from auth middleware
        const user = await UserModel.findById(userId);
        
        if (!user) {
            return res.status(404).json({ 
                success: false, 
                message: 'User not found' 
            });
        }
        
        res.json({
            success: true,
            data: user
        });
        
    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to get profile', 
            error: error.message 
        });
    }
};

// Update Profile
const updateProfile = async (req, res) => {
    try {
        const userId = req.user.user_id;
        const updateData = req.body;
        
        const updatedUser = await UserModel.update(userId, updateData);
        
        res.json({
            success: true,
            message: 'Profile updated successfully',
            data: updatedUser
        });
        
    } catch (error) {
        console.error('Update profile error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to update profile', 
            error: error.message 
        });
    }
};

// Get All Universities (for registration dropdown)
const getUniversities = async (req, res) => {
    try {
        const { query } = require('../config/database');
        const result = await query('SELECT university_id, name, location FROM universities ORDER BY name');
        
        res.json({
            success: true,
            data: result.rows
        });
        
    } catch (error) {
        console.error('Get universities error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to get universities', 
            error: error.message 
        });
    }
};

// Get All Skills (for registration dropdown)
const getSkills = async (req, res) => {
    try {
        const { query } = require('../config/database');
        const result = await query('SELECT skill_id, name, category FROM skills ORDER BY name');
        
        res.json({
            success: true,
            data: result.rows
        });
        
    } catch (error) {
        console.error('Get skills error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to get skills', 
            error: error.message 
        });
    }
};

const forgotPassword = async (req, res) => {
    try {
        await ensurePasswordResetTable();
        const email = `${req.body?.email || ''}`.trim().toLowerCase();
        const genericMessage =
            'If an account with that email exists, a reset link has been sent.';

        if (!email || !email.includes('@')) {
            return res.status(400).json({
                success: false,
                message: 'Please enter a valid email address'
            });
        }

        const userResult = await query(
            `SELECT user_id, full_name, email, is_active
             FROM users
             WHERE LOWER(email) = $1
             LIMIT 1`,
            [email]
        );

        if (userResult.rows.length === 0) {
            return res.json({
                success: true,
                message: genericMessage
            });
        }

        const user = userResult.rows[0];
        if (!user.is_active) {
            return res.json({
                success: true,
                message: genericMessage
            });
        }

        await query(
            `UPDATE password_reset_tokens
             SET used_at = NOW()
             WHERE user_id = $1 AND used_at IS NULL`,
            [user.user_id]
        );

        const rawToken = crypto.randomBytes(32).toString('hex');
        const tokenHash = hashResetToken(rawToken);
        const expiryMinutes = Number(
            process.env.PASSWORD_RESET_TOKEN_TTL_MINUTES || 60
        );

        await query(
            `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
             VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 minute'))`,
            [user.user_id, tokenHash, expiryMinutes]
        );

        const resetLink = `${getPasswordResetBaseUrl()}/api/auth/reset-password?token=${rawToken}`;

        try {
            await sendPasswordResetEmail({
                to: user.email,
                userName: user.full_name,
                resetLink,
                expiryLabel: `${expiryMinutes} minute${expiryMinutes === 1 ? '' : 's'}`,
                initiatedBy: 'user'
            });
        } catch (emailError) {
            console.error('Forgot password email error:', emailError);
        }

        const responseBody = {
            success: true,
            message: genericMessage
        };

        if (shouldExposeResetDebugData()) {
            responseBody.debugResetLink = resetLink;
            responseBody.debugResetToken = rawToken;
        }

        return res.json(responseBody);
    } catch (error) {
        console.error('Forgot password error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to process forgot password request'
        });
    }
};

const renderPasswordResetForm = async (req, res) => {
    try {
        await ensurePasswordResetTable();
        const { token } = req.query;

        if (!token) {
            return res.status(400).send(
                renderResetPasswordPage({
                    title: 'Invalid reset link',
                    subtitle: 'This password reset link is missing a token.'
                })
            );
        }

        const tokenHash = hashResetToken(`${token}`);
        const result = await query(
            `SELECT token_id
             FROM password_reset_tokens
             WHERE token_hash = $1
               AND used_at IS NULL
               AND expires_at > NOW()
             LIMIT 1`,
            [tokenHash]
        );

        if (result.rows.length === 0) {
            return res.status(400).send(
                renderResetPasswordPage({
                    title: 'Reset link expired',
                    subtitle: 'This reset link is invalid or has already expired.'
                })
            );
        }

        return res.send(
            renderResetPasswordPage({
                title: 'Create a new password',
                subtitle: 'Enter your new password below to finish resetting your account.',
                token: `${token}`
            })
        );
    } catch (error) {
        console.error('Render password reset form error:', error);
        return res.status(500).send(
            renderResetPasswordPage({
                title: 'Reset unavailable',
                subtitle: 'Something went wrong while loading the reset page.'
            })
        );
    }
};

const completePasswordReset = async (req, res) => {
    try {
        await ensurePasswordResetTable();
        const { token, password, confirmPassword } = req.body;

        if (!token) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Invalid reset request',
                subtitle: 'The reset token is missing.'
            });
        }

        if (!password || `${password}`.trim().length < 6) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Password too short',
                subtitle: 'Your new password must be at least 6 characters long.',
                token: `${token}`
            });
        }

        if (`${password}` !== `${confirmPassword}`) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Passwords do not match',
                subtitle: 'Please enter the same password in both fields.',
                token: `${token}`
            });
        }

        const tokenHash = hashResetToken(`${token}`);
        const tokenResult = await query(
            `SELECT token_id, user_id
             FROM password_reset_tokens
             WHERE token_hash = $1
               AND used_at IS NULL
               AND expires_at > NOW()
             LIMIT 1`,
            [tokenHash]
        );

        if (tokenResult.rows.length === 0) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Reset link expired',
                subtitle: 'This reset link is invalid or has already expired.'
            });
        }

        const tokenRow = tokenResult.rows[0];
        const userResult = await query(
            `SELECT email, full_name
             FROM users
             WHERE user_id = $1
             LIMIT 1`,
            [tokenRow.user_id]
        );
        const user = userResult.rows[0];
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(`${password}`.trim(), salt);

        await query('UPDATE users SET password_hash = $1 WHERE user_id = $2', [
            passwordHash,
            tokenRow.user_id
        ]);

        await query(
            'UPDATE password_reset_tokens SET used_at = NOW() WHERE token_id = $1',
            [tokenRow.token_id]
        );

        let passwordChangedEmailSent = false;
        try {
            const emailResult = await sendPasswordChangedEmail({
                to: user?.email,
                userName: user?.full_name
            });
            passwordChangedEmailSent = emailResult?.skipped != true;
        } catch (emailError) {
            console.error('Password changed email error:', emailError);
        }

        return sendResetResponse(req, res, {
            success: true,
            title: 'Password updated',
            subtitle: passwordChangedEmailSent
                ? 'Your password has been reset successfully. Check your email for a confirmation message, then return to the app and log in.'
                : 'Your password has been reset successfully. You can now return to the app and log in.',
            isSuccess: true
        });
    } catch (error) {
        console.error('Complete password reset error:', error);
        return sendResetResponse(req, res, {
            statusCode: 500,
            success: false,
            title: 'Reset failed',
            subtitle: 'Something went wrong while resetting your password.'
        });
    }
};

module.exports = {
    register,
    login,
    getProfile,
    updateProfile,
    getUniversities,
    getSkills,
    forgotPassword,
    renderPasswordResetForm,
    completePasswordReset
};
