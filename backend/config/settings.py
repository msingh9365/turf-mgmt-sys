import os
import sys
from pathlib import Path
from django.core.management.utils import get_random_secret_key

# 🧠 BASE_DIR points to the backend folder
BASE_DIR = Path(__file__).resolve().parent.parent

# ✅ Secret key (used for signing sessions, cookies, etc.)
SECRET_KEY = os.getenv("DJANGO_SECRET_KEY", get_random_secret_key())

# 🧩 Add backend folder to sys.path
if str(BASE_DIR) not in sys.path:
    sys.path.insert(0, str(BASE_DIR))

print("✅ SYS.PATH:", sys.path)  # (optional debug line, you can remove later)

# Static files (CSS, JavaScript, Images)
STATIC_URL = '/static/'

# Optional but good practice (for collected static files)
STATIC_ROOT = BASE_DIR / 'staticfiles'

# During development, Django will also look here for app-specific static files
STATICFILES_DIRS = [
    BASE_DIR / 'static',
]

ROOT_URLCONF = 'backend.config.urls'

# ✅ Development Settings
DEBUG = True
ALLOWED_HOSTS = ['*']  # allow all hosts during development

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
    'backend.core_app',
]

MIDDLEWARE = [
    'django.middleware.security.SecurityMiddleware',
    'django.contrib.sessions.middleware.SessionMiddleware',        # Required by admin
    'django.middleware.common.CommonMiddleware',
    'django.middleware.csrf.CsrfViewMiddleware',
    'django.contrib.auth.middleware.AuthenticationMiddleware',      # Required by admin
    'django.contrib.messages.middleware.MessageMiddleware',         # Required by admin
    'django.middleware.clickjacking.XFrameOptionsMiddleware',
]

TEMPLATES = [
    {
        'BACKEND': 'django.template.backends.django.DjangoTemplates',
        'DIRS': [],
        'APP_DIRS': True,
        'OPTIONS': {
            'context_processors': [
                'django.template.context_processors.debug',
                'django.template.context_processors.request',
                'django.contrib.auth.context_processors.auth',
                'django.contrib.messages.context_processors.messages',
            ],
        },
    },
]


# Database
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",  
        "NAME": "playground_db", 
        "USER": "root",        
        "PASSWORD": "root", 
        "HOST": "127.0.0.1", 
        "PORT": "3306", 
    }
}
