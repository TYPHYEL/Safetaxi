// lib/core/error/failures.dart

import 'package:dio/dio.dart';

abstract class Failure {
  final String message;
  final int? code;

  const Failure({
    required this.message,
    this.code,
  });

  @override
  String toString() => 'Failure($code): $message';
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Erreur réseau',
    super.code,
  });
}

class AuthFailure extends Failure {
  const AuthFailure({
    super.message = 'Erreur d\'authentification',
    super.code,
  });
}

class ServerFailure extends Failure {
  const ServerFailure({
    super.message = 'Erreur serveur',
    super.code,
  });
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({
    super.message = 'Ressource introuvable',
    super.code = 404,
  });
}

class ValidationFailure extends Failure {
  final Map<String, List<String>> errors;

  const ValidationFailure({
    super.message = 'Données invalides',
    required this.errors,
  });
}

class PermissionFailure extends Failure {
  const PermissionFailure({
    super.message = 'Permission refusée',
    super.code = 403,
  });
}

class OfflineFailure extends Failure {
  const OfflineFailure({
    super.message = 'Pas de connexion internet',
  });
}

class GpsFailure extends Failure {
  const GpsFailure({
    super.message = 'Impossible d\'obtenir la position GPS',
  });
}

// ─────────────────────────────────────────────────────────
// Exception parser
// ─────────────────────────────────────────────────────────

Failure parseFailure(dynamic error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkFailure(
          message: 'Délai de connexion dépassé',
        );

      case DioExceptionType.connectionError:
        return const OfflineFailure();

      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        final data = error.response?.data;

        switch (status) {
          case 400:
            final errors = _extractErrors(data);

            return ValidationFailure(
              message: errors.isNotEmpty &&
                      errors.values.first.isNotEmpty
                  ? errors.values.first.first
                  : 'Données invalides',
              errors: errors,
            );

          case 401:
            return const AuthFailure(
              message: 'Session expirée, veuillez vous reconnecter',
            );

          case 403:
            return const PermissionFailure();

          case 404:
            return const NotFoundFailure();

          case 429:
            return const ServerFailure(
              message:
                  'Trop de requêtes, réessayez dans quelques instants',
            );

          default:
            return ServerFailure(
              message:
                  _extractMessage(data) ??
                  'Erreur serveur ($status)',
              code: status,
            );
        }

      case DioExceptionType.cancel:
        return const NetworkFailure(
          message: 'Requête annulée',
        );

      default:
        return NetworkFailure(
          message: error.message ?? 'Erreur réseau',
        );
    }
  }

  return ServerFailure(
    message: error.toString(),
  );
}

Map<String, List<String>> _extractErrors(dynamic data) {
  if (data is Map<String, dynamic>) {
    final result = <String, List<String>>{};

    for (final entry in data.entries) {
      if (entry.value is List) {
        result[entry.key] =
            (entry.value as List)
                .map((e) => e.toString())
                .toList();
      } else if (entry.value is String) {
        result[entry.key] = [entry.value as String];
      }
    }

    return result;
  }

  return {};
}

String? _extractMessage(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data['detail'] as String? ??
        data['message'] as String? ??
        data['error'] as String?;
  }

  return null;
}