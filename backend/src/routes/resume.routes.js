const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();

console.log('✅✅✅ RESUME ROUTES FILE IS BEING LOADED! ✅✅✅');

// Configure multer for file upload
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = path.join(__dirname, '../../uploads/resumes');
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    const ext = path.extname(file.originalname);
    cb(null, `resume-${uniqueSuffix}${ext}`);
  }
});

const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'];
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type. Only PDF, DOC, DOCX are allowed.'));
    }
  }
});

// Simple test route (NO AUTH)
router.get('/test', (req, res) => {
  console.log('🎯 Test endpoint hit!');
  res.json({ success: true, message: 'Resume route is working!' });
});

// Upload route (NO AUTH for testing)
router.post('/upload', upload.single('resume'), (req, res) => {
  console.log('📤 Upload endpoint hit!');
  console.log('File:', req.file);
  
  if (!req.file) {
    return res.status(400).json({ success: false, message: 'No file uploaded' });
  }
  
  const resumeUrl = `/uploads/resumes/${req.file.filename}`;
  res.json({
    success: true,
    message: 'Resume uploaded successfully',
    data: { resume_url: resumeUrl }
  });
});

module.exports = router;
