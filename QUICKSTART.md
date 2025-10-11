# Quick Start Guide

Get up and running with Turf Management System in under 10 minutes!

## Prerequisites

- Docker and Docker Compose installed
- Git installed
- (Optional) Flutter SDK for mobile app development

## Option 1: Using Docker (Recommended)

### 1. Clone the Repository
```bash
git clone https://github.com/msingh9365/turf-mgmt-sys.git
cd turf-mgmt-sys
```

### 2. Start Services
```bash
docker-compose up -d
```

This will start:
- MySQL database
- Redis
- Django backend
- Celery worker
- Celery beat scheduler

### 3. Create Admin User
```bash
docker-compose exec backend python manage.py createsuperuser
```

### 4. Load Sample Data
```bash
docker-compose exec backend python manage.py seed_data
```

### 5. Access the Application

**Backend API**: http://localhost:8000/api/
**Admin Panel**: http://localhost:8000/admin/

Default sample credentials (after running seed_data):
- Admin: `admin` / `admin123`
- Student: `student1` / `student123`
- Faculty: `faculty1` / `faculty123`

## Option 2: Manual Setup

### Backend Setup

1. **Install Python Dependencies**
   ```bash
   cd backend
   python -m venv venv
   source venv/bin/activate  # Windows: venv\Scripts\activate
   pip install -r requirements.txt
   ```

2. **Setup Database**
   ```bash
   # Install MySQL if not already installed
   # Create database
   mysql -u root -p
   CREATE DATABASE turf_management;
   exit;
   ```

3. **Configure Environment**
   ```bash
   cp .env.example .env
   # Edit .env with your database credentials
   ```

4. **Run Migrations**
   ```bash
   python manage.py migrate
   python manage.py seed_data
   python manage.py createsuperuser
   ```

5. **Start Development Server**
   ```bash
   # Terminal 1: Django
   python manage.py runserver
   
   # Terminal 2: Redis (if not using Docker)
   redis-server
   
   # Terminal 3: Celery Worker
   celery -A turf_management worker -l info
   
   # Terminal 4: Celery Beat
   celery -A turf_management beat -l info
   ```

### Frontend Setup

1. **Install Flutter**
   - Follow [Flutter installation guide](https://flutter.dev/docs/get-started/install)

2. **Setup Project**
   ```bash
   cd frontend
   flutter pub get
   ```

3. **Configure API Endpoint**
   - Edit `lib/services/api_service.dart`
   - Update `baseUrl` to your backend URL

4. **Run App**
   ```bash
   # For Android Emulator
   flutter run
   
   # For Physical Device
   flutter run -d <device-id>
   ```

## Testing the System

### 1. Access Admin Panel
- URL: http://localhost:8000/admin/
- Login with admin credentials
- Explore Sports Types, Grounds, Bookings

### 2. Test API Endpoints

**Get Token:**
```bash
curl -X POST http://localhost:8000/api/token/ \
  -H "Content-Type: application/json" \
  -d '{"username":"student1","password":"student123"}'
```

**List Grounds:**
```bash
curl -X GET http://localhost:8000/api/grounds/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN"
```

**Create Booking:**
```bash
curl -X POST http://localhost:8000/api/bookings/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "ground": 1,
    "time_slot": 1,
    "booking_date": "2024-12-25",
    "purpose": "Practice match",
    "number_of_players": 22
  }'
```

### 3. Test Mobile App

1. Login with sample credentials
2. Browse available grounds
3. Create a booking
4. View your bookings
5. Join/create teams

## Sample Data

After running `seed_data`, you'll have:

**Sports Types:**
- Football
- Cricket
- Basketball
- Volleyball
- Badminton
- Tennis

**Grounds:**
- Main Football Ground (Sports Complex A)
- Cricket Ground (Sports Complex B)
- Basketball Court 1 (Indoor Stadium)

**Time Slots:**
Each ground has slots from 6 AM to 8 PM

**Users:**
- admin (Admin)
- student1 (Student)
- faculty1 (Faculty)

## Common Issues

### Database Connection Error
```bash
# Check MySQL is running
sudo systemctl status mysql

# Check credentials in .env file
DB_NAME=turf_management
DB_USER=turf_user
DB_PASSWORD=your_password
```

### Redis Connection Error
```bash
# Check Redis is running
redis-cli ping
# Should return: PONG
```

### Port Already in Use
```bash
# Django port 8000
lsof -ti:8000 | xargs kill -9

# MySQL port 3306
lsof -ti:3306 | xargs kill -9
```

### Migration Errors
```bash
# Reset migrations
python manage.py migrate --fake api zero
python manage.py migrate
```

## Next Steps

1. **Explore Documentation**
   - [API Documentation](docs/API.md)
   - [User Guide](docs/USER_GUIDE.md)
   - [Architecture](docs/ARCHITECTURE.md)

2. **Customize Settings**
   - Add more sports types
   - Configure time slots
   - Set up email notifications

3. **Deploy to Production**
   - Set up proper database
   - Configure HTTPS
   - Set environment variables
   - Use production-ready web server

4. **Develop Features**
   - Check [Contributing Guide](CONTRIBUTING.md)
   - Create issues for bugs/features
   - Submit pull requests

## Support

- 📖 Documentation: `/docs` folder
- 🐛 Issues: GitHub Issues
- 💬 Discussions: GitHub Discussions

## Quick Reference

### Useful Commands

```bash
# Backend
python manage.py migrate          # Run migrations
python manage.py createsuperuser  # Create admin
python manage.py seed_data        # Load sample data
python manage.py runserver        # Start server
python manage.py test             # Run tests

# Frontend
flutter pub get                   # Install dependencies
flutter run                       # Run app
flutter build apk                 # Build APK
flutter test                      # Run tests

# Docker
docker-compose up -d              # Start services
docker-compose down               # Stop services
docker-compose logs -f backend    # View logs
docker-compose exec backend bash  # Access container
```

Happy coding! 🚀
