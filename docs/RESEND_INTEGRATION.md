# Resend Email Integration Guide

This guide covers the complete integration of Resend email service for professional email communications in the Member Management System.

## Table of Contents

1. [Overview](#overview)
2. [Setup and Configuration](#setup-and-configuration)
3. [Email Service Features](#email-service-features)
4. [API Endpoints](#api-endpoints)
5. [Email Templates](#email-templates)
6. [Mailing Lists](#mailing-lists)
7. [Analytics and Tracking](#analytics-and-tracking)
8. [Best Practices](#best-practices)
9. [Troubleshooting](#troubleshooting)

## Overview

### What is Resend?

Resend is a modern email API service designed for developers, offering:
- High deliverability rates
- Real-time analytics
- Webhook support for tracking
- Simple API integration
- Competitive pricing

### Integration Benefits

1. **Professional Email Delivery**: High deliverability rates and reputation management
2. **Real-time Tracking**: Open rates, click rates, bounces, and delivery status
3. **Bulk Email Support**: Efficient mailing list management
4. **Template System**: Reusable email templates with personalization
5. **Webhook Integration**: Real-time event tracking and analytics
6. **Error Handling**: Robust retry logic and error reporting

## Setup and Configuration

### 1. Create Resend Account

1. Visit [resend.com](https://resend.com) and create an account
2. Verify your email address
3. Add and verify your sending domain
4. Generate an API key

### 2. Domain Verification

Add these DNS records to your domain:

```dns
# SPF Record
TXT @ "v=spf1 include:_spf.resend.com ~all"

# DKIM Record (provided by Resend)
TXT resend._domainkey "your-dkim-key-from-resend"

# DMARC Record (optional but recommended)
TXT _dmarc "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

### 3. Environment Configuration

Add to your `.env` file:

```bash
# Resend Configuration
RESEND_API_KEY=re_your_api_key_here
FROM_EMAIL=noreply@yourdomain.com

# Optional: Custom reply-to address
REPLY_TO_EMAIL=support@yourdomain.com
```

### 4. Application Configuration

The email service is automatically configured during deployment. Key configuration:

```javascript
// backend/services/emailService.js
const { Resend } = require('resend');

class EmailService {
    constructor() {
        this.resend = new Resend(process.env.RESEND_API_KEY);
        this.fromEmail = process.env.FROM_EMAIL;
    }
}
```

## Email Service Features

### Core Functionality

1. **Single Email Sending**: Individual email delivery
2. **Bulk Email Campaigns**: Mass email to mailing lists
3. **Template System**: Reusable email templates
4. **Personalization**: Dynamic content insertion
5. **Delivery Tracking**: Real-time status updates
6. **Error Handling**: Retry logic and failure management

### Supported Email Types

1. **Transactional Emails**:
   - Welcome emails
   - Account approval notifications
   - Password reset emails
   - Payment confirmations

2. **Marketing Emails**:
   - Newsletters
   - Event announcements
   - General communications
   - Promotional campaigns

3. **System Emails**:
   - Administrative notifications
   - System alerts
   - Backup reports
   - Error notifications

## API Endpoints

### Email Campaign Management

#### Create Campaign
```http
POST /api/email/campaigns
Content-Type: application/json
Authorization: Bearer <token>

{
    "mailing_list_id": "uuid-here",
    "subject": "Monthly Newsletter",
    "content": "<h1>Newsletter Content</h1>",
    "template_name": "newsletter",
    "scheduled_at": "2024-02-01T10:00:00Z"
}
```

#### Send Campaign
```http
POST /api/email/campaigns/{id}/send
Authorization: Bearer <token>
```

#### Get Campaigns
```http
GET /api/email/campaigns
Authorization: Bearer <token>
```

#### Get Campaign Details
```http
GET /api/email/campaigns/{id}
Authorization: Bearer <token>
```

### Email Testing

#### Send Test Email
```http
POST /api/email/test
Content-Type: application/json
Authorization: Bearer <token>

{
    "to": "test@example.com",
    "subject": "Test Email",
    "content": "<h1>Test Content</h1>"
}
```

### Analytics

#### Get Email Statistics
```http
GET /api/email/stats
Authorization: Bearer <token>
```

Response:
```json
{
    "total_campaigns": 25,
    "sent_campaigns": 20,
    "draft_campaigns": 5,
    "total_emails_sent": 1500,
    "total_delivered": 1485,
    "total_opened": 742,
    "total_clicked": 156,
    "total_bounced": 15,
    "delivery_rate": 99.0,
    "open_rate": 49.9,
    "click_rate": 10.5
}
```

#### Get Campaign Logs
```http
GET /api/email/campaigns/{id}/logs
Authorization: Bearer <token>
```

## Email Templates

### Template System

The email service includes a built-in template system with personalization:

```javascript
// Personalization variables
{{name}}              // Member name
{{email}}             // Member email
{{member_id}}         // Member ID
{{association_name}}  // Association name
```

### Built-in Templates

#### 1. Welcome Email Template

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Welcome to {{association_name}}</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #007bff;">Welcome to {{association_name}}!</h1>
        
        <p>Dear {{name}},</p>
        
        <p>Thank you for registering with {{association_name}}. Your membership application has been received and is currently under review.</p>
        
        <div style="background-color: #f8f9fa; padding: 15px; border-radius: 5px; margin: 20px 0;">
            <h3>Your Member Details:</h3>
            <p><strong>Member ID:</strong> {{member_id}}</p>
            <p><strong>Email:</strong> {{email}}</p>
            <p><strong>Status:</strong> Pending Approval</p>
        </div>
        
        <p>You will receive another email once your membership has been approved.</p>
        
        <p>Best regards,<br>
        {{association_name}} Team</p>
    </div>
</body>
</html>
```

#### 2. Approval Email Template

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Membership Approved - {{association_name}}</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
    <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
        <h1 style="color: #28a745;">Membership Approved!</h1>
        
        <p>Dear {{name}},</p>
        
        <p>Congratulations! Your membership with {{association_name}} has been approved.</p>
        
        <div style="background-color: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #28a745;">
            <h3>You now have full access to:</h3>
            <ul>
                <li>Member portal and profile management</li>
                <li>Association events and activities</li>
                <li>Member communications and newsletters</li>
                <li>Online dues payment system</li>
            </ul>
        </div>
        
        <p>You can now log in to your member portal at: <a href="https://{{domain}}">https://{{domain}}</a></p>
        
        <p>Welcome to the {{association_name}} community!</p>
        
        <p>Best regards,<br>
        {{association_name}} Team</p>
    </div>
</body>
</html>
```

### Custom Templates

Create custom templates by extending the email service:

```javascript
// Add to backend/services/emailService.js
getCustomTemplate(templateName, data) {
    const templates = {
        'event_reminder': `
            <h1>Event Reminder</h1>
            <p>Dear {{name}},</p>
            <p>Don't forget about our upcoming event: {{event_name}}</p>
            <p>Date: {{event_date}}</p>
            <p>Location: {{event_location}}</p>
        `,
        'payment_reminder': `
            <h1>Payment Reminder</h1>
            <p>Dear {{name}},</p>
            <p>Your payment of ${{amount}} is due on {{due_date}}.</p>
            <p>Please log in to your account to make a payment.</p>
        `
    };
    
    return this.personalizeContent(templates[templateName], data);
}
```

## Mailing Lists

### Mailing List Management

#### Create Mailing List
```http
POST /api/mailing-lists
Content-Type: application/json
Authorization: Bearer <token>

{
    "name": "Monthly Newsletter",
    "description": "Monthly updates and news",
    "type": "newsletter",
    "auto_subscribe_new_members": true
}
```

#### Subscribe Member
```http
POST /api/mailing-lists/{id}/subscribe
Content-Type: application/json
Authorization: Bearer <token>

{
    "member_id": "uuid-here"
}
```

#### Unsubscribe Member
```http
POST /api/mailing-lists/{id}/unsubscribe
Content-Type: application/json
Authorization: Bearer <token>

{
    "member_id": "uuid-here"
}
```

### Auto-Subscription

New members can be automatically subscribed to mailing lists:

```sql
-- Enable auto-subscription for a mailing list
UPDATE mailing_lists 
SET auto_subscribe_new_members = true 
WHERE id = 'list-uuid';
```

### Bulk Operations

#### Export Subscribers
```http
GET /api/mailing-lists/{id}/export
Authorization: Bearer <token>
```

#### Import Subscribers
```http
POST /api/mailing-lists/{id}/import
Content-Type: multipart/form-data
Authorization: Bearer <token>

file: subscribers.csv
```

## Analytics and Tracking

### Real-time Tracking

The system tracks email events in real-time:

1. **Delivery**: Email successfully delivered
2. **Opens**: Email opened by recipient
3. **Clicks**: Links clicked in email
4. **Bounces**: Email bounced back
5. **Complaints**: Spam complaints

### Webhook Integration

Resend webhooks are automatically handled:

```javascript
// Webhook endpoint: /api/email/webhook
router.post('/webhook', async (req, res) => {
    await emailService.handleWebhook(req.body);
    res.status(200).json({ received: true });
});
```

### Analytics Dashboard

View comprehensive email analytics:

```javascript
// Get campaign statistics
const stats = await fetch('/api/email/stats');

// Example response
{
    "delivery_rate": 99.0,
    "open_rate": 45.2,
    "click_rate": 8.7,
    "bounce_rate": 1.0
}
```

### Database Tracking

All email events are stored in the database:

```sql
-- View delivery logs
SELECT 
    edl.*,
    m.name as member_name,
    ec.subject
FROM email_delivery_logs edl
JOIN members m ON edl.member_id = m.id
JOIN email_campaigns ec ON edl.campaign_id = ec.id
WHERE edl.campaign_id = 'campaign-uuid'
ORDER BY edl.created_at DESC;
```

## Best Practices

### Email Deliverability

1. **Domain Authentication**: Always verify your sending domain
2. **List Hygiene**: Regularly clean bounced and inactive emails
3. **Content Quality**: Avoid spam trigger words and excessive links
4. **Sending Reputation**: Monitor bounce and complaint rates
5. **Gradual Ramp-up**: Increase sending volume gradually

### Content Guidelines

1. **Subject Lines**:
   - Keep under 50 characters
   - Avoid ALL CAPS and excessive punctuation
   - Personalize when possible
   - A/B test different approaches

2. **Email Body**:
   - Use responsive HTML templates
   - Include plain text version
   - Optimize for mobile devices
   - Include clear call-to-action buttons

3. **Personalization**:
   - Use member names and relevant data
   - Segment lists based on member preferences
   - Customize content for different member types

### Compliance

1. **CAN-SPAM Compliance**:
   - Include physical address
   - Provide easy unsubscribe option
   - Honor unsubscribe requests promptly
   - Use accurate subject lines

2. **GDPR Compliance**:
   - Obtain explicit consent
   - Provide data access and deletion
   - Document consent records
   - Include privacy policy links

### Performance Optimization

1. **Batch Processing**: Send emails in batches to avoid rate limits
2. **Queue Management**: Use background jobs for large campaigns
3. **Error Handling**: Implement retry logic for failed sends
4. **Monitoring**: Track delivery rates and performance metrics

## Troubleshooting

### Common Issues

#### 1. Emails Not Sending

**Symptoms**: Emails stuck in draft or failed status

**Solutions**:
```bash
# Check API key configuration
grep RESEND_API_KEY /opt/member-management/.env

# Check service logs
sudo journalctl -u member-management -f | grep email

# Test API connection
curl -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"from":"test@yourdomain.com","to":"test@example.com","subject":"Test","html":"Test"}'
```

#### 2. High Bounce Rate

**Symptoms**: Many emails bouncing back

**Solutions**:
1. Verify domain authentication
2. Clean email list of invalid addresses
3. Check content for spam triggers
4. Monitor sender reputation

#### 3. Low Open Rates

**Symptoms**: Emails delivered but not opened

**Solutions**:
1. Improve subject lines
2. Check sender name and address
3. Verify email content quality
4. Test send times and frequency

#### 4. Webhook Issues

**Symptoms**: Analytics not updating

**Solutions**:
```bash
# Check webhook endpoint
curl -X POST https://yourdomain.com/api/email/webhook \
  -H "Content-Type: application/json" \
  -d '{"type":"test","data":{}}'

# Check webhook logs
sudo tail -f /var/log/member-management/app.log | grep webhook
```

### Debugging Tools

#### 1. Email Testing

```javascript
// Test email sending
const testEmail = async () => {
    try {
        const result = await emailService.sendEmail({
            to: 'test@example.com',
            subject: 'Test Email',
            html: '<h1>Test</h1>',
            text: 'Test'
        });
        console.log('Email sent:', result);
    } catch (error) {
        console.error('Email failed:', error);
    }
};
```

#### 2. Database Queries

```sql
-- Check recent email campaigns
SELECT * FROM email_campaigns 
ORDER BY created_at DESC LIMIT 10;

-- Check delivery statistics
SELECT 
    status,
    COUNT(*) as count
FROM email_delivery_logs 
WHERE campaign_id = 'campaign-uuid'
GROUP BY status;

-- Check bounce reasons
SELECT 
    error_message,
    COUNT(*) as count
FROM email_delivery_logs 
WHERE status = 'bounced'
GROUP BY error_message;
```

#### 3. API Testing

```bash
# Test Resend API directly
curl -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "from": "test@yourdomain.com",
    "to": "recipient@example.com",
    "subject": "Test Email",
    "html": "<h1>Test Email</h1>"
  }'
```

### Getting Help

1. **Resend Documentation**: [resend.com/docs](https://resend.com/docs)
2. **Resend Support**: Contact through their dashboard
3. **Application Logs**: Check `/var/log/member-management/app.log`
4. **Database Logs**: Monitor email delivery logs table
5. **Community**: Node.js and email delivery communities

## Configuration Examples

### Development Configuration

```bash
# .env for development
NODE_ENV=development
RESEND_API_KEY=re_test_key_here
FROM_EMAIL=test@localhost
LOG_LEVEL=debug
```

### Production Configuration

```bash
# .env for production
NODE_ENV=production
RESEND_API_KEY=re_live_key_here
FROM_EMAIL=noreply@yourdomain.com
REPLY_TO_EMAIL=support@yourdomain.com
LOG_LEVEL=info
```

### Nginx Configuration for Webhooks

```nginx
# Add to your Nginx configuration
location /api/email/webhook {
    proxy_pass http://127.0.0.1:3000;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    
    # Increase timeout for webhook processing
    proxy_read_timeout 60s;
}
```

The Resend integration provides a robust, professional email system for your member management platform with comprehensive tracking, analytics, and delivery optimization.