// lib/shared/widgets/safe_avatar.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class SafeAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double size;
  final Color? borderColor;
  final VoidCallback? onTap;

  const SafeAvatar({
    super.key,
    this.photoUrl,
    required this.initials,
    this.size = 44,
    this.borderColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? AppColors.border,
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: photoUrl != null && photoUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => _initials(),
                  errorWidget: (_, __, ___) => _initials(),
                )
              : _initials(),
        ),
      ),
    );
  }

  Widget _initials() => Container(
        color: AppColors.surfaceElevated,
        child: Center(
          child: Text(
            initials.toUpperCase(),
            style: TextStyle(
              fontSize: size * 0.33,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────
// lib/shared/widgets/trust_badge.dart

class TrustBadge extends StatelessWidget {
  final double score;
  final bool large;

  const TrustBadge({super.key, required this.score, this.large = false});

  Color get _color {
    if (score >= 4.0) return AppColors.primary;
    if (score >= 2.5) return AppColors.warning;
    return AppColors.danger;
  }

  String get _label {
    if (score >= 4.0) return 'Fiable';
    if (score >= 2.5) return 'Moyen';
    return 'Faible';
  }

  IconData get _icon {
    if (score >= 4.0) return Icons.verified_rounded;
    if (score >= 2.5) return Icons.warning_amber_rounded;
    return Icons.dangerous_rounded;
  }

  @override
  Widget build(BuildContext context) {
    if (large) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_icon, color: _color, size: 28),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, color: _color, size: 12),
          const SizedBox(width: 3),
          Text(
            _label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
