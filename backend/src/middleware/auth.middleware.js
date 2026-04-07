// src/middleware/auth.middleware.js
const jwt = require('jsonwebtoken');
const { query } = require('../config/database');

const authMiddleware = async (req, res, next) => {
    // Get token from header
    const token = req.header('Authorization')?.replace('Bearer ', '');
    
    if (!token) {
        return res.status(401).json({ 
            success: false, 
            message: 'Access denied. No token provided.' 
        });
    }
    
    try {
        // Verify token
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        const userResult = await query(
            `SELECT user_id, email, role, full_name, is_active
             FROM users
             WHERE user_id = $1
             LIMIT 1`,
            [decoded.user_id]
        );

        const currentUser = userResult.rows[0];
        if (!currentUser) {
            return res.status(401).json({
                success: false,
                message: 'User account was not found.'
            });
        }

        if (!currentUser.is_active) {
            return res.status(403).json({
                success: false,
                message: 'User blocked. Please contact IT support.'
            });
        }

        if (currentUser.role === 'company') {
            const companyResult = await query(
                `SELECT company_id
                 FROM companies
                 WHERE company_id = $1
                 LIMIT 1`,
                [currentUser.user_id]
            );

            if (companyResult.rows.length === 0) {
                await query(
                    `INSERT INTO companies (
                        company_id,
                        company_name,
                        industry,
                        company_size,
                        location,
                        description
                    ) VALUES ($1, $2, NULL, NULL, NULL, NULL)
                    ON CONFLICT (company_id) DO NOTHING`,
                    [
                        currentUser.user_id,
                        `${currentUser.full_name || currentUser.email || 'Company'}`
                            .trim()
                    ]
                );
            }
        }

        req.user = {
            ...decoded,
            user_id: currentUser.user_id,
            email: currentUser.email,
            role: currentUser.role,
            full_name: currentUser.full_name
        };
        next();
    } catch (error) {
        console.error('Auth error:', error);
        
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid token.' 
            });
        }
        
        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({ 
                success: false, 
                message: 'Token expired. Please login again.' 
            });
        }
        
        res.status(401).json({ 
            success: false, 
            message: 'Authentication failed.' 
        });
    }
};

// Role-based access control
const authorize = (...roles) => {
    return (req, res, next) => {
        if (!roles.includes(req.user.role)) {
            return res.status(403).json({ 
                success: false, 
                message: 'Access denied. You do not have permission.' 
            });
        }
        next();
    };
};

module.exports = { authMiddleware, authorize };
