const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notification.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

router.get('/', authMiddleware, notificationController.getNotifications);
router.put('/:id/read', authMiddleware, notificationController.markAsRead);
router.delete('/:id', authMiddleware, notificationController.deleteNotification);
router.put('/read-all', authMiddleware, notificationController.markAllAsRead);
router.get('/unread-count', authMiddleware, notificationController.getUnreadCount);

module.exports = router;
