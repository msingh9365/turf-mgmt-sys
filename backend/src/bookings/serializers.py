"""Serializers for booking endpoints."""
from datetime import timedelta
from rest_framework import serializers
from django.utils import timezone

from .models import Booking, Booked_Details


class BookingPlayerSerializer(serializers.Serializer):
    """Serializer for player information supplied during booking."""

    name = serializers.CharField(max_length=100)
    email = serializers.EmailField(max_length=100)

    def validate_name(self, value: str) -> str:
        """Ensure name is not blank after trimming."""
        trimmed = value.strip()
        if not trimmed:
            raise serializers.ValidationError("Player name cannot be blank.")
        return trimmed


class BookedDetailSerializer(serializers.ModelSerializer):
    """Serializer for booked detail entries associated with a booking."""

    ground_id = serializers.IntegerField(source="ground.ground_id", read_only=True)

    class Meta:
        model = Booked_Details
        fields = [
            "player_name",
            "player_email",
            "sort_key",
            "is_user",
            "ground_id",
            "date",
            "slot_id",
        ]
        read_only_fields = fields


class BookingSerializer(serializers.ModelSerializer):
    """
    Serializer for Booking model.
    Used for responses and GET requests.
    """
    
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_name = serializers.CharField(source="user.name", read_only=True)
    ground_id = serializers.SerializerMethodField()
    ground_name = serializers.SerializerMethodField()
    slots = serializers.SerializerMethodField()
    players = serializers.SerializerMethodField()
    details = BookedDetailSerializer(source="booked_details", many=True, read_only=True)
    
    class Meta:
        model = Booking
        fields = [
            "booking_id",
            "date",
            "status",
            "metadata",
            "created_at",
            "user_email",
            "user_name",
            "ground_id",
            "ground_name",
            "slots",
            "players",
            "details",
        ]
        read_only_fields = [
            "booking_id",
            "status",
            "created_at",
            "user_email",
            "user_name",
            "ground_id",
            "ground_name",
            "slots",
            "players",
            "details",
        ]

    def get_ground_id(self, obj):
        metadata_ground = obj.metadata.get("ground_id") if isinstance(obj.metadata, dict) else None
        if metadata_ground is not None:
            return metadata_ground
        detail = obj.booked_details.first()
        return detail.ground.ground_id if detail and detail.ground else None

    def get_ground_name(self, obj):
        metadata_ground = obj.metadata.get("ground_name") if isinstance(obj.metadata, dict) else None
        if metadata_ground:
            return metadata_ground
        detail = obj.booked_details.first()
        return detail.ground.ground_name if detail and detail.ground else None

    def get_slots(self, obj):
        """Return sorted unique slot identifiers for the booking."""
        slot_ids = {detail.slot_id for detail in obj.booked_details.all()}
        return sorted(slot_ids)

    def get_players(self, obj):
        """Return unique players participating in the booking."""
        players = {}
        for detail in obj.booked_details.all():
            email_key = detail.player_email.lower()
            if email_key not in players:
                players[email_key] = {
                    "name": detail.player_name,
                    "email": detail.player_email,
                    "sort_key": detail.sort_key,
                    "is_user": detail.is_user,
                }
        return list(players.values())


class BookingCreateSerializer(serializers.Serializer):
    """
    Serializer for creating a new booking.
    Validates input and enforces business rules.
    Supports both single slot_id (integer) and multiple slot_ids (list).
    """
    
    ground_id = serializers.IntegerField(min_value=1)
    slot_id = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        min_length=1,
        help_text="List of slot IDs to book (e.g., [3, 4, 5])"
    )
    date = serializers.DateField()
    players = BookingPlayerSerializer(many=True)
    metadata = serializers.JSONField(required=False, default=dict)
    
    def validate_date(self, value):
        """
        Validate that the booking date is:
        1. Not in the past
        2. Not more than 14 days in advance
        """
        today = timezone.now().date()
        
        # Check if date is in the past
        if value < today:
            raise serializers.ValidationError("Cannot book slots in the past.")
        
        # Check if date is more than 14 days in advance
        max_advance_date = today + timedelta(days=14)
        if value > max_advance_date:
            raise serializers.ValidationError("Cannot book more than 14 days in advance.")
        
        return value
    
    def validate_ground_id(self, value):
        """Validate ground_id exists (placeholder - extend if Ground model available)."""
        if value < 1:
            raise serializers.ValidationError("Invalid ground ID.")
        return value
    
    def validate_slot_id(self, value):
        """
        Validate slot_ids list.
        Ensures no duplicate slot IDs in the request.
        """
        if not value:
            raise serializers.ValidationError("At least one slot ID is required.")
        
        # Check for duplicates
        if len(value) != len(set(value)):
            raise serializers.ValidationError("Duplicate slot IDs are not allowed.")
        
        # Validate each slot_id
        for slot in value:
            if slot < 1:
                raise serializers.ValidationError(f"Invalid slot ID: {slot}")
        
        return value
    
    def validate(self, attrs):
        """
        Cross-field validation.
        Combine player_ids into metadata if provided.
        """
        metadata = attrs.get("metadata", {})
        attrs["metadata"] = metadata or {}
        players = attrs.get("players", [])

        if not players:
            raise serializers.ValidationError({"players": "At least one player is required."})

        emails = set()
        for player in players:
            email_key = player["email"].lower()
            if email_key in emails:
                raise serializers.ValidationError({"players": "Duplicate player email detected."})
            emails.add(email_key)
        return attrs


class BookingCancelSerializer(serializers.Serializer):
    """
    Serializer for booking cancellation response.
    """
    
    message = serializers.CharField()
    booking_id = serializers.CharField()


class BookingResponseSerializer(serializers.Serializer):
    """
    Serializer for booking creation success response.
    """
    
    booking_id = serializers.CharField()
    status = serializers.CharField()
    message = serializers.CharField()


class BookingErrorSerializer(serializers.Serializer):
    """
    Serializer for booking error responses.
    """
    
    error = serializers.CharField()
