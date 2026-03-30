const { query } = require('../config/database');

class NotificationModel {
    // Create notification
    static async create(notificationData) {
        const { user_id, title, message, type } = notificationData;
        
        const result = await query(
            `INSERT INTO notifications (user_id, title, message, type, is_read, created_at)
             VALUES ($1, $2, $3, $4, false, CURRENT_TIMESTAMP)
             RETURNING *`,
            [user_id, title, message, type]
        );
        
        return result.rows[0];
    }

    // Get user notifications
    static async getUserNotifications(user_id) {
        const result = await query(
            `SELECT * FROM notifications 
             WHERE user_id = $1 
             ORDER BY created_at DESC 
             LIMIT 50`,
            [user_id]
        );
        return result.rows;
    }

    // Mark as read
    static async markAsRead(notification_id) {
        const result = await query(
            `UPDATE notifications 
             SET is_read = true 
             WHERE notification_id = $1 
             RETURNING *`,
            [notification_id]
        );
        return result.rows[0];
    }

    static async deleteForUser(notification_id, user_id) {
        const result = await query(
            `DELETE FROM notifications
             WHERE notification_id = $1 AND user_id = $2
             RETURNING notification_id`,
            [notification_id, user_id]
        );
        return result.rows[0] || null;
    }

    // Mark all as read
    static async markAllAsRead(user_id) {
        await query(
            `UPDATE notifications 
             SET is_read = true 
             WHERE user_id = $1 AND is_read = false`,
            [user_id]
        );
    }

    // Get unread count
    static async getUnreadCount(user_id) {
        const result = await query(
            `SELECT COUNT(*) FROM notifications 
             WHERE user_id = $1 AND is_read = false`,
            [user_id]
        );
        return parseInt(result.rows[0].count);
    }
}

module.exports = NotificationModel;
