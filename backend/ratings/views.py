from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated
from rest_framework.decorators import action
from rest_framework.response import Response
from django.db import models
from .models import Rating
from .serializers import RatingSerializer


class RatingViewSet(viewsets.ModelViewSet):
    queryset = Rating.objects.all()
    serializer_class = RatingSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        if user.is_staff:
            return self.queryset
        return self.queryset.filter(rater=user) | self.queryset.filter(ratee=user)

    def perform_create(self, serializer):
        serializer.save(rater=self.request.user)

    def create(self, request, *args, **kwargs):
        # Prevent double-rating for same rater->ratee on the same trip
        ratee = request.data.get('ratee')
        trip = request.data.get('trip')
        if ratee and trip:
            exists = Rating.objects.filter(rater=request.user, ratee_id=ratee, trip_id=trip).exists()
            if exists:
                from rest_framework.response import Response
                from rest_framework import status
                return Response({'detail': 'You have already rated this user for this trip.'}, status=status.HTTP_400_BAD_REQUEST)
        return super().create(request, *args, **kwargs)

    @action(detail=False, methods=['get'])
    def my_score(self, request):
        """Calculate trust score for current user"""
        user = request.user
        ratings_received = Rating.objects.filter(ratee=user)
        
        if not ratings_received.exists():
            return Response({'trust_score': 3.0, 'level': 'Moyen', 'ratings_count': 0})
        
        # Calculate average rating
        avg_rating = ratings_received.aggregate(models.Avg('score'))['score__avg'] or 3.0
        
        # Calculate trust score (0-5 scale based on ratings)
        trust_score = min(5.0, max(0.0, avg_rating))
        
        # Determine level
        if trust_score >= 4.5:
            level = 'Excellent'
        elif trust_score >= 4.0:
            level = 'Très bon'
        elif trust_score >= 3.5:
            level = 'Bon'
        elif trust_score >= 3.0:
            level = 'Moyen'
        elif trust_score >= 2.0:
            level = 'Faible'
        else:
            level = 'Très faible'
        
        return Response({
            'trust_score': round(trust_score, 2),
            'level': level,
            'ratings_count': ratings_received.count(),
            'average_rating': round(avg_rating, 2),
        })
