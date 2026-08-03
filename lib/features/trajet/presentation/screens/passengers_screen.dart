// lib/features/trajet/presentation/screens/passengers_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:safetaxi_cameroun/features/trajet/presentation/providers/trajet_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;

class PassengersScreen extends ConsumerWidget {
  final String tripId;
  const PassengersScreen({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final passengersAsync =
        ref.watch(tripPassengersStreamProvider(tripId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Passagers à bord'),
        actions: [
          passengersAsync.when(
            data: (list) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: _CountBadge(count: list.length),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: passengersAsync.when(
        data: (passengers) => _buildList(context, passengers),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wifi_off_rounded,
                  color: AppColors.textMuted, size: 48),
              SizedBox(height: 12),
              Text('Impossible de charger les passagers',
                  style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(BuildContext ctx, List<LivePassenger> passengers) {
    if (passengers.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: AppColors.surfaceElevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  color: AppColors.textMuted, size: 48),
            ),
            const SizedBox(height: 20),
            const Text('Aucun passager à bord',
                style: AppTextStyles.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Le taxi est vide pour l\'instant',
              style: AppTextStyles.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Info confidentialité
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primarySurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.privacy_tip_outlined,
                  color: AppColors.primary, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Par souci de confidentialité, seuls le prénom '
                  'et la photo sont affichés.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Titre
        Text(
          '${passengers.length} passager${passengers.length > 1 ? 's' : ''} à bord',
          style: AppTextStyles.titleLarge,
        ),
        const SizedBox(height: 14),

        // Liste
        ...passengers.asMap().entries.map(
              (e) => _PassengerCard(
                passenger: e.value,
                index: e.key + 1,
              ),
            ),
      ],
    );
  }
}

class _PassengerCard extends StatelessWidget {
  final LivePassenger passenger;
  final int index;
  const _PassengerCard({required this.passenger, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          // Numéro
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Center(
              child: Text(
                '$index',
                style: AppTextStyles.labelMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Photo
          _PassengerAvatar(
            photoUrl: passenger.photoUrl,
            firstName: passenger.firstName,
            isVerified: passenger.isVerified,
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      passenger.firstName,
                      style: AppTextStyles.titleMedium,
                    ),
                    if (passenger.isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified_rounded,
                          color: AppColors.primary, size: 16),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Monté ${timeago.format(passenger.boardedAt, locale: 'fr')}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),

          // Badge trust
          if (passenger.isVerified)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_rounded,
                      color: AppColors.primary, size: 12),
                  const SizedBox(width: 3),
                  Text(
                    'Vérifié',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PassengerAvatar extends StatelessWidget {
  final String photoUrl;
  final String firstName;
  final bool isVerified;
  const _PassengerAvatar({
    required this.photoUrl,
    required this.firstName,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isVerified
                  ? AppColors.primary.withValues(alpha: 0.4)
                  : AppColors.border,
              width: 1.5,
            ),
          ),
          child: ClipOval(
            child: photoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: photoUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: AppColors.surfaceElevated,
                      child: Center(
                        child: Text(
                          firstName.isNotEmpty ? firstName[0] : '?',
                          style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    errorWidget: (_, __, ___) => _initials(),
                  )
                : _initials(),
          ),
        ),
        if (isVerified)
          Positioned(
            bottom: -2,
            right: -2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.background, width: 1.5),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 10),
            ),
          ),
      ],
    );
  }

  Widget _initials() => Container(
        color: AppColors.surfaceElevated,
        child: Center(
          child: Text(
            firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
}

class _CountBadge extends StatelessWidget {
  final int count;
  const _CountBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.people_rounded,
              color: AppColors.primary, size: 14),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
