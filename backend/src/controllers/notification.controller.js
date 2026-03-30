const NotificationModel = require('../models/notification.model');

// Get user notifications
const getNotifications = async (req, res) => {
    try {
        const notifications = await NotificationModel.getUserNotifications(req.user.user_id);
        res.json({ success: true, data: notifications });
    } catch (error) {
        console.error('Get notifications error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Mark notification as read
const markAsRead = async (req, res) => {
    try {
        const { id } = req.params;
        await NotificationModel.markAsRead(id);
        res.json({ success: true, message: 'Notification marked as read' });
    } catch (error) {
        console.error('Mark as read error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

const deleteNotification = async (req, res) => {
    try {
        const { id } = req.params;
        const deleted = await NotificationModel.deleteForUser(id, req.user.user_id);

        if (!deleted) {
            return res.status(404).json({
                success: false,
                message: 'Notification not found'
            });
        }

        return res.json({
            success: true,
            message: 'Notification deleted successfully'
        });
    } catch (error) {
        console.error('Delete notification error:', error);
        return res.status(500).json({ success: false, message: error.message });
    }
};

// Mark all as read
const markAllAsRead = async (req, res) => {
    try {
        await NotificationModel.markAllAsRead(req.user.user_id);
        res.json({ success: true, message: 'All notifications marked as read' });
    } catch (error) {
        console.error('Mark all as read error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

// Get unread count
const getUnreadCount = async (req, res) => {
    try {
        const count = await NotificationModel.getUnreadCount(req.user.user_id);
        res.json({ success: true, data: { count } });
    } catch (error) {
        console.error('Get unread count error:', error);
        res.status(500).json({ success: false, message: error.message });
    }
};

module.exports = {
    getNotifications,
    markAsRead,
    deleteNotification,
    markAllAsRead,
    getUnreadCount
};
