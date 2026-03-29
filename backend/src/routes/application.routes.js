const express = require('express');
const router = express.Router();
const applicationController = require('../controllers/application.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

// Student routes
router.post('/', authMiddleware, authorize('student', 'graduate'), applicationController.applyForJob);
router.get('/my-applications', authMiddleware, authorize('student', 'graduate'), applicationController.getMyApplications);

// Company routes
router.get('/company', authMiddleware, authorize('company'), applicationController.getCompanyApplications);
router.get('/job/:job_id', authMiddleware, authorize('company'), applicationController.getJobApplications);
router.put('/:application_id', authMiddleware, authorize('company'), applicationController.updateApplicationStatus);

module.exports = router;
