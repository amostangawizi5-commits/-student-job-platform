const express = require('express');
const router = express.Router();
const multer = require('multer');
const { query } = require('../config/database');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');
const { uploadAsset, deleteAssetByUrl } = require('../services/file-storage.service');

const createUpload = ({ allowedExtensions, message }) =>
  multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
      const ext = `${file.originalname || ''}`.split('.').pop()?.toLowerCase();
      if (ext && allowedExtensions.includes(`.${ext}`)) {
        cb(null, true);
        return;
      }

      cb(new Error(message));
    },
  });

const logoUpload = createUpload({
  allowedExtensions: ['.jpg', '.jpeg', '.png'],
  message: 'Only JPG, JPEG, PNG files are allowed',
});

const acceptanceAssetUpload = createUpload({
  allowedExtensions: ['.jpg', '.jpeg'],
  message: 'Only JPG or JPEG files are allowed for acceptance letter assets',
});

const uploadCompanyImageAsset = async ({
  req,
  res,
  dbColumn,
  fieldLabel,
  formFieldName,
  localSubdir,
  fileNamePrefix,
  cloudinaryFolder,
}) => {
  try {
    if (!req.file) {
      return res
        .status(400)
        .json({ success: false, message: `No ${fieldLabel.toLowerCase()} uploaded` });
    }

    const existingAssetResult = await query(
      `SELECT ${dbColumn} FROM companies WHERE company_id = $1 LIMIT 1`,
      [req.user.user_id],
    );

    const uploadedAsset = await uploadAsset({
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      originalName: req.file.originalname,
      localSubdir,
      fileNamePrefix: `${req.user.user_id}-${fileNamePrefix}`,
      cloudinaryFolder,
      cloudinaryResourceType: 'image',
    });
    const assetUrl = uploadedAsset.secureUrl;

    await query(
      `UPDATE companies SET ${dbColumn} = $1 WHERE company_id = $2`,
      [assetUrl, req.user.user_id],
    );

    const previousAssetUrl = existingAssetResult.rows[0]?.[dbColumn];
    if (previousAssetUrl && previousAssetUrl !== assetUrl) {
      await deleteAssetByUrl({
        fileUrl: previousAssetUrl,
        resourceType: 'image',
      }).catch(() => false);
    }

    return res.json({
      success: true,
      message: `${fieldLabel} uploaded successfully`,
      data: { [formFieldName]: assetUrl },
    });
  } catch (error) {
    console.error(`Upload ${fieldLabel.toLowerCase()} error:`, error);
    return res.status(500).json({
      success: false,
      message: error.message || `Failed to upload ${fieldLabel.toLowerCase()}`,
    });
  }
};

router.post(
  '/logo',
  authMiddleware,
  authorize('company'),
  logoUpload.single('logo'),
  async (req, res) =>
    uploadCompanyImageAsset({
      req,
      res,
      dbColumn: 'logo_url',
      fieldLabel: 'Logo',
      formFieldName: 'logo_url',
      localSubdir: 'logos',
      fileNamePrefix: 'logo',
      cloudinaryFolder: 'student-job-platform/company-logos',
    }),
);

router.post(
  '/stamp',
  authMiddleware,
  authorize('company'),
  acceptanceAssetUpload.single('stamp'),
  async (req, res) =>
    uploadCompanyImageAsset({
      req,
      res,
      dbColumn: 'stamp_url',
      fieldLabel: 'Stamp',
      formFieldName: 'stamp_url',
      localSubdir: 'company-stamps',
      fileNamePrefix: 'stamp',
      cloudinaryFolder: 'student-job-platform/company-stamps',
    }),
);

router.post(
  '/signature',
  authMiddleware,
  authorize('company'),
  acceptanceAssetUpload.single('signature'),
  async (req, res) =>
    uploadCompanyImageAsset({
      req,
      res,
      dbColumn: 'signature_url',
      fieldLabel: 'Signature',
      formFieldName: 'signature_url',
      localSubdir: 'company-signatures',
      fileNamePrefix: 'signature',
      cloudinaryFolder: 'student-job-platform/company-signatures',
    }),
);

router.use((error, req, res, next) => {
  if (error instanceof multer.MulterError) {
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(400).json({
        success: false,
        message: 'Image file is too large. Maximum size is 5MB.',
      });
    }

    return res.status(400).json({ success: false, message: error.message });
  }

  if (error) {
    return res.status(400).json({
      success: false,
      message: error.message || 'File upload failed.',
    });
  }

  next();
});

module.exports = router;
