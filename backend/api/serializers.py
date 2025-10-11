"""
Serializers for API endpoints
"""
from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import (
    SportsType, Ground, TimeSlot, Booking, 
    Team, TeamRequest, Notification, BookingQueue
)

User = get_user_model()


class UserSerializer(serializers.ModelSerializer):
    """Serializer for User model"""
    password = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'first_name', 'last_name',
            'user_type', 'phone_number', 'roll_number', 'department',
            'fcm_token', 'password', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def create(self, validated_data):
        password = validated_data.pop('password', None)
        user = User(**validated_data)
        if password:
            user.set_password(password)
        user.save()
        return user

    def update(self, instance, validated_data):
        password = validated_data.pop('password', None)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance


class SportsTypeSerializer(serializers.ModelSerializer):
    """Serializer for SportsType model"""
    class Meta:
        model = SportsType
        fields = ['id', 'name', 'description', 'icon', 'is_active', 'created_at', 'updated_at']
        read_only_fields = ['id', 'created_at', 'updated_at']


class TimeSlotSerializer(serializers.ModelSerializer):
    """Serializer for TimeSlot model"""
    class Meta:
        model = TimeSlot
        fields = ['id', 'ground', 'start_time', 'end_time', 'is_available']
        read_only_fields = ['id']


class GroundSerializer(serializers.ModelSerializer):
    """Serializer for Ground model"""
    sports_type_detail = SportsTypeSerializer(source='sports_type', read_only=True)
    time_slots = TimeSlotSerializer(many=True, read_only=True)

    class Meta:
        model = Ground
        fields = [
            'id', 'name', 'location', 'sports_type', 'sports_type_detail',
            'capacity', 'description', 'image', 'is_available', 'amenities',
            'time_slots', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class BookingSerializer(serializers.ModelSerializer):
    """Serializer for Booking model"""
    user_detail = UserSerializer(source='user', read_only=True)
    ground_detail = GroundSerializer(source='ground', read_only=True)
    time_slot_detail = TimeSlotSerializer(source='time_slot', read_only=True)

    class Meta:
        model = Booking
        fields = [
            'id', 'user', 'user_detail', 'ground', 'ground_detail',
            'time_slot', 'time_slot_detail', 'booking_date', 'status',
            'purpose', 'number_of_players', 'queue_position',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'queue_position', 'created_at', 'updated_at']


class TeamSerializer(serializers.ModelSerializer):
    """Serializer for Team model"""
    captain_detail = UserSerializer(source='captain', read_only=True)
    sports_type_detail = SportsTypeSerializer(source='sports_type', read_only=True)
    members_detail = UserSerializer(source='members', many=True, read_only=True)
    member_count = serializers.SerializerMethodField()

    class Meta:
        model = Team
        fields = [
            'id', 'name', 'sports_type', 'sports_type_detail', 'captain',
            'captain_detail', 'members', 'members_detail', 'member_count',
            'max_members', 'description', 'logo', 'is_active',
            'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']

    def get_member_count(self, obj):
        return obj.members.count()


class TeamRequestSerializer(serializers.ModelSerializer):
    """Serializer for TeamRequest model"""
    team_detail = TeamSerializer(source='team', read_only=True)
    user_detail = UserSerializer(source='user', read_only=True)

    class Meta:
        model = TeamRequest
        fields = [
            'id', 'team', 'team_detail', 'user', 'user_detail',
            'status', 'message', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']


class NotificationSerializer(serializers.ModelSerializer):
    """Serializer for Notification model"""
    class Meta:
        model = Notification
        fields = [
            'id', 'user', 'notification_type', 'title', 'message',
            'is_read', 'data', 'sent_at'
        ]
        read_only_fields = ['id', 'sent_at']


class BookingQueueSerializer(serializers.ModelSerializer):
    """Serializer for BookingQueue model"""
    booking_detail = BookingSerializer(source='booking', read_only=True)

    class Meta:
        model = BookingQueue
        fields = [
            'id', 'booking', 'booking_detail', 'position',
            'estimated_wait_time', 'notified', 'created_at', 'updated_at'
        ]
        read_only_fields = ['id', 'created_at', 'updated_at']
