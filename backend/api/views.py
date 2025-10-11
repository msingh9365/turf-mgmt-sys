"""
API views for turf management system
"""
from rest_framework import viewsets, status, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from django.utils import timezone
from django.db import models
from django_filters.rest_framework import DjangoFilterBackend
from .models import (
    User, SportsType, Ground, TimeSlot, Booking,
    Team, TeamRequest, Notification, BookingQueue
)
from .serializers import (
    UserSerializer, SportsTypeSerializer, GroundSerializer,
    TimeSlotSerializer, BookingSerializer, TeamSerializer,
    TeamRequestSerializer, NotificationSerializer, BookingQueueSerializer
)
from .tasks import send_notification


class UserViewSet(viewsets.ModelViewSet):
    """ViewSet for User management"""
    queryset = User.objects.all()
    serializer_class = UserSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['user_type', 'department']

    @action(detail=False, methods=['get'])
    def me(self, request):
        """Get current user details"""
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)

    @action(detail=False, methods=['put'])
    def update_profile(self, request):
        """Update current user profile"""
        serializer = self.get_serializer(request.user, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data)


class SportsTypeViewSet(viewsets.ModelViewSet):
    """ViewSet for SportsType management"""
    queryset = SportsType.objects.filter(is_active=True)
    serializer_class = SportsTypeSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_active']


class GroundViewSet(viewsets.ModelViewSet):
    """ViewSet for Ground management"""
    queryset = Ground.objects.filter(is_available=True)
    serializer_class = GroundSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['sports_type', 'is_available', 'location']

    @action(detail=True, methods=['get'])
    def available_slots(self, request, pk=None):
        """Get available time slots for a ground on a specific date"""
        ground = self.get_object()
        date = request.query_params.get('date', timezone.now().date())
        
        # Get all time slots for the ground
        slots = TimeSlot.objects.filter(ground=ground, is_available=True)
        
        # Filter out already booked slots
        booked_slots = Booking.objects.filter(
            ground=ground,
            booking_date=date,
            status__in=['pending', 'confirmed']
        ).values_list('time_slot_id', flat=True)
        
        available_slots = slots.exclude(id__in=booked_slots)
        serializer = TimeSlotSerializer(available_slots, many=True)
        return Response(serializer.data)


class BookingViewSet(viewsets.ModelViewSet):
    """ViewSet for Booking management"""
    queryset = Booking.objects.all()
    serializer_class = BookingSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status', 'ground', 'booking_date']

    def get_queryset(self):
        """Filter bookings based on user"""
        if self.request.user.user_type == 'admin':
            return Booking.objects.all()
        return Booking.objects.filter(user=self.request.user)

    def perform_create(self, serializer):
        """Create booking and add to queue if necessary"""
        booking = serializer.save(user=self.request.user)
        
        # Check if slot is already booked
        existing_booking = Booking.objects.filter(
            ground=booking.ground,
            time_slot=booking.time_slot,
            booking_date=booking.booking_date,
            status__in=['confirmed', 'pending']
        ).exclude(id=booking.id).first()
        
        if existing_booking:
            # Add to queue
            queue_count = BookingQueue.objects.filter(
                booking__ground=booking.ground,
                booking__booking_date=booking.booking_date
            ).count()
            
            BookingQueue.objects.create(
                booking=booking,
                position=queue_count + 1,
                estimated_wait_time=60  # Default 60 minutes
            )
            booking.status = 'pending'
            booking.queue_position = queue_count + 1
            booking.save()
        else:
            booking.status = 'confirmed'
            booking.save()
            
        # Send notification
        send_notification.delay(
            booking.user.id,
            'booking_confirmed' if booking.status == 'confirmed' else 'queue_update',
            'Booking Confirmation',
            f'Your booking for {booking.ground.name} has been {booking.status}.'
        )

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        """Cancel a booking"""
        booking = self.get_object()
        
        if booking.user != request.user and request.user.user_type != 'admin':
            return Response(
                {'error': 'You do not have permission to cancel this booking'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        booking.status = 'cancelled'
        booking.save()
        
        # Update queue
        self._update_queue(booking)
        
        return Response({'status': 'Booking cancelled successfully'})

    def _update_queue(self, cancelled_booking):
        """Update queue when a booking is cancelled"""
        # Get next booking in queue for the same ground and date
        next_in_queue = BookingQueue.objects.filter(
            booking__ground=cancelled_booking.ground,
            booking__booking_date=cancelled_booking.booking_date,
            notified=False
        ).order_by('position').first()
        
        if next_in_queue:
            next_in_queue.booking.status = 'confirmed'
            next_in_queue.booking.save()
            next_in_queue.notified = True
            next_in_queue.save()
            
            # Send notification
            send_notification.delay(
                next_in_queue.booking.user.id,
                'queue_update',
                'Booking Confirmed',
                f'Your booking for {next_in_queue.booking.ground.name} has been confirmed!'
            )

    @action(detail=False, methods=['get'])
    def my_bookings(self, request):
        """Get current user's bookings"""
        bookings = Booking.objects.filter(user=request.user).order_by('-booking_date')
        page = self.paginate_queryset(bookings)
        if page is not None:
            serializer = self.get_serializer(page, many=True)
            return self.get_paginated_response(serializer.data)
        serializer = self.get_serializer(bookings, many=True)
        return Response(serializer.data)


class TeamViewSet(viewsets.ModelViewSet):
    """ViewSet for Team management"""
    queryset = Team.objects.filter(is_active=True)
    serializer_class = TeamSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['sports_type', 'is_active']

    @action(detail=True, methods=['post'])
    def join_request(self, request, pk=None):
        """Request to join a team"""
        team = self.get_object()
        
        # Check if already a member
        if request.user in team.members.all():
            return Response(
                {'error': 'You are already a member of this team'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Check if request already exists
        if TeamRequest.objects.filter(team=team, user=request.user, status='pending').exists():
            return Response(
                {'error': 'You already have a pending request for this team'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        # Create team request
        team_request = TeamRequest.objects.create(
            team=team,
            user=request.user,
            message=request.data.get('message', '')
        )
        
        # Notify team captain
        send_notification.delay(
            team.captain.id,
            'team_request',
            'New Team Join Request',
            f'{request.user.username} wants to join your team {team.name}'
        )
        
        serializer = TeamRequestSerializer(team_request)
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=False, methods=['get'])
    def my_teams(self, request):
        """Get teams where user is a member or captain"""
        teams = Team.objects.filter(
            models.Q(captain=request.user) | models.Q(members=request.user)
        ).distinct()
        serializer = self.get_serializer(teams, many=True)
        return Response(serializer.data)


class TeamRequestViewSet(viewsets.ModelViewSet):
    """ViewSet for TeamRequest management"""
    queryset = TeamRequest.objects.all()
    serializer_class = TeamRequestSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['status', 'team']

    def get_queryset(self):
        """Filter team requests based on user"""
        return TeamRequest.objects.filter(
            models.Q(team__captain=self.request.user) | models.Q(user=self.request.user)
        )

    @action(detail=True, methods=['post'])
    def accept(self, request, pk=None):
        """Accept a team join request"""
        team_request = self.get_object()
        
        if team_request.team.captain != request.user:
            return Response(
                {'error': 'Only team captain can accept requests'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        # Check team capacity
        if team_request.team.members.count() >= team_request.team.max_members:
            return Response(
                {'error': 'Team is already full'},
                status=status.HTTP_400_BAD_REQUEST
            )
        
        team_request.status = 'accepted'
        team_request.save()
        team_request.team.members.add(team_request.user)
        
        # Notify user
        send_notification.delay(
            team_request.user.id,
            'team_invite',
            'Team Request Accepted',
            f'You have been accepted to join {team_request.team.name}'
        )
        
        return Response({'status': 'Request accepted successfully'})

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        """Reject a team join request"""
        team_request = self.get_object()
        
        if team_request.team.captain != request.user:
            return Response(
                {'error': 'Only team captain can reject requests'},
                status=status.HTTP_403_FORBIDDEN
            )
        
        team_request.status = 'rejected'
        team_request.save()
        
        # Notify user
        send_notification.delay(
            team_request.user.id,
            'team_invite',
            'Team Request Rejected',
            f'Your request to join {team_request.team.name} has been rejected'
        )
        
        return Response({'status': 'Request rejected successfully'})


class NotificationViewSet(viewsets.ModelViewSet):
    """ViewSet for Notification management"""
    queryset = Notification.objects.all()
    serializer_class = NotificationSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['is_read', 'notification_type']

    def get_queryset(self):
        """Get notifications for current user"""
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        """Mark notification as read"""
        notification = self.get_object()
        notification.is_read = True
        notification.save()
        return Response({'status': 'Notification marked as read'})

    @action(detail=False, methods=['post'])
    def mark_all_read(self, request):
        """Mark all notifications as read"""
        Notification.objects.filter(user=request.user, is_read=False).update(is_read=True)
        return Response({'status': 'All notifications marked as read'})


class BookingQueueViewSet(viewsets.ReadOnlyModelViewSet):
    """ViewSet for BookingQueue (read-only)"""
    queryset = BookingQueue.objects.all()
    serializer_class = BookingQueueSerializer
    permission_classes = [permissions.IsAuthenticated]
    filter_backends = [DjangoFilterBackend]
    filterset_fields = ['booking__ground', 'booking__booking_date']

    def get_queryset(self):
        """Get queue entries for current user's bookings"""
        return BookingQueue.objects.filter(booking__user=self.request.user)
