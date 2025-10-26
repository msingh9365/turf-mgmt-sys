from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    # Links your core_app URLs under the '/api/v1/auth/' prefix
    path('api/v1/auth/', include('core_app.urls')), 
]