const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const path = require('path');
const fs = require('fs');
require('dotenv').config();

const logger = require('./utils/logger');
const db = require('./config/database');
const authRoutes = require('./routes/auth');
const memberRoutes = require('./routes/members');
const associationRoutes = require('./routes/associations');
const mailingListRoutes = require('./routes/mailingLists');
const emailRoutes = require('./routes/email');
const uploadRoutes = require('./routes/upload');

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            scriptSrc: ["'self'", "'unsafe-inline'", "cdn.tailwindcss.com", "unpkg.com", "cdnjs.cloudflare.com"],
            styleSrc: ["'self'", "'unsafe-inline'", "cdn.tailwindcss.com", "cdnjs.cloudflare.com"],
            fontSrc: ["'self'", "cdnjs.cloudflare.com"],
            imgSrc: ["'self'", "data:"],
            connectSrc: ["'self'"]
        }
    }
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: (process.env.RATE_LIMIT_WINDOW || 15) * 60 * 1000, // 15 minutes
    max: process.env.RATE_LIMIT_MAX || 100, // limit each IP to 100 requests per windowMs
    message: 'Too many requests from this IP, please try again later.',
    standardHeaders: true,
    legacyHeaders: false,
});

const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // limit each IP to 5 requests per windowMs
    message: 'Too many authentication attempts, please try again later.',
    skipSuccessfulRequests: true,
});

app.use('/api/auth', authLimiter);
app.use('/api', limiter);

// Middleware
app.use(compression());
app.use(cors({
    origin: process.env.NODE_ENV === 'production' 
        ? [`https://${process.env.MAIN_DOMAIN}`, `https://${process.env.ADMIN_DOMAIN}`]
        : true,
    credentials: true
}));

app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Serve static files
app.use('/static', express.static(path.join(__dirname, 'frontend')));
app.use(express.static(path.join(__dirname, 'frontend')));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ 
        status: 'ok', 
        timestamp: new Date().toISOString(),
        version: '1.0.0',
        database: 'connected' // TODO: Add actual DB health check
    });
});

// API Routes
app.use('/api/auth', authRoutes);
app.use('/api/members', memberRoutes);
app.use('/api/associations', associationRoutes);
app.use('/api/mailing-lists', mailingListRoutes);
app.use('/api/email', emailRoutes);
app.use('/api/upload', uploadRoutes);

// Frontend serving with proper error handling
app.get('/', (req, res) => {
    const host = req.get('host') || '';
    
    // Check if this is the admin domain
    if (host.includes('p.ringing.org.uk') || host === process.env.ADMIN_DOMAIN) {
        return res.redirect(301, '/admin');
    }
    
    const indexPath = path.join(__dirname, 'frontend', 'index.html');
    
    // Check if file exists
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        logger.error('Frontend index.html not found at:', indexPath);
        res.status(500).json({ 
            error: 'Frontend files not found',
            path: indexPath,
            exists: false,
            directory_contents: fs.existsSync(path.join(__dirname, 'frontend')) 
                ? fs.readdirSync(path.join(__dirname, 'frontend'))
                : 'frontend directory does not exist'
        });
    }
});

// Association-specific login page
app.get('/association', (req, res) => {
    const associationPath = path.join(__dirname, 'frontend', 'association.html');
    
    if (fs.existsSync(associationPath)) {
        res.sendFile(associationPath);
    } else {
        logger.error('Association frontend file not found at:', associationPath);
        res.status(500).json({ 
            error: 'Association frontend file not found',
            path: associationPath
        });
    }
});
// Admin interface
app.get('/admin*', (req, res) => {
    const host = req.get('host') || '';
    logger.info(`Admin access from host: ${host}, path: ${req.path}`);
    
    const adminPath = path.join(__dirname, 'frontend', 'admin.html');
    
    if (fs.existsSync(adminPath)) {
        logger.info(`Serving admin.html from: ${adminPath}`);
        res.sendFile(adminPath);
    } else {
        logger.error(`Admin frontend file not found at: ${adminPath}`);
        res.status(500).json({ 
            error: 'Admin frontend file not found',
            path: adminPath,
            exists: false,
            directory_contents: fs.existsSync(path.join(__dirname, 'frontend')) 
                ? fs.readdirSync(path.join(__dirname, 'frontend'))
                : 'frontend directory does not exist'
        });
    }
});

// Catch-all handler for SPA routing
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'frontend', 'index.html');
    
    if (fs.existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        logger.error('Frontend files not found for catch-all route');
        res.status(404).json({ 
            error: 'Frontend files not found',
            path: indexPath,
            exists: false,
            requestedUrl: req.url
        });
    }
});

// Error handling middleware
app.use((err, req, res, next) => {
    logger.error('Unhandled error:', err);
    
    if (err.type === 'entity.parse.failed') {
        return res.status(400).json({ error: 'Invalid JSON payload' });
    }
    
    if (err.code === 'LIMIT_FILE_SIZE') {
        return res.status(413).json({ error: 'File too large' });
    }
    
    res.status(500).json({ 
        error: process.env.NODE_ENV === 'production' 
            ? 'Internal server error' 
            : err.message 
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({ error: 'Not found' });
});

// Start server
app.listen(PORT, '127.0.0.1', () => {
    logger.info(`Member Management System started on port ${PORT}`);
    logger.info(`Environment: ${process.env.NODE_ENV}`);
    logger.info(`Main domain: ${process.env.MAIN_DOMAIN}`);
    logger.info(`Admin domain: ${process.env.ADMIN_DOMAIN}`);
});

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully');
    process.exit(0);
});
