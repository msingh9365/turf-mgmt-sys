# Contributing to Turf Management System

Thank you for your interest in contributing to the Turf Management System! We welcome contributions from the community.

## Table of Contents
- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Guidelines](#development-guidelines)
- [Pull Request Process](#pull-request-process)

## Code of Conduct

### Our Pledge
We are committed to providing a welcoming and inclusive environment for all contributors, regardless of experience level, gender, gender identity and expression, sexual orientation, disability, personal appearance, body size, race, ethnicity, age, religion, or nationality.

### Our Standards
- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

1. **Fork the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/turf-mgmt-sys.git
   cd turf-mgmt-sys
   ```

2. **Set up development environment**
   - Follow the [Installation Guide](docs/INSTALLATION.md)
   - Set up both backend and frontend

3. **Create a branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

## How to Contribute

### Reporting Bugs

Before submitting a bug report:
- Check if the bug has already been reported in Issues
- Ensure you're using the latest version
- Collect information about the bug

Bug reports should include:
- Clear and descriptive title
- Steps to reproduce the issue
- Expected behavior
- Actual behavior
- Screenshots (if applicable)
- Environment details (OS, Python version, Flutter version, etc.)

### Suggesting Features

Feature requests should include:
- Clear and descriptive title
- Detailed description of the proposed feature
- Use cases and benefits
- Possible implementation approach (optional)

### Contributing Code

Areas where contributions are welcome:
- Bug fixes
- New features
- Documentation improvements
- Test coverage
- Performance improvements
- UI/UX enhancements

## Development Guidelines

### Backend (Django)

#### Code Style
- Follow PEP 8 style guide
- Use meaningful variable and function names
- Add docstrings to all functions and classes
- Keep functions small and focused

#### Best Practices
- Write unit tests for new features
- Use Django ORM for database queries
- Follow REST API best practices
- Validate all user inputs
- Handle errors gracefully

#### Example
```python
def create_booking(user, ground, time_slot, booking_date):
    """
    Create a new booking for a user.
    
    Args:
        user: User instance
        ground: Ground instance
        time_slot: TimeSlot instance
        booking_date: Date of booking
        
    Returns:
        Booking instance
        
    Raises:
        ValidationError: If slot is not available
    """
    # Implementation
    pass
```

### Frontend (Flutter)

#### Code Style
- Follow Dart style guide
- Use meaningful widget and variable names
- Keep widgets small and reusable
- Use const constructors where possible

#### Best Practices
- Separate UI and business logic
- Use Provider for state management
- Handle loading and error states
- Implement proper error handling
- Make UI responsive

#### Example
```dart
class BookingCard extends StatelessWidget {
  final Booking booking;
  
  const BookingCard({
    Key? key,
    required this.booking,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    // Implementation
  }
}
```

### Database

- Always create migrations for model changes
- Add indexes for frequently queried fields
- Use appropriate field types
- Add helpful help_text to fields
- Consider data migration for existing data

### API Design

- Use RESTful conventions
- Version your APIs
- Provide clear error messages
- Document all endpoints
- Use appropriate HTTP status codes

### Documentation

- Update README.md for significant changes
- Add/update API documentation
- Include code comments for complex logic
- Update user guide for new features
- Add screenshots for UI changes

## Pull Request Process

### Before Submitting

1. **Test your changes**
   ```bash
   # Backend tests
   cd backend
   python manage.py test
   
   # Frontend tests
   cd frontend
   flutter test
   ```

2. **Lint your code**
   ```bash
   # Python
   flake8 backend/
   
   # Dart
   flutter analyze
   ```

3. **Update documentation**
   - Update relevant .md files
   - Add/update docstrings
   - Update API documentation if needed

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "Brief description of changes"
   ```
   
   Commit message format:
   - `feat: Add new feature`
   - `fix: Fix bug in booking system`
   - `docs: Update API documentation`
   - `style: Format code`
   - `refactor: Refactor user service`
   - `test: Add tests for team management`

### Submitting Pull Request

1. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your branch
   - Fill in the PR template

3. **PR Description should include:**
   - What changes were made
   - Why the changes were necessary
   - How to test the changes
   - Screenshots (for UI changes)
   - Related issue numbers

### PR Review Process

1. Automated checks will run (CI/CD)
2. Maintainers will review your code
3. Address any requested changes
4. Once approved, PR will be merged

### After Merge

- Delete your feature branch
- Update your local repository
- Celebrate! 🎉

## Development Setup

### Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data
python manage.py runserver
```

### Frontend Setup
```bash
cd frontend
flutter pub get
flutter run
```

## Testing

### Backend Tests
```bash
cd backend
python manage.py test api
```

### Frontend Tests
```bash
cd frontend
flutter test
```

### Manual Testing
- Test on real devices
- Test different screen sizes
- Test offline scenarios
- Test error cases

## Questions?

- Create an issue for questions
- Join discussions in existing issues
- Check documentation first

## Recognition

Contributors will be recognized in:
- README.md contributors section
- Release notes
- Project documentation

Thank you for contributing to making campus sports more organized and accessible!

---

## Useful Resources

- [Django Documentation](https://docs.djangoproject.com/)
- [Django REST Framework](https://www.django-rest-framework.org/)
- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- [PEP 8 Style Guide](https://pep8.org/)
- [Git Best Practices](https://git-scm.com/book/en/v2)
