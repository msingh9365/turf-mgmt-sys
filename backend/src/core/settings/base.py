"""
Base Django settings for the playground backend.
- Loads environment variables using django-environ
- Configures DRF, JWT, CORS, and Supabase Postgres
- Uses custom user model `users.User`
This file is imported by environment-specific settings (dev/prod).
"""
from __future__ import annotations

from datetime import timedelta
from pathlib import Path

import environ

# Paths
BASE_DIR = Path(__file__).resolve().parent.parent.parent

# Environment
env = environ.Env(
    DEBUG=(bool, False),
    DJANGO_SECRET_KEY=(str, ""),
    ALLOWED_HOSTS=(list, ["localhost"]),
    DB_USE_SQLITE=(bool, False),
    DATABASE_URL=(str, ""),  # Supabase Postgres connection string
    ALLOWED_EMAIL_DOMAIN=(str, "@iitrpr.ac.in"),
    JWT_ACCESS_LIFETIME=(int, 15),
    JWT_REFRESH_LIFETIME=(int, 7),
    GOOGLE_CLIENT_ID_ANDROID=(str, "stub_android_id"),
    GOOGLE_CLIENT_ID_WEB=(str, "stub_web_id"),
    GOOGLE_CLIENT_SECRET_WEB=(str, "stub_web_secret"),
    GOOGLE_CALLBACK_URL=(str, "http://localhost:8000/accounts/google/login/callback/"),
    SUPABASE_URL=(str, ""),
    SUPABASE_KEY=(str, ""),
    SUPABASE_JWT_SECRET=(str, ""),
)

# Load .env if present at project root
ENV_FILE = BASE_DIR / ".env"
if ENV_FILE.exists():
    environ.Env.read_env(str(ENV_FILE))

DEBUG = env.bool("DEBUG")
SECRET_KEY = env("DJANGO_SECRET_KEY") or "unsafe-dev-key-change-me"
ALLOWED_HOSTS = env.list("ALLOWED_HOSTS")

# Applications
INSTALLED_APPS = [
    # Django
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "django.contrib.sites",

    # Third-party
    "rest_framework",
    "rest_framework.authtoken",
    "corsheaders",
    "allauth",
    "allauth.account",
    "allauth.socialaccount",
    "allauth.socialaccount.providers.google",

    # Local apps
    "users",
]

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "allauth.account.middleware.AccountMiddleware",
]

ROOT_URLCONF = "core.urls"
WSGI_APPLICATION = "core.wsgi.application"
ASGI_APPLICATION = "core.asgi.application"

# Templates (required for admin)
TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [str(BASE_DIR / "templates")],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# Database configuration
if env.bool("DB_USE_SQLITE"):
    # Lightweight DB for local development/testing
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": str(BASE_DIR / "db.sqlite3"),
        }
    }
else:
    # Supabase Postgres (production)
    DATABASES = {"default": env.db("DATABASE_URL")}

# Password validation
AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 8},
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# Internationalization
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# Static files
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"

# Default primary key field type
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Custom user model
AUTH_USER_MODEL = "users.User"

# Allow authentication by email
AUTHENTICATION_BACKENDS = (
    "users.authentication.EmailBackend",
    "django.contrib.auth.backends.ModelBackend",
    "allauth.account.auth_backends.AuthenticationBackend",
)

# Site ID for django-allauth
SITE_ID = 1

# Django Allauth settings
ACCOUNT_EMAIL_VERIFICATION = "none"  # Skip email verification for simplicity
ACCOUNT_LOGIN_METHODS = {'email'}
ACCOUNT_SIGNUP_FIELDS = ['email*', 'password1*', 'password2*']
ACCOUNT_USER_MODEL_USERNAME_FIELD = None
ACCOUNT_USER_MODEL_EMAIL_FIELD = "email"
SOCIALACCOUNT_AUTO_SIGNUP = True

# DRF configuration
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": (
        "rest_framework.permissions.AllowAny",
    ),
    # Placeholders for future tuning
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": "100/hour",
        "user": "1000/hour",
    },
}

# Simple JWT
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=env.int("JWT_ACCESS_LIFETIME")),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=env.int("JWT_REFRESH_LIFETIME")),
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# CORS (allow localhost during development)
CORS_ALLOW_ALL_ORIGINS = True
CORS_ALLOW_CREDENTIALS = True

# Domain restriction for college emails
ALLOWED_EMAIL_DOMAIN = env("ALLOWED_EMAIL_DOMAIN")

# Google OAuth client configuration (used in future implementation)
GOOGLE_CLIENT_ID_ANDROID = env("GOOGLE_CLIENT_ID_ANDROID")
GOOGLE_CLIENT_ID_WEB = env("GOOGLE_CLIENT_ID_WEB")
GOOGLE_CLIENT_SECRET_WEB = env("GOOGLE_CLIENT_SECRET_WEB")
GOOGLE_CALLBACK_URL = env("GOOGLE_CALLBACK_URL")

# Social account providers configuration
SOCIALACCOUNT_PROVIDERS = {
    "google": {
        "SCOPE": ["profile", "email"],
        "AUTH_PARAMS": {"access_type": "online"},
        "APP": {
            "client_id": GOOGLE_CLIENT_ID_WEB,
            "secret": GOOGLE_CLIENT_SECRET_WEB,
            "key": "",
        },
    }
}
