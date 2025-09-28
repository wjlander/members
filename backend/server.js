const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const compression = require('compression');
const path = require('path');
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

// Serve frontend for main domain
app.get('/', (req, res) => {
    const indexPath = path.join(__dirname, 'frontend/index.html');
    if (require('fs').existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(500).json({ 
            error: 'Frontend files not found',
            path: indexPath,
            exists: require('fs').existsSync(indexPath)
        });
    }
});

// Admin interface
app.get('/admin*', (req, res) => {
    // Check if this is the admin domain
    if (req.get('host') === process.env.ADMIN_DOMAIN) {
        const adminPath = path.join(__dirname, 'frontend/admin.html');
        if (require('fs').existsSync(adminPath)) {
            res.sendFile(adminPath);
        } else {
            // Fallback to index.html if admin.html doesn't exist
            const indexPath = path.join(__dirname, 'frontend/index.html');
            if (require('fs').existsSync(indexPath)) {
                res.sendFile(indexPath);
            } else {
                res.status(500).json({ 
                    error: 'Admin frontend files not found',
                    adminPath,
                    indexPath,
                    adminExists: require('fs').existsSync(adminPath),
                    indexExists: require('fs').existsSync(indexPath)
                });
            }
        }
    } else {
        // Redirect to admin domain
        res.redirect(`https://${process.env.ADMIN_DOMAIN}/admin`);
    }
});

// Handle admin domain root
app.get('/', (req, res) => {
    if (req.get('host') === process.env.ADMIN_DOMAIN) {
        // Admin domain root - redirect to admin interface
        res.redirect('/admin');
        return;
    }
    
    // Main domain - serve main interface
    const indexPath = path.join(__dirname, 'frontend/index.html');
    if (require('fs').existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(500).json({ 
            error: 'Frontend files not found',
            path: indexPath,
            exists: require('fs').existsSync(indexPath)
        });
    }
});

// Catch-all handler for SPA routing
app.get('*', (req, res) => {
    const indexPath = path.join(__dirname, 'frontend/index.html');
    if (require('fs').existsSync(indexPath)) {
        res.sendFile(indexPath);
    } else {
        res.status(404).json({ 
            error: 'Frontend files not found',
            path: indexPath,
            exists: require('fs').existsSync(indexPath),
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