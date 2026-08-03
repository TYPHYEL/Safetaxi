from math import asin, cos, radians, sin, sqrt

from drf_spectacular.utils import OpenApiParameter, extend_schema
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response

from users.permissions import IsDriverOrOwner, IsOwnerOrAdmin

from .models import Taxi
from .serializers import TaxiSerializer
import time


class TaxiViewSet(viewsets.ModelViewSet):
    queryset = Taxi.objects.all()
    serializer_class = TaxiSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(owner=self.request.user)

    def get_permissions(self):
        # Allow only drivers/owners to create taxis, and owners/admins to modify
        if self.action == 'create':
            return [IsDriverOrOwner()]
        if self.action in ('update', 'partial_update', 'destroy'):
            return [IsOwnerOrAdmin()]
        return [IsAuthenticated()]

    def _distance_km(self, lat1, lng1, lat2, lng2):
        lat1_rad, lng1_rad = radians(lat1), radians(lng1)
        lat2_rad, lng2_rad = radians(lat2), radians(lng2)
        dlon = lng2_rad - lng1_rad
        dlat = lat2_rad - lat1_rad
        a = sin(dlat / 2) ** 2 + cos(lat1_rad) * cos(lat2_rad) * sin(dlon / 2) ** 2
        c = 2 * asin(sqrt(a))
        return 6371 * c

    @action(detail=True, methods=['post'])
    def suspend(self, request, pk=None):
        # Admin-only suspend taxi
        if not request.user.is_staff:
            return Response({'detail': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)
        taxi = self.get_object()
        taxi.is_active = False
        taxi.save()
        return Response({'detail': 'Taxi suspended'})

    @action(detail=True, methods=['post'])
    def activate(self, request, pk=None):
        if not request.user.is_staff:
            return Response({'detail': 'Forbidden'}, status=status.HTTP_403_FORBIDDEN)
        taxi = self.get_object()
        taxi.is_active = True
        taxi.save()
        return Response({'detail': 'Taxi activated'})

    @extend_schema(
        summary='Lister les taxis proches',
        description='Retourne les taxis actifs dans un rayon donné autour des coordonnées fournies.',
        parameters=[
            OpenApiParameter(name='lat', type=float, required=True, description='Latitude de référence'),
            OpenApiParameter(name='lng', type=float, required=True, description='Longitude de référence'),
            OpenApiParameter(name='radius', type=float, required=False, description='Rayon en kilomètres'),
        ],
        responses={200: TaxiSerializer(many=True)},
    )
    @action(detail=False, methods=['get'])
    def nearby(self, request):
        """Get taxis nearby based on lat/lng and radius"""
        lat = request.query_params.get('lat')
        lng = request.query_params.get('lng')

        if not lat or not lng:
            return Response({'detail': 'lat and lng required'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            lat = float(lat)
            lng = float(lng)
            radius = float(request.query_params.get('radius', 2.0))
        except ValueError:
            return Response({'detail': 'Invalid lat/lng or radius'}, status=status.HTTP_400_BAD_REQUEST)

        if radius <= 0 or radius > 50:
            return Response(
                {'detail': 'radius must be between 0 and 50 km'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Bounding box to avoid scanning the entire table before the haversine refinement.
        lat_delta = radius / 111.0
        lng_delta = radius / (111.0 * max(cos(radians(lat)), 0.1))

        candidates = Taxi.objects.filter(
            is_active=True,
            last_lat__gte=lat - lat_delta,
            last_lat__lte=lat + lat_delta,
            last_lng__gte=lng - lng_delta,
            last_lng__lte=lng + lng_delta,
        )

        nearby_taxis = []
        for taxi in candidates:
            if taxi.last_lat is None or taxi.last_lng is None:
                continue
            km = self._distance_km(lat, lng, float(taxi.last_lat), float(taxi.last_lng))
            if km <= radius:
                nearby_taxis.append((km, taxi))

        nearby_taxis.sort(key=lambda item: item[0])
        taxis = [taxi for _, taxi in nearby_taxis]
        serializer = TaxiSerializer(taxis, many=True)
        return Response(serializer.data)

    @action(detail=True, methods=['get'])
    def qrcode(self, request, pk=None):
        """Generate QR code data for taxi"""
        taxi = self.get_object()
        # Format: safetaxi:{taxi_id}:{timestamp}
        qr_data = f"safetaxi:{pk}:{int(time.time())}"
        return Response({'qr_data': qr_data, 'taxi_id': pk})
