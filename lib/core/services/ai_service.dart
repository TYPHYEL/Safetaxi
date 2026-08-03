// lib/core/services/ai_service.dart
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:logger/logger.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// Service IA basé sur Qwen API pour :
/// - Assistant conversationnel SafeTaxi
/// - Analyse de risque en temps réel
/// - Détection d'anomalies
/// - Recommandations de sécurité
class AiService {
  final Dio _dio;

  AiService() : _dio = Dio(BaseOptions(
    baseUrl: AppConstants.qwenBaseUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer ${AppConstants.qwenApiKey}',
    },
  ));

  // ─── Chat avec l'assistant SafeTaxi ───────────────────

  Future<String> chat(List<AiMessage> messages) async {
    try {
      final body = {
        'model': 'qwen-turbo',
        'messages': messages.map((m) => m.toJson()).toList(),
        'temperature': 0.7,
        'max_tokens': 500,
      };

      final resp = await _dio.post('/chat/completions', data: body);
      final choices = resp.data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        return 'Je suis désolé, je n\'ai pas pu générer de réponse.';
      }
      return choices[0]['message']['content'] as String;
    } catch (e) {
      _log.e('Qwen chat failed: $e');
      return _getOfflineResponse(messages.last.content);
    }
  }

  // ─── Analyse de risque d'un trajet ─────────────────────
  ///
  /// Retourne un score de risque (0-100) basé sur :
  /// - Heure du trajet
  /// - Zone géographique
  /// - Historique des incidents
  /// - Comportement du chauffeur
  Future<RiskAnalysis> analyzeRisk({
    required double lat,
    required double lng,
    required int hour,
    required int dayOfWeek,
    String? taxiId,
    String? driverId,
  }) async {
    try {
      final messages = [
        const AiMessage(
          role: 'system',
          content: '''Tu es un expert en sécurité urbaine pour les taxis à Yaoundé, Cameroun.
Analyse les risques et donne un score de 0 (très sûr) à 100 (très dangereux).
Réponds UNIQUEMENT au format JSON :
{
  "score": 0-100,
  "niveau": "faible|moyen|eleve",
  "conseils": ["conseil1", "conseil2"],
  "zone": "nom du quartier"
}''',
        ),
        AiMessage(
          role: 'user',
          content: '''
Analyser le risque pour un trajet à Yaoundé:
- Position: $lat, $lng
- Heure: ${hour}h
- Jour: $dayOfWeek
- Taxi: $taxiId
- Chauffeur: $driverId''',
        ),
      ];

      final response = await chat(messages);
      return RiskAnalysis.fromQwenResponse(response);
    } catch (e) {
      _log.e('Risk analysis failed: $e');
      return RiskAnalysis.defaultAnalysis(lat, lng);
    }
  }

  // ─── Recommandations de sécurité ───────────────────────

  Future<List<String>> getSafetyTips(String context) async {
    try {
      final messages = [
        const AiMessage(
          role: 'system',
          content: 'Tu es un assistant sécurité SafeTaxi. Donne 3 conseils courts et pratiques.',
        ),
        AiMessage(role: 'user', content: context),
      ];

      final response = await chat(messages);
      return response
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .take(3)
          .map((l) => l.replaceFirst(RegExp(r'^[\d\.\-\*\•]+\s*'), '').trim())
          .toList();
    } catch (_) {
      return [
        'Vérifiez toujours le QR code du taxi avant de monter.',
        'Partagez votre position avec un proche.',
        'Restez attentif pendant le trajet.',
      ];
    }
  }

  // ─── Réponses offline quand l'API échoue ─────────────

  String _getOfflineResponse(String question) {
    final q = question.toLowerCase();
    if (q.contains('sos') || q.contains('urgence')) {
      return 'Pour une urgence, appuyez sur le bouton SOS et maintenez 3 secondes. '
          'Votre position sera envoyée à vos contacts et à SafeTaxi.';
    }
    if (q.contains('qr') || q.contains('scan')) {
      return 'Pour scanner un taxi, appuyez sur "Scanner un taxi" dans l\'accueil, '
          'puis dirigez la caméra vers le QR code à l\'intérieur du véhicule.';
    }
    if (q.contains('trust') || q.contains('score')) {
      return 'Le Trust Score reflète votre fiabilité (notes + trajets + ancienneté). '
          'Maintenez un score élevé en ayant des trajets sans incident.';
    }
    return 'Je suis l\'assistant SafeTaxi. Comment puis-je vous aider ? '
        'Essayez de poser une question sur la sécurité, les taxis, ou l\'application.';
  }
}

// ─── Modèle message IA ─────────────────────────────────

class AiMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  const AiMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

// ─── Modèle analyse de risque ─────────────────────────────

class RiskAnalysis {
  final int score; // 0-100
  final String niveau; // 'faible' | 'moyen' | 'eleve'
  final List<String> conseils;
  final String zone;

  const RiskAnalysis({
    required this.score,
    required this.niveau,
    required this.conseils,
    required this.zone,
  });

  factory RiskAnalysis.fromQwenResponse(String jsonStr) {
    try {
      // Parser la réponse JSON de Qwen
      final cleaned = jsonStr
          .replaceFirst(RegExp(r'^```json\s*'), '')
          .replaceFirst(RegExp(r'^```\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '')
          .trim();
      final map = jsonDecode(cleaned) as Map<String, dynamic>;
      return RiskAnalysis(
        score: (map['score'] as num).toInt().clamp(0, 100),
        niveau: map['niveau'] as String? ?? 'moyen',
        conseils: (map['conseils'] as List<dynamic>?)
                ?.cast<String>() ??
            [],
        zone: map['zone'] as String? ?? 'Yaoundé',
      );
    } catch (_) {
      return const RiskAnalysis(
        score: 30,
        niveau: 'moyen',
        conseils: ['Restez vigilant', 'Gardez votre téléphone accessible'],
        zone: 'Yaoundé',
      );
    }
  }

  factory RiskAnalysis.defaultAnalysis(double lat, double lng) {
    return const RiskAnalysis(
      score: 30,
      niveau: 'moyen',
      conseils: ['Restez vigilant', 'Gardez votre téléphone accessible'],
      zone: 'Yaoundé',
    );
  }
}

// ─── Provider ─────────────────────────────────────────

final aiServiceProvider = Provider<AiService>((ref) => AiService());
