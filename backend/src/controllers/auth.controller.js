// src/controllers/auth.controller.js
const UserModel = require('../models/user.model');
const bcrypt = require('bcryptjs');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');
const { query } = require('../config/database');
const {
    sendPasswordResetEmail,
    sendPasswordChangedEmail
} = require('../services/email.service');
const { logAuditEvent } = require('../services/audit-log.service');
const { uploadAsset, deleteAssetByUrl } = require('../services/file-storage.service');

const queueAuditEvent = (payload) => {
    void logAuditEvent(payload);
};

const TCU_REGISTERED_ = [
    { name: 'University of Dar es Salaam (UDSM)', location: 'Dar es Salaam' },
    { name: 'Sokoine University of Agriculture (SUA)', location: 'Morogoro' },
    { name: 'Open University of Tanzania (OUT)', location: 'Dar es Salaam' },
    { name: 'State University of Zanzibar (SUZA)', location: 'Zanzibar' },
    { name: 'Mzumbe University (MU)', location: 'Morogoro' },
    {
        name: 'Nelson Mandela African Institution of Science and Technology (NM-AIST)',
        location: 'Arusha',
        aliases: ['Nelson Mandela African Institute of Science and Technology']
    },
    {
        name: 'Muhimbili University of Health and Allied Sciences (MUHAS)',
        location: 'Dar es Salaam'
    },
    { name: 'Ardhi University (ARU)', location: 'Dar es Salaam' },
    { name: 'University of Dodoma (UDOM)', location: 'Dodoma' },
    { name: 'Mbeya University of Science and Technology (MUST)', location: 'Mbeya' },
    {
        name: 'Moshi Cooperative University (MoCU)',
        location: 'Moshi',
        aliases: ['Moshi Co-operative University']
    },
    {
        name: 'Mwalimu Nyerere University of Agriculture and Technology (MNUAT)',
        location: 'Musoma'
    },
    {
        name: 'Kairuki University (KU), formerly HKMU',
        location: 'Dar es Salaam',
        aliases: ['Hubert Kairuki Memorial University']
    },
    { name: 'Abdulrahman Al-Sumait University (SUMAIT)', location: 'Zanzibar' },
    { name: 'St. Augustine University of Tanzania (SAUT)', location: 'Mwanza' },
    { name: 'Zanzibar University (ZU)', location: 'Zanzibar' },
    { name: 'Tumaini University Makumira (TUMA)', location: 'Arusha' },
    { name: 'Aga Khan University (AKU)', location: 'Dar es Salaam' },
    {
        name: 'Catholic University of Health and Allied Sciences (CUHAS)',
        location: 'Mwanza'
    },
    { name: 'University of Arusha (UoA)', location: 'Arusha' },
    { name: 'St. Augustine University of Tanzania, Arusha Centre', location: 'Arusha' },
    { name: 'St. Joseph University in Tanzania (SJUIT)', location: 'Dar es Salaam' },
    { name: 'Teofilo Kisanji University (TEKU)', location: 'Mbeya' },
    { name: 'Mwenge Catholic University (MWECAU)', location: 'Moshi' },
    { name: 'Muslim University of Morogoro (MUM)', location: 'Morogoro' },
    { name: 'University of Iringa (UoI)', location: 'Iringa' },
    { name: "St. John's University of Tanzania (SJUT)", location: 'Dodoma' },
    { name: 'Kampala International University in Tanzania (KIUT)', location: 'Dar es Salaam' },
    { name: 'United African University of Tanzania (UAUT)', location: 'Dar es Salaam' },
    { name: 'Ruaha Catholic University (RUCU)', location: 'Iringa' },
    { name: 'Mwanza University (MzU)', location: 'Mwanza' },
    {
        name: 'Catholic University of Mbeya (CUoM), formerly CUCoM',
        location: 'Mbeya'
    },
    {
        name: 'Dar es Salaam Tumaini University (DarTU), formerly TUDARCo',
        location: 'Dar es Salaam'
    },
    {
        name: 'Rabininsia Memorial University of Health and Allied Sciences (RMUHAS)',
        location: 'Dar es Salaam'
    },
    {
        name: 'University of Medical Sciences and Technology (UMST)',
        location: 'Dar es Salaam'
    },
    { name: 'Islamic University of East Africa (IUEA)', location: 'Dar es Salaam' },
    { name: 'Hikmah University of East Africa (HUEA)', location: 'Dar es Salaam' },
    { name: 'KCMC University', location: 'Moshi' },
    { name: 'Dar es Salaam University College of Education (DUCE)', location: 'Dar es Salaam' },
    { name: 'Institute of Marine Sciences (IMS)', location: 'Zanzibar' },
    { name: 'Mkwawa University College of Education (MUCE)', location: 'Iringa' },
    {
        name: 'Mzumbe University - Dar es Salaam Campus College (MU - Dar es Salaam Campus College)',
        location: 'Dar es Salaam'
    },
    {
        name: 'St. Augustine University of Tanzania, Dar es Salaam Centre',
        location: 'Dar es Salaam'
    },
    {
        name: 'Mzumbe University - Mbeya Campus College (MU - Mbeya Campus College)',
        location: 'Mbeya'
    },
    { name: 'Mbeya College of Health and Allied Sciences (MCHAS)', location: 'Mbeya' },
    {
        name: 'Mbeya University of Science and Technology - Rukwa Campus College (MUST - RC)',
        location: 'Rukwa'
    },
    {
        name: 'Sokoine University of Agriculture - Mizengo Pinda Campus College (SUA - MPC)',
        location: 'Katavi'
    },
    {
        name: 'Mbeya University of Science and Technology - Mtwara Campus College of Technical Education (MUST - MCCTE)',
        location: 'Mtwara'
    },
    { name: 'Stefano Moshi Memorial University College (SMMUCo)', location: 'Moshi' },
    { name: 'Archbishop Mihayo University College of Tabora (AMUCTA)', location: 'Tabora' },
    { name: 'Jordan University College (JUCo)', location: 'Morogoro' },
    {
        name: 'St. Francis University College of Health and Allied Sciences (SFUCHAS)',
        location: 'Morogoro'
    },
    {
        name: 'Stefano Moshi Memorial University College, Mwika Centre',
        location: 'Moshi'
    },
    { name: 'Stella Maris Mtwara University College (STeMMUCo)', location: 'Mtwara' },
    { name: 'Marian University College (MARUCo)', location: 'Bagamoyo' },
    {
        name: 'St. Joseph University College of Health and Allied Sciences (SJCHAS)',
        location: 'Dar es Salaam'
    },
    {
        name: 'Kizumbi Institute of Cooperative Business Education (KICoB)',
        location: 'Shinyanga'
    },
    {
        name: 'Mwenge Catholic University, Hedaru Campus College (MWECAU-HCC)',
        location: 'Same, Kilimanjaro'
    }
];

const GOVERNMENT_REGISTERED_ = [
    { name: "President's Office - Regional Administration and Local Government", location: 'Dodoma' },
    { name: "President's Office - Public Service Management and Good Governance", location: 'Dodoma' },
    { name: "Prime Minister's Office", location: 'Dodoma' },
    { name: 'Ministry Headquarters', location: 'Dodoma' },
    { name: 'Regional Secretariat', location: 'All Regions' },
    { name: 'Regional Commissioner Office', location: 'All Regions' },
    { name: 'District Commissioner Office', location: 'All Districts' },
    { name: 'District Executive Director Office', location: 'All District Councils' },
    { name: 'City Council Headquarters', location: 'City Councils' },
    { name: 'Municipal Council Headquarters', location: 'Municipal Councils' },
    { name: 'Town Council Headquarters', location: 'Town Councils' },
    { name: 'District Council Headquarters', location: 'District Councils' },
    { name: 'Ward Executive Office', location: 'All Wards' },
    { name: 'Village Executive Office', location: 'All Villages' },
    { name: 'Government Agency Headquarters', location: 'Nationwide' },
    { name: 'Government Authority Headquarters', location: 'Nationwide' },
    { name: 'Government Commission Office', location: 'Nationwide' },
    { name: 'Public Institution Headquarters', location: 'Nationwide' },
    { name: 'Public Hospital Administration', location: 'Nationwide' },
    { name: 'Regional Referral Hospital Administration', location: 'Regional Hospitals' },
    { name: 'District Hospital Administration', location: 'District Hospitals' },
    { name: 'Police Regional Office', location: 'All Regions' },
    { name: 'Police District Office', location: 'All Districts' },
    { name: 'Immigration Regional Office', location: 'All Regions' },
    { name: 'TRA Regional Office', location: 'All Regions' },
    { name: 'Public School Administration', location: 'Nationwide' }
];

const UNIVERSITY_INSTITUTION_NAMES = TCU_REGISTERED_.map(({ name }) =>
    name.toLowerCase()
);
const GOVERNMENT_INSTITUTION_NAMES = GOVERNMENT_REGISTERED_.map(({ name }) =>
    name.toLowerCase()
);
const REGISTERABLE_INSTITUTION_NAMES = [
    ...UNIVERSITY_INSTITUTION_NAMES,
    ...GOVERNMENT_INSTITUTION_NAMES
];
const DEFAULT_REGISTERABLE_ = [
    ...TCU_REGISTERED_,
    ...GOVERNMENT_REGISTERED_
];

const PDF_FILE_SIGNATURE = Buffer.from('%PDF-', 'utf8');
const IDENTIFICATION_CARD_PDF_ONLY_MESSAGE =
    'Only PDF files are allowed for identification cards.';
const ORGANIZATION_SUBTYPES = new Set(['private_sector', 'government_sector']);
const GOVERNMENT_SECTOR_CATEGORIES = new Set([
    'Ministry',
    'Department / Agency',
    'Authority',
    'Commission',
    'Regional Secretariat',
    'Local Government Authority',
    'Public Institution',
    'Hospital / Health Facility',
    'School / College',
    'Security / Immigration / Revenue'
]);

const isPdfFileUpload = (file) => {
    if (!file) {
        return false;
    }

    const originalName = `${file.originalname || ''}`.trim().toLowerCase();
    const mimeType = `${file.mimetype || ''}`.trim().toLowerCase();
    const fileBuffer = Buffer.isBuffer(file.buffer) ? file.buffer : null;
    const hasPdfExtension = originalName.endsWith('.pdf');
    const hasPdfMimeType =
        mimeType === 'application/pdf' || mimeType === 'application/octet-stream';
    const hasPdfHeader =
        fileBuffer &&
        fileBuffer.length >= PDF_FILE_SIGNATURE.length &&
        fileBuffer
            .subarray(0, PDF_FILE_SIGNATURE.length)
            .equals(PDF_FILE_SIGNATURE);

    return hasPdfExtension && hasPdfMimeType && hasPdfHeader;
};

const normalizeNamePart = (value) => `${value || ''}`.trim();
const normalizeCompanySubtype = (value) => {
    const normalized = `${value || ''}`
        .trim()
        .toLowerCase()
        .replace(/\s+/g, '_');

    return normalized || '';
};

const buildFullName = ({ firstName, secondName, fallbackFullName }) => {
    const parts = [normalizeNamePart(firstName), normalizeNamePart(secondName)].filter(Boolean);
    if (parts.length > 0) {
        return parts.join(' ');
    }

    return normalizeNamePart(fallbackFullName);
};

const splitFullName = (value) => {
    const normalized = normalizeNamePart(value);
    if (!normalized) {
        return {
            first_name: '',
            second_name: ''
        };
    }

    const parts = normalized.split(/\s+/).filter(Boolean);
    return {
        first_name: parts[0] || '',
        second_name: parts.slice(1).join(' ')
    };
};

const annotateInstitution = (institution) => {
    const name = `${institution?.name || ''}`.trim();
    const normalizedName = name.toLowerCase();
    const category = UNIVERSITY_INSTITUTION_NAMES.includes(normalizedName)
        ? 'university'
        : GOVERNMENT_INSTITUTION_NAMES.includes(normalizedName)
          ? 'government'
          : 'institution';

    return {
        ...institution,
        category,
        ...splitFullName(name)
    };
};

const fetchOfficial = async (institutionNames) => {
    const result = await query(
        `SELECT university_id, name, location
         FROM (
             SELECT DISTINCT ON (LOWER(name))
                 university_id,
                 name,
                 location
             FROM universities
             WHERE LOWER(name) = ANY($1::text[])
             ORDER BY LOWER(name), university_id
         ) official_
         ORDER BY name`,
        [institutionNames]
    );

    return result.rows.map(annotateInstitution);
};

const fetchAllUniversity = async () => {
    const result = await query(
        `SELECT university_id, name, location
         FROM (
             SELECT DISTINCT ON (LOWER(name))
                 university_id,
                 name,
                 location
             FROM universities
             WHERE LOWER(name) <> ALL($1::text[])
               AND TRIM(COALESCE(name, '')) <> ''
             ORDER BY LOWER(name), university_id
         ) official_
         ORDER BY name`,
        [GOVERNMENT_INSTITUTION_NAMES]
    );

    return result.rows.map((institution) => ({
        ...annotateInstitution(institution),
        category: 'university'
    }));
};

const ensureDefault = async () => {
    for (const institution of DEFAULT_REGISTERABLE_) {
        const matchNames = [institution.name, ...(institution.aliases || [])].map((value) =>
            value.toLowerCase()
        );

        const existingResult = await query(
            `SELECT university_id, name, location
             FROM universities
             WHERE LOWER(name) = ANY($1::text[])
             ORDER BY CASE WHEN LOWER(name) = LOWER($2) THEN 0 ELSE 1 END, university_id ASC
             LIMIT 1`,
            [matchNames, institution.name]
        );

        const existingInstitution = existingResult.rows[0];
        if (existingInstitution) {
            if (
                existingInstitution.name !== institution.name ||
                existingInstitution.location !== institution.location
            ) {
                await query(
                    'UPDATE universities SET name = $1, location = $2 WHERE university_id = $3',
                    [institution.name, institution.location, existingInstitution.university_id]
                );
            }
            continue;
        }

        await query('INSERT INTO universities (name, location) VALUES ($1, $2)', [
            institution.name,
            institution.location
        ]);
    }
};

// Generate JWT Token
const generateToken = (userId, email, role, authVersion = 0) => {
    const normalizedAuthVersion = Number.parseInt(`${authVersion ?? 0}`, 10);
    return jwt.sign(
        {
            user_id: userId,
            email,
            role,
            auth_version: Number.isNaN(normalizedAuthVersion)
                ? 0
                : normalizedAuthVersion
        },
        process.env.JWT_SECRET,
        { expiresIn: process.env.JWT_EXPIRES_IN || '7d' }
    );
};

const PASSWORD_RESET_TABLE_SQL = `
    CREATE TABLE IF NOT EXISTS password_reset_tokens (
        token_id SERIAL PRIMARY KEY,
        user_id UUID NOT NULL REFERENCES users(user_id) ON DELETE CASCADE,
        token_hash TEXT NOT NULL,
        expires_at TIMESTAMPTZ NOT NULL,
        used_at TIMESTAMPTZ,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    )
`;

const ensurePasswordResetTable = async () => {
    await query(PASSWORD_RESET_TABLE_SQL);
};

const hashResetToken = (token) => {
    return crypto.createHash('sha256').update(token).digest('hex');
};

const normalizeBaseUrl = (value) => `${value || ''}`.trim().replace(/\/+$/, '');

const getRequestBaseUrl = (req) => {
    const origin = normalizeBaseUrl(req.headers.origin);
    if (origin) {
        return origin;
    }

    const forwardedProto = `${req.headers['x-forwarded-proto'] || ''}`
        .split(',')[0]
        .trim();
    const forwardedHost = `${req.headers['x-forwarded-host'] || req.headers.host || ''}`
        .split(',')[0]
        .trim();

    if (!forwardedHost) {
        return '';
    }

    const protocol =
        forwardedProto ||
        req.protocol ||
        (process.env.NODE_ENV === 'production' ? 'https' : 'http');

    return normalizeBaseUrl(`${protocol}://${forwardedHost}`);
};

const getPasswordResetBaseUrl = (req) => {
    const configuredBaseUrl = normalizeBaseUrl(
        process.env.RESET_PASSWORD_BASE_URL || process.env.PUBLIC_API_URL
    );

    if (configuredBaseUrl) {
        return configuredBaseUrl;
    }

    const requestBaseUrl = getRequestBaseUrl(req);
    if (requestBaseUrl) {
        return requestBaseUrl;
    }

    return normalizeBaseUrl(`http://localhost:${process.env.PORT || 5000}`);
};

const shouldExposeResetDebugData = () => {
    const flag = `${process.env.EXPOSE_RESET_DEBUG_LINKS || ''}`
        .trim()
        .toLowerCase();

    if (['1', 'true', 'yes', 'on'].includes(flag)) {
        return true;
    }

    return process.env.NODE_ENV !== 'production';
};

const buildPasswordResetDebugResponse = ({
    resetLink,
    rawToken,
    genericMessage,
    emailError
}) => {
    if (!shouldExposeResetDebugData()) {
        return {
            statusCode: 503,
            body: {
                success: false,
                message: 'Unable to send password reset email right now. Please try again later.'
            }
        };
    }

    const debugMessage =
        emailError?.message
            ? `Email delivery failed on the server. Use the reset link below instead. (${emailError.message})`
            : `${genericMessage} Email delivery is unavailable right now, so use the reset link below instead.`;

    return {
        statusCode: 200,
        body: {
            success: true,
            message: debugMessage,
            debugResetLink: resetLink,
            debugResetToken: rawToken,
            emailSent: false
        }
    };
};

const prefersJsonResponse = (req) => {
    const contentType = `${req.headers['content-type'] || ''}`.toLowerCase();
    const accept = `${req.headers.accept || ''}`.toLowerCase();
    return contentType.includes('application/json') || accept.includes('application/json');
};

const sendResetResponse = (
    req,
    res,
    {
        statusCode = 200,
        success,
        title,
        subtitle,
        token = '',
        isSuccess = false
    }
) => {
    if (prefersJsonResponse(req)) {
        return res.status(statusCode).json({
            success,
            title,
            message: subtitle
        });
    }

    return res.status(statusCode).send(
        renderResetPasswordPage({
            title,
            subtitle,
            token,
            isSuccess
        })
    );
};

const renderResetPasswordPage = ({
    title,
    subtitle,
    token = '',
    isSuccess = false
}) => {
    const primaryBlue = '#1e3a8a';
    const primaryDark = '#0f172a';
    const accentGold = '#fbbf24';
    const statusColor = isSuccess ? '#059669' : primaryBlue;
    const buttonMarkup = isSuccess
        ? ''
        : `
            <form method="POST" action="/api/auth/reset-password" onsubmit="handleResetSubmit(event)" style="display: grid; gap: 16px;">
                <input type="hidden" name="token" value="${token}">
                <label style="display: grid; gap: 6px; font-weight: 600; color: #1f2937;">
                    New password
                    <div style="display: flex; align-items: center; border: 1px solid #cbd5e1; border-radius: 12px; background: #fff; overflow: hidden;">
                        <input
                            id="password"
                            type="password"
                            name="password"
                            minlength="6"
                            required
                            style="flex: 1; padding: 14px 16px; border: none; outline: none; font-size: 14px;"
                        >
                        <button
                            type="button"
                            onclick="togglePassword('password', this)"
                            style="border: none; border-left: 1px solid #e5e7eb; background: #eff6ff; color: ${primaryBlue}; padding: 14px 16px; font-weight: 700; cursor: pointer;"
                        >
                            Show
                        </button>
                    </div>
                </label>
                <label style="display: grid; gap: 6px; font-weight: 600; color: #1f2937;">
                    Confirm password
                    <div style="display: flex; align-items: center; border: 1px solid #cbd5e1; border-radius: 12px; background: #fff; overflow: hidden;">
                        <input
                            id="confirmPassword"
                            type="password"
                            name="confirmPassword"
                            minlength="6"
                            required
                            style="flex: 1; padding: 14px 16px; border: none; outline: none; font-size: 14px;"
                        >
                        <button
                            type="button"
                            onclick="togglePassword('confirmPassword', this)"
                            style="border: none; border-left: 1px solid #e5e7eb; background: #eff6ff; color: ${primaryBlue}; padding: 14px 16px; font-weight: 700; cursor: pointer;"
                        >
                            Show
                        </button>
                    </div>
                </label>
                <button
                    id="reset-submit-button"
                    type="submit"
                    style="padding: 14px 16px; border: none; border-radius: 12px; background: linear-gradient(135deg, ${primaryBlue}, ${primaryDark}); color: #fff; font-weight: 700; cursor: pointer; letter-spacing: 0.02em;"
                >
                    Reset password
                </button>
                <p id="reset-submit-status" style="display: none; margin: 0; color: #475569; font-size: 13px;">
                    Updating your password...
                </p>
            </form>
        `;

    return `
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Reset Password</title>
        </head>
        <body style="margin: 0; font-family: Arial, sans-serif; background: linear-gradient(180deg, #eaf1ff 0%, #f8fafc 45%, #eef2ff 100%); color: #0f172a;">
            <div style="min-height: 100vh; display: grid; place-items: center; padding: 24px;">
                <div style="width: 100%; max-width: 440px; background: white; border-radius: 24px; box-shadow: 0 24px 60px rgba(15, 23, 42, 0.16); overflow: hidden; border: 1px solid rgba(30, 58, 138, 0.08);">
                    <div style="padding: 24px 28px; background: linear-gradient(135deg, ${primaryBlue}, ${primaryDark}); color: white;">
                        <div style="display: inline-flex; align-items: center; gap: 12px;">
                            <div style="width: 52px; height: 52px; border-radius: 16px; background: rgba(251, 191, 36, 0.18); color: ${accentGold}; display: grid; place-items: center; font-size: 18px; font-weight: 800;">
                                IGS
                            </div>
                            <div>
                                <div style="font-size: 13px; letter-spacing: 0.08em; text-transform: uppercase; color: rgba(255,255,255,0.75);">Student Job Platform</div>
                                <div style="font-size: 22px; font-weight: 700; margin-top: 4px;">${title}</div>
                            </div>
                        </div>
                    </div>
                    <div style="padding: 28px;">
                        <div style="width: 56px; height: 56px; border-radius: 18px; background: rgba(30, 58, 138, 0.1); color: ${statusColor}; display: grid; place-items: center; font-size: 24px; font-weight: 700; margin-bottom: 18px;">
                            ${isSuccess ? '✓' : '🔒'}
                        </div>
                        <p style="margin: 0 0 22px; color: #475569; line-height: 1.7;">${subtitle}</p>
                        ${!isSuccess ? '<p style="margin: 0 0 18px; color: #64748b; font-size: 13px;">Use at least 6 characters. You can tap Show to confirm what you typed.</p>' : ''}
                        ${buttonMarkup}
                    </div>
                </div>
            </div>
            <script>
                function togglePassword(id, button) {
                    var input = document.getElementById(id);
                    if (!input) return;
                    var show = input.type === 'password';
                    input.type = show ? 'text' : 'password';
                    button.textContent = show ? 'Hide' : 'Show';
                }

                function handleResetSubmit(event) {
                    var form = event.target;
                    if (!form || typeof form.checkValidity !== 'function') {
                        return true;
                    }

                    if (!form.checkValidity()) {
                        return true;
                    }

                    var button = document.getElementById('reset-submit-button');
                    var status = document.getElementById('reset-submit-status');
                    if (button) {
                        button.disabled = true;
                        button.textContent = 'Updating...';
                        button.style.opacity = '0.8';
                        button.style.cursor = 'progress';
                    }
                    if (status) {
                        status.style.display = 'block';
                    }
                    return true;
                }
            </script>
        </body>
        </html>
    `;
};

// Register User
const register = async (req, res) => {
    let uploadedIdentificationCard = null;
    let uploadedCollegeLogo = null;

    try {
        const userData = req.body;
        const requestedRole = `${userData.role || ''}`.trim().toLowerCase();
        const normalizedRole = requestedRole === 'institution' ? 'university' : requestedRole;
        const allowedRoles = new Set(['student', 'company', 'university']);
        const identificationCardFile = req.files?.identification_card?.[0] || null;
        const collegeLogoFile = req.files?.college_logo?.[0] || null;

        if (!allowedRoles.has(normalizedRole)) {
            return res.status(403).json({
                success: false,
                message: 'This account type cannot be registered from the app'
            });
        }

        userData.role = normalizedRole;

        if (normalizedRole === 'student') {
            userData.first_name = normalizeNamePart(userData.first_name);
            userData.second_name = normalizeNamePart(userData.second_name);
            userData.full_name = buildFullName({
                firstName: userData.first_name,
                secondName: userData.second_name,
                fallbackFullName: userData.full_name
            });

            if (!userData.full_name) {
                return res.status(400).json({
                    success: false,
                    message: 'First name and second name are required for students'
                });
            }

            const registrationNumber = `${userData.registration_number || ''}`.trim();
            if (!registrationNumber) {
                return res.status(400).json({
                    success: false,
                    message: 'Registration number is required for students'
                });
            }

            if (!identificationCardFile) {
                return res.status(400).json({
                    success: false,
                    message: 'Identification card is required for students'
                });
            }

            if (!isPdfFileUpload(identificationCardFile)) {
                return res.status(400).json({
                    success: false,
                    message: IDENTIFICATION_CARD_PDF_ONLY_MESSAGE
                });
            }

            const selectedUniversityId = `${userData.university_id || ''}`.trim();
            if (!selectedUniversityId) {
                return res.status(400).json({
                    success: false,
                    message: 'Institution selection is required for students'
                });
            }

            const selectedUniversityResult = await query(
                `SELECT university_id, name
                 FROM universities
                 WHERE university_id::text = $1
                 LIMIT 1`,
                [selectedUniversityId]
            );

            if (selectedUniversityResult.rows.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Selected institution was not found'
                });
            }

            userData.university_id = selectedUniversityResult.rows[0].university_id;
        }

        if (normalizedRole === 'company') {
            const requiredFields = [
                ['email', 'Email is required'],
                ['password', 'Password is required'],
                ['phone', 'Phone number is required'],
                ['company_name', 'Organization name is required'],
                ['location', 'Location is required']
            ];

            for (const [field, message] of requiredFields) {
                if (`${userData[field] || ''}`.trim() === '') {
                    return res.status(400).json({
                        success: false,
                        message
                    });
                }
            }

            const organizationSubtype = normalizeCompanySubtype(
                userData.organization_subtype
            );
            if (!ORGANIZATION_SUBTYPES.has(organizationSubtype)) {
                return res.status(400).json({
                    success: false,
                    message: 'Organization subtype is required'
                });
            }

            userData.organization_subtype = organizationSubtype;

            if (organizationSubtype === 'private_sector') {
                const privateSectorFields = [
                    ['tin_number', 'TIN number is required for private sector organizations'],
                    ['brela_number', 'BRELA number is required for private sector organizations'],
                    ['business_license_number', 'Business license number is required for private sector organizations']
                ];

                for (const [field, message] of privateSectorFields) {
                    if (`${userData[field] || ''}`.trim() === '') {
                        return res.status(400).json({
                            success: false,
                            message
                        });
                    }
                }

                userData.full_name =
                    `${userData.full_name || ''}`.trim() ||
                    `${userData.company_name || userData.organization_name || ''}`.trim();
                userData.government_category = null;
                userData.department = null;
                userData.sector = null;
                userData.industry = null;
                userData.company_size = null;
            }

            if (organizationSubtype === 'government_sector') {
                const governmentCategory = `${userData.government_category || ''}`.trim();
                if (!governmentCategory) {
                    return res.status(400).json({
                        success: false,
                        message: 'Government category is required for government sector organizations'
                    });
                }

                if (!GOVERNMENT_SECTOR_CATEGORIES.has(governmentCategory)) {
                    return res.status(400).json({
                        success: false,
                        message: 'Selected government category is invalid'
                    });
                }

                const governmentSectorFields = [
                    ['department', 'Department is required for government sector organizations'],
                    ['sector', 'Sector is required for government sector organizations']
                ];

                for (const [field, message] of governmentSectorFields) {
                    if (`${userData[field] || ''}`.trim() === '') {
                        return res.status(400).json({
                            success: false,
                            message
                        });
                    }
                }

                userData.government_category = governmentCategory;
                userData.full_name =
                    `${userData.full_name || ''}`.trim() ||
                    `${userData.company_name || ''}`.trim();
                userData.industry = null;
                userData.company_size = null;
                userData.tin_number = null;
                userData.brela_number = null;
                userData.business_license_number = null;
            }
        }

        if (normalizedRole === 'university') {
            const requiredFields = [
                ['university_id', 'University selection is required'],
                ['college_name', 'College name is required'],
                ['registration_number', 'College registration number is required'],
                ['college_email', 'College email is required'],
                ['college_phone', 'College phone is required'],
                ['address', 'College address is required'],
                ['region', 'College region is required'],
                ['district', 'College district is required'],
                ['coordinator_name', 'Coordinator name is required'],
                ['coordinator_phone', 'Coordinator phone is required'],
                ['coordinator_email', 'Coordinator email is required'],
                ['password', 'Password is required']
            ];

            for (const [field, message] of requiredFields) {
                if (`${userData[field] || ''}`.trim() === '') {
                    return res.status(400).json({
                        success: false,
                        message
                    });
                }
            }

            const selectedUniversityId = `${userData.university_id || ''}`.trim();
            const selectedUniversityResult = await query(
                `SELECT university_id, name
                 FROM universities
                 WHERE university_id::text = $1
                 LIMIT 1`,
                [selectedUniversityId]
            );

            if (selectedUniversityResult.rows.length === 0) {
                return res.status(400).json({
                    success: false,
                    message: 'Selected university was not found'
                });
            }

            const selectedUniversity = selectedUniversityResult.rows[0];

            if (!collegeLogoFile) {
                return res.status(400).json({
                    success: false,
                    message: 'College logo is required for university registration'
                });
            }

            userData.university_id = selectedUniversity.university_id;
            userData.college_name = `${selectedUniversity.name || ''}`.trim();
            userData.email = `${userData.college_email || ''}`.trim().toLowerCase();
            userData.full_name = `${userData.college_name || ''}`.trim();
            userData.phone = `${userData.college_phone || ''}`.trim();
        }
        
        // Check if email already exists
        const emailExists = await UserModel.emailExists(userData.email);
        if (emailExists) {
            return res.status(409).json({
                success: false, 
                message: 'Email already registered' 
            });
        }

        if (identificationCardFile && normalizedRole === 'student') {
            uploadedIdentificationCard = await uploadAsset({
                buffer: identificationCardFile.buffer,
                mimeType: identificationCardFile.mimetype,
                originalName: identificationCardFile.originalname,
                localSubdir: 'student-identification-cards',
                fileNamePrefix: `${`${userData.email || 'student'}`.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-')}-id`,
                cloudinaryFolder: 'student-job-platform/student-identification-cards',
                cloudinaryResourceType: 'raw'
            });

            userData.identification_card_url = uploadedIdentificationCard.secureUrl;
            userData.identification_card_name = identificationCardFile.originalname;
        }

        if (collegeLogoFile && normalizedRole === 'university') {
            uploadedCollegeLogo = await uploadAsset({
                buffer: collegeLogoFile.buffer,
                mimeType: collegeLogoFile.mimetype,
                originalName: collegeLogoFile.originalname,
                localSubdir: 'college-logos',
                fileNamePrefix: `${`${userData.college_name || 'college'}`.trim().toLowerCase().replace(/[^a-z0-9]+/g, '-')}-logo`,
                cloudinaryFolder: 'student-job-platform/college-logos',
                cloudinaryResourceType: 'image'
            });

            userData.logo_url = uploadedCollegeLogo.secureUrl;
            userData.logo_name = collegeLogoFile.originalname;
        }
        
        // Create user
        const newUser = await UserModel.create(userData);
        
        // Generate token
        const token = generateToken(newUser.user_id, newUser.email, newUser.role);
        
        res.status(201).json({
            success: true,
            message: 'Registration successful',
            data: {
                user: newUser,
                token
            }
        });
        
    } catch (error) {
        console.error('Registration error:', error);
        if (uploadedIdentificationCard?.secureUrl) {
            try {
                await deleteAssetByUrl({
                    fileUrl: uploadedIdentificationCard.secureUrl,
                    resourceType: 'raw'
                });
            } catch (cleanupError) {
                console.error('Identification card cleanup error:', cleanupError);
            }
        }
        if (uploadedCollegeLogo?.secureUrl) {
            try {
                await deleteAssetByUrl({
                    fileUrl: uploadedCollegeLogo.secureUrl,
                    resourceType: 'image'
                });
            } catch (cleanupError) {
                console.error('College logo cleanup error:', cleanupError);
            }
        }
        res.status(500).json({ 
            success: false, 
            message: 'Registration failed', 
            error: error.message 
        });
    }
};

// Login User
const login = async (req, res) => {
    try {
        const email = `${req.body?.email || ''}`.trim().toLowerCase();
        const password = `${req.body?.password || ''}`;

        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: 'Email and password are required'
            });
        }
        
        // Find user by email
        const user = await UserModel.findByEmail(email);
        if (!user) {
            queueAuditEvent({
                category: 'error',
                eventType: 'Login failed',
                message: `Failed login attempt for ${email || 'unknown email'}`
            });
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
        
        // Check if account is active
        if (!user.is_active) {
            queueAuditEvent({
                category: 'error',
                eventType: 'Login blocked',
                message: `Blocked login attempt for ${user.full_name || user.email}`,
                userInvolved: user.user_id,
                userInvolvedName: user.full_name || user.email
            });
            return res.status(403).json({ 
                success: false, 
                message: 'User blocked. Please contact IT support.' 
            });
        }
        
        // Verify password
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);
        if (!isPasswordValid) {
            queueAuditEvent({
                category: 'error',
                eventType: 'Login failed',
                message: `Incorrect password attempt for ${user.email}`,
                userInvolved: user.user_id,
                userInvolvedName: user.full_name || user.email
            });
            return res.status(401).json({ 
                success: false, 
                message: 'Invalid email or password' 
            });
        }
        
        // Generate token
        const token = generateToken(
            user.user_id,
            user.email,
            user.role,
            user.auth_version
        );
        
        // Get full profile
        const userProfile = await UserModel.findById(user.user_id);

        queueAuditEvent({
            category: 'login',
            eventType: 'User login',
            message: `${userProfile.full_name || user.email} signed in as ${userProfile.role}`,
            actorUserId: user.user_id,
            actorName: userProfile.full_name || user.email,
            userInvolved: user.user_id,
            userInvolvedName: userProfile.full_name || user.email
        });
        
        res.json({
            success: true,
            message: 'Login successful',
            data: {
                user: userProfile,
                token
            }
        });
        
    } catch (error) {
        console.error('Login error:', error);
        queueAuditEvent({
            category: 'error',
            eventType: 'System error',
            message: `Login controller error: ${error.message}`
        });
        res.status(500).json({ 
            success: false, 
            message: 'Login failed', 
            error: error.message 
        });
    }
};

// Get Current User Profile
const getProfile = async (req, res) => {
    try {
        const userId = req.user.user_id; // from auth middleware
        const user = await UserModel.findById(userId);
        
        if (!user) {
            return res.status(404).json({ 
                success: false, 
                message: 'User not found' 
            });
        }
        
        res.json({
            success: true,
            data: user
        });
        
    } catch (error) {
        console.error('Get profile error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to get profile', 
            error: error.message 
        });
    }
};

const changePassword = async (req, res) => {
    try {
        const userId = req.user.user_id;
        const currentPassword = `${req.body?.current_password || ''}`.trim();
        const newPassword = `${req.body?.new_password || ''}`.trim();

        if (!currentPassword) {
            return res.status(400).json({
                success: false,
                message: 'Current password is required'
            });
        }

        if (!newPassword || newPassword.length < 6) {
            return res.status(400).json({
                success: false,
                message: 'New password must be at least 6 characters long'
            });
        }

        const userResult = await query(
            `SELECT user_id, email, full_name, password_hash
             FROM users
             WHERE user_id = $1
             LIMIT 1`,
            [userId]
        );

        const user = userResult.rows[0];
        if (!user) {
            return res.status(404).json({
                success: false,
                message: 'User not found'
            });
        }

        const isPasswordValid = await bcrypt.compare(
            currentPassword,
            user.password_hash
        );
        if (!isPasswordValid) {
            return res.status(400).json({
                success: false,
                message: 'Current password is incorrect'
            });
        }

        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(newPassword, salt);

        await query(
            `UPDATE users
             SET password_hash = $1,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $2`,
            [passwordHash, userId]
        );

        try {
            await sendPasswordChangedEmail({
                to: user.email,
                userName: user.full_name
            });
        } catch (emailError) {
            console.error('Change password email error:', emailError);
        }

        return res.json({
            success: true,
            message: 'Password changed successfully'
        });
    } catch (error) {
        console.error('Change password error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to change password'
        });
    }
};

// Update Profile
const updateProfile = async (req, res) => {
    let uploadedIdentificationCard = null;
    let previousIdentificationCardUrl = null;

    try {
        const userId = req.user.user_id;
        const updateData = { ...req.body };
        const identificationCardFile = req.files?.identification_card?.[0] || null;

        if (
            updateData.student_data &&
            typeof updateData.student_data === 'string'
        ) {
            try {
                updateData.student_data = JSON.parse(updateData.student_data);
            } catch (parseError) {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid student profile data'
                });
            }
        }

        if (identificationCardFile) {
            if (!isPdfFileUpload(identificationCardFile)) {
                return res.status(400).json({
                    success: false,
                    message: IDENTIFICATION_CARD_PDF_ONLY_MESSAGE
                });
            }

            const existingCardResult = await query(
                `SELECT identification_card_url
                 FROM students
                 WHERE student_id = $1
                 LIMIT 1`,
                [userId]
            );

            uploadedIdentificationCard = await uploadAsset({
                buffer: identificationCardFile.buffer,
                mimeType: identificationCardFile.mimetype,
                originalName: identificationCardFile.originalname,
                localSubdir: 'student-identification-cards',
                fileNamePrefix: `${userId}-id`,
                cloudinaryFolder: 'student-job-platform/student-identification-cards',
                cloudinaryResourceType: 'raw'
            });

            previousIdentificationCardUrl =
                existingCardResult.rows[0]?.identification_card_url || null;

            updateData.student_data = {
                ...(updateData.student_data && typeof updateData.student_data === 'object'
                    ? updateData.student_data
                    : {}),
                identification_card_url: uploadedIdentificationCard.secureUrl,
                identification_card_name: identificationCardFile.originalname
            };
        }
        
        const updatedUser = await UserModel.update(userId, updateData);

        if (
            previousIdentificationCardUrl &&
            previousIdentificationCardUrl !== uploadedIdentificationCard?.secureUrl
        ) {
            await deleteAssetByUrl({
                fileUrl: previousIdentificationCardUrl,
                resourceType: 'raw'
            }).catch((cleanupError) => {
                console.error('Previous identification card cleanup error:', cleanupError);
            });
        }
        
        res.json({
            success: true,
            message: 'Profile updated successfully',
            data: updatedUser
        });
        
    } catch (error) {
        console.error('Update profile error:', error);
        if (uploadedIdentificationCard?.secureUrl) {
            try {
                await deleteAssetByUrl({
                    fileUrl: uploadedIdentificationCard.secureUrl,
                    resourceType: 'raw'
                });
            } catch (cleanupError) {
                console.error('Identification card cleanup error:', cleanupError);
            }
        }
        res.status(500).json({ 
            success: false, 
            message: 'Failed to update profile', 
            error: error.message 
        });
    }
};

const get = async (req, res) => {
    try {
        await ensureDefault();
        const institutions = await fetchOfficial(
            REGISTERABLE_INSTITUTION_NAMES
        );

        res.json({
            success: true,
            data: institutions
        });
    } catch (error) {
        console.error('Get institutions error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get institutions',
            error: error.message
        });
    }
};

// Get All Universities (for registration dropdown)
const getUniversities = async (req, res) => {
    try {
        await ensureDefault();
        const universities = await fetchAllUniversity();
        
        res.json({
            success: true,
            data: universities
        });
        
    } catch (error) {
        console.error('Get universities error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to get universities', 
            error: error.message 
        });
    }
};

const getGovernment = async (req, res) => {
    try {
        await ensureDefault();
        const governmentInstitutions = await fetchOfficial(
            GOVERNMENT_INSTITUTION_NAMES
        );

        res.json({
            success: true,
            data: governmentInstitutions
        });
    } catch (error) {
        console.error('Get government institutions error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get government institutions',
            error: error.message
        });
    }
};

const getCompanyDirectory = async (req, res) => {
    try {
        const regionFilter = `${req.query?.region || ''}`.trim().toLowerCase();
        const districtFilter = `${req.query?.district || ''}`.trim().toLowerCase();
        const result = await query(
            `SELECT DISTINCT ON (LOWER(TRIM(company_name)), LOWER(COALESCE(region, '')), LOWER(COALESCE(district, '')))
                TRIM(company_name) AS company_name,
                TRIM(COALESCE(organization_subtype, '')) AS organization_subtype,
                TRIM(COALESCE(government_category, '')) AS government_category,
                TRIM(COALESCE(region, '')) AS region,
                TRIM(COALESCE(district, '')) AS district,
                TRIM(COALESCE(location, '')) AS location
             FROM companies
             WHERE TRIM(COALESCE(company_name, '')) <> ''
               AND ($1 = '' OR LOWER(COALESCE(region, '')) = $1)
               AND ($2 = '' OR LOWER(COALESCE(district, '')) = $2)
             ORDER BY LOWER(TRIM(company_name)), LOWER(COALESCE(region, '')), LOWER(COALESCE(district, ''))
             LIMIT 1000`,
            [regionFilter, districtFilter]
        );

        res.json({
            success: true,
            data: result.rows
                .map((row) => ({
                    company_name: `${row.company_name || ''}`.trim(),
                    organization_subtype: `${row.organization_subtype || ''}`.trim(),
                    government_category: `${row.government_category || ''}`.trim(),
                    region: `${row.region || ''}`.trim(),
                    district: `${row.district || ''}`.trim(),
                    location: `${row.location || ''}`.trim()
                }))
                .filter((row) => row.company_name.length > 0)
        });
    } catch (error) {
        console.error('Get company directory error:', error);
        res.status(500).json({
            success: false,
            message: 'Failed to get company directory',
            error: error.message
        });
    }
};

// Get All Skills (for registration dropdown)
const getSkills = async (req, res) => {
    try {
        const { query } = require('../config/database');
        const result = await query('SELECT skill_id, name, category FROM skills ORDER BY name');
        
        res.json({
            success: true,
            data: result.rows
        });
        
    } catch (error) {
        console.error('Get skills error:', error);
        res.status(500).json({ 
            success: false, 
            message: 'Failed to get skills', 
            error: error.message 
        });
    }
};

const forgotPassword = async (req, res) => {
    try {
        await ensurePasswordResetTable();
        const email = `${req.body?.email || ''}`.trim().toLowerCase();
        const genericMessage =
            'If an account with that email exists, a reset link has been sent.';

        if (!email || !email.includes('@')) {
            return res.status(400).json({
                success: false,
                message: 'Please enter a valid email address'
            });
        }

        const userResult = await query(
            `SELECT user_id, full_name, email, is_active
             FROM users
             WHERE LOWER(email) = $1
             LIMIT 1`,
            [email]
        );

        if (userResult.rows.length === 0) {
            return res.json({
                success: true,
                message: genericMessage
            });
        }

        const user = userResult.rows[0];
        if (!user.is_active) {
            return res.json({
                success: true,
                message: genericMessage
            });
        }

        await query(
            `UPDATE password_reset_tokens
             SET used_at = NOW()
             WHERE user_id = $1 AND used_at IS NULL`,
            [user.user_id]
        );

        const rawToken = crypto.randomBytes(32).toString('hex');
        const tokenHash = hashResetToken(rawToken);
        const expiryMinutes = Number(
            process.env.PASSWORD_RESET_TOKEN_TTL_MINUTES || 60
        );

        await query(
            `INSERT INTO password_reset_tokens (user_id, token_hash, expires_at)
             VALUES ($1, $2, NOW() + ($3 * INTERVAL '1 minute'))`,
            [user.user_id, tokenHash, expiryMinutes]
        );

        const resetLink = `${getPasswordResetBaseUrl(req)}/api/auth/reset-password?token=${rawToken}`;

        try {
            await sendPasswordResetEmail({
                to: user.email,
                userName: user.full_name,
                resetLink,
                expiryLabel: `${expiryMinutes} minute${expiryMinutes === 1 ? '' : 's'}`,
                initiatedBy: 'user'
            });
        } catch (emailError) {
            console.error('Forgot password email error:', emailError);
            return res.json({
                success: true,
                message: genericMessage
            });
        }

        return res.json({
            success: true,
            message: genericMessage,
            emailSent: true
        });
    } catch (error) {
        console.error('Forgot password error:', error);
        return res.status(500).json({
            success: false,
            message: 'Failed to process forgot password request'
        });
    }
};

const renderPasswordResetForm = async (req, res) => {
    try {
        await ensurePasswordResetTable();
        const { token } = req.query;

        if (!token) {
            return res.status(400).send(
                renderResetPasswordPage({
                    title: 'Invalid reset link',
                    subtitle: 'This password reset link is missing a token.'
                })
            );
        }

        const tokenHash = hashResetToken(`${token}`);
        const result = await query(
            `SELECT token_id
             FROM password_reset_tokens
             WHERE token_hash = $1
               AND used_at IS NULL
               AND expires_at > NOW()
             LIMIT 1`,
            [tokenHash]
        );

        if (result.rows.length === 0) {
            return res.status(400).send(
                renderResetPasswordPage({
                    title: 'Reset link expired',
                    subtitle: 'This reset link is invalid or has already expired.'
                })
            );
        }

        return res.send(
            renderResetPasswordPage({
                title: 'Create a new password',
                subtitle: 'Enter your new password below to finish resetting your account.',
                token: `${token}`
            })
        );
    } catch (error) {
        console.error('Render password reset form error:', error);
        return res.status(500).send(
            renderResetPasswordPage({
                title: 'Reset unavailable',
                subtitle: 'Something went wrong while loading the reset page.'
            })
        );
    }
};

const completePasswordReset = async (req, res) => {
    try {
        await ensurePasswordResetTable();
        const { token, password, confirmPassword } = req.body;

        if (!token) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Invalid reset request',
                subtitle: 'The reset token is missing.'
            });
        }

        if (!password || `${password}`.trim().length < 6) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Password too short',
                subtitle: 'Your new password must be at least 6 characters long.',
                token: `${token}`
            });
        }

        if (`${password}` !== `${confirmPassword}`) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Passwords do not match',
                subtitle: 'Please enter the same password in both fields.',
                token: `${token}`
            });
        }

        const tokenHash = hashResetToken(`${token}`);
        const tokenResult = await query(
            `SELECT token_id, user_id
             FROM password_reset_tokens
             WHERE token_hash = $1
               AND used_at IS NULL
               AND expires_at > NOW()
             LIMIT 1`,
            [tokenHash]
        );

        if (tokenResult.rows.length === 0) {
            return sendResetResponse(req, res, {
                statusCode: 400,
                success: false,
                title: 'Reset link expired',
                subtitle: 'This reset link is invalid or has already expired.'
            });
        }

        const tokenRow = tokenResult.rows[0];
        const userResult = await query(
            `SELECT email, full_name
             FROM users
             WHERE user_id = $1
             LIMIT 1`,
            [tokenRow.user_id]
        );
        const user = userResult.rows[0];
        const salt = await bcrypt.genSalt(10);
        const passwordHash = await bcrypt.hash(`${password}`.trim(), salt);

        await query(
            `UPDATE users
             SET password_hash = $1,
                 updated_at = CURRENT_TIMESTAMP
             WHERE user_id = $2`,
            [passwordHash, tokenRow.user_id]
        );

        await query(
            'UPDATE password_reset_tokens SET used_at = NOW() WHERE token_id = $1',
            [tokenRow.token_id]
        );

        let passwordChangedEmailSent = false;
        try {
            const emailResult = await sendPasswordChangedEmail({
                to: user?.email,
                userName: user?.full_name
            });
            passwordChangedEmailSent = emailResult?.skipped != true;
        } catch (emailError) {
            console.error('Password changed email error:', emailError);
        }

        return sendResetResponse(req, res, {
            success: true,
            title: 'Password updated',
            subtitle: passwordChangedEmailSent
                ? 'Your password has been reset successfully. Check your email for a confirmation message, then return to the app and log in.'
                : 'Your password has been reset successfully. You can now return to the app and log in.',
            isSuccess: true
        });
    } catch (error) {
        console.error('Complete password reset error:', error);
        return sendResetResponse(req, res, {
            statusCode: 500,
            success: false,
            title: 'Reset failed',
            subtitle: 'Something went wrong while resetting your password.'
        });
    }
};

module.exports = {
    register,
    login,
    getProfile,
    changePassword,
    updateProfile,
    get,
    getUniversities,
    getGovernment,
    getCompanyDirectory,
    getSkills,
    forgotPassword,
    renderPasswordResetForm,
    completePasswordReset
};
