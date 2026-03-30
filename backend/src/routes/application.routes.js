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
  authorize('student', 'graduate'),
  pdfUpload.single('supportive_document'),
  applicationController.applyForJob
);
router.get('/my-applications', authMiddleware, authorize('student', 'graduate'), applicationController.getMyApplications);

// Company routes
router.get('/company', authMiddleware, authorize('company'), applicationController.getCompanyApplications);
router.get('/job/:job_id', authMiddleware, authorize('company'), applicationController.getJobApplications);
router.put(
  '/:application_id/document-review',
  authMiddleware,
  authorize('company'),
  applicationController.reviewSupportiveDocument
);
router.put(
  '/:application_id',
  authMiddleware,
  authorize('company'),
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
