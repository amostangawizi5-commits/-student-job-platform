const express = require('express');
const router = express.Router();
const multer = require('multer');
const { query } = require('../config/database');
const { authMiddleware, authorize } = require('../middleware/auth.middleware');
const universityOrganizationChatController = require('../controllers/university-organization-chat.controller');
const { uploadAsset, deleteAssetByUrl } = require('../services/file-storage.service');

const matchesAllowedUpload = (file, { allowedExtensions, allowedMimeTypes }) => {
  const ext = `${file.originalname || ''}`.split('.').pop()?.toLowerCase();
  const mimeType = `${file.mimetype || ''}`.toLowerCase();

  return (
    (ext && allowedExtensions.includes(`.${ext}`)) ||
    (mimeType && allowedMimeTypes.includes(mimeType))
  );
};

const createUpload = ({ allowedExtensions, message }) =>
  multer({
    storage: multer.memoryStorage(),
    limits: { fileSize: 5 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
      const isAllowed = matchesAllowedUpload(file, {
        allowedExtensions,
        allowedMimeTypes: allowedExtensions.includes('.webp')
          ? ['image/jpeg', 'image/png', 'image/webp']
          : ['image/jpeg', 'image/png'],
      });

      if (isAllowed) {
        cb(null, true);
        return;
      }

      cb(new Error(message));
    },
  });

const logoUpload = createUpload({
  allowedExtensions: ['.jpg', '.jpeg', '.png', '.webp'],
  message: 'Only JPG, JPEG, PNG, or WEBP files are allowed',
});

const acceptanceAssetUpload = createUpload({
  allowedExtensions: ['.jpg', '.jpeg', '.png'],
  message: 'Only JPG, JPEG, or PNG files are allowed for acceptance letter assets',
});

const ensureCompanyProfileExists = async (userId) => {
  const existingAssetResult = await query(
    `SELECT logo_url, stamp_url, signature_url
     FROM companies
     WHERE company_id = $1
     LIMIT 1`,
    [userId],
  );

  if (existingAssetResult.rows[0]) {
    return existingAssetResult.rows[0];
  }

  const userResult = await query(
    `SELECT full_name, email
     FROM users
     WHERE user_id = $1
     LIMIT 1`,
    [userId],
  );
  const user = userResult.rows[0];
  if (!user) {
    return null;
  }

  const fallbackCompanyName =
    `${user.full_name || ''}`.trim() ||
    `${user.email || ''}`.trim() ||
    'Company';

  await query(
    `INSERT INTO companies (company_id, company_name)
     VALUES ($1, $2)
     ON CONFLICT (company_id) DO NOTHING`,
    [userId, fallbackCompanyName],
  );

  const createdCompanyResult = await query(
    `SELECT logo_url, stamp_url, signature_url
     FROM companies
     WHERE company_id = $1
     LIMIT 1`,
    [userId],
  );

  return createdCompanyResult.rows[0] || null;
};

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

    const existingCompany = await ensureCompanyProfileExists(req.user.user_id);

    if (!existingCompany) {
      return res.status(404).json({
        success: false,
        message: 'Company profile not found. Please complete company setup first.',
      });
    }

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

    const updateResult = await query(
      `UPDATE companies
       SET ${dbColumn} = $1
       WHERE company_id = $2
       RETURNING logo_url, stamp_url, signature_url`,
      [assetUrl, req.user.user_id],
    );
    const updatedCompany = updateResult.rows[0];

    if (!updatedCompany) {
      return res.status(500).json({
        success: false,
        message: `Failed to save ${fieldLabel.toLowerCase()} to company profile`,
      });
    }

    const previousAssetUrl = existingCompany[dbColumn];
    if (previousAssetUrl && previousAssetUrl !== assetUrl) {
      await deleteAssetByUrl({
        fileUrl: previousAssetUrl,
        resourceType: 'image',
      }).catch(() => false);
    }

    return res.json({
      success: true,
      message: `${fieldLabel} uploaded successfully`,
      data: {
        [formFieldName]: assetUrl,
        company: updatedCompany,
      },
    });
  } catch (error) {
    console.error(`Upload ${fieldLabel.toLowerCase()} error:`, error);
    return res.status(500).json({
      success: false,
      message: error.message || `Failed to upload ${fieldLabel.toLowerCase()}`,
    });
  }
};

router.get(
  '/university-chats',
  authMiddleware,
  authorize('company'),
  universityOrganizationChatController.getCompanyUniversityChats,
);

router.get(
  '/university-chats/:universityUserId/messages',
  authMiddleware,
  authorize('company'),
  universityOrganizationChatController.getCompanyChatMessages,
);

router.post(
  '/university-chats/:universityUserId/messages',
  authMiddleware,
  authorize('company'),
  universityOrganizationChatController.sendCompanyChatMessage,
);

router.delete(
  '/university-chats/:universityUserId/messages/:messageId',
  authMiddleware,
  authorize('company'),
  universityOrganizationChatController.deleteCompanyChatMessage,
);

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
