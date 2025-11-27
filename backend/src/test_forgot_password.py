#!/usr/bin/env python3
"""
Test script for Forgot Password API endpoints
"""

import requests
import json
import time

BASE_URL = "http://127.0.0.1:8000/api/forgot-password"
TEST_EMAIL = "karan@iitrpr.ac.in"

def test_request_otp():
    """Test requesting an OTP"""
    url = f"{BASE_URL}/request-otp/"
    data = {"email": TEST_EMAIL}
    
    print(f"🔄 Testing Request OTP for: {TEST_EMAIL}")
    response = requests.post(url, json=data)
    
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        print("✅ OTP Request - SUCCESS")
        return True
    else:
        print("❌ OTP Request - FAILED")
        return False

def test_verify_otp(otp):
    """Test verifying an OTP"""
    url = f"{BASE_URL}/verify-otp/"
    data = {"email": TEST_EMAIL, "otp": otp}
    
    print(f"\n🔄 Testing Verify OTP: {otp}")
    response = requests.post(url, json=data)
    
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        print("✅ OTP Verification - SUCCESS")
        return True
    else:
        print("❌ OTP Verification - FAILED")
        return False

def test_reset_password():
    """Test resetting password"""
    url = f"{BASE_URL}/reset-password/"
    data = {
        "email": TEST_EMAIL,
        "new_password": "NewTestPassword123!",
        "confirm_password": "NewTestPassword123!"
    }
    
    print(f"\n🔄 Testing Password Reset")
    response = requests.post(url, json=data)
    
    print(f"Status: {response.status_code}")
    print(f"Response: {response.json()}")
    
    if response.status_code == 200:
        print("✅ Password Reset - SUCCESS")
        return True
    else:
        print("❌ Password Reset - FAILED")
        return False

def main():
    print("🚀 Starting Forgot Password API Test\n")
    
    # Step 1: Request OTP
    if not test_request_otp():
        return
    
    # Step 2: Get OTP from user (since we can't read email in test)
    print(f"\n📧 Please check the email sent to {TEST_EMAIL}")
    otp = input("Enter the OTP received: ").strip()
    
    if not otp:
        print("❌ No OTP provided, exiting...")
        return
    
    # Step 3: Verify OTP
    if not test_verify_otp(otp):
        return
    
    # Step 4: Reset Password
    if not test_reset_password():
        return
    
    print("\n🎉 All tests completed successfully!")
    print("✅ Forgot Password flow is working correctly")

if __name__ == "__main__":
    try:
        main()
    except requests.exceptions.ConnectionError:
        print("❌ Connection Error: Make sure Django server is running on http://127.0.0.1:8000")
    except KeyboardInterrupt:
        print("\n⏹️ Test interrupted by user")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")