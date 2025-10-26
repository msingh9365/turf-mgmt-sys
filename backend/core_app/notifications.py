from firebase_admin import messaging
from django.conf import settings # If you use settings later

def send_single_notification(registration_token, title, body, data_payload=None):
    """Sends a single push notification to a specified device."""

    # 

    # Build the message structure
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=data_payload,  
        token=registration_token,
    )

    try:
        # Send the message
        response = messaging.send(message)
        print(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        print(f"Error sending Firebase message: {e}")
        return False

def send_test_notification():
    # **REPLACE THIS WITH A REAL TOKEN FROM YOUR TEST DEVICE**
    # Santhana's frontend app must capture and send you a device token.
    TEST_TOKEN = "e2d8y-g_D4p5X3f... (a long string from a test phone)"

    send_single_notification(
        registration_token=TEST_TOKEN,
        title="Ground Ready!",
        body="Your slot is now open! Tap to confirm booking.",
        data_payload={'type': 'waitlist_promo', 'slot_id': '123'}
    )