const express = require('express');
const router = express.Router();
const universityController = require('../controllers/university.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

router.use(authMiddleware, authorize('university'));

router.get('/students/overview', universityController.getUniversityStudentsOverview);
router.get('/students/placed', universityController.getUniversityPlacedStudents);
router.get('/companies/contacts', universityController.getUniversityCompanyContacts);

module.exports = router;
