const { Resend } = require('resend');
const logger = require('../utils/logger');
const db = require('../config/database');

class EmailService {
    constructor() {
        this.resend = process.env.RESEND_API_KEY ? new Resend(process.env.RESEND_API_KEY) : null;
        this.fromEmail = process.env.FROM_EMAIL || 'noreply@example.com';
        
        if (!this.resend) {
            logger.warn('Resend API key not configured - email features will be disabled');
        }
    }

    // Check if email service is available
    isAvailable() {
        return !!this.resend;
    }

    // Send a single email
    async sendEmail({ to, subject, html, text, replyTo }) {
        if (!this.isAvailable()) {
            throw new Error('Email service not configured');
        }

        try {
            const result = await this.resend.emails.send({
                from: this.fromEmail,
                to: Array.isArray(to) ? to : [to],
                subject,
                html,
                text,
                reply_to: replyTo
            });

            logger.info('Email sent successfully', { 
                to: Array.isArray(to) ? to.join(', ') : to, 
                subject,
                messageId: result.data?.id 
            });

            return result;
        } catch (error) {
            logger.error('Failed to send email', { 
                to: Array.isArray(to) ? to.join(', ') : to, 
                subject, 
                error: error.message 
            });
            throw error;
        }
    }

    // Send bulk emails to mailing list
    async sendBulkEmail(campaignId, recipients, subject, html, text) {
        if (!this.isAvailable()) {
            throw new Error('Email service not configured');
        }

        const results = [];
        const batchSize = 50; // Resend batch limit

        try {
            // Update campaign status
            await db.query(
                'UPDATE email_campaigns SET status = $1, sent_at = NOW() WHERE id = $2',
                ['sending', campaignId]
            );

            // Process recipients in batches
            for (let i = 0; i < recipients.length; i += batchSize) {
                const batch = recipients.slice(i, i + batchSize);
                const batchResults = await this.processBatch(campaignId, batch, subject, html, text);
                results.push(...batchResults);
            }

            // Update campaign statistics
            const delivered = results.filter(r => r.status === 'delivered').length;
            const failed = results.filter(r => r.status === 'failed').length;

            await db.query(`
                UPDATE email_campaigns 
                SET status = $1, delivered_count = $2, recipient_count = $3
                WHERE id = $4
            `, ['sent', delivered, recipients.length, campaignId]);

            logger.info('Bulk email campaign completed', {
                campaignId,
                total: recipients.length,
                delivered,
                failed
            });

            return {
                total: recipients.length,
                delivered,
                failed,
                results
            };

        } catch (error) {
            // Update campaign status to failed
            await db.query(
                'UPDATE email_campaigns SET status = $1 WHERE id = $2',
                ['failed', campaignId]
            );

            logger.error('Bulk email campaign failed', { campaignId, error: error.message });
            throw error;
        }
    }

    // Process a batch of recipients
    async processBatch(campaignId, recipients, subject, html, text) {
        const results = [];

        for (const recipient of recipients) {
            try {
                const result = await this.resend.emails.send({
                    from: this.fromEmail,
                    to: recipient.email,
                    subject,
                    html: this.personalizeContent(html, recipient),
                    text: this.personalizeContent(text, recipient)
                });

                // Log successful delivery
                await db.query(`
                    INSERT INTO email_delivery_logs 
                    (campaign_id, member_id, email, status, resend_message_id, delivered_at)
                    VALUES ($1, $2, $3, $4, $5, NOW())
                `, [campaignId, recipient.member_id, recipient.email, 'delivered', result.data?.id]);

                results.push({
                    email: recipient.email,
                    status: 'delivered',
                    messageId: result.data?.id
                });

            } catch (error) {
                // Log failed delivery
                await db.query(`
                    INSERT INTO email_delivery_logs 
                    (campaign_id, member_id, email, status, error_message)
                    VALUES ($1, $2, $3, $4, $5)
                `, [campaignId, recipient.member_id, recipient.email, 'failed', error.message]);

                results.push({
                    email: recipient.email,
                    status: 'failed',
                    error: error.message
                });

                logger.error('Failed to send email to recipient', {
                    email: recipient.email,
                    error: error.message
                });
            }

            // Small delay to avoid rate limiting
            await new Promise(resolve => setTimeout(resolve, 100));
        }

        return results;
    }

    // Personalize email content with recipient data
    personalizeContent(content, recipient) {
        if (!content) return content;

        return content
            .replace(/\{\{name\}\}/g, recipient.name || 'Member')
            .replace(/\{\{email\}\}/g, recipient.email || '')
            .replace(/\{\{member_id\}\}/g, recipient.member_id || '')
            .replace(/\{\{association_name\}\}/g, recipient.association_name || '');
    }

    // Send welcome email to new member
    async sendWelcomeEmail(member, association) {
        const subject = `Welcome to ${association.name}!`;
        const html = this.getWelcomeEmailTemplate(member, association);
        const text = this.getWelcomeEmailText(member, association);

        return await this.sendEmail({
            to: member.email,
            subject,
            html,
            text
        });
    }

    // Send member approval notification
    async sendApprovalEmail(member, association) {
        const subject = `Your membership has been approved - ${association.name}`;
        const html = this.getApprovalEmailTemplate(member, association);
        const text = this.getApprovalEmailText(member, association);

        return await this.sendEmail({
            to: member.email,
            subject,
            html,
            text
        });
    }

    // Send password reset email
    async sendPasswordResetEmail(user, resetToken) {
        const subject = 'Password Reset Request';
        const resetUrl = `https://${process.env.MAIN_DOMAIN}/reset-password?token=${resetToken}`;
        
        const html = `
            <h2>Password Reset Request</h2>
            <p>Hello ${user.name},</p>
            <p>You requested a password reset for your account. Click the link below to reset your password:</p>
            <p><a href="${resetUrl}" style="background-color: #007bff; color: white; padding: 10px 20px; text-decoration: none; border-radius: 5px;">Reset Password</a></p>
            <p>This link will expire in 1 hour.</p>
            <p>If you didn't request this reset, please ignore this email.</p>
        `;

        const text = `
            Password Reset Request
            
            Hello ${user.name},
            
            You requested a password reset for your account. Visit the following link to reset your password:
            ${resetUrl}
            
            This link will expire in 1 hour.
            
            If you didn't request this reset, please ignore this email.
        `;

        return await this.sendEmail({
            to: user.email,
            subject,
            html,
            text
        });
    }

    // Email templates
    getWelcomeEmailTemplate(member, association) {
        return `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Welcome to ${association.name}</title>
            </head>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h1 style="color: #007bff;">Welcome to ${association.name}!</h1>
                    
                    <p>Dear ${member.name},</p>
                    
                    <p>Thank you for registering with ${association.name}. Your membership application has been received and is currently under review.</p>
                    
                    <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
                        <h3>Your Member Details:</h3>
                        <p><strong>Member ID:</strong> ${member.member_id}</p>
                        <p><strong>Email:</strong> ${member.email}</p>
                        <p><strong>Status:</strong> Pending Approval</p>
                    </div>
                    
                    <p>You will receive another email once your membership has been approved by our administrators.</p>
                    
                    <p>If you have any questions, please don't hesitate to contact us.</p>
                    
                    <p>Best regards,<br>
                    ${association.name} Team</p>
                </div>
            </body>
            </html>
        `;
    }

    getWelcomeEmailText(member, association) {
        return `
            Welcome to ${association.name}!
            
            Dear ${member.name},
            
            Thank you for registering with ${association.name}. Your membership application has been received and is currently under review.
            
            Your Member Details:
            Member ID: ${member.member_id}
            Email: ${member.email}
            Status: Pending Approval
            
            You will receive another email once your membership has been approved by our administrators.
            
            If you have any questions, please don't hesitate to contact us.
            
            Best regards,
            ${association.name} Team
        `;
    }

    getApprovalEmailTemplate(member, association) {
        return `
            <!DOCTYPE html>
            <html>
            <head>
                <meta charset="utf-8">
                <title>Membership Approved - ${association.name}</title>
            </head>
            <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
                    <h1 style="color: #28a745;">Membership Approved!</h1>
                    
                    <p>Dear ${member.name},</p>
                    
                    <p>Congratulations! Your membership with ${association.name} has been approved.</p>
                    
                    <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #28a745;">
                        <h3>You now have full access to:</h3>
                        <ul>
                            <li>Member portal and profile management</li>
                            <li>Association events and activities</li>
                            <li>Member communications and newsletters</li>
                            <li>Online dues payment system</li>
                        </ul>
                    </div>
                    
                    <p>You can now log in to your member portal at: <a href="https://${process.env.MAIN_DOMAIN}">https://${process.env.MAIN_DOMAIN}</a></p>
                    
                    <p>Welcome to the ${association.name} community!</p>
                    
                    <p>Best regards,<br>
                    ${association.name} Team</p>
                </div>
            </body>
            </html>
        `;
    }

    getApprovalEmailText(member, association) {
        return `
            Membership Approved!
            
            Dear ${member.name},
            
            Congratulations! Your membership with ${association.name} has been approved.
            
            You now have full access to:
            - Member portal and profile management
            - Association events and activities
            - Member communications and newsletters
            - Online dues payment system
            
            You can now log in to your member portal at: https://${process.env.MAIN_DOMAIN}
            
            Welcome to the ${association.name} community!
            
            Best regards,
            ${association.name} Team
        `;
    }

    // Handle email webhooks (for tracking opens, clicks, bounces)
    async handleWebhook(webhookData) {
        try {
            const { type, data } = webhookData;
            
            switch (type) {
                case 'email.delivered':
                    await this.handleDelivered(data);
                    break;
                case 'email.opened':
                    await this.handleOpened(data);
                    break;
                case 'email.clicked':
                    await this.handleClicked(data);
                    break;
                case 'email.bounced':
                    await this.handleBounced(data);
                    break;
                default:
                    logger.debug('Unhandled webhook type', { type });
            }
        } catch (error) {
            logger.error('Error handling email webhook', { error: error.message, webhookData });
        }
    }

    async handleDelivered(data) {
        await db.query(`
            UPDATE email_delivery_logs 
            SET status = 'delivered', delivered_at = NOW()
            WHERE resend_message_id = $1
        `, [data.email_id]);
    }

    async handleOpened(data) {
        await db.query(`
            UPDATE email_delivery_logs 
            SET opened_at = NOW()
            WHERE resend_message_id = $1
        `, [data.email_id]);
    }

    async handleClicked(data) {
        await db.query(`
            UPDATE email_delivery_logs 
            SET clicked_at = NOW()
            WHERE resend_message_id = $1
        `, [data.email_id]);
    }

    async handleBounced(data) {
        await db.query(`
            UPDATE email_delivery_logs 
            SET status = 'bounced', bounced_at = NOW(), error_message = $2
            WHERE resend_message_id = $1
        `, [data.email_id, data.reason]);
    }
}

module.exports = new EmailService();