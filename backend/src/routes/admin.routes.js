const express = require('express');
const router = express.Router();
const adminController = require('../controllers/admin.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

// All admin routes require authentication and admin role
router.use(authMiddleware, authorize('admin'));

// Dashboard stats
router.get('/stats', adminController.getStats);

// User management
router.get('/users', adminController.getAllUsers);
router.get('/users/:id', adminController.getUserById);
router.put('/users/:id/role', adminController.updateUserRole);
router.put('/users/:id/verify', adminController.verifyUser);
router.put('/users/:id/reset-password', adminController.resetUserPassword);
router.put('/users/:id/suspend', adminController.suspendUser);
router.put('/users/:id/activate', adminController.activateUser);
router.delete('/users/:id', adminController.deleteUser);

// Application management
router.get('/applications', adminController.getAllApplications);
router.put(
  '/applications/:applicationId/status',
  adminController.updateAdminApplicationStatus
);

router.get('/logs', adminController.getLogs);

// Job management
router.get('/jobs', adminController.getAllJobs);
router.delete('/jobs/:id', adminController.deleteJob);

module.exports = router;
