// server.js - Main Entry Point
const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const os = require('os');
const path = require('path');
const {
    isEmailConfigured,
    getConfiguredEmailProviders
} = require('./src/services/email.service');

// Load environment variables
dotenv.config();

// Import database connection
const { connectDB } = require('./src/config/database');

// Import routes
const authRoutes = require('./src/routes/auth.routes');
const jobRoutes = require('./src/routes/job.routes');
const skillRoutes = require('./src/routes/skill.routes');
const applicationRoutes = require('./src/routes/application.routes');
const studentRoutes = require('./src/routes/student.routes');
const notificationRoutes = require('./src/routes/notification.routes');
const companyRoutes = require('./src/routes/company.routes');
const adminRoutes = require('./src/routes/admin.routes');
const universityRoutes = require('./src/routes/university.routes');
const projectRoutes = require('./src/routes/project.routes');  // ADDED
const awardRoutes = require('./src/routes/award.routes');
const testRoutes = require('./src/routes/test.routes');

// Import resume routes
const resumeRoutes = require('./simple-resume.js');

const app = express();
app.set('trust proxy', 1);

const normalizeOrigin = (origin) => `${origin || ''}`.trim().replace(/\/+$/, '');
const allowedOrigins = `${process.env.ALLOWED_ORIGINS || ''}`
    .split(',')
    .map(normalizeOrigin)
    .filter(Boolean);

const isAllowedOrigin = (origin) => {
    if (!origin) {
        // Mobile apps and server-to-server requests often omit Origin.
        return true;
    }

    if (allowedOrigins.length === 0) {
        return true;
    }

    return allowedOrigins.includes(normalizeOrigin(origin));
};

const corsOptions = {
    origin: (origin, callback) => {
        if (isAllowedOrigin(origin)) {
            return callback(null, true);
        }

        return callback(new Error(`Origin not allowed by CORS: ${origin}`));
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
};

// ============ MIDDLEWARE ============
app.use('/uploads', cors(corsOptions), express.static(path.join(__dirname, 'uploads')));
app.use(cors(corsOptions));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const webPublicDir = path.join(__dirname, 'public');
const noCacheStaticFiles = new Set([
    '/index.html',
    '/flutter_bootstrap.js',
    '/flutter_service_worker.js',
    '/main.dart.js',
    '/manifest.json',
    '/version.json'
]);

app.use(express.static(webPublicDir, {
    setHeaders: (res, filePath) => {
        const publicPath = `/${path.relative(webPublicDir, filePath).replace(/\\/g, '/')}`;
        if (noCacheStaticFiles.has(publicPath)) {
            res.setHeader('Cache-Control', 'no-store, no-cache, must-revalidate, proxy-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');
        }
    }
}));

// ============ TEST ROUTES ============
app.get('/', (req, res) => {
    res.json({ 
        message: 'Student Job Platform API',
        status: 'Running',
        version: '1.0.0'
    });
});

app.get('/health', (req, res) => {
    res.json({ 
        status: 'OK', 
        timestamp: new Date().toISOString() 
    });
});

// ============ REGISTER ROUTES ============
console.log(' Registering routes...');

// Register RESUME routes FIRST
console.log('   Registering /api/resume...');
app.use('/api/resume', resumeRoutes);

// Register other routes
console.log('  Registering /api/auth...');
app.use('/api/auth', authRoutes);

console.log('   Registering /api/training...');
app.use('/api/training', jobRoutes);

console.log('  Registering /api/skills...');
app.use('/api/skills', skillRoutes);

console.log('  Registering /api/applications...');
app.use('/api/applications', applicationRoutes);

console.log('  Registering /api/student...');
app.use('/api/student', studentRoutes);

console.log('   Registering /api/notifications...');
app.use('/api/notifications', notificationRoutes);

console.log('   Registering /api/company...');
app.use('/api/company', companyRoutes);

console.log('   Registering /api/organization...');
app.use('/api/organization', companyRoutes);

console.log('  Registering /api/university...');
app.use('/api/university', universityRoutes);

console.log('  Registering /api/admin...');
app.use('/api/admin', adminRoutes);

console.log('  Registering /api/tests...');
app.use('/api/tests', testRoutes);

console.log('  Registering /api/awards...');
app.use('/api/awards', awardRoutes);

console.log('   Registering /api/projects...');  // ADDED
app.use('/api/projects', projectRoutes);  // ADDED

console.log(' All routes registered successfully!');

app.get(/^\/(?!api\/|health$|uploads\/).*/, (req, res) => {
    res.sendFile(path.join(webPublicDir, 'index.html'));
});

// ============ ERROR HANDLING MIDDLEWARE ============
app.use((err, req, res, next) => {
    console.error('❌ Error:', err.stack);
    res.status(500).json({ 
        message: 'Something went wrong!', 
        error: err.message 
    });
});

// ============ START SERVER ============
const PORT = process.env.PORT || 5000;
const HOST = '0.0.0.0';
const publicApiUrl = normalizeOrigin(
    process.env.PUBLIC_API_URL || process.env.RESET_PASSWORD_BASE_URL
);

const getLanUrls = () => {
    const interfaces = os.networkInterfaces();
    const lanUrls = [];

    for (const addresses of Object.values(interfaces)) {
        for (const address of addresses || []) {
            if (address.family === 'IPv4' && !address.internal) {
                lanUrls.push(`http://${address.address}:${PORT}`);
            }
        }
    }

    return [...new Set(lanUrls)];
};

const startServer = async () => {
    try {
        await connectDB();
        
        app.listen(PORT, HOST, () => {
            console.log(`\n Server is running on port ${PORT}`);
            console.log(` API URL: http://localhost:${PORT}`);
            if (publicApiUrl) {
                console.log(`Public API URL: ${publicApiUrl}`);
            }
            if (isEmailConfigured()) {
                console.log(
                    ` Email providers configured: ${getConfiguredEmailProviders().join(', ')}`
                );
            } else {
                console.warn(
                    'Email is not configured. Password reset emails will not be delivered.'
                );
            }
            const lanUrls = getLanUrls();
            if (lanUrls.length > 0) {
                console.log(` Access from mobile devices: ${lanUrls.join(', ')}`);
            }
            console.log('\nReady to accept requests!\n');
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
};

startServer();
