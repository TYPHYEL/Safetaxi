// lib/features/auth/presentation/screens/driver_documents_screen.dart
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:safetaxi_cameroun/core/network/api_client.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

// ─── Types de documents requis ──────────────────────────────

enum DocType {
  cniRecto('CNI Recto', 'cni_recto', Icons.badge_rounded),
  cniVerso('CNI Verso', 'cni_verso', Icons.badge_outlined),
  permis('Permis de conduire', 'permis', Icons.drive_eta_rounded),
  carteGrise('Carte grise', 'carte_grise', Icons.description_rounded),
  photoTaxi('Photo du taxi', 'photo_taxi', Icons.local_taxi_rounded);

  final String label;
  final String apiKey;
  final IconData icon;
  const DocType(this.label, this.apiKey, this.icon);
}

// ─── Provider pour les documents ─────────────────────────

class DriverDocumentsState {
  final Map<DocType, dynamic> files;
  final Map<DocType, bool> uploaded;
  final Map<DocType, String?> errors;
  final bool isSubmitting;
  final int completedCount;

  const DriverDocumentsState({
    this.files = const {},
    this.uploaded = const {},
    this.errors = const {},
    this.isSubmitting = false,
    this.completedCount = 0,
  });

  DriverDocumentsState copyWith({
    Map<DocType, dynamic>? files,
    Map<DocType, bool>? uploaded,
    Map<DocType, String?>? errors,
    bool? isSubmitting,
    int? completedCount,
  }) =>
      DriverDocumentsState(
        files: files ?? this.files,
        uploaded: uploaded ?? this.uploaded,
        errors: errors ?? this.errors,
        isSubmitting: isSubmitting ?? this.isSubmitting,
        completedCount: completedCount ?? this.completedCount,
      );
}

class DriverDocumentsNotifier extends StateNotifier<DriverDocumentsState> {
  final ApiClient _api;
  final ImagePicker _picker = ImagePicker();

  DriverDocumentsNotifier(this._api) : super(const DriverDocumentsState());

  Future<void> pickImage(DocType type, ImageSource source) async {
    try {
      // On web, camera is not available, so use gallery
      final actualSource = kIsWeb ? ImageSource.gallery : source;
      
      final XFile? picked = await _picker.pickImage(
        source: actualSource,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked == null) return;

      // On web, use XFile directly; on mobile, convert to File
      final file = kIsWeb ? picked : File(picked.path);

      // Vérifier que le fichier existe (only on mobile)
      if (!kIsWeb && !await file.exists()) {
        state = state.copyWith(
          errors: {...state.errors, type: 'Fichier introuvable'},
        );
        return;
      }

      // Vérifier la taille (max 5MB)
      final sizeMB = await file.length() / (1024 * 1024);
      if (sizeMB > 5) {
        state = state.copyWith(
          errors: {...state.errors, type: 'Image trop grande (max 5MB)'},
        );
        return;
      }

      // Ajouter le fichier
      state = state.copyWith(
        files: {...state.files, type: file},
        errors: {...state.errors, type: null},
      );

      // Upload immédiat
      await _uploadDoc(type, file);
    } catch (e) {
      _log.e('Pick image error: $e');
      state = state.copyWith(
        errors: {...state.errors, type: 'Erreur: ${e.toString()}'},
      );
    }
  }

  Future<void> _uploadDoc(DocType type, File file) async {
    state = state.copyWith(isSubmitting: true);

    try {
      final formData = FormData.fromMap({
        'doc_type': type.apiKey,
        'file': await MultipartFile.fromFile(
          file.path,
          filename: '${type.apiKey}.jpg',
        ),
      });

      await _api.uploadDriverDoc(type.apiKey, formData);

      state = state.copyWith(
        uploaded: {...state.uploaded, type: true},
        isSubmitting: false,
      );
    } catch (e) {
      _log.e('Upload ${type.label} failed: $e');
      state = state.copyWith(
        errors: {...state.errors, type: 'Échec de l\'upload'},
        isSubmitting: false,
      );
    }
  }

  void removeDoc(DocType type) {
    final newFiles = Map<DocType, File?>.from(state.files);
    final newUploaded = Map<DocType, bool>.from(state.uploaded);
    newFiles.remove(type);
    newUploaded.remove(type);
    state = state.copyWith(files: newFiles, uploaded: newUploaded);
  }

  bool get allDocumentsUploaded {
    return DocType.values.every((t) => state.uploaded[t] == true);
  }

  Future<void> submitAll() async {
    state = state.copyWith(isSubmitting: true);
    try {
      for (final type in DocType.values) {
        final file = state.files[type];
        if (file != null && state.uploaded[type] != true) {
          await _uploadDoc(type, file);
        }
      }
    } finally {
      state = state.copyWith(isSubmitting: false);
    }
  }
}

final driverDocsProvider =
    StateNotifierProvider<DriverDocumentsNotifier, DriverDocumentsState>((ref) {
  return DriverDocumentsNotifier(ref.watch(apiClientProvider));
});

// ─── Screen principale ─────────────────────────────────────

class DriverDocumentsScreen extends ConsumerWidget {
  const DriverDocumentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(driverDocsProvider);
    final notifier = ref.read(driverDocsProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Documents chauffeur'),
      ),
      body: Column(
        children: [
          // Header avec progression
          _buildHeader(state),

          // Liste des documents
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(20),
              itemCount: DocType.values.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final docType = DocType.values[i];
                return _DocCard(
                  type: docType,
                  file: state.files[docType],
                  uploaded: state.uploaded[docType] ?? false,
                  error: state.errors[docType],
                  onPickCamera: () =>
                      notifier.pickImage(docType, ImageSource.camera),
                  onPickGallery: () =>
                      notifier.pickImage(docType, ImageSource.gallery),
                  onRemove: () => notifier.removeDoc(docType),
                );
              },
            ),
          ),

          // Bouton de soumission
          _buildFooter(context, state, notifier),
        ],
      ),
    );
  }

  Widget _buildHeader(DriverDocumentsState state) {
    final total = DocType.values.length;
    final done = state.uploaded.values.where((v) => v == true).length;
    final pct = total > 0 ? done / total : 0.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$done / $total documents',
                      style: AppTextStyles.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      done == total
                          ? 'Tous les documents sont uploadés ✓'
                          : 'Upload vos documents pour la validation',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: done == total
                      ? AppColors.primarySurface
                      : AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(pct * 100).toInt()}%',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: done == total
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor: AppColors.surfaceElevated,
              valueColor: AlwaysStoppedAnimation(
                done == total ? AppColors.primary : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, DriverDocumentsState state,
      DriverDocumentsNotifier notifier) {
    final allDone = notifier.allDocumentsUploaded;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          if (!allDone)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: AppColors.warningSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Votre compte sera validé une fois tous les documents uploadés.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.warning),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton.icon(
              onPressed: allDone && !state.isSubmitting
                  ? () {
                      notifier.submitAll();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Documents soumis ! En cours de validation.'),
                          backgroundColor: AppColors.primarySurface,
                        ),
                      );
                      context.pop();
                    }
                  : null,
              icon: state.isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(allDone
                      ? Icons.check_rounded
                      : Icons.upload_file_rounded),
              label: Text(allDone
                  ? 'Soumettre pour validation'
                  : 'Upload en cours...'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Carte document individuelle ──────────────────────────

class _DocCard extends StatelessWidget {
  final DocType type;
  final File? file;
  final bool uploaded;
  final String? error;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;
  final VoidCallback onRemove;

  const _DocCard({
    required this.type,
    this.file,
    required this.uploaded,
    this.error,
    required this.onPickCamera,
    required this.onPickGallery,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card(),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: uploaded
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    type.icon,
                    color:
                        uploaded ? AppColors.primary : AppColors.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(type.label, style: AppTextStyles.titleMedium),
                      Text(
                        uploaded
                            ? 'Uploadé ✓'
                            : file != null
                                ? 'Prêt à envoyer'
                                : 'Photo obligatoire',
                        style: AppTextStyles.bodySmall.copyWith(
                          color:
                              uploaded ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (uploaded)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: AppColors.primary, size: 16),
                  ),
              ],
            ),
          ),

          // Image ou zone de drop
          if (file != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      file!,
                      height: 160,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (uploaded)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.cloud_done_rounded,
                                color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Cloud',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: _PickButton(
                      icon: Icons.camera_alt_rounded,
                      label: 'Caméra',
                      onTap: onPickCamera,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _PickButton(
                      icon: Icons.photo_library_rounded,
                      label: 'Galerie',
                      onTap: onPickGallery,
                    ),
                  ),
                ],
              ),
            ),

          // Erreur
          if (error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: AppColors.danger, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(error!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.danger)),
                  ),
                ],
              ),
            ),

          // Actions
          if (file != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  if (!uploaded) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onPickCamera,
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Remplacer'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 38),
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    TextButton.icon(
                      onPressed: onRemove,
                      icon:
                          const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                    ),
                  ],
                  if (uploaded)
                    TextButton.icon(
                      onPressed: onRemove,
                      icon:
                          const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Supprimer'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
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

class _PickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary, size: 24),
            const SizedBox(height: 4),
            Text(label,
                style: AppTextStyles.labelMedium
                    .copyWith(color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
