// lib/features/profil/presentation/screens/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/services/settings_service.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

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
        children: [
          // ─── Apparence ───────────────────────────────────
          const _SectionHeader('Apparence'),
          _SettingTile(
            icon: Icons.dark_mode_rounded,
            title: 'Thème',
            trailing: DropdownButton<String>(
              value: settings[SettingsService.kThemeMode] as String,
              underline: const SizedBox.shrink(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
              dropdownColor: AppColors.surface,
              onChanged: (v) {
                if (v != null) {
                  notifier.set(SettingsService.kThemeMode, v);
                }
              },
              items: const [
                DropdownMenuItem(value: 'dark', child: Text('Sombre')),
                DropdownMenuItem(value: 'light', child: Text('Clair')),
                DropdownMenuItem(value: 'system', child: Text('Système')),
              ],
            ),
          ),
          _SettingTile(
            icon: Icons.language_rounded,
            title: 'Langue',
            trailing: DropdownButton<String>(
              value: settings[SettingsService.kLanguage] as String,
              underline: const SizedBox.shrink(),
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.primary,
              ),
              dropdownColor: AppColors.surface,
              onChanged: (v) {
                if (v != null) {
                  notifier.set(SettingsService.kLanguage, v);
                }
              },
              items: const [
                DropdownMenuItem(value: 'fr', child: Text('Français')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ─── Notifications ───────────────────────────────
          const _SectionHeader('Notifications'),
          _SettingTile(
            icon: Icons.emergency_rounded,
            title: 'Alertes SOS',
            subtitle: 'Recevoir les alertes SOS dans un rayon de 2 km',
            trailing: Switch(
              value: settings[SettingsService.kNotifSos] as bool,
              onChanged: (_) => notifier.toggle(SettingsService.kNotifSos),
              activeColor: AppColors.primary,
            ),
          ),
          _SettingTile(
            icon: Icons.people_rounded,
            title: 'Notifications passagers',
            subtitle: 'Montée/descente, nouveaux passagers',
            trailing: Switch(
              value: settings[SettingsService.kNotifPassenger] as bool,
              onChanged: (_) =>
                  notifier.toggle(SettingsService.kNotifPassenger),
              activeColor: AppColors.primary,
            ),
          ),
          _SettingTile(
            icon: Icons.campaign_rounded,
            title: 'Promotions et actualités',
            trailing: Switch(
              value: settings[SettingsService.kNotifPromo] as bool,
              onChanged: (_) => notifier.toggle(SettingsService.kNotifPromo),
              activeColor: AppColors.primary,
            ),
          ),

          const SizedBox(height: 24),

          // ─── Sécurité & Vie Privée ──────────────────────
          const _SectionHeader('Sécurité & Vie Privée'),
          _SettingTile(
            icon: Icons.location_on_rounded,
            title: 'Partage de position',
            subtitle: 'Partager ma position en temps réel durant les trajets',
            trailing: Switch(
              value: settings[SettingsService.kLocationShare] as bool,
              onChanged: (_) => notifier.toggle(SettingsService.kLocationShare),
              activeColor: AppColors.primary,
            ),
          ),
          _SettingTile(
            icon: Icons.photo_camera_rounded,
            title: 'Afficher ma photo',
            subtitle: 'Photo de profil visible aux autres usagers',
            trailing: Switch(
              value: settings[SettingsService.kShowPhoto] as bool,
              onChanged: (_) => notifier.toggle(SettingsService.kShowPhoto),
              activeColor: AppColors.primary,
            ),
          ),
          _SettingTile(
            icon: Icons.volume_down_rounded,
            title: 'SOS discret (bouton volume)',
            subtitle: 'Longue pression sur Volume Bas = alerte discrète',
            trailing: Switch(
              value: settings[SettingsService.kSosVolumeButton] as bool,
              onChanged: (_) =>
                  notifier.toggle(SettingsService.kSosVolumeButton),
              activeColor: AppColors.primary,
            ),
          ),

          const SizedBox(height: 24),

          // ─── Données & Stockage ──────────────────────────
          const _SectionHeader('Données & Stockage'),
          _SettingTile(
            icon: Icons.offline_bolt_rounded,
            title: 'Mode hors ligne',
            subtitle: 'Conserver trajets et taxis en cache local',
            trailing: Switch(
              value: settings[SettingsService.kOfflineMode] as bool,
              onChanged: (_) => notifier.toggle(SettingsService.kOfflineMode),
              activeColor: AppColors.primary,
            ),
          ),
          _SettingTile(
            icon: Icons.vibration_rounded,
            title: 'Vibrations',
            trailing: Switch(
              value: settings[SettingsService.kVibrations] as bool,
              onChanged: (_) => notifier.toggle(SettingsService.kVibrations),
              activeColor: AppColors.primary,
            ),
          ),

          const SizedBox(height: 24),

          // ─── À propos ────────────────────────────────────
          const _SectionHeader('À propos'),
          _SettingTile(
            icon: Icons.info_outline_rounded,
            title: 'Version de l\'application',
            subtitle: '1.0.0 (Build 1)',
            onTap: () {},
          ),
          _SettingTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Politique de confidentialité',
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              // TODO: Ouvrir la politique de confidentialité
            },
          ),
          _SettingTile(
            icon: Icons.description_outlined,
            title: 'Conditions d\'utilisation',
            trailing: const Icon(Icons.chevron_right_rounded, size: 18),
            onTap: () {
              // TODO: Ouvrir les CGU
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleMedium),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
