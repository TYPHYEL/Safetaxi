from django.db import models
from django.conf import settings
from django.utils import timezone
from taxis.models import Taxi


class Trip(models.Model):
    STATUS_CHOICES = (
        ('pending', 'Pending'),
        ('active', 'Active'),
        ('completed', 'Completed'),
        ('cancelled', 'Cancelled'),
    )
    taxi = models.ForeignKey(Taxi, on_delete=models.SET_NULL, null=True, related_name='trips')
    driver = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, related_name='driven_trips')
    passengers = models.ManyToManyField(settings.AUTH_USER_MODEL, related_name='trips', blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default='pending')
    join_code = models.CharField(max_length=8, unique=True, blank=True, null=True)
    start_location = models.CharField(max_length=255, blank=True, null=True)
    end_location = models.CharField(max_length=255, blank=True, null=True)
    start_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    start_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    current_lat = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    current_lng = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    estimated_duration = models.IntegerField(null=True, blank=True, help_text='Duration in minutes')
    fare = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    started_at = models.DateTimeField(null=True, blank=True)
    ended_at = models.DateTimeField(null=True, blank=True)
    created_at = models.DateTimeField(default=timezone.now)

    def __str__(self):
        return f"Trip {self.id} ({self.status})"
