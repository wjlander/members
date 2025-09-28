const express = require('express');
const router = express.Router();
const Joi = require('joi');
const db = require('../config/database');
const { authenticateToken, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

// Validation schemas
const mailingListSchema = Joi.object({
    name: Joi.string().min(1).max(255).required(),
    description: Joi.string().max(1000).optional(),
    type: Joi.string().valid('general', 'announcements', 'events', 'newsletter', 'urgent', 'social').required(),
    moderator_email: Joi.string().email().optional(),
    auto_subscribe_new_members: Joi.boolean().default(false)
});

// Get all mailing lists for association
router.get('/', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                ml.*,
                get_mailing_list_subscriber_count(ml.id) as subscriber_count
            FROM mailing_lists ml
            WHERE ml.association_id = $1
            ORDER BY ml.name
        `, [req.user.association_id]);

        client.release();
        res.json(result.rows);
    } catch (error) {
        logger.error('Error fetching mailing lists:', error);
        res.status(500).json({ error: 'Failed to fetch mailing lists' });
    }
});

// Get single mailing list
router.get('/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                ml.*,
                get_mailing_list_subscriber_count(ml.id) as subscriber_count
            FROM mailing_lists ml
            WHERE ml.id = $1 AND ml.association_id = $2
        `, [req.params.id, req.user.association_id]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Mailing list not found' });
        }

        client.release();
        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching mailing list:', error);
        res.status(500).json({ error: 'Failed to fetch mailing list' });
    }
});

// Create mailing list
router.post('/', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { error, value } = mailingListSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            INSERT INTO mailing_lists 
            (association_id, name, description, type, moderator_email, auto_subscribe_new_members)
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
        `, [
            req.user.association_id,
            value.name,
            value.description || null,
            value.type,
            value.moderator_email || null,
            value.auto_subscribe_new_members
        ]);

        client.release();
        res.status(201).json(result.rows[0]);
    } catch (error) {
        if (error.code === '23505') { // Unique constraint violation
            return res.status(400).json({ error: 'Mailing list name already exists' });
        }
        logger.error('Error creating mailing list:', error);
        res.status(500).json({ error: 'Failed to create mailing list' });
    }
});

// Update mailing list
router.put('/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { error, value } = mailingListSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            UPDATE mailing_lists 
            SET name = $1, description = $2, type = $3, moderator_email = $4, 
                auto_subscribe_new_members = $5, updated_at = NOW()
            WHERE id = $6 AND association_id = $7
            RETURNING *
        `, [
            value.name,
            value.description || null,
            value.type,
            value.moderator_email || null,
            value.auto_subscribe_new_members,
            req.params.id,
            req.user.association_id
        ]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Mailing list not found' });
        }

        client.release();
        res.json(result.rows[0]);
    } catch (error) {
        if (error.code === '23505') { // Unique constraint violation
            return res.status(400).json({ error: 'Mailing list name already exists' });
        }
        logger.error('Error updating mailing list:', error);
        res.status(500).json({ error: 'Failed to update mailing list' });
    }
});

// Delete mailing list
router.delete('/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            DELETE FROM mailing_lists 
            WHERE id = $1 AND association_id = $2
            RETURNING id, name
        `, [req.params.id, req.user.association_id]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Mailing list not found' });
        }

        client.release();
        res.json({ message: 'Mailing list deleted successfully' });
    } catch (error) {
        logger.error('Error deleting mailing list:', error);
        res.status(500).json({ error: 'Failed to delete mailing list' });
    }
});

// Get subscribers for a mailing list
router.get('/:id/subscribers', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                mls.*,
                m.name as member_name,
                m.email as member_email,
                m.member_id
            FROM mailing_list_subscriptions mls
            JOIN members m ON mls.member_id = m.id
            JOIN mailing_lists ml ON mls.mailing_list_id = ml.id
            WHERE mls.mailing_list_id = $1 AND ml.association_id = $2
            ORDER BY m.name
        `, [req.params.id, req.user.association_id]);

        client.release();
        res.json(result.rows);
    } catch (error) {
        logger.error('Error fetching subscribers:', error);
        res.status(500).json({ error: 'Failed to fetch subscribers' });
    }
});

// Subscribe member to mailing list
router.post('/:id/subscribe', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { member_id } = req.body;
        
        if (!member_id) {
            return res.status(400).json({ error: 'Member ID is required' });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        // Verify mailing list belongs to association
        const listCheck = await client.query(
            'SELECT id FROM mailing_lists WHERE id = $1 AND association_id = $2',
            [req.params.id, req.user.association_id]
        );

        if (listCheck.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Mailing list not found' });
        }

        // Use the resubscribe function which handles existing subscriptions
        const result = await client.query(
            'SELECT resubscribe_to_mailing_list($1, $2) as success',
            [req.params.id, member_id]
        );

        client.release();
        res.json({ message: 'Member subscribed successfully' });
    } catch (error) {
        logger.error('Error subscribing member:', error);
        res.status(500).json({ error: 'Failed to subscribe member' });
    }
});

// Unsubscribe member from mailing list
router.post('/:id/unsubscribe', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { member_id } = req.body;
        
        if (!member_id) {
            return res.status(400).json({ error: 'Member ID is required' });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        // Verify mailing list belongs to association
        const listCheck = await client.query(
            'SELECT id FROM mailing_lists WHERE id = $1 AND association_id = $2',
            [req.params.id, req.user.association_id]
        );

        if (listCheck.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Mailing list not found' });
        }

        const result = await client.query(
            'SELECT unsubscribe_from_mailing_list($1, $2) as success',
            [req.params.id, member_id]
        );

        client.release();
        res.json({ message: 'Member unsubscribed successfully' });
    } catch (error) {
        logger.error('Error unsubscribing member:', error);
        res.status(500).json({ error: 'Failed to unsubscribe member' });
    }
});

// Export subscribers as CSV
router.get('/:id/export', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                m.name,
                m.email,
                m.phone,
                m.member_id,
                mls.subscribed_at
            FROM mailing_list_subscriptions mls
            JOIN members m ON mls.member_id = m.id
            JOIN mailing_lists ml ON mls.mailing_list_id = ml.id
            WHERE mls.mailing_list_id = $1 AND ml.association_id = $2 AND mls.is_active = true
            ORDER BY m.name
        `, [req.params.id, req.user.association_id]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'No subscribers found' });
        }

        // Convert to CSV
        const headers = ['Name', 'Email', 'Phone', 'Member ID', 'Subscribed Date'];
        const csvContent = [
            headers.join(','),
            ...result.rows.map(row => [
                `"${row.name}"`,
                `"${row.email}"`,
                `"${row.phone || ''}"`,
                `"${row.member_id}"`,
                `"${new Date(row.subscribed_at).toLocaleDateString()}"`
            ].join(','))
        ].join('\n');

        client.release();

        res.setHeader('Content-Type', 'text/csv');
        res.setHeader('Content-Disposition', `attachment; filename="mailing-list-subscribers-${Date.now()}.csv"`);
        res.send(csvContent);
    } catch (error) {
        logger.error('Error exporting subscribers:', error);
        res.status(500).json({ error: 'Failed to export subscribers' });
    }
});

module.exports = router;