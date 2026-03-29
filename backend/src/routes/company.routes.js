const express = require('express');
const router = express.Router();
const multer = require('multer');
const { query } = require('../config/database');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');
const { uploadAsset, deleteAssetByUrl } = require('../services/file-storage.service');

const upload = multer({ 
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB limit
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.jpg', '.jpeg', '.png'];
    const ext = `${file.originalname || ''}`.split('.').pop()?.toLowerCase();
    if (ext && allowedTypes.includes(`.${ext}`)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG, JPEG, PNG files are allowed'));
    }
  }
});

// Upload company logo
router.post('/logo', authMiddleware, authorize('company'), upload.single('logo'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ success: false, message: 'No file uploaded' });
    }

    const existingLogoResult = await query(
      'SELECT logo_url FROM companies WHERE company_id = $1 LIMIT 1',
      [req.user.user_id]
    );

    const uploadedLogo = await uploadAsset({
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      originalName: req.file.originalname,
      localSubdir: 'logos',
      fileNamePrefix: `${req.user.user_id}-logo`,
      cloudinaryFolder: 'student-job-platform/company-logos',
      cloudinaryResourceType: 'image'
    });
    const logoUrl = uploadedLogo.secureUrl;

    await query(
      'UPDATE companies SET logo_url = $1 WHERE company_id = $2',
      [logoUrl, req.user.user_id]
    );

    const previousLogoUrl = existingLogoResult.rows[0]?.logo_url;
    if (previousLogoUrl && previousLogoUrl !== logoUrl) {
      await deleteAssetByUrl({
        fileUrl: previousLogoUrl,
        resourceType: 'image'
      });
    }
    
    res.json({ 
      success: true, 
      message: 'Logo uploaded successfully',
      data: { logo_url: logoUrl }
    });
  } catch (error) {
    console.error('Upload logo error:', error);
    res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
