const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const Joi = require('joi');
const router = express.Router();
const db = require('../config/database');
const emailService = require('../services/emailService');
const { authenticateToken } = require('../middleware/auth');
const logger = require('../utils/logger');

// Validation schemas
const registerSchema = Joi.object({
    name: Joi.string().min(1).max(255).required(),
    email: Joi.string().email().required(),
    password: Joi.string().min(8).required(),
    phone: Joi.string().max(20).optional(),
    association_id: Joi.string().uuid().required()
});

const loginSchema = Joi.object({
    email: Joi.string().email().required(),
    password: Joi.string().required(),
    association_id: Joi.string().uuid().optional()
});

// Register new user
router.post('/register', async (req, res) => {
    try {
        const { error, value } = registerSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        const { name, email, password, phone, association_id } = value;

        // Check if user already exists
        const existingUser = await db.query(
            'SELECT id FROM users WHERE email = $1',
            [email]
        );

        if (existingUser.rows.length > 0) {
            return res.status(400).json({ error: 'User already exists with this email' });
        }

        // Verify association exists
        const associationResult = await db.query(
            'SELECT id, name FROM associations WHERE id = $1 AND status = $2',
            [association_id, 'active']
        );

        if (associationResult.rows.length === 0) {
            return res.status(400).json({ error: 'Invalid association' });
        }

        const association = associationResult.rows[0];

        // Hash password
        const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
        const passwordHash = await bcrypt.hash(password, saltRounds);

        // Create user and member in transaction
        const result = await db.transaction(async (client) => {
            // Create user
            const userResult = await client.query(`
                INSERT INTO users (email, password_hash, name, role, association_id)
                VALUES ($1, $2, $3, $4, $5)
                RETURNING id, email, name, role, association_id
            `, [email, passwordHash, name, 'member', association_id]);

            const user = userResult.rows[0];

            // Create member record
            const memberResult = await client.query(`
                INSERT INTO members (user_id, association_id, name, email, phone, status)
                VALUES ($1, $2, $3, $4, $5, $6)
                RETURNING id, member_id
            `, [user.id, association_id, name, email, phone || null, 'pending']);

            return { user, member: memberResult.rows[0] };
        });

        // Send welcome email
        if (emailService.isAvailable()) {
            try {
                await emailService.sendWelcomeEmail(
                    { ...result.member, name, email },
                    association
                );
            } catch (emailError) {
                logger.error('Failed to send welcome email:', emailError);
                // Don't fail registration if email fails
            }
        }

        logger.info('New user registered', {
            userId: result.user.id,
            email,
            associationId: association_id
        });

        res.status(201).json({
            message: 'Registration successful. Your account is pending approval.',
            user: {
                id: result.user.id,
                email: result.user.email,
                name: result.user.name,
                member_id: result.member.member_id
            }
        });

    } catch (error) {
        logger.error('Registration error:', error);
        res.status(500).json({ error: 'Registration failed' });
    }
});

// Login user
router.post('/login', async (req, res) => {
    try {
        const { error, value } = loginSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        const { email, password, association_id } = value;

        // Get user with association info
        let query = `
            SELECT 
                u.*,
                a.name as association_name,
                m.status as member_status,
                m.member_id
            FROM users u
            LEFT JOIN associations a ON u.association_id = a.id
            LEFT JOIN members m ON u.id = m.user_id
            WHERE u.email = $1
        `;
        let params = [email];
        
        // If association_id is provided, filter by it (for regular admins)
        // Super admins can login without specifying association
        if (association_id) {
            query += ` AND u.association_id = $2`;
            params.push(association_id);
        }
        
        const result = await db.query(`
            ${query}
        `, params);

        if (result.rows.length === 0) {
            logger.warn('Login attempt with invalid credentials', { email, association_id });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        const user = result.rows[0];
        
        // If association_id was provided but user doesn't belong to it, deny access
        if (association_id && user.association_id !== association_id) {
            logger.warn('Login attempt with wrong association', { email, association_id, userAssociation: user.association_id });
            return res.status(401).json({ error: 'Invalid credentials' });
        }
        
        // Super admins can login without association, regular admins need association match
        if (user.role !== 'super_admin' && association_id && user.association_id !== association_id) {
            logger.warn('Non-super admin login with wrong association', { email, role: user.role });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Check password
        const validPassword = await bcrypt.compare(password, user.password_hash);
        if (!validPassword) {
            logger.warn('Login attempt with wrong password', { email, userId: user.id });
            return res.status(401).json({ error: 'Invalid credentials' });
        }

        // Check if member is approved (unless admin/super_admin)
        if (user.role === 'member' && user.member_status !== 'active') {
            return res.status(403).json({ 
                error: 'Account pending approval',
                status: user.member_status
            });
        }

        // Update last login
        await db.query(
            'UPDATE users SET last_login = NOW() WHERE id = $1',
            [user.id]
        );

        // Generate JWT token
        const token = jwt.sign(
            { 
                userId: user.id,
                email: user.email,
                role: user.role,
                associationId: user.association_id
            },
            process.env.JWT_SECRET,
            { expiresIn: process.env.JWT_EXPIRES_IN || '24h' }
        );

        logger.info('User logged in', {
            userId: user.id,
            email: user.email,
            role: user.role
        });

        res.json({
            token,
            user: {
                id: user.id,
                email: user.email,
                name: user.name,
                role: user.role,
                association_id: user.association_id,
                association_name: user.association_name,
                member_id: user.member_id,
                member_status: user.member_status
            }
        });

    } catch (error) {
        logger.error('Login error:', error);
        res.status(500).json({ error: 'Login failed' });
    }
});

// Get current user info
router.get('/me', authenticateToken, async (req, res) => {
    try {
        const result = await db.query(`
            SELECT 
                u.id, u.email, u.name, u.role, u.association_id,
                a.name as association_name,
                m.member_id, m.status as member_status
            FROM users u
            LEFT JOIN associations a ON u.association_id = a.id
            LEFT JOIN members m ON u.id = m.user_id
            WHERE u.id = $1
        `, [req.user.id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching user info:', error);
        res.status(500).json({ error: 'Failed to fetch user info' });
    }
});

// Logout (client-side token removal, but we can log it)
router.post('/logout', authenticateToken, (req, res) => {
    logger.info('User logged out', { userId: req.user.id });
    res.json({ message: 'Logged out successfully' });
});

// Change password
router.post('/change-password', authenticateToken, async (req, res) => {
    try {
        const schema = Joi.object({
            current_password: Joi.string().required(),
            new_password: Joi.string().min(8).required()
        });

        const { error, value } = schema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        const { current_password, new_password } = value;

        // Get current password hash
        const result = await db.query(
            'SELECT password_hash FROM users WHERE id = $1',
            [req.user.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'User not found' });
        }

        // Verify current password
        const validPassword = await bcrypt.compare(current_password, result.rows[0].password_hash);
        if (!validPassword) {
            return res.status(400).json({ error: 'Current password is incorrect' });
        }

        // Hash new password
        const saltRounds = parseInt(process.env.BCRYPT_ROUNDS) || 12;
        const newPasswordHash = await bcrypt.hash(new_password, saltRounds);

        // Update password
        await db.query(
            'UPDATE users SET password_hash = $1 WHERE id = $2',
            [newPasswordHash, req.user.id]
        );

        logger.info('Password changed', { userId: req.user.id });
        res.json({ message: 'Password changed successfully' });

    } catch (error) {
        logger.error('Error changing password:', error);
        res.status(500).json({ error: 'Failed to change password' });
    }
});

module.exports = router;