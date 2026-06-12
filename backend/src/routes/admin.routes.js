const express = require('express');
const router = express.Router();
const adminController = require('../controllers/admin.controller');
const testController = require('../controllers/test.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

// All admin routes require authentication and admin role
router.use(authMiddleware, authorize('admin'));

// Dashboard stats
router.get('/stats', adminController.getStats);

// User management
router.post('/users/admin', adminController.createAdminUser);
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
router.get('/training', adminController.getAlltraining);
router.get('/students/all', adminController.getAllAdminStudents);
router.get('/students/with-university', adminController.getStudentsWithUniversity);
router.get('/students/with-awards', adminController.getStudentsWithAwards);
router.get('/students/no-field', adminController.getStudentsNoField);

router.delete('/training/:id', adminController.deleteJob);

// Online test management
router.get('/tests', testController.listTests);
router.post('/tests', testController.createTest);
router.get('/tests/:testId', testController.getTest);
router.post('/tests/:testId/invite', testController.inviteStudents);
router.get('/tests/:testId/results', testController.getResults);
router.get('/tests/attempts/:attemptId/answers', testController.getAttemptAnswersForAdmin);
router.put('/tests/answers/:answerId/score', testController.gradeAnswerManually);
router.post('/tests/:testId/auto-selection', testController.applyAutoSelection);

module.exports = router;
