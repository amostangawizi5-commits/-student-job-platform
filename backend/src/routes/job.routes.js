// src/routes/job.routes.js
const express = require('express');
const router = express.Router();
const jobController = require('../controllers/job.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

// Public routes
router.get('/', jobController.getAllJobs);
router.get('/:id', jobController.getJobById);

// Protected routes (require authentication)
router.post('/', authMiddleware, authorize('company'), jobController.createJob);
router.put('/:id', authMiddleware, jobController.updateJob);
router.delete('/:id', authMiddleware, jobController.deleteJob);
router.get('/company/my-jobs', authMiddleware, authorize('company'), jobController.getCompanyJobs);

module.exports = router;
