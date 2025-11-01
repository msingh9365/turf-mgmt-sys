# FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\core\celery.py

import os
from celery import Celery

# Set the default Django settings module
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'core.settings.base') # Use your base settings path

# Create Celery application instance named 'app'
app = Celery('turf-mgmt-sys') 

# Load configuration from Django settings, using a prefix (CELERY_)
app.config_from_object('django.conf:settings', namespace='CELERY')

# Discover tasks from all installed Django apps
app.autodiscover_tasks()

# NOTE: The name 'app' is mandatory for the import in __init__.py to work.