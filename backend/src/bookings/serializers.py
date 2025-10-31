"""
Serializers for booking endpoints.
"""
from datetime import datetime, timedelta
from rest_framework import serializers
from django.utils import timezone
from .models import Booking


class BookingSerializer(serializers.ModelSerializer):
    """
    Serializer for Booking model.
    Used for responses and GET requests.
    """
    
    booking_id = serializers.CharField(source="unique_id", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_name = serializers.CharField(source="user.name", read_only=True)
    
    class Meta:
        model = Booking
        fields = [
            "booking_id",
            "ground_id",
            "slot_id",
            "date",
            "status",
            "metadata",
            "created_at",
            "user_email",
            "user_name",
        ]
        read_only_fields = ["booking_id", "status", "created_at", "user_email", "user_name"]


class BookingCreateSerializer(serializers.Serializer):
    """
    Serializer for creating a new booking.
    Validates input and enforces business rules.
    """
    
    ground_id = serializers.IntegerField(min_value=1)
    slot_id = serializers.IntegerField(min_value=1)
    date = serializers.DateField()
    player_ids = serializers.ListField(
        child=serializers.IntegerField(min_value=1),
        required=False,
        allow_empty=True,
    )
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
        """Validate slot_id exists (placeholder - extend if Slot model available)."""
        if value < 1:
            raise serializers.ValidationError("Invalid slot ID.")
        return value
    
    def validate(self, attrs):
        """
        Cross-field validation.
        Combine player_ids into metadata if provided.
        """
        metadata = attrs.get("metadata", {})
        player_ids = attrs.pop("player_ids", None)
        
        if player_ids:
            metadata["player_ids"] = player_ids
        
        attrs["metadata"] = metadata
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
