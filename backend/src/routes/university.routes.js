const express = require('express');
const router = express.Router();
const universityController = require('../controllers/university.controller');
const universityOrganizationChatController = require('../controllers/university-organization-chat.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

router.use(authMiddleware, authorize('university'));

router.get('/students/overview', universityController.getUniversityStudentsOverview);
router.get('/students/placed', universityController.getUniversityPlacedStudents);
router.get('/companies/contacts', universityController.getUniversityCompanyContacts);
router.post(
    '/companies/:companyId/jobs/:jobId/reserve-slot',
    universityController.reserveCompanyJobSlotForUniversityAssignment
);
router.post(
    '/companies/:companyId/jobs/:jobId/assign-student',
    universityController.assignStudentToCompanyJob
);
router.get(
    '/organization-chats',
    universityOrganizationChatController.getUniversityOrganizationChats
);
router.get(
    '/organization-chats/:companyUserId/messages',
    universityOrganizationChatController.getUniversityChatMessages
);
router.post(
    '/organization-chats/:companyUserId/messages',
    universityOrganizationChatController.sendUniversityChatMessage
);
router.put(
    '/organization-chats/:companyUserId/messages/:messageId',
    universityOrganizationChatController.updateUniversityChatMessage
);
router.delete(
    '/organization-chats/:companyUserId/messages/:messageId',
    universityOrganizationChatController.deleteUniversityChatMessage
);

module.exports = router;
