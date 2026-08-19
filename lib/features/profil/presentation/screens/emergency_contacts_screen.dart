// lib/features/profil/presentation/screens/emergency_contacts_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
);

const _contactsKey = 'emergency_contacts';

// ─── Modèle contact ───────────────────────────────────────

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String relation;
  final bool canReceiveSms;
  final bool canReceiveCall;

  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    required this.relation,
    this.canReceiveSms = true,
    this.canReceiveCall = true,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) =>
      EmergencyContact(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String,
        relation: json['relation'] as String,
        canReceiveSms: json['can_receive_sms'] as bool? ?? true,
        canReceiveCall: json['can_receive_call'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'relation': relation,
        'can_receive_sms': canReceiveSms,
        'can_receive_call': canReceiveCall,
      };

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? relation,
    bool? canReceiveSms,
    bool? canReceiveCall,
  }) =>
      EmergencyContact(
        id: id ?? this.id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        relation: relation ?? this.relation,
        canReceiveSms: canReceiveSms ?? this.canReceiveSms,
        canReceiveCall: canReceiveCall ?? this.canReceiveCall,
      );
}

// ─── Provider ─────────────────────────────────────────────

final emergencyContactsProvider =
    StateNotifierProvider<EmergencyContactsNotifier, List<EmergencyContact>>(
        (ref) {
  return EmergencyContactsNotifier();
});

class EmergencyContactsNotifier extends StateNotifier<List<EmergencyContact>> {
  EmergencyContactsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final raw = await _storage.read(key: _contactsKey);
      if (raw != null) {
        final list = (jsonDecode(raw) as List)
            .cast<Map<String, dynamic>>()
            .map((e) => EmergencyContact.fromJson(e))
            .toList();
        state = list;
      } else {
        // Contacts par défaut si c'est la première fois
        state = [
          const EmergencyContact(
            id: 'default-1',
            name: 'Maman',
            phone: '+237 6XX XXX XXX',
            relation: 'Mère',
          ),
        ];
      }
    } catch (_) {
      state = [];
    }
  }

  Future<void> _save() async {
    final raw = jsonEncode(state.map((c) => c.toJson()).toList());
    await _storage.write(key: _contactsKey, value: raw);
  }

  Future<void> add(EmergencyContact contact) async {
    state = [...state, contact];
    await _save();
  }

  Future<void> update(EmergencyContact contact) async {
    state = state.map((c) => c.id == contact.id ? contact : c).toList();
    await _save();
  }

  Future<void> remove(String id) async {
    state = state.where((c) => c.id != id).toList();
    await _save();
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
    await _save();
  }
}

// ─── Screen ────────────────────────────────────────────────

class EmergencyContactsScreen extends ConsumerWidget {
  const EmergencyContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(emergencyContactsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Contacts d\'urgence'),
        actions: [
          if (contacts.length < 5)
            IconButton(
              icon: const Icon(Icons.add_rounded, color: AppColors.primary),
              onPressed: () => _showAddContactSheet(context, ref),
            ),
        ],
      ),
      body: Column(
        children: [
          // Header info
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency_rounded,
                    color: AppColors.danger, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ces contacts seront alertés automatiquement en cas de SOS.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),

          // Limite
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text('${contacts.length} / 5 contacts',
                    style: AppTextStyles.bodySmall),
                const Spacer(),
                const Text('Maintenez pour réorganiser',
                    style: AppTextStyles.caption),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Liste
          Expanded(
            child: contacts.isEmpty
                ? _buildEmpty(context, ref)
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: contacts.length,
                    onReorder: (oldIndex, newIndex) {
                      ref
                          .read(emergencyContactsProvider.notifier)
                          .reorder(oldIndex, newIndex);
                    },
                    itemBuilder: (_, i) {
                      final contact = contacts[i];
                      return _ContactCard(
                        key: ValueKey(contact.id),
                        contact: contact,
                        index: i,
                        isFirst: i == 0,
                        onEdit: () =>
                            _showEditContactSheet(context, ref, contact),
                        onDelete: () => _confirmDelete(context, ref, contact),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: contacts.isEmpty
          ? null
          : FloatingActionButton(
              onPressed: () => _showAddContactSheet(context, ref),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add_rounded),
            ),
    );
  }

  Widget _buildEmpty(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.contact_phone_rounded,
                color: AppColors.danger, size: 48),
          ),
          const SizedBox(height: 20),
          const Text('Aucun contact d\'urgence',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          const Text('Ajoutez des proches à alerter\nen cas d\'urgence.',
              textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _showAddContactSheet(context, ref),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Ajouter un contact'),
          ),
        ],
      ),
    );
  }

  void _showAddContactSheet(BuildContext context, WidgetRef ref) {
    _showContactSheet(context, ref, null);
  }

  void _showEditContactSheet(
      BuildContext context, WidgetRef ref, EmergencyContact contact) {
    _showContactSheet(context, ref, contact);
  }

  void _showContactSheet(
      BuildContext context, WidgetRef ref, EmergencyContact? contact) {
    final isEdit = contact != null;
    final nameCtrl = TextEditingController(text: contact?.name ?? '');
    final phoneCtrl = TextEditingController(text: contact?.phone ?? '');
    String? selectedRelation = contact?.relation;
    bool selectedSms = contact?.canReceiveSms ?? true;
    bool selectedCall = contact?.canReceiveCall ?? true;

    final relations = [
      'Conjoint(e)',
      'Mère',
      'Père',
      'Frère/Sœur',
      'Enfant',
      'Ami(e)',
      'Collègue',
      'Autre',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEdit ? 'Modifier le contact' : 'Nouveau contact',
                  style: AppTextStyles.headlineMedium,
                ),
                const SizedBox(height: 20),

                // Nom
                const Text('Nom complet', style: AppTextStyles.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  style: AppTextStyles.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: 'Ex: Marie NKOLO',
                    prefixIcon: Icon(Icons.person_outline_rounded,
                        color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),

                // Téléphone
                const Text('Numéro de téléphone',
                    style: AppTextStyles.labelLarge),
                const SizedBox(height: 8),
                TextFormField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: AppTextStyles.bodyLarge,
                  decoration: const InputDecoration(
                    hintText: '+237 6XX XXX XXX',
                    prefixIcon:
                        Icon(Icons.phone_rounded, color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 16),

                // Relation
                const Text('Relation', style: AppTextStyles.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: relations.map((r) {
                    final isSelected = selectedRelation == r;
                    return GestureDetector(
                      onTap: () => setSheetState(() => selectedRelation = r),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.15)
                              : AppColors.surfaceElevated,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                        child: Text(
                          r,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('SMS'),
                        subtitle: const Text('Recevoir un SMS en cas de SOS'),
                        value: selectedSms,
                        onChanged: (value) =>
                            setSheetState(() => selectedSms = value),
                      ),
                    ),
                    Expanded(
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Appel'),
                        subtitle: const Text('Recevoir un appel en cas de SOS'),
                        value: selectedCall,
                        onChanged: (value) =>
                            setSheetState(() => selectedCall = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Bouton
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (nameCtrl.text.trim().isEmpty ||
                          phoneCtrl.text.trim().isEmpty ||
                          selectedRelation == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Remplissez tous les champs'),
                          ),
                        );
                        return;
                      }
                      final newContact = EmergencyContact(
                        id: contact?.id ??
                            DateTime.now().millisecondsSinceEpoch.toString(),
                        name: nameCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        relation: selectedRelation!,
                        canReceiveSms: selectedSms,
                        canReceiveCall: selectedCall,
                      );
                      if (isEdit) {
                        ref
                            .read(emergencyContactsProvider.notifier)
                            .update(newContact);
                      } else {
                        ref
                            .read(emergencyContactsProvider.notifier)
                            .add(newContact);
                      }
                      Navigator.pop(ctx);
                    },
                    child: Text(isEdit ? 'Modifier' : 'Ajouter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(
      BuildContext context, WidgetRef ref, EmergencyContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Supprimer ce contact ?'),
        content: Text('${contact.name} ne sera plus alerté en cas de SOS.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(emergencyContactsProvider.notifier).remove(contact.id);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

// ─── Carte contact ───────────────────────────────────────

class _ContactCard extends StatelessWidget {
  final EmergencyContact contact;
  final int index;
  final bool isFirst;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ContactCard({
    super.key,
    required this.contact,
    required this.index,
    required this.isFirst,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color:
            isFirst ? AppColors.danger.withValues(alpha: 0.06) : AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFirst
              ? AppColors.danger.withValues(alpha: 0.2)
              : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onLongPress: () {},
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icône ou initiales
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? AppColors.danger.withValues(alpha: 0.15)
                        : AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      contact.name.isNotEmpty
                          ? contact.name[0].toUpperCase()
                          : '?',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: isFirst
                            ? AppColors.danger
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(contact.name, style: AppTextStyles.titleMedium),
                          if (isFirst) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.danger,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PRINCIPAL',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(contact.phone, style: AppTextStyles.bodySmall),
                      const SizedBox(height: 2),
                      Text(contact.relation, style: AppTextStyles.caption),
                    ],
                  ),
                ),

                // Actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded,
                          color: AppColors.textMuted, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: AppColors.danger, size: 20),
                      onPressed: onDelete,
                    ),
                    ReorderableDragStartListener(
                      index: index,
                      child: const Icon(Icons.drag_handle_rounded,
                          color: AppColors.textMuted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
