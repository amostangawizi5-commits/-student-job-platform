const express = require('express');
const multer = require('multer');
const router = express.Router();
const applicationController = require('../controllers/application.controller');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');

const pdfUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    if (file.mimetype === 'application/pdf') {
      cb(null, true);
      return;
    }

    cb(new Error('Only PDF files are allowed.'));
  }
});

// Student routes
router.post(
  '/',
  authMiddleware,
  authorize('student', ''),
  pdfUpload.fields([
    { name: 'cover_letter_file', maxCount: 1 },
    { name: 'supportive_document', maxCount: 1 }
  ]),
  applicationController.applyForJob
);
router.get('/my-applications', authMiddleware, authorize('student', ''), applicationController.getMyApplications);
router.post(
  '/:application_id/confirm-selection',
  authMiddleware,
  authorize('student', ''),
  applicationController.confirmApplicationSelection
);
router.get(
  '/:application_id/cover-letter',
  authMiddleware,
  authorize('student', '', 'company', 'admin', 'university'),
  applicationController.downloadCoverLetter
);
router.get(
  '/:application_id/supportive-document',
  authMiddleware,
  authorize('student', '', 'company', 'admin', 'university'),
  applicationController.downloadSupportiveDocument
);
router.get(
  '/:application_id/response-letter',
  authMiddleware,
  authorize('student', '', 'company', 'admin', 'university'),
  applicationController.downloadResponseLetter
);

// Organization/company routes
router.get('/organization', authMiddleware, authorize('company', 'university'), applicationController.getCompanyApplications);
router.get('/job/:job_id', authMiddleware, authorize('company', 'university'), applicationController.getJobApplications);
router.put(
  '/:application_id/document-review',
  authMiddleware,
  authorize('company', 'university'),
  applicationController.reviewSupportiveDocument
);
router.put(
  '/:application_id',
  authMiddleware,
  authorize('company', 'university'),
  pdfUpload.single('response_letter'),
  applicationController.updateApplicationStatus
);

router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res
        .status(400)
        .json({ success: false, message: 'PDF file is too large. Maximum size is 5MB.' });
    }

    return res.status(400).json({ success: false, message: error.message });
  }

  if (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'File upload failed.'
    });
  }

  next();
});

module.exports = router;
