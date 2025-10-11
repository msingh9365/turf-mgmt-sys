# Turf Management Backend

Django REST API backend for the turf management system.

## Quick Start

### Prerequisites
- Python 3.8+
- MySQL 5.7+
- Redis

### Installation

1. **Create virtual environment**
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Configure environment**
```bash
cp .env.example .env
# Edit .env with your settings
```

4. **Setup database**
```bash
# Create MySQL database
mysql -u root -p
CREATE DATABASE turf_management;

# Run migrations
python manage.py makemigrations
python manage.py migrate
```

5. **Create superuser**
```bash
python manage.py createsuperuser
```

6. **Load sample data**
```bash
python manage.py seed_data
```

7. **Run server**
```bash
# Django server
python manage.py runserver

# In separate terminals:
# Celery worker
celery -A turf_management worker -l info

# Celery beat (scheduled tasks)
celery -A turf_management beat -l info
```

## API Endpoints

See [API Documentation](../docs/API.md) for detailed endpoint information.

### Authentication
- `POST /api/token/` - Login
- `POST /api/token/refresh/` - Refresh token

### Main Endpoints
- `/api/users/` - User management
- `/api/grounds/` - Ground management
- `/api/bookings/` - Booking management
- `/api/teams/` - Team management
- `/api/notifications/` - Notifications

## Admin Panel

Access at: `http://localhost:8000/admin`

Default credentials after running `seed_data`:
- Username: `admin`
- Password: `admin123`

## Development

### Running Tests
```bash
python manage.py test
```

### Creating Migrations
```bash
python manage.py makemigrations
python manage.py migrate
```

### Database Reset
```bash
python manage.py flush
python manage.py seed_data
```

## Environment Variables

See `.env.example` for all available configuration options.

Required variables:
- `SECRET_KEY` - Django secret key
- `DB_NAME` - Database name
- `DB_USER` - Database user
- `DB_PASSWORD` - Database password
- `FCM_SERVER_KEY` - Firebase Cloud Messaging key

## Project Structure

```
backend/
├── api/                    # Main API app
│   ├── models.py          # Database models
│   ├── serializers.py     # DRF serializers
│   ├── views.py           # API views
│   ├── urls.py            # API routes
│   ├── admin.py           # Admin configuration
│   ├── tasks.py           # Celery tasks
│   ├── signals.py         # Django signals
│   └── management/        # Management commands
│       └── commands/
│           └── seed_data.py
├── turf_management/       # Django project
│   ├── settings.py       # Django settings
│   ├── urls.py           # Main URL configuration
│   ├── celery.py         # Celery configuration
│   └── wsgi.py           # WSGI configuration
├── manage.py             # Django management script
├── requirements.txt      # Python dependencies
└── .env.example         # Environment template
```

## Technologies Used

- **Django 4.2** - Web framework
- **Django REST Framework** - REST API
- **MySQL** - Database
- **Celery** - Task queue
- **Redis** - Message broker
- **JWT** - Authentication
- **FCM** - Push notifications

## License

MIT License
