# Brevo (Sendinblue) Email Setup Guide

This project has been configured to use [Brevo](https://www.brevo.com) (formerly Sendinblue) for sending emails via SMTP.

## Setup Instructions

### 1. Get Your Brevo SMTP Credentials

1. Sign up for a free account at [brevo.com](https://www.brevo.com)
2. Go to **Settings** → **SMTP & API**
3. Under the **SMTP** tab, you'll find:
   - SMTP Server: `smtp-relay.brevo.com`
   - Port: `587`
   - Login: Your Brevo account email
   - SMTP Key: Click "Generate a new SMTP key" or use an existing one

### 2. Configure Sender Email

1. Go to **Senders** in your Brevo dashboard
2. Add and verify your sender email address
3. Brevo will send a verification email - click the link to verify

### 3. Update Environment Variables

Update the `.env` file in `backend/src/` with your Brevo credentials:

```env
EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp-relay.brevo.com
EMAIL_PORT=587
EMAIL_USE_TLS=True
EMAIL_HOST_USER=your_brevo_account_email@example.com
EMAIL_HOST_PASSWORD=your_smtp_key_here
DEFAULT_FROM_EMAIL=your_verified_sender@example.com
```

**Important Notes:**
- `EMAIL_HOST_USER`: Your Brevo account login email
- `EMAIL_HOST_PASSWORD`: Your SMTP key (NOT your account password)
- `DEFAULT_FROM_EMAIL`: Must be a verified sender email in your Brevo account

### 4. Testing with Free Tier

Brevo's free tier allows you to:
- Send up to **300 emails per day**
- No domain verification required (can use any email you verify as sender)
- Full access to SMTP and API features

### 5. Test the Integration

The email sending functionality is used in the OTP system. To test:

1. Start your Django server
2. Make a POST request to the OTP endpoint with a valid email
3. Check that the OTP email is sent successfully

### Code Changes Made

The following files were modified to integrate Brevo:

1. **requirements.txt**: Removed `resend` package (using standard Django SMTP)
2. **backend/src/.env**: Updated with Brevo SMTP configuration
3. **backend/src/core/settings/base.py**: Updated settings to use standard Django email settings
4. **backend/src/otp/views.py**: Using Django's `send_mail()` with Brevo SMTP

### Brevo Features

- **SMTP & API**: Both options available
- **High Deliverability**: Professional email delivery infrastructure
- **Email Templates**: Create and use templates in dashboard
- **Analytics**: Track email opens, clicks, and bounces
- **Free Tier**: 300 emails/day with no domain verification needed
- **Marketing Tools**: Email campaigns, automation, and more

### Email Sending Code

Django's standard `send_mail()` is used with Brevo SMTP:

```python
from django.core.mail import send_mail
from django.conf import settings

send_mail(
    subject="Your OTP Code",
    message="Your OTP is: 123456",
    from_email=settings.DEFAULT_FROM_EMAIL,
    recipient_list=[email],
    fail_silently=False,
)
```

### Additional Features (Optional)

You can enhance the email functionality by:

1. **Adding HTML emails**:
```python
from django.core.mail import EmailMultiAlternatives

msg = EmailMultiAlternatives(
    subject="Your OTP Code",
    body="Your OTP is: 123456",
    from_email=settings.DEFAULT_FROM_EMAIL,
    to=[email]
)
msg.attach_alternative("<strong>Your OTP is: 123456</strong>", "text/html")
msg.send()
```

2. **Using Brevo templates** (via API)
3. **Adding attachments**
4. **Tracking campaigns**
5. **Setting up transactional emails**

### Troubleshooting

- **Authentication Error**: 
  - Verify you're using your SMTP key, not your account password
  - Check that `EMAIL_HOST_USER` matches your Brevo account email
  
- **Sender Not Verified**: 
  - Go to Senders in Brevo dashboard and verify your sender email
  - Wait for verification email and click the confirmation link

- **Connection Error**: 
  - Ensure port 587 is not blocked by your firewall
  - Try port 465 with `EMAIL_USE_SSL=True` instead of `EMAIL_USE_TLS`

- **Rate Limits**: 
  - Free tier: 300 emails/day
  - Upgrade your plan if you need more

### Support

- [Brevo Documentation](https://developers.brevo.com/)
- [Brevo SMTP Guide](https://help.brevo.com/hc/en-us/articles/209467485)
- [Brevo Dashboard](https://app.brevo.com/)
