from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import User 
import jwt
import datetime

# NOTE: This key must be a secret. In a production app, use settings.SECRET_KEY.
SECRET_KEY = 'your_super_secret_key_from_settings' 

@api_view(['POST'])
def login_view(request):
    """Handles POST request for /auth/login - verifies user credentials."""
    
    # 1. Get credentials from Devasari's frontend request
    email = request.data.get('email_id')
    entry_no = request.data.get('entry_no')
    password = request.data.get('password') 
    
    # 2. Look up user in the database
    try:
        user = User.objects.get(email_id=email, entry_no=entry_no)
    except User.DoesNotExist:
       
        return Response({'message': 'Invalid credentials.'}, 
                        status=status.HTTP_401_UNAUTHORIZED)
    
    # 3. Password Check (VERY IMPORTANT: Replace with password hashing/checking later!)
    if password == user.password_hash: 
        
        # 4. Generate a temporary Auth Token (JWT)
        payload = {
            'id': user.user_id,
            
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24), 
            'iat': datetime.datetime.utcnow()
        }
        token = jwt.encode(payload, SECRET_KEY, algorithm='HS256')
        
        # Success response
        return Response({
            'message': 'Login successful',
            'user_id': user.user_id,
            'access_token': token
        }, status=status.HTTP_200_OK)
    else:
        # Invalid password
        return Response({'message': 'Invalid credentials.'}, 
                        status=status.HTTP_401_UNAUTHORIZED)

