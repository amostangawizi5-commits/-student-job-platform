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

const normalizeOptionalDecimal = (value) => {
    if (value === undefined) {
        return undefined;
    }

    if (value === null || value === '') {
        return null;
    }

    const parsed = Number.parseFloat(`${value}`.trim());
    return Number.isNaN(parsed) ? value : parsed;
};

const splitFullName = (value) => {
    const normalized = `${value || ''}`.trim();
    if (!normalized) {
        return {
            first_name: '',
            second_name: ''
        };
    }

    const parts = normalized.split(/\s+/).filter(Boolean);
    return {
        first_name: parts[0] || '',
        second_name: parts.slice(1).join(' ')
    };
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
            registration_number,
            identification_card_url,
            identification_card_name,
            expected_graduation_year,
            graduation_year,
            experience_level,
            company_name,
            organization_subtype,
            government_category,
            industry,
            company_size,
            tin_number,
            brela_number,
            business_license_number,
            department,
            sector,
            location,
            description,
            college_name,
            registration_number: university_registration_number,
            college_email,
            college_phone,
            address,
            region,
            district,
            website_url,
            college_type,
            subscription_status,
            coordinator_name,
            coordinator_phone,
            coordinator_email,
            logo_url,
            logo_name
        } = userData;
            const normalizedEmail = `${email || ''}`.trim().toLowerCase();
            const normalizedRole = role === '' ? 'student' : role;
            const normalizedCompanySubtype = normalizeOptionalString(
                organization_subtype
            )?.toLowerCase().replace(/\s+/g, '_');
            const normalizedGovernmentCategory = normalizeOptionalString(
                government_category
            );
            const normalizedTinNumber = normalizeOptionalString(tin_number);
            const normalizedBrelaNumber = normalizeOptionalString(brela_number);
            const normalizedBusinessLicenseNumber = normalizeOptionalString(
                business_license_number
            );
            const normalizedDepartment = normalizeOptionalString(department);
            const normalizedSector = normalizeOptionalString(sector);
            const normalizedIndustry = normalizeOptionalString(industry);
            const normalizedCompanySize = normalizeOptionalString(company_size);
            const normalizedLocation = normalizeOptionalString(location);
            const normalizedDescription = normalizeOptionalString(description);
            const normalizedRegion = normalizeOptionalString(region);
            const normalizedDistrict = normalizeOptionalString(district);
            const isPrivateSectorOrganization =
                normalizedCompanySubtype === 'private_sector';
            const isGovernmentSectorOrganization =
                normalizedCompanySubtype === 'government_sector';

        try {
            // Hash password
            const salt = await bcrypt.genSalt(10);
            const password_hash = await bcrypt.hash(password, salt);

            // Insert into users table
            const userResult = await query(
                `INSERT INTO users (email, password_hash, role, full_name, phone)
                 VALUES ($1, $2, $3, $4, $5)
                 RETURNING user_id, email, role, full_name, created_at`,
                [normalizedEmail, password_hash, normalizedRole, full_name, phone]
            );

            const userId = userResult.rows[0].user_id;

            // Insert into specific role table
            if (normalizedRole === 'student') {
                await query(
                    `INSERT INTO students (
                        student_id,
                        university_id,
                        program,
                        student_type,
                        registration_number,
                        identification_card_url,
                        identification_card_name,
                        expected_graduation_year,
                        graduation_year,
                        experience_level,
                        bio
                    )
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)`,
                    [
                        userId,
                        university_id,
                        program,
                        student_type,
                        registration_number,
                        identification_card_url,
                        identification_card_name,
                        expected_graduation_year,
                        graduation_year,
                        experience_level,
                        null
                    ]
                );
            } 
            else if (normalizedRole === 'company') {
                await query(
                    `INSERT INTO companies (
                        company_id,
                        company_name,
                        organization_subtype,
                        government_category,
                        industry,
                        company_size,
                        tin_number,
                        brela_number,
                        business_license_number,
                        department,
                        sector,
                        location,
                        description,
                        region,
                        district
                    )
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15)`,
                    [
                        userId,
                        normalizeOptionalString(company_name),
                        normalizedCompanySubtype,
                        isGovernmentSectorOrganization
                            ? normalizedGovernmentCategory
                            : null,
                        isPrivateSectorOrganization ? normalizedIndustry : null,
                        isPrivateSectorOrganization ? normalizedCompanySize : null,
                        isPrivateSectorOrganization ? normalizedTinNumber : null,
                        isPrivateSectorOrganization ? normalizedBrelaNumber : null,
                        isPrivateSectorOrganization
                            ? normalizedBusinessLicenseNumber
                            : null,
                        isGovernmentSectorOrganization ? normalizedDepartment : null,
                        isGovernmentSectorOrganization ? normalizedSector : null,
                        normalizedLocation,
                        normalizedDescription,
                        normalizedRegion,
                        normalizedDistrict
                    ]
                );
            }
            else if (normalizedRole === 'university') {
                await query(
                    `INSERT INTO university_profiles (
                        user_id,
                        university_id,
                        college_name,
                        registration_number,
                        college_email,
                        college_phone,
                        address,
                        region,
                        district,
                        website_url,
                        college_type,
                        subscription_status,
                        coordinator_name,
                        coordinator_phone,
                        coordinator_email,
                        logo_url,
                        logo_name
                    )
                     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17)`,
                    [
                        userId,
                        university_id,
                        college_name,
                        university_registration_number,
                        college_email,
                        college_phone,
                        address,
                        region,
                        district,
                        website_url,
                        college_type,
                        subscription_status || 'trial',
                        coordinator_name,
                        coordinator_phone,
                        coordinator_email,
                        logo_url,
                        logo_name
                    ]
                );

                await query(
                    `INSERT INTO companies (
                        company_id,
                        company_name,
                        industry,
                        location,
                        description
                    )
                     VALUES ($1, $2, $3, $4, $5)`,
                    [
                        userId,
                        normalizeOptionalString(college_name) ||
                            normalizeOptionalString(full_name) ||
                            normalizedEmail,
                        'Education / Institution',
                        [district, region].filter(Boolean).join(', ') || null,
                        normalizeOptionalString(address) ||
                            'Institution practical training opportunities'
                    ]
                );
            }
            // Admin doesn't need additional data insertion
            
            return await this.findById(userId);
            
        } catch (error) {
            throw error;
        }
    }

    // Find user by email
    static async findByEmail(email) {
        const result = await query(
            `SELECT user_id, email, role, full_name, is_active, password_hash, auth_version
             FROM users
             WHERE LOWER(BTRIM(email)) = LOWER(BTRIM($1))
             LIMIT 1`,
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
        
        let user = result.rows[0];
        
        // Get role-specific data
        if (user.role === 'student' || user.role === '') {
            const studentResult = await query(
                `SELECT s.*, u.name as university_name 
                 FROM students s 
                 LEFT JOIN universities u ON s.university_id = u.university_id 
                 WHERE s.student_id = $1`,
                [userId]
            );
            if (studentResult.rows.length > 0) {
                user.student_data = {
                    ...studentResult.rows[0],
                    institution_name:
                        studentResult.rows[0].institution_name ||
                        studentResult.rows[0].university_name
                };
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
        else if (user.role === 'university') {
            const universityResult = await query(
                `SELECT up.*, uni.name AS university_name
                 FROM university_profiles up
                 LEFT JOIN universities uni ON up.university_id = uni.university_id
                 WHERE up.user_id = $1`,
                [userId]
            );
            if (universityResult.rows.length > 0) {
                user.university_data = universityResult.rows[0];
            }
        }
        // Admin doesn't have additional data
        user = {
            ...user,
            ...splitFullName(user.full_name)
        };

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
        const universityData = payload.university_data && typeof payload.university_data === 'object'
            ? payload.university_data
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
            if (userRole === 'student' || userRole === '') {
                await query(
                    `INSERT INTO students (student_id, student_type)
                     VALUES ($1, $2)
                     ON CONFLICT (student_id) DO NOTHING`,
                    [userId, userRole === '' ? '' : 'current']
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
            if (studentData.registration_number !== undefined) {
                studentData.registration_number = normalizeOptionalString(
                    studentData.registration_number
                );
            }
            if (studentData.identification_card_url !== undefined) {
                studentData.identification_card_url = normalizeOptionalString(
                    studentData.identification_card_url
                );
            }
            if (studentData.identification_card_name !== undefined) {
                studentData.identification_card_name = normalizeOptionalString(
                    studentData.identification_card_name
                );
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
            if (studentData.gpa !== undefined) {
                studentData.gpa = normalizeOptionalDecimal(studentData.gpa);
            }

            if (userRole === 'student') {
                studentData.student_type = 'current';
            } else if (userRole === '') {
                studentData.student_type = '';
            }

            const allowedStudentFields = new Set([
                'university_id',
                'program',
                'student_type',
                'expected_graduation_year',
                'graduation_year',
                'gpa',
                'experience_level',
                'bio',
                'resume_url',
                'registration_number',
                'identification_card_url',
                'identification_card_name',
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
            if (userRole === 'company') {
                const fallbackCompanyName =
                    normalizeOptionalString(companyData.company_name) ||
                    normalizeOptionalString(payload.full_name) ||
                    'Company';

                await query(
                    `INSERT INTO companies (company_id, company_name)
                     VALUES ($1, $2)
                     ON CONFLICT (company_id) DO NOTHING`,
                    [userId, fallbackCompanyName]
                );
            }

            const optionalCompanyTextFields = [
                'company_name',
                'organization_subtype',
                'government_category',
                'industry',
                'company_size',
                'tin_number',
                'brela_number',
                'business_license_number',
                'department',
                'sector',
                'location',
                'region',
                'district',
                'description',
                'website_url',
                'logo_url',
                'stamp_url',
                'signature_url'
            ];

            for (const field of optionalCompanyTextFields) {
                if (companyData[field] !== undefined) {
                    companyData[field] = normalizeOptionalString(companyData[field]);
                }
            }

            if (companyData.organization_subtype) {
                companyData.organization_subtype = companyData.organization_subtype
                    .toLowerCase()
                    .replace(/\s+/g, '_');
            }

            if (companyData.organization_subtype === 'private_sector') {
                companyData.government_category = null;
                companyData.department = null;
                companyData.sector = null;
            }

            if (companyData.organization_subtype === 'government_sector') {
                companyData.industry = null;
                companyData.company_size = null;
                companyData.tin_number = null;
                companyData.brela_number = null;
                companyData.business_license_number = null;
            }

            const allowedCompanyFields = new Set([
                'company_name',
                'organization_subtype',
                'government_category',
                'industry',
                'company_size',
                'tin_number',
                'brela_number',
                'business_license_number',
                'department',
                'sector',
                'location',
                'region',
                'district',
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

        if (universityData) {
            const normalizedUniversityData = { ...universityData };
            const optionalTextFields = [
                'university_id',
                'college_name',
                'registration_number',
                'college_email',
                'college_phone',
                'address',
                'region',
                'district',
                'website_url',
                'college_type',
                'subscription_status',
                'coordinator_name',
                'coordinator_phone',
                'coordinator_email',
                'logo_url',
                'logo_name'
            ];

            for (const field of optionalTextFields) {
                if (normalizedUniversityData[field] !== undefined) {
                    normalizedUniversityData[field] = normalizeOptionalString(
                        normalizedUniversityData[field]
                    );
                }
            }

            if (userRole === 'university') {
                await query(
                    `INSERT INTO university_profiles (
                        user_id,
                        college_name,
                        registration_number,
                        college_email,
                        college_phone,
                        address,
                        region,
                        district,
                        subscription_status,
                        coordinator_name,
                        coordinator_phone,
                        coordinator_email
                    )
                     VALUES ($1, '', '', '', '', '', '', '', 'trial', '', '', '')
                     ON CONFLICT (user_id) DO NOTHING`,
                    [userId]
                );
            }

            const allowedUniversityFields = new Set(optionalTextFields);
            const universityFields = [];
            const universityValues = [];
            let universityIndex = 1;

            for (const [key, value] of Object.entries(normalizedUniversityData)) {
                if (!allowedUniversityFields.has(key)) continue;
                if (value !== undefined) {
                    universityFields.push(`${key} = $${universityIndex}`);
                    universityValues.push(value);
                    universityIndex++;
                }
            }

            if (universityFields.length > 0) {
                universityFields.push('updated_at = CURRENT_TIMESTAMP');
                universityValues.push(userId);
                await query(
                    `UPDATE university_profiles SET ${universityFields.join(', ')}
                     WHERE user_id = $${universityIndex}`,
                    universityValues
                );
            }

            if (userRole === 'university') {
                const profileResult = await query(
                    `SELECT college_name, region, district, address, website_url, logo_url
                     FROM university_profiles
                     WHERE user_id = $1
                     LIMIT 1`,
                    [userId]
                );
                const profile = profileResult.rows[0] || {};
                const companyName =
                    normalizeOptionalString(profile.college_name) ||
                    normalizeOptionalString(payload.full_name) ||
                    'Institution';
                const location =
                    normalizeOptionalString(
                        [profile.district, profile.region]
                            .filter(Boolean)
                            .join(', ')
                    ) ||
                    normalizeOptionalString(profile.address);

                await query(
                    `INSERT INTO companies (
                        company_id,
                        company_name,
                        industry,
                        location,
                        description,
                        website_url,
                        logo_url
                    )
                     VALUES ($1, $2, $3, $4, $5, $6, $7)
                     ON CONFLICT (company_id) DO UPDATE SET
                        company_name = EXCLUDED.company_name,
                        industry = EXCLUDED.industry,
                        location = EXCLUDED.location,
                        description = EXCLUDED.description,
                        website_url = EXCLUDED.website_url,
                        logo_url = EXCLUDED.logo_url`,
                    [
                        userId,
                        companyName,
                        'Education / Institution',
                        location,
                        'Institution practical training opportunities',
                        normalizeOptionalString(profile.website_url),
                        normalizeOptionalString(profile.logo_url)
                    ]
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
            `SELECT EXISTS(
                SELECT 1
                FROM users
                WHERE LOWER(BTRIM(email)) = LOWER(BTRIM($1))
            )`,
            [email]
        );
        return result.rows[0].exists;
    }
}

module.exports = UserModel;
