from rest_framework import serializers
from .models import Trip


class TripSerializer(serializers.ModelSerializer):
    class Meta:
        model = Trip
        fields = ['id', 'taxi', 'driver', 'passengers', 'status', 'join_code', 'start_lat', 'start_lng', 'current_lat', 'current_lng', 'started_at', 'ended_at', 'created_at']
        read_only_fields = ['driver', 'status', 'join_code', 'started_at', 'ended_at', 'created_at']
