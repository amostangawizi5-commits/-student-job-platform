// src/routes/auth.routes.js
const express = require('express');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

// Public routes
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/forgot-password', authController.forgotPassword);
router.get('/universities', authController.getUniversities);
router.get('/skills', authController.getSkills);
router.get('/reset-password', authController.renderPasswordResetForm);
router.post('/reset-password', authController.completePasswordReset);

// Protected routes (require authentication)
router.get('/profile', authMiddleware, authController.getProfile);
router.put('/profile', authMiddleware, authController.updateProfile);

module.exports = router;
