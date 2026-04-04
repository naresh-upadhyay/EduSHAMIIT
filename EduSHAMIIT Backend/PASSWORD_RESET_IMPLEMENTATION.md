# Password Reset Implementation Guide

## Overview

This document describes the complete implementation of the password reset functionality for EduSHAMIIT, including OTP generation, email delivery, verification, and password update.

## Implementation Summary

### Features Implemented

1. **OTP Generation**: Secure 6-digit random OTP generation
2. **Email Delivery**: Gmail SMTP integration with retry logic (3 attempts)
3. **OTP Verification**: Time-based expiration (15 minutes) and status tracking
4. **Password Update**: Secure password update via Supabase Admin API
5. **Rate Limiting**: 3 OTP requests per hour per user
6. **Email Templates**: Google-style OTP email and confirmation email
7. **Comprehensive Testing**: Unit tests and integration tests

### API Endpoints

#### 1. POST `/api/auth/send-otp`
Sends an OTP to the user's email for password reset.

**Request Body:**
```json
{
  "identifier": "user@example.com",  // email or user_id
  "user_name": "John Doe"            // optional
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "OTP sent successfully",
  "expires_in": 900  // seconds
}
```

**Error Responses:**
- `400 Bad Request`: Missing identifier
- `404 Not Found`: User not found
- `429 Too Many Requests`: Rate limit exceeded

#### 2. POST `/api/auth/verify-otp`
Verifies the OTP before allowing password reset.

**Request Body:**
```json
{
  "identifier": "user@example.com",
  "otp": "123456"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "OTP verified successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid or expired OTP
- `404 Not Found`: User not found

#### 3. POST `/api/auth/reset-password`
Resets the password using a verified OTP.

**Request Body:**
```json
{
  "identifier": "user@example.com",
  "otp": "123456",
  "new_password": "newsecurepassword123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Password reset successfully"
}
```

**Error Responses:**
- `400 Bad Request`: Missing fields, invalid OTP, or password too short
- `404 Not Found`: User not found
- `500 Internal Server Error`: Failed to update password

## Database Schema

The `password_resets` table stores OTP records:

```sql
CREATE TABLE password_resets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id UUID REFERENCES schools(id),
  user_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  otp TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'verified', 'used')),
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_password_resets_user ON password_resets(user_id);
```

## Configuration

### Environment Variables

Add these to your `.env` file:

```env
# Email Configuration
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=binaftab936@gmail.com
SMTP_PASSWORD=your_app_password
EMAIL_FROM=binaftab936@gmail.com
EMAIL_RETRY_ATTEMPTS=3
EMAIL_RETRY_DELAY=1

# OTP Configuration
OTP_LENGTH=6
OTP_EXPIRATION_MINUTES=15
OTP_RATE_LIMIT_PER_HOUR=3
```

### Gmail App Password Setup

1. Go to your Google Account settings
2. Enable 2-Factor Authentication
3. Generate an App Password for "Mail"
4. Use this 16-character password in the `SMTP_PASSWORD` field

## Setup Instructions

### 1. Run Database Migration

```bash
cd EduSHAMIIT\ Backend
python run_migration.py
```

Or manually run the SQL in `EduSHAMIIT Database/edushamiit-db/migrations/004_password_resets.sql`

### 2. Update Environment Variables

Update the `.env` file in `EduSHAMIIT Backend/backend/` with your Gmail credentials.

### 3. Start the API Server

```bash
cd EduSHAMIIT\ Backend/backend
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### 4. Test the Implementation

#### Option A: Run Unit Tests

```bash
cd EduSHAMIIT\ Backend
pytest tests/test_auth.py -v
```

#### Option B: Run Integration Tests

```bash
cd EduSHAMIIT\ Backend
python tests/integration_test_password_reset.py
```

#### Option C: Manual Testing with cURL

**1. Register a user:**
```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "testpassword123",
    "full_name": "Test User",
    "role": "student",
    "school_id": "test-school-123"
  }'
```

**2. Request OTP:**
```bash
curl -X POST http://localhost:8000/api/auth/send-otp \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "test@example.com"
  }'
```

**3. Verify OTP:**
```bash
curl -X POST http://localhost:8000/api/auth/verify-otp \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "test@example.com",
    "otp": "123456"
  }'
```

**4. Reset Password:**
```bash
curl -X POST http://localhost:8000/api/auth/reset-password \
  -H "Content-Type: application/json" \
  -d '{
    "identifier": "test@example.com",
    "otp": "123456",
    "new_password": "newpassword123"
  }'
```

**5. Login with New Password:**
```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "newpassword123"
  }'
```

## Email Templates

### OTP Email

The OTP email follows Google's format with:
- Blue header with EduSHAMIIT branding
- Large, centered OTP code in a bordered box
- Clear instructions and expiration time
- Security warning about not sharing the code
- Responsive design for mobile devices

### Confirmation Email

The confirmation email includes:
- Green header indicating success
- Success checkmark icon
- Clear confirmation message
- Login button
- Security notice about contacting support if unauthorized

## Security Features

1. **OTP Expiration**: OTPs expire after 15 minutes
2. **Rate Limiting**: Maximum 3 OTP requests per hour per user
3. **Single Use**: OTPs can only be used once
4. **Secure Storage**: OTPs are stored with expiration timestamps
5. **Password Validation**: Minimum 8 characters required
6. **Email Confirmation**: Confirmation email sent after successful reset
7. **Error Logging**: All failures are logged for monitoring

## Error Handling

The implementation includes comprehensive error handling:

- **Database Errors**: Handled with appropriate HTTP status codes
- **Email Failures**: Logged with retry logic (3 attempts with exponential backoff)
- **Authentication Errors**: Proper error messages without exposing sensitive information
- **Rate Limiting**: Clear error messages when limits are exceeded

## Testing Coverage

### Unit Tests (`tests/test_auth.py`)
- OTP generation (length, uniqueness, range)
- Email service (success, retry, auth failures)
- User lookup (by email, by UUID, not found)
- Rate limiting (exceeded, not exceeded)
- OTP verification (success, expired)
- Password reset (success, validation)

### Integration Tests (`tests/integration_test_password_reset.py`)
- Complete end-to-end flow
- Manual OTP entry for real testing
- Rate limiting verification
- Invalid OTP handling
- Login with new password

## Troubleshooting

### Database Connection Issues
```bash
# Check if PostgreSQL is running
docker-compose ps

# View logs
docker-compose logs postgres
```

### Email Delivery Issues
1. Verify Gmail App Password is correct
2. Check SMTP settings in `.env`
3. Ensure "Less secure app access" is enabled (or use App Password)
4. Check email logs in the console

### Rate Limiting Issues
- Wait 1 hour for rate limit to reset
- Check the `password_resets` table for recent entries

### OTP Not Working
- Verify OTP hasn't expired (15 minutes)
- Check if OTP was already used
- Ensure user_id matches

## API Documentation

Once the server is running, visit:
- Swagger UI: `http://localhost:8000/docs`
- ReDoc: `http://localhost:8000/redoc`

## Production Considerations

1. **Environment Variables**: Use secure environment variables for sensitive data
2. **Rate Limiting**: Consider using Redis for distributed rate limiting
3. **Email Service**: Consider using a professional email service (SendGrid, AWS SES)
4. **Monitoring**: Set up logging and monitoring for email delivery failures
5. **Security**: Implement additional password complexity requirements
6. **HTTPS**: Always use HTTPS in production
7. **CORS**: Configure proper CORS settings

## Support

For issues or questions:
- Check the logs in the console
- Review the error messages in API responses
- Consult the API documentation at `/docs`
- Contact the development team

## Changelog

### Version 1.0.0 (2026-04-04)
- Initial implementation
- OTP generation and email delivery
- Password reset functionality
- Comprehensive testing suite
- Google-style email templates
- Rate limiting and security features