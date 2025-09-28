const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const router = express.Router();
const { authenticateToken } = require('../middleware/auth');
const logger = require('../utils/logger');

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        const uploadDir = process.env.UPLOAD_DIR || '/var/lib/member-management/uploads';
        
        // Create directory if it doesn't exist
        if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
        }
        
        cb(null, uploadDir);
    },
    filename: (req, file, cb) => {
        // Generate unique filename
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const ext = path.extname(file.originalname);
        cb(null, `${file.fieldname}-${uniqueSuffix}${ext}`);
    }
});

// File filter for allowed types
const fileFilter = (req, file, cb) => {
    const allowedTypes = [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'image/jpeg',
        'image/png',
        'image/gif'
    ];
    
    if (allowedTypes.includes(file.mimetype)) {
        cb(null, true);
    } else {
        cb(new Error('Invalid file type. Only PDF, Word documents, and images are allowed.'), false);
    }
};

const upload = multer({
    storage: storage,
    limits: {
        fileSize: parseInt(process.env.MAX_FILE_SIZE) || 10 * 1024 * 1024 // 10MB default
    },
    fileFilter: fileFilter
});

// Upload single file
router.post('/single', authenticateToken, upload.single('file'), (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        logger.info('File uploaded', {
            userId: req.user.id,
            filename: req.file.filename,
            originalName: req.file.originalname,
            size: req.file.size
        });

        res.json({
            message: 'File uploaded successfully',
            file: {
                filename: req.file.filename,
                originalName: req.file.originalname,
                size: req.file.size,
                mimetype: req.file.mimetype,
                url: `/api/upload/files/${req.file.filename}`
            }
        });
    } catch (error) {
        logger.error('File upload error:', error);
        res.status(500).json({ error: 'File upload failed' });
    }
});

// Upload multiple files
router.post('/multiple', authenticateToken, upload.array('files', 10), (req, res) => {
    try {
        if (!req.files || req.files.length === 0) {
            return res.status(400).json({ error: 'No files uploaded' });
        }

        const uploadedFiles = req.files.map(file => ({
            filename: file.filename,
            originalName: file.originalname,
            size: file.size,
            mimetype: file.mimetype,
            url: `/api/upload/files/${file.filename}`
        }));

        logger.info('Multiple files uploaded', {
            userId: req.user.id,
            fileCount: req.files.length,
            totalSize: req.files.reduce((sum, file) => sum + file.size, 0)
        });

        res.json({
            message: 'Files uploaded successfully',
            files: uploadedFiles
        });
    } catch (error) {
        logger.error('Multiple file upload error:', error);
        res.status(500).json({ error: 'File upload failed' });
    }
});

// Serve uploaded files
router.get('/files/:filename', authenticateToken, (req, res) => {
    try {
        const filename = req.params.filename;
        const uploadDir = process.env.UPLOAD_DIR || '/var/lib/member-management/uploads';
        const filePath = path.join(uploadDir, filename);

        // Security check - ensure file is within upload directory
        const resolvedPath = path.resolve(filePath);
        const resolvedUploadDir = path.resolve(uploadDir);
        
        if (!resolvedPath.startsWith(resolvedUploadDir)) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Check if file exists
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'File not found' });
        }

        // Get file stats
        const stats = fs.statSync(filePath);
        const ext = path.extname(filename).toLowerCase();

        // Set appropriate content type
        let contentType = 'application/octet-stream';
        switch (ext) {
            case '.pdf':
                contentType = 'application/pdf';
                break;
            case '.doc':
                contentType = 'application/msword';
                break;
            case '.docx':
                contentType = 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
                break;
            case '.jpg':
            case '.jpeg':
                contentType = 'image/jpeg';
                break;
            case '.png':
                contentType = 'image/png';
                break;
            case '.gif':
                contentType = 'image/gif';
                break;
        }

        res.setHeader('Content-Type', contentType);
        res.setHeader('Content-Length', stats.size);
        res.setHeader('Cache-Control', 'public, max-age=31536000'); // 1 year cache

        // Stream the file
        const fileStream = fs.createReadStream(filePath);
        fileStream.pipe(res);

    } catch (error) {
        logger.error('File serving error:', error);
        res.status(500).json({ error: 'Failed to serve file' });
    }
});

// Delete uploaded file
router.delete('/files/:filename', authenticateToken, (req, res) => {
    try {
        const filename = req.params.filename;
        const uploadDir = process.env.UPLOAD_DIR || '/var/lib/member-management/uploads';
        const filePath = path.join(uploadDir, filename);

        // Security check - ensure file is within upload directory
        const resolvedPath = path.resolve(filePath);
        const resolvedUploadDir = path.resolve(uploadDir);
        
        if (!resolvedPath.startsWith(resolvedUploadDir)) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Check if file exists
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'File not found' });
        }

        // Delete the file
        fs.unlinkSync(filePath);

        logger.info('File deleted', {
            userId: req.user.id,
            filename: filename
        });

        res.json({ message: 'File deleted successfully' });

    } catch (error) {
        logger.error('File deletion error:', error);
        res.status(500).json({ error: 'Failed to delete file' });
    }
});

// Get file information
router.get('/info/:filename', authenticateToken, (req, res) => {
    try {
        const filename = req.params.filename;
        const uploadDir = process.env.UPLOAD_DIR || '/var/lib/member-management/uploads';
        const filePath = path.join(uploadDir, filename);

        // Security check - ensure file is within upload directory
        const resolvedPath = path.resolve(filePath);
        const resolvedUploadDir = path.resolve(uploadDir);
        
        if (!resolvedPath.startsWith(resolvedUploadDir)) {
            return res.status(403).json({ error: 'Access denied' });
        }

        // Check if file exists
        if (!fs.existsSync(filePath)) {
            return res.status(404).json({ error: 'File not found' });
        }

        const stats = fs.statSync(filePath);
        const ext = path.extname(filename);

        res.json({
            filename: filename,
            size: stats.size,
            extension: ext,
            created: stats.birthtime,
            modified: stats.mtime,
            url: `/api/upload/files/${filename}`
        });

    } catch (error) {
        logger.error('File info error:', error);
        res.status(500).json({ error: 'Failed to get file information' });
    }
});

// Error handling middleware for multer
router.use((error, req, res, next) => {
    if (error instanceof multer.MulterError) {
        if (error.code === 'LIMIT_FILE_SIZE') {
            return res.status(413).json({ error: 'File too large' });
        }
        if (error.code === 'LIMIT_FILE_COUNT') {
            return res.status(413).json({ error: 'Too many files' });
        }
        if (error.code === 'LIMIT_UNEXPECTED_FILE') {
            return res.status(400).json({ error: 'Unexpected file field' });
        }
    }
    
    if (error.message.includes('Invalid file type')) {
        return res.status(400).json({ error: error.message });
    }
    
    logger.error('Upload middleware error:', error);
    res.status(500).json({ error: 'Upload failed' });
});

module.exports = router;