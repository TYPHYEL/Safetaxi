// lib/features/notation/presentation/screens/notation_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class NotationScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String targetUserId;
  final bool targetIsDriver;
  const NotationScreen({
    super.key,
    required this.tripId,
    required this.targetUserId,
    required this.targetIsDriver,
  });
  @override
  ConsumerState<NotationScreen> createState() => _NotationScreenState();
}

class _NotationScreenState extends ConsumerState<NotationScreen> {
  int _stars = 0;
  String _comment = '';
  bool _isLoading = false;
  final _selectedAspects = <String>{};

  final _aspects = [
    'Conduite sûre',
    'Ponctuel',
    'Respectueux',
    'Véhicule propre',
    'Bonne communication',
  ];

  Future<void> _submit() async {
    if (_stars == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Donnez au moins 1 étoile')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await ref.read(apiClientProvider).rateUser({
        'trip_id': widget.tripId,
        'rated_id': widget.targetUserId,
        'score': _stars,
        'comment': _comment,
        'aspects': _selectedAspects.toList(),
      });
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            backgroundColor: AppColors.surface,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded,
                    color: AppColors.ownerColor, size: 56),
                const SizedBox(height: 12),
                const Text('Merci pour votre note !',
                    style: AppTextStyles.headlineMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erreur: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

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
        title: Text(widget.targetIsDriver
            ? 'Évaluer le chauffeur'
            : 'Évaluer le passager'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.ownerColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                widget.targetIsDriver
                    ? Icons.drive_eta_rounded
                    : Icons.person_rounded,
                color: AppColors.ownerColor,
                size: 40,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.targetIsDriver
                  ? 'Comment était le chauffeur ?'
                  : 'Comment était ce passager ?',
              style: AppTextStyles.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  5,
                  (i) => GestureDetector(
                        onTap: () => setState(() => _stars = i + 1),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Icon(
                            i < _stars
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            color: i < _stars
                                ? AppColors.ownerColor
                                : AppColors.textMuted,
                            size: 44,
                          ),
                        ),
                      )),
            ),
            const SizedBox(height: 8),
            Text(
              _stars == 0
                  ? 'Appuyez pour noter'
                  : _stars == 5
                      ? 'Excellent'
                      : _stars >= 3
                          ? 'Bien'
                          : 'Mauvais',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: _stars > 0 ? AppColors.ownerColor : null),
            ),
            const SizedBox(height: 24),
            const Align(
                alignment: Alignment.centerLeft,
                child:
                    Text('Points positifs', style: AppTextStyles.titleLarge)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _aspects.map((a) {
                final sel = _selectedAspects.contains(a);
                return GestureDetector(
                  onTap: () => setState(() {
                    sel ? _selectedAspects.remove(a) : _selectedAspects.add(a);
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? AppColors.ownerColor.withValues(alpha: 0.15)
                          : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? AppColors.ownerColor : AppColors.border),
                    ),
                    child: Text(a,
                        style: AppTextStyles.labelMedium.copyWith(
                            color: sel
                                ? AppColors.ownerColor
                                : AppColors.textSecondary)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            TextFormField(
              maxLines: 3,
              style: AppTextStyles.bodyLarge,
              onChanged: (v) => _comment = v,
              decoration:
                  const InputDecoration(hintText: 'Laissez un commentaire...'),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.ownerColor),
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer l\'évaluation'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
