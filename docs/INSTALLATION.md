# Installation Guide

## Backend Installation

### Prerequisites
- Python 3.8 or higher
- MySQL 5.7 or higher
- Redis server
- pip (Python package manager)
- virtualenv (recommended)

### Step 1: Clone Repository
```bash
git clone https://github.com/msingh9365/turf-mgmt-sys.git
cd turf-mgmt-sys/backend
```

### Step 2: Create Virtual Environment
```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/Mac:
source venv/bin/activate
# On Windows:
venv\Scripts\activate
```

### Step 3: Install Dependencies
```bash
pip install -r requirements.txt
```

### Step 4: Database Setup

1. **Install MySQL** (if not already installed)
   - On Ubuntu/Debian:
     ```bash
     sudo apt update
     sudo apt install mysql-server
     sudo systemctl start mysql
     ```
   - On macOS:
     ```bash
     brew install mysql
     brew services start mysql
     ```
   - On Windows: Download from [MySQL official website](https://dev.mysql.com/downloads/installer/)

2. **Create Database**
   ```bash
   mysql -u root -p
   ```
   ```sql
   CREATE DATABASE turf_management CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
   CREATE USER 'turf_user'@'localhost' IDENTIFIED BY 'your_password';
   GRANT ALL PRIVILEGES ON turf_management.* TO 'turf_user'@'localhost';
   FLUSH PRIVILEGES;
   EXIT;
   ```

### Step 5: Redis Setup

1. **Install Redis**
   - On Ubuntu/Debian:
     ```bash
     sudo apt install redis-server
     sudo systemctl start redis
     ```
   - On macOS:
     ```bash
     brew install redis
     brew services start redis
     ```
   - On Windows: Use WSL or download from [Redis website](https://redis.io/download)

2. **Test Redis**
   ```bash
   redis-cli ping
   # Should return: PONG
   ```

### Step 6: Environment Configuration

1. **Copy environment template**
   ```bash
   cp .env.example .env
   ```

2. **Edit .env file**
   ```bash
   nano .env  # or use your preferred editor
   ```

3. **Configure environment variables**
   ```env
   # Django settings
   SECRET_KEY=your-secret-key-here-change-this-to-random-string
   DEBUG=True
   ALLOWED_HOSTS=localhost,127.0.0.1

   # Database settings
   DB_NAME=turf_management
   DB_USER=turf_user
   DB_PASSWORD=your_password
   DB_HOST=localhost
   DB_PORT=3306

   # Firebase Cloud Messaging
   FCM_SERVER_KEY=your-fcm-server-key-from-firebase-console

   # Redis settings
   REDIS_URL=redis://localhost:6379/0
   ```

### Step 7: Database Migrations
```bash
# Create migrations
python manage.py makemigrations

# Apply migrations
python manage.py migrate
```

### Step 8: Create Superuser
```bash
python manage.py createsuperuser
# Follow the prompts to create admin account
```

### Step 9: Collect Static Files
```bash
python manage.py collectstatic --noinput
```

### Step 10: Start Development Server
```bash
# Start Django server
python manage.py runserver

# In a new terminal, start Celery worker
celery -A turf_management worker -l info

# In another terminal, start Celery beat (for scheduled tasks)
celery -A turf_management beat -l info
```

The backend should now be running at: `http://localhost:8000`

Admin panel: `http://localhost:8000/admin`

---

## Frontend Installation

### Prerequisites
- Flutter SDK 3.0 or higher
- Android Studio (for Android development)
- Xcode (for iOS development, macOS only)
- Android SDK
- Java Development Kit (JDK)

### Step 1: Install Flutter

1. **Download Flutter SDK**
   - Visit [Flutter installation guide](https://flutter.dev/docs/get-started/install)
   - Choose your operating system and follow instructions

2. **Add Flutter to PATH**
   - On Linux/Mac, add to `~/.bashrc` or `~/.zshrc`:
     ```bash
     export PATH="$PATH:/path/to/flutter/bin"
     ```
   - On Windows, add Flutter bin directory to System PATH

3. **Verify Installation**
   ```bash
   flutter doctor
   ```

### Step 2: Install Android Studio

1. **Download and install**
   - Download from [Android Studio website](https://developer.android.com/studio)
   - Install with default settings

2. **Install Android SDK**
   - Open Android Studio
   - Go to Tools > SDK Manager
   - Install latest Android SDK

3. **Configure Android Emulator**
   - Go to Tools > AVD Manager
   - Create a new Virtual Device
   - Choose a device definition and system image

### Step 3: Setup Flutter Project

1. **Navigate to frontend directory**
   ```bash
   cd turf-mgmt-sys/frontend
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Check for issues**
   ```bash
   flutter doctor
   ```

### Step 4: Firebase Setup

1. **Create Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Add project"
   - Follow the setup wizard

2. **Add Android App**
   - Click "Add app" and select Android
   - Package name: `com.example.turf_management` (or your custom package)
   - Download `google-services.json`
   - Place it in `android/app/` directory

3. **Enable Firebase Cloud Messaging**
   - In Firebase Console, go to Project Settings
   - Go to Cloud Messaging tab
   - Copy the Server Key
   - Add it to backend `.env` file as `FCM_SERVER_KEY`

4. **Update Android Configuration**
   - Open `android/build.gradle`
   - Ensure Google Services plugin is included:
     ```gradle
     dependencies {
         classpath 'com.google.gms:google-services:4.3.15'
     }
     ```
   - Open `android/app/build.gradle`
   - Add at the bottom:
     ```gradle
     apply plugin: 'com.google.gms.google-services'
     ```

### Step 5: Configure API Endpoint

1. **Edit API Service**
   ```bash
   nano lib/services/api_service.dart
   ```

2. **Update Base URL**
   ```dart
   static const String baseUrl = 'http://YOUR_IP_ADDRESS:8000/api';
   // For Android emulator: 'http://10.0.2.2:8000/api'
   // For physical device: 'http://YOUR_LOCAL_IP:8000/api'
   ```

### Step 6: Run the App

1. **Connect Device or Start Emulator**
   ```bash
   # List available devices
   flutter devices
   ```

2. **Run in Debug Mode**
   ```bash
   flutter run
   ```

3. **Run in Release Mode**
   ```bash
   flutter run --release
   ```

4. **Build APK**
   ```bash
   flutter build apk --release
   # APK will be in: build/app/outputs/flutter-apk/app-release.apk
   ```

---

## Troubleshooting

### Backend Issues

**Issue: Database connection error**
- Check MySQL is running: `sudo systemctl status mysql`
- Verify credentials in `.env` file
- Test connection: `mysql -u turf_user -p turf_management`

**Issue: Redis connection error**
- Check Redis is running: `redis-cli ping`
- Verify `REDIS_URL` in `.env` file

**Issue: Module not found**
- Ensure virtual environment is activated
- Reinstall dependencies: `pip install -r requirements.txt`

### Frontend Issues

**Issue: SDK version error**
- Update Flutter: `flutter upgrade`
- Check `pubspec.yaml` for SDK constraints

**Issue: Google services error**
- Ensure `google-services.json` is in correct location
- Verify package name matches Firebase configuration

**Issue: Network error when connecting to API**
- For emulator, use `http://10.0.2.2:8000/api`
- For physical device, use actual IP address
- Ensure backend server is accessible from device

**Issue: Build fails**
- Clean build: `flutter clean`
- Get dependencies: `flutter pub get`
- Rebuild: `flutter run`

---

## Production Deployment

### Backend Deployment

1. **Use Production Database**
   - Set up MySQL on production server
   - Update database credentials

2. **Configure Web Server**
   - Use Gunicorn or uWSGI
   - Set up Nginx as reverse proxy

3. **Environment Variables**
   - Set `DEBUG=False`
   - Update `ALLOWED_HOSTS`
   - Use strong `SECRET_KEY`

4. **SSL Certificate**
   - Use Let's Encrypt for HTTPS
   - Update CORS settings

### Frontend Deployment

1. **Build Release APK**
   ```bash
   flutter build apk --release
   ```

2. **Build App Bundle** (for Play Store)
   ```bash
   flutter build appbundle --release
   ```

3. **Sign APK**
   - Create keystore
   - Configure signing in `android/app/build.gradle`

4. **Update API Endpoint**
   - Use production API URL
   - Ensure HTTPS is used

---

## Next Steps

- Configure initial data (sports types, grounds, time slots)
- Set up email notifications (optional)
- Configure backup system
- Set up monitoring and logging
- Review security settings

For more information, see the main [README.md](../README.md) and [API.md](API.md) documentation.
