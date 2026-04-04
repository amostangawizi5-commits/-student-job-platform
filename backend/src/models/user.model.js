// src/models/user.model.js
const { query } = require('../config/database');
const bcrypt = require('bcryptjs');

const normalizeOptionalString = (value) => {
    if (typeof value !== 'string') {
        return value;
    }

    const trimmed = value.trim();
    return trimmed === '' ? null : trimmed;
};

const normalizeOptionalInteger = (value) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null || value === '') {
        return null;
    }

    const parsed = Number.parseInt(value, 10);
    return Number.isNaN(parsed) ? value : parsed;
};

class UserModel {
    // Create new user
    static async create(userData) {
        const { 
            email, 
            password, 
            role, 
            full_name, 
            phone,
            university_id,
            program,
            student_type,
            expected_graduation_year,
            graduation_year,
            experience_level,
            company_name,
            industry,
            company_size,
            location,
            description
        } = userData;
        const normalizedEmail = `${email || ''}`.trim().toLowerCase();

        try {
            // Hash password
            const salt = await bcrypt.genSalt(10);
            const password_hash = await bcrypt.hash(password, salt);

            // Insert into users table
            const userResult = await query(
                `INSERT INTO users (email, password_hash, role, full_name, phone)
                 VALUES ($1, $2, $3, $4, $5)
                 RETURNING user_id, email, role, full_name, created_at`,
                [normalizedEmail, password_hash, role, full_name, phone]
            );

            const userId = userResult.rows[0].user_id;

            // Insert into specific role table
            if (role === 'student' || role === 'graduate') {
                await query(
                    `INSERT INTO students (student_id, university_id, program, student_type, 
                      expected_graduation_year, graduation_year, experience_level, bio)
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
                    [userId, university_id, program, student_type, 
                     expected_graduation_year, graduation_year, experience_level, null]
                );
            } 
            else if (role === 'company') {
                await query(
                    `INSERT INTO companies (company_id, company_name, industry, company_size, location, description)
                     VALUES ($1, $2, $3, $4, $5, $6)`,
                    [userId, company_name, industry, company_size, location, description]
                );
            }
            // Admin doesn't need additional data insertion
            
            return {
                user_id: userId,
                email: normalizedEmail,
                role,
                full_name,
                created_at: userResult.rows[0].created_at
            };
            
        } catch (error) {
            throw error;
        }
    }

    // Find user by email
    static async findByEmail(email) {
        const result = await query(
            'SELECT * FROM users WHERE LOWER(email) = LOWER($1)',
            [email]
        );
        return result.rows[0];
    }

    // Find user by ID
    static async findById(userId) {
        const result = await query(
            'SELECT user_id, email, role, full_name, phone, profile_image_url, is_verified, is_active, created_at FROM users WHERE user_id = $1',
            [userId]
        );
        
        if (result.rows.length === 0) return null;
        
        const user = result.rows[0];
        
        // Get role-specific data
        if (user.role === 'student' || user.role === 'graduate') {
            const studentResult = await query(
                `SELECT s.*, u.name as university_name 
                 FROM students s 
                 LEFT JOIN universities u ON s.university_id = u.university_id 
                 WHERE s.student_id = $1`,
                [userId]
            );
            if (studentResult.rows.length > 0) {
                user.student_data = studentResult.rows[0];
            }
        } 
        else if (user.role === 'company') {
            const companyResult = await query(
                'SELECT * FROM companies WHERE company_id = $1',
                [userId]
            );
            if (companyResult.rows.length > 0) {
                user.company_data = companyResult.rows[0];
            }
        }
        // Admin doesn't have additional data
        
        return user;
    }

    // Update user profile
    static async update(userId, updateData) {
        const payload = updateData || {};
        const userResult = await query(
            'SELECT role FROM users WHERE user_id = $1 LIMIT 1',
            [userId]
        );

        if (userResult.rows.length === 0) {
            throw new Error('User not found');
        }

        const userRole = userResult.rows[0].role;
        const studentData = payload.student_data && typeof payload.student_data === 'object'
            ? { ...payload.student_data }
            : null;
        const companyData = payload.company_data && typeof payload.company_data === 'object'
            ? payload.company_data
            : null;

        const allowedUserFields = new Set([
            'full_name',
            'phone',
            'profile_image_url',
            'email'
        ]);

        const userFields = [];
        const userValues = [];
        let userIndex = 1;

        for (const [key, value] of Object.entries(payload)) {
            if (key === 'student_data') continue;
            if (!allowedUserFields.has(key)) continue;
            let normalizedValue = value;

            if (key === 'email') {
                normalizedValue = normalizeOptionalString(value)?.toLowerCase();
            } else {
                normalizedValue = normalizeOptionalString(value);
            }

            if (normalizedValue !== undefined) {
                userFields.push(`${key} = $${userIndex}`);
                userValues.push(normalizedValue);
                userIndex++;
            }
        }

        if (userFields.length > 0) {
            userValues.push(userId);
            await query(
                `UPDATE users SET ${userFields.join(', ')}, updated_at = CURRENT_TIMESTAMP 
                 WHERE user_id = $${userIndex}`,
                userValues
            );
        }

        if (studentData) {
            if (userRole === 'student' || userRole === 'graduate') {
                await query(
                    `INSERT INTO students (student_id, student_type)
                     VALUES ($1, $2)
                     ON CONFLICT (student_id) DO NOTHING`,
                    [userId, userRole === 'graduate' ? 'graduate' : 'current']
                );
            }

            if (studentData.university_id !== undefined) {
                studentData.university_id = normalizeOptionalString(studentData.university_id);
            }
            if (studentData.program !== undefined) {
                studentData.program = normalizeOptionalString(studentData.program);
            }
            if (studentData.student_type !== undefined) {
                studentData.student_type = normalizeOptionalString(studentData.student_type);
            }
            if (studentData.experience_level !== undefined) {
                studentData.experience_level = normalizeOptionalString(studentData.experience_level);
            }
            if (studentData.bio !== undefined) {
                studentData.bio = normalizeOptionalString(studentData.bio);
            }
            if (studentData.resume_url !== undefined) {
                studentData.resume_url = normalizeOptionalString(studentData.resume_url);
            }
            if (studentData.github_url !== undefined) {
                studentData.github_url = normalizeOptionalString(studentData.github_url);
            }
            if (studentData.linkedin_url !== undefined) {
                studentData.linkedin_url = normalizeOptionalString(studentData.linkedin_url);
            }
            if (studentData.expected_graduation_year !== undefined) {
                studentData.expected_graduation_year = normalizeOptionalInteger(
                    studentData.expected_graduation_year
                );
            }
            if (studentData.graduation_year !== undefined) {
                studentData.graduation_year = normalizeOptionalInteger(
                    studentData.graduation_year
                );
            }

            if (userRole === 'student') {
                studentData.student_type = 'current';
            } else if (userRole === 'graduate') {
                studentData.student_type = 'graduate';
            }

            const allowedStudentFields = new Set([
                'university_id',
                'program',
                'student_type',
                'expected_graduation_year',
                'graduation_year',
                'experience_level',
                'bio',
                'resume_url',
                'github_url',
                'linkedin_url'
            ]);

            const studentFields = [];
            const studentValues = [];
            let studentIndex = 1;

            for (const [key, value] of Object.entries(studentData)) {
                if (!allowedStudentFields.has(key)) continue;
                if (value !== undefined) {
                    studentFields.push(`${key} = $${studentIndex}`);
                    studentValues.push(value);
                    studentIndex++;
                }
            }

            if (studentFields.length > 0) {
                studentValues.push(userId);
                await query(
                    `UPDATE students SET ${studentFields.join(', ')}
                     WHERE student_id = $${studentIndex}`,
                    studentValues
                );
            }
        }

        if (companyData) {
            const allowedCompanyFields = new Set([
                'company_name',
                'industry',
                'company_size',
                'location',
                'description',
                'website_url',
                'logo_url',
                'stamp_url',
                'signature_url'
            ]);

            const companyFields = [];
            const companyValues = [];
            let companyIndex = 1;

            for (const [key, value] of Object.entries(companyData)) {
                if (!allowedCompanyFields.has(key)) continue;
                if (value !== undefined) {
                    companyFields.push(`${key} = $${companyIndex}`);
                    companyValues.push(value);
                    companyIndex++;
                }
            }

            if (companyFields.length > 0) {
                companyValues.push(userId);
                await query(
                    `UPDATE companies SET ${companyFields.join(', ')}
                     WHERE company_id = $${companyIndex}`,
                    companyValues
                );
            }
        }

        return this.findById(userId);
    }

    // Verify user
    static async verifyUser(userId) {
        const result = await query(
            'UPDATE users SET is_verified = true WHERE user_id = $1 RETURNING user_id',
            [userId]
        );
        return result.rows[0];
    }

    // Check if email exists
    static async emailExists(email) {
        const result = await query(
            'SELECT EXISTS(SELECT 1 FROM users WHERE LOWER(email) = LOWER($1))',
            [email]
        );
        return result.rows[0].exists;
    }
}

module.exports = UserModel;
