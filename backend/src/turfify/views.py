# FILE: I:\PGSL Project\turf-mgmt-sys\backend\src\turfify\views.py

from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework import status
from rest_framework.permissions import IsAuthenticated

# Import the model we just created
from .models import DeviceToken

class DeviceTokenView(APIView):
    """
    API endpoint to register and update a user's FCM device token.
    """
    permission_classes = [IsAuthenticated] # Ensures only logged-in users can register a token

    def post(self, request, *args, **kwargs):
        # 1. Get the token from the request body (assuming it's sent as 'fcm_token')
        token = request.data.get('fcm_token')
        
        if not token:
            return Response(
                {"detail": "fcm_token field is required."},
                status=status.HTTP_400_BAD_REQUEST
            )

        user = request.user
        
        # 2. Use update_or_create to handle both new tokens and token updates
        # If the token exists, it updates 'is_active' and 'updated_at'.
        # If the token is new, it creates a new entry.
        device, created = DeviceToken.objects.update_or_create(
            token=token, # Look up by the unique token
            defaults={
                'user': user,
                'is_active': True, # Ensure it's active
            }
        )
        
        if created:
            message = "FCM token registered successfully."
        else:
            message = "FCM token updated successfully."
            
        return Response({"detail": message}, status=status.HTTP_200_OK)
    

