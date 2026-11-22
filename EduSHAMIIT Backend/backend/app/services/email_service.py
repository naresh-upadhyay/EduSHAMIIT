"""
Email Service - Handles sending emails via SMTP with retry logic, logging, and RFC 5545 iCalendar scheduling.
"""
import smtplib
import logging
import time
import uuid
import urllib.parse
from datetime import datetime, date, timedelta, timezone
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from email.mime.application import MIMEApplication
from email.header import Header
from typing import Optional, Dict, Any, List
from app.config import settings

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


def generate_ics_invite(
    summary: str,
    description: str,
    location: str,
    start_dt: datetime,
    end_dt: datetime,
    organizer_email: str,
    organizer_name: str,
    attendee_email: str,
    attendee_name: str,
    uid: Optional[str] = None
) -> str:
    """Generate RFC 5545 compliant iCalendar content with METHOD:REQUEST for automatic calendar parsing in Gmail/Outlook."""
    uid = uid or f"edushamiit-interview-{uuid.uuid4()}@edushamiit.com"
    dtstamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")

    if start_dt.tzinfo is not None:
        start_utc = start_dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        end_utc = end_dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    else:
        ist_delta = timedelta(hours=5, minutes=30)
        start_utc = (start_dt - ist_delta).strftime("%Y%m%dT%H%M%SZ")
        end_utc = (end_dt - ist_delta).strftime("%Y%m%dT%H%M%SZ")

    def _escape(text: str) -> str:
        if not text:
            return ""
        return text.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n").replace("\r", "")

    clean_summary = _escape(summary)
    clean_desc = _escape(description)
    clean_loc = _escape(location)
    clean_org_name = _escape(organizer_name)
    clean_att_name = _escape(attendee_name)

    ics_lines = [
        "BEGIN:VCALENDAR",
        "PRODID:-//EduSHAMIIT ERP//Recruitment Calendar//EN",
        "VERSION:2.0",
        "CALSCALE:GREGORIAN",
        "METHOD:REQUEST",
        "BEGIN:VEVENT",
        f"UID:{uid}",
        f"DTSTAMP:{dtstamp}",
        f"DTSTART:{start_utc}",
        f"DTEND:{end_utc}",
        f"SUMMARY:{clean_summary}",
        f"DESCRIPTION:{clean_desc}",
        f"LOCATION:{clean_loc}",
        f'ORGANIZER;CN="{clean_org_name}":mailto:{organizer_email}',
        f'ATTENDEE;CUTYPE=INDIVIDUAL;ROLE=REQ-PARTICIPANT;PARTSTAT=NEEDS-ACTION;RSVP=TRUE;CN="{clean_att_name}":mailto:{attendee_email}',
        "STATUS:CONFIRMED",
        "SEQUENCE:0",
        "TRANSP:OPAQUE",
        "BEGIN:VALARM",
        "TRIGGER:-PT15M",
        "ACTION:DISPLAY",
        f"DESCRIPTION:Reminder: {clean_summary}",
        "END:VALARM",
        "END:VEVENT",
        "END:VCALENDAR",
    ]
    return "\r\n".join(ics_lines) + "\r\n"


def make_google_calendar_url(
    title: str,
    details: str,
    location: str,
    start_dt: datetime,
    end_dt: datetime
) -> str:
    """Generate direct 'Add to Google Calendar' deep link."""
    if start_dt.tzinfo is not None:
        start_utc = start_dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
        end_utc = end_dt.astimezone(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    else:
        ist_delta = timedelta(hours=5, minutes=30)
        start_utc = (start_dt - ist_delta).strftime("%Y%m%dT%H%M%SZ")
        end_utc = (end_dt - ist_delta).strftime("%Y%m%dT%H%M%SZ")

    params = {
        "action": "TEMPLATE",
        "text": title,
        "dates": f"{start_utc}/{end_utc}",
        "details": details,
        "location": location
    }
    return f"https://calendar.google.com/calendar/render?{urllib.parse.urlencode(params)}"


def make_outlook_calendar_url(
    title: str,
    details: str,
    location: str,
    start_dt: datetime,
    end_dt: datetime
) -> str:
    """Generate direct 'Add to Outlook' deep link."""
    if start_dt.tzinfo is not None:
        start_iso = start_dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        end_iso = end_dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    else:
        ist_delta = timedelta(hours=5, minutes=30)
        start_iso = (start_dt - ist_delta).strftime("%Y-%m-%dT%H:%M:%SZ")
        end_iso = (end_dt - ist_delta).strftime("%Y-%m-%dT%H:%M:%SZ")

    params = {
        "subject": title,
        "startdt": start_iso,
        "enddt": end_iso,
        "body": details,
        "location": location,
        "path": "/calendar/action/compose",
        "rru": "addevent"
    }
    return f"https://outlook.live.com/calendar/0/deeplink/compose?{urllib.parse.urlencode(params)}"


class EmailService:
    """Email service for sending OTP, notification, and interview scheduling calendar emails."""
    
    def __init__(self):
        self._refresh_credentials()
        self.retry_attempts = getattr(settings, 'EMAIL_RETRY_ATTEMPTS', 3)
        self.retry_delay = getattr(settings, 'EMAIL_RETRY_DELAY', 2)

    def _refresh_credentials(self):
        """Dynamically refresh SMTP credentials from environment variables / settings (synced from Supabase Vault)."""
        import os
        self.smtp_host = os.getenv('SMTP_HOST') or getattr(settings, 'SMTP_HOST', 'smtp.gmail.com')
        raw_port = os.getenv('SMTP_PORT') or getattr(settings, 'SMTP_PORT', 587)
        try:
            self.smtp_port = int(raw_port)
        except (ValueError, TypeError):
            self.smtp_port = 587
        
        self.smtp_user = os.getenv('SMTP_USER') or getattr(settings, 'SMTP_USER', '')
        self.smtp_password = (
            os.getenv('SMTP_PASSWORD') 
            or os.getenv('SMTP_PASS') 
            or getattr(settings, 'SMTP_PASSWORD', '')
        )
        self.email_from = (
            os.getenv('EMAIL_FROM') 
            or getattr(settings, 'EMAIL_FROM', '') 
            or self.smtp_user 
            or 'noreply@edushamiit.com'
        )
    
    def _create_message(
        self,
        to_email: str,
        subject: str,
        html_content: str,
        ics_content: Optional[str] = None,
        ics_filename: str = "interview_invite.ics",
        attachments: Optional[List[Dict[str, Any]]] = None
    ) -> MIMEMultipart:
        """Create email message with HTML content, optional RFC 5545 iCalendar invite, and optional file attachments."""
        if ics_content or attachments:
            msg = MIMEMultipart('mixed')
            msg['From'] = self.email_from
            msg['To'] = to_email
            msg['Subject'] = Header(subject, 'utf-8')

            # Multipart alternative containing HTML and inline calendar event
            alt_part = MIMEMultipart('alternative')
            alt_part.attach(MIMEText(html_content, 'html', 'utf-8'))

            if ics_content:
                # Inline calendar part with method=REQUEST so Gmail/Outlook render native RSVP cards
                cal_part = MIMEText(ics_content, 'calendar; method=REQUEST; charset="utf-8"', 'utf-8')
                cal_part.add_header('Content-Class', 'urn:content-classes:calendarmessage')
                alt_part.attach(cal_part)

            msg.attach(alt_part)

            if ics_content:
                # Also attach as an .ics file for offline/Apple Mail import
                attachment = MIMEText(ics_content, 'calendar; charset="utf-8"', 'utf-8')
                attachment.add_header('Content-Disposition', f'attachment; filename="{ics_filename}"')
                msg.attach(attachment)

            if attachments:
                for att in attachments:
                    part = MIMEApplication(att['content'], _subtype=att.get('subtype', 'pdf'))
                    part.add_header('Content-Disposition', 'attachment', filename=att['filename'])
                    msg.attach(part)

            return msg
        else:
            msg = MIMEMultipart('alternative')
            msg['From'] = self.email_from
            msg['To'] = to_email
            msg['Subject'] = Header(subject, 'utf-8')
            msg.attach(MIMEText(html_content, 'html', 'utf-8'))
            return msg
    
    def _send_email(
        self,
        to_email: str,
        subject: str,
        html_content: str,
        ics_content: Optional[str] = None,
        ics_filename: str = "interview_invite.ics",
        attachments: Optional[List[Dict[str, Any]]] = None
    ) -> bool:
        """Send email with retry logic, optional calendar attachment, and optional file attachments."""
        self._refresh_credentials()
        if not self.smtp_user or not self.smtp_password or self.smtp_host in ('', 'localhost', '127.0.0.1'):
            logger.info(f"[Email Sandbox/Mock] Simulated sending email to {to_email}: {subject}")
            return True
        last_error = None
        
        for attempt in range(self.retry_attempts):
            try:
                if attempt > 0:
                    delay = self.retry_delay * (2 ** (attempt - 1))
                    logger.info(f"Retry attempt {attempt + 1}/{self.retry_attempts}. Waiting {delay}s...")
                    time.sleep(delay)
                
                msg = self._create_message(
                    to_email, subject, html_content,
                    ics_content=ics_content,
                    ics_filename=ics_filename,
                    attachments=attachments
                )
                
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

    def send_interview_scheduled_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        interview_round: str,
        scheduled_date: str,
        time_start: str,
        time_end: str,
        mode: str,
        location_or_link: Optional[str] = None,
        interviewer_names: Optional[str] = None,
        notes: Optional[str] = None,
        raw_start_dt: Optional[datetime] = None,
        raw_end_dt: Optional[datetime] = None
    ) -> bool:
        """Send a professional, branded interview invitation email to the candidate with attached calendar invite."""
        subject = f"Interview Invitation: {interview_round} for {job_title} at {school_name}"

        location_display = location_or_link if location_or_link and location_or_link.strip() else "To be shared / Campus Main Office"
        interviewers_display = interviewer_names if interviewer_names and interviewer_names.strip() else "Department Hiring Panel"

        # Construct datetime objects for calendar sync if not provided
        if not raw_start_dt or not raw_end_dt:
            try:
                # Try parsing scheduled_date and time strings
                d_obj = datetime.strptime(scheduled_date, "%A, %d %B %Y").date()
                st_obj = datetime.strptime(time_start.strip(), "%I:%M %p").time()
                et_obj = datetime.strptime(time_end.strip(), "%I:%M %p").time()
                raw_start_dt = datetime.combine(d_obj, st_obj)
                raw_end_dt = datetime.combine(d_obj, et_obj)
            except Exception:
                raw_start_dt = datetime.now() + timedelta(days=1)
                raw_end_dt = raw_start_dt + timedelta(minutes=45)

        # Generate direct web calendar links
        cal_title = f"Interview: {job_title} ({interview_round}) - {school_name}"
        cal_desc = (
            f"Interview Round: {interview_round}\n"
            f"Position: {job_title}\n"
            f"Institution: {school_name}\n"
            f"Mode: {mode}\n"
            f"Location / Link: {location_display}\n"
            f"Interview Panel: {interviewers_display}\n"
            f"Instructions: {notes or 'Please be ready 10 minutes prior.'}"
        )
        google_cal_url = make_google_calendar_url(cal_title, cal_desc, location_display, raw_start_dt, raw_end_dt)
        outlook_cal_url = make_outlook_calendar_url(cal_title, cal_desc, location_display, raw_start_dt, raw_end_dt)

        # Generate RFC 5545 .ics invite string
        ics_content = generate_ics_invite(
            summary=cal_title,
            description=cal_desc,
            location=location_display,
            start_dt=raw_start_dt,
            end_dt=raw_end_dt,
            organizer_email=self.email_from,
            organizer_name=f"{school_name} Recruitment",
            attendee_email=to_email,
            attendee_name=candidate_name
        )

        action_button_html = ""
        if mode == "Online" and location_or_link and ("http://" in location_or_link or "https://" in location_or_link):
            action_button_html = f"""
            <tr>
              <td align="center" style="padding: 18px 0 6px 0;">
                <a href="{location_or_link}" target="_blank" style="display:inline-block;background:linear-gradient(135deg, #4F46E5, #3730A3);color:#ffffff;padding:14px 28px;border-radius:8px;text-decoration:none;font-weight:600;font-size:15px;letter-spacing:0.3px;box-shadow:0 4px 12px rgba(79,70,229,0.35);">
                  🎥 Join Virtual Interview
                </a>
              </td>
            </tr>
            """

        notes_box_html = ""
        if notes and notes.strip():
            notes_box_html = f"""
            <div style="margin-top: 20px; background-color: #F8FAFC; border-left: 4px solid #4F46E5; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 6px 0; font-weight: 600; font-size: 13px; color: #1E293B;">📝 Special Instructions &amp; Preparation:</p>
              <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.5;">{notes.strip()}</p>
            </div>
            """

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 25px rgba(0,0,0,0.06);">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 50%, #312E81 100%); padding: 36px 32px; text-align: center;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <span style="display:inline-block;background:rgba(255,255,255,0.12);color:#E0E7FF;padding:6px 14px;border-radius:20px;font-size:11px;font-weight:600;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                      ✦ EduSHAMIIT Recruitment
                    </span>
                    <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">
                      {school_name}
                    </h1>
                    <p style="margin: 0; color: #C7D2FE; font-size: 14px; font-weight: 400;">
                      Interview Invitation • Talent Acquisition
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Body -->
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <p style="margin: 0 0 16px 0; font-size: 16px; font-weight: 600; color: #0F172A;">
                Dear {candidate_name},
              </p>
              <p style="margin: 0 0 20px 0; font-size: 14.5px; color: #334155; line-height: 1.65;">
                Thank you for your interest in joining <strong>{school_name}</strong>. Following a thorough review of your profile, we are pleased to invite you to the <strong>{interview_round}</strong> for the <strong>{job_title}</strong> position.
              </p>

              <!-- Scheduled Details Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; margin-bottom: 20px;">
                <tr>
                  <td style="padding: 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding-bottom: 12px; border-bottom: 1px solid #E2E8F0;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Interview Round</span>
                          <div style="font-size: 15px; font-weight: 600; color: #1E293B; margin-top: 2px;">{interview_round}</div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 12px 0; border-bottom: 1px solid #E2E8F0;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Date &amp; Time</span>
                          <div style="font-size: 15px; font-weight: 600; color: #4F46E5; margin-top: 2px;">
                            📅 {scheduled_date} &nbsp;•&nbsp; ⏰ {time_start} – {time_end}
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 12px 0; border-bottom: 1px solid #E2E8F0;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Interview Mode</span>
                          <div style="font-size: 14.5px; font-weight: 500; color: #1E293B; margin-top: 2px;">
                            <span style="display:inline-block;padding:3px 10px;background:#EEF2FF;color:#4338CA;border-radius:6px;font-size:12px;font-weight:600;">{mode}</span>
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding: 12px 0; border-bottom: 1px solid #E2E8F0;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Location / Meeting Info</span>
                          <div style="font-size: 14px; font-weight: 500; color: #1E293B; margin-top: 2px; word-break: break-all;">
                            📍 {location_display}
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding-top: 12px;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 0.5px;">Interviewer / Panel</span>
                          <div style="font-size: 14px; font-weight: 600; color: #1E293B; margin-top: 2px;">
                            👤 {interviewers_display}
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Instant Calendar Scheduling Deep-Links -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: #F1F5F9; border: 1px solid #E2E8F0; border-radius: 8px; margin-bottom: 20px; padding: 12px 16px;">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; font-size: 12px; font-weight: 600; color: #475569; text-transform: uppercase; letter-spacing: 0.5px;">
                      ⚡ Add this interview directly to your personal calendar:
                    </p>
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 0 6px;">
                          <a href="{google_cal_url}" target="_blank" style="display:inline-block;background-color:#FFFFFF;border:1px solid #CBD5E1;color:#1E293B;padding:9px 16px;border-radius:6px;text-decoration:none;font-size:12.5px;font-weight:600;box-shadow:0 1px 2px rgba(0,0,0,0.05);">
                            📅 Google Calendar
                          </a>
                        </td>
                        <td style="padding: 0 6px;">
                          <a href="{outlook_cal_url}" target="_blank" style="display:inline-block;background-color:#FFFFFF;border:1px solid #CBD5E1;color:#1E293B;padding:9px 16px;border-radius:6px;text-decoration:none;font-size:12.5px;font-weight:600;box-shadow:0 1px 2px rgba(0,0,0,0.05);">
                            📅 Outlook Calendar
                          </a>
                        </td>
                      </tr>
                    </table>
                    <p style="margin: 8px 0 0 0; font-size: 11px; color: #64748B;">
                      (An interactive calendar file <code>invite.ics</code> is also attached to this email)
                    </p>
                  </td>
                </tr>
              </table>

              {action_button_html}
              {notes_box_html}

              <div style="margin-top: 24px; padding-top: 20px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0 0 8px 0; font-size: 13px; color: #64748B; line-height: 1.5;">
                  💡 <strong>Preparation Tips:</strong> Please ensure you are available 10 minutes prior to the scheduled start time. If this is an online interview, please test your camera and microphone in advance.
                </p>
                <p style="margin: 0; font-size: 13px; color: #64748B; line-height: 1.5;">
                  If you need to reschedule or have any questions, please reply directly to this email or reach out to our HR recruitment desk.
                </p>
              </div>

              <div style="margin-top: 24px;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Warm regards,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">HR &amp; Recruitment Team</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8; line-height: 1.5;">
                This email was sent to <strong>{to_email}</strong> regarding your application for {job_title}.<br/>
                &copy; 2026 {school_name} • Powered by EduSHAMIIT Enterprise ERP
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

        return self._send_email(to_email, subject, html_content, ics_content=ics_content, ics_filename="interview_invitation.ics")

    def send_interviewer_interview_scheduled_email(
        self,
        to_email: str,
        interviewer_name: str,
        candidate_name: str,
        candidate_email: str,
        job_title: str,
        school_name: str,
        interview_round: str,
        scheduled_date: str,
        time_start: str,
        time_end: str,
        mode: str,
        location_or_link: Optional[str] = None,
        co_interviewers: Optional[str] = None,
        notes: Optional[str] = None,
        candidate_phone: Optional[str] = None,
        candidate_dossier: Optional[Dict[str, Any]] = None,
        raw_start_dt: Optional[datetime] = None,
        raw_end_dt: Optional[datetime] = None
    ) -> bool:
        """Send an executive panel assignment email to assigned staff interviewer with candidate dossier and calendar invite."""
        subject = f"[Panel Assignment] Interview: {candidate_name} for {job_title} ({interview_round})"

        location_display = location_or_link if location_or_link and location_or_link.strip() else "To be announced / Campus Meeting Room"
        co_panel_display = co_interviewers if co_interviewers and co_interviewers.strip() else "You are the primary evaluator"
        dossier = candidate_dossier or {}

        # Candidate background fields
        phone_display = candidate_phone or dossier.get("phone") or "N/A"
        exp_display = f"{dossier.get('experience_years')} yrs" if dossier.get('experience_years') is not None else "N/A"
        qual_display = dossier.get("qualification") or "N/A"
        spec_display = f"({dossier.get('specialization')})" if dossier.get("specialization") else ""
        org_display = dossier.get("current_organization") or "Not Specified"
        desig_display = f" - {dossier.get('current_designation')}" if dossier.get("current_designation") else ""
        skills_raw = dossier.get("skills")
        resume_url = dossier.get("resume_url")

        # Format skills chips
        skills_html = ""
        if skills_raw:
            if isinstance(skills_raw, list):
                skills_list = [str(s).strip() for s in skills_raw if str(s).strip()]
            else:
                skills_list = [str(s).strip() for s in str(skills_raw).split(",") if str(s).strip()]
            if skills_list:
                chips = "".join([
                    f'<span style="display:inline-block;background:#F1F5F9;color:#334155;border:1px solid #CBD5E1;border-radius:12px;padding:3px 10px;font-size:11px;font-weight:600;margin:2px 4px 2px 0;">{s}</span>'
                    for s in skills_list[:8]
                ])
                skills_html = f"""
                <tr>
                  <td style="padding-top: 10px;">
                    <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Key Skills &amp; Competencies:</span>
                    <div style="margin-top: 6px;">{chips}</div>
                  </td>
                </tr>
                """

        # Resume button
        resume_btn_html = ""
        if resume_url and resume_url.strip():
            resume_btn_html = f"""
            <a href="{resume_url}" target="_blank" style="display:inline-block;background:#0F172A;color:#ffffff;padding:9px 16px;border-radius:6px;text-decoration:none;font-size:12.5px;font-weight:600;margin-top:8px;">
              📄 View Candidate Resume (PDF)
            </a>
            """

        # Virtual meeting action button
        join_btn_html = ""
        if mode == "Online" and location_or_link and ("http://" in location_or_link or "https://" in location_or_link):
            join_btn_html = f"""
            <tr>
              <td align="center" style="padding: 16px 0 8px 0;">
                <a href="{location_or_link}" target="_blank" style="display:inline-block;background:linear-gradient(135deg, #4F46E5, #3730A3);color:#ffffff;padding:12px 26px;border-radius:8px;text-decoration:none;font-weight:600;font-size:14px;letter-spacing:0.3px;box-shadow:0 4px 12px rgba(79,70,229,0.3);">
                  🎥 Launch Virtual Interview
                </a>
              </td>
            </tr>
            """

        # HR Notes
        notes_box_html = ""
        if notes and notes.strip():
            notes_box_html = f"""
            <div style="margin-top: 18px; background-color: #FFFBEB; border-left: 4px solid #F59E0B; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 4px 0; font-weight: 700; font-size: 12.5px; color: #92400E;">📝 Coordinator / HR Notes for Panel:</p>
              <p style="margin: 0; font-size: 13px; color: #78350F; line-height: 1.5;">{notes.strip()}</p>
            </div>
            """

        # Resolve datetimes for calendar
        if not raw_start_dt or not raw_end_dt:
            try:
                d_obj = datetime.strptime(scheduled_date, "%A, %d %B %Y").date()
                st_obj = datetime.strptime(time_start.strip(), "%I:%M %p").time()
                et_obj = datetime.strptime(time_end.strip(), "%I:%M %p").time()
                raw_start_dt = datetime.combine(d_obj, st_obj)
                raw_end_dt = datetime.combine(d_obj, et_obj)
            except Exception:
                raw_start_dt = datetime.now() + timedelta(days=1)
                raw_end_dt = raw_start_dt + timedelta(minutes=45)

        cal_title = f"[Panel] Interview: {candidate_name} - {job_title} ({interview_round})"
        cal_desc = (
            f"Candidate: {candidate_name} ({candidate_email} / {phone_display})\n"
            f"Position: {job_title}\n"
            f"Round: {interview_round}\n"
            f"Mode: {mode}\n"
            f"Location / Link: {location_display}\n"
            f"Co-Panelists: {co_panel_display}\n"
            f"Experience: {exp_display}\n"
            f"Notes: {notes or 'None'}"
        )
        google_cal_url = make_google_calendar_url(cal_title, cal_desc, location_display, raw_start_dt, raw_end_dt)
        outlook_cal_url = make_outlook_calendar_url(cal_title, cal_desc, location_display, raw_start_dt, raw_end_dt)

        ics_content = generate_ics_invite(
            summary=cal_title,
            description=cal_desc,
            location=location_display,
            start_dt=raw_start_dt,
            end_dt=raw_end_dt,
            organizer_email=self.email_from,
            organizer_name=f"{school_name} Recruitment",
            attendee_email=to_email,
            attendee_name=interviewer_name
        )

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" max-width="620" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #1E1B4B 0%, #312E81 60%, #4338CA 100%); padding: 32px 32px; text-align: center;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <span style="display:inline-block;background:rgba(255,255,255,0.15);color:#EEF2FF;padding:5px 14px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:10px;">
                      ✦ Interview Panel Assignment
                    </span>
                    <h1 style="margin: 8px 0 4px 0; color: #FFFFFF; font-size: 22px; font-weight: 700; letter-spacing: -0.4px;">
                      {school_name}
                    </h1>
                    <p style="margin: 0; color: #C7D2FE; font-size: 13.5px; font-weight: 400;">
                      Candidate Assessment &amp; Evaluation Schedule
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Body -->
          <tr>
            <td style="padding: 30px 32px 24px 32px;">
              <p style="margin: 0 0 14px 0; font-size: 16px; font-weight: 600; color: #0F172A;">
                Dear {interviewer_name},
              </p>
              <p style="margin: 0 0 18px 0; font-size: 14.5px; color: #334155; line-height: 1.6;">
                You have been assigned as an interviewer / evaluation panel member for <strong>{candidate_name}</strong>, who has applied for the <strong>{job_title}</strong> position.
              </p>

              <!-- Interview Timing & Logistics -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; margin-bottom: 20px;">
                <tr>
                  <td style="padding: 18px 20px;">
                    <div style="font-size: 12px; font-weight: 700; color: #4F46E5; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px;">
                      🗓️ Schedule &amp; Meeting Logistics
                    </div>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding-bottom: 8px; width: 50%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Interview Round</span>
                          <div style="font-size: 14px; font-weight: 600; color: #1E293B; margin-top: 2px;">{interview_round}</div>
                        </td>
                        <td style="padding-bottom: 8px; width: 50%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Mode</span>
                          <div style="font-size: 14px; font-weight: 600; color: #1E293B; margin-top: 2px;">
                            <span style="display:inline-block;padding:2px 8px;background:#EEF2FF;color:#4338CA;border-radius:4px;font-size:11.5px;">{mode}</span>
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding: 8px 0; border-top: 1px solid #F1F5F9;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Date &amp; Time</span>
                          <div style="font-size: 14.5px; font-weight: 700; color: #4F46E5; margin-top: 2px;">
                            📅 {scheduled_date} &nbsp;•&nbsp; ⏰ {time_start} – {time_end}
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding: 8px 0; border-top: 1px solid #F1F5F9;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Location / Join Link</span>
                          <div style="font-size: 13.5px; font-weight: 500; color: #1E293B; margin-top: 2px; word-break: break-all;">
                            📍 {location_display}
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding-top: 8px; border-top: 1px solid #F1F5F9;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Co-Panelists</span>
                          <div style="font-size: 13.5px; font-weight: 600; color: #334155; margin-top: 2px;">
                            👥 {co_panel_display}
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- Candidate Dossier Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #FFFFFF; border: 1px solid #CBD5E1; border-radius: 12px; margin-bottom: 20px; box-shadow: 0 2px 6px rgba(0,0,0,0.03);">
                <tr>
                  <td style="padding: 18px 20px;">
                    <div style="font-size: 12px; font-weight: 700; color: #0F172A; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 12px; display: flex; align-items: center;">
                      👤 Candidate Profile &amp; Dossier
                    </div>
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding-bottom: 8px; width: 50%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Full Name</span>
                          <div style="font-size: 14px; font-weight: 600; color: #0F172A; margin-top: 2px;">{candidate_name}</div>
                        </td>
                        <td style="padding-bottom: 8px; width: 50%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Total Experience</span>
                          <div style="font-size: 14px; font-weight: 600; color: #0F172A; margin-top: 2px;">{exp_display}</div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding-bottom: 8px; width: 50%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Email Address</span>
                          <div style="font-size: 13px; color: #334155; margin-top: 2px;">{candidate_email}</div>
                        </td>
                        <td style="padding-bottom: 8px; width: 50%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Phone Number</span>
                          <div style="font-size: 13px; color: #334155; margin-top: 2px;">{phone_display}</div>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding: 8px 0; border-top: 1px solid #F1F5F9;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Qualification &amp; Specialization</span>
                          <div style="font-size: 13.5px; font-weight: 600; color: #1E293B; margin-top: 2px;">
                            🎓 {qual_display} {spec_display}
                          </div>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding: 8px 0; border-top: 1px solid #F1F5F9;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Current Employment</span>
                          <div style="font-size: 13px; color: #334155; margin-top: 2px;">
                            🏢 {org_display}{desig_display}
                          </div>
                        </td>
                      </tr>
                      {skills_html}
                    </table>

                    <div style="margin-top: 12px; padding-top: 12px; border-top: 1px dashed #E2E8F0;">
                      {resume_btn_html}
                    </div>
                  </td>
                </tr>
              </table>

              <!-- Instant Calendar Scheduling Deep-Links -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background: #F1F5F9; border: 1px solid #E2E8F0; border-radius: 8px; margin-bottom: 20px; padding: 12px 16px;">
                <tr>
                  <td align="center">
                    <p style="margin: 0 0 10px 0; font-size: 12px; font-weight: 600; color: #475569; text-transform: uppercase; letter-spacing: 0.5px;">
                      ⚡ Book this slot in your work calendar:
                    </p>
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding: 0 6px;">
                          <a href="{google_cal_url}" target="_blank" style="display:inline-block;background-color:#FFFFFF;border:1px solid #CBD5E1;color:#1E293B;padding:9px 16px;border-radius:6px;text-decoration:none;font-size:12.5px;font-weight:600;box-shadow:0 1px 2px rgba(0,0,0,0.05);">
                            📅 Google Calendar
                          </a>
                        </td>
                        <td style="padding: 0 6px;">
                          <a href="{outlook_cal_url}" target="_blank" style="display:inline-block;background-color:#FFFFFF;border:1px solid #CBD5E1;color:#1E293B;padding:9px 16px;border-radius:6px;text-decoration:none;font-size:12.5px;font-weight:600;box-shadow:0 1px 2px rgba(0,0,0,0.05);">
                            📅 Outlook Calendar
                          </a>
                        </td>
                      </tr>
                    </table>
                    <p style="margin: 8px 0 0 0; font-size: 11px; color: #64748B;">
                      (Attached <code>panel_invite.ics</code> can also be opened to schedule automatically)
                    </p>
                  </td>
                </tr>
              </table>

              {join_btn_html}
              {notes_box_html}

              <div style="margin-top: 20px; padding-top: 16px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0 0 8px 0; font-size: 13px; color: #64748B; line-height: 1.5;">
                  📋 <strong>Evaluation Form:</strong> After the interview, please log in to the <strong>EduSHAMIIT Recruitment Portal</strong> to record your independent feedback scores across core competencies.
                </p>
              </div>

              <div style="margin-top: 24px;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Sincerely,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Recruitment &amp; HR Department</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8; line-height: 1.5;">
                This internal assignment notice was dispatched to panel member <strong>{to_email}</strong>.<br/>
                &copy; 2026 {school_name} • EduSHAMIIT Enterprise ERP
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

        return self._send_email(to_email, subject, html_content, ics_content=ics_content, ics_filename="panel_interview_assignment.ics")

    def send_job_application_confirmation_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        application_reference: str,
        applied_date: str,
        department: Optional[str] = None,
        location: Optional[str] = None,
        work_mode: Optional[str] = None
    ) -> bool:
        """Send a premium, branded application confirmation email when candidate applies for a job."""
        subject = f"Application Confirmed: {job_title} at {school_name} [{application_reference}]"

        dept_display = department if department and department.strip() else "Academics & Administration"
        loc_display = location if location and location.strip() else "Main Campus"
        mode_display = work_mode if work_mode and work_mode.strip() else "Full-Time / On-Site"

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 50%, #312E81 100%); padding: 36px 32px; text-align: center;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <span style="display:inline-block;background:rgba(255,255,255,0.12);color:#E0E7FF;padding:6px 16px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                      ✦ EduSHAMIIT Recruitment • Application Received
                    </span>
                    <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">
                      {school_name}
                    </h1>
                    <p style="margin: 0; color: #C7D2FE; font-size: 14px; font-weight: 400;">
                      Talent Acquisition &amp; Careers Portal
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Success Icon & Greeting -->
          <tr>
            <td style="padding: 32px 32px 20px 32px;">
              <div style="text-align: center; margin-bottom: 24px;">
                <div style="display: inline-block; width: 56px; height: 56px; line-height: 56px; border-radius: 50%; background-color: #ECFDF5; color: #10B981; font-size: 28px; text-align: center; box-shadow: 0 4px 12px rgba(16,185,129,0.2);">
                  ✓
                </div>
                <h2 style="margin: 12px 0 6px 0; color: #0F172A; font-size: 20px; font-weight: 700;">
                  Application Submitted Successfully
                </h2>
                <p style="margin: 0; color: #64748B; font-size: 14px;">
                  We have received your application and logged it into our hiring pipeline.
                </p>
              </div>

              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">
                Dear {candidate_name},
              </p>
              <p style="margin: 0 0 20px 0; font-size: 14.5px; color: #334155; line-height: 1.65;">
                Thank you for applying for the position of <strong>{job_title}</strong> at <strong>{school_name}</strong>. We are delighted that you are considering a career with our academic institution.
              </p>

              <!-- Application Reference Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; margin-bottom: 24px;">
                <tr>
                  <td style="padding: 20px;">
                    <!-- Reference Highlight -->
                    <div style="text-align: center; padding-bottom: 16px; margin-bottom: 16px; border-bottom: 1px dashed #CBD5E1;">
                      <div style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase; letter-spacing: 1px;">
                        Application Reference Number
                      </div>
                      <div style="font-size: 20px; font-weight: 800; color: #312E81; margin-top: 4px; letter-spacing: 0.5px; font-family: monospace;">
                        {application_reference}
                      </div>
                    </div>

                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="padding-bottom: 10px; width: 45%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Position Applied</span>
                          <div style="font-size: 14px; font-weight: 600; color: #0F172A; margin-top: 2px;">{job_title}</div>
                        </td>
                        <td style="padding-bottom: 10px; width: 55%; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Department</span>
                          <div style="font-size: 14px; font-weight: 600; color: #0F172A; margin-top: 2px;">{dept_display}</div>
                        </td>
                      </tr>
                      <tr>
                        <td style="padding-bottom: 10px; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Date Submitted</span>
                          <div style="font-size: 13.5px; font-weight: 500; color: #0F172A; margin-top: 2px;">📅 {applied_date}</div>
                        </td>
                        <td style="padding-bottom: 10px; vertical-align: top;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Location &amp; Mode</span>
                          <div style="font-size: 13.5px; font-weight: 500; color: #0F172A; margin-top: 2px;">📍 {loc_display} • {mode_display}</div>
                        </td>
                      </tr>
                      <tr>
                        <td colspan="2" style="padding-top: 6px; border-top: 1px solid #E2E8F0;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Current Status</span>
                          <div style="margin-top: 4px;">
                            <span style="display:inline-block;padding:4px 12px;background:#ECFDF5;color:#059669;border-radius:12px;font-size:12px;font-weight:700;">
                              ● Active • Under Review
                            </span>
                          </div>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>

              <!-- 4-Step Recruitment Roadmap -->
              <div style="margin-bottom: 24px;">
                <div style="font-size: 13px; font-weight: 700; color: #1E293B; margin-bottom: 14px; text-transform: uppercase; letter-spacing: 0.5px;">
                  What Happens Next (Hiring Workflow)
                </div>

                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td style="padding-bottom: 12px;">
                      <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                          <td style="width: 28px; vertical-align: top;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background: #10B981; color: #FFFFFF; font-size: 12px; font-weight: bold; text-align: center; line-height: 22px;">✓</div>
                          </td>
                          <td style="padding-left: 10px;">
                            <div style="font-size: 13.5px; font-weight: 600; color: #0F172A;">1. Application Received</div>
                            <div style="font-size: 12px; color: #64748B;">Your resume, credentials, and questionnaire responses are securely recorded.</div>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding-bottom: 12px;">
                      <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                          <td style="width: 28px; vertical-align: top;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background: #4F46E5; color: #FFFFFF; font-size: 12px; font-weight: bold; text-align: center; line-height: 22px;">2</div>
                          </td>
                          <td style="padding-left: 10px;">
                            <div style="font-size: 13.5px; font-weight: 600; color: #4F46E5;">2. Profile Screening &amp; Shortlisting (Current Stage)</div>
                            <div style="font-size: 12px; color: #64748B;">Our HR department and hiring managers review applicant qualifications.</div>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                  <tr>
                    <td style="padding-bottom: 12px;">
                      <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                          <td style="width: 28px; vertical-align: top;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background: #CBD5E1; color: #64748B; font-size: 12px; font-weight: bold; text-align: center; line-height: 22px;">3</div>
                          </td>
                          <td style="padding-left: 10px;">
                            <div style="font-size: 13.5px; font-weight: 600; color: #64748B;">3. Evaluation &amp; Interview Rounds</div>
                            <div style="font-size: 12px; color: #94A3B8;">Shortlisted candidates receive interview invitations with calendar coordinates.</div>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                  <tr>
                    <td>
                      <table width="100%" cellpadding="0" cellspacing="0">
                        <tr>
                          <td style="width: 28px; vertical-align: top;">
                            <div style="width: 22px; height: 22px; border-radius: 50%; background: #CBD5E1; color: #64748B; font-size: 12px; font-weight: bold; text-align: center; line-height: 22px;">4</div>
                          </td>
                          <td style="padding-left: 10px;">
                            <div style="font-size: 13.5px; font-weight: 600; color: #64748B;">4. Final Selection &amp; Formal Offer</div>
                            <div style="font-size: 12px; color: #94A3B8;">Selected candidates receive employment agreements and onboarding details.</div>
                          </td>
                        </tr>
                      </table>
                    </td>
                  </tr>
                </table>
              </div>

              <!-- Helpful Note -->
              <div style="background-color: #EEF2FF; border-left: 4px solid #4F46E5; border-radius: 6px; padding: 14px 16px; margin-bottom: 24px;">
                <p style="margin: 0 0 4px 0; font-weight: 600; font-size: 13px; color: #1E293B;">
                  💡 Important Information:
                </p>
                <p style="margin: 0; font-size: 12.5px; color: #4338CA; line-height: 1.5;">
                  Please keep your application reference (<strong>{application_reference}</strong>) handy. You will receive updates by email at each stage of your application journey.
                </p>
              </div>

              <!-- Sign-off -->
              <div style="padding-top: 16px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Warm regards,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">HR &amp; Recruitment Team</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8; line-height: 1.5;">
                This notification was sent to <strong>{to_email}</strong> regarding application {application_reference}.<br/>
                &copy; 2026 {school_name} • Powered by EduSHAMIIT Enterprise ERP
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

        return self._send_email(to_email, subject, html_content)

    def send_candidate_stage_transition_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        to_stage: str,
        from_stage: Optional[str] = None,
        application_reference: Optional[str] = None,
        notes: Optional[str] = None,
        extra_info: Optional[Dict[str, Any]] = None
    ) -> bool:
        """Send a premium, branded email notification to candidate when their application stage changes."""
        extra_info = extra_info or {}
        ref_text = f" [{application_reference}]" if application_reference else ""

        # Normalize target stage
        stage_norm = to_stage.strip().title()

        # Stage specific metadata & styling configuration
        stage_configs = {
            "Shortlisted": {
                "subject": f"🎉 Congratulations! You have been Shortlisted for {job_title} at {school_name}{ref_text}",
                "pill": "✦ APPLICATION SHORTLISTED ✦",
                "accent_color": "#10B981",
                "badge_bg": "#ECFDF5",
                "badge_color": "#059669",
                "icon": "⭐",
                "headline": "Congratulations! You're Shortlisted",
                "message": f"We are thrilled to inform you that after reviewing all applicants for the <strong>{job_title}</strong> role, your qualifications, expertise, and background have impressed our hiring panel. You have been officially <strong>Shortlisted</strong>.",
                "next_steps": "Our talent acquisition team will be in touch shortly to schedule your upcoming interview round. Please ensure your contact details are accessible and keep an eye on your inbox for calendar invitations.",
                "tip": "Tip: Review the job description and prepare any portfolio items or work samples that highlight your recent accomplishments."
            },
            "Selected": {
                "subject": f"🌟 Wonderful News! You have been Selected for {job_title} at {school_name}{ref_text}",
                "pill": "✦ CANDIDATE SELECTED ✦",
                "accent_color": "#6366F1",
                "badge_bg": "#EEF2FF",
                "badge_color": "#4338CA",
                "icon": "🌟",
                "headline": "Congratulations on Your Selection!",
                "message": f"We are delighted to share wonderful news! Following your comprehensive evaluations and interview sessions, the recruitment committee has officially <strong>Selected</strong> you for the position of <strong>{job_title}</strong> at <strong>{school_name}</strong>.",
                "next_steps": "Our Human Resources and Operations team is now preparing your formal offer letter, compensation breakdown, and employment agreement. A formal offer document will be issued to you soon.",
                "tip": "Tip: If you have any pending documentation or questions regarding joining timelines, feel free to reply directly to this email."
            },
            "Interview": {
                "subject": f"📅 Interview Stage Update: {job_title} at {school_name}{ref_text}",
                "pill": "✦ INTERVIEW STAGE ADVANCEMENT ✦",
                "accent_color": "#3B82F6",
                "badge_bg": "#EFF6FF",
                "badge_color": "#1D4ED8",
                "icon": "📅",
                "headline": "Advancement to Interview Stage",
                "message": f"Your application for <strong>{job_title}</strong> at <strong>{school_name}</strong> has advanced to the <strong>Interview Stage</strong>.",
                "next_steps": "Our interview panel is coordinating upcoming session dates. You will receive a separate calendar invitation detailing the exact time, mode (virtual/on-campus), and panel members shortly.",
                "tip": "Tip: Please ensure you have a stable internet connection and quiet environment if scheduled for an online meeting."
            },
            "Offer": {
                "subject": f"📄 Formal Employment Offer: {job_title} at {school_name}{ref_text}",
                "pill": "✦ EMPLOYMENT OFFER ISSUED ✦",
                "accent_color": "#4F46E5",
                "badge_bg": "#EEF2FF",
                "badge_color": "#3730A3",
                "icon": "📄",
                "headline": "Your Formal Offer of Employment",
                "message": f"On behalf of <strong>{school_name}</strong>, we are delighted to extend a formal offer of employment for the <strong>{job_title}</strong> position. We are confident that your leadership and talent will enrich our institution.",
                "next_steps": "Please review the offer parameters, terms of engagement, and joining particulars. Kindly reply or accept through our official channels to initiate your formal onboarding.",
                "tip": "Tip: If you have questions regarding the terms or require any clarification, our HR desk is ready to support you."
            },
            "Hired": {
                "subject": f"🎉 Welcome to {school_name}! Appointment Confirmed as {job_title}{ref_text}",
                "pill": "✦ WELCOME TO THE TEAM ✦",
                "accent_color": "#059669",
                "badge_bg": "#ECFDF5",
                "badge_color": "#047857",
                "icon": "🤝",
                "headline": "Welcome to Our Academic Community!",
                "message": f"It is our immense pleasure to formally welcome you as an appointed staff member of <strong>{school_name}</strong>! Your hiring journey for <strong>{job_title}</strong> is officially complete.",
                "next_steps": "Our HR onboarding team will reach out with your orientation itinerary, account credentials, and document verification schedule.",
                "tip": "Tip: We look forward to your impactful contributions and an inspiring professional journey together!"
            },
            "Screening": {
                "subject": f"Application Status Update: Screening for {job_title} at {school_name}{ref_text}",
                "pill": "✦ INITIAL SCREENING ✦",
                "accent_color": "#0284C7",
                "badge_bg": "#F0F9FF",
                "badge_color": "#0369A1",
                "icon": "🔍",
                "headline": "Application in Initial Screening",
                "message": f"Your application for <strong>{job_title}</strong> at <strong>{school_name}</strong> is currently being screened by our talent acquisition specialists against the position requirements.",
                "next_steps": "We will update you as soon as this review phase is concluded. Thank you for your patience.",
                "tip": None
            },
            "Assessment": {
                "subject": f"Assessment Stage: {job_title} at {school_name}{ref_text}",
                "pill": "✦ TECHNICAL & SKILLS ASSESSMENT ✦",
                "accent_color": "#8B5CF6",
                "badge_bg": "#F5F3FF",
                "badge_color": "#6D28D9",
                "icon": "📝",
                "headline": "Skills & Credentials Assessment",
                "message": f"Your candidacy for <strong>{job_title}</strong> has progressed to the <strong>Assessment Stage</strong>.",
                "next_steps": "Our evaluators will examine your credentials or dispatch assessment instructions if applicable.",
                "tip": None
            },
            "Rejected": {
                "subject": f"Application Update: {job_title} at {school_name}{ref_text}",
                "pill": "✦ APPLICATION STATUS UPDATE ✦",
                "accent_color": "#64748B",
                "badge_bg": "#F8FAFC",
                "badge_color": "#475569",
                "icon": "✉️",
                "headline": "Application Status Update",
                "message": f"Thank you for your interest in the <strong>{job_title}</strong> role at <strong>{school_name}</strong> and for the time and energy you invested in our application process. After thoughtful review of all applications against our immediate requirements, we have decided to move forward with other candidates at this time.",
                "next_steps": "We will retain your profile in our talent pool and will proactively reach out should future openings align with your professional background. We wish you continued success in your career endeavors.",
                "tip": None
            }
        }

        cfg = stage_configs.get(stage_norm)
        if not cfg:
            # Fallback for custom or unlisted stages
            cfg = {
                "subject": f"Application Update: {stage_norm} for {job_title} at {school_name}{ref_text}",
                "pill": f"✦ STAGE: {stage_norm.upper()} ✦",
                "accent_color": "#4F46E5",
                "badge_bg": "#EEF2FF",
                "badge_color": "#3730A3",
                "icon": "📋",
                "headline": f"Application Advanced to {stage_norm}",
                "message": f"Your application for <strong>{job_title}</strong> at <strong>{school_name}</strong> has updated to the <strong>{stage_norm}</strong> stage.",
                "next_steps": "Our recruitment team will communicate any necessary next steps with you.",
                "tip": None
            }

        subject = cfg["subject"]
        pill = cfg["pill"]
        accent_color = cfg["accent_color"]
        badge_bg = cfg["badge_bg"]
        badge_color = cfg["badge_color"]
        icon = cfg["icon"]
        headline = cfg["headline"]
        main_message = cfg["message"]
        next_steps_text = cfg["next_steps"]
        tip_text = cfg.get("tip")

        # Optional notes box if provided by recruiter
        notes_box_html = ""
        if notes and notes.strip() and stage_norm != "Rejected":
            notes_box_html = f"""
            <div style="margin-top: 20px; background-color: #F8FAFC; border-left: 4px solid {accent_color}; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 6px 0; font-weight: 600; font-size: 13px; color: #1E293B;">📝 Recruiter Notes:</p>
              <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.5;">{notes.strip()}</p>
            </div>
            """

        # Extra info highlight if available (e.g. Employee ID on hire, Joining date on offer)
        extra_box_html = ""
        if extra_info:
            extra_rows = ""
            for k, v in extra_info.items():
                if v:
                    extra_rows += f"""
                    <tr>
                      <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600; width: 40%;">{k}:</td>
                      <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{v}</td>
                    </tr>
                    """
            if extra_rows:
                extra_box_html = f"""
                <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 14px 16px; margin: 20px 0;">
                  {extra_rows}
                </table>
                """

        tip_box_html = ""
        if tip_text:
            tip_box_html = f"""
            <div style="margin-top: 18px; padding: 12px 14px; background-color: #F8FAFC; border-radius: 8px; font-size: 12.5px; color: #64748B; line-height: 1.5;">
              {tip_text}
            </div>
            """

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 50%, #312E81 100%); padding: 36px 32px; text-align: center;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td align="center">
                    <span style="display:inline-block;background:rgba(255,255,255,0.12);color:#E0E7FF;padding:6px 16px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                      {pill}
                    </span>
                    <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700; letter-spacing: -0.5px;">
                      {school_name}
                    </h1>
                    <p style="margin: 0; color: #C7D2FE; font-size: 14px; font-weight: 400;">
                      Talent Acquisition &amp; Careers
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- Main Body -->
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <div style="text-align: center; margin-bottom: 24px;">
                <div style="display: inline-block; width: 54px; height: 54px; line-height: 54px; border-radius: 50%; background-color: {badge_bg}; color: {badge_color}; font-size: 24px; text-align: center;">
                  {icon}
                </div>
                <h2 style="margin: 12px 0 6px 0; color: #0F172A; font-size: 20px; font-weight: 700;">
                  {headline}
                </h2>
                <span style="display: inline-block; padding: 4px 14px; background: {badge_bg}; color: {badge_color}; border-radius: 16px; font-size: 12px; font-weight: 700; text-transform: uppercase;">
                  Stage: {stage_norm}
                </span>
              </div>

              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">
                Dear {candidate_name},
              </p>
              <p style="margin: 0 0 20px 0; font-size: 14.5px; color: #334155; line-height: 1.65;">
                {main_message}
              </p>

              <!-- Application Details Mini-card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; margin-bottom: 20px;">
                <tr>
                  <td style="padding: 16px 20px;">
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="width: 50%; padding-bottom: 8px;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Position</span>
                          <div style="font-size: 14px; font-weight: 600; color: #0F172A; margin-top: 2px;">{job_title}</div>
                        </td>
                        <td style="width: 50%; padding-bottom: 8px;">
                          <span style="font-size: 11px; font-weight: 700; color: #64748B; text-transform: uppercase;">Institution</span>
                          <div style="font-size: 14px; font-weight: 600; color: #0F172A; margin-top: 2px;">{school_name}</div>
                        </td>
                      </tr>
                      {f'<tr><td colspan="2"><span style="font-size:11px;font-weight:700;color:#64748B;text-transform:uppercase;">Reference ID</span><div style="font-size:13px;font-weight:600;color:#312E81;margin-top:2px;font-family:monospace;">{application_reference}</div></td></tr>' if application_reference else ''}
                    </table>
                  </td>
                </tr>
              </table>

              {extra_box_html}
              {notes_box_html}

              <!-- Next Steps Box -->
              <div style="margin-top: 20px; background-color: #F8FAFC; border-left: 4px solid {accent_color}; border-radius: 6px; padding: 16px;">
                <p style="margin: 0 0 6px 0; font-weight: 700; font-size: 13px; color: #1E293B; text-transform: uppercase; letter-spacing: 0.5px;">
                  What to Expect Next:
                </p>
                <p style="margin: 0; font-size: 13.5px; color: #334155; line-height: 1.6;">
                  {next_steps_text}
                </p>
              </div>

              {tip_box_html}

              <!-- Sign-off -->
              <div style="margin-top: 26px; padding-top: 18px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Warm regards,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">HR &amp; Recruitment Team</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8; line-height: 1.5;">
                This communication was sent to <strong>{to_email}</strong> regarding application {ref_text or f'for {job_title}'}.<br/>
                &copy; 2026 {school_name} • Powered by EduSHAMIIT Enterprise ERP
              </p>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""

        return self._send_email(to_email, subject, html_content)

    def send_assessment_assigned_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        assessment_title: str,
        assessment_type: str,
        due_date: Optional[str] = None,
        test_link: Optional[str] = None,
        max_score: Optional[float] = 100.0,
        instructions: Optional[str] = None,
        application_reference: Optional[str] = None
    ) -> bool:
        """Send formal assessment invitation and guidelines email to candidate."""
        ref_text = f" [{application_reference}]" if application_reference else ""
        subject = f"📝 Assessment Invitation: {assessment_title} for {job_title} at {school_name}{ref_text}"

        link_button_html = ""
        if test_link and test_link.strip():
            link_clean = test_link.strip()
            link_button_html = f"""
            <div style="text-align: center; margin: 26px 0;">
              <a href="{link_clean}" target="_blank" style="display: inline-block; background: #8B5CF6; color: #FFFFFF; text-decoration: none; padding: 14px 28px; border-radius: 8px; font-weight: 700; font-size: 14px; letter-spacing: 0.3px; box-shadow: 0 4px 12px rgba(139, 92, 246, 0.3);">
                Access Online Assessment Platform &rarr;
              </a>
              <p style="margin: 8px 0 0 0; font-size: 11.5px; color: #94A3B8;">Direct Link: <a href="{link_clean}" style="color: #8B5CF6;">{link_clean}</a></p>
            </div>
            """

        instructions_html = ""
        if instructions and instructions.strip():
            instructions_html = f"""
            <div style="margin-top: 20px; background-color: #F8FAFC; border-left: 4px solid #8B5CF6; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 6px 0; font-weight: 700; font-size: 12.5px; color: #1E293B; text-transform: uppercase;">📋 Candidate Guidelines &amp; Instructions:</p>
              <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.6;">{instructions.strip()}</p>
            </div>
            """

        due_date_str = due_date or "To be completed at your earliest convenience"
        max_score_str = f"{int(max_score)} points" if max_score else "100 points"

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #1E1B4B 0%, #4C1D95 50%, #7C3AED 100%); padding: 36px 32px; text-align: center;">
              <span style="display:inline-block;background:rgba(255,255,255,0.15);color:#F5F3FF;padding:6px 16px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                ✦ CANDIDATE ASSESSMENT ✦
              </span>
              <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700;">{school_name}</h1>
              <p style="margin: 0; color: #DDD6FE; font-size: 14px;">Talent Acquisition &amp; Academic Recruitment</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <div style="text-align: center; margin-bottom: 24px;">
                <div style="display: inline-block; width: 54px; height: 54px; line-height: 54px; border-radius: 50%; background-color: #F5F3FF; color: #7C3AED; font-size: 24px; text-align: center;">
                  📝
                </div>
                <h2 style="margin: 12px 0 6px 0; color: #0F172A; font-size: 20px; font-weight: 700;">{assessment_title}</h2>
                <span style="display: inline-block; padding: 4px 14px; background: #F5F3FF; color: #6D28D9; border-radius: 16px; font-size: 12px; font-weight: 700;">
                  Type: {assessment_type}
                </span>
              </div>

              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">Dear {candidate_name},</p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #334155; line-height: 1.65;">
                As part of our recruitment evaluation for the <strong>{job_title}</strong> role at <strong>{school_name}</strong>, you have been invited to complete the <strong>{assessment_title}</strong>. This evaluation enables our academic panel to assess your subject depth, pedagogy, and technical expertise.
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 14px 18px; margin: 20px 0;">
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600; width: 40%;">Position:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{job_title}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Assessment Format:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{assessment_type}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Due / Scheduled Date:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #7C3AED; font-weight: 700;">{due_date_str}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Maximum Score:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{max_score_str}</td>
                </tr>
              </table>

              {link_button_html}
              {instructions_html}

              <div style="margin-top: 26px; padding-top: 18px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Best of luck with your assessment,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Evaluation &amp; Hiring Panel</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 {school_name} • EduSHAMIIT Enterprise Recruitment</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content)

    def send_assessment_result_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        assessment_title: str,
        result: str,
        score: Optional[float] = None,
        max_score: Optional[float] = 100.0,
        remarks: Optional[str] = None,
        application_reference: Optional[str] = None
    ) -> bool:
        """Send assessment results notification email to candidate."""
        ref_text = f" [{application_reference}]" if application_reference else ""
        is_passed = result.lower() == "passed"
        accent_color = "#10B981" if is_passed else ("#F59E0B" if result.lower() == "pending" else "#EF4444")
        badge_bg = "#ECFDF5" if is_passed else ("#FFFBEB" if result.lower() == "pending" else "#FEF2F2")
        badge_color = "#047857" if is_passed else ("#B45309" if result.lower() == "pending" else "#B91C1C")
        icon = "🌟" if is_passed else "📊"

        subject = f"{'🎉 Assessment Result: Passed - ' if is_passed else 'Assessment Update: '}{assessment_title} for {job_title} at {school_name}{ref_text}"

        score_disp = f"{score} / {max_score}" if score is not None else "Evaluated"

        remarks_html = ""
        if remarks and remarks.strip():
            remarks_html = f"""
            <div style="margin-top: 18px; background-color: #F8FAFC; border-left: 4px solid {accent_color}; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 4px 0; font-weight: 700; font-size: 12.5px; color: #1E293B;">Reviewer Feedback:</p>
              <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.5;">{remarks.strip()}</p>
            </div>
            """

        next_steps = "Congratulations on successfully passing this assessment! Our talent acquisition committee has reviewed your score, and you are advancing to the next stage in our hiring pipeline." if is_passed else "Thank you for completing this assessment. Our team is reviewing the collective evaluation metrics."

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E293B 100%); padding: 36px 32px; text-align: center;">
              <h1 style="margin: 0 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700;">{school_name}</h1>
              <p style="margin: 0; color: #94A3B8; font-size: 14px;">Assessment Performance Notification</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <div style="text-align: center; margin-bottom: 24px;">
                <div style="display: inline-block; width: 54px; height: 54px; line-height: 54px; border-radius: 50%; background-color: {badge_bg}; color: {badge_color}; font-size: 24px; text-align: center;">
                  {icon}
                </div>
                <h2 style="margin: 12px 0 6px 0; color: #0F172A; font-size: 20px; font-weight: 700;">{assessment_title} Result</h2>
                <span style="display: inline-block; padding: 6px 16px; background: {badge_bg}; color: {badge_color}; border-radius: 16px; font-size: 13px; font-weight: 800; text-transform: uppercase;">
                  Outcome: {result}
                </span>
              </div>

              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">Dear {candidate_name},</p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #334155; line-height: 1.65;">
                We are writing to share the evaluation outcome for the <strong>{assessment_title}</strong> for the <strong>{job_title}</strong> role at <strong>{school_name}</strong>.
              </p>

              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 14px 18px; margin: 20px 0;">
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600; width: 40%;">Position:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{job_title}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Score Achieved:</td>
                  <td style="padding: 6px 0; font-size: 15px; color: {accent_color}; font-weight: 800;">{score_disp}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Assessment Status:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: {badge_color}; font-weight: 700;">{result}</td>
                </tr>
              </table>

              {remarks_html}

              <p style="margin: 20px 0 0 0; font-size: 13.5px; color: #334155; line-height: 1.6;">
                {next_steps}
              </p>

              <div style="margin-top: 26px; padding-top: 18px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Sincerely,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Recruitment &amp; Academic Panel</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 {school_name} • EduSHAMIIT Enterprise Recruitment</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content)

    def send_job_offer_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        salary: Optional[str] = None,
        joining_date: Optional[str] = None,
        employment_type: Optional[str] = None,
        probation_period_months: Optional[int] = 6,
        benefits: Optional[str] = None,
        offer_expiry_date: Optional[str] = None,
        terms: Optional[str] = None,
        application_reference: Optional[str] = None
    ) -> bool:
        """Send formal employment offer details email to candidate."""
        ref_text = f" [{application_reference}]" if application_reference else ""
        subject = f"📄 Formal Employment Offer: {job_title} at {school_name}{ref_text}"

        salary_num = 0.0
        try:
            if salary:
                clean_sal = salary.replace("₹", "").replace(",", "").strip()
                salary_num = float(clean_sal)
        except Exception:
            salary_num = 0.0

        monthly_formatted = f"₹{salary_num:,.2f}" if salary_num > 0 else (salary or "Commensurate with experience")
        annual_ctc = f"₹{salary_num * 12:,.2f} per annum" if salary_num > 0 else "Competitive Annual Package"

        probation_str = f"{probation_period_months} months" if probation_period_months else "6 months"
        joining_str = joining_date or "To be mutually agreed"
        expiry_str = offer_expiry_date or "Within 7 days of receipt"

        benefits_html = ""
        if benefits and benefits.strip():
            benefits_html = f"""
            <tr>
              <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600; vertical-align: top;">Benefits &amp; Perks:</td>
              <td style="padding: 8px 0; font-size: 13.5px; color: #0F172A; font-weight: 600;">{benefits.strip()}</td>
            </tr>
            """

        terms_html = ""
        if terms and terms.strip():
            terms_html = f"""
            <div style="margin-top: 20px; background-color: #F8FAFC; border-left: 4px solid #4F46E5; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 6px 0; font-weight: 700; font-size: 12.5px; color: #1E293B; text-transform: uppercase;">📜 Key Terms &amp; Conditions:</p>
              <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.6;">{terms.strip()}</p>
            </div>
            """

        # Generate Professional Offer Letter PDF attachment
        attachments = []
        try:
            from app.services.offer_letter_pdf import generate_offer_letter_pdf
            pdf_bytes = generate_offer_letter_pdf(
                candidate_name=candidate_name,
                job_title=job_title,
                school_name=school_name,
                salary=salary,
                joining_date=joining_date,
                employment_type=employment_type,
                probation_period_months=probation_period_months,
                benefits=benefits,
                offer_expiry_date=offer_expiry_date,
                terms=terms,
                application_reference=application_reference,
                to_email=to_email
            )
            safe_name = "".join(c for c in candidate_name if c.isalnum() or c in (' ', '_', '-')).strip().replace(' ', '_')
            pdf_filename = f"Offer_Letter_{safe_name or 'Candidate'}.pdf"
            attachments.append({
                "filename": pdf_filename,
                "content": pdf_bytes,
                "subtype": "pdf"
            })
            logger.info(f"Generated professional PDF offer letter for {candidate_name} ({len(pdf_bytes)} bytes)")
        except Exception as e:
            logger.error(f"Failed to generate offer letter PDF for {candidate_name}: {e}")

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 50%, #312E81 100%); padding: 36px 32px; text-align: center;">
              <span style="display:inline-block;background:rgba(255,255,255,0.12);color:#E0E7FF;padding:6px 16px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                ✦ FORMAL EMPLOYMENT OFFER ✦
              </span>
              <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700;">{school_name}</h1>
              <p style="margin: 0; color: #C7D2FE; font-size: 14px;">Office of Human Resources &amp; Talent Management</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <div style="text-align: center; margin-bottom: 24px;">
                <div style="display: inline-block; width: 54px; height: 54px; line-height: 54px; border-radius: 50%; background-color: #EEF2FF; color: #4F46E5; font-size: 24px; text-align: center;">
                  📄
                </div>
                <h2 style="margin: 12px 0 6px 0; color: #0F172A; font-size: 20px; font-weight: 700;">Official Offer of Employment</h2>
                <span style="display: inline-block; padding: 4px 14px; background: #EEF2FF; color: #3730A3; border-radius: 16px; font-size: 12px; font-weight: 700;">
                  Position: {job_title}
                </span>
              </div>

              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">Dear {candidate_name},</p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #334155; line-height: 1.65;">
                On behalf of <strong>{school_name}</strong>, we are thrilled to extend this formal offer of employment for the position of <strong>{job_title}</strong>. Following your successful progression through our recruitment evaluations, our leadership and academic panel are enthusiastic about the expertise and leadership you will bring to our community.
              </p>

              <!-- Compensation & Offer Summary Table -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 16px 20px; margin: 20px 0;">
                <tr>
                  <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600; width: 40%;">Monthly Gross Salary:</td>
                  <td style="padding: 8px 0; font-size: 16px; color: #059669; font-weight: 800;">{monthly_formatted} / month</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Annual Cost to Company (CTC):</td>
                  <td style="padding: 8px 0; font-size: 14px; color: #0F172A; font-weight: 700;">{annual_ctc}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Employment Type:</td>
                  <td style="padding: 8px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{employment_type or 'Full-time'}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Expected Commencement:</td>
                  <td style="padding: 8px 0; font-size: 13.5px; color: #4F46E5; font-weight: 700;">{joining_str}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Probation Period:</td>
                  <td style="padding: 8px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{probation_str}</td>
                </tr>
                <tr>
                  <td style="padding: 8px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Offer Acceptance Deadline:</td>
                  <td style="padding: 8px 0; font-size: 13.5px; color: #DC2626; font-weight: 700;">{expiry_str}</td>
                </tr>
                {benefits_html}
              </table>

              {terms_html}

              <!-- PDF Attachment Notice -->
              <div style="margin-top: 22px; background-color: #EEF2FF; border: 1.5px solid #C7D2FE; border-radius: 10px; padding: 14px 18px;">
                <table width="100%" cellpadding="0" cellspacing="0">
                  <tr>
                    <td width="36" style="vertical-align: middle; font-size: 24px;">📄</td>
                    <td style="vertical-align: middle;">
                      <p style="margin: 0; font-weight: 700; font-size: 13.5px; color: #1E1B4B;">Official Offer Letter Attached (PDF)</p>
                      <p style="margin: 3px 0 0 0; font-size: 12px; color: #4338CA; line-height: 1.4;">
                        A formal, digitally certified PDF copy of your employment offer letter is attached to this email for your official records and countersignature.
                      </p>
                    </td>
                  </tr>
                </table>
              </div>

              <div style="margin-top: 24px; background-color: #ECFDF5; border-left: 4px solid #10B981; border-radius: 6px; padding: 16px;">
                <p style="margin: 0 0 4px 0; font-weight: 700; font-size: 13px; color: #065F46;">How to Accept this Offer:</p>
                <p style="margin: 0; font-size: 13px; color: #047857; line-height: 1.55;">
                  To accept this offer, please reply to this email confirming your acceptance or submit your signed agreement before <strong>{expiry_str}</strong>. Our onboarding coordinator will then connect with you to prepare your joining credentials and documentation.
                </p>
              </div>

              <div style="margin-top: 26px; padding-top: 18px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">With best regards,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Director of Human Resources</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 20px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 {school_name} • EduSHAMIIT Enterprise Recruitment</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content, attachments=attachments)

    def send_candidate_hired_welcome_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        school_name: str,
        employee_id: Optional[str] = None,
        joining_date: Optional[str] = None,
        department: Optional[str] = None,
        application_reference: Optional[str] = None
    ) -> bool:
        """Send official appointment welcome email to hired candidate with employee ID."""
        extra_info = {}
        if employee_id:
            extra_info["Staff / Employee ID"] = employee_id
        if department:
            extra_info["Department"] = department
        if joining_date:
            extra_info["Commencement Date"] = joining_date

        return self.send_candidate_stage_transition_email(
            to_email=to_email,
            candidate_name=candidate_name,
            job_title=job_title,
            school_name=school_name,
            to_stage="Hired",
            application_reference=application_reference,
            extra_info=extra_info
        )

    def send_onboarding_reminder_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        department: str,
        school_name: str,
        employee_id: str,
        current_stage: str,
        expected_joining_date: Optional[str] = None,
        reporting_time: Optional[str] = None,
        reporting_location: Optional[str] = None,
        pending_documents: Optional[List[str]] = None,
        pending_tasks: Optional[List[str]] = None,
        custom_message: Optional[str] = None
    ) -> bool:
        """Send a comprehensive, professional onboarding action reminder email to a new hire."""
        subject = f"📢 Action Required: Complete Your Onboarding at {school_name} - {candidate_name} ({employee_id})"

        docs_list = pending_documents or []
        tasks_list = pending_tasks or []

        # Format pending documents HTML
        if docs_list:
            docs_items = "".join([f'<li style="padding: 4px 0; color: #DC2626; font-size: 13px;"><strong>{d}</strong></li>' for d in docs_list])
            docs_section = f"""
            <div style="margin: 20px 0; background-color: #FEF2F2; border-left: 4px solid #EF4444; border-radius: 8px; padding: 16px 20px;">
              <p style="margin: 0 0 8px 0; font-weight: 700; font-size: 13.5px; color: #991B1B;">
                📄 Pending Documents Required ({len(docs_list)}):
              </p>
              <ul style="margin: 0; padding-left: 20px; line-height: 1.6;">
                {docs_items}
              </ul>
              <p style="margin: 10px 0 0 0; font-size: 12px; color: #B91C1C;">
                Please submit or upload these documents as soon as possible to ensure timely completion of background verification and payroll registration.
              </p>
            </div>
            """
        else:
            docs_section = """
            <div style="margin: 20px 0; background-color: #ECFDF5; border-left: 4px solid #10B981; border-radius: 8px; padding: 14px 18px;">
              <p style="margin: 0; font-size: 13px; color: #065F46; font-weight: 600;">
                ✓ All required documents have been received and verified.
              </p>
            </div>
            """

        # Format pending tasks HTML
        if tasks_list:
            tasks_items = "".join([f'<li style="padding: 4px 0; color: #4338CA; font-size: 13px;">{t}</li>' for t in tasks_list])
            tasks_section = f"""
            <div style="margin: 20px 0; background-color: #EEF2FF; border-left: 4px solid #6366F1; border-radius: 8px; padding: 16px 20px;">
              <p style="margin: 0 0 8px 0; font-weight: 700; font-size: 13.5px; color: #3730A3;">
                📋 Pending Formalities &amp; Action Items ({len(tasks_list)}):
              </p>
              <ul style="margin: 0; padding-left: 20px; line-height: 1.6;">
                {tasks_items}
              </ul>
            </div>
            """
        else:
            tasks_section = ""

        custom_note_html = ""
        if custom_message and custom_message.strip():
            custom_note_html = f"""
            <div style="margin: 20px 0; background-color: #FFFBEB; border-left: 4px solid #F59E0B; border-radius: 8px; padding: 14px 18px;">
              <p style="margin: 0 0 4px 0; font-weight: 700; font-size: 12.5px; color: #92400E; text-transform: uppercase;">Note from HR:</p>
              <p style="margin: 0; font-size: 13px; color: #78350F; line-height: 1.6;">{custom_message.strip()}</p>
            </div>
            """

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 50%, #312E81 100%); padding: 36px 32px; text-align: center;">
              <span style="display:inline-block;background:rgba(255,255,255,0.12);color:#E0E7FF;padding:6px 16px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                ✦ ONBOARDING ACTION REQUIRED ✦
              </span>
              <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700;">{school_name}</h1>
              <p style="margin: 0; color: #C7D2FE; font-size: 14px;">Office of Human Resources &amp; Employee Success</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">Dear {candidate_name},</p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #334155; line-height: 1.65;">
                This is a friendly reminder regarding your onboarding process for the position of <strong>{job_title}</strong> in the <strong>{department}</strong> department at <strong>{school_name}</strong>.
              </p>

              <!-- Onboarding Summary Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 16px 20px; margin: 20px 0;">
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600; width: 42%;">Employee ID / Code:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #4F46E5; font-weight: 800;">{employee_id}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Current Stage:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{current_stage}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Expected Joining Date:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 700;">{expected_joining_date or 'As Scheduled'}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Reporting Time &amp; Location:</td>
                  <td style="padding: 6px 0; font-size: 13px; color: #0F172A; font-weight: 600;">
                    {reporting_time or '09:00 AM'} ({reporting_location or 'Main Campus HR Office'})
                  </td>
                </tr>
              </table>

              {docs_section}
              {tasks_section}
              {custom_note_html}

              <div style="margin-top: 24px; background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 8px; padding: 16px;">
                <p style="margin: 0 0 6px 0; font-weight: 700; font-size: 13px; color: #0F172A;">How to Complete Your Formalities:</p>
                <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.6;">
                  Please submit the outstanding documents to your designated HR coordinator or bring physical copies on your reporting day. If you need any assistance or have questions, reply directly to this email or reach out to the HR Operations team.
                </p>
              </div>

              <div style="margin-top: 26px; padding-top: 18px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Best regards,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Onboarding &amp; Talent Operations</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 {school_name} • EduSHAMIIT Enterprise HR</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content)

    def send_onboarding_stage_transition_email(
        self,
        to_email: str,
        candidate_name: str,
        job_title: str,
        department: str,
        school_name: str,
        employee_id: str,
        from_stage: str,
        to_stage: str,
        notes: Optional[str] = None,
        expected_joining_date: Optional[str] = None
    ) -> bool:
        """Send notification to candidate when their onboarding pipeline stage is advanced."""
        subject = f"🚀 Onboarding Update: Moved to '{to_stage}' - {candidate_name} ({employee_id})"

        notes_html = ""
        if notes and notes.strip():
            notes_html = f"""
            <div style="margin: 18px 0; background-color: #F8FAFC; border-left: 4px solid #4F46E5; border-radius: 6px; padding: 14px 16px;">
              <p style="margin: 0 0 4px 0; font-weight: 700; font-size: 12.5px; color: #1E293B;">Stage Notes:</p>
              <p style="margin: 0; font-size: 13px; color: #475569; line-height: 1.5;">{notes.strip()}</p>
            </div>
            """

        html_content = f"""<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F1F5F9; padding: 32px 16px;">
    <tr>
      <td align="center">
        <table width="100%" cellpadding="0" cellspacing="0" style="max-width: 620px; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 10px 30px rgba(0,0,0,0.07); border: 1px solid #E2E8F0;">
          <tr>
            <td style="background: linear-gradient(135deg, #0F172A 0%, #1E1B4B 50%, #312E81 100%); padding: 36px 32px; text-align: center;">
              <span style="display:inline-block;background:rgba(255,255,255,0.12);color:#E0E7FF;padding:6px 16px;border-radius:20px;font-size:11px;font-weight:700;letter-spacing:1px;text-transform:uppercase;margin-bottom:12px;">
                ✦ ONBOARDING STAGE PROGRESSION ✦
              </span>
              <h1 style="margin: 10px 0 4px 0; color: #FFFFFF; font-size: 24px; font-weight: 700;">{school_name}</h1>
              <p style="margin: 0; color: #C7D2FE; font-size: 14px;">Office of Human Resources &amp; Talent Operations</p>
            </td>
          </tr>
          <tr>
            <td style="padding: 32px 32px 24px 32px;">
              <p style="margin: 0 0 16px 0; font-size: 15px; font-weight: 600; color: #0F172A;">Dear {candidate_name},</p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #334155; line-height: 1.65;">
                We are pleased to inform you that your onboarding process for the role of <strong>{job_title}</strong> has advanced to the next stage:
              </p>

              <!-- Stage Transition Card -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #EEF2FF; border: 1.5px solid #C7D2FE; border-radius: 12px; padding: 18px 20px; margin: 20px 0; text-align: center;">
                <tr>
                  <td>
                    <span style="font-size: 12px; color: #64748B; font-weight: 600; text-transform: uppercase;">Previous Stage</span>
                    <div style="font-size: 14px; color: #475569; font-weight: 600; margin-top: 2px;">{from_stage}</div>
                  </td>
                  <td width="40" style="font-size: 20px; color: #4F46E5;">➔</td>
                  <td>
                    <span style="font-size: 12px; color: #4338CA; font-weight: 700; text-transform: uppercase;">New Stage</span>
                    <div style="font-size: 16px; color: #312E81; font-weight: 800; margin-top: 2px;">{to_stage}</div>
                  </td>
                </tr>
              </table>

              {notes_html}

              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 14px 18px; margin: 16px 0;">
                <tr>
                  <td style="padding: 5px 0; font-size: 12.5px; color: #64748B; font-weight: 600; width: 40%;">Employee ID:</td>
                  <td style="padding: 5px 0; font-size: 13px; color: #0F172A; font-weight: 700;">{employee_id}</td>
                </tr>
                <tr>
                  <td style="padding: 5px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Department:</td>
                  <td style="padding: 5px 0; font-size: 13px; color: #0F172A; font-weight: 700;">{department}</td>
                </tr>
                <tr>
                  <td style="padding: 5px 0; font-size: 12.5px; color: #64748B; font-weight: 600;">Expected Joining Date:</td>
                  <td style="padding: 5px 0; font-size: 13px; color: #0F172A; font-weight: 700;">{expected_joining_date or 'As Scheduled'}</td>
                </tr>
              </table>

              <div style="margin-top: 26px; padding-top: 18px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Sincerely,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Human Resources Team</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px 32px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">&copy; 2026 {school_name} • EduSHAMIIT Enterprise Onboarding</p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content)

    def send_policy_acknowledgement_reminder_email(
        self,
        to_email: str,
        employee_name: str,
        policy_title: str,
        version_number: str = "1.0",
        category_name: str = "HR & Institutional",
        deadline: Optional[str] = None,
        is_mandatory: bool = True,
        reminder_count: int = 1,
        school_name: str = "EduSHAMIIT International School",
        custom_message: Optional[str] = None,
        portal_url: Optional[str] = None
    ) -> bool:
        """
        Send an executive, high-visibility policy acknowledgement reminder email
        to an employee for pending digital sign-off.
        """
        subject = f"Action Required: Reminder #{reminder_count} - Sign-off on {policy_title} (v{version_number})"
        portal_link = portal_url or "http://localhost:51780/admin/hr/policies"

        deadline_badge = f'<span style="background-color: #FEF2F2; color: #DC2626; border: 1px solid #FCA5A5; font-size: 12px; font-weight: 700; padding: 3px 8px; border-radius: 6px;">{deadline}</span>' if deadline else '<span style="color: #64748B; font-size: 12.5px;">Immediate Action Required</span>'
        priority_badge = '<span style="background-color: #EF4444; color: #FFFFFF; font-size: 11px; font-weight: 800; padding: 2px 8px; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.5px;">Mandatory</span>' if is_mandatory else '<span style="background-color: #3B82F6; color: #FFFFFF; font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 4px; text-transform: uppercase;">Standard</span>'

        custom_note_html = ""
        if custom_message and custom_message.strip():
            custom_note_html = f"""
            <div style="background-color: #EFF6FF; border-left: 4px solid #3B82F6; border-radius: 6px; padding: 12px 16px; margin: 16px 0;">
              <div style="font-size: 12px; font-weight: 700; color: #1E40AF; text-transform: uppercase; margin-bottom: 4px;">Note from HR Administration</div>
              <div style="font-size: 13.5px; color: #1E3A8A; line-height: 1.5;">{custom_message.strip()}</div>
            </div>
            """

        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 32px 12px;">
    <tr>
      <td align="center">
        <table width="600" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background-color: #FFFFFF; border-radius: 14px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06); border: 1px solid #E2E8F0;">
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #312E81 0%, #4338CA 50%, #6366F1 100%); padding: 32px 36px; text-align: left;">
              <div style="font-size: 12px; font-weight: 700; letter-spacing: 1px; color: #C7D2FE; text-transform: uppercase; margin-bottom: 6px;">{school_name} • HR Compliance</div>
              <h1 style="margin: 0; font-size: 22px; font-weight: 800; color: #FFFFFF; letter-spacing: -0.3px; line-height: 1.3;">
                Action Required: Policy Sign-off Reminder #{reminder_count}
              </h1>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 32px 36px;">
              <p style="margin: 0 0 16px 0; font-size: 15px; color: #1E293B; line-height: 1.6;">
                Dear <strong>{employee_name}</strong>,
              </p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #475569; line-height: 1.6;">
                Our records indicate that you have a pending policy acknowledgement that requires your digital review and sign-off. Please take a moment to review the policy details below and submit your formal acknowledgement.
              </p>

              {custom_note_html}

              <!-- Policy Summary Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600; width: 38%;">Policy Document:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 800;">{policy_title}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Document Version:</td>
                  <td style="padding: 6px 0; font-size: 13px; color: #1E293B; font-weight: 700;">Version {version_number}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Category:</td>
                  <td style="padding: 6px 0; font-size: 13px; color: #1E293B; font-weight: 600;">{category_name}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Sign-off Requirement:</td>
                  <td style="padding: 6px 0;">{priority_badge}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Sign-off Deadline:</td>
                  <td style="padding: 6px 0;">{deadline_badge}</td>
                </tr>
              </table>

              <!-- Steps -->
              <div style="background-color: #F1F5F9; border-radius: 8px; padding: 14px 18px; margin: 20px 0;">
                <div style="font-size: 12.5px; font-weight: 700; color: #334155; margin-bottom: 8px;">How to complete your sign-off:</div>
                <ol style="margin: 0; padding-left: 20px; font-size: 13px; color: #475569; line-height: 1.6;">
                  <li>Log in to the <strong>EduSHAMIIT Portal</strong> with your staff credentials.</li>
                  <li>Go to <strong>Organization &gt; HR Management &gt; Policies &amp; Documents</strong>.</li>
                  <li>Click on <strong>My Acknowledgements</strong> or locate the pending document.</li>
                  <li>Review the policy text and click <strong>Sign Off</strong> to record your digital signature.</li>
                </ol>
              </div>

              <!-- CTA Button -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 28px 0 24px 0; text-align: center;">
                <tr>
                  <td align="center">
                    <a href="{portal_link}" target="_blank" style="display: inline-block; background-color: #4F46E5; color: #FFFFFF; font-size: 14px; font-weight: 700; text-decoration: none; padding: 13px 32px; border-radius: 8px; box-shadow: 0 2px 8px rgba(79, 70, 229, 0.35);">
                      Review &amp; Sign Off in Portal &rarr;
                    </a>
                  </td>
                </tr>
              </table>

              <div style="margin-top: 28px; padding-top: 20px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Sincerely,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Human Resources &amp; Governance Team</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px 36px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">
                &copy; 2026 {school_name} • EduSHAMIIT Enterprise ERP Compliance Engine
              </p>
              <p style="margin: 4px 0 0 0; font-size: 11px; color: #CBD5E1;">
                This automated compliance reminder was generated securely by EduSHAMIIT HR Management.
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content)

    def send_policy_acknowledgement_request_email(
        self,
        to_email: str,
        employee_name: str,
        policy_title: str,
        version_number: str = "1.0",
        category_name: str = "HR & Institutional",
        deadline: Optional[str] = None,
        is_mandatory: bool = True,
        school_name: str = "EduSHAMIIT International School",
        custom_message: Optional[str] = None,
        portal_url: Optional[str] = None
    ) -> bool:
        """
        Send initial policy acknowledgement request email when HR dispatches
        a new policy or version requirement to employees.
        """
        subject = f"Action Required: Digital Sign-off Requested for {policy_title} (v{version_number})"
        portal_link = portal_url or "http://localhost:51780/admin/hr/policies"

        deadline_badge = f'<span style="background-color: #FEF2F2; color: #DC2626; border: 1px solid #FCA5A5; font-size: 12px; font-weight: 700; padding: 3px 8px; border-radius: 6px;">{deadline}</span>' if deadline else '<span style="color: #64748B; font-size: 12.5px;">Standard Review Period</span>'
        priority_badge = '<span style="background-color: #EF4444; color: #FFFFFF; font-size: 11px; font-weight: 800; padding: 2px 8px; border-radius: 4px; text-transform: uppercase; letter-spacing: 0.5px;">Mandatory</span>' if is_mandatory else '<span style="background-color: #3B82F6; color: #FFFFFF; font-size: 11px; font-weight: 700; padding: 2px 8px; border-radius: 4px; text-transform: uppercase;">Standard</span>'

        custom_note_html = ""
        if custom_message and custom_message.strip():
            custom_note_html = f"""
            <div style="background-color: #EFF6FF; border-left: 4px solid #3B82F6; border-radius: 6px; padding: 12px 16px; margin: 16px 0;">
              <div style="font-size: 12px; font-weight: 700; color: #1E40AF; text-transform: uppercase; margin-bottom: 4px;">Message from HR Administration</div>
              <div style="font-size: 13.5px; color: #1E3A8A; line-height: 1.5;">{custom_message.strip()}</div>
            </div>
            """

        html_content = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{subject}</title>
</head>
<body style="margin: 0; padding: 0; background-color: #F1F5F9; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; -webkit-font-smoothing: antialiased;">
  <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F1F5F9; padding: 32px 12px;">
    <tr>
      <td align="center">
        <table width="600" border="0" cellspacing="0" cellpadding="0" style="max-width: 600px; width: 100%; background-color: #FFFFFF; border-radius: 14px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06); border: 1px solid #E2E8F0;">
          <!-- Header Banner -->
          <tr>
            <td style="background: linear-gradient(135deg, #1E1B4B 0%, #312E81 50%, #4F46E5 100%); padding: 32px 36px; text-align: left;">
              <div style="font-size: 12px; font-weight: 700; letter-spacing: 1px; color: #C7D2FE; text-transform: uppercase; margin-bottom: 6px;">{school_name} • HR Governance</div>
              <h1 style="margin: 0; font-size: 22px; font-weight: 800; color: #FFFFFF; letter-spacing: -0.3px; line-height: 1.3;">
                New Institutional Policy Sign-off Request
              </h1>
            </td>
          </tr>

          <!-- Main Content -->
          <tr>
            <td style="padding: 32px 36px;">
              <p style="margin: 0 0 16px 0; font-size: 15px; color: #1E293B; line-height: 1.6;">
                Dear <strong>{employee_name}</strong>,
              </p>
              <p style="margin: 0 0 20px 0; font-size: 14px; color: #475569; line-height: 1.6;">
                A new institutional policy document has been published and assigned to you for mandatory digital sign-off. Please review the updated terms and guidelines in the EduSHAMIIT portal.
              </p>

              {custom_note_html}

              <!-- Policy Summary Box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600; width: 38%;">Policy Document:</td>
                  <td style="padding: 6px 0; font-size: 13.5px; color: #0F172A; font-weight: 800;">{policy_title}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Document Version:</td>
                  <td style="padding: 6px 0; font-size: 13px; color: #1E293B; font-weight: 700;">Version {version_number}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Category:</td>
                  <td style="padding: 6px 0; font-size: 13px; color: #1E293B; font-weight: 600;">{category_name}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Sign-off Requirement:</td>
                  <td style="padding: 6px 0;">{priority_badge}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; font-size: 13px; color: #64748B; font-weight: 600;">Sign-off Deadline:</td>
                  <td style="padding: 6px 0;">{deadline_badge}</td>
                </tr>
              </table>

              <!-- CTA Button -->
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="margin: 28px 0 24px 0; text-align: center;">
                <tr>
                  <td align="center">
                    <a href="{portal_link}" target="_blank" style="display: inline-block; background-color: #4F46E5; color: #FFFFFF; font-size: 14px; font-weight: 700; text-decoration: none; padding: 13px 32px; border-radius: 8px; box-shadow: 0 2px 8px rgba(79, 70, 229, 0.35);">
                      Review &amp; Sign Off Policy &rarr;
                    </a>
                  </td>
                </tr>
              </table>

              <div style="margin-top: 28px; padding-top: 20px; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; font-size: 14px; color: #334155;">Sincerely,</p>
                <p style="margin: 4px 0 0 0; font-size: 15px; font-weight: 700; color: #0F172A;">Human Resources &amp; Governance Team</p>
                <p style="margin: 2px 0 0 0; font-size: 13px; color: #64748B;">{school_name}</p>
              </div>
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="background-color: #F8FAFC; border-top: 1px solid #E2E8F0; padding: 18px 36px; text-align: center;">
              <p style="margin: 0; font-size: 12px; color: #94A3B8;">
                &copy; 2026 {school_name} • EduSHAMIIT Enterprise ERP Compliance Engine
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>"""
        return self._send_email(to_email, subject, html_content)



_email_service: Optional[EmailService] = None


def get_email_service() -> EmailService:
    """Get email service singleton."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service

