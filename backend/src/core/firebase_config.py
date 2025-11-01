# FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\core\firebase_config.py

import firebase_admin
from firebase_admin import credentials
import os
from pathlib import Path

# Define the path to your key file
# Gets the path to the root directory (turf-mgmt-sys\backend\src\)
BASE_DIR = Path(__file__).resolve().parent.parent

# Path to the downloaded JSON key file (CORRECTED PATH)
FIREBASE_CREDENTIAL_PATH = os.path.join(
    BASE_DIR, 
    'core', 
    'firebase', # <-- ADDED THE 'firebase' FOLDER
    # Use the EXACT filename from your file explorer:
    # 'turf-management-system-2eb8f-firebase-adminsdk-fbsvc-key.json' 
    'turf-management-system-2eb8f-firebase-adminsdk-fbsvc-3b93b699c7 (1).json'
) 

# Initialize the Firebase Admin SDK
try:
    cred = credentials.Certificate(FIREBASE_CREDENTIAL_PATH)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin SDK initialized successfully.")
except Exception as e:
    # This error should now be fixed!
    print(f"Error initializing Firebase Admin SDK: {e}")