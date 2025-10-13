from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from django.conf import settings 
from .models import User 
import jwt
import datetime

# **IMPORTANT: REPLACE WITH A SECURE KEY FROM settings.py**
SECRET_KEY = 'your_super_secret_key_from_settings' 

@api_view(['POST'])
def login_view(request):
    """Handles POST request for /auth/login - verifies user credentials."""
    
    email = request.data.get('email_id')
    entry_no = request.data.get('entry_no')
    password = request.data.get('password') # Password hash is stored in DB
    
    # 1. Look up user by unique email and entry number
    try:
        # Check against your combined keys in the users table
        user = User.objects.get(email_id=email, entry_no=entry_no)
    except User.DoesNotExist:
        # User not found with that combination
        return Response({'message': 'Invalid credentials.'}, 
                        status=status.HTTP_401_UNAUTHORIZED)
    
    # 2. Password Check (CRITICAL: Placeholder logic - must be replaced with check_password)
    # For initial testing, we use the stored hash field, but ONLY use hashed passwords!
    if password == user.password_hash: 
        
        # 3. Generate a temporary Auth Token (JWT)
        # The token is based on user ID and expires in 24 hours
        payload = {
            'id': user.user_id,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24), 
            'iat': datetime.datetime.utcnow()
        }
        token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
        
        return Response({
            'message': 'Login successful',
            'user_id': user.user_id,
            'access_token': token
        }, status=status.HTTP_200_OK)
    else:
        # Invalid password
        return Response({'message': 'Invalid credentials.'}, 
                        status=status.HTTP_401_UNAUTHORIZED)