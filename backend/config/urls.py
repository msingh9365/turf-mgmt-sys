from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    # Final API Path: /api/v1/auth/login
    path('api/v1/auth/', include('core_app.urls')), 
]