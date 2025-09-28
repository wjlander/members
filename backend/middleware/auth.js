const jwt = require('jsonwebtoken');
const db = require('../config/database');
const logger = require('../utils/logger');

// Authenticate JWT token
const authenticateToken = async (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];

    if (!token) {
        return res.status(401).json({ error: 'Access token required' });
    }

    try {
        const decoded = jwt.verify(token, process.env.JWT_SECRET);
        
        // Get user details from database
        const result = await db.query(`
            SELECT u.*, a.name as association_name 
            FROM users u
            LEFT JOIN associations a ON u.association_id = a.id
            WHERE u.id = $1
        `, [decoded.userId]);

        if (result.rows.length === 0) {
            return res.status(401).json({ error: 'Invalid token' });
        }

        req.user = result.rows[0];
        next();
    } catch (error) {
        logger.error('Token verification failed:', error);
        return res.status(403).json({ error: 'Invalid or expired token' });
    }
};

// Require specific role(s)
const requireRole = (roles) => {
    return (req, res, next) => {
        if (!req.user) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        if (!roles.includes(req.user.role)) {
            logger.warn('Unauthorized access attempt', {
                userId: req.user.id,
                userRole: req.user.role,
                requiredRoles: roles,
                endpoint: req.path
            });
            return res.status(403).json({ error: 'Insufficient permissions' });
        }

        next();
    };
};

// Require association membership
const requireAssociation = async (req, res, next) => {
    if (!req.user) {
        return res.status(401).json({ error: 'Authentication required' });
    }

    if (req.user.role === 'super_admin') {
        return next(); // Super admin can access all associations
    }

    if (!req.user.association_id) {
        return res.status(403).json({ error: 'No association assigned' });
    }

    next();
};

module.exports = {
    authenticateToken,
    requireRole,
    requireAssociation
};