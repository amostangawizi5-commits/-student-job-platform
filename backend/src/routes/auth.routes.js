// src/routes/auth.routes.js
const express = require('express');
const multer = require('multer');
const router = express.Router();
const authController = require('../controllers/auth.controller');
const { query } = require('../config/database');
const { authMiddleware } = require('../middleware/auth.middleware');
const { uploadAsset, deleteAssetByUrl } = require('../services/file-storage.service');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
  fileFilter: (req, file, cb) => {
    const allowedTypes = ['.jpg', '.jpeg', '.png'];
    const ext = `${file.originalname || ''}`.split('.').pop()?.toLowerCase();
    if (ext && allowedTypes.includes(`.${ext}`)) {
      cb(null, true);
    } else {
      cb(new Error('Only JPG, JPEG, PNG files are allowed'));
    }
  },
});

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
router.post(
  '/profile-image',
  authMiddleware,
  upload.single('profile_image'),
  async (req, res) => {
    try {
      if (!req.file) {
        return res
          .status(400)
          .json({ success: false, message: 'No image uploaded' });
      }

      const existingImageResult = await query(
        'SELECT profile_image_url FROM users WHERE user_id = $1 LIMIT 1',
        [req.user.user_id],
      );

      const uploadedImage = await uploadAsset({
        buffer: req.file.buffer,
        mimeType: req.file.mimetype,
        originalName: req.file.originalname,
        localSubdir: 'profile-images',
        fileNamePrefix: `${req.user.user_id}-profile`,
        cloudinaryFolder: 'student-job-platform/profile-images',
        cloudinaryResourceType: 'image',
      });
      const imageUrl = uploadedImage.secureUrl;

      await query(
        'UPDATE users SET profile_image_url = $1, updated_at = CURRENT_TIMESTAMP WHERE user_id = $2',
        [imageUrl, req.user.user_id],
      );

      const previousImageUrl = existingImageResult.rows[0]?.profile_image_url;
      if (previousImageUrl && previousImageUrl !== imageUrl) {
        await deleteAssetByUrl({
          fileUrl: previousImageUrl,
          resourceType: 'image',
        });
      }

      return res.json({
        success: true,
        message: 'Profile image uploaded successfully',
        data: { profile_image_url: imageUrl },
      });
    } catch (error) {
      console.error('Upload profile image error:', error);
      return res.status(500).json({
        success: false,
        message: error.message || 'Failed to upload profile image',
      });
    }
  },
);
router.delete('/profile-image', authMiddleware, async (req, res) => {
  try {
    const existingImageResult = await query(
      'SELECT profile_image_url FROM users WHERE user_id = $1 LIMIT 1',
      [req.user.user_id],
    );

    const previousImageUrl = existingImageResult.rows[0]?.profile_image_url;
    if (!previousImageUrl) {
      return res.status(404).json({
        success: false,
        message: 'No profile image found',
      });
    }

    await query(
      'UPDATE users SET profile_image_url = NULL, updated_at = CURRENT_TIMESTAMP WHERE user_id = $1',
      [req.user.user_id],
    );

    await deleteAssetByUrl({
      fileUrl: previousImageUrl,
      resourceType: 'image',
    });

    return res.json({
      success: true,
      message: 'Profile image removed successfully',
    });
  } catch (error) {
    console.error('Delete profile image error:', error);
    return res.status(500).json({
      success: false,
      message: error.message || 'Failed to remove profile image',
    });
  }
});

module.exports = router;
