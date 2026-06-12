const { query } = require('../config/database');
const NotificationModel = require('../models/notification.model');

const normalizeText = (value) =>
    `${value || ''}`
        .trim()
        .replace(/\s+/g, ' ')
        .toLowerCase();

const getUniversityScope = async (userId) => {
    const profileResult = await query(
        `SELECT
            up.user_id,
            up.college_name,
            up.coordinator_name,
            up.coordinator_phone,
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
        userId,
        collegeName: `${profile?.college_name || ''}`.trim(),
        universityName,
        universityId,
        universityIdText: universityId == null ? '' : `${universityId}`.trim(),
        coordinatorName: `${profile?.coordinator_name || ''}`.trim(),
        coordinatorPhone: `${profile?.coordinator_phone || ''}`.trim()
    };
};

const getCompanyScope = async (userId) => {
    const result = await query(
        `SELECT
            c.company_id AS company_user_id,
            c.company_name,
            u.phone,
            u.full_name
         FROM companies c
         JOIN users u ON u.user_id = c.company_id
         WHERE c.company_id = $1
         LIMIT 1`,
        [userId]
    );

    const company = result.rows[0];
    if (!company) {
        return {
            userId,
            companyName: '',
            phone: ''
        };
    }

    return {
        userId,
        companyName:
            `${company.company_name || company.full_name || ''}`.trim(),
        phone: `${company.phone || ''}`.trim()
    };
};

const COMPANY_CHAT_EXCLUDED_CONFIRMATION_STATUSES = [
    'expired',
    'confirmed_elsewhere'
];

const getCompanyConversationList = async (companyUserId) => {
    const result = await query(
        `WITH eligible_universities AS (
            SELECT DISTINCT up.user_id AS university_user_id
            FROM applications a
            JOIN training t ON t.job_id = a.job_id
            JOIN students s ON s.student_id = a.student_id
            LEFT JOIN universities uni ON uni.university_id = s.university_id
            JOIN university_profiles up
              ON (
                    (up.university_id IS NOT NULL AND s.university_id IS NOT NULL AND up.university_id = s.university_id)
                    OR (
                        LOWER(TRIM(COALESCE(up.college_name, ''))) = LOWER(TRIM(COALESCE(uni.name, '')))
                    )
                    OR EXISTS (
                        SELECT 1
                        FROM universities profile_uni
                        WHERE profile_uni.university_id = up.university_id
                          AND LOWER(TRIM(COALESCE(profile_uni.name, ''))) = LOWER(TRIM(COALESCE(uni.name, '')))
                    )
                 )
            WHERE t.company_id = $1
              AND a.status = 'accepted'
              AND COALESCE(NULLIF(TRIM(a.student_confirmation_status), ''), 'pending') <> ALL($2::text[])
         ),
         latest_messages AS (
            SELECT DISTINCT ON (m.university_user_id)
                m.university_user_id,
                m.message AS latest_message,
                m.created_at AS latest_message_at,
                m.sender_role AS latest_sender_role
            FROM university_organization_messages m
            WHERE m.company_user_id = $1
              AND m.deleted_for_company_at IS NULL
              AND m.university_user_id IN (
                    SELECT university_user_id FROM eligible_universities
                )
            ORDER BY m.university_user_id, m.created_at DESC
         ),
         unread_counts AS (
            SELECT
                m.university_user_id,
                COUNT(*)::int AS unread_count
            FROM university_organization_messages m
            WHERE m.company_user_id = $1
              AND m.sender_role = 'university'
              AND m.deleted_for_company_at IS NULL
              AND m.read_at IS NULL
              AND m.university_user_id IN (
                    SELECT university_user_id FROM eligible_universities
                )
            GROUP BY m.university_user_id
         )
         SELECT
            c.university_user_id,
            COALESCE(NULLIF(TRIM(up.college_name), ''), NULLIF(TRIM(u.full_name), ''), 'University') AS university_name,
            COALESCE(NULLIF(TRIM(up.coordinator_name), ''), NULLIF(TRIM(u.full_name), ''), 'University') AS coordinator_name,
            COALESCE(NULLIF(TRIM(up.coordinator_phone), ''), NULLIF(TRIM(u.phone), '')) AS coordinator_phone,
            lm.latest_message,
            lm.latest_message_at,
            lm.latest_sender_role,
            COALESCE(uc.unread_count, 0) AS unread_count
         FROM eligible_universities c
         JOIN users u ON u.user_id = c.university_user_id
         LEFT JOIN university_profiles up ON up.user_id = c.university_user_id
         LEFT JOIN latest_messages lm ON lm.university_user_id = c.university_user_id
         LEFT JOIN unread_counts uc ON uc.university_user_id = c.university_user_id
         ORDER BY
            COALESCE(lm.latest_message_at, u.created_at) DESC,
            university_name ASC`,
        [companyUserId, COMPANY_CHAT_EXCLUDED_CONFIRMATION_STATUSES]
    );

    return result.rows;
};

const canCompanyChatWithUniversity = async ({
    companyUserId,
    universityUserId
}) => {
    const result = await query(
        `SELECT 1
         FROM applications a
         JOIN training t ON t.job_id = a.job_id
         JOIN students s ON s.student_id = a.student_id
         LEFT JOIN universities uni ON uni.university_id = s.university_id
         JOIN university_profiles up ON up.user_id = $2
         LEFT JOIN universities profile_uni ON profile_uni.university_id = up.university_id
         WHERE t.company_id = $1
           AND a.status = 'accepted'
           AND COALESCE(NULLIF(TRIM(a.student_confirmation_status), ''), 'pending') <> ALL($3::text[])
           AND (
                (up.university_id IS NOT NULL AND s.university_id IS NOT NULL AND up.university_id = s.university_id)
                OR LOWER(TRIM(COALESCE(profile_uni.name, up.college_name, ''))) =
                   LOWER(TRIM(COALESCE(uni.name, '')))
           )
         LIMIT 1`,
        [
            companyUserId,
            universityUserId,
            COMPANY_CHAT_EXCLUDED_CONFIRMATION_STATUSES
        ]
    );

    return result.rows.length > 0;
};

const getUniversityConversationList = async (scope) => {
    const universityName = scope.universityName || scope.collegeName;
    const result = await query(
        `WITH chat_companies AS (
            SELECT DISTINCT m.company_user_id
            FROM university_organization_messages m
            WHERE m.university_user_id = $1
         ),
         application_companies AS (
            SELECT DISTINCT c.company_id AS company_user_id
            FROM applications a
            JOIN students s ON s.student_id = a.student_id
            JOIN training t ON t.job_id = a.job_id
            JOIN companies c ON c.company_id = t.company_id
            LEFT JOIN universities uni ON uni.university_id = s.university_id
            WHERE (
                ($2 <> '' AND s.university_id::text = $2)
                OR LOWER(TRIM(COALESCE(uni.name, ''))) = LOWER(TRIM($3))
            )
         ),
         candidates AS (
            SELECT company_user_id FROM chat_companies
            UNION
            SELECT company_user_id FROM application_companies
         ),
         latest_messages AS (
            SELECT DISTINCT ON (m.company_user_id)
                m.company_user_id,
                m.message AS latest_message,
                m.created_at AS latest_message_at,
                m.sender_role AS latest_sender_role
            FROM university_organization_messages m
            WHERE m.university_user_id = $1
              AND m.deleted_for_university_at IS NULL
            ORDER BY m.company_user_id, m.created_at DESC
         ),
         unread_counts AS (
            SELECT
                m.company_user_id,
                COUNT(*)::int AS unread_count
            FROM university_organization_messages m
            WHERE m.university_user_id = $1
              AND m.sender_role IN ('organization', 'company')
              AND m.deleted_for_university_at IS NULL
              AND m.read_at IS NULL
            GROUP BY m.company_user_id
         )
         SELECT
            c.company_user_id,
            COALESCE(NULLIF(TRIM(comp.company_name), ''), NULLIF(TRIM(u.full_name), ''), 'Organization') AS company_name,
            COALESCE(NULLIF(TRIM(u.phone), '')) AS phone,
            lm.latest_message,
            lm.latest_message_at,
            lm.latest_sender_role,
            COALESCE(uc.unread_count, 0) AS unread_count
         FROM candidates c
         JOIN users u ON u.user_id = c.company_user_id
         LEFT JOIN companies comp ON comp.company_id = c.company_user_id
         LEFT JOIN latest_messages lm ON lm.company_user_id = c.company_user_id
         LEFT JOIN unread_counts uc ON uc.company_user_id = c.company_user_id
         ORDER BY
            COALESCE(lm.latest_message_at, u.created_at) DESC,
            company_name ASC`,
        [scope.userId, scope.universityIdText, universityName]
    );

    return result.rows;
};

const markConversationRead = async ({
    recipientRole,
    companyUserId,
    universityUserId,
    readerUserId
}) => {
    const senderRoleCondition =
        recipientRole === 'company'
            ? `m.sender_role = 'university'`
            : `m.sender_role IN ('organization', 'company')`;

    await query(
        `UPDATE university_organization_messages m
         SET read_at = CURRENT_TIMESTAMP,
             read_by_user_id = $3
         WHERE m.company_user_id = $1
           AND m.university_user_id = $2
           AND ${senderRoleCondition}
           AND ${
               recipientRole === 'company'
                   ? 'm.deleted_for_company_at IS NULL'
                   : 'm.deleted_for_university_at IS NULL'
           }
           AND m.read_at IS NULL`,
        [companyUserId, universityUserId, readerUserId]
    );
};

const getCompanyUniversityChats = async (req, res) => {
    try {
        const scope = await getCompanyScope(req.user.user_id);
        if (!scope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Company profile not found for this account.'
            });
        }

        const conversations = await getCompanyConversationList(req.user.user_id);
        return res.json({
            success: true,
            data: conversations
        });
    } catch (error) {
        console.error('Get company university chats error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load university chats.'
        });
    }
};

const getUniversityOrganizationChats = async (req, res) => {
    try {
        const scope = await getUniversityScope(req.user.user_id);
        const universityName = scope.universityName || scope.collegeName;
        if (!universityName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const conversations = await getUniversityConversationList(scope);
        return res.json({
            success: true,
            data: conversations
        });
    } catch (error) {
        console.error('Get university organization chats error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load organization chats.'
        });
    }
};

const getCompanyChatMessages = async (req, res) => {
    try {
        const { universityUserId } = req.params;
        const scope = await getCompanyScope(req.user.user_id);
        if (!scope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Company profile not found for this account.'
            });
        }

        const isAllowed = await canCompanyChatWithUniversity({
            companyUserId: req.user.user_id,
            universityUserId
        });
        if (!isAllowed) {
            return res.status(403).json({
                success: false,
                message: 'This university is not available for chat.'
            });
        }

        await markConversationRead({
            recipientRole: 'company',
            companyUserId: req.user.user_id,
            universityUserId,
            readerUserId: req.user.user_id
        });

        const messagesResult = await query(
            `SELECT
                chat_message_id AS id,
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message,
                created_at,
                edited_at,
                read_at
             FROM university_organization_messages
             WHERE university_user_id = $1
               AND company_user_id = $2
               AND deleted_for_company_at IS NULL
             ORDER BY created_at ASC`,
            [universityUserId, req.user.user_id]
        );

        return res.json({
            success: true,
            data: messagesResult.rows
        });
    } catch (error) {
        console.error('Get company chat messages error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load chat messages.'
        });
    }
};

const getUniversityChatMessages = async (req, res) => {
    try {
        const { companyUserId } = req.params;
        const scope = await getUniversityScope(req.user.user_id);
        const universityName = scope.universityName || scope.collegeName;
        if (!universityName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        await markConversationRead({
            recipientRole: 'university',
            companyUserId,
            universityUserId: req.user.user_id,
            readerUserId: req.user.user_id
        });

        const messagesResult = await query(
            `SELECT
                chat_message_id AS id,
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message,
                created_at,
                edited_at,
                read_at
             FROM university_organization_messages
             WHERE university_user_id = $1
               AND company_user_id = $2
               AND deleted_for_university_at IS NULL
             ORDER BY created_at ASC`,
            [req.user.user_id, companyUserId]
        );

        return res.json({
            success: true,
            data: messagesResult.rows
        });
    } catch (error) {
        console.error('Get university chat messages error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to load chat messages.'
        });
    }
};

const sendCompanyChatMessage = async (req, res) => {
    try {
        const { universityUserId } = req.params;
        const trimmedMessage = `${req.body?.message || ''}`.trim();
        if (!trimmedMessage) {
            return res.status(400).json({
                success: false,
                message: 'Message cannot be empty.'
            });
        }

        const companyScope = await getCompanyScope(req.user.user_id);
        if (!companyScope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Company profile not found for this account.'
            });
        }

        const isAllowed = await canCompanyChatWithUniversity({
            companyUserId: req.user.user_id,
            universityUserId
        });
        if (!isAllowed) {
            return res.status(403).json({
                success: false,
                message: 'This university is not available for chat.'
            });
        }

        const universityScope = await getUniversityScope(universityUserId);
        const universityName =
            universityScope.universityName || universityScope.collegeName;
        if (!universityName) {
            return res.status(404).json({
                success: false,
                message: 'Target university was not found.'
            });
        }

        const insertResult = await query(
            `INSERT INTO university_organization_messages (
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message
             ) VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING
                chat_message_id AS id,
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message,
                created_at,
                edited_at,
                read_at`,
            [
                universityUserId,
                req.user.user_id,
                req.user.user_id,
                'organization',
                companyScope.companyName,
                companyScope.phone,
                trimmedMessage
            ]
        );

        await NotificationModel.create({
            user_id: universityUserId,
            title: `New message from ${companyScope.companyName}`,
            message: `${companyScope.companyName}: ${trimmedMessage}`,
            type: 'university_organization_chat'
        });

        return res.json({
            success: true,
            data: {
                ...insertResult.rows[0],
                university_name: universityName,
                company_name: companyScope.companyName
            }
        });
    } catch (error) {
        console.error('Send company chat message error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to send message.'
        });
    }
};

const updateCompanyChatMessage = async (req, res) => {
    try {
        const { universityUserId, messageId } = req.params;
        const trimmedMessage = `${req.body?.message || ''}`.trim();
        if (!trimmedMessage) {
            return res.status(400).json({
                success: false,
                message: 'Message cannot be empty.'
            });
        }

        const companyScope = await getCompanyScope(req.user.user_id);
        if (!companyScope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Company profile not found for this account.'
            });
        }

        const isAllowed = await canCompanyChatWithUniversity({
            companyUserId: req.user.user_id,
            universityUserId
        });
        if (!isAllowed) {
            return res.status(403).json({
                success: false,
                message: 'This university is not available for chat.'
            });
        }

        const updateResult = await query(
            `UPDATE university_organization_messages
             SET
                message = $4,
                edited_at = CURRENT_TIMESTAMP
             WHERE chat_message_id = $1
               AND university_user_id = $2
               AND company_user_id = $3
               AND sender_user_id = $3
             RETURNING
                chat_message_id AS id,
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message,
                created_at,
                edited_at,
                read_at`,
            [messageId, universityUserId, req.user.user_id, trimmedMessage]
        );

        if (!updateResult.rows.length) {
            return res.status(404).json({
                success: false,
                message:
                    'Message not found, or you can only edit your own messages.'
            });
        }

        return res.json({
            success: true,
            message: 'Message updated successfully.',
            data: updateResult.rows[0]
        });
    } catch (error) {
        console.error('Update company chat message error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to update message.'
        });
    }
};

const sendUniversityChatMessage = async (req, res) => {
    try {
        const { companyUserId } = req.params;
        const trimmedMessage = `${req.body?.message || ''}`.trim();
        if (!trimmedMessage) {
            return res.status(400).json({
                success: false,
                message: 'Message cannot be empty.'
            });
        }

        const universityScope = await getUniversityScope(req.user.user_id);
        const universityName =
            universityScope.universityName || universityScope.collegeName;
        if (!universityName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const companyScope = await getCompanyScope(companyUserId);
        if (!companyScope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Target organization was not found.'
            });
        }

        const senderName =
            universityScope.coordinatorName || universityName;
        const insertResult = await query(
            `INSERT INTO university_organization_messages (
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message
             ) VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING
                chat_message_id AS id,
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message,
                created_at,
                edited_at,
                read_at`,
            [
                req.user.user_id,
                companyUserId,
                req.user.user_id,
                'university',
                senderName,
                universityScope.coordinatorPhone,
                trimmedMessage
            ]
        );

        await NotificationModel.create({
            user_id: companyUserId,
            title: `New message from ${universityName}`,
            message: `${senderName}: ${trimmedMessage}`,
            type: 'university_organization_chat'
        });

        return res.json({
            success: true,
            data: {
                ...insertResult.rows[0],
                university_name: universityName,
                company_name: companyScope.companyName
            }
        });
    } catch (error) {
        console.error('Send university chat message error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to send message.'
        });
    }
};

const updateUniversityChatMessage = async (req, res) => {
    try {
        const { companyUserId, messageId } = req.params;
        const trimmedMessage = `${req.body?.message || ''}`.trim();
        if (!trimmedMessage) {
            return res.status(400).json({
                success: false,
                message: 'Message cannot be empty.'
            });
        }

        const universityScope = await getUniversityScope(req.user.user_id);
        const universityName =
            universityScope.universityName || universityScope.collegeName;
        if (!universityName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const companyScope = await getCompanyScope(companyUserId);
        if (!companyScope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Target organization was not found.'
            });
        }

        const updateResult = await query(
            `UPDATE university_organization_messages
             SET
                message = $4,
                edited_at = CURRENT_TIMESTAMP
             WHERE chat_message_id = $1
               AND university_user_id = $2
               AND company_user_id = $3
               AND sender_user_id = $2
             RETURNING
                chat_message_id AS id,
                university_user_id,
                company_user_id,
                sender_user_id,
                sender_role,
                sender_name,
                sender_phone,
                message,
                created_at,
                edited_at,
                read_at`,
            [messageId, req.user.user_id, companyUserId, trimmedMessage]
        );

        if (!updateResult.rows.length) {
            return res.status(404).json({
                success: false,
                message:
                    'Message not found, or you can only edit your own messages.'
            });
        }

        return res.json({
            success: true,
            message: 'Message updated successfully.',
            data: updateResult.rows[0]
        });
    } catch (error) {
        console.error('Update university chat message error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to update message.'
        });
    }
};

const purgeFullyDeletedConversationMessage = async (messageId) => {
    if (!messageId) return;

    await query(
        `DELETE FROM university_organization_messages
         WHERE chat_message_id = $1
           AND deleted_for_university_at IS NOT NULL
           AND deleted_for_company_at IS NOT NULL`,
        [messageId]
    );
};

const deleteCompanyChatMessage = async (req, res) => {
    try {
        const { universityUserId, messageId } = req.params;
        const companyScope = await getCompanyScope(req.user.user_id);
        if (!companyScope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Company profile not found for this account.'
            });
        }

        const isAllowed = await canCompanyChatWithUniversity({
            companyUserId: req.user.user_id,
            universityUserId
        });
        if (!isAllowed) {
            return res.status(403).json({
                success: false,
                message: 'This university is not available for chat.'
            });
        }

        const deleteResult = await query(
            `UPDATE university_organization_messages
             SET deleted_for_company_at = COALESCE(
                    deleted_for_company_at,
                    CURRENT_TIMESTAMP
                 )
             WHERE chat_message_id = $1
               AND university_user_id = $2
               AND company_user_id = $3
               AND deleted_for_company_at IS NULL
             RETURNING chat_message_id AS id`,
            [messageId, universityUserId, req.user.user_id]
        );

        if (!deleteResult.rows.length) {
            return res.status(404).json({
                success: false,
                message: 'Message not found, or it is already removed from your chat.'
            });
        }

        await purgeFullyDeletedConversationMessage(messageId);

        return res.json({
            success: true,
            message: 'Message removed from your chat successfully.',
            data: deleteResult.rows[0]
        });
    } catch (error) {
        console.error('Delete company chat message error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete message.'
        });
    }
};

const deleteUniversityChatMessage = async (req, res) => {
    try {
        const { companyUserId, messageId } = req.params;
        const universityScope = await getUniversityScope(req.user.user_id);
        const universityName =
            universityScope.universityName || universityScope.collegeName;
        if (!universityName) {
            return res.status(404).json({
                success: false,
                message: 'University profile not found for this coordinator.'
            });
        }

        const companyScope = await getCompanyScope(companyUserId);
        if (!companyScope.companyName) {
            return res.status(404).json({
                success: false,
                message: 'Target organization was not found.'
            });
        }

        const deleteResult = await query(
            `UPDATE university_organization_messages
             SET deleted_for_university_at = COALESCE(
                    deleted_for_university_at,
                    CURRENT_TIMESTAMP
                 )
             WHERE chat_message_id = $1
              AND university_user_id = $2
              AND company_user_id = $3
               AND deleted_for_university_at IS NULL
             RETURNING chat_message_id AS id`,
            [messageId, req.user.user_id, companyUserId]
        );

        if (!deleteResult.rows.length) {
            return res.status(404).json({
                success: false,
                message: 'Message not found, or it is already removed from your chat.'
            });
        }

        await purgeFullyDeletedConversationMessage(messageId);

        return res.json({
            success: true,
            message: 'Message removed from your chat successfully.',
            data: deleteResult.rows[0]
        });
    } catch (error) {
        console.error('Delete university chat message error:', error);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete message.'
        });
    }
};

module.exports = {
    getCompanyUniversityChats,
    getUniversityOrganizationChats,
    getCompanyChatMessages,
    getUniversityChatMessages,
    sendCompanyChatMessage,
    sendUniversityChatMessage,
    updateCompanyChatMessage,
    updateUniversityChatMessage,
    deleteCompanyChatMessage,
    deleteUniversityChatMessage
};
