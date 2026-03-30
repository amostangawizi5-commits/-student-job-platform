const fs = require('fs');
const path = require('path');

const PAGE_WIDTH = 595;
const PAGE_HEIGHT = 842;
const LEFT_MARGIN = 60;
const RIGHT_MARGIN = 535;
const CONTENT_WIDTH = RIGHT_MARGIN - LEFT_MARGIN;
const GOVERNMENT_LOGO_ABSOLUTE_PATH = path.join(
    __dirname,
    '../../../student_app/assets/images/gov_logo.png'
);

function sanitizePdfText(value) {
    return `${value || ''}`
        .replace(/\\/g, '\\\\')
        .replace(/\(/g, '\\(')
        .replace(/\)/g, '\\)')
        .replace(/[^\x20-\x7E]/g, '?');
}

function ordinalSuffix(day) {
    const mod100 = day % 100;
    if (mod100 >= 11 && mod100 <= 13) {
        return `${day}th`;
    }

    switch (day % 10) {
        case 1:
            return `${day}st`;
        case 2:
            return `${day}nd`;
        case 3:
            return `${day}rd`;
        default:
            return `${day}th`;
    }
}

function formatLetterDate(dateValue) {
    const parsed = dateValue ? new Date(dateValue) : new Date();
    if (Number.isNaN(parsed.getTime())) {
        return '________________';
    }

    const month = parsed.toLocaleDateString('en-GB', { month: 'long' });
    return `${ordinalSuffix(parsed.getDate())} ${month} ${parsed.getFullYear()}`;
}

function estimateTextWidth(text, fontSize) {
    return [...`${text || ''}`].reduce((total, char) => {
        if ('il.,:;|!'.includes(char)) return total + (fontSize * 0.22);
        if ('MW@%&QGO'.includes(char)) return total + (fontSize * 0.72);
        if ('ABCDEFGHKNOPRSTUVXYZbdghnopqu'.includes(char)) {
            return total + (fontSize * 0.58);
        }
        if (char === ' ') return total + (fontSize * 0.28);
        return total + (fontSize * 0.5);
    }, 0);
}

function wrapText(text, maxWidth, fontSize) {
    const words = `${text || ''}`.trim().split(/\s+/).filter(Boolean);
    if (words.length === 0) {
        return [''];
    }

    const lines = [];
    let currentLine = words[0];

    for (let i = 1; i < words.length; i += 1) {
        const nextLine = `${currentLine} ${words[i]}`;
        if (estimateTextWidth(nextLine, fontSize) <= maxWidth) {
            currentLine = nextLine;
        } else {
            lines.push(currentLine);
            currentLine = words[i];
        }
    }

    lines.push(currentLine);
    return lines;
}

function createTextOperation({ text, x, y, size = 11, font = 'F1' }) {
    return `BT /${font} ${size} Tf 1 0 0 1 ${x} ${y} Tm (${sanitizePdfText(text)}) Tj ET`;
}

function createCenteredTextOperation({ text, y, size = 11, font = 'F1' }) {
    const width = estimateTextWidth(text, size);
    const x = Math.max(40, (PAGE_WIDTH - width) / 2);
    return createTextOperation({ text, x, y, size, font });
}

function createLineOperation(x1, y1, x2, y2, width = 1) {
    return `${width} w ${x1} ${y1} m ${x2} ${y2} l S`;
}

function createRectangleOperation(x, y, width, height, strokeWidth = 1) {
    return `${strokeWidth} w ${x} ${y} ${width} ${height} re S`;
}

function createImageOperation({ name, x, y, width, height }) {
    return `q ${width} 0 0 ${height} ${x} ${y} cm /${name} Do Q`;
}

function appendWrappedText(
    operations,
    text,
    { x, y, maxWidth, size = 11, font = 'F1', lineHeight = 16 }
) {
    const lines = wrapText(text, maxWidth, size);
    let cursorY = y;

    lines.forEach((line) => {
        operations.push(createTextOperation({ text: line, x, y: cursorY, size, font }));
        cursorY -= lineHeight;
    });

    return cursorY;
}

function appendCenteredWrappedText(
    operations,
    text,
    { y, maxWidth, size = 11, font = 'F1', lineHeight = 16 }
) {
    const lines = wrapText(text, maxWidth, size);
    let cursorY = y;

    lines.forEach((line) => {
        const width = estimateTextWidth(line, size);
        const x = Math.max(40, (PAGE_WIDTH - width) / 2);
        operations.push(createTextOperation({ text: line, x, y: cursorY, size, font }));
        cursorY -= lineHeight;
    });

    return cursorY;
}

function fitInside({ width, height, maxWidth, maxHeight }) {
    const ratio = Math.min(maxWidth / width, maxHeight / height, 1);
    return {
        width: Math.max(1, Math.round(width * ratio)),
        height: Math.max(1, Math.round(height * ratio))
    };
}

function parseJpegDimensions(buffer) {
    if (!Buffer.isBuffer(buffer) || buffer.length < 4) {
        throw new Error('Invalid JPEG buffer');
    }

    if (buffer[0] !== 0xFF || buffer[1] !== 0xD8) {
        throw new Error('Image must be a JPEG file');
    }

    let offset = 2;
    while (offset < buffer.length) {
        if (buffer[offset] !== 0xFF) {
            offset += 1;
            continue;
        }

        let marker = buffer[offset + 1];
        while (marker === 0xFF) {
            offset += 1;
            marker = buffer[offset + 1];
        }

        if (marker === 0xD9 || marker === 0xDA) {
            break;
        }

        const blockLength = buffer.readUInt16BE(offset + 2);
        const isStartOfFrame =
            (marker >= 0xC0 && marker <= 0xC3) ||
            (marker >= 0xC5 && marker <= 0xC7) ||
            (marker >= 0xC9 && marker <= 0xCB) ||
            (marker >= 0xCD && marker <= 0xCF);

        if (isStartOfFrame) {
            return {
                height: buffer.readUInt16BE(offset + 5),
                width: buffer.readUInt16BE(offset + 7)
            };
        }

        offset += 2 + blockLength;
    }

    throw new Error('Could not read JPEG dimensions');
}

function resolveLocalAbsolutePath(fileUrl) {
    const normalizedPath = `${fileUrl || ''}`.replace(/^\/+/, '');
    return path.join(__dirname, '../../', normalizedPath);
}

async function loadBinaryFromUrl(fileUrl) {
    if (!fileUrl) {
        return null;
    }

    if (path.isAbsolute(fileUrl)) {
        return fs.readFileSync(fileUrl);
    }

    if (fileUrl.startsWith('http://') || fileUrl.startsWith('https://')) {
        const response = await fetch(fileUrl);
        if (!response.ok) {
            throw new Error(`Failed to fetch image asset: ${response.status}`);
        }

        const arrayBuffer = await response.arrayBuffer();
        return Buffer.from(arrayBuffer);
    }

    const absolutePath = resolveLocalAbsolutePath(fileUrl);
    return fs.readFileSync(absolutePath);
}

async function loadJpegAsset(fileUrl, name) {
    if (!fileUrl) {
        return null;
    }

    try {
        const buffer = await loadBinaryFromUrl(fileUrl);
        if (!buffer) {
            return null;
        }

        const { width, height } = parseJpegDimensions(buffer);
        return { name, buffer, width, height };
    } catch (error) {
        return null;
    }
}

function createStreamObject(objectNumber, dictionary, streamBuffer) {
    return Buffer.concat([
        Buffer.from(
            `${objectNumber} 0 obj\n<< ${dictionary} /Length ${streamBuffer.length} >>\nstream\n`,
            'utf8'
        ),
        streamBuffer,
        Buffer.from('\nendstream\nendobj\n', 'utf8')
    ]);
}

function buildPdfBuffer({ operations, imageAssets }) {
    const contentBuffer = Buffer.from(operations.join('\n'), 'utf8');
    const imageEntries = imageAssets.map((asset, index) => ({
        ...asset,
        objectNumber: 8 + index
    }));

    const xObjectEntries = imageEntries
        .map((asset) => `/${asset.name} ${asset.objectNumber} 0 R`)
        .join(' ');

    const pageResourceBlock = xObjectEntries
        ? `<< /Font << /F1 5 0 R /F2 6 0 R /F3 7 0 R >> /XObject << ${xObjectEntries} >> >>`
        : '<< /Font << /F1 5 0 R /F2 6 0 R /F3 7 0 R >> >>';

    const objects = [
        Buffer.from('1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n', 'utf8'),
        Buffer.from('2 0 obj\n<< /Type /Pages /Count 1 /Kids [3 0 R] >>\nendobj\n', 'utf8'),
        Buffer.from(
            `3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${PAGE_WIDTH} ${PAGE_HEIGHT}] /Resources ${pageResourceBlock} /Contents 4 0 R >>\nendobj\n`,
            'utf8'
        ),
        createStreamObject(4, '', contentBuffer),
        Buffer.from(
            '5 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
            'utf8'
        ),
        Buffer.from(
            '6 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n',
            'utf8'
        ),
        Buffer.from(
            '7 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Oblique >>\nendobj\n',
            'utf8'
        ),
        ...imageEntries.map((asset) =>
            createStreamObject(
                asset.objectNumber,
                ` /Type /XObject /Subtype /Image /Width ${asset.width} /Height ${asset.height} /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /DCTDecode`,
                asset.buffer
            )
        )
    ];

    const parts = [Buffer.from('%PDF-1.4\n', 'utf8')];
    const offsets = [0];
    let currentLength = parts[0].length;

    for (const objectBuffer of objects) {
        offsets.push(currentLength);
        parts.push(objectBuffer);
        currentLength += objectBuffer.length;
    }

    const xrefOffset = currentLength;
    let xref = `xref\n0 ${objects.length + 1}\n`;
    xref += '0000000000 65535 f \n';
    for (let i = 1; i < offsets.length; i += 1) {
        xref += `${offsets[i].toString().padStart(10, '0')} 00000 n \n`;
    }
    xref += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xrefOffset}\n%%EOF`;
    parts.push(Buffer.from(xref, 'utf8'));

    return Buffer.concat(parts);
}

async function buildAcceptanceLetterPdf({
    organizationName,
    studentName,
    registrationNumber,
    collegeName,
    universityName,
    sectionDepartment,
    officerName,
    officerDesignation,
    officerPhone,
    officerEmail,
    officerRegion,
    officerDistrict,
    officerArea,
    startDate,
    endDate,
    letterDate,
    companyLogoUrl,
    footerCompanyName,
    footerLocation,
    footerPhone,
    footerEmail,
    footerWebsite,
    stampImageUrl,
    signatureImageUrl
}) {
    const [governmentLogoImage, companyLogoImage, stampImage, signatureImage] = await Promise.all([
        loadJpegAsset(GOVERNMENT_LOGO_ABSOLUTE_PATH, 'GOVERNMENT_LOGO'),
        loadJpegAsset(companyLogoUrl, 'COMPANY_LOGO'),
        loadJpegAsset(stampImageUrl, 'STAMP_IMAGE'),
        loadJpegAsset(signatureImageUrl, 'SIGNATURE_IMAGE')
    ]);

    const formattedStartDate = formatLetterDate(startDate);
    const formattedEndDate = formatLetterDate(endDate);
    const formattedLetterDate = formatLetterDate(letterDate);
    const companyHeader = `${organizationName || 'COMPANY NAME'}`.trim().toUpperCase();
    const footerLineOne = `${footerCompanyName || organizationName || 'Company Name'}`.trim();
    const footerLineTwo = `${footerLocation || ''}`.trim();
    const footerContactBits = [
        footerPhone ? `Tel: ${footerPhone}` : '',
        footerEmail ? `E-mail: ${footerEmail}` : '',
        footerWebsite ? `Website: ${footerWebsite}` : ''
    ].filter(Boolean);
    const footerLineThree = footerContactBits.join(', ');
    const operations = [];
    const imageAssets = [];
    let y = 806;
    const headerLogoTopY = 742;

    if (companyLogoImage) {
        const fitted = fitInside({
            width: companyLogoImage.width,
            height: companyLogoImage.height,
            maxWidth: 72,
            maxHeight: 72
        });
        imageAssets.push(companyLogoImage);
        operations.push(createImageOperation({
            name: companyLogoImage.name,
            x: PAGE_WIDTH - LEFT_MARGIN - fitted.width + 6,
            y: headerLogoTopY,
            width: fitted.width,
            height: fitted.height
        }));
    }

    if (governmentLogoImage) {
        const fitted = fitInside({
            width: governmentLogoImage.width,
            height: governmentLogoImage.height,
            maxWidth: 72,
            maxHeight: 72
        });
        imageAssets.push(governmentLogoImage);
        operations.push(createImageOperation({
            name: governmentLogoImage.name,
            x: LEFT_MARGIN - 6,
            y: headerLogoTopY,
            width: fitted.width,
            height: fitted.height
        }));
    }

    operations.push(createCenteredTextOperation({
        text: 'THE UNITED REPUBLIC OF TANZANIA',
        y,
        size: 15,
        font: 'F2'
    }));
    y -= 20;

    operations.push(createCenteredTextOperation({
        text: 'MINISTRY OF EDUCATION, SCIENCE AND TECHNOLOGY',
        y,
        size: 11,
        font: 'F2'
    }));
    y -= 19;

    y = appendCenteredWrappedText(
        operations,
        companyHeader,
        {
            y,
            maxWidth: 300,
            size: 14,
            font: 'F2',
            lineHeight: 18
        }
    );

    operations.push(createLineOperation(LEFT_MARGIN - 2, y, RIGHT_MARGIN + 2, y));
    y -= 26;

    operations.push(createCenteredTextOperation({
        text: 'INDUSTRIAL PRACTICAL TRAINING (IPT)',
        y,
        size: 12,
        font: 'F2'
    }));
    y -= 19;

    operations.push(createCenteredTextOperation({
        text: 'FIELD ATTACHMENT FORM OF RESPONSE',
        y,
        size: 13,
        font: 'F2'
    }));
    y -= 16;

    operations.push(createLineOperation(LEFT_MARGIN - 2, y, RIGHT_MARGIN + 2, y, 0.8));
    y -= 24;

    operations.push(createTextOperation({
        text: 'Name of Organization / Institution',
        x: LEFT_MARGIN,
        y,
        size: 10.5,
        font: 'F2'
    }));
    y -= 16;

    y = appendWrappedText(
        operations,
        organizationName,
        { x: LEFT_MARGIN + 6, y, maxWidth: CONTENT_WIDTH - 12, size: 12.5, lineHeight: 18 }
    );
    operations.push(createLineOperation(LEFT_MARGIN, y + 8, RIGHT_MARGIN, y + 8, 0.8));
    y -= 18;

    y = appendWrappedText(
        operations,
        `have accepted to enroll ${studentName} with registration number ${registrationNumber} from the ${collegeName} of the ${universityName} for industrial practical training for a period of at least Eight (8) weeks starting from ${formattedStartDate} to ${formattedEndDate}.`,
        { x: LEFT_MARGIN, y, maxWidth: CONTENT_WIDTH, size: 12, lineHeight: 19 }
    );
    y -= 16;

    operations.push(createTextOperation({
        text: 'Reporting Section / Department',
        x: LEFT_MARGIN,
        y,
        size: 10.5,
        font: 'F2'
    }));
    y -= 16;

    y = appendWrappedText(
        operations,
        sectionDepartment,
        { x: LEFT_MARGIN + 6, y, maxWidth: CONTENT_WIDTH - 12, size: 12, lineHeight: 18 }
    );
    operations.push(createLineOperation(LEFT_MARGIN, y + 8, RIGHT_MARGIN, y + 8, 0.8));
    y -= 18;

    operations.push(createTextOperation({
        text: 'Yours Sincerely,',
        x: LEFT_MARGIN,
        y,
        size: 12,
        font: 'F1'
    }));
    y -= 26;

    const signatureLineAnchorY = y - 26;
    const signatureLines = [
        `${officerName} (Name of Authorizing Officer)`,
        `${officerDesignation} (Designation)`,
        '........................................................ (Signature of Authorizing Officer)',
        `${officerPhone} (Telephone Number)`,
        `${officerEmail} (E-mail Address)`,
        `${officerRegion} (Region)`,
        `${officerDistrict} (District)`,
        `${officerArea} (Area / Physical Address)`,
        `${formattedLetterDate} (Date)`
    ];

    signatureLines.forEach((line) => {
        y = appendWrappedText(
            operations,
            line,
            { x: LEFT_MARGIN, y, maxWidth: CONTENT_WIDTH, size: 11, lineHeight: 18 }
        );
        y -= 6;
    });

    y -= 10;
    const stampLabelY = y;
    operations.push(createTextOperation({
        text: 'Official rubber stamp:',
        x: LEFT_MARGIN,
        y: stampLabelY,
        size: 10.5,
        font: 'F3'
    }));
    const stampBoxX = LEFT_MARGIN;
    const stampBoxY = stampLabelY - 82;
    const stampBoxWidth = 150;
    const stampBoxHeight = 58;
    operations.push(createRectangleOperation(stampBoxX, stampBoxY, stampBoxWidth, stampBoxHeight, 0.8));

    if (signatureImage) {
        const fitted = fitInside({
            width: signatureImage.width,
            height: signatureImage.height,
            maxWidth: 150,
            maxHeight: 46
        });
        imageAssets.push(signatureImage);
        operations.push(createImageOperation({
            name: signatureImage.name,
            x: LEFT_MARGIN + 10,
            y: signatureLineAnchorY - 2,
            width: fitted.width,
            height: fitted.height
        }));
    }

    if (stampImage) {
        const fitted = fitInside({
            width: stampImage.width,
            height: stampImage.height,
            maxWidth: stampBoxWidth - 16,
            maxHeight: stampBoxHeight - 12
        });
        imageAssets.push(stampImage);
        operations.push(createImageOperation({
            name: stampImage.name,
            x: stampBoxX + ((stampBoxWidth - fitted.width) / 2),
            y: stampBoxY + ((stampBoxHeight - fitted.height) / 2),
            width: fitted.width,
            height: fitted.height
        }));
    }

    operations.push(createLineOperation(44, 62, 551, 62, 0.8));
    operations.push(createCenteredTextOperation({
        text: footerLineOne,
        y: 48,
        size: 8.2,
        font: 'F2'
    }));
    if (footerLineTwo) {
        operations.push(createCenteredTextOperation({
            text: footerLineTwo,
            y: 37,
            size: 8,
            font: 'F1'
        }));
    }
    if (footerLineThree) {
        operations.push(createCenteredTextOperation({
            text: footerLineThree,
            y: 26,
            size: 8,
            font: 'F1'
        }));
    }

    return buildPdfBuffer({ operations, imageAssets });
}

module.exports = {
    buildAcceptanceLetterPdf
};
