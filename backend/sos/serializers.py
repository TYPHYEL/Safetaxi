from rest_framework import serializers
from .models import Incident


class IncidentSerializer(serializers.ModelSerializer):
    incident_type = serializers.CharField(write_only=True, required=False, allow_blank=True)
    trip_id = serializers.CharField(write_only=True, required=False, allow_blank=True)
    alert_type = serializers.CharField(write_only=True, required=False, allow_blank=True)

    class Meta:
        model = Incident
        fields = [
            'id',
            'user',
            'lat',
            'lng',
            'description',
            'status',
            'created_at',
            'incident_type',
            'trip_id',
            'alert_type',
        ]
        read_only_fields = ['id', 'user', 'created_at']

    def validate(self, attrs):
        if self.instance is None and not attrs.get('description') and not attrs.get('incident_type') and not attrs.get('alert_type'):
            raise serializers.ValidationError({
                'detail': 'At least one of description, incident_type, or alert_type is required.'
            })
        return attrs

    def create(self, validated_data):
        validated_data.pop('incident_type', None)
        validated_data.pop('trip_id', None)
        validated_data.pop('alert_type', None)
        return super().create(validated_data)
