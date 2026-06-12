// src/routes/skill.routes.js
const express = require('express');
const router = express.Router();
const skillController = require('../controllers/skill.controller');
const { authMiddleware } = require('../middleware/auth.middleware');

// Public routes
router.get('/', skillController.getAllSkills);
router.get('/trending', skillController.getTrendingSkills);
router.get('/all', skillController.getAllSkills);

// Protected routes
router.get('/match', authMiddleware, skillController.getSkillMatch);

module.exports = router;
