const express = require('express');
const router = express.Router();
const Joi = require('joi');
const db = require('../config/database');
const { authenticateToken, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

// Validation schemas
const associationSchema = Joi.object({
    name: Joi.string().min(1).max(255).required(),
    code: Joi.string().min(2).max(10).pattern(/^[A-Z0-9]+$/).required(),
    description: Joi.string().max(1000).optional(),
    settings: Joi.object().optional()
});

// Get all associations (super admin only)
router.get('/', authenticateToken, async (req, res) => {
    try {
        // Super admins can see all associations, regular admins only see their own
        let query = `
            SELECT 
                a.*,
                COUNT(m.id) as member_count
            FROM associations a
            LEFT JOIN members m ON a.id = m.association_id
        `;
        let params = [];
        
        if (req.user.role === 'super_admin') {
            // Super admin sees all associations
            query += ` GROUP BY a.id ORDER BY a.name`;
        } else {
            // Regular admin sees only their association
            query += ` WHERE a.id = $1 GROUP BY a.id ORDER BY a.name`;
            params.push(req.user.association_id);
        }
        
        const result = await db.query(`
            ${query}
        `, params);

        res.json(result.rows);
    } catch (error) {
        logger.error('Error fetching associations:', error);
        res.status(500).json({ error: 'Failed to fetch associations' });
    }
});

// Get current user's association
router.get('/current', authenticateToken, async (req, res) => {
    try {
        if (!req.user.association_id) {
            return res.status(404).json({ error: 'No association assigned' });
        }

        const result = await db.query(`
            SELECT 
                a.*,
                COUNT(m.id) as member_count
            FROM associations a
            LEFT JOIN members m ON a.id = m.association_id
            WHERE a.id = $1
            GROUP BY a.id
        `, [req.user.association_id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Association not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching current association:', error);
        res.status(500).json({ error: 'Failed to fetch association' });
    }
});

// Get association by code (public endpoint for login pages)
router.get('/by-code/:code', async (req, res) => {
    try {
        const result = await db.query(`
            SELECT 
                a.*,
                COUNT(m.id) as member_count
            FROM associations a
            LEFT JOIN members m ON a.id = m.association_id
            WHERE a.code = $1 AND a.status = 'active'
            GROUP BY a.id
        `, [req.params.code]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Association not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching association by code:', error);
        res.status(500).json({ error: 'Failed to fetch association' });
    }
});
// Get single association
router.get('/:id', authenticateToken, async (req, res) => {
    try {
        // Check permissions
        if (req.user.role !== 'super_admin' && req.user.association_id !== req.params.id) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const result = await db.query(`
            SELECT 
                a.*,
                COUNT(m.id) as member_count
            FROM associations a
            LEFT JOIN members m ON a.id = m.association_id
            WHERE a.id = $1
            GROUP BY a.id
        `, [req.params.id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Association not found' });
        }

        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching association:', error);
        res.status(500).json({ error: 'Failed to fetch association' });
    }
});

// Create association (super admin only)
router.post('/', authenticateToken, requireRole(['super_admin']), async (req, res) => {
    try {
        const { error, value } = associationSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        // Check if code already exists
        const existingAssoc = await db.query(
            'SELECT id FROM associations WHERE code = $1',
            [value.code]
        );

        if (existingAssoc.rows.length > 0) {
            return res.status(400).json({ error: 'Association code already exists' });
        }

        const result = await db.query(`
            INSERT INTO associations (name, code, description, settings, status)
            VALUES ($1, $2, $3, $4, $5)
            RETURNING *
        `, [
            value.name,
            value.code,
            value.description || null,
            JSON.stringify(value.settings || {}),
            'active'
        ]);

        logger.info('Association created', {
            associationId: result.rows[0].id,
            name: value.name,
            code: value.code,
            createdBy: req.user.id
        });

        res.status(201).json(result.rows[0]);
    } catch (error) {
        logger.error('Error creating association:', error);
        res.status(500).json({ error: 'Failed to create association' });
    }
});

// Update association
router.put('/:id', authenticateToken, async (req, res) => {
    try {
        // Check permissions
        if (req.user.role !== 'super_admin' && req.user.association_id !== req.params.id) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const { error, value } = associationSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        // Check if code already exists (excluding current association)
        const existingAssoc = await db.query(
            'SELECT id FROM associations WHERE code = $1 AND id != $2',
            [value.code, req.params.id]
        );

        if (existingAssoc.rows.length > 0) {
            return res.status(400).json({ error: 'Association code already exists' });
        }

        const result = await db.query(`
            UPDATE associations 
            SET name = $1, code = $2, description = $3, settings = $4, updated_at = NOW()
            WHERE id = $5
            RETURNING *
        `, [
            value.name,
            value.code,
            value.description || null,
            JSON.stringify(value.settings || {}),
            req.params.id
        ]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Association not found' });
        }

        logger.info('Association updated', {
            associationId: req.params.id,
            updatedBy: req.user.id
        });

        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error updating association:', error);
        res.status(500).json({ error: 'Failed to update association' });
    }
});

// Delete association (super admin only)
router.delete('/:id', authenticateToken, requireRole(['super_admin']), async (req, res) => {
    try {
        // Check if association has members
        const memberCount = await db.query(
            'SELECT COUNT(*) as count FROM members WHERE association_id = $1',
            [req.params.id]
        );

        if (parseInt(memberCount.rows[0].count) > 0) {
            return res.status(400).json({ 
                error: 'Cannot delete association with existing members' 
            });
        }

        const result = await db.query(
            'DELETE FROM associations WHERE id = $1 RETURNING id, name',
            [req.params.id]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Association not found' });
        }

        logger.info('Association deleted', {
            associationId: req.params.id,
            name: result.rows[0].name,
            deletedBy: req.user.id
        });

        res.json({ message: 'Association deleted successfully' });
    } catch (error) {
        logger.error('Error deleting association:', error);
        res.status(500).json({ error: 'Failed to delete association' });
    }
});

// Get association statistics
router.get('/:id/stats', authenticateToken, async (req, res) => {
    try {
        // Check permissions
        if (req.user.role !== 'super_admin' && req.user.association_id !== req.params.id) {
            return res.status(403).json({ error: 'Access denied' });
        }

        const result = await db.query(`
            SELECT * FROM get_association_stats($1)
        `, [req.params.id]);

        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching association statistics:', error);
        res.status(500).json({ error: 'Failed to fetch statistics' });
    }
});

module.exports = router;