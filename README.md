# Turf Management System

A smart, campus-exclusive platform that simplifies sports ground bookings, encourages team formation, and makes campus sports more organized, inclusive, and engaging.

## Overview

This is an Android application that helps students and faculty book sports grounds available in the college campus based on sports type. The system includes queue management and push notifications to keep users informed about their bookings.

## Tech Stack

- **Frontend**: Flutter (Android Application)
- **Backend**: Django REST Framework
- **Database**: MySQL
- **Push Notifications**: Firebase Cloud Messaging (FCM)
- **Task Queue**: Celery with Redis

## Features

### Core Features
- ✅ User Authentication (Students, Faculty, Admin)
- ✅ Sports Ground Booking System
- ✅ Queue Management for Fully Booked Grounds
- ✅ Team Formation and Management
- ✅ Push Notifications for Booking Updates
- ✅ Real-time Booking Status
- ✅ Available Time Slot Checking

### User Management
- User registration and login
- Profile management
- Role-based access (Student/Faculty/Admin)

### Booking System
- View available grounds by sports type
- Check available time slots
- Book grounds for specific dates and times
- Queue system when grounds are fully booked
- Cancel bookings
- View booking history

### Team Features
- Create teams for specific sports
- Join existing teams
- Team join requests approval system
- View team members and details

### Notifications
- Booking confirmation notifications
- Queue position updates
- Team request notifications
- Booking reminders

## Project Structure

```
turf-mgmt-sys/
├── backend/                    # Django Backend
│   ├── api/                   # Main API app
│   │   ├── models.py         # Database models
│   │   ├── serializers.py    # DRF serializers
│   │   ├── views.py          # API views
│   │   ├── urls.py           # API URL routing
│   │   ├── admin.py          # Django admin config
│   │   ├── tasks.py          # Celery tasks
│   │   └── signals.py        # Django signals
│   ├── turf_management/      # Django project settings
│   │   ├── settings.py       # Django settings
│   │   ├── urls.py           # Main URL routing
│   │   ├── celery.py         # Celery configuration
│   │   └── wsgi.py           # WSGI application
│   ├── manage.py             # Django management script
│   ├── requirements.txt      # Python dependencies
│   └── .env.example          # Environment variables template
│
├── frontend/                  # Flutter Frontend
│   ├── lib/
│   │   ├── models/           # Data models
│   │   ├── providers/        # State management
│   │   ├── screens/          # UI screens
│   │   ├── services/         # API services
│   │   ├── widgets/          # Reusable widgets
│   │   └── main.dart         # App entry point
│   ├── android/              # Android configuration
│   ├── ios/                  # iOS configuration
│   └── pubspec.yaml          # Flutter dependencies
│
├── docs/                      # Documentation
└── README.md                 # This file
```

## Getting Started

### Prerequisites

- Python 3.8+
- MySQL 5.7+
- Redis
- Flutter 3.0+
- Android Studio (for Android development)
- Firebase project (for push notifications)

### Backend Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/msingh9365/turf-mgmt-sys.git
   cd turf-mgmt-sys/backend
   ```

2. **Create virtual environment**
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: venv\Scripts\activate
   ```

3. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your database and Firebase credentials
   ```

5. **Create MySQL database**
   ```sql
   CREATE DATABASE turf_management;
   ```

6. **Run migrations**
   ```bash
   python manage.py makemigrations
   python manage.py migrate
   ```

7. **Create superuser**
   ```bash
   python manage.py createsuperuser
   ```

8. **Start development server**
   ```bash
   python manage.py runserver
   ```

9. **Start Celery worker** (in a separate terminal)
   ```bash
   celery -A turf_management worker -l info
   ```

### Frontend Setup

1. **Navigate to frontend directory**
   ```bash
   cd frontend
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Add Android app to Firebase project
   - Download `google-services.json` and place it in `android/app/`
   - Enable Firebase Cloud Messaging

4. **Update API endpoint**
   - Edit `lib/services/api_service.dart`
   - Update `baseUrl` with your backend server URL

5. **Run the app**
   ```bash
   flutter run
   ```

## API Endpoints

### Authentication
- `POST /api/token/` - Obtain JWT token
- `POST /api/token/refresh/` - Refresh JWT token

### Users
- `GET /api/users/me/` - Get current user
- `PUT /api/users/update_profile/` - Update user profile

### Grounds
- `GET /api/grounds/` - List all grounds
- `GET /api/grounds/{id}/` - Get ground details
- `GET /api/grounds/{id}/available_slots/` - Get available time slots

### Bookings
- `GET /api/bookings/` - List bookings
- `POST /api/bookings/` - Create booking
- `GET /api/bookings/my_bookings/` - Get user's bookings
- `POST /api/bookings/{id}/cancel/` - Cancel booking

### Teams
- `GET /api/teams/` - List teams
- `POST /api/teams/` - Create team
- `GET /api/teams/my_teams/` - Get user's teams
- `POST /api/teams/{id}/join_request/` - Request to join team

### Notifications
- `GET /api/notifications/` - List notifications
- `POST /api/notifications/{id}/mark_read/` - Mark as read
- `POST /api/notifications/mark_all_read/` - Mark all as read

## Database Models

### User
Custom user model with additional fields for student/faculty information.

### SportsType
Different types of sports (Football, Cricket, Basketball, etc.)

### Ground
Sports grounds with location, capacity, and amenities.

### TimeSlot
Available time slots for each ground.

### Booking
Booking records with status tracking and queue management.

### Team
Teams for collaborative sports activities.

### TeamRequest
Join requests for teams with approval workflow.

### Notification
Push notification records.

### BookingQueue
Queue management for fully booked grounds.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Contact

Project Link: [https://github.com/msingh9365/turf-mgmt-sys](https://github.com/msingh9365/turf-mgmt-sys)
