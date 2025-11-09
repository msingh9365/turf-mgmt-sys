# Turf Management Backend

Django REST API backend for the turf management system.

## 📖 Documentation

- **[Booking System Documentation](BOOKING_SYSTEM_DOCUMENTATION.md)** - Complete API reference for booking management
- **[Member Lock System](MEMBER_LOCK_SYSTEM.md)** - Sort key based locking mechanism
- **[Performance Optimizations](PERFORMANCE_OPTIMIZATIONS.md)** - Database and Redis optimization details

## Quick Start

### Prerequisites
- **Option 1 (Docker)**: Docker and Docker Compose
- **Option 2 (Local)**: Python 3.13+ and Supabase account

---

## 🐳 Docker Setup (Recommended)

### 1. Clone and configure
```bash
cd backend

# Copy environment template
cp .env.docker.example src/.env

# Edit src/.env with your Supabase credentials
nano src/.env
```

### 2. Build and run
```bash
# Build and start the container
docker-compose up --build

# Or run in detached mode
docker-compose up -d

# View logs
docker-compose logs -f backend
```

### 3. Access the application
- API: http://localhost:8000
- Admin: http://localhost:8000/admin

### 4. Common Docker commands
```bash
# Stop containers
docker-compose down

# Restart containers
docker-compose restart

# Run migrations
docker-compose exec backend python src/manage.py migrate

# Create superuser
docker-compose exec backend python src/manage.py createsuperuser

# View logs
docker-compose logs -f backend

# Shell access
docker-compose exec backend bash
```

---

## 💻 Local Development Setup

### Prerequisites
- Python 3.13+
- Supabase account (or SQLite for local testing)

### Installation

1. **Create virtual environment**
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
```

2. **Install dependencies**
```bash
pip install -r requirements.txt
```

3. **Configure environment**
```bash
cp .env.docker.example src/.env
# Edit src/.env with your Supabase credentials or set DB_USE_SQLITE=True
```

4. **Setup database**
```bash
cd src

# Run migrations
python manage.py makemigrations
python manage.py migrate
```

5. **Create superuser**
```bash
python manage.py createsuperuser
```

6. **Run server**
```bash
python manage.py runserver
```

## API Endpoints

### Complete API Documentation

📚 **[Booking System Documentation](BOOKING_SYSTEM_DOCUMENTATION.md)** - Complete guide for all booking-related APIs

This comprehensive documentation includes:
- All booking endpoints (Create, List, Get, Cancel, Delete)
- Booked slots availability API
- Request/response examples
- Error handling
- Test documentation
- Setup and troubleshooting guides
- Best practices and flow diagrams

### Quick Reference

**Booking Endpoints:**
- `POST /api/bookings/` - Create a booking
- `GET /api/bookings/my/` - List my bookings
- `GET /api/bookings/{id}/` - Get single booking
- `POST /api/bookings/{id}/cancel/` - Cancel a booking
- `DELETE /api/bookings/{id}/` - Delete a booking
- `GET /api/bookings/booked-slots/` - Get booked slots for a ground/date

**Authentication:**
- `POST /api/auth/register/` - User registration
- `POST /api/auth/login/` - Login (returns JWT tokens)
- `POST /api/auth/token/refresh/` - Refresh access token
- `GET /api/user/me/` - Get current user profile

## Admin Panel

Access at: `http://localhost:8000/admin`

Create a superuser:
```bash
# Docker
docker-compose exec backend python src/manage.py createsuperuser

# Local
python src/manage.py createsuperuser
```

## Development

### Running Tests
```bash
# Docker
docker-compose exec backend python src/manage.py test

# Local
python src/manage.py test
```

### Creating Migrations
```bash
# Docker
docker-compose exec backend python src/manage.py makemigrations
docker-compose exec backend python src/manage.py migrate

# Local
python src/manage.py makemigrations
python src/manage.py migrate
```

## Environment Variables

See `.env.docker.example` for all available configuration options.

Required variables:
- `DJANGO_SECRET_KEY` - Django secret key
- `DATABASE_URL` - Supabase Postgres connection string (or set `DB_USE_SQLITE=True` for local dev)
- `ALLOWED_EMAIL_DOMAIN` - Email domain restriction (e.g., @iitrpr.ac.in)

Optional variables:
- `SUPABASE_URL` - Supabase project URL (for Auth/Storage/Realtime)
- `SUPABASE_KEY` - Supabase API key
- `SUPABASE_JWT_SECRET` - JWT secret for token verification
- `GOOGLE_CLIENT_ID_*` - Google OAuth credentials

## Project Structure

```
backend/
├── src/
│   ├── manage.py              # Django management script
│   ├── core/                  # Django project settings
│   │   ├── settings/
│   │   │   ├── base.py       # Base settings
│   │   │   ├── dev.py        # Development settings
│   │   │   └── prod.py       # Production settings
│   │   ├── urls.py           # Main URL configuration
│   │   ├── wsgi.py           # WSGI configuration
│   │   └── asgi.py           # ASGI configuration
│   ├── users/                # Users app
│   │   ├── models.py         # Custom User model
│   │   ├── serializers.py    # User serializers
│   │   ├── views.py          # Auth views (register, login, profile)
│   │   ├── urls.py           # User routes
│   │   ├── authentication.py # Email backend
│   │   └── admin.py          # User admin
│   └── .env                  # Environment variables (create from .env.docker.example)
├── Dockerfile                # Docker configuration
├── docker-compose.yml        # Docker Compose orchestration
├── .dockerignore            # Docker ignore rules
├── .env.docker.example      # Environment template
├── requirements.txt         # Python dependencies
└── README.md               # This file
```

## Technologies Used

- **Django 5.0.6** - Web framework
- **Django REST Framework** - REST API
- **Supabase Postgres** - Database (or SQLite for local dev)
- **psycopg 3** - PostgreSQL adapter
- **JWT (Simple JWT)** - Authentication
- **Docker** - Containerization
- **django-environ** - Environment variable management
- **CORS Headers** - Cross-origin requests

## Database Options

### Option 1: Supabase Postgres (Recommended for production)
1. Create a Supabase project at https://supabase.com
2. Get your connection string from Settings → Database
3. Set `DB_USE_SQLITE=False` and add `DATABASE_URL` in `.env`

### Option 2: SQLite (Local development/testing)
1. Set `DB_USE_SQLITE=True` in `.env`
2. Database file will be created at `src/db.sqlite3`

## Troubleshooting

### Docker issues
```bash
# Rebuild containers
docker-compose build --no-cache

# Remove all containers and volumes
docker-compose down -v

# Check container logs
docker-compose logs -f backend
```

### Database connection issues
- Verify `DATABASE_URL` includes `?sslmode=require` for Supabase
- Check Supabase project is not paused
- Ensure credentials are correct

### Permission issues
```bash
# Fix file permissions
sudo chown -R $USER:$USER .
```

## License

MIT License
