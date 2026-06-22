"""
Email Service - Handles sending emails via SMTP with retry logic and logging.
"""
import smtplib
import logging
import time
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
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
        msg['Subject'] = subject
        
        # Add HTML content
        msg.attach(MIMEText(html_content, 'html'))
        
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



# Singleton instance
_email_service = None


def get_email_service() -> EmailService:
    """Get email service singleton."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service