INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',

    # Third-party apps
    'rest_framework',  # ⬅️ Required for your API to work
    
    # My Project Apps
    'core_app',        # ⬅️ ADD THIS LINE to fix the error!
]