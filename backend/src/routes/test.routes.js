const express = require('express');
const router = express.Router();
const testController = require('../controllers/test.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

router.get('/my-attempts', authMiddleware, authorize('student', ''), testController.getMyAttempts);
router.get('/attempt/:token', testController.getPublicAttempt);
router.put('/attempt/:token/save', testController.saveAttempt);
router.post('/attempt/:token/submit', testController.submitAttempt);

module.exports = router;
