// lib/features/sos/presentation/screens/incident_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

class IncidentScreen extends ConsumerStatefulWidget {
  final String tripId;
  const IncidentScreen({super.key, required this.tripId});
  @override
  ConsumerState<IncidentScreen> createState() => _IncidentScreenState();
}

class _IncidentScreenState extends ConsumerState<IncidentScreen> {
  final _descCtrl = TextEditingController();
  String? _selectedType;
  bool _isLoading = false;

  final _types = [
    ('aggression', 'Agression', Icons.warning_rounded, AppColors.danger),
    ('robbery', 'Vol', Icons.money_off_rounded, AppColors.warning),
    ('accident', 'Accident', Icons.car_crash_rounded, AppColors.ownerColor),
    ('harassment', 'Harcèlement', Icons.block_rounded, AppColors.adminColor),
    ('other', 'Autre', Icons.more_horiz_rounded, AppColors.textMuted),
  ];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final description = _descCtrl.text.trim();
    if (_selectedType == null || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Remplissez tous les champs')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final payload = <String, dynamic>{
        'incident_type': _selectedType,
        'description': description,
      };
      if (widget.tripId.isNotEmpty) {
        payload['trip_id'] = widget.tripId;
      }
      await ref.read(apiClientProvider).reportIncident(payload);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Incident signalé. Merci.'),
            backgroundColor: AppColors.primarySurface,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
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
        title: const Text('Signaler un incident'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ce signalement sera transmis à nos équipes de sécurité.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Type d\'incident', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _types.map((t) {
                final sel = _selectedType == t.$1;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = t.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color:
                          sel ? t.$4.withValues(alpha: 0.15) : AppColors.card,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: sel ? t.$4 : AppColors.border,
                        width: sel ? 1.5 : 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.$3,
                            color: sel ? t.$4 : AppColors.textMuted, size: 16),
                        const SizedBox(width: 6),
                        Text(t.$2,
                            style: AppTextStyles.labelMedium.copyWith(
                              color: sel ? t.$4 : AppColors.textSecondary,
                            )),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Description', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Décrivez ce qui s\'est passé...',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.warning),
                onPressed: _isLoading ? null : _submit,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded),
                label: const Text('Envoyer le signalement'),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
