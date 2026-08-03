// lib/features/auth/presentation/screens/role_select_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              const Text(
                'Choisissez votre rôle',
                style: AppTextStyles.displayLarge,
              ),
              const SizedBox(height: 12),
              const Text(
                'Sélectionnez comment vous souhaitez utiliser SafeTaxi',
                style: AppTextStyles.bodyLarge,
              ),
              const SizedBox(height: 40),
              Expanded(
                child: ListView(
                  children: [
                    _RoleCard(
                      icon: Icons.person_rounded,
                      title: 'Passager',
                      subtitle: 'Voyagez en toute sécurité',
                      color: AppColors.passengerColor,
                      onTap: () => context.push(
                        '${AppRoutes.register}?role=passenger',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.drive_eta_rounded,
                      title: 'Chauffeur',
                      subtitle: 'Conduisez et sécurisez vos trajets',
                      color: AppColors.driverColor,
                      onTap: () => context.push(
                        '${AppRoutes.register}?role=driver',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _RoleCard(
                      icon: Icons.directions_car_rounded,
                      title: 'Propriétaire',
                      subtitle: 'Gérez votre flotte de taxis',
                      color: AppColors.ownerColor,
                      onTap: () => context.push(
                        '${AppRoutes.register}?role=owner',
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go(AppRoutes.login),
                child: const Text('Déjà un compte ? Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.headlineMedium.copyWith(color: color),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
