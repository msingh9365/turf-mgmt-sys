import os
from pathlib import Path
import sys

BASE_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, os.path.join(BASE_DIR, 'backend'))

# Application definition
INSTALLED_APPS = [
    'django.contrib.admin',
    'django.contrib.auth',
    'django.contrib.contenttypes',
    'django.contrib.sessions',
    'django.contrib.messages',
    'django.contrib.staticfiles',


    'rest_framework',  
    # My Project Apps
    'core_app',      
]


# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.mysql',  
        'NAME': 'endgame_db', 
        'USER': 'root',        
        'PASSWORD': '#karan.sql09', 
        'HOST': '127.0.0.1', 
        'PORT': '3306', 
    }
}
