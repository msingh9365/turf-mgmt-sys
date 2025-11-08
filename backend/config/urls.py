from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    
    # Links your teams URLs under the '/api/' prefix
    path('api/', include('backend.teams.urls')),

]
