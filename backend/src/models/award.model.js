const { query } = require('../config/database');

const AWARD_SELECT = `
    SELECT
        aw.*,
        u.full_name AS student_name,
        u.email AS student_email,
        c.company_name,
        c.logo_url AS company_logo_url,
        j.title AS job_title,
        s.program,
        un.name AS university_name
    FROM awards aw
    JOIN users u ON aw.student_id = u.user_id
    JOIN companies c ON aw.company_id = c.company_id
    LEFT JOIN training j ON aw.job_id = j.job_id
    LEFT JOIN students s ON aw.student_id = s.student_id
    LEFT JOIN universities un ON s.university_id = un.university_id
`;

class AwardModel {
    static async getFeaturedAward() {
        const result = await query(
            `${AWARD_SELECT}
             WHERE aw.announce_on_homepage = TRUE
             ORDER BY aw.is_student_of_month DESC, aw.created_at DESC
             LIMIT 1`
        );

        return result.rows[0] || null;
    }

    static async getCompanyHighlights(limit = 3) {
        const result = await query(
            `SELECT * FROM (
                SELECT DISTINCT ON (aw.company_id)
                    aw.award_id,
                    aw.created_at
                FROM awards aw
                WHERE aw.announce_on_homepage = TRUE
                ORDER BY aw.company_id, aw.created_at DESC
             ) latest_company_awards
             ORDER BY created_at DESC
             LIMIT $1`,
            [limit]
        );

        if (result.rows.length === 0) {
            return [];
        }

        const ids = result.rows.map((row) => row.award_id);
        const awardsResult = await query(
            `${AWARD_SELECT}
             WHERE aw.award_id = ANY($1::int[])
             ORDER BY aw.created_at DESC`,
            [ids]
        );

        return awardsResult.rows;
    }

    static async getRecentAnnouncements(limit = 6) {
        const result = await query(
            `${AWARD_SELECT}
             WHERE aw.announce_on_homepage = TRUE
             ORDER BY aw.created_at DESC
             LIMIT $1`,
            [limit]
        );

        return result.rows;
    }

    static async getLeaderboard(limit = 10) {
        const result = await query(
            `${AWARD_SELECT}
             WHERE aw.announce_on_homepage = TRUE
             ORDER BY aw.rating DESC, aw.likes_count DESC, aw.created_at DESC
             LIMIT $1`,
            [limit]
        );

        return result.rows;
    }

    static async getWallOfFame({ limit = 60 } = {}) {
        const result = await query(
            `${AWARD_SELECT}
             WHERE aw.announce_on_homepage = TRUE
             ORDER BY aw.created_at DESC
             LIMIT $1`,
            [limit]
        );

        return result.rows;
    }
}

module.exports = AwardModel;
