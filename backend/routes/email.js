const express = require('express');
const router = express.Router();
const Joi = require('joi');
const db = require('../config/database');
const emailService = require('../services/emailService');
const { authenticateToken, requireRole } = require('../middleware/auth');
const logger = require('../utils/logger');

// Validation schemas
const campaignSchema = Joi.object({
    mailing_list_id: Joi.string().uuid().optional(),
    subject: Joi.string().min(1).max(255).required(),
    content: Joi.string().min(1).required(),
    template_name: Joi.string().max(100).optional(),
    scheduled_at: Joi.date().iso().optional()
});

const testEmailSchema = Joi.object({
    to: Joi.string().email().required(),
    subject: Joi.string().min(1).max(255).required(),
    content: Joi.string().min(1).required()
});

// Get email campaigns for association
router.get('/campaigns', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                ec.*,
                ml.name as mailing_list_name,
                u.name as sender_name
            FROM email_campaigns ec
            LEFT JOIN mailing_lists ml ON ec.mailing_list_id = ml.id
            LEFT JOIN users u ON ec.sender_id = u.id
            WHERE ec.association_id = $1
            ORDER BY ec.created_at DESC
        `, [req.user.association_id]);

        client.release();
        res.json(result.rows);
    } catch (error) {
        logger.error('Error fetching email campaigns:', error);
        res.status(500).json({ error: 'Failed to fetch email campaigns' });
    }
});

// Get single campaign
router.get('/campaigns/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                ec.*,
                ml.name as mailing_list_name,
                u.name as sender_name
            FROM email_campaigns ec
            LEFT JOIN mailing_lists ml ON ec.mailing_list_id = ml.id
            LEFT JOIN users u ON ec.sender_id = u.id
            WHERE ec.id = $1 AND ec.association_id = $2
        `, [req.params.id, req.user.association_id]);

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Campaign not found' });
        }

        client.release();
        res.json(result.rows[0]);
    } catch (error) {
        logger.error('Error fetching email campaign:', error);
        res.status(500).json({ error: 'Failed to fetch email campaign' });
    }
});

// Create email campaign
router.post('/campaigns', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { error, value } = campaignSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        if (!emailService.isAvailable()) {
            return res.status(503).json({ error: 'Email service not configured' });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            INSERT INTO email_campaigns 
            (association_id, mailing_list_id, sender_id, subject, content, template_name, scheduled_at)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING *
        `, [
            req.user.association_id,
            value.mailing_list_id || null,
            req.user.id,
            value.subject,
            value.content,
            value.template_name || null,
            value.scheduled_at || null
        ]);

        client.release();
        res.status(201).json(result.rows[0]);
    } catch (error) {
        logger.error('Error creating email campaign:', error);
        res.status(500).json({ error: 'Failed to create email campaign' });
    }
});

// Send email campaign
router.post('/campaigns/:id/send', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        if (!emailService.isAvailable()) {
            return res.status(503).json({ error: 'Email service not configured' });
        }

        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        // Get campaign details
        const campaignResult = await client.query(`
            SELECT * FROM email_campaigns 
            WHERE id = $1 AND association_id = $2 AND status = 'draft'
        `, [req.params.id, req.user.association_id]);

        if (campaignResult.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Campaign not found or already sent' });
        }

        const campaign = campaignResult.rows[0];

        // Get recipients
        let recipientsQuery;
        let recipientsParams;

        if (campaign.mailing_list_id) {
            // Send to specific mailing list
            recipientsQuery = `
                SELECT DISTINCT
                    m.id as member_id,
                    m.name,
                    m.email,
                    a.name as association_name
                FROM mailing_list_subscriptions mls
                JOIN members m ON mls.member_id = m.id
                JOIN associations a ON m.association_id = a.id
                WHERE mls.mailing_list_id = $1 
                AND mls.is_active = true
                AND m.status = 'active'
            `;
            recipientsParams = [campaign.mailing_list_id];
        } else {
            // Send to all active members in association
            recipientsQuery = `
                SELECT 
                    m.id as member_id,
                    m.name,
                    m.email,
                    a.name as association_name
                FROM members m
                JOIN associations a ON m.association_id = a.id
                WHERE m.association_id = $1 
                AND m.status = 'active'
            `;
            recipientsParams = [req.user.association_id];
        }

        const recipientsResult = await client.query(recipientsQuery, recipientsParams);
        const recipients = recipientsResult.rows;

        if (recipients.length === 0) {
            client.release();
            return res.status(400).json({ error: 'No recipients found' });
        }

        client.release();

        // Send emails in background
        setImmediate(async () => {
            try {
                await emailService.sendBulkEmail(
                    campaign.id,
                    recipients,
                    campaign.subject,
                    campaign.content,
                    campaign.content // TODO: Convert HTML to text
                );
            } catch (error) {
                logger.error('Error sending bulk email:', error);
            }
        });

        res.json({ 
            message: 'Email campaign started',
            recipient_count: recipients.length
        });

    } catch (error) {
        logger.error('Error sending email campaign:', error);
        res.status(500).json({ error: 'Failed to send email campaign' });
    }
});

// Get campaign delivery logs
router.get('/campaigns/:id/logs', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                edl.*,
                m.name as member_name
            FROM email_delivery_logs edl
            LEFT JOIN members m ON edl.member_id = m.id
            JOIN email_campaigns ec ON edl.campaign_id = ec.id
            WHERE edl.campaign_id = $1 AND ec.association_id = $2
            ORDER BY edl.created_at DESC
        `, [req.params.id, req.user.association_id]);

        client.release();
        res.json(result.rows);
    } catch (error) {
        logger.error('Error fetching campaign logs:', error);
        res.status(500).json({ error: 'Failed to fetch campaign logs' });
    }
});

// Send test email
router.post('/test', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const { error, value } = testEmailSchema.validate(req.body);
        if (error) {
            return res.status(400).json({ error: error.details[0].message });
        }

        if (!emailService.isAvailable()) {
            return res.status(503).json({ error: 'Email service not configured' });
        }

        await emailService.sendEmail({
            to: value.to,
            subject: `[TEST] ${value.subject}`,
            html: value.content,
            text: value.content
        });

        res.json({ message: 'Test email sent successfully' });
    } catch (error) {
        logger.error('Error sending test email:', error);
        res.status(500).json({ error: 'Failed to send test email' });
    }
});

// Get email statistics
router.get('/stats', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            SELECT 
                COUNT(*) as total_campaigns,
                COUNT(CASE WHEN status = 'sent' THEN 1 END) as sent_campaigns,
                COUNT(CASE WHEN status = 'draft' THEN 1 END) as draft_campaigns,
                COALESCE(SUM(recipient_count), 0) as total_emails_sent,
                COALESCE(SUM(delivered_count), 0) as total_delivered,
                COALESCE(SUM(opened_count), 0) as total_opened,
                COALESCE(SUM(clicked_count), 0) as total_clicked,
                COALESCE(SUM(bounced_count), 0) as total_bounced
            FROM email_campaigns
            WHERE association_id = $1
        `, [req.user.association_id]);

        const stats = result.rows[0];
        
        // Calculate rates
        const deliveryRate = stats.total_emails_sent > 0 
            ? (stats.total_delivered / stats.total_emails_sent * 100).toFixed(2)
            : 0;
        
        const openRate = stats.total_delivered > 0 
            ? (stats.total_opened / stats.total_delivered * 100).toFixed(2)
            : 0;
        
        const clickRate = stats.total_delivered > 0 
            ? (stats.total_clicked / stats.total_delivered * 100).toFixed(2)
            : 0;

        client.release();
        res.json({
            ...stats,
            delivery_rate: parseFloat(deliveryRate),
            open_rate: parseFloat(openRate),
            click_rate: parseFloat(clickRate)
        });
    } catch (error) {
        logger.error('Error fetching email statistics:', error);
        res.status(500).json({ error: 'Failed to fetch email statistics' });
    }
});

// Resend webhook endpoint
router.post('/webhook', async (req, res) => {
    try {
        // TODO: Verify webhook signature for security
        await emailService.handleWebhook(req.body);
        res.status(200).json({ received: true });
    } catch (error) {
        logger.error('Error handling email webhook:', error);
        res.status(500).json({ error: 'Webhook processing failed' });
    }
});

// Delete campaign
router.delete('/campaigns/:id', authenticateToken, requireRole(['admin']), async (req, res) => {
    try {
        const client = await db.getClient();
        await db.setUserContext(client, req.user.id);

        const result = await client.query(`
            DELETE FROM email_campaigns 
            WHERE id = $1 AND association_id = $2 AND status = 'draft'
            RETURNING id
        `, [req.params.id, req.user.association_id]);

        if (result.rows.length === 0) {
            client.release();
            return res.status(404).json({ error: 'Campaign not found or cannot be deleted' });
        }

        client.release();
        res.json({ message: 'Campaign deleted successfully' });
    } catch (error) {
        logger.error('Error deleting email campaign:', error);
        res.status(500).json({ error: 'Failed to delete email campaign' });
    }
});

module.exports = router;