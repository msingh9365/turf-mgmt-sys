# Firebase configuration template

Follow these steps to set up Firebase for push notifications:

## 1. Create Firebase Project
- Go to https://console.firebase.google.com/
- Click "Add project"
- Enter project name: "Turf Management"
- Follow the setup wizard

## 2. Add Android App
- In Firebase Console, click "Add app" → Android
- Android package name: `com.example.turf_management`
- App nickname: "Turf Management"
- Download `google-services.json`

## 3. Place google-services.json
- Copy the downloaded `google-services.json` file
- Place it in: `android/app/google-services.json`

## 4. Enable Cloud Messaging
- In Firebase Console → Project Settings
- Go to "Cloud Messaging" tab
- Copy the "Server key"
- Add to backend `.env` file:
  ```
  FCM_SERVER_KEY=your-server-key-here
  ```

## 5. Test Notifications
- Run the app
- Login with a user account
- The app will automatically register for notifications
- Test by creating a booking

## Important Notes
- DO NOT commit `google-services.json` to git (already in .gitignore)
- Each developer needs their own Firebase project for development
- Use different Firebase projects for development and production
- Keep your FCM Server Key secure

## Troubleshooting
If notifications don't work:
1. Verify `google-services.json` is in correct location
2. Check FCM_SERVER_KEY in backend `.env`
3. Ensure app has notification permissions
4. Check Firebase Console for any errors
