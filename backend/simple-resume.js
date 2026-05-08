const express = require('express');
const multer = require('multer');
const router = express.Router();
const { query } = require('./src/config/database');
const { authMiddleware, authorize } = require('./src/middleware/auth.middleware');
const { uploadAsset, deleteAssetByUrl } = require('./src/services/file-storage.service');

console.log('RESUME ROUTER DB VERSION LOADED');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PDF, DOC, DOCX are allowed.'));
    }
  }
});

// Test route - GET
router.get('/test', (req, res) => {
  res.json({ 
    success: true, 
    message: 'Resume route DB version is working!',
    timestamp: new Date().toISOString()
  });
});

// Upload route - POST (auth + persist to students.resume_url)
router.post('/upload', authMiddleware, authorize('student', ''), upload.single('resume'), async (req, res) => {
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No file uploaded' });
  }

  try {
    const uploadedResume = await uploadAsset({
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      originalName: req.file.originalname,
      localSubdir: 'resumes',
      fileNamePrefix: 'resume',
      cloudinaryFolder: 'student-job-platform/resumes',
      cloudinaryResourceType: 'raw'
    });
    const resumeUrl = uploadedResume.secureUrl;

    const updateResult = await query(
      `UPDATE students
       SET resume_url = $1
       WHERE student_id = $2
       RETURNING student_id, resume_url`,
      [resumeUrl, req.user.user_id]
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Student profile not found',
      });
    }

    res.json({
      success: true,
      message: 'Resume uploaded successfully',
      data: {
        resume_url: resumeUrl,
        filename: req.file.filename,
        size: req.file.size,
      },
    });
  } catch (error) {
    console.error('Resume upload DB error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to save resume',
      error: error.message,
    });
  }
});

// Delete route - DELETE (auth + remove file + clear students.resume_url)
router.delete('/', authMiddleware, authorize('student', ''), async (req, res) => {
  try {
    const studentId = req.user.user_id;

    const currentResult = await query(
      `SELECT resume_url
       FROM students
       WHERE student_id = $1`,
      [studentId]
    );

    if (currentResult.rows.length === 0) {
      return res.status(404).json({
        success: false,
        message: 'Student profile not found',
      });
    }

    const currentResumeUrl = currentResult.rows[0].resume_url;

    if (currentResumeUrl) {
      await deleteAssetByUrl({
        fileUrl: currentResumeUrl,
        resourceType: 'raw'
      });
    }

    const updateResult = await query(
      `UPDATE students
       SET resume_url = NULL
       WHERE student_id = $1
       RETURNING student_id, resume_url`,
      [studentId]
    );

    res.json({
      success: true,
      message: currentResumeUrl ? 'Resume deleted successfully' : 'No resume found to delete',
      data: updateResult.rows[0],
    });
  } catch (error) {
    console.error('Resume delete error:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete resume',
      error: error.message,
    });
  }
});

router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({ success: false, message: 'File too large. Maximum size is 5MB.' });
    }
    return res.status(400).json({ success: false, message: error.message });
  }

  if (error) {
    return res.status(400).json({ success: false, message: error.message || 'File upload failed.' });
  }

  next();
});

module.exports = router;
