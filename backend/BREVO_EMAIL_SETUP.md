# Brevo (Sendinblue) Email Setup Guide

This project uses [Brevo](https://www.brevo.com/) (formerly Sendinblue) for sending emails via their API.

## Quick Setup Steps

### 1. Create a Brevo Account

1. Sign up for a free account at [brevo.com](https://www.brevo.com/)
2. Verify your email address
3. Complete the account setup

### 2. Get Your API Key

1. Log in to your Brevo dashboard
2. Go to **Settings** → **SMTP & API** → **API Keys**
   - Direct link: [https://app.brevo.com/settings/keys/api](https://app.brevo.com/settings/keys/api)
3. Click **Generate a new API key**
4. Give it a name (e.g., "Django App")
5. Copy the generated API key (starts with `xkeysib-`)

### 3. Add a Verified Sender

1. Go to **Settings** → **Senders & IP**
   - Direct link: [https://app.brevo.com/settings/senders](https://app.brevo.com/settings/senders)
2. Click **Add a new sender**
3. Enter your email address and name
4. Verify your email (check your inbox for verification link)

### 4. Update Your .env File

Update `backend/src/.env` with your Brevo credentials:

```env
BREVO_API_KEY=xkeysib-your_actual_api_key_here
DEFAULT_FROM_EMAIL=your_verified_sender_email@example.com
```

**Important:**
- `BREVO_API_KEY`: Your API key from step 2 (starts with `xkeysib-`)
- `DEFAULT_FROM_EMAIL`: Must be a verified sender email from step 3

### 5. Test Your Configuration

The email functionality is used in the OTP system. To test:

```bash
# Start your Django server
python manage.py runserver

# Make a POST request to send an OTP
curl -X POST http://localhost:8000/api/otp/send/ \
  -H "Content-Type: application/json" \
  -d '{"email": "test@iitrpr.ac.in"}'
```

## Brevo Free Tier Benefits

- **300 emails per day** (free forever)
- **Unlimited contacts**
- **Real-time statistics**
- **Email templates**
- **Transactional emails**
- **99% deliverability rate**
- **No domain verification required** for basic sending

### Troubleshooting

**"Authentication failed" or "Invalid API key" Error**
- Verify your API key is correct and starts with `xkeysib-`
- Make sure you copied the full key without spaces
- Check that `BREVO_API_KEY` is set in your `.env` file

**"Sender not verified" Error**
- Go to Brevo dashboard and verify your sender email
- Make sure `DEFAULT_FROM_EMAIL` matches a verified sender

**"Daily quota exceeded" Error**
- Free tier allows 300 emails/day
- Wait for 24 hours or upgrade your plan

**Emails going to spam**
- Add SPF and DKIM records (Brevo provides these in Settings → Senders & IP)
- Use a verified domain email instead of generic providers

**Module not found error**
- Make sure you've installed the package: `pip install sib-api-v3-sdk==7.6.0`
- Restart your Django server after installation

## Advanced Configuration (Optional)

### Using HTML Emails

Update `otp/views.py` to use HTML:

```python
from django.core.mail import EmailMultiAlternatives

# Create message
subject = "Your OTP Code"
text_content = f"Your OTP is: {otp}"
html_content = f"<h2>Your OTP is: <strong>{otp}</strong></h2>"

msg = EmailMultiAlternatives(subject, text_content, settings.DEFAULT_FROM_EMAIL, [email])
msg.attach_alternative(html_content, "text/html")
msg.send()
```

### Email Templates

Brevo supports transactional templates that you can manage in the dashboard.

### Webhooks

Set up webhooks to track email events (opens, clicks, bounces):
- Go to Settings → Webhooks
- Configure endpoints for email events

## Support & Resources

- [Brevo Documentation](https://developers.brevo.com/)
- [SMTP Setup Guide](https://help.brevo.com/hc/en-us/articles/209467485)
- [API Documentation](https://developers.brevo.com/reference)
- [Support Center](https://help.brevo.com/)

## Migration Notes

This project was migrated from Google SMTP to Brevo for:
- Better deliverability rates
- Higher daily sending limits
- Built-in email analytics
- No need for app-specific passwords
- Better spam protection
