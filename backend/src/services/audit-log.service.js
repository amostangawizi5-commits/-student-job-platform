const { query } = require('../config/database');

const AUDIT_LOG_TABLE_SQL = `
    CREATE TABLE IF NOT EXISTS admin_audit_logs (
        log_id SERIAL PRIMARY KEY,
        category VARCHAR(32) NOT NULL,
        event_type VARCHAR(120) NOT NULL,
        message TEXT NOT NULL,
        actor_user_id UUID,
        actor_name TEXT,
        user_involved UUID,
        user_involved_name TEXT,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
`;

const ensureAuditLogTable = async () => {
    await query(AUDIT_LOG_TABLE_SQL);
};

const logAuditEvent = async ({
    category,
    eventType,
    message,
    actorUserId = null,
    actorName = null,
    userInvolved = null,
    userInvolvedName = null
}) => {
    try {
        await ensureAuditLogTable();
        await query(
            `INSERT INTO admin_audit_logs (
                category,
                event_type,
                message,
                actor_user_id,
                actor_name,
                user_involved,
                user_involved_name
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7)`,
            [
                category,
                eventType,
                message,
                actorUserId,
                actorName,
                userInvolved,
                userInvolvedName
            ]
        );
    } catch (error) {
        console.error('Audit log error:', error);
    }
};

const getAuditLogs = async () => {
    await ensureAuditLogTable();
    const result = await query(
        `SELECT log_id, category, event_type, message, actor_user_id, actor_name,
                user_involved, user_involved_name, created_at
         FROM admin_audit_logs
         ORDER BY created_at DESC
         LIMIT 200`
    );
    return result.rows;
};

module.exports = {
    getAuditLogs,
    logAuditEvent
};
