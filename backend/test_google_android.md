# Android Google Sign-In Testing Guide

## Overview
This backend now supports **Android-only** Google Sign-In using ID token verification. No web OAuth redirect flow is included.

## API Endpoint

**Endpoint:** `POST /api/auth/google/android/`

**Purpose:** Verify Google ID token from Android app and return JWT access/refresh tokens

## How It Works

1. **Android app** uses Google Sign-In SDK to authenticate user
2. App receives **ID token** from Google
3. App sends ID token to your backend
4. Backend **verifies token with Google** servers
5. Backend creates/updates user and returns **JWT tokens**

## Testing the Endpoint

### 1. Start Django Server

```bash
cd /Users/manish/Code/Assignments/CS509/turf-mgmt-sys/backend/src
python manage.py runserver
```

### 2. Test with Mock ID Token (Will Fail - Expected)

```bash
curl -X POST http://localhost:8000/api/auth/google/android/ \
  -H "Content-Type: application/json" \
  -d '{
    "id_token": "fake_token_for_testing"
  }'
```

**Expected Response:**
```json
{
  "error": "Invalid token: ..."
}
```

### 3. Test with Real ID Token from Android

To get a real ID token, you need to:

#### Option A: Use Android Emulator/Device

1. **Create Android Google Sign-In App:**
   ```kotlin
   // In your Android app (build.gradle)
   implementation 'com.google.android.gms:play-services-auth:20.7.0'
   
   // In your sign-in code
   val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
       .requestIdToken("YOUR_ANDROID_CLIENT_ID")  // From Google Console
       .requestEmail()
       .build()
   
   val googleSignInClient = GoogleSignIn.getClient(this, gso)
   ```

2. **Get ID Token:**
   ```kotlin
   val account = GoogleSignIn.getLastSignedInAccount(context)
   val idToken = account?.idToken
   
   // Send to backend
   val jsonObject = JSONObject()
   jsonObject.put("id_token", idToken)
   
   // Make POST request to /api/auth/google/android/
   ```

#### Option B: Use Google's OAuth Playground (Development Only)

For **development testing only**, you can manually obtain an ID token:

1. Visit: https://developers.google.com/oauthplayground/
2. Click the gear icon, enable **Use your own OAuth credentials**, and enter the client ID/secret you configured in Google Cloud (Web client works best for this flow)
3. Select "Google OAuth2 API v2" →
  - "https://www.googleapis.com/auth/userinfo.email"
  - "https://www.googleapis.com/auth/userinfo.profile" (required to receive full name)
4. Click **Authorize APIs** and sign in with a `@iitrpr.ac.in` email
5. Click **Exchange authorization code for tokens**
6. In the JSON response, copy the full value of `id_token` – it must contain **two dots** (e.g., `header.payload.signature`)

Then test:
```bash
curl -X POST http://localhost:8000/api/auth/google/android/ \
  -H "Content-Type: application/json" \
  -d '{
    "id_token": "PASTE_THE_FULL_ID_TOKEN_STRING_HERE"
  }'
```

**Expected Success Response:**
```json
{
  "access": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGc...",
  "user": {
    "id": 1,
    "email": "user@iitrpr.ac.in",
    "name": "John Doe",
    "sort_key": "user"
  },
  "created": true
}
```

### 4. Test Protected Endpoint with JWT

```bash
# Save the access token from previous response
ACCESS_TOKEN="paste_access_token_here"

# Call protected endpoint
curl -X GET http://localhost:8000/api/user/me/ \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Expected Response:**
```json
{
  "id": 1,
  "email": "user@iitrpr.ac.in",
  "name": "John Doe",
  "sort_key": "user",
  "phone": "",
  "is_admin": false,
  "created_at": "2025-11-05T10:30:00Z"
}
```

## Google Console Setup

### 1. Create OAuth 2.0 Client ID

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select/Create project
3. Navigate to **APIs & Services** → **Credentials**
4. Click **Create Credentials** → **OAuth 2.0 Client ID**
5. Select **Android** as application type

### 2. Configure Android Client

- **Package name:** Your Android app package (e.g., `com.yourcompany.turfmgmt`)
- **SHA-1 fingerprint:** Get from your Android keystore

```bash
# Get SHA-1 from debug keystore
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

### 3. Copy Client ID

Copy the **Android Client ID** and update in `.env`:

```env
GOOGLE_CLIENT_ID_ANDROID=891475394855-xxxxxxxxxxxxx.apps.googleusercontent.com
```

## Environment Configuration

### Required Environment Variables

```env
# .env file
GOOGLE_CLIENT_ID_ANDROID=YOUR_ANDROID_CLIENT_ID
GOOGLE_CLIENT_ID_WEB=YOUR_WEB_CLIENT_ID  # Optional, for fallback
ALLOWED_EMAIL_DOMAIN=@iitrpr.ac.in
```

> **Important:** Replace the placeholder values above. The backend now reports a configuration error if `GOOGLE_CLIENT_ID_ANDROID` is left unset or uses the stub value.

## Security Features

✅ **ID Token Verification** - Verifies with Google servers  
✅ **Audience Validation** - Ensures token is for your app  
✅ **Email Verification Check** - Only accepts verified emails  
✅ **Domain Restriction** - Only `@iitrpr.ac.in` emails allowed  
✅ **Auto User Creation** - Creates user on first sign-in  
✅ **Last Login Tracking** - Updates login timestamp  

## Error Handling

### Common Errors

| Error | Status | Reason |
|-------|--------|--------|
| `id_token is required` | 400 | Missing token in request |
| `Invalid token` | 401 | Token expired or malformed |
| `Invalid audience` | 400 | Token not for your app |
| `Email not provided by Google` | 400 | Token missing email claim |
| `Email not verified by Google` | 400 | Google hasn't verified email |
| `Only @iitrpr.ac.in emails allowed` | 403 | Wrong email domain |
| `Authentication failed` | 400 | Other verification errors |

## Integration with Android App

### Kotlin Example

```kotlin
// 1. Configure Google Sign-In
val gso = GoogleSignInOptions.Builder(GoogleSignInOptions.DEFAULT_SIGN_IN)
    .requestIdToken(getString(R.string.google_client_id_android))
    .requestEmail()
    .build()

val googleSignInClient = GoogleSignIn.getClient(this, gso)

// 2. Launch sign-in intent
val signInIntent = googleSignInClient.signInIntent
startActivityForResult(signInIntent, RC_SIGN_IN)

// 3. Handle result
override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
    super.onActivityResult(requestCode, resultCode, data)
    
    if (requestCode == RC_SIGN_IN) {
        val task = GoogleSignIn.getSignedInAccountFromIntent(data)
        handleSignInResult(task)
    }
}

// 4. Send ID token to backend
private fun handleSignInResult(completedTask: Task<GoogleSignInAccount>) {
    try {
        val account = completedTask.getResult(ApiException::class.java)
        val idToken = account?.idToken
        
        // Make API call to your backend
        sendTokenToBackend(idToken)
    } catch (e: ApiException) {
        Log.e(TAG, "signInResult:failed code=" + e.statusCode)
    }
}

// 5. API call function
private fun sendTokenToBackend(idToken: String?) {
    val json = JSONObject()
    json.put("id_token", idToken)
    
    val request = Request.Builder()
        .url("http://your-backend-url/api/auth/google/android/")
        .post(json.toString().toRequestBody("application/json".toMediaType()))
        .build()
    
    client.newCall(request).enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) {
            val body = response.body?.string()
            val jsonResponse = JSONObject(body)
            
            // Save JWT tokens
            val accessToken = jsonResponse.getString("access")
            val refreshToken = jsonResponse.getString("refresh")
            
            // Store in SharedPreferences or secure storage
            saveTokens(accessToken, refreshToken)
        }
        
        override fun onFailure(call: Call, e: IOException) {
            Log.e(TAG, "Network request failed", e)
        }
    })
}
```

## Best Practices

1. **Store JWT Securely** - Use Android Keystore or EncryptedSharedPreferences
2. **Handle Token Refresh** - Implement refresh token logic when access token expires
3. **Validate Before Sending** - Check if token exists before making API call
4. **Error Feedback** - Show user-friendly messages for authentication errors
5. **Logout Handling** - Clear tokens and sign out from Google when user logs out

## Development vs Production

### Development
- Use debug keystore SHA-1
- Test with development backend URL
- Use test Google accounts

### Production
- Use release keystore SHA-1
- Update to production backend URL
- Ensure HTTPS for backend
- Test with real `@iitrpr.ac.in` accounts

## Troubleshooting

### "Invalid audience" Error
- **Cause:** Token was issued for different client ID
- **Fix:** Ensure `GOOGLE_CLIENT_ID_ANDROID` in `.env` matches Android app's client ID

### "Email not verified" Error
- **Cause:** Google account email not verified
- **Fix:** User must verify their email with Google first

### "Only @iitrpr.ac.in emails allowed" Error
- **Cause:** User signed in with non-college email
- **Fix:** Instruct users to sign in with college email only

### Token Expired
- **Cause:** ID token has 1-hour expiration
- **Fix:** Re-authenticate user to get new token

### "Wrong number of segments in token" Error
- **Cause:** The copied token is missing the signature segment (only contains header and payload)
- **Fix:** Copy the encoded `id_token` value exactly as returned by Google so it contains two dots (`xxx.yyy.zzz`)

## Next Steps

1. ✅ Backend endpoint is ready
2. 📱 Integrate Google Sign-In SDK in Android app
3. 🔐 Configure Google Console with Android package & SHA-1
4. 🧪 Test end-to-end flow
5. 🚀 Deploy and monitor

## Support

For issues or questions:
- Check Google Console configuration
- Verify SHA-1 fingerprint matches
- Ensure email domain is `@iitrpr.ac.in`
- Review Django logs for detailed errors
