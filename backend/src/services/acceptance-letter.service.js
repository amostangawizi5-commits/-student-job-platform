const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const PAGE_WIDTH = 595;
const PAGE_HEIGHT = 842;
const LEFT_MARGIN = 60;
const RIGHT_MARGIN = 535;
const CONTENT_WIDTH = RIGHT_MARGIN - LEFT_MARGIN;
const GOVERNMENT_LOGO_ABSOLUTE_PATH = path.join(
    __dirname,
    '../../../student_app/assets/images/gov_logo.png'
);
const ACCEPTANCE_LETTER_LOG_PREFIX = '[acceptance-letter]';

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

function isPngBuffer(buffer) {
    return (
        Buffer.isBuffer(buffer) &&
        buffer.length > 8 &&
        buffer[0] === 0x89 &&
        buffer[1] === 0x50 &&
        buffer[2] === 0x4E &&
        buffer[3] === 0x47 &&
        buffer[4] === 0x0D &&
        buffer[5] === 0x0A &&
        buffer[6] === 0x1A &&
        buffer[7] === 0x0A
    );
}

function isJpegBuffer(buffer) {
    return Buffer.isBuffer(buffer) && buffer.length > 2 && buffer[0] === 0xFF && buffer[1] === 0xD8;
}

function paethPredictor(left, up, upLeft) {
    const prediction = left + up - upLeft;
    const leftDistance = Math.abs(prediction - left);
    const upDistance = Math.abs(prediction - up);
    const upLeftDistance = Math.abs(prediction - upLeft);

    if (leftDistance <= upDistance && leftDistance <= upLeftDistance) {
        return left;
    }

    if (upDistance <= upLeftDistance) {
        return up;
    }

    return upLeft;
}

function parsePngAsset(buffer, name) {
    if (!isPngBuffer(buffer)) {
        throw new Error('Image must be a PNG file');
    }

    let offset = 8;
    let width = 0;
    let height = 0;
    let bitDepth = 0;
    let colorType = 0;
    const idatChunks = [];

    while (offset < buffer.length) {
        const chunkLength = buffer.readUInt32BE(offset);
        const chunkType = buffer.toString('ascii', offset + 4, offset + 8);
        const chunkDataStart = offset + 8;
        const chunkDataEnd = chunkDataStart + chunkLength;
        const chunkData = buffer.subarray(chunkDataStart, chunkDataEnd);

        if (chunkType === 'IHDR') {
            width = chunkData.readUInt32BE(0);
            height = chunkData.readUInt32BE(4);
            bitDepth = chunkData[8];
            colorType = chunkData[9];
        } else if (chunkType === 'IDAT') {
            idatChunks.push(chunkData);
        } else if (chunkType === 'IEND') {
            break;
        }

        offset = chunkDataEnd + 4;
    }

    if (!width || !height || idatChunks.length === 0) {
        throw new Error('PNG image data is incomplete');
    }

    if (bitDepth !== 8 || ![2, 6].includes(colorType)) {
        throw new Error('Only 8-bit RGB or RGBA PNG images are supported');
    }

    const channels = colorType === 6 ? 4 : 3;
    const bytesPerPixel = channels;
    const rowLength = width * channels;
    const inflated = zlib.inflateSync(Buffer.concat(idatChunks));
    const expectedLength = height * (rowLength + 1);

    if (inflated.length < expectedLength) {
        throw new Error('PNG image data is truncated');
    }

    const rawRows = Buffer.alloc(width * height * channels);
    let readOffset = 0;
    let writeOffset = 0;
    let previousRow = null;

    for (let rowIndex = 0; rowIndex < height; rowIndex += 1) {
        const filterType = inflated[readOffset];
        readOffset += 1;
        const currentRow = Buffer.from(inflated.subarray(readOffset, readOffset + rowLength));
        readOffset += rowLength;

        for (let column = 0; column < rowLength; column += 1) {
            const left = column >= bytesPerPixel ? currentRow[column - bytesPerPixel] : 0;
            const up = previousRow ? previousRow[column] : 0;
            const upLeft =
                previousRow && column >= bytesPerPixel
                    ? previousRow[column - bytesPerPixel]
                    : 0;

            switch (filterType) {
                case 0:
                    break;
                case 1:
                    currentRow[column] = (currentRow[column] + left) & 0xFF;
                    break;
                case 2:
                    currentRow[column] = (currentRow[column] + up) & 0xFF;
                    break;
                case 3:
                    currentRow[column] = (currentRow[column] + Math.floor((left + up) / 2)) & 0xFF;
                    break;
                case 4:
                    currentRow[column] =
                        (currentRow[column] + paethPredictor(left, up, upLeft)) & 0xFF;
                    break;
                default:
                    throw new Error(`Unsupported PNG filter type: ${filterType}`);
            }
        }

        currentRow.copy(rawRows, writeOffset);
        writeOffset += rowLength;
        previousRow = currentRow;
    }

    if (colorType === 6) {
        const rgbBuffer = Buffer.alloc(width * height * 3);
        const alphaBuffer = Buffer.alloc(width * height);

        for (let source = 0, rgbOffset = 0, alphaOffset = 0; source < rawRows.length; source += 4) {
            rgbBuffer[rgbOffset] = rawRows[source];
            rgbBuffer[rgbOffset + 1] = rawRows[source + 1];
            rgbBuffer[rgbOffset + 2] = rawRows[source + 2];
            alphaBuffer[alphaOffset] = rawRows[source + 3];
            rgbOffset += 3;
            alphaOffset += 1;
        }

        return {
            name,
            width,
            height,
            buffer: zlib.deflateSync(rgbBuffer),
            pdfFilter: '/FlateDecode',
            colorSpace: '/DeviceRGB',
            bitsPerComponent: 8,
            smask: {
                width,
                height,
                buffer: zlib.deflateSync(alphaBuffer),
                pdfFilter: '/FlateDecode',
                colorSpace: '/DeviceGray',
                bitsPerComponent: 8
            }
        };
    }

    return {
        name,
        width,
        height,
        buffer: zlib.deflateSync(rawRows),
        pdfFilter: '/FlateDecode',
        colorSpace: '/DeviceRGB',
        bitsPerComponent: 8
    };
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

async function loadImageAsset(fileUrl, name) {
    if (!fileUrl) {
        return null;
    }

    try {
        const buffer = await loadBinaryFromUrl(fileUrl);
        if (!buffer) {
            return null;
        }

        if (isJpegBuffer(buffer)) {
            const { width, height } = parseJpegDimensions(buffer);
            return {
                name,
                buffer,
                width,
                height,
                pdfFilter: '/DCTDecode',
                colorSpace: '/DeviceRGB',
                bitsPerComponent: 8
            };
        }

        if (isPngBuffer(buffer)) {
            return parsePngAsset(buffer, name);
        }

        throw new Error('Only JPEG and PNG image assets are supported');
    } catch (error) {
        console.error(`${ACCEPTANCE_LETTER_LOG_PREFIX} Failed to load image asset`, {
            assetName: name,
            fileUrl,
            error: error.message
        });
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
    let nextObjectNumber = 8;
    const imageEntries = imageAssets.map((asset) => {
        const entry = {
            ...asset,
            objectNumber: nextObjectNumber
        };
        nextObjectNumber += 1;

        if (asset.smask) {
            entry.smaskObjectNumber = nextObjectNumber;
            nextObjectNumber += 1;
        }

        return entry;
    });

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
                ` /Type /XObject /Subtype /Image /Width ${asset.width} /Height ${asset.height} /ColorSpace ${asset.colorSpace || '/DeviceRGB'} /BitsPerComponent ${asset.bitsPerComponent || 8} /Filter ${asset.pdfFilter || '/DCTDecode'}${
                    asset.smaskObjectNumber ? ` /SMask ${asset.smaskObjectNumber} 0 R` : ''
                }`,
                asset.buffer
            )
        ),
        ...imageEntries
            .filter((asset) => asset.smask && asset.smaskObjectNumber)
            .map((asset) =>
                createStreamObject(
                    asset.smaskObjectNumber,
                    ` /Type /XObject /Subtype /Image /Width ${asset.smask.width} /Height ${asset.smask.height} /ColorSpace ${asset.smask.colorSpace} /BitsPerComponent ${asset.smask.bitsPerComponent} /Filter ${asset.smask.pdfFilter}`,
                    asset.smask.buffer
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
    console.log(`${ACCEPTANCE_LETTER_LOG_PREFIX} Building PDF`, {
        hasCompanyLogo: Boolean(companyLogoUrl),
        hasStampImage: Boolean(stampImageUrl),
        hasSignatureImage: Boolean(signatureImageUrl),
        organizationName,
        studentName,
        registrationNumber
    });

    const [governmentLogoImage, companyLogoImage, stampImage, signatureImage] = await Promise.all([
        loadImageAsset(GOVERNMENT_LOGO_ABSOLUTE_PATH, 'GOVERNMENT_LOGO'),
        loadImageAsset(companyLogoUrl, 'COMPANY_LOGO'),
        loadImageAsset(stampImageUrl, 'STAMP_IMAGE'),
        loadImageAsset(signatureImageUrl, 'SIGNATURE_IMAGE')
    ]);

    console.log(`${ACCEPTANCE_LETTER_LOG_PREFIX} Asset load result`, {
        governmentLogoLoaded: Boolean(governmentLogoImage),
        companyLogoLoaded: Boolean(companyLogoImage),
        stampLoaded: Boolean(stampImage),
        signatureLoaded: Boolean(signatureImage)
    });

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
    const headerLogoTopY = 754;

    if (companyLogoImage) {
        const fitted = fitInside({
            width: companyLogoImage.width,
            height: companyLogoImage.height,
            maxWidth: 82,
            maxHeight: 50
        });
        imageAssets.push(companyLogoImage);
        operations.push(createImageOperation({
            name: companyLogoImage.name,
            x: PAGE_WIDTH - LEFT_MARGIN - fitted.width,
            y: headerLogoTopY,
            width: fitted.width,
            height: fitted.height
        }));
    }

    if (governmentLogoImage) {
        const fitted = fitInside({
            width: governmentLogoImage.width,
            height: governmentLogoImage.height,
            maxWidth: 78,
            maxHeight: 50
        });
        imageAssets.push(governmentLogoImage);
        operations.push(createImageOperation({
            name: governmentLogoImage.name,
            x: LEFT_MARGIN,
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

    operations.push(createLineOperation(LEFT_MARGIN - 6, y - 10, RIGHT_MARGIN + 6, y - 10, 1.2));
    y -= 34;

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
    y -= 28;

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
    y -= 16;

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
        'Signature of Authorizing Officer',
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
