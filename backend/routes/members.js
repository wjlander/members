const express = require('express');
const router = express.Router();
const Joi = require('joi');
const db = require('../config/database');
const { authenticateToken, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

// Validation schemas
const memberSchema = Joi.object({
    name: Joi.string().min(1).max(255).required(),
    email: Joi.string().email().required(),
    phone: Joi.string().max(20).optional(),
    address: Joi.string().max(500).optional(),
    date_of_birth: Joi.date().optional(),
    membership_type: Joi.string().valid('regular', 'premium', 'student', 'senior', 'honorary').optional()
});

// Get all members for association
router.get('/', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { status, search, page = 1, limit = 50 } = req.query;
        
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        let query = `
            SELECT 
                m.*,
                u.email as user_email,
                u.last_login
            FROM members m
            LEFT JOIN users u ON m.user_id = u.id
            WHERE m.association_id = $1
        `;
        
        const params = [req.user.association_id];
        let paramCount = 1;

        if (status) {
            paramCount++;
            query += ` AND m.status = $${paramCount}`;
            params.push(status);
        }

        if (search) {
            paramCount++;
            query += ` AND (m.name ILIKE $${paramCount} OR m.email ILIKE $${paramCount})`;
            params.push(`%${search}%`);
        }

        query += ` ORDER BY m.created_at DESC LIMIT $${paramCount + 1} OFFSET $${paramCount + 2}`;
        params.push(parseInt(limit), (parseInt(page) - 1) * parseInt(limit));

        const result = await client.query(query, params);
        
        // Get total count
        let countQuery = `
            SELECT COUNT(*) as total
            FROM members m
            WHERE m.association_id = $1
        `;
        const countParams = [req.user.association_id];
        
        if (status) {
            countQuery += ` AND m.status = $2`;
            countParams.push(status);
        }
        
        const countResult = await client.query(countQuery, countParams);
        
        client.release();
        
        res.json({
            items: result.rows,
            totalItems: parseInt(countResult.rows[0].total),
            page: parseInt(page),
            perPage: parseInt(limit)
        });
    } catch (error) {
        logger.error('Error fetching members:', error);
        res.status(500).json({ error: 'Failed to fetch members' });
    }
});

// Get single member
router.get('/:id', authenticateToken, async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                m.*,
                u.email as user_email,
                u.last_login,
                a.name as association_name
            FROM members m
            LEFT JOIN users u ON m.user_id = u.id
            LEFT JOIN associations a ON m.association_id = a.id
            WHERE m.id = $1 AND (
                m.association_id = $2 OR 
                $3 = 'super_admin' OR
                m.user_id = $4
            )
        `, [req.params.id, req.user.association_id, req.user.role, req.user.id]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Member not found' });
        }

        client.release();
        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching member:', error);
        res.status(500).json({ error: 'Failed to fetch member' });
    }
});

// Update member
router.put('/:id', authenticateToken, async (req, res) => {
    try {
        const { error, value } = memberSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        // Check if member exists and user has permission
        const memberCheck = await client.query(`
            SELECT id, user_id FROM members 
            WHERE id = $1 AND (
                association_id = $2 OR 
                $3 = 'super_admin' OR
                user_id = $4
            )
        `, [req.params.id, req.user.association_id, req.user.role, req.user.id]);

        if (memberCheck.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Member not found or access denied' });
        }

        const result = await client.query(`
            UPDATE members 
            SET name = $1, email = $2, phone = $3, address = $4, 
                date_of_birth = $5, membership_type = $6, updated_at = NOW()
            WHERE id = $7
            RETURNING *
        `, [
            value.name, value.email, value.phone, value.address,
            value.date_of_birth, value.membership_type, req.params.id
        ]);

        // Also update user email if it changed
        if (memberCheck.rows[0].user_id) {
            await client.query(
                'UPDATE users SET email = $1 WHERE id = $2',
                [value.email, memberCheck.rows[0].user_id]
            );
        }

        client.release();
        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error updating member:', error);
        res.status(500).json({ error: 'Failed to update member' });
    }
});

// Approve member
router.post('/:id/approve', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            UPDATE members 
            SET status = 'active', updated_at = NOW()
            WHERE id = $1 AND association_id = $2 AND status = 'pending'
            RETURNING *
        `, [req.params.id, req.user.association_id]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Member not found or already approved' });
        }

        const member = result.rows[0];

        // Get association info for email
        const assocResult = await client.query(
            'SELECT name FROM associations WHERE id = $1',
            [req.user.association_id]
        );

        client.release();

        // Send approval email if email service is available
        const emailService = require('../services/emailService');
        if (emailService.isAvailable()) {
            try {
                await emailService.sendApprovalEmail(member, assocResult.rows[0]);
            } catch (emailError) {
                logger.error('Failed to send approval email:', emailError);
            }
        }

        res.json({ message: 'Member approved successfully', member });
    } catch (error) {
        logger.error('Error approving member:', error);
        res.status(500).json({ error: 'Failed to approve member' });
    }
});

// Get member statistics
router.get('/stats/summary', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                COUNT(*) as total_members,
                COUNT(CASE WHEN status = 'active' THEN 1 END) as active_members,
                COUNT(CASE WHEN status = 'pending' THEN 1 END) as pending_members,
                COUNT(CASE WHEN status = 'inactive' THEN 1 END) as inactive_members,
                COUNT(CASE WHEN status = 'suspended' THEN 1 END) as suspended_members
            FROM members
            WHERE association_id = $1
        `, [req.user.association_id]);

        client.release();
        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching member statistics:', error);
        res.status(500).json({ error: 'Failed to fetch statistics' });
    }
});

module.exports = router;