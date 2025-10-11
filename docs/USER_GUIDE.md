# User Guide - Turf Management System

## Table of Contents
1. [Getting Started](#getting-started)
2. [User Roles](#user-roles)
3. [Features](#features)
4. [Mobile App Usage](#mobile-app-usage)
5. [Admin Panel](#admin-panel)

---

## Getting Started

### First Time Setup

1. **Download and Install**
   - Download the Turf Management APK
   - Install on your Android device
   - Grant necessary permissions (Camera, Storage, Notifications)

2. **Login**
   - Open the app
   - Enter your username and password
   - Credentials are provided by campus administration

### Demo Accounts
For testing purposes, use these sample accounts:
- **Student**: username: `student1`, password: `student123`
- **Faculty**: username: `faculty1`, password: `faculty123`
- **Admin**: username: `admin`, password: `admin123`

---

## User Roles

### Student
- Book sports grounds
- Join/create teams
- View booking history
- Receive notifications

### Faculty
- Same as students
- Additional booking priority (configurable)
- Extended booking durations

### Admin
- Manage grounds and time slots
- View all bookings
- Manage users
- Configure system settings

---

## Features

### 1. Ground Booking

#### View Available Grounds
1. Open the app
2. Navigate to **Home** tab
3. View list of available grounds
4. Each ground shows:
   - Ground name
   - Sport type
   - Location
   - Availability status

#### Book a Ground
1. Select a ground from the list
2. Choose your preferred date using the calendar
3. Select an available time slot
4. Enter booking details:
   - Purpose of booking
   - Number of players
5. Tap **Book Now**
6. Receive confirmation or queue notification

#### Queue System
When a time slot is fully booked:
- Your booking is added to a queue
- You receive a queue position number
- Estimated wait time is displayed
- Notification sent when your turn comes
- Automatic confirmation when slot becomes available

### 2. My Bookings

#### View Your Bookings
1. Navigate to **Bookings** tab
2. View all your bookings with status:
   - **Confirmed**: Booking is confirmed
   - **Pending**: In queue
   - **Cancelled**: Booking cancelled
   - **Completed**: Past booking

#### Cancel a Booking
1. Go to **Bookings** tab
2. Select the booking you want to cancel
3. Tap **Cancel Booking**
4. Confirm cancellation
5. Next person in queue gets automatically confirmed

### 3. Team Management

#### Browse Teams
1. Navigate to **Teams** tab
2. View all available teams
3. Filter by sport type
4. See team details:
   - Team name
   - Sport type
   - Captain name
   - Member count
   - Maximum members

#### Create a Team
1. Go to **Teams** tab
2. Tap **Create Team** button
3. Fill in team details:
   - Team name
   - Sport type
   - Maximum members (default: 11)
   - Description
   - Upload logo (optional)
4. Tap **Create**
5. You become the team captain

#### Join a Team
1. Browse teams in **Teams** tab
2. Select a team you want to join
3. Tap **Request to Join**
4. Write a message to the captain
5. Wait for captain's approval
6. Receive notification when accepted/rejected

#### Manage Team (Captain Only)
1. View join requests
2. Accept or reject requests
3. View team members
4. Edit team details

### 4. Notifications

#### Notification Types
- **Booking Confirmed**: Your booking is confirmed
- **Queue Update**: Your position in queue changed
- **Team Invite**: Invitation to join a team
- **Team Request**: Someone wants to join your team
- **Reminder**: Upcoming booking reminder

#### Managing Notifications
1. Tap bell icon in app bar
2. View all notifications
3. Mark as read by tapping
4. Clear all notifications

### 5. Profile Management

#### View Profile
1. Navigate to **Profile** tab
2. View your information:
   - Name
   - Email
   - Department
   - Roll number (students)
   - User type

#### Update Profile
1. Go to **Profile** tab
2. Tap **Edit Profile**
3. Update your information
4. Tap **Save**

---

## Mobile App Usage

### Navigation

The app has 4 main tabs:

1. **Home** 🏠
   - View available grounds
   - Quick access to booking

2. **Bookings** 📖
   - View all your bookings
   - Check booking status
   - Cancel bookings

3. **Teams** 👥
   - Browse teams
   - Create teams
   - Manage join requests

4. **Profile** 👤
   - View profile information
   - Update profile
   - Logout

### Tips for Best Experience

1. **Enable Notifications**
   - Go to device settings
   - Allow notifications for Turf Management app
   - Stay updated on booking status

2. **Book in Advance**
   - Popular time slots fill up quickly
   - Book at least 1 day in advance
   - Check queue position if slot is full

3. **Cancel Early**
   - If you can't make it, cancel early
   - Helps others in the queue
   - Maintains good booking record

4. **Join Teams**
   - Connect with players
   - Organize matches easily
   - Build campus community

---

## Admin Panel

### Accessing Admin Panel
1. Open browser
2. Go to: `http://your-server:8000/admin`
3. Login with admin credentials

### Admin Dashboard Features

#### Manage Sports Types
1. Go to **Sports Types** section
2. Add new sports
3. Upload sport icons
4. Activate/deactivate sports

#### Manage Grounds
1. Go to **Grounds** section
2. Add new grounds
3. Set capacity
4. Add amenities
5. Upload ground images
6. Mark as available/unavailable

#### Manage Time Slots
1. Go to **Time Slots** section
2. Add time slots for each ground
3. Set start and end times
4. Enable/disable slots

#### View All Bookings
1. Go to **Bookings** section
2. Filter by:
   - Date
   - Ground
   - Status
   - User
3. View booking details
4. Cancel bookings if needed

#### Manage Users
1. Go to **Users** section
2. View all registered users
3. Edit user details
4. Change user roles
5. Deactivate accounts

#### View Queue
1. Go to **Booking Queues** section
2. See queue positions
3. View wait times
4. Monitor queue status

### Periodic Tasks

#### Daily Tasks
- Review upcoming bookings
- Check ground availability
- Monitor queue status

#### Weekly Tasks
- Clean up old notifications
- Review booking patterns
- Update ground schedules

#### Monthly Tasks
- Generate usage reports
- Review user feedback
- Update maintenance schedules

---

## Troubleshooting

### Common Issues

**Cannot login**
- Check username and password
- Ensure account is active
- Contact admin if issue persists

**Booking not confirmed**
- Check if you're in queue
- Wait for notification
- Contact admin if delayed

**Notifications not received**
- Check notification permissions
- Ensure internet connection
- Update app to latest version

**Cannot join team**
- Check if team is full
- Wait for captain approval
- Check notification for status

### Support

For additional help:
- Contact campus IT support
- Email: support@example.com
- Visit admin office during working hours

---

## Best Practices

### For Students
1. Book only when you're sure you can attend
2. Cancel early if plans change
3. Respect ground rules and timings
4. Participate in team activities

### For Team Captains
1. Respond to join requests promptly
2. Keep team information updated
3. Coordinate with team members
4. Organize regular practice sessions

### For Admins
1. Keep ground information updated
2. Monitor booking patterns
3. Respond to user queries
4. Maintain fair booking policies

---

## Frequently Asked Questions

**Q: How far in advance can I book?**
A: You can book up to 30 days in advance (configurable).

**Q: Can I book multiple slots?**
A: Yes, but subject to availability and fair use policy.

**Q: What happens if I'm in queue?**
A: You'll receive a notification when the slot becomes available.

**Q: Can I transfer my booking to someone else?**
A: No, bookings are non-transferable. You must cancel and let them book.

**Q: How do I know if my team request is accepted?**
A: You'll receive a push notification and can check in the Teams section.

**Q: Can faculty members book longer durations?**
A: Yes, based on campus policy (configurable).

---

## Updates and Changelog

### Version 1.0.0
- Initial release
- Basic booking system
- Team management
- Push notifications
- Queue management

---

For more technical information, see [API Documentation](API.md) and [Installation Guide](INSTALLATION.md).
