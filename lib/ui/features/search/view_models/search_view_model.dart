import 'dart:async';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:u_art/data/services/junggu_crawler_service.dart';

part 'search_view_model.g.dart';

@riverpod
class SearchViewModel extends _$SearchViewModel {
  List<Performance> _cachedAllPerformances = [];

  @override
  Future<List<Performance>> build() async {
    _cachedAllPerformances = await _loadAllUlsanPerformances();
    return _cachedAllPerformances;
  }

  DateTime calculateEndDate(DateTime now) {
    if (now.month >= 11) {
      final nextYear = now.year + 1;
      final isLeapYear =
          (nextYear % 4 == 0 && nextYear % 100 != 0) || (nextYear % 400 == 0);
      return DateTime(nextYear, 2, isLeapYear ? 29 : 28);
    } else {
      return DateTime(now.year, 12, 31);
    }
  }

  Future<List<Performance>> _loadAllUlsanPerformances() async {
    final service = ref.read(uartApiServiceProvider);
    final kopisService = KopisService('534331c08630453bbd1df50692635746');
    final jungguService = JungguCrawlerService();
    final now = DateTime.now();
    final endDate = calculateEndDate(now);

    final dateFormat = DateFormat('yyyy.MM.dd');
    final stdateStr = dateFormat.format(now);
    final eddateStr = dateFormat.format(endDate);

    List<Performance> list = [];

    try {
      final list = await service
          .getPerformances(stdate: stdateStr, eddate: eddateStr)
          .timeout(const Duration(milliseconds: 1500));
      if (list.isNotEmpty) {
        final seenIds = <String>{};
        final deduped = list.where((p) => seenIds.add(p.id)).toList();
        deduped.sort((a, b) => a.startDate.compareTo(b.startDate));
        return deduped;
      }
      throw Exception('Empty backend response');
    } catch (_) {
      final kopisFormat = DateFormat('yyyyMMdd');
      final list = await kopisService.getAllPerformancesByRegion(
        stdate: kopisFormat.format(now),
        eddate: kopisFormat.format(endDate),
        signgucode: '31',
      );

      final hasJunggu = list.any((p) => p.venue.contains('중구'));
      if (hasJunggu) {
        try {
          final statuses = await jungguService.fetchSoldOutStatuses();
          if (statuses.isNotEmpty) {
            final enriched = list.map((perf) {
              if (perf.venue.contains('중구') &&
                  JungguCrawlerService.isTitleSoldOut(perf.title, statuses)) {
                return Performance(
                  id: perf.id,
                  title: perf.title,
                  startDate: perf.startDate,
                  endDate: perf.endDate,
                  venue: perf.venue,
                  posterUrl: perf.posterUrl,
                  genre: perf.genre,
                  state: '매진',
                  district: perf.district,
                );
              }
              return perf;
            }).toList();
            enriched.sort((a, b) => a.startDate.compareTo(b.startDate));
            return enriched;
          }
        } catch (_) {}
      }

      list.sort((a, b) => a.startDate.compareTo(b.startDate));
      return list;
    }
  }

  Future<void> search(String query, String genre) async {
    if (_cachedAllPerformances.isEmpty) {
      state = const AsyncValue.loading();
      state = await AsyncValue.guard(() async {
        _cachedAllPerformances = await _loadAllUlsanPerformances();
        return _filterPerformances(_cachedAllPerformances, query, genre);
      });
    } else {
      final filtered = _filterPerformances(
        _cachedAllPerformances,
        query,
        genre,
      );
      state = AsyncValue.data(filtered);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      _cachedAllPerformances = await _loadAllUlsanPerformances();
      return _cachedAllPerformances;
    });
  }

  List<Performance> _filterPerformances(
    List<Performance> list,
    String query,
    String genre,
  ) {
    var result = list;
    final trimmedQuery = query.trim().toLowerCase();

    if (trimmedQuery.isNotEmpty) {
      result = result.where((p) {
        final matchesTitle = p.title.toLowerCase().contains(trimmedQuery);
        final matchesVenue = p.venue.toLowerCase().contains(trimmedQuery);
        return matchesTitle || matchesVenue;
      }).toList();
    }

    if (genre.isNotEmpty && genre != '전체') {
      result = result.where((p) => p.genre.contains(genre)).toList();
    }

    return result;
  }
}
