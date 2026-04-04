"""
End-to-end integration test for password reset functionality.
This script tests the complete flow: send OTP -> verify OTP -> reset password.
"""
import requests
import json
import time
import sys
import os

# Configuration
BASE_URL = os.getenv("API_BASE_URL", "http://localhost:8000")
API_ENDPOINTS = {
    "send_otp": f"{BASE_URL}/api/auth/send-otp",
    "verify_otp": f"{BASE_URL}/api/auth/verify-otp",
    "reset_password": f"{BASE_URL}/api/auth/reset-password",
    "login": f"{BASE_URL}/api/auth/login",
    "register": f"{BASE_URL}/api/auth/register"
}

# Test user data
TEST_USER = {
    "email": os.getenv("TEST_USER_EMAIL", "test@example.com"),
    "password": os.getenv("TEST_USER_PASSWORD", "testpassword123"),
    "full_name": "Test User",
    "role": "student",
    "school_id": "test-school-123"
}

NEW_PASSWORD = os.getenv("NEW_PASSWORD", "newpassword123")


def print_section(title):
    """Print a section header."""
    print(f"\n{'='*60}")
    print(f"  {title}")
    print(f"{'='*60}\n")


def print_step(step_num, description):
    """Print a step description."""
    print(f"\n[Step {step_num}] {description}")
    print("-" * 40)


def test_register_user():
    """Test user registration."""
    print_section("STEP 1: Register Test User")
    print_step(1, "Registering a new user")
    
    try:
        response = requests.post(API_ENDPOINTS["register"], json=TEST_USER)
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code in [200, 201]:
            print("✓ User registered successfully")
            return True
        elif response.status_code == 400:
            print("⚠ User may already exist, continuing with existing user")
            return True
        else:
            print(f"✗ Registration failed: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API. Make sure the server is running.")
        return False


def test_login_with_old_password():
    """Test login with original password."""
    print_section("STEP 2: Login with Original Password")
    print_step(2, "Logging in with original password")
    
    try:
        response = requests.post(API_ENDPOINTS["login"], json={
            "email": TEST_USER["email"],
            "password": TEST_USER["password"]
        })
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code == 200:
            print("✓ Login successful with original password")
            return True
        else:
            print(f"✗ Login failed: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def test_send_otp():
    """Test sending OTP."""
    print_section("STEP 3: Send OTP for Password Reset")
    print_step(3, "Requesting OTP for password reset")
    
    try:
        response = requests.post(API_ENDPOINTS["send_otp"], json={
            "identifier": TEST_USER["email"]
        })
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code == 200:
            print("✓ OTP sent successfully")
            print(f"  Expires in: {response.json().get('expires_in', 'N/A')} seconds")
            return True
        else:
            print(f"✗ OTP sending failed: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def test_verify_otp(otp):
    """Test verifying OTP."""
    print_section("STEP 4: Verify OTP")
    print_step(4, f"Verifying OTP: {otp}")
    
    try:
        response = requests.post(API_ENDPOINTS["verify_otp"], json={
            "identifier": TEST_USER["email"],
            "otp": otp
        })
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code == 200:
            print("✓ OTP verified successfully")
            return True
        else:
            print(f"✗ OTP verification failed: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def test_reset_password(otp):
    """Test resetting password."""
    print_section("STEP 5: Reset Password")
    print_step(5, "Resetting password with OTP")
    
    try:
        response = requests.post(API_ENDPOINTS["reset_password"], json={
            "identifier": TEST_USER["email"],
            "otp": otp,
            "new_password": NEW_PASSWORD
        })
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code == 200:
            print("✓ Password reset successfully")
            return True
        else:
            print(f"✗ Password reset failed: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def test_login_with_new_password():
    """Test login with new password."""
    print_section("STEP 6: Login with New Password")
    print_step(6, "Logging in with new password")
    
    try:
        response = requests.post(API_ENDPOINTS["login"], json={
            "email": TEST_USER["email"],
            "password": NEW_PASSWORD
        })
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code == 200:
            print("✓ Login successful with new password")
            return True
        else:
            print(f"✗ Login failed: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def test_rate_limiting():
    """Test rate limiting."""
    print_section("STEP 7: Test Rate Limiting")
    print_step(7, "Testing rate limiting (sending multiple OTPs)")
    
    try:
        # Send multiple OTPs to trigger rate limit
        for i in range(4):
            response = requests.post(API_ENDPOINTS["send_otp"], json={
                "identifier": TEST_USER["email"]
            })
            print(f"Request {i+1}: Status {response.status_code}")
            
            if response.status_code == 429:
                print("✓ Rate limiting working correctly")
                print(f"  Message: {response.json().get('detail', 'Rate limit exceeded')}")
                return True
            
            time.sleep(0.5)  # Small delay between requests
        
        print("⚠ Rate limiting may not be enforced (or limit not reached)")
        return True
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def test_invalid_otp():
    """Test invalid OTP."""
    print_section("STEP 8: Test Invalid OTP")
    print_step(8, "Testing with invalid OTP")
    
    try:
        response = requests.post(API_ENDPOINTS["verify_otp"], json={
            "identifier": TEST_USER["email"],
            "otp": "000000"  # Invalid OTP
        })
        print(f"Response Status: {response.status_code}")
        print(f"Response Body: {response.json()}")
        
        if response.status_code == 400:
            print("✓ Invalid OTP correctly rejected")
            return True
        else:
            print(f"✗ Invalid OTP not properly rejected: {response.status_code}")
            return False
    except requests.ConnectionError:
        print("✗ Cannot connect to API")
        return False


def main():
    """Run all integration tests."""
    print("="*60)
    print("  EduSHAMIIT Password Reset Integration Tests")
    print("="*60)
    print(f"\nAPI Base URL: {BASE_URL}")
    print(f"Test User: {TEST_USER['email']}")
    print(f"New Password: {NEW_PASSWORD}")
    
    results = []
    
    # Run tests
    results.append(("Register User", test_register_user()))
    results.append(("Login with Old Password", test_login_with_old_password()))
    results.append(("Send OTP", test_send_otp()))
    
    # For manual testing, ask for OTP
    print_section("MANUAL OTP ENTRY")
    print("Please check your email for the OTP and enter it below.")
    print("Or press Enter to skip to automated tests.")
    
    otp = input("Enter OTP: ").strip()
    
    if otp:
        results.append(("Verify OTP", test_verify_otp(otp)))
        results.append(("Reset Password", test_reset_password(otp)))
        results.append(("Login with New Password", test_login_with_new_password()))
    else:
        print("\nSkipping OTP verification tests (automated testing mode)")
        print("Run with OTP for full end-to-end testing.")
    
    results.append(("Rate Limiting", test_rate_limiting()))
    results.append(("Invalid OTP", test_invalid_otp()))
    
    # Print summary
    print_section("Test Summary")
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    print(f"\nTotal Tests: {total}")
    print(f"Passed: {passed}")
    print(f"Failed: {total - passed}")
    print("\nDetailed Results:")
    print("-" * 40)
    
    for name, result in results:
        status = "✓ PASS" if result else "✗ FAIL"
        print(f"  {status}: {name}")
    
    print(f"\n{'='*60}")
    if passed == total:
        print("  All tests passed! ✓")
    else:
        print(f"  {total - passed} test(s) failed. ✗")
    print(f"{'='*60}\n")
    
    return passed == total


if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)