from rest_framework import viewsets, permissions, status
from rest_framework.decorators import action
from rest_framework.response import Response
from rest_framework.exceptions import PermissionDenied
from django.utils.timezone import now
from datetime import timedelta

from .models import Event
from .serializers import (
    EventCreateSerializer, EventListSerializer, EventDetailSerializer
)
from teams.models import Team


class CreateAuthElseReadOnly(permissions.BasePermission):
    """Allow read access to all, write access only to authenticated users"""
    def has_permission(self, request, view):
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return True
        return request.user and request.user.is_authenticated


class IsCaptainOrReadOnly(permissions.BasePermission):
    """Allow read access to all, event creation only to team captains, update/delete to creator or admin"""
    
    def has_permission(self, request, view):
        # Allow unauthenticated read access (GET, HEAD, OPTIONS)
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Require authentication for all write operations
        if not request.user or not request.user.is_authenticated:
            return False
        
        # For create action, verify user is a captain of at least one team
        if view.action == 'create':
            is_captain = Team.objects.filter(captain=request.user).exists()
            if not is_captain:
                raise PermissionDenied("You must be a team captain to create events")
            return True
        
        # For other write operations (update, delete), check object permission
        return True
    
    def has_object_permission(self, request, view, obj):
        # Allow read access to all
        if request.method in permissions.SAFE_METHODS:
            return True
        
        # Allow update/delete only to creator or admin
        return obj.created_by == request.user or request.user.is_admin


class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.all()
    permission_classes = [IsCaptainOrReadOnly]

    def get_serializer_class(self):
        if self.action in ["create", "update", "partial_update"]:
            return EventCreateSerializer
        if self.action == "retrieve":
            return EventDetailSerializer
        return EventListSerializer

    def get_queryset(self):
        """
        Filter events based on lifecycle:
        - Exclude events older than 3 days after completion (auto-delete threshold)
        - For list: show only upcoming or recently completed events
        """
        qs = super().get_queryset()
        
        # Exclude events that should be auto-deleted (>3 days after completion)
        three_days_ago = now() - timedelta(days=3)
        qs = qs.exclude(ends_at__lt=three_days_ago)

        # Default list: upcoming published events + recently completed (for home page)
        if self.action == "list":
            # Show published events that haven't ended yet OR completed events within 3 days
            qs = qs.filter(
                status__in=[Event.PUBLISHED, Event.COMPLETED]
            ).order_by("starts_at")

        # Optional filter by sport_id: /api/events/?sport_id=101
        sport_id = self.request.query_params.get("sport_id")
        if sport_id:
            try:
                qs = qs.filter(sport_id=int(sport_id))
            except (ValueError, TypeError):
                pass  # Ignore invalid sport_id
        
        return qs

    @action(detail=False, methods=["get"], permission_classes=[permissions.IsAuthenticated])
    def mine(self, request):
        """Get events created by the authenticated user"""
        qs = Event.objects.filter(created_by=request.user).order_by("-created_at")
        return Response(EventListSerializer(qs, many=True, context={"request": request}).data)

    @action(detail=False, methods=["get"])
    def featured(self, request):
        """Get featured upcoming events (limited number)"""
        limit = int(request.query_params.get("limit", 5))
        qs = Event.objects.filter(
            status=Event.PUBLISHED, 
            starts_at__gte=now()
        ).order_by("starts_at")[:limit]
        return Response(EventListSerializer(qs, many=True, context={"request": request}).data)
    
    # Poster selection is handled entirely by frontend
    # Backend only validates and stores the poster_id string
