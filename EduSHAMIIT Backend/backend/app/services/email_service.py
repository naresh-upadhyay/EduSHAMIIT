"""
Email Service - Handles sending emails via SMTP with retry logic and logging.
"""
import smtplib
import logging
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.header import Header
from typing import Optional, Dict, Any
from app.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


class EmailService:
    """Email service for sending OTP and confirmation emails."""
    
    def __init__(self):
        self.smtp_host = settings.SMTP_HOST
        self.smtp_port = settings.SMTP_PORT
        self.smtp_user = settings.SMTP_USER
        self.smtp_password = settings.SMTP_PASSWORD
        self.email_from = settings.EMAIL_FROM
        self.retry_attempts = settings.EMAIL_RETRY_ATTEMPTS
        self.retry_delay = settings.EMAIL_RETRY_DELAY
    
    def _create_message(self, to_email: str, subject: str, html_content: str) -> MIMEMultipart:
        """Create email message with HTML content."""
        msg = MIMEMultipart('alternative')
        msg['From'] = self.email_from
        msg['To'] = to_email
        # Encode subject as UTF-8 per RFC 2047 so special chars render correctly in all mail clients
        msg['Subject'] = Header(subject, 'utf-8')
        
        # Attach HTML with explicit utf-8 charset so body text renders correctly
        msg.attach(MIMEText(html_content, 'html', 'utf-8'))
        
        return msg
    
    def _send_email(self, to_email: str, subject: str, html_content: str) -> bool:
        """Send email with retry logic."""
        last_error = None
        
        for attempt in range(self.retry_attempts):
            try:
                if attempt > 0:
                    # Exponential backoff: 1s, 2s, 4s, etc.
                    delay = self.retry_delay * (2 ** (attempt - 1))
                    logger.info(f"Retry attempt {attempt + 1}/{self.retry_attempts}. Waiting {delay}s...")
                    time.sleep(delay)
                
                # Create message
                msg = self._create_message(to_email, subject, html_content)
                
                # Connect to SMTP server and send email
                with smtplib.SMTP(self.smtp_host, self.smtp_port) as server:
                    server.starttls()  # Secure the connection
                    server.login(self.smtp_user, self.smtp_password)
                    server.send_message(msg)
                
                logger.info(f"Email sent successfully to {to_email}")
                return True
                
            except smtplib.SMTPAuthenticationError as e:
                last_error = f"SMTP Authentication failed: {str(e)}"
                logger.error(last_error)
                # Don't retry on authentication errors
                break
                
            except smtplib.SMTPRecipientsRefused as e:
                last_error = f"Recipient refused: {str(e)}"
                logger.error(last_error)
                # Don't retry on recipient errors
                break
                
            except smtplib.SMTPException as e:
                last_error = f"SMTP error on attempt {attempt + 1}: {str(e)}"
                logger.error(last_error)
                # Continue to retry
                
            except Exception as e:
                last_error = f"Unexpected error on attempt {attempt + 1}: {str(e)}"
                logger.error(last_error)
                # Continue to retry
        
        # Log final failure
        logger.error(f"Failed to send email to {to_email} after {self.retry_attempts} attempts. Last error: {last_error}")
        return False
    
    def send_otp_email(self, to_email: str, otp: str, user_name: Optional[str] = None) -> bool:
        """Send OTP email using Google's format."""
        
        # Create Google-style OTP email template
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {{
                    font-family: 'Roboto', Arial, sans-serif;
                    background-color: #f8f9fa;
                    margin: 0;
                    padding: 20px;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    background-color: #ffffff;
                    border-radius: 8px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    overflow: hidden;
                }}
                .header {{
                    background-color: #4285f4;
                    padding: 20px;
                    text-align: center;
                }}
                .header h1 {{
                    color: #ffffff;
                    margin: 0;
                    font-size: 24px;
                    font-weight: 500;
                }}
                .content {{
                    padding: 30px;
                }}
                .greeting {{
                    font-size: 18px;
                    color: #202124;
                    margin-bottom: 20px;
                }}
                .otp-box {{
                    background-color: #f8f9fa;
                    border: 2px solid #dadce0;
                    border-radius: 8px;
                    padding: 20px;
                    text-align: center;
                    margin: 20px 0;
                }}
                .otp-code {{
                    font-size: 32px;
                    font-weight: bold;
                    color: #202124;
                    letter-spacing: 8px;
                    font-family: 'Courier New', monospace;
                }}
                .instructions {{
                    color: #5f6368;
                    font-size: 14px;
                    line-height: 1.6;
                    margin: 20px 0;
                }}
                .warning {{
                    background-color: #fff3cd;
                    border: 1px solid #ffeaa7;
                    border-radius: 4px;
                    padding: 15px;
                    margin: 20px 0;
                    font-size: 14px;
                    color: #856404;
                }}
                .footer {{
                    background-color: #f8f9fa;
                    padding: 20px;
                    text-align: center;
                    font-size: 12px;
                    color: #5f6368;
                }}
                .button {{
                    display: inline-block;
                    background-color: #4285f4;
                    color: #ffffff;
                    padding: 12px 24px;
                    text-decoration: none;
                    border-radius: 4px;
                    font-weight: 500;
                    margin: 20px 0;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>EduSHAMIIT</h1>
                </div>
                
                <div class="content">
                    <div class="greeting">
                        Hello {user_name or 'there'},
                    </div>
                    
                    <p class="instructions">
                        We received a request to reset your password. Use the verification code below to reset your password:
                    </p>
                    
                    <div class="otp-box">
                        <div class="otp-code">{otp}</div>
                    </div>
                    
                    <p class="instructions">
                        This code is valid for {settings.OTP_EXPIRATION_MINUTES} minutes. 
                        If you didn't request this code, you can safely ignore this email.
                    </p>
                    
                    <div class="warning">
                        <strong>Security Notice:</strong> Never share this code with anyone. 
                        EduSHAMIIT staff will never ask for this code.
                    </div>
                </div>
                
                <div class="footer">
                    <p>This is an automated message. Please do not reply to this email.</p>
                    <p>&copy; 2026 EduSHAMIIT. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        subject = "EduSHAMIIT Password Reset Verification Code"
        return self._send_email(to_email, subject, html_content)
    
    def send_password_reset_confirmation(self, to_email: str, user_name: Optional[str] = None) -> bool:
        """Send confirmation email after successful password reset."""
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {{
                    font-family: 'Roboto', Arial, sans-serif;
                    background-color: #f8f9fa;
                    margin: 0;
                    padding: 20px;
                }}
                .container {{
                    max-width: 600px;
                    margin: 0 auto;
                    background-color: #ffffff;
                    border-radius: 8px;
                    box-shadow: 0 2px 10px rgba(0,0,0,0.1);
                    overflow: hidden;
                }}
                .header {{
                    background-color: #34a853;
                    padding: 20px;
                    text-align: center;
                }}
                .header h1 {{
                    color: #ffffff;
                    margin: 0;
                    font-size: 24px;
                    font-weight: 500;
                }}
                .success-icon {{
                    text-align: center;
                    margin: 30px 0;
                }}
                .success-icon svg {{
                    width: 80px;
                    height: 80px;
                }}
                .content {{
                    padding: 30px;
                }}
                .greeting {{
                    font-size: 18px;
                    color: #202124;
                    margin-bottom: 20px;
                }}
                .message {{
                    color: #5f6368;
                    font-size: 16px;
                    line-height: 1.6;
                    margin: 20px 0;
                }}
                .warning {{
                    background-color: #fff3cd;
                    border: 1px solid #ffeaa7;
                    border-radius: 4px;
                    padding: 15px;
                    margin: 20px 0;
                    font-size: 14px;
                    color: #856404;
                }}
                .button {{
                    display: inline-block;
                    background-color: #4285f4;
                    color: #ffffff;
                    padding: 12px 24px;
                    text-decoration: none;
                    border-radius: 4px;
                    font-weight: 500;
                    margin: 20px 0;
                }}
                .footer {{
                    background-color: #f8f9fa;
                    padding: 20px;
                    text-align: center;
                    font-size: 12px;
                    color: #5f6368;
                }}
            </style>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>EduSHAMIIT</h1>
                </div>
                
                <div class="content">
                    <div class="success-icon">
                        <svg viewBox="0 0 52 52">
                            <circle cx="26" cy="26" r="25" fill="none" stroke="#34a853" stroke-width="2"/>
                            <path fill="none" stroke="#34a853" stroke-width="3" d="M14.1 27.2l7.1 7.2 16.7-16.8"/>
                        </svg>
                    </div>
                    
                    <div class="greeting">
                        Hello {user_name or 'there'},
                    </div>
                    
                    <p class="message">
                        Your password has been successfully reset. You can now log in to your EduSHAMIIT account with your new password.
                    </p>
                    
                    <div style="text-align: center;">
                        <a href="#" class="button">Log In to EduSHAMIIT</a>
                    </div>
                    
                    <div class="warning">
                        <strong>Security Notice:</strong> If you didn't reset your password, please contact our support team immediately. 
                        Your account security is important to us.
                    </div>
                </div>
                
                <div class="footer">
                    <p>This is an automated message. Please do not reply to this email.</p>
                    <p>&copy; 2026 EduSHAMIIT. All rights reserved.</p>
                </div>
            </div>
        </body>
        </html>
        """
        
        subject = "EduSHAMIIT Password Reset Successful"
        return self._send_email(to_email, subject, html_content)

    def send_login_otp_email(self, to_email: str, otp: str, user_name: Optional[str] = None) -> bool:
        """Send a premium, clean transactional OTP email for account login."""
        
        html_content = f"""
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>EduSHAMIIT Login Verification</title>
            <style>
                body {{
                    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;
                    background-color: #f3f4f6;
                    margin: 0;
                    padding: 0;
                    -webkit-font-smoothing: antialiased;
                }}
                .wrapper {{
                    width: 100%;
                    background-color: #f3f4f6;
                    padding: 40px 0;
                }}
                .container {{
                    max-width: 500px;
                    margin: 0 auto;
                    background-color: #ffffff;
                    border-radius: 16px;
                    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05);
                    overflow: hidden;
                    border: 1px solid #e5e7eb;
                }}
                .header {{
                    background: linear-gradient(135deg, #4f46e5 0%, #312e81 100%);
                    padding: 30px;
                    text-align: center;
                }}
                .logo {{
                    color: #ffffff;
                    font-size: 24px;
                    font-weight: 800;
                    letter-spacing: -0.5px;
                    margin: 0;
                }}
                .logo span {{
                    color: #818cf8;
                }}
                .content {{
                    padding: 40px 35px;
                }}
                .title {{
                    font-size: 20px;
                    font-weight: 600;
                    color: #1f2937;
                    margin-top: 0;
                    margin-bottom: 8px;
                }}
                .greeting {{
                    font-size: 16px;
                    color: #4b5563;
                    margin-bottom: 20px;
                }}
                .instructions {{
                    font-size: 14px;
                    color: #4b5563;
                    line-height: 1.6;
                    margin-bottom: 30px;
                }}
                .otp-card {{
                    background-color: #f9fafb;
                    border: 1px dashed #c7d2fe;
                    border-radius: 12px;
                    padding: 24px;
                    text-align: center;
                    margin-bottom: 30px;
                }}
                .otp-label {{
                    font-size: 11px;
                    text-transform: uppercase;
                    letter-spacing: 1.5px;
                    color: #6366f1;
                    font-weight: 600;
                    margin-bottom: 8px;
                }}
                .otp-code {{
                    font-size: 36px;
                    font-weight: 800;
                    color: #1e1b4b;
                    letter-spacing: 8px;
                    font-family: 'Courier New', monospace;
                    margin: 0;
                }}
                .expiry {{
                    font-size: 12px;
                    color: #9ca3af;
                    margin-top: 8px;
                }}
                .warning-box {{
                    background-color: #fef3c7;
                    border-left: 4px solid #f59e0b;
                    padding: 16px;
                    border-radius: 4px;
                    margin-bottom: 30px;
                }}
                .warning-text {{
                    font-size: 12px;
                    color: #78350f;
                    margin: 0;
                    line-height: 1.5;
                }}
                .footer {{
                    background-color: #f9fafb;
                    padding: 30px;
                    text-align: center;
                    border-top: 1px solid #f3f4f6;
                }}
                .footer-text {{
                    font-size: 12px;
                    color: #9ca3af;
                    line-height: 1.8;
                    margin: 0 0 10px 0;
                }}
                .footer-link {{
                    color: #6366f1;
                    text-decoration: none;
                }}
            </style>
        </head>
        <body>
            <div class="wrapper">
                <div class="container">
                    <div class="header">
                        <div class="logo">Edu<span>SHAMIIT</span></div>
                    </div>
                    <div class="content">
                        <h2 class="title">Verify Your Sign-In</h2>
                        <div class="greeting">Hello {user_name or 'there'},</div>
                        <p class="instructions">
                            We received a request to access your EduSHAMIIT account. Use the secure verification code below to complete your sign-in:
                        </p>
                        
                        <div class="otp-card">
                            <div class="otp-label">Verification Code</div>
                            <div class="otp-code">{otp}</div>
                            <div class="expiry">Expires in {settings.OTP_EXPIRATION_MINUTES} minutes</div>
                        </div>
                        
                        <div class="warning-box">
                            <p class="warning-text">
                                <strong>Security Notice:</strong> If you did not make this request, someone else may be trying to access your account. Please log in to change your password immediately or notify school administration.
                            </p>
                        </div>
                    </div>
                    <div class="footer">
                        <p class="footer-text">
                            This is a transactional security notification sent on behalf of EduSHAMIIT.
                        </p>
                        <p class="footer-text">
                            EduSHAMIIT Inc. &bull; 123 Academic Square &bull; Tech City
                        </p>
                        <p class="footer-text" style="margin-bottom: 0;">
                            Need help? <a href="#" class="footer-link">Contact Support</a>
                        </p>
                    </div>
                </div>
            </div>
        </body>
        </html>
        """
        
        subject = "EduSHAMIIT Secure Login Code"
        return self._send_email(to_email, subject, html_content)


    def send_renewal_warning_email(
        self,
        to_email: str,
        owner_name: str,
        school_name: str,
        expiry_date: str,
        start_date: str = "N/A",
        days_remaining: str = "N/A",
        tier: str = "Premium",
        status: str = "ACTIVE",
        billing_label: str = "N/A",
        max_students: int = 0,
        mail_plan_code: str = "N/A",
        mail_monthly_limit: int = 0,
        mail_emails_sent: int = 0,
    ) -> bool:
        """Send an enterprise-grade subscription renewal warning email to the school owner."""
        subject = f"[ACTION REQUIRED] Subscription Expiring Soon - {school_name}"

        # Urgency color based on days remaining
        try:
            days_int = int(days_remaining)
            urgency_color = "#ef4444" if days_int <= 30 else ("#f59e0b" if days_int <= 90 else "#10b981")
        except Exception:
            urgency_color = "#f59e0b"

        # Mail usage percentage bar
        mail_usage_pct = 0
        try:
            if mail_monthly_limit > 0:
                mail_usage_pct = min(int((mail_emails_sent / mail_monthly_limit) * 100), 100)
        except Exception:
            pass
        mail_bar_color = "#ef4444" if mail_usage_pct >= 80 else ("#f59e0b" if mail_usage_pct >= 50 else "#4f46e5")

        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>Subscription Renewal Warning</title>
</head>
<body style="margin:0;padding:0;background-color:#f0f2f5;font-family:'Segoe UI',Roboto,Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f0f2f5;padding:32px 16px;">
    <tr>
      <td align="center">
        <table width="620" cellpadding="0" cellspacing="0" border="0" style="background:#ffffff;border-radius:12px;overflow:hidden;box-shadow:0 4px 24px rgba(0,0,0,0.08);">

          <!-- HEADER -->
          <tr>
            <td style="background:linear-gradient(135deg,#4f46e5 0%,#312e81 100%);padding:32px 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td>
                    <div style="font-size:11px;font-weight:600;letter-spacing:2px;text-transform:uppercase;color:rgba(255,255,255,0.6);margin-bottom:6px;">EduSHAMIIT SaaS Platform</div>
                    <div style="font-size:22px;font-weight:700;color:#ffffff;line-height:1.3;">Subscription Renewal Notice</div>
                  </td>
                  <td align="right">
                    <span style="display:inline-block;background:rgba(255,255,255,0.15);border:1px solid rgba(255,255,255,0.3);border-radius:20px;padding:5px 14px;font-size:12px;font-weight:700;color:#ffffff;letter-spacing:1px;">{status}</span>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ALERT BANNER -->
          <tr>
            <td style="background:#fffbeb;border-left:4px solid #f59e0b;padding:14px 40px;">
              <p style="margin:0;font-size:13px;color:#92400e;">
                <strong>Action Required:</strong>&nbsp; Your subscription for <strong>{school_name}</strong>
                expires on <strong style="color:#b45309;">{expiry_date}</strong>.
                There are <strong style="color:{urgency_color};">{days_remaining} day(s)</strong> remaining.
                Renew now to avoid any service interruption.
              </p>
            </td>
          </tr>

          <!-- BODY -->
          <tr>
            <td style="padding:36px 40px 0 40px;">
              <p style="margin:0 0 6px 0;font-size:16px;font-weight:600;color:#1e1b4b;">Dear {owner_name},</p>
              <p style="margin:0 0 28px 0;font-size:14px;color:#475569;line-height:1.7;">
                We are writing to inform you that the EduSHAMIIT subscription for your institution is
                scheduled to expire soon. Please review your current plan details below and take action
                to ensure uninterrupted access for your students, faculty, and administrative staff.
              </p>

              <!-- ERP SUBSCRIPTION SECTION -->
              <div style="font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#6366f1;margin-bottom:12px;">ERP Subscription Details</div>
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin-bottom:24px;">
                <tr style="background:#f8fafc;">
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;width:42%;border-bottom:1px solid #e2e8f0;">Institution Name</td>
                  <td style="padding:13px 20px;font-size:13px;color:#0f172a;font-weight:600;border-bottom:1px solid #e2e8f0;">{school_name}</td>
                </tr>
                <tr>
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;border-bottom:1px solid #e2e8f0;">Subscription Tier</td>
                  <td style="padding:13px 20px;font-size:13px;border-bottom:1px solid #e2e8f0;">
                    <span style="background:#ede9fe;color:#5b21b6;padding:3px 10px;border-radius:12px;font-size:12px;font-weight:700;">{tier}</span>
                  </td>
                </tr>
                <tr style="background:#f8fafc;">
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;border-bottom:1px solid #e2e8f0;">Active Since</td>
                  <td style="padding:13px 20px;font-size:13px;color:#0f172a;font-weight:600;border-bottom:1px solid #e2e8f0;">{start_date}</td>
                </tr>
                <tr>
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;border-bottom:1px solid #e2e8f0;">Expiry Date</td>
                  <td style="padding:13px 20px;font-size:13px;font-weight:700;border-bottom:1px solid #e2e8f0;">
                    <span style="color:{urgency_color};">{expiry_date}</span>
                    &nbsp;<span style="background:#fee2e2;color:#991b1b;padding:2px 8px;border-radius:10px;font-size:11px;font-weight:700;">{days_remaining} days left</span>
                  </td>
                </tr>
                <tr style="background:#f8fafc;">
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;border-bottom:1px solid #e2e8f0;">Billing Rate</td>
                  <td style="padding:13px 20px;font-size:13px;color:#0f172a;font-weight:600;border-bottom:1px solid #e2e8f0;">{billing_label}</td>
                </tr>
                <tr>
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;">Max Enrolled Students</td>
                  <td style="padding:13px 20px;font-size:13px;color:#0f172a;font-weight:600;">{max_students:,} students</td>
                </tr>
              </table>

              <!-- MAIL SUBSCRIPTION SECTION -->
              <div style="font-size:11px;font-weight:700;letter-spacing:1.5px;text-transform:uppercase;color:#6366f1;margin-bottom:12px;">Transactional Mail Subscription</div>
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="border:1px solid #e2e8f0;border-radius:8px;overflow:hidden;margin-bottom:24px;">
                <tr style="background:#f8fafc;">
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;width:42%;border-bottom:1px solid #e2e8f0;">Mail Plan</td>
                  <td style="padding:13px 20px;font-size:13px;border-bottom:1px solid #e2e8f0;">
                    <span style="background:#dbeafe;color:#1e40af;padding:3px 10px;border-radius:12px;font-size:12px;font-weight:700;">{mail_plan_code}</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;border-bottom:1px solid #e2e8f0;">Monthly Allowance</td>
                  <td style="padding:13px 20px;font-size:13px;color:#0f172a;font-weight:600;border-bottom:1px solid #e2e8f0;">{mail_monthly_limit:,} emails / month</td>
                </tr>
                <tr style="background:#f8fafc;">
                  <td style="padding:13px 20px;font-size:13px;color:#64748b;font-weight:500;">This Month's Usage</td>
                  <td style="padding:13px 20px;">
                    <div style="font-size:12px;color:#0f172a;font-weight:600;margin-bottom:6px;">{mail_emails_sent:,} / {mail_monthly_limit:,} &nbsp;({mail_usage_pct}% used)</div>
                    <div style="background:#e2e8f0;border-radius:999px;height:6px;width:100%;max-width:240px;">
                      <div style="background:{mail_bar_color};border-radius:999px;height:6px;width:{mail_usage_pct}%;"></div>
                    </div>
                  </td>
                </tr>
              </table>

              <!-- NEXT STEPS -->
              <div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:8px;padding:16px 20px;margin-bottom:28px;">
                <div style="font-size:13px;font-weight:700;color:#166534;margin-bottom:8px;">Recommended Next Steps</div>
                <ul style="margin:0;padding-left:18px;font-size:13px;color:#15803d;line-height:1.8;">
                  <li>Log in to the EduSHAMIIT Admin Dashboard to renew your subscription.</li>
                  <li>Choose from our Starter, Growth, or Enterprise plans for the best value.</li>
                  <li>Contact our billing team if you need a custom quotation or invoice.</li>
                </ul>
              </div>

              <!-- CTA -->
              <table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-bottom:36px;">
                <tr>
                  <td align="center">
                    <a href="http://localhost:50555/#/admin/schools"
                       style="display:inline-block;background:linear-gradient(135deg,#4f46e5,#312e81);color:#ffffff;text-decoration:none;padding:14px 40px;border-radius:8px;font-size:15px;font-weight:700;letter-spacing:0.5px;box-shadow:0 4px 14px rgba(79,70,229,0.35);">
                      Renew Subscription Now
                    </a>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top:10px;">
                    <a href="mailto:support@edushamiit.com" style="font-size:12px;color:#6366f1;text-decoration:none;">Or contact billing support</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="background:#f8fafc;border-top:1px solid #e2e8f0;padding:20px 40px;">
              <table width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td style="font-size:11px;color:#94a3b8;line-height:1.6;">
                    This is an automated notification from the <strong>EduSHAMIIT Billing &amp; Subscription System</strong>.<br/>
                    You are receiving this because you are the registered owner of <strong>{school_name}</strong>.<br/>
                    &copy; 2026 EduSHAMIIT Inc. &nbsp;|&nbsp;
                    <a href="mailto:support@edushamiit.com" style="color:#6366f1;text-decoration:none;">support@edushamiit.com</a>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

        return self._send_email(to_email, subject, html_content)


# Singleton instance
_email_service = None


def get_email_service() -> EmailService:
    """Get email service singleton."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service
