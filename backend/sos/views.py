from rest_framework import viewsets
from rest_framework.permissions import IsAuthenticated, IsAdminUser
from .models import Incident
from .serializers import IncidentSerializer
from users.permissions import IsAdminOrReadOnly


class IncidentViewSet(viewsets.ModelViewSet):
    queryset = Incident.objects.all()
    serializer_class = IncidentSerializer
    permission_classes = [IsAuthenticated]

    def perform_create(self, serializer):
        serializer.save(user=self.request.user)

    def get_permissions(self):
        if self.action == 'list':
            return [IsAdminUser()]
        if self.action in ('partial_update', 'update', 'destroy'):
            return [IsAdminOrReadOnly()]
        return [IsAuthenticated()]
