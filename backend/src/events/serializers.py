from rest_framework import serializers
from .models import Event

class EventCreateSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = [
            "id", "sport_id", "poster_id",
            "title", "description", "location_text",
            "starts_at", "organizer_contact",
        ]

    def create(self, validated_data):
        req = self.context.get("request")
        if req and req.user and req.user.is_authenticated:
            validated_data["created_by"] = req.user
        return super().create(validated_data)


class EventListSerializer(serializers.ModelSerializer):
    class Meta:
        model = Event
        fields = [
            "id", "sport_id", "title",
            "starts_at", "location_text", "poster_id"
        ]


class EventDetailSerializer(EventListSerializer):
    class Meta(EventListSerializer.Meta):
        fields = EventListSerializer.Meta.fields + [
            "description", "organizer_contact", "status", "created_at"
        ]
