from firebase_admin import messaging

def send_fcm_notification(fcm_token, title, body, payload=None):
    """
    Sends a push notification to a single device using FCM.

    Args:
        fcm_token (str): The FCM registration token of the target device.
        title (str): The title of the notification.
        body (str): The body of the notification.
        payload (dict, optional): A dictionary of data to be sent with the notification.
    """
    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        data=payload,
        token=fcm_token,
    )

    try:
        response = messaging.send(message)
        print(f"Successfully sent message: {response}")
        return True
    except Exception as e:
        print(f"Error sending FCM message: {e}")
        return False

def send_test_notification():
    # **REPLACE THIS WITH A REAL TOKEN FROM YOUR TEST DEVICE**
    # Santhana's frontend app must capture and send you a device token.
    TEST_TOKEN = "e2d8y-g_D4p5X3f... (a long string from a test phone)"

    send_fcm_notification(
        fcm_token=TEST_TOKEN,
        title="Ground Ready!",
        body="Your slot is now open! Tap to confirm booking.",
        payload={'type': 'waitlist_promo', 'slot_id': '123'}
    )
