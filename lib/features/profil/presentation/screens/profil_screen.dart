// lib/features/profil/presentation/screens/profil_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/features/auth/domain/entities/user_entity.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/shared/widgets/safe_avatar.dart';

class ProfilScreen extends ConsumerStatefulWidget {
  const ProfilScreen({super.key});

  @override
  ConsumerState<ProfilScreen> createState() => _ProfilScreenState();
}

class _ProfilScreenState extends ConsumerState<ProfilScreen> {
  bool _isUploadingPhoto = false;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // Header avec photo et infos
          SliverToBoxAdapter(
            child: _buildProfileHeader(context, ref, user),
          ),

          // Menu items
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 24),
                const _SectionTitle('Mon compte'),
                const SizedBox(height: 12),
                _MenuGroup(items: [
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    label: 'Informations personnelles',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.shield_outlined,
                    label: 'Trust Score',
                    trailing: TrustBadge(score: user?.trustScore ?? 5.0),
                    onTap: () => context.push(AppRoutes.trustScore),
                  ),
                  _MenuItem(
                    icon: Icons.star_outline_rounded,
                    label: 'Mes avis',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.history_rounded,
                    label: 'Historique trajets',
                    onTap: () => context.push(AppRoutes.history),
                  ),
                ]),

                const SizedBox(height: 20),
                const _SectionTitle('Sécurité'),
                const SizedBox(height: 12),
                _MenuGroup(items: [
                  _MenuItem(
                    icon: Icons.contacts_rounded,
                    label: 'Contacts d\'urgence',
                    onTap: () => context.push(AppRoutes.emergencyContacts),
                  ),
                ]),

                if (user?.role == UserRole.driver ||
                    user?.role == UserRole.owner) ...[
                  const SizedBox(height: 20),
                  const _SectionTitle('Mon taxi'),
                  const SizedBox(height: 12),
                  _MenuGroup(items: [
                    _MenuItem(
                      icon: Icons.local_taxi_rounded,
                      label: 'Mes taxis',
                      onTap: () => context.push(AppRoutes.myTaxis),
                    ),
                    if (user?.role == UserRole.owner)
                      _MenuItem(
                        icon: Icons.add_rounded,
                        label: 'Ajouter un taxi',
                        onTap: () => context.push(AppRoutes.taxiCreate),
                      ),
                  ]),
                ],

                const SizedBox(height: 20),
                const _SectionTitle('Application'),
                const SizedBox(height: 12),
                _MenuGroup(items: [
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: 'Paramètres',
                    onTap: () => context.push(AppRoutes.settings),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline_rounded,
                    label: 'Aide & Support',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.info_outline_rounded,
                    label: 'À propos',
                    onTap: () {},
                  ),
                ]),

                const SizedBox(height: 20),

                // Déconnexion
                GestureDetector(
                  onTap: () => _confirmLogout(context, ref),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.logout_rounded,
                            color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Se déconnecter',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 48),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
      BuildContext context, WidgetRef ref, UserEntity? user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 28),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.surface, AppColors.background],
        ),
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => context.pop(),
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Profil', style: AppTextStyles.headlineMedium),
            ],
          ),
          const SizedBox(height: 28),

          // Avatar
          Stack(
            clipBehavior: Clip.none,
            children: [
              SafeAvatar(
                photoUrl: user?.photoUrl,
                initials: user?.initials ?? 'P',
                size: 80,
                borderColor: AppColors.primary,
                onTap: _pickProfilePhoto,
              ),
              if (_isUploadingPhoto)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.textPrimary.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: -4,
                child: GestureDetector(
                  onTap: _pickProfilePhoto,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.background, width: 2),
                    ),
                    child: const Icon(Icons.camera_alt_rounded,
                        color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),
          Text(user?.fullName ?? 'Utilisateur',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 4),
          Text(user?.phone ?? '', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 10),

          // Role badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: _roleColor(user?.role).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: _roleColor(user?.role).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_roleIcon(user?.role),
                    color: _roleColor(user?.role), size: 14),
                const SizedBox(width: 6),
                Text(
                  _roleLabel(user?.role),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: _roleColor(user?.role),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          if (user?.isVerified == true) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.verified_rounded,
                    color: AppColors.primary, size: 14),
                const SizedBox(width: 4),
                Text('Identité vérifiée',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.primary)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _roleColor(UserRole? role) {
    switch (role) {
      case UserRole.driver:
        return AppColors.driverColor;
      case UserRole.owner:
        return AppColors.ownerColor;
      case UserRole.admin:
        return AppColors.adminColor;
      default:
        return AppColors.passengerColor;
    }
  }

  IconData _roleIcon(UserRole? role) {
    switch (role) {
      case UserRole.driver:
        return Icons.drive_eta_rounded;
      case UserRole.owner:
        return Icons.directions_car_rounded;
      case UserRole.admin:
        return Icons.admin_panel_settings_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  String _roleLabel(UserRole? role) {
    switch (role) {
      case UserRole.driver:
        return 'Chauffeur';
      case UserRole.owner:
        return 'Propriétaire';
      case UserRole.admin:
        return 'Administrateur';
      default:
        return 'Passager';
    }
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1000,
      maxHeight: 1000,
      imageQuality: 80,
    );
    if (image == null) return;

    setState(() => _isUploadingPhoto = true);
    try {
      // On web, use XFile directly; on mobile, convert to File
      final file = kIsWeb ? image : File(image.path);
      await ref.read(authProvider.notifier).updateProfilePhoto(file);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo de profil mise à jour')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de téléchargement : $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Se déconnecter ?'),
        content:
            const Text('Vous devrez vous reconnecter pour utiliser SafeTaxi.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(context);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle(this.label);
  @override
  Widget build(BuildContext context) => Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          letterSpacing: 1.5,
          color: AppColors.textMuted,
          fontWeight: FontWeight.w600,
        ),
      );
}

class _MenuGroup extends StatelessWidget {
  final List<_MenuItem> items;
  const _MenuGroup({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return Column(
            children: [
              e.value,
              if (!isLast) const Divider(height: 1, indent: 56),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 18),
      ),
      title: Text(label, style: AppTextStyles.titleMedium),
      trailing: trailing ??
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textMuted, size: 18),
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
    );
  }
}

// ═══════════════════════════════════════════════════════
// TRUST SCORE SCREEN
// ═══════════════════════════════════════════════════════

class TrustScoreScreen extends ConsumerWidget {
  const TrustScoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final score = user?.trustScore ?? 5.0;
    final pct = score / 5.0;

    final color = score >= 4
        ? AppColors.primary
        : score >= 2.5
            ? AppColors.warning
            : AppColors.danger;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Trust Score'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Center(
              child: SizedBox(
                width: 180,
                height: 180,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: pct,
                      strokeWidth: 12,
                      backgroundColor: AppColors.surfaceElevated,
                      valueColor: AlwaysStoppedAnimation(color),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            score.toStringAsFixed(1),
                            style: AppTextStyles.displayLarge
                                .copyWith(color: color),
                          ),
                          const Text('/5.0', style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            TrustBadge(score: score, large: true),
            const SizedBox(height: 8),
            Text(
              score >= 4
                  ? 'Profil très fiable ✓'
                  : score >= 2.5
                      ? 'Profil moyen'
                      : 'Profil à améliorer',
              style: AppTextStyles.headlineMedium.copyWith(color: color),
            ),
            const SizedBox(height: 32),

            // Critères de calcul
            Container(
              padding: const EdgeInsets.all(18),
              decoration: AppDecorations.card(),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comment est calculé votre score ?',
                      style: AppTextStyles.titleLarge),
                  SizedBox(height: 16),
                  _ScoreFactor(
                      label: 'Notes reçues',
                      weight: '40%',
                      color: AppColors.primary),
                  _ScoreFactor(
                      label: 'Trajets sans incident',
                      weight: '30%',
                      color: AppColors.driverColor),
                  _ScoreFactor(
                      label: 'Ancienneté compte',
                      weight: '15%',
                      color: AppColors.ownerColor),
                  _ScoreFactor(
                      label: 'Identité vérifiée',
                      weight: '15%',
                      color: AppColors.adminColor),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _ScoreFactor extends StatelessWidget {
  final String label;
  final String weight;
  final Color color;
  const _ScoreFactor(
      {required this.label, required this.weight, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
          Text(weight, style: AppTextStyles.labelLarge.copyWith(color: color)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════
// SETTINGS SCREEN
// ═══════════════════════════════════════════════════════

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Paramètres'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: const [
          _SectionTitle('Notifications'),
          SizedBox(height: 12),
          _ToggleTile(
              label: 'Alertes SOS reçues',
              subtitle: 'Être notifié des SOS proches'),
          _ToggleTile(
              label: 'Nouveaux passagers',
              subtitle: 'Notifié quand un passager monte',
              initial: true),
          _ToggleTile(
              label: 'Promotions', subtitle: 'Offres et nouveautés SafeTaxi'),
          SizedBox(height: 20),
          _SectionTitle('Confidentialité'),
          SizedBox(height: 12),
          _ToggleTile(
              label: 'Partage de localisation',
              subtitle: 'Permettre le suivi GPS',
              initial: true),
          _ToggleTile(
              label: 'Afficher ma photo',
              subtitle: 'Visible par les autres passagers',
              initial: true),
          SizedBox(height: 20),
          _SectionTitle('Application'),
          SizedBox(height: 12),
          _ToggleTile(
              label: 'Mode hors-ligne',
              subtitle: 'Cache local activé',
              initial: true),
          _ToggleTile(
              label: 'Vibrations', subtitle: 'Retour haptique', initial: true),
          SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _ToggleTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final bool initial;
  const _ToggleTile(
      {required this.label, required this.subtitle, this.initial = false});
  @override
  State<_ToggleTile> createState() => _ToggleTileState();
}

class _ToggleTileState extends State<_ToggleTile> {
  late bool _val;
  @override
  void initState() {
    super.initState();
    _val = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: AppDecorations.card(),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label, style: AppTextStyles.titleMedium),
                Text(widget.subtitle, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Switch(
            value: _val,
            onChanged: (v) => setState(() => _val = v),
            activeColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}
