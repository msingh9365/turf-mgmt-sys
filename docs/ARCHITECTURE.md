# System Architecture

## Overview

The Turf Management System is built using a modern, scalable architecture with clear separation between frontend, backend, and supporting services.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Mobile App (Flutter)                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Splash  │  │  Auth    │  │  Home    │  │ Bookings │       │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘       │
│  ┌──────────┐  ┌──────────┐                                     │
│  │  Teams   │  │ Profile  │     Provider State Management       │
│  └──────────┘  └──────────┘                                     │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTPS/REST API
                     │ JWT Authentication
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Django REST Framework                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                     API Layer                             │  │
│  │  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐ ┌─────────┐        │  │
│  │  │Users │ │Ground│ │Book- │ │Teams │ │Notifica-│        │  │
│  │  │      │ │      │ │ings  │ │      │ │  tions  │        │  │
│  │  └──────┘ └──────┘ └──────┘ └──────┘ └─────────┘        │  │
│  └──────────────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   Business Logic                          │  │
│  │  • Authentication (JWT)                                   │  │
│  │  • Booking Management                                     │  │
│  │  • Queue System                                           │  │
│  │  • Team Management                                        │  │
│  │  • Notification Service                                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────┬───────────────────────────┬────────────────────────┘
             │                           │
             │                           │ Celery Tasks
             │                           ▼
             │                   ┌──────────────┐
             │                   │    Redis     │
             │                   │ Message Broker│
             │                   └──────────────┘
             │                           │
             │                           ▼
             │                   ┌──────────────┐
             │                   │    Celery    │
             │                   │   Workers    │
             │                   └──────────────┘
             │                           │
             ▼                           │
    ┌──────────────┐                    │
    │    MySQL     │◄───────────────────┘
    │   Database   │
    └──────────────┘
             │
             └─────────► FCM Server
                        (Push Notifications)
```

## Component Details

### 1. Mobile Application (Flutter)

**Technology**: Flutter 3.0+, Dart

**Responsibilities**:
- User interface and experience
- Local state management (Provider)
- API communication
- Push notification handling
- Image capture and upload
- Offline data caching

**Key Libraries**:
- `provider` - State management
- `dio` - HTTP client
- `firebase_messaging` - Push notifications
- `flutter_secure_storage` - Secure token storage
- `cached_network_image` - Image caching

### 2. Backend API (Django)

**Technology**: Django 4.2, Django REST Framework

**Responsibilities**:
- RESTful API endpoints
- Business logic implementation
- Authentication and authorization
- Data validation
- Database operations
- Background task scheduling

**Key Components**:
- **Models**: Database schema definition
- **Serializers**: Data transformation
- **Views**: API endpoint logic
- **Permissions**: Access control
- **Signals**: Event handling

### 3. Database (MySQL)

**Technology**: MySQL 5.7+

**Responsibilities**:
- Persistent data storage
- Transaction management
- Data integrity
- Query optimization

**Key Tables**:
- `users` - User accounts
- `sports_types` - Sports categories
- `grounds` - Sports grounds
- `time_slots` - Available time slots
- `bookings` - Booking records
- `teams` - Team information
- `team_requests` - Join requests
- `notifications` - Notification history
- `booking_queues` - Queue management

### 4. Task Queue (Celery + Redis)

**Technology**: Celery 5.3, Redis 4.5

**Responsibilities**:
- Asynchronous task processing
- Scheduled tasks (reminders)
- Background notifications
- Email sending (optional)
- Data cleanup jobs

**Tasks**:
- Send push notifications
- Process booking confirmations
- Update queue positions
- Send booking reminders
- Clean old notifications

### 5. Push Notifications (Firebase Cloud Messaging)

**Technology**: Firebase Cloud Messaging

**Responsibilities**:
- Push notification delivery
- Device token management
- Message queueing
- Platform-specific handling

**Notification Types**:
- Booking confirmations
- Queue updates
- Team invitations
- Booking reminders
- System announcements

## Data Flow

### Booking Creation Flow

```
1. User selects ground and time slot in app
   ↓
2. App sends POST request to /api/bookings/
   ↓
3. Django validates request and checks availability
   ↓
4. If available:
   - Create booking with status "confirmed"
   - Trigger notification task
   ↓
5. If unavailable:
   - Create booking with status "pending"
   - Add to queue
   - Calculate position and wait time
   ↓
6. Celery worker sends notification to user
   ↓
7. User receives push notification
```

### Queue Management Flow

```
1. User cancels confirmed booking
   ↓
2. Django updates booking status to "cancelled"
   ↓
3. System finds next pending booking in queue
   ↓
4. Update next booking to "confirmed"
   ↓
5. Celery sends notification to queued user
   ↓
6. User receives notification and booking confirmation
```

### Authentication Flow

```
1. User enters credentials in app
   ↓
2. App sends POST to /api/token/
   ↓
3. Django validates credentials
   ↓
4. Returns JWT access and refresh tokens
   ↓
5. App stores tokens securely
   ↓
6. Subsequent requests include Bearer token
   ↓
7. Django validates token on each request
   ↓
8. If expired, app uses refresh token
```

## Security Architecture

### Authentication & Authorization

- **JWT Tokens**: Stateless authentication
- **Token Refresh**: Automatic token renewal
- **Role-Based Access**: Student/Faculty/Admin roles
- **Permission Classes**: DRF permission system

### Data Security

- **HTTPS**: Encrypted communication (production)
- **SQL Injection Prevention**: ORM parameterized queries
- **XSS Protection**: Django template escaping
- **CSRF Protection**: Django CSRF middleware
- **Password Hashing**: Django's PBKDF2 algorithm

### API Security

- **Rate Limiting**: Prevent API abuse (configurable)
- **CORS**: Controlled cross-origin access
- **Input Validation**: DRF serializers
- **Error Handling**: No sensitive data in errors

## Scalability Considerations

### Horizontal Scaling

- **Stateless API**: Easy to add more Django instances
- **Load Balancer**: Distribute requests (Nginx/HAProxy)
- **Database Replication**: Read replicas for queries
- **Redis Cluster**: Distributed caching

### Performance Optimization

- **Database Indexing**: Optimized queries
- **API Pagination**: Limited result sets
- **Caching**: Redis for frequent queries
- **CDN**: Static file delivery
- **Image Optimization**: Compressed uploads

### Monitoring & Logging

- **Application Logs**: Django logging
- **Error Tracking**: Sentry integration (optional)
- **Performance Monitoring**: APM tools
- **Database Monitoring**: Query performance
- **Celery Monitoring**: Task execution status

## Deployment Architecture

### Development Environment

```
Local Machine
├── Django (localhost:8000)
├── MySQL (localhost:3306)
├── Redis (localhost:6379)
├── Celery Worker
└── Android Emulator (10.0.2.2:8000)
```

### Production Environment

```
Cloud Infrastructure
├── Web Server (Nginx)
│   └── Load Balancer
│       ├── Django App Server 1 (Gunicorn)
│       ├── Django App Server 2 (Gunicorn)
│       └── Django App Server N (Gunicorn)
├── Database Cluster
│   ├── MySQL Primary
│   └── MySQL Replicas
├── Cache Layer
│   └── Redis Cluster
├── Task Queue
│   ├── Celery Worker Pool
│   └── Celery Beat Scheduler
└── CDN
    └── Static/Media Files
```

## Technology Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Frontend | Flutter | Mobile UI |
| API | Django REST Framework | Backend API |
| Database | MySQL | Data persistence |
| Cache/Queue | Redis | Caching & message broker |
| Task Queue | Celery | Background jobs |
| Push Notifications | Firebase | Mobile notifications |
| Authentication | JWT | Stateless auth |
| Web Server | Gunicorn/Nginx | Production server |

## Future Enhancements

1. **Microservices**: Split into smaller services
2. **GraphQL**: Add GraphQL API
3. **WebSocket**: Real-time updates
4. **Machine Learning**: Smart scheduling
5. **Analytics**: Usage patterns and insights
6. **Payment Integration**: Paid bookings
7. **iOS Support**: Expand to iOS platform
8. **Progressive Web App**: Web-based access

---

For implementation details, see:
- [API Documentation](API.md)
- [Installation Guide](INSTALLATION.md)
- [User Guide](USER_GUIDE.md)
