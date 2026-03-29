const nodemailer = require('nodemailer');

let transporter;
const BREVO_API_URL = 'https://api.brevo.com/v3/smtp/email';
const BREVO_PLACEHOLDER_KEY = 'xkeysib_your_brevo_api_key';
const RESEND_API_URL = 'https://api.resend.com/emails';
const RESEND_PLACEHOLDER_KEY = 're_your_resend_api_key';
const SMTP_PLACEHOLDER_USER = 'your_email@gmail.com';
const SMTP_PLACEHOLDER_PASSWORD = 'your_app_password';
const DEFAULT_RESEND_FROM = 'Student Job Platform <onboarding@resend.dev>';

function isBrevoConfigured() {
    return Boolean(
        process.env.BREVO_API_KEY &&
        process.env.BREVO_API_KEY !== BREVO_PLACEHOLDER_KEY
    );
}

function isResendConfigured() {
    return Boolean(
        process.env.RESEND_API_KEY &&
        process.env.RESEND_API_KEY !== RESEND_PLACEHOLDER_KEY
    );
}

function isSmtpConfigured() {
    return Boolean(
        process.env.EMAIL_HOST &&
        process.env.EMAIL_PORT &&
        process.env.EMAIL_USER &&
        process.env.EMAIL_PASSWORD &&
        process.env.EMAIL_USER !== SMTP_PLACEHOLDER_USER &&
        process.env.EMAIL_PASSWORD !== SMTP_PLACEHOLDER_PASSWORD
    );
}

function isEmailConfigured() {
    return isBrevoConfigured() || isResendConfigured() || isSmtpConfigured();
}

function getConfiguredEmailProviders() {
    const providers = [];

    if (isBrevoConfigured()) {
        providers.push('brevo');
    }

    if (isResendConfigured()) {
        providers.push('resend');
    }

    if (isSmtpConfigured()) {
        providers.push('smtp');
    }

    return providers;
}

function getTransporter() {
    if (transporter) return transporter;

    transporter = nodemailer.createTransport({
        host: process.env.EMAIL_HOST,
        port: Number(process.env.EMAIL_PORT || 587),
        secure: Number(process.env.EMAIL_PORT) === 465,
        auth: {
            user: process.env.EMAIL_USER,
            pass: process.env.EMAIL_PASSWORD
        }
    });

    return transporter;
}

function stripMarkdown(text) {
    return `${text || ''}`
        .replace(/\*\*(.*?)\*\*/g, '$1')
        .replace(/`(.*?)`/g, '$1')
        .trim();
}

function htmlFromText(text) {
    return stripMarkdown(text)
        .replace(/\n/g, '<br>');
}

function parseMailbox(value, fallbackName = 'Student Job Platform') {
    const raw = `${value || ''}`.trim();
    const match = raw.match(/^(.*)<([^>]+)>$/);

    if (match) {
        const name = match[1].trim().replace(/^"|"$/g, '') || fallbackName;
        const email = match[2].trim();
        return { name, email };
    }

    if (raw.includes('@')) {
        return { name: fallbackName, email: raw };
    }

    return { name: fallbackName, email: '' };
}

async function sendViaBrevo({ to, subject, text, html }) {
    const recipients = (Array.isArray(to) ? to : [to])
        .filter(Boolean)
        .map((entry) => parseMailbox(entry, 'Recipient'))
        .filter((entry) => entry.email);

    if (recipients.length === 0) {
        return { skipped: true };
    }

    const sender = parseMailbox(
        process.env.EMAIL_FROM ||
            process.env.RESEND_FROM ||
            DEFAULT_RESEND_FROM,
        'Student Job Platform'
    );

    if (!sender.email) {
        throw new Error(
            'EMAIL_FROM must contain a valid sender email for Brevo.'
        );
    }

    const response = await fetch(BREVO_API_URL, {
        method: 'POST',
        headers: {
            'api-key': process.env.BREVO_API_KEY,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            sender,
            to: recipients,
            subject,
            textContent: stripMarkdown(text),
            htmlContent: html || htmlFromText(text),
            replyTo: process.env.RESEND_REPLY_TO
                ? parseMailbox(process.env.RESEND_REPLY_TO, sender.name)
                : undefined
        })
    });

    let payload = null;
    try {
        payload = await response.json();
    } catch (error) {
        payload = null;
    }

    if (!response.ok) {
        const providerMessage =
            payload?.message ||
            payload?.code ||
            payload?.error ||
            `Brevo request failed with status ${response.status}`;
        throw new Error(providerMessage);
    }

    return {
        skipped: false,
        provider: 'brevo',
        id: payload?.messageId || null
    };
}

async function sendViaResend({ to, subject, text, html }) {
    const recipients = Array.isArray(to) ? to : [to];
    const response = await fetch(RESEND_API_URL, {
        method: 'POST',
        headers: {
            Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
            'Content-Type': 'application/json'
        },
        body: JSON.stringify({
            from: process.env.RESEND_FROM || process.env.EMAIL_FROM || DEFAULT_RESEND_FROM,
            to: recipients,
            subject,
            text: stripMarkdown(text),
            html: html || htmlFromText(text),
            reply_to: process.env.RESEND_REPLY_TO || undefined
        })
    });

    let payload = null;
    try {
        payload = await response.json();
    } catch (error) {
        payload = null;
    }

    if (!response.ok) {
        const providerMessage =
            payload?.message ||
            payload?.error ||
            `Resend request failed with status ${response.status}`;
        throw new Error(providerMessage);
    }

    return {
        skipped: false,
        provider: 'resend',
        id: payload?.id || null
    };
}

async function sendMail({ to, subject, text, html }) {
    const configuredProviders = getConfiguredEmailProviders();
    const providerErrors = [];
    const payload = { to, subject, text, html };

    if (configuredProviders.length === 0) {
        console.warn(
            'Email service skipped: configure BREVO_API_KEY, RESEND_API_KEY, or SMTP credentials.'
        );
        return {
            skipped: true,
            reason: 'not_configured'
        };
    }

    if (isBrevoConfigured()) {
        try {
            return await sendViaBrevo(payload);
        } catch (error) {
            const message = error?.message || `${error}`;
            providerErrors.push(`Brevo: ${message}`);
            console.error('Brevo email send failed:', error);
        }
    }

    if (isResendConfigured()) {
        try {
            return await sendViaResend(payload);
        } catch (error) {
            const message = error?.message || `${error}`;
            providerErrors.push(`Resend: ${message}`);
            console.error('Resend email send failed:', error);
        }
    }

    if (isSmtpConfigured()) {
        try {
            const mailer = getTransporter();
            await mailer.sendMail({
                from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
                to,
                subject,
                text: stripMarkdown(text),
                html: html || htmlFromText(text)
            });

            return { skipped: false, provider: 'smtp' };
        } catch (error) {
            const message = error?.message || `${error}`;
            providerErrors.push(`SMTP: ${message}`);
            console.error('SMTP email send failed:', error);
        }
    }

    throw new Error(
        `All configured email providers failed. ${providerErrors.join(' | ')}`
    );
}

async function sendApplicationStatusEmail({
    to,
    studentName,
    title,
    message
}) {
    if (!to) {
        return { skipped: true };
    }

    const greetingName = studentName || 'Student';
    const recipientLabel = Array.isArray(to) ? to.join(', ') : `${to}`;
    const html = `
        <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1f2937;">
            <p>Hello ${greetingName},</p>
            <p><strong>This message was sent to:</strong> ${recipientLabel}</p>
            <p>${htmlFromText(message)}</p>
            <p style="margin-top: 20px;">Best regards,<br>Student Job Platform</p>
        </div>
    `;

    return sendMail({
        to,
        subject: stripMarkdown(title),
        text: `Hello ${greetingName},\n\nThis message was sent to: ${recipientLabel}\n\n${stripMarkdown(message)}\n\nBest regards,\nStudent Job Platform`,
        html
    });
}

async function sendPasswordResetEmail({
    to,
    userName,
    resetLink,
    expiryLabel,
    initiatedBy = 'user'
}) {
    if (!to || !resetLink) {
        return { skipped: true };
    }

    const greetingName = userName || 'User';
    const introLine = initiatedBy === 'admin'
        ? 'An administrator requested a password reset for your account.'
        : 'A password reset was requested for your account.';
    const text = [
        `Hello ${greetingName},`,
        '',
        introLine,
        `This message was sent to: ${to}`,
        `Open this reset link: ${resetLink}`,
        '',
        `This link expires in ${expiryLabel || '1 hour'}.`,
        'If you did not expect this email, you can safely ignore it.',
        '',
        'Best regards,',
        'Student Job Platform'
    ].join('\n');

    const html = `
        <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1f2937;">
            <p>Hello ${greetingName},</p>
            <p>${introLine}</p>
            <p><strong>This message was sent to:</strong> ${to}</p>
            <p>
                <a
                    href="${resetLink}"
                    style="display: inline-block; padding: 12px 18px; background: #2563eb; color: white; text-decoration: none; border-radius: 8px; font-weight: 600;"
                >
                    Reset your Student Job Platform password
                </a>
            </p>
            <p>If the button does not open, use this link:</p>
            <p><a href="${resetLink}">${resetLink}</a></p>
            <p>This link expires in ${expiryLabel || '1 hour'}.</p>
            <p>If you did not expect this email, you can safely ignore it.</p>
            <p style="margin-top: 20px;">Best regards,<br>Student Job Platform</p>
        </div>
    `;

    return sendMail({
        to,
        subject: `Student Job Platform password reset for ${to}`,
        text,
        html
    });
}

async function sendPasswordChangedEmail({
    to,
    userName
}) {
    if (!to) {
        return { skipped: true };
    }

    const greetingName = userName || 'User';
    const text = [
        `Hello ${greetingName},`,
        '',
        'Your Student Job Platform password was changed successfully.',
        'For your security, we do not send passwords by email.',
        'If you did not make this change, reset your password again immediately or contact support.',
        '',
        'Best regards,',
        'Student Job Platform'
    ].join('\n');

    const html = `
        <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1f2937;">
            <div style="max-width: 520px; margin: 0 auto; background: #ffffff; border-radius: 18px; border: 1px solid #dbe4ff; overflow: hidden;">
                <div style="background: linear-gradient(135deg, #1e3a8a, #0f172a); padding: 22px 24px; color: #ffffff;">
                    <div style="display: inline-flex; align-items: center; gap: 10px;">
                        <div style="width: 42px; height: 42px; border-radius: 12px; background: rgba(251, 191, 36, 0.18); display: grid; place-items: center; font-weight: 700; color: #fbbf24;">
                            IGS
                        </div>
                        <div>
                            <div style="font-size: 18px; font-weight: 700;">Student Job Platform</div>
                            <div style="font-size: 13px; opacity: 0.88;">Password updated</div>
                        </div>
                    </div>
                </div>
                <div style="padding: 24px;">
                    <p>Hello ${greetingName},</p>
                    <p>Your Student Job Platform password was changed successfully.</p>
                    <p><strong>For your security, we do not send passwords by email.</strong></p>
                    <p>If you did not make this change, reset your password again immediately or contact support.</p>
                    <p style="margin-top: 20px;">Best regards,<br>Student Job Platform</p>
                </div>
            </div>
        </div>
    `;

    return sendMail({
        to,
        subject: 'Your Student Job Platform password was changed',
        text,
        html
    });
}

module.exports = {
    isEmailConfigured,
    getConfiguredEmailProviders,
    sendApplicationStatusEmail,
    sendPasswordResetEmail,
    sendPasswordChangedEmail
};
