from rest_framework import viewsets, permissions
from rest_framework.decorators import action
from rest_framework.response import Response
from django.utils.timezone import now

from .models import Event
from .serializers import (
    EventCreateSerializer, EventListSerializer, EventDetailSerializer
)

class CreateAuthElseReadOnly(permissions.BasePermission):
    def has_permission(self, request, view):
        if request.method in ("GET", "HEAD", "OPTIONS"):
            return True
        return request.user and request.user.is_authenticated

class EventViewSet(viewsets.ModelViewSet):
    queryset = Event.objects.all()
    permission_classes = [CreateAuthElseReadOnly]

    def get_serializer_class(self):
        if self.action in ["create", "update", "partial_update"]:
            return EventCreateSerializer
        if self.action == "retrieve":
            return EventDetailSerializer
        return EventListSerializer

    def get_queryset(self):
        qs = super().get_queryset()

        # Default list: upcoming published events (for home)
        if self.action == "list":
            qs = qs.filter(status=Event.PUBLISHED, starts_at__gte=now()).order_by("starts_at")

        # Optional filter by sport_id: /api/events/?sport_id=101
        sport_id = self.request.query_params.get("sport_id")
        if sport_id:
            qs = qs.filter(sport_id=sport_id)
        return qs

    @action(detail=False, methods=["get"], permission_classes=[permissions.IsAuthenticated])
    def mine(self, request):
        qs = Event.objects.filter(created_by=request.user).order_by("-created_at")
        return Response(EventListSerializer(qs, many=True, context={"request": request}).data)

    @action(detail=False, methods=["get"])
    def featured(self, request):
        limit = int(request.query_params.get("limit", 5))
        qs = Event.objects.filter(status=Event.PUBLISHED, starts_at__gte=now()).order_by("starts_at")[:limit]
        return Response(EventListSerializer(qs, many=True, context={"request": request}).data)
