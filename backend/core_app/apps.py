from django.apps import AppConfig

class CoreAppConfig(AppConfig):
    default_auto_field = 'django.db.models.BigAutoField'
    name = 'backend.core_app'  # ✅ exact import path
