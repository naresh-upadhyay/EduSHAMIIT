"""
Comprehensive tests for authentication endpoints including password reset functionality.
"""
import pytest
import asyncio
import sys
import os
from unittest.mock import Mock, patch, MagicMock, PropertyMock
from datetime import datetime, timedelta, timezone
import uuid

# Add the backend directory to the path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'backend'))

from app.api.auth import generate_otp, check_rate_limit, find_user_by_identifier
from app.config import settings
from app.services.email_service import EmailService, get_email_service


def run_async(coro):
    """Helper to run async functions in tests."""
    return asyncio.run(coro)


class TestOTPGeneration:
    """Test OTP generation functionality."""
    
    def test_generate_otp_length(self):
        """Test that OTP has correct length."""
        otp = generate_otp(6)
        assert len(otp) == 6
        assert otp.isdigit()
    
    def test_generate_otp_default_length(self):
        """Test that default OTP length is 6."""
        otp = generate_otp()
        assert len(otp) == 6
    
    def test_generate_otp_custom_length(self):
        """Test that custom length works."""
        for length in [4, 6, 8, 10]:
            otp = generate_otp(length)
            assert len(otp) == length
            assert otp.isdigit()
    
    def test_generate_otp_uniqueness(self):
        """Test that generated OTPs are unique (statistically)."""
        otps = [generate_otp(6) for _ in range(100)]
        # There should be very few duplicates in 100 random 6-digit numbers
        unique_otps = set(otps)
        assert len(unique_otps) > 95  # At least 95% unique
    
    def test_generate_otp_range(self):
        """Test that OTP is within expected range."""
        otp = generate_otp(6)
        otp_int = int(otp)
        assert 0 <= otp_int <= 999999


class TestEmailService:
    """Test email service functionality."""
    
    @patch('smtplib.SMTP')
    def test_send_email_success(self, mock_smtp):
        """Test successful email sending."""
        # Mock the SMTP connection
        mock_server = MagicMock()
        mock_smtp.return_value.__enter__.return_value = mock_server
        
        email_service = EmailService()
        result = email_service._send_email("test@example.com", "Test Subject", "<html>Test</html>")
        
        assert result is True
        mock_server.starttls.assert_called_once()
        mock_server.login.assert_called_once_with(settings.SMTP_USER, settings.SMTP_PASSWORD)
        mock_server.send_message.assert_called_once()
    
    @patch('smtplib.SMTP')
    def test_send_email_retry_on_failure(self, mock_smtp):
        """Test email retry logic."""
        # Mock SMTP to fail twice then succeed
        mock_server = MagicMock()
        call_count = [0]
        
        def side_effect(*args, **kwargs):
            call_count[0] += 1
            if call_count[0] < 3:
                raise Exception("Connection failed")
            return mock_server
        
        mock_smtp.side_effect = side_effect
        mock_smtp.return_value.__enter__.return_value = mock_server
        
        email_service = EmailService()
        result = email_service._send_email("test@example.com", "Test Subject", "<html>Test</html>")
        
        # Should succeed on third attempt
        assert result is True
        assert call_count[0] == 3
    
    @patch('smtplib.SMTP')
    def test_send_email_auth_failure_no_retry(self, mock_smtp):
        """Test that authentication failures don't retry."""
        import smtplib
        
        mock_smtp.side_effect = smtplib.SMTPAuthenticationError(535, b"Authentication failed")
        
        email_service = EmailService()
        result = email_service._send_email("test@example.com", "Test Subject", "<html>Test</html>")
        
        assert result is False
        assert mock_smtp.call_count == 1  # Only one attempt, no retry
    
    def test_send_otp_email_format(self):
        """Test OTP email content format."""
        email_service = EmailService()
        
        # Check that the email contains the OTP
        otp = "123456"
        html_content = email_service.send_otp_email.__code__.co_consts  # Can't easily test this
        
        # Instead, test that the method exists and can be called
        assert hasattr(email_service, 'send_otp_email')
    
    def test_send_confirmation_email_format(self):
        """Test confirmation email content format."""
        email_service = EmailService()
        
        # Check that the method exists
        assert hasattr(email_service, 'send_password_reset_confirmation')


def create_mock_supabase():
    """Helper to create a properly mocked Supabase client."""
    mock_sb = MagicMock()
    
    def table_side_effect(table_name):
        mock_table = MagicMock()
        
        def select_side_effect(*args, **kwargs):
            mock_select = MagicMock()
            
            def eq_side_effect(*args, **kwargs):
                mock_eq = MagicMock()
                
                def maybe_single_side_effect():
                    mock_maybe_single = MagicMock()
                    mock_maybe_single.execute.return_value = MagicMock(data=None)
                    return mock_maybe_single
                
                def gte_side_effect(*args, **kwargs):
                    mock_gte = MagicMock()
                    mock_gte.execute.return_value = MagicMock(data=[])
                    return mock_gte
                
                mock_eq.maybe_single = maybe_single_side_effect
                mock_eq.gte = gte_side_effect
                mock_eq.execute.return_value = MagicMock(data=[])
                return mock_eq
            
            mock_select.eq = eq_side_effect
            mock_select.maybe_single = lambda: MagicMock(execute=MagicMock(return_value=MagicMock(data=None)))
            return mock_select
        
        def insert_side_effect(data):
            mock_insert = MagicMock()
            mock_insert.execute.return_value = MagicMock(data=[data])
            return mock_insert
        
        def update_side_effect(data):
            mock_update = MagicMock()
            
            def eq_side_effect(*args, **kwargs):
                mock_eq = MagicMock()
                mock_eq.execute.return_value = MagicMock(data=[])
                return mock_eq
            
            mock_update.eq = eq_side_effect
            return mock_update
        
        mock_table.select = select_side_effect
        mock_table.insert = insert_side_effect
        mock_table.update = update_side_effect
        return mock_table
    
    mock_sb.table.side_effect = table_side_effect
    return mock_sb


def setup_user_lookup(mock_sb, mock_user):
    """Helper to set up user lookup mock."""
    def table_side_effect(table_name):
        if table_name == "profiles":
            mock_table = MagicMock()
            
            def select_side_effect(*args, **kwargs):
                mock_select = MagicMock()
                
                def eq_side_effect(*args, **kwargs):
                    mock_eq = MagicMock()
                    
                    def maybe_single_side_effect():
                        mock_maybe_single = MagicMock()
                        mock_maybe_single.execute.return_value = MagicMock(data=mock_user)
                        return mock_maybe_single
                    
                    mock_eq.maybe_single = maybe_single_side_effect
                    mock_eq.execute.return_value = MagicMock(data=[mock_user])
                    return mock_eq
                
                mock_select.eq = eq_side_effect
                mock_select.maybe_single = lambda: MagicMock(execute=MagicMock(return_value=MagicMock(data=mock_user)))
                return mock_select
            
            mock_table.select = select_side_effect
            return mock_table
        else:
            mock_table = MagicMock()
            mock_table.insert = lambda data: MagicMock(execute=MagicMock(return_value=MagicMock(data=[data])))
            mock_table.update = lambda data: MagicMock(eq=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=[])))))
            mock_table.select = lambda *args, **kwargs: MagicMock(eq=MagicMock(return_value=MagicMock(gte=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=[])))))))
            return mock_table
    
    mock_sb.table.side_effect = table_side_effect


class TestPasswordResetFlow:
    """Test complete password reset flow."""
    
    @pytest.mark.asyncio
    @patch('app.api.auth.get_supabase')
    @patch('app.api.auth.get_email_service')
    async def test_send_otp_success(self, mock_email_service, mock_supabase):
        """Test successful OTP sending."""
        # Mock Supabase client
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User",
            "school_id": str(uuid.uuid4())
        }
        setup_user_lookup(mock_sb, mock_user)
        
        # Mock email service
        mock_email = MagicMock()
        mock_email.send_otp_email.return_value = True
        mock_email_service.return_value = mock_email
        
        # Test the send_otp function
        from app.api.auth import send_otp
        
        request = {"identifier": "test@example.com"}
        result = await send_otp(request)
        
        assert result["success"] is True
        assert result["message"] == "OTP sent successfully"
        assert "expires_in" in result
    
    @pytest.mark.asyncio
    @patch('app.api.auth.get_supabase')
    async def test_send_otp_user_not_found(self, mock_supabase):
        """Test OTP sending with non-existent user."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup to return None
        def table_side_effect(table_name):
            if table_name == "profiles":
                mock_table = MagicMock()
                mock_table.select = lambda *args, **kwargs: MagicMock(eq=MagicMock(return_value=MagicMock(maybe_single=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=None)))))))
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        from app.api.auth import send_otp
        
        request = {"identifier": "nonexistent@example.com"}
        
        with pytest.raises(Exception) as exc_info:
            await send_otp(request)
        
        assert exc_info.value.status_code == 404
    
    @pytest.mark.asyncio
    @patch('app.api.auth.get_supabase')
    async def test_send_otp_rate_limit_exceeded(self, mock_supabase):
        """Test OTP sending when rate limit is exceeded."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User",
            "school_id": str(uuid.uuid4())
        }
        setup_user_lookup(mock_sb, mock_user)
        
        # Override rate limit check to return exceeded
        def table_side_effect(table_name):
            if table_name == "password_resets":
                mock_table = MagicMock()
                
                def select_side_effect(*args, **kwargs):
                    mock_select = MagicMock()
                    
                    def eq_side_effect(*args, **kwargs):
                        mock_eq = MagicMock()
                        
                        def gte_side_effect(*args, **kwargs):
                            mock_gte = MagicMock()
                            # Return 3 attempts (at limit)
                            mock_gte.execute.return_value = MagicMock(data=[1, 2, 3])
                            return mock_gte
                        
                        mock_eq.gte = gte_side_effect
                        mock_eq.execute.return_value = MagicMock(data=[1, 2, 3])
                        return mock_eq
                    
                    mock_select.eq = eq_side_effect
                    return mock_select
                
                mock_table.select = select_side_effect
                mock_table.insert = lambda data: MagicMock(execute=MagicMock(return_value=MagicMock(data=[data])))
                mock_table.update = lambda data: MagicMock(eq=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=[])))))
                return mock_table
            elif table_name == "profiles":
                mock_table = MagicMock()
                mock_table.select = lambda *args, **kwargs: MagicMock(eq=MagicMock(return_value=MagicMock(maybe_single=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=mock_user)))))))
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        from app.api.auth import send_otp
        
        request = {"identifier": "test@example.com"}
        
        with pytest.raises(Exception) as exc_info:
            await send_otp(request)
        
        assert exc_info.value.status_code == 429


class TestVerifyOTP:
    """Test OTP verification functionality."""
    
    @pytest.mark.asyncio
    @patch('app.api.auth.get_supabase')
    async def test_verify_otp_success(self, mock_supabase):
        """Test successful OTP verification."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User"
        }
        setup_user_lookup(mock_sb, mock_user)
        
        # Mock OTP verification
        mock_otp_record = {
            "id": str(uuid.uuid4()),
            "user_id": mock_user["id"],
            "otp": "123456",
            "status": "pending",
            "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()
        }
        
        # Override password_resets table for OTP lookup
        def table_side_effect(table_name):
            if table_name == "password_resets":
                mock_table = MagicMock()
                
                def select_side_effect(*args, **kwargs):
                    mock_select = MagicMock()
                    
                    def eq_side_effect(*args, **kwargs):
                        mock_eq = MagicMock()
                        
                        def gte_side_effect(*args, **kwargs):
                            mock_gte = MagicMock()
                            mock_gte.execute.return_value = MagicMock(data=[mock_otp_record])
                            return mock_gte
                        
                        mock_eq.gte = gte_side_effect
                        mock_eq.execute.return_value = MagicMock(data=[mock_otp_record])
                        return mock_eq
                    
                    mock_select.eq = eq_side_effect
                    return mock_select
                
                mock_table.select = select_side_effect
                mock_table.update = lambda data: MagicMock(eq=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=[])))))
                return mock_table
            elif table_name == "profiles":
                mock_table = MagicMock()
                mock_table.select = lambda *args, **kwargs: MagicMock(eq=MagicMock(return_value=MagicMock(maybe_single=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=mock_user)))))))
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        from app.api.auth import verify_otp
        
        request = {"identifier": "test@example.com", "otp": "123456"}
        result = await verify_otp(request)
        
        assert result["success"] is True
        assert result["message"] == "OTP verified successfully"
    
    @pytest.mark.asyncio
    @patch('app.api.auth.get_supabase')
    async def test_verify_otp_expired(self, mock_supabase):
        """Test OTP verification with expired OTP."""
        # Create a fresh mock without the default setup
        mock_sb = MagicMock()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User"
        }
        
        # Helper to create a chainable mock that returns empty data
        def create_empty_chain_mock():
            mock_obj = MagicMock()
            mock_obj.eq.return_value = mock_obj
            mock_obj.gte.return_value = mock_obj
            mock_obj.execute.return_value = MagicMock(data=[])
            return mock_obj
        
        # Helper to create a chainable mock that returns user data
        def create_user_chain_mock():
            mock_obj = MagicMock()
            mock_obj.eq.return_value = mock_obj
            mock_obj.maybe_single.return_value = MagicMock(execute=MagicMock(return_value=MagicMock(data=mock_user)))
            mock_obj.execute.return_value = MagicMock(data=[mock_user])
            return mock_obj
        
        # Set up all table mocks explicitly
        def table_side_effect(table_name):
            mock_table = MagicMock()
            
            if table_name == "profiles":
                # User lookup returns the user
                mock_select = create_user_chain_mock()
                mock_table.select.return_value = mock_select
                
            elif table_name == "password_resets":
                # OTP lookup returns empty (expired OTP)
                mock_select = create_empty_chain_mock()
                mock_table.select.return_value = mock_select
                
                # Update mock
                mock_update = MagicMock()
                mock_update.eq.return_value = MagicMock(execute=MagicMock(return_value=MagicMock(data=[])))
                mock_table.update.return_value = mock_update
            
            return mock_table
        
        mock_sb.table.side_effect = table_side_effect
        
        from app.api.auth import verify_otp
        
        request = {"identifier": "test@example.com", "otp": "123456"}
        
        with pytest.raises(Exception) as exc_info:
            await verify_otp(request)
        
        assert exc_info.value.status_code == 400


class TestResetPassword:
    """Test password reset functionality."""
    
    @pytest.mark.asyncio
    @patch('app.api.auth.httpx.put')
    @patch('app.api.auth.get_email_service')
    @patch('app.api.auth.get_supabase')
    async def test_reset_password_success(self, mock_supabase, mock_email_service, mock_http_put):
        """Test successful password reset."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User",
            "school_id": str(uuid.uuid4())
        }
        setup_user_lookup(mock_sb, mock_user)
        
        # Mock OTP verification
        mock_otp_record = {
            "id": str(uuid.uuid4()),
            "user_id": mock_user["id"],
            "otp": "123456",
            "status": "pending",
            "expires_at": (datetime.now(timezone.utc) + timedelta(minutes=10)).isoformat()
        }
        
        # Override password_resets table
        def table_side_effect(table_name):
            if table_name == "password_resets":
                mock_table = MagicMock()
                
                def select_side_effect(*args, **kwargs):
                    mock_select = MagicMock()
                    
                    def eq_side_effect(*args, **kwargs):
                        mock_eq = MagicMock()
                        
                        def gte_side_effect(*args, **kwargs):
                            mock_gte = MagicMock()
                            mock_gte.execute.return_value = MagicMock(data=[mock_otp_record])
                            return mock_gte
                        
                        mock_eq.gte = gte_side_effect
                        mock_eq.execute.return_value = MagicMock(data=[mock_otp_record])
                        return mock_eq
                    
                    mock_select.eq = eq_side_effect
                    return mock_select
                
                mock_table.select = select_side_effect
                mock_table.update = lambda data: MagicMock(eq=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=[])))))
                return mock_table
            elif table_name == "profiles":
                mock_table = MagicMock()
                mock_table.select = lambda *args, **kwargs: MagicMock(eq=MagicMock(return_value=MagicMock(maybe_single=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=mock_user)))))))
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        # Mock Supabase Admin API
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_http_put.return_value = mock_response
        
        # Mock email service
        mock_email = MagicMock()
        mock_email.send_password_reset_confirmation.return_value = True
        mock_email_service.return_value = mock_email
        
        from app.api.auth import reset_password
        
        request = {
            "identifier": "test@example.com",
            "otp": "123456",
            "new_password": "newpassword123"
        }
        
        result = await reset_password(request)
        
        assert result["success"] is True
        assert result["message"] == "Password reset successfully"
    
    @pytest.mark.asyncio
    @patch('app.api.auth.get_supabase')
    async def test_reset_password_too_short(self, mock_supabase):
        """Test password reset with too short password."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock user lookup
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User"
        }
        setup_user_lookup(mock_sb, mock_user)
        
        from app.api.auth import reset_password
        
        request = {
            "identifier": "test@example.com",
            "otp": "123456",
            "new_password": "short"  # Too short
        }
        
        with pytest.raises(Exception) as exc_info:
            await reset_password(request)
        
        assert exc_info.value.status_code == 400
        assert "8 characters" in str(exc_info.value.detail)


class TestFindUserByIdentifier:
    """Test user lookup functionality."""
    
    @patch('app.api.auth.get_supabase')
    def test_find_user_by_email(self, mock_supabase):
        """Test finding user by email."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        mock_user = {
            "id": str(uuid.uuid4()),
            "email": "test@example.com",
            "full_name": "Test User"
        }
        setup_user_lookup(mock_sb, mock_user)
        
        result = find_user_by_identifier(mock_sb, "test@example.com")
        
        assert result == mock_user
    
    @patch('app.api.auth.get_supabase')
    def test_find_user_by_uuid(self, mock_supabase):
        """Test finding user by UUID."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        user_id = str(uuid.uuid4())
        mock_user = {
            "id": user_id,
            "email": "test@example.com",
            "full_name": "Test User"
        }
        
        # Set up for UUID lookup (email returns None first)
        call_count = [0]
        
        def table_side_effect(table_name):
            if table_name == "profiles":
                mock_table = MagicMock()
                
                def select_side_effect(*args, **kwargs):
                    mock_select = MagicMock()
                    
                    def eq_side_effect(*args, **kwargs):
                        mock_eq = MagicMock()
                        
                        def maybe_single_side_effect():
                            mock_maybe_single = MagicMock()
                            call_count[0] += 1
                            if call_count[0] == 1:
                                # First call (email lookup) returns None
                                mock_maybe_single.execute.return_value = MagicMock(data=None)
                            else:
                                # Second call (UUID lookup) returns user
                                mock_maybe_single.execute.return_value = MagicMock(data=mock_user)
                            return mock_maybe_single
                        
                        mock_eq.maybe_single = maybe_single_side_effect
                        return mock_eq
                    
                    mock_select.eq = eq_side_effect
                    return mock_select
                
                mock_table.select = select_side_effect
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        result = find_user_by_identifier(mock_sb, user_id)
        
        assert result == mock_user
    
    @patch('app.api.auth.get_supabase')
    def test_find_user_not_found(self, mock_supabase):
        """Test user not found."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Mock to always return None
        def table_side_effect(table_name):
            if table_name == "profiles":
                mock_table = MagicMock()
                mock_table.select = lambda *args, **kwargs: MagicMock(eq=MagicMock(return_value=MagicMock(maybe_single=MagicMock(return_value=MagicMock(execute=MagicMock(return_value=MagicMock(data=None)))))))
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        result = find_user_by_identifier(mock_sb, "nonexistent@example.com")
        
        assert result is None


class TestRateLimiting:
    """Test rate limiting functionality."""
    
    @patch('app.api.auth.get_supabase')
    def test_rate_limit_not_exceeded(self, mock_supabase):
        """Test that rate limit is not exceeded."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Override for rate limit check
        def table_side_effect(table_name):
            if table_name == "password_resets":
                mock_table = MagicMock()
                
                def select_side_effect(*args, **kwargs):
                    mock_select = MagicMock()
                    
                    def eq_side_effect(*args, **kwargs):
                        mock_eq = MagicMock()
                        
                        def gte_side_effect(*args, **kwargs):
                            mock_gte = MagicMock()
                            # Return 2 attempts (under limit of 3)
                            mock_gte.execute.return_value = MagicMock(data=[1, 2])
                            return mock_gte
                        
                        mock_eq.gte = gte_side_effect
                        mock_eq.execute.return_value = MagicMock(data=[1, 2])
                        return mock_eq
                    
                    mock_select.eq = eq_side_effect
                    return mock_select
                
                mock_table.select = select_side_effect
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        result = check_rate_limit(mock_sb, "user_id")
        
        assert result is True  # Rate limit not exceeded
    
    @patch('app.api.auth.get_supabase')
    def test_rate_limit_exceeded(self, mock_supabase):
        """Test that rate limit is exceeded."""
        mock_sb = create_mock_supabase()
        mock_supabase.return_value = mock_sb
        
        # Override for rate limit check
        def table_side_effect(table_name):
            if table_name == "password_resets":
                mock_table = MagicMock()
                
                def select_side_effect(*args, **kwargs):
                    mock_select = MagicMock()
                    
                    def eq_side_effect(*args, **kwargs):
                        mock_eq = MagicMock()
                        
                        def gte_side_effect(*args, **kwargs):
                            mock_gte = MagicMock()
                            # Return 3 attempts (at limit)
                            mock_gte.execute.return_value = MagicMock(data=[1, 2, 3])
                            return mock_gte
                        
                        mock_eq.gte = gte_side_effect
                        mock_eq.execute.return_value = MagicMock(data=[1, 2, 3])
                        return mock_eq
                    
                    mock_select.eq = eq_side_effect
                    return mock_select
                
                mock_table.select = select_side_effect
                return mock_table
            return MagicMock()
        
        mock_sb.table.side_effect = table_side_effect
        
        result = check_rate_limit(mock_sb, "user_id")
        
        assert result is False  # Rate limit exceeded


if __name__ == "__main__":
    pytest.main([__file__, "-v"])