const crypto = require('crypto');
const { v2: cloudinary } = require('cloudinary');
const fs = require('fs');
const path = require('path');

const CLOUDINARY_API_BASE = 'https://api.cloudinary.com/v1_1';
const CLOUDINARY_DELIVERY_HOST = 'res.cloudinary.com';

const isCloudinaryConfigured = () => {
    return Boolean(
        process.env.CLOUDINARY_CLOUD_NAME &&
            process.env.CLOUDINARY_API_KEY &&
            process.env.CLOUDINARY_API_SECRET
    );
};

const configureCloudinarySdk = () => {
    if (!isCloudinaryConfigured()) {
        return;
    }

    cloudinary.config({
        cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
        api_key: process.env.CLOUDINARY_API_KEY,
        api_secret: process.env.CLOUDINARY_API_SECRET,
        secure: true
    });
};

const ensureDirectory = (dirPath) => {
    if (!fs.existsSync(dirPath)) {
        fs.mkdirSync(dirPath, { recursive: true });
    }
};

const normalizePublicIdBase = (value) => {
    return `${value || ''}`
        .trim()
        .toLowerCase()
        .replace(/[^a-z0-9._/-]+/g, '-')
        .replace(/-+/g, '-')
        .replace(/^[-/.]+|[-/.]+$/g, '');
};

const buildSignature = (params, apiSecret) => {
    const serialized = Object.entries(params)
        .filter(([, value]) => value !== undefined && value !== null && value !== '')
        .sort(([left], [right]) => left.localeCompare(right))
        .map(([key, value]) => `${key}=${value}`)
        .join('&');

    return crypto
        .createHash('sha1')
        .update(`${serialized}${apiSecret}`)
        .digest('hex');
};

const toDataUri = (buffer, mimeType) => {
    return `data:${mimeType};base64,${buffer.toString('base64')}`;
};

const buildLocalUrl = (segments) => {
    return `/${segments.map((segment) => `${segment}`.replace(/^\/+|\/+$/g, '')).join('/')}`;
};

const saveFileLocally = ({
    buffer,
    uploadSubdir,
    fileName,
}) => {
    const uploadRoot = path.join(__dirname, '../../uploads');
    const destinationDir = path.join(uploadRoot, uploadSubdir);
    ensureDirectory(destinationDir);

    const absolutePath = path.join(destinationDir, fileName);
    fs.writeFileSync(absolutePath, buffer);

    return {
        secureUrl: buildLocalUrl(['uploads', uploadSubdir, fileName]),
        publicId: null,
        storage: 'local'
    };
};

const uploadToCloudinary = async ({
    buffer,
    mimeType,
    folder,
    publicId,
    resourceType
}) => {
    const timestamp = Math.floor(Date.now() / 1000);
    const params = {
        folder,
        public_id: publicId,
        overwrite: 'true',
        timestamp
    };

    const signature = buildSignature(params, process.env.CLOUDINARY_API_SECRET);
    const payload = new URLSearchParams({
        file: toDataUri(buffer, mimeType),
        api_key: process.env.CLOUDINARY_API_KEY,
        folder,
        public_id: publicId,
        overwrite: 'true',
        timestamp: `${timestamp}`,
        signature
    });

    const response = await fetch(
        `${CLOUDINARY_API_BASE}/${process.env.CLOUDINARY_CLOUD_NAME}/${resourceType}/upload`,
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: payload
        }
    );

    let data = null;
    try {
        data = await response.json();
    } catch (error) {
        data = null;
    }

    if (!response.ok) {
        throw new Error(
            data?.error?.message || `Cloudinary upload failed with status ${response.status}`
        );
    }

    return {
        secureUrl: data.secure_url || data.url,
        publicId: data.public_id,
        storage: 'cloudinary'
    };
};

const uploadAsset = async ({
    buffer,
    mimeType,
    originalName,
    localSubdir,
    fileNamePrefix,
    cloudinaryFolder,
    cloudinaryResourceType
}) => {
    const ext = path.extname(originalName || '').toLowerCase();
    const baseName = normalizePublicIdBase(path.basename(originalName || 'file', ext)) || fileNamePrefix;
    const uniqueSuffix = `${Date.now()}-${Math.round(Math.random() * 1e9)}`;
    const localFileName = `${fileNamePrefix}-${uniqueSuffix}${ext}`;

    if (!isCloudinaryConfigured()) {
        return saveFileLocally({
            buffer,
            uploadSubdir: localSubdir,
            fileName: localFileName
        });
    }

    const resourceType = cloudinaryResourceType;
    const publicIdBase = normalizePublicIdBase(`${fileNamePrefix}-${baseName}-${uniqueSuffix}`);
    const publicId =
        resourceType === 'raw' && ext
            ? `${publicIdBase}${ext}`
            : publicIdBase;

    return uploadToCloudinary({
        buffer,
        mimeType,
        folder: cloudinaryFolder,
        publicId,
        resourceType
    });
};

const extractCloudinaryPublicId = (fileUrl, resourceType) => {
    try {
        const parsed = new URL(fileUrl);
        if (parsed.hostname !== CLOUDINARY_DELIVERY_HOST) {
            return null;
        }

        const segments = parsed.pathname.split('/').filter(Boolean);
        const uploadIndex = segments.findIndex((segment) => segment === 'upload');
        if (uploadIndex === -1) {
            return null;
        }

        let publicIdSegments = segments.slice(uploadIndex + 1);
        if (publicIdSegments[0] && /^v\d+$/.test(publicIdSegments[0])) {
            publicIdSegments = publicIdSegments.slice(1);
        }

        const joined = publicIdSegments.join('/');
        if (!joined) {
            return null;
        }

        if (resourceType === 'image') {
            return joined.replace(/\.[^/.]+$/, '');
        }

        return joined;
    } catch (error) {
        return null;
    }
};

const extractCloudinaryDownloadParts = (fileUrl) => {
    try {
        const parsed = new URL(fileUrl);
        if (parsed.hostname !== CLOUDINARY_DELIVERY_HOST) {
            return null;
        }

        const segments = parsed.pathname.split('/').filter(Boolean);
        if (segments.length < 4) {
            return null;
        }

        const [, resourceType, deliveryType] = segments;
        const uploadIndex = segments.findIndex((segment) => segment === deliveryType);
        if (uploadIndex === -1) {
            return null;
        }

        let publicIdSegments = segments.slice(uploadIndex + 1);
        if (publicIdSegments[0] && /^v\d+$/.test(publicIdSegments[0])) {
            publicIdSegments = publicIdSegments.slice(1);
        }

        const fullPublicId = publicIdSegments.join('/');
        if (!fullPublicId) {
            return null;
        }

        const ext = path.extname(fullPublicId).replace('.', '').toLowerCase();
        const publicId = ext
            ? fullPublicId.slice(0, -(ext.length + 1))
            : fullPublicId;

        if (!publicId || !ext) {
            return null;
        }

        return {
            publicId,
            format: ext,
            resourceType,
            deliveryType
        };
    } catch (error) {
        return null;
    }
};

const buildCloudinarySignedDownloadUrl = (fileUrl) => {
    if (!isCloudinaryConfigured()) {
        return null;
    }

    const parts = extractCloudinaryDownloadParts(fileUrl);
    if (!parts) {
        return null;
    }

    configureCloudinarySdk();

    return cloudinary.utils.private_download_url(parts.publicId, parts.format, {
        resource_type: parts.resourceType,
        type: parts.deliveryType,
        expires_at: Math.floor(Date.now() / 1000) + 300,
        attachment: false
    });
};

const destroyOnCloudinary = async ({ publicId, resourceType }) => {
    if (!publicId || !isCloudinaryConfigured()) {
        return false;
    }

    const timestamp = Math.floor(Date.now() / 1000);
    const params = {
        invalidate: 'true',
        public_id: publicId,
        timestamp
    };

    const signature = buildSignature(params, process.env.CLOUDINARY_API_SECRET);
    const payload = new URLSearchParams({
        api_key: process.env.CLOUDINARY_API_KEY,
        invalidate: 'true',
        public_id: publicId,
        timestamp: `${timestamp}`,
        signature
    });

    const response = await fetch(
        `${CLOUDINARY_API_BASE}/${process.env.CLOUDINARY_CLOUD_NAME}/${resourceType}/destroy`,
        {
            method: 'POST',
            headers: {
                'Content-Type': 'application/x-www-form-urlencoded'
            },
            body: payload
        }
    );

    if (!response.ok) {
        return false;
    }

    return true;
};

const deleteAssetByUrl = async ({ fileUrl, resourceType }) => {
    if (!fileUrl) {
        return false;
    }

    if (
        fileUrl.startsWith('http://') ||
        fileUrl.startsWith('https://')
    ) {
        const publicId = extractCloudinaryPublicId(fileUrl, resourceType);
        return destroyOnCloudinary({ publicId, resourceType });
    }

    const normalizedPath = `${fileUrl}`.replace(/^\/+/, '');
    const absolutePath = path.join(__dirname, '../../', normalizedPath);
    if (fs.existsSync(absolutePath)) {
        fs.unlinkSync(absolutePath);
        return true;
    }

    return false;
};

const readBinaryFromUrl = async (fileUrl) => {
    if (!fileUrl) {
        throw new Error('File URL is required');
    }

    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
        const response = await fetch(fileUrl);
        if (!response.ok) {
            const signedUrl = buildCloudinarySignedDownloadUrl(fileUrl);
            if (signedUrl) {
                const signedResponse = await fetch(signedUrl);
                if (signedResponse.ok) {
                    const signedArrayBuffer = await signedResponse.arrayBuffer();
                    return Buffer.from(signedArrayBuffer);
                }
            }

            throw new Error(`Failed to fetch asset: ${response.status}`);
        }

        const arrayBuffer = await response.arrayBuffer();
        return Buffer.from(arrayBuffer);
    }

    const normalizedPath = `${fileUrl}`.replace(/^\/+/, '');
    const absolutePath = path.join(__dirname, '../../', normalizedPath);
    return fs.readFileSync(absolutePath);
};

const readAssetBuffer = async (fileUrl) => {
    const buffer = await readBinaryFromUrl(fileUrl);
    return Buffer.isBuffer(buffer) ? buffer : Buffer.from(buffer || '');
};

module.exports = {
    isCloudinaryConfigured,
    readAssetBuffer,
    uploadAsset,
    deleteAssetByUrl
};
