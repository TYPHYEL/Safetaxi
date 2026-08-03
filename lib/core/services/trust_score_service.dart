// lib/core/services/trust_score_service.dart

/// Service de calcul dynamique du Trust Score
/// 
/// Le Trust Score est calculé sur une échelle de 0 à 5 basé sur:
/// - Historique des notations reçues
/// - Incidents signalés
/// - Complétion des trajets
/// - Vérification de l'identité
/// - Ancienneté sur la plateforme
class TrustScoreService {
  /// Calcule le Trust Score d'un utilisateur
  double calculateTrustScore({
    required List<double> ratingsReceived,
    required int totalTrips,
    required int incidentsReported,
    required bool isVerified,
    required DateTime joinedAt,
    required int cancelledTrips,
  }) {
    double score = 3.0; // Score de base

    // 1. Moyenne des notations (poids: 40%)
    if (ratingsReceived.isNotEmpty) {
      final avgRating = ratingsReceived.reduce((a, b) => a + b) / ratingsReceived.length;
      // Convertir notation 1-5 en impact sur score
      final ratingImpact = (avgRating - 3) * 0.4;
      score += ratingImpact;
    }

    // 2. Incidents signalés (poids: -25% par incident, max -50%)
    final incidentPenalty = (incidentsReported * 0.25).clamp(0.0, 0.5);
    score -= incidentPenalty;

    // 3. Vérification identité (poids: +0.5)
    if (isVerified) {
      score += 0.5;
    }

    // 4. Ancienneté (poids: +0.3 par année, max +0.6)
    final yearsSinceJoin = DateTime.now().difference(joinedAt).inDays / 365;
    final seniorityBonus = (yearsSinceJoin * 0.3).clamp(0.0, 0.6);
    score += seniorityBonus;

    // 5. Taux d'annulation (poids: -20% si > 10%)
    if (totalTrips > 0) {
      final cancellationRate = cancelledTrips / totalTrips;
      if (cancellationRate > 0.1) {
        score -= 0.2;
      }
    }

    // 6. Bonus pour trajets complétés (poids: +0.1 tous les 50 trajets, max +0.3)
    if (totalTrips >= 50) {
      final tripBonus = (totalTrips / 50 * 0.1).clamp(0.0, 0.3);
      score += tripBonus;
    }

    // Clamp entre 0 et 5
    return score.clamp(0.0, 5.0);
  }

  /// Calcule le Trust Score d'un chauffeur avec facteurs spécifiques
  double calculateDriverTrustScore({
    required List<double> ratingsReceived,
    required int totalTrips,
    required int incidentsReported,
    required bool isVerified,
    required bool biometricVerified,
    required DateTime joinedAt,
    required int cancelledTrips,
    required int onTimeArrivals,
    required double responseRate,
  }) {
    double score = calculateTrustScore(
      ratingsReceived: ratingsReceived,
      totalTrips: totalTrips,
      incidentsReported: incidentsReported,
      isVerified: isVerified,
      joinedAt: joinedAt,
      cancelledTrips: cancelledTrips,
    );

    // Facteurs spécifiques chauffeurs

    // Biométrie vérifiée (+0.3)
    if (biometricVerified) {
      score += 0.3;
    }

    // Ponctualité (+0.2 si > 80% à l'heure)
    if (totalTrips > 0 && onTimeArrivals / totalTrips > 0.8) {
      score += 0.2;
    }

    // Taux de réponse (+0.15 si > 90%)
    if (responseRate > 0.9) {
      score += 0.15;
    }

    return score.clamp(0.0, 5.0);
  }

  /// Calcule le Trust Score d'un passager avec facteurs spécifiques
  double calculatePassengerTrustScore({
    required List<double> ratingsReceived,
    required int totalTrips,
    required int incidentsReported,
    required bool isVerified,
    required DateTime joinedAt,
    required int cancelledTrips,
    required int noShows,
  }) {
    double score = calculateTrustScore(
      ratingsReceived: ratingsReceived,
      totalTrips: totalTrips,
      incidentsReported: incidentsReported,
      isVerified: isVerified,
      joinedAt: joinedAt,
      cancelledTrips: cancelledTrips,
    );

    // Facteurs spécifiques passagers

    // No-shows (-0.25 si > 10%)
    if (totalTrips > 0 && noShows / totalTrips > 0.1) {
      score -= 0.25;
    }

    return score.clamp(0.0, 5.0);
  }

  /// Obtient le niveau de confiance basé sur le score
  String getTrustLevel(double score) {
    if (score >= 4.5) return 'Excellent';
    if (score >= 4.0) return 'Très bon';
    if (score >= 3.5) return 'Bon';
    if (score >= 3.0) return 'Moyen';
    if (score >= 2.0) return 'Faible';
    return 'Très faible';
  }

  /// Obtient la couleur associée au niveau de confiance
  String getTrustLevelColor(double score) {
    if (score >= 4.0) return '#00C896'; // Vert
    if (score >= 3.0) return '#FFB800'; // Jaune
    if (score >= 2.0) return '#FF6B00'; // Orange
    return '#FF3B30'; // Rouge
  }

  /// Analyse les facteurs influençant le score
  Map<String, dynamic> analyzeScoreFactors({
    required double currentScore,
    required List<double> ratingsReceived,
    required int incidentsReported,
    required bool isVerified,
    required DateTime joinedAt,
  }) {
    final factors = <String, dynamic>{};

    // Analyse des notations
    if (ratingsReceived.isNotEmpty) {
      final avgRating = ratingsReceived.reduce((a, b) => a + b) / ratingsReceived.length;
      factors['avg_rating'] = avgRating;
      factors['rating_impact'] = avgRating >= 4.0 ? 'Positif' : avgRating >= 3.0 ? 'Neutre' : 'Négatif';
    }

    // Analyse des incidents
    if (incidentsReported > 0) {
      factors['incidents'] = incidentsReported;
      factors['incident_impact'] = 'Négatif';
    }

    // Analyse de la vérification
    factors['verified'] = isVerified;
    factors['verification_impact'] = isVerified ? 'Positif' : 'Neutre';

    // Analyse de l'ancienneté
    final daysSinceJoin = DateTime.now().difference(joinedAt).inDays;
    factors['days_since_join'] = daysSinceJoin;
    factors['seniority_impact'] = daysSinceJoin > 365 ? 'Positif' : 'Neutre';

    // Recommandations
    final recommendations = <String>[];
    if (ratingsReceived.isNotEmpty) {
      final avgRating = ratingsReceived.reduce((a, b) => a + b) / ratingsReceived.length;
      if (avgRating < 3.5) {
        recommendations.add('Améliorez la qualité de service');
      }
    }
    if (incidentsReported > 0) {
      recommendations.add('Évitez les incidents');
    }
    if (!isVerified) {
      recommendations.add('Complétez la vérification');
    }
    if (daysSinceJoin < 30) {
      recommendations.add('Gagnez en expérience');
    }

    factors['recommendations'] = recommendations;
    factors['current_level'] = getTrustLevel(currentScore);

    return factors;
  }
}
