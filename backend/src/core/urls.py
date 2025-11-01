"""
Root URL configuration for the project.
Routes the API under /api/ and prepares for future apps.
"""
from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    # Admin kept for development convenience; can be disabled in prod settings
    path("admin/", admin.site.urls),

    # API routes
    path("api/", include("users.urls")),

    path('api/v1/auth/', include('users.urls')),

]
# """
# Root URL configuration for the project.
# Routes the API under /api/v1/ and prepares for future apps.
# """
# from django.contrib import admin
# from django.urls import include, path

# urlpatterns = [
#     path("admin/", admin.site.urls),

#     # 1. NEW: Define ONE, clear API path prefix for ALL user-related endpoints: /api/v1/
#     #    We must use the full Python path: 'core.users.urls'
#     path("api/v1/", include("users.urls")),
    
#     # 2. NEW: Include the turfify app under the same prefix: /api/v1/
#     #    We must use the full Python path: 'core.turfify.urls'
#     path("api/v1/", include("turfify.urls")), 

#     # REMOVED: The conflicting lines that caused the confusion and 404
#     # path("api/", include("users.urls")),
#     # path('api/v1/auth/', include('users.urls')),

# ]