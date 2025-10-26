import firebase_admin
from firebase_admin import credentials
import os
from pathlib import Path

# Define the path to your key file
# Gets the path to the root directory (turf-mgmt-sys)
BASE_DIR = Path(__file__).resolve().parent.parent

# Path to the downloaded JSON key file
FIREBASE_CREDENTIAL_PATH = os.path.join(BASE_DIR, 'config', 'turf-mgmt-sys-firebase-adminsdk-xxxxx.json')

# Initialize the Firebase Admin SDK
try:
    cred = credentials.Certificate(FIREBASE_CREDENTIAL_PATH)
    firebase_admin.initialize_app(cred)
    print("Firebase Admin SDK initialized successfully.")
except Exception as e:
    print(f"Error initializing Firebase Admin SDK: {e}")