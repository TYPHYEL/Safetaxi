from rest_framework import viewsets, status
from rest_framework.permissions import IsAuthenticated
from .models import Trip
from .serializers import TripSerializer
from users.permissions import IsDriver, IsOwnerOrAdmin
from rest_framework.decorators import action
from rest_framework.response import Response
from django.shortcuts import get_object_or_404
from channels.layers import get_channel_layer
from asgiref.sync import async_to_sync
import random
import string
from notifications.models import Device
from notifications import services as notify_service


class TripViewSet(viewsets.ModelViewSet):
    queryset = Trip.objects.all()
    serializer_class = TripSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return self.queryset
        if getattr(user, 'role', None) == 'driver':
            return self.queryset.filter(driver=user)
        return self.queryset.filter(passengers=user)

    def get_permissions(self):
        if self.action == 'create':
            return [IsDriver()]
        if self.action in ('update', 'partial_update', 'destroy'):
            return [IsOwnerOrAdmin()]
        return [IsAuthenticated()]

    def _generate_join_code(self, length=6):
        for _ in range(20):
            code = ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))
            if not Trip.objects.filter(join_code=code).exists():
                return code
        return ''.join(random.choices(string.ascii_uppercase + string.digits, k=length))

    def perform_create(self, serializer):
        serializer.save(driver=self.request.user, join_code=self._generate_join_code())

    def _join_trip(self, trip, user):
        if not trip:
            return Response({'detail': 'Trip not found'}, status=status.HTTP_404_NOT_FOUND)
        if user == trip.driver:
            return Response({'detail': 'Driver cannot join as passenger'}, status=status.HTTP_400_BAD_REQUEST)
        if trip.passengers.filter(id=user.id).exists():
            return Response(TripSerializer(trip).data)
        taxi = trip.taxi
        if taxi and taxi.capacity is not None and trip.passengers.count() >= taxi.capacity:
            return Response({'detail': 'Trip is full'}, status=status.HTTP_400_BAD_REQUEST)
        trip.passengers.add(user)
        trip.save()
        return Response(TripSerializer(trip).data)

    @action(detail=False, methods=['post'])
    def join_by_code(self, request):
        code = request.data.get('join_code')
        if not code:
            return Response({'detail': 'join_code required'}, status=status.HTTP_400_BAD_REQUEST)
        trip = get_object_or_404(Trip, join_code=code, status='pending')
        return self._join_trip(trip, request.user)

    @action(detail=True, methods=['post'])
    def join(self, request, pk=None):
        trip = get_object_or_404(Trip, pk=pk, status='pending')
        return self._join_trip(trip, request.user)

    @action(detail=True, methods=['post'])
    def leave(self, request, pk=None):
        trip = self.get_object()
        user = request.user
        trip.passengers.remove(user)
        trip.save()
        return Response(TripSerializer(trip).data)

    @action(detail=True, methods=['post'])
    def start(self, request, pk=None):
        trip = self.get_object()
        if request.user != trip.driver:
            return Response({'detail': 'Only driver can start the trip'}, status=status.HTTP_403_FORBIDDEN)
        if trip.status != 'pending':
            return Response({'detail': 'Trip cannot be started'}, status=status.HTTP_400_BAD_REQUEST)
        trip.status = 'active'
        import django.utils.timezone as tz
        trip.started_at = tz.now()
        trip.save()
        try:
            passenger_qs = trip.passengers.all()
            tokens = list(Device.objects.filter(user__in=passenger_qs).values_list('token', flat=True))
            if tokens:
                title = 'Trip started'
                body = f'Driver {trip.driver.username} a démarré le trajet.'
                notify_service.send_multicast(tokens, title, body, data={'trip_id': str(trip.id)})
        except Exception:
            pass
        return Response(TripSerializer(trip).data)

    @action(detail=True, methods=['post'])
    def end(self, request, pk=None):
        trip = self.get_object()
        if request.user != trip.driver:
            return Response({'detail': 'Only driver can end the trip'}, status=status.HTTP_403_FORBIDDEN)
        if trip.status != 'active':
            return Response({'detail': 'Trip cannot be ended'}, status=status.HTTP_400_BAD_REQUEST)
        trip.status = 'completed'
        import django.utils.timezone as tz
        trip.ended_at = tz.now()
        trip.save()
        return Response(TripSerializer(trip).data)

    @action(detail=True, methods=['post'])
    def location(self, request, pk=None):
        trip = self.get_object()
        if request.user != trip.driver:
            return Response({'detail': 'Only driver can update location'}, status=status.HTTP_403_FORBIDDEN)
        lat = request.data.get('lat')
        lng = request.data.get('lng')
        payload = {'lat': lat, 'lng': lng, 'trip_id': trip.id}
        channel_layer = get_channel_layer()
        async_to_sync(channel_layer.group_send)(f'trip_{trip.id}', {'type': 'location.message', 'payload': payload})
        if lat is not None and lng is not None:
            trip.current_lat = lat
            trip.current_lng = lng
            trip.save()
        return Response({'detail': 'location broadcasted'})

    @action(detail=False, methods=['get'])
    def history(self, request):
        """Get trip history for current user"""
        user = request.user
        from django.db.models import Q
        trips = self.queryset.filter(Q(driver=user) | Q(passengers=user)).order_by('-created_at')
        page = int(request.query_params.get('page', 1))
        page_size = 20
        start = (page - 1) * page_size
        end = start + page_size
        serializer = TripSerializer(trips[start:end], many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['get'])
    def active(self, request):
        """Get active trip for current user"""
        user = request.user
        if getattr(user, 'role', None) == 'driver':
            trip = self.queryset.filter(driver=user, status='active').first()
        else:
            trip = self.queryset.filter(passengers=user, status='active').first()
        if trip:
            return Response(TripSerializer(trip).data)
        return Response({})

    @action(detail=True, methods=['get'])
    def passengers(self, request, pk=None):
        """Get passengers list for a trip"""
        trip = self.get_object()
        from users.serializers import UserSerializer
        serializer = UserSerializer(trip.passengers.all(), many=True)
        return Response(serializer.data)
