const { query } = require('../config/database');

const normalizeText = (value) =>
    `${value || ''}`
        .trim()
        .replace(/\s+/g, ' ')
        .toLowerCase();

const getUniversityScope = async (userId) => {
    const profileResult = await query(
        `SELECT
            up.college_name,
            up.university_id,
            matched.university_id AS resolved_university_id,
            matched.name AS resolved_university_name
         FROM university_profiles up
         LEFT JOIN LATERAL (
            SELECT university_id, name
            FROM universities
            WHERE university_id = up.university_id
               OR (
                    up.university_id IS NULL
                    AND LOWER(TRIM(COALESCE(name, ''))) = LOWER(TRIM(COALESCE(up.college_name, '')))
               )
            ORDER BY CASE WHEN university_id = up.university_id THEN 0 ELSE 1 END
            LIMIT 1
         ) matched ON true
         WHERE up.user_id = $1
         LIMIT 1`,
        [userId]
    );

    const profile = profileResult.rows[0];
    const universityName = `${profile?.resolved_university_name || profile?.college_name || ''}`.trim();
    const universityId = profile?.university_id || profile?.resolved_university_id || null;

    return {
        collegeName: `${profile?.college_name || ''}`.trim(),
        universityName,
        universityId,
        universityIdText: universityId == null ? '' : `${universityId}`.trim()
    };
};

const getUniversityStudentsOverview = async (req, res) => {
    try {
        const scope = await getUniversityScope(req.user.user_id);
        const collegeName = scope.universityName || scope.collegeName;

        if (!collegeName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const result = await query(
            `SELECT
                u.user_id,
                u.email,
                u.role,
                u.full_name,
                u.phone,
                u.is_verified,
                u.is_active,
                u.created_at,
                s.program,
                s.university_id,
                s.registration_number,
                uni.name AS university_name,
                s.gpa,
                s.expected_graduation_year
             FROM users u
             JOIN students s ON u.user_id = s.student_id
             LEFT JOIN universities uni ON s.university_id = uni.university_id
             WHERE u.role IN ('student', '')
               AND (
                    ($1 <> '' AND s.university_id::text = $1)
                    OR (
                        $1 = ''
                        AND LOWER(TRIM(COALESCE(uni.name, ''))) = LOWER(TRIM($2))
                    )
               )
             ORDER BY
                LOWER(COALESCE(NULLIF(u.full_name, ''), u.email)),
                u.created_at DESC`,
            [scope.universityIdText, collegeName]
        );

        return res.json({
            success: true,
            data: {
                university_id: scope.universityId,
                university_name: collegeName,
                students: result.rows,
            }
        });
    } catch (error) {
        console.error('Get university students overview error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load university students.'
        });
    }
};

const getUniversityPlacedStudents = async (req, res) => {
    try {
        const scope = await getUniversityScope(req.user.user_id);
        const collegeName = scope.universityName || scope.collegeName;

        if (!collegeName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const result = await query(
            `SELECT DISTINCT ON (a.student_id)
                a.application_id,
                a.student_id,
                a.status,
                a.applied_date,
                a.updated_date,
                a.response_letter_sent_at,
                u.full_name AS student_name,
                u.email,
                u.phone,
                s.registration_number,
                s.program,
                s.university_id,
                COALESCE(uni.name, $2) AS university_name,
                c.company_name,
                j.title,
                c.location AS placement_location
             FROM applications a
             JOIN students s ON a.student_id = s.student_id
             JOIN users u ON a.student_id = u.user_id
             JOIN training j ON a.job_id = j.job_id
             JOIN companies c ON j.company_id = c.company_id
             LEFT JOIN universities uni ON s.university_id = uni.university_id
             WHERE u.role IN ('student', '')
               AND a.status = 'accepted'
               AND (
                    ($1 <> '' AND s.university_id::text = $1)
                    OR (
                        $1 = ''
                        AND LOWER(TRIM(COALESCE(uni.name, ''))) = LOWER(TRIM($2))
                    )
               )
             ORDER BY
                a.student_id,
                COALESCE(a.updated_date, a.response_letter_sent_at, a.applied_date) DESC`,
            [scope.universityIdText, collegeName]
        );

        return res.json({
            success: true,
            data: {
                university_id: scope.universityId,
                university_name: collegeName,
                placements: result.rows
            }
        });
    } catch (error) {
        console.error('Get university placed students error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load placed students.'
        });
    }
};

const getUniversityCompanyContacts = async (req, res) => {
    try {
        const result = await query(
            `SELECT
                c.company_id,
                c.company_name,
                c.industry,
                c.location,
                c.website_url,
                c.description,
                c.logo_url,
                u.email,
                u.phone
             FROM companies c
             JOIN users u ON c.company_id = u.user_id
             WHERE u.role = 'company'
               AND COALESCE(u.is_active, true) = true
             ORDER BY LOWER(COALESCE(NULLIF(c.company_name, ''), u.email))`
        );

        return res.json({
            success: true,
            data: result.rows,
        });
    } catch (error) {
        console.error('Get university company contacts error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load company contacts.'
        });
    }
};

module.exports = {
    getUniversityStudentsOverview,
    getUniversityPlacedStudents,
    getUniversityCompanyContacts,
};
