from rest_framework import serializers
from django.utils import timezone
from .models import Event


class EventCreateSerializer(serializers.ModelSerializer):
    """Serializer for creating a new event with all required fields"""
    
    class Meta:
        model = Event
        fields = [
            "id", "sport_id", "poster_id",
            "title", "description", "location_text",
            "starts_at", "ends_at",
            "organizer_name", "organizer_contact",
        ]
        read_only_fields = ["id"]
    
    def validate(self, data):
        """Validate event dates"""
        starts_at = data.get("starts_at")
        ends_at = data.get("ends_at")
        
        # Ensure starts_at is in the future
        if starts_at and starts_at <= timezone.now():
            raise serializers.ValidationError({
                "starts_at": "Event start time must be in the future."
            })
        
        # Ensure ends_at is after starts_at
        if starts_at and ends_at and ends_at <= starts_at:
            raise serializers.ValidationError({
                "ends_at": "Event end time must be after start time."
            })
        
        return data

    def create(self, validated_data):
        """Attach the authenticated user as creator"""
        req = self.context.get("request")
        if req and req.user and req.user.is_authenticated:
            validated_data["created_by"] = req.user
            # Auto-set organizer_name from user if not provided
            if not validated_data.get("organizer_name"):
                validated_data["organizer_name"] = req.user.get_full_name() or req.user.email
        return super().create(validated_data)


class EventListSerializer(serializers.ModelSerializer):
    """Serializer for listing events on home page (optimized for poster display)"""
    is_completed = serializers.SerializerMethodField()
    days_until_start = serializers.SerializerMethodField()
    
    class Meta:
        model = Event
        fields = [
            "id", "sport_id", "title",
            "poster_id", "starts_at", "ends_at", "location_text",
            "status", "is_completed", "days_until_start"
        ]
    
    def get_is_completed(self, obj):
        """Return whether event has ended"""
        return obj.is_completed()
    
    def get_days_until_start(self, obj):
        """Return days until event starts"""
        return obj.days_until_start()


class EventDetailSerializer(serializers.ModelSerializer):
    """Serializer for detailed event view with all information"""
    is_completed = serializers.SerializerMethodField()
    creator_name = serializers.SerializerMethodField()
    
    class Meta:
        model = Event
        fields = [
            "id", "sport_id", "title",
            "poster_id", "description", "location_text",
            "starts_at", "ends_at",
            "organizer_name", "organizer_contact",
            "status", "is_completed",
            "creator_name", "created_at", "updated_at"
        ]
    
    def get_is_completed(self, obj):
        """Return whether event has ended"""
        return obj.is_completed()
    
    def get_creator_name(self, obj):
        """Return creator's name if available"""
        if obj.created_by:
            return obj.created_by.get_full_name() or obj.created_by.email
        return None


# Poster selection is handled entirely by frontend
# Backend only stores poster_id as a string identifier
