// lib/features/trajet/presentation/screens/history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:safetaxi_cameroun/core/services/cache_service.dart';
import 'package:safetaxi_cameroun/features/auth/presentation/providers/auth_provider.dart';
import 'package:safetaxi_cameroun/shared/theme/app_theme.dart';
import 'package:safetaxi_cameroun/core/constants/app_constants.dart';
import 'package:intl/intl.dart';

List<Map<String, dynamic>> normalizeTripHistoryPayload(dynamic payload) {
  if (payload is List) {
    return payload.whereType<Map<String, dynamic>>().toList();
  }

  if (payload is Map<String, dynamic>) {
    final results = payload['results'];
    if (results is List) {
      return results.whereType<Map<String, dynamic>>().toList();
    }

    final data = payload['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
  }

  return [];
}

// ─── Provider paginé ─────────────────────────────────────
class TripHistoryNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  TripHistoryNotifier(this.ref) : super(const AsyncLoading()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    state = const AsyncLoading();
    _page = 1;
    _hasMore = true;
    final cachedTrips = CacheService.getCachedTripHistory();
    if (cachedTrips.isNotEmpty) {
      state = AsyncData(cachedTrips);
    }
    try {
      final api = ref.read(apiClientProvider);
      final resp = await api.getTripHistory(page: _page);
      final trips = normalizeTripHistoryPayload(resp.data);
      await CacheService.cacheTripHistory(trips);
      state = AsyncData(trips);
      if (trips.length < AppConstants.pageSize) {
        _hasMore = false;
      }
    } catch (e, st) {
      if (cachedTrips.isEmpty) {
        state = AsyncError(e, st);
      }
    }
  }

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;

    try {
      final api = ref.read(apiClientProvider);
      _page++;
      final resp = await api.getTripHistory(page: _page);
      final newTrips = normalizeTripHistoryPayload(resp.data);

      final current = state.value ?? [];
      final mergedTrips = [...current, ...newTrips];
      await CacheService.cacheTripHistory(mergedTrips);
      state = AsyncData(mergedTrips);

      if (newTrips.length < AppConstants.pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      _page--; // rollback en cas d'erreur
    } finally {
      _isLoadingMore = false;
    }
  }

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;
}

final tripHistoryProvider = StateNotifierProvider<TripHistoryNotifier,
    AsyncValue<List<Map<String, dynamic>>>>(
  (ref) => TripHistoryNotifier(ref),
);

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(tripHistoryProvider.notifier);
      if (notifier.hasMore && !notifier.isLoadingMore) {
        notifier.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(tripHistoryProvider);
    final notifier = ref.read(tripHistoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Historique trajets'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: () => notifier.loadInitial(),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (trips) => trips.isEmpty
            ? _EmptyHistory()
            : ListView.separated(
                controller: _scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: trips.length + (notifier.hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  if (i == trips.length) {
                    // Indicateur de chargement en bas
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  }
                  return _TripCard(trip: trips[i]);
                },
              ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              Text('Erreur: $e', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => notifier.loadInitial(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final startedAt = DateTime.tryParse(trip['started_at'] as String? ?? '');
    final endedAt = DateTime.tryParse(trip['ended_at'] as String? ?? '');
    final taxi = trip['taxi'] as Map<String, dynamic>? ?? {};
    final driver = trip['driver'] as Map<String, dynamic>? ?? {};
    final user = driver['user'] as Map<String, dynamic>? ?? {};

    String duration = '';
    if (startedAt != null && endedAt != null) {
      final diff = endedAt.difference(startedAt);
      duration = '${diff.inMinutes} min';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppDecorations.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.local_taxi_rounded,
                    color: AppColors.taxiYellow, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${taxi['brand'] ?? ''} ${taxi['model'] ?? ''} · ${taxi['plate'] ?? ''}',
                      style: AppTextStyles.titleMedium,
                    ),
                    Text(
                      'Chauffeur: ${user['first_name'] ?? ''} ${user['last_name'] ?? ''}',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Terminé',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              _TripStat(
                icon: Icons.access_time_rounded,
                value: startedAt != null
                    ? DateFormat('dd/MM HH:mm').format(startedAt.toLocal())
                    : '--',
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 16),
              _TripStat(
                icon: Icons.timer_rounded,
                value: duration,
                color: AppColors.ownerColor,
              ),
              const SizedBox(width: 16),
              _TripStat(
                icon: Icons.people_rounded,
                value: '${trip['passenger_count'] ?? 0} pass.',
                color: AppColors.driverColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TripStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;
  const _TripStat(
      {required this.icon, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(value, style: AppTextStyles.caption.copyWith(color: color)),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.route_rounded, color: AppColors.textMuted, size: 56),
          SizedBox(height: 16),
          Text('Aucun trajet', style: AppTextStyles.headlineMedium),
          SizedBox(height: 8),
          Text('Vos trajets SafeTaxi apparaîtront ici',
              style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }
}
