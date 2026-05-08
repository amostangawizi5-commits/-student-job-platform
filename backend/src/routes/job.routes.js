// src/routes/job.routes.js
const express = require('express');
const router = express.Router();
const jobController = require('../controllers/job.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

// Public routes
router.get('/', jobController.getAlltraining);
router.get(
    '/organization/my-training',
    authMiddleware,
    authorize('company', 'university'),
    jobController.getCompanytraining
);
router.get(
    '/company/my-training',
    authMiddleware,
    authorize('company', 'university'),
    jobController.getCompanytraining
);
router.get('/:id', jobController.getJobById);

// Protected routes (require authentication)
router.post(
    '/',
    authMiddleware,
    authorize('company', 'university'),
    jobController.createJob
);
router.put('/:id', authMiddleware, jobController.updateJob);
router.delete('/:id', authMiddleware, jobController.deleteJob);

module.exports = router;
