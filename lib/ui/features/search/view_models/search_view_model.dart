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
        final Map<String, Performance> synthesizedMap = {};

        for (final p in list) {
          if (!seenIds.add(p.id)) continue;

          final normTitle = p.title
              .replaceAll(RegExp(r'\[.*?\]'), '')
              .replaceAll(RegExp(r'\(.*?\)'), '')
              .replaceAll(RegExp(r'[^a-zA-Z0-9가-힣]+'), '')
              .toLowerCase();

          String? matchedKey;
          for (final existingKey in synthesizedMap.keys) {
            final parts = existingKey.split('__');
            final existingDate = parts[0];
            final existingTitle = parts.length > 1 ? parts[1] : '';
            if (existingDate == p.startDate) {
              if (normTitle.contains(existingTitle) || existingTitle.contains(normTitle)) {
                matchedKey = existingKey;
                break;
              }
            }
          }

          if (matchedKey != null) {
            final existing = synthesizedMap[matchedKey]!;
            final isPNewKopis = p.id.startsWith('PF');
            final kopisItem = isPNewKopis ? p : existing;
            final crawledItem = isPNewKopis ? existing : p;

            final isSoldOut = kopisItem.isSoldOut || crawledItem.isSoldOut;
            final detailedVenue = crawledItem.venue.contains('(') ? crawledItem.venue : kopisItem.venue;

            synthesizedMap[matchedKey] = Performance(
              id: kopisItem.id,
              title: kopisItem.title,
              startDate: kopisItem.startDate,
              endDate: kopisItem.endDate,
              venue: detailedVenue,
              posterUrl: kopisItem.posterUrl.isNotEmpty ? kopisItem.posterUrl : crawledItem.posterUrl,
              genre: kopisItem.genre.isNotEmpty ? kopisItem.genre : crawledItem.genre,
              state: isSoldOut ? '매진' : (kopisItem.state.isNotEmpty ? kopisItem.state : '공연예정'),
              district: kopisItem.district != '전체' ? kopisItem.district : crawledItem.district,
            );
          } else {
            synthesizedMap['${p.startDate}__$normTitle'] = p;
          }
        }

        final deduped = synthesizedMap.values.toList();
        for (var i = 0; i < deduped.length; i++) {
          final perf = deduped[i];
          if (perf.venue.contains('중구') || perf.venue.contains('함월홀') || perf.venue.contains('달빛마루')) {
            if (perf.title.contains('긴긴밤') || perf.title.contains('양파') || perf.title.contains('미녀와')) {
              deduped[i] = Performance(
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
          }
        }

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
        final enriched = list.map((perf) {
          if (perf.venue.contains('중구') &&
              (perf.title.contains('긴긴밤') || perf.title.contains('양파') || perf.title.contains('미녀와'))) {
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

      list.sort((a, b) => a.startDate.compareTo(b.startDate));
      return list;
    }
  }

  Future<void> search(String query, String genre) async {
    if (!ref.mounted) return;
    if (_cachedAllPerformances.isEmpty) {
      state = const AsyncValue.loading();
      final res = await AsyncValue.guard(() async {
        _cachedAllPerformances = await _loadAllUlsanPerformances();
        return _filterPerformances(_cachedAllPerformances, query, genre);
      });
      if (ref.mounted) {
        state = res;
      }
    } else {
      final filtered = _filterPerformances(
        _cachedAllPerformances,
        query,
        genre,
      );
      if (ref.mounted) {
        state = AsyncValue.data(filtered);
      }
    }
  }

  Future<void> refresh() async {
    if (!ref.mounted) return;
    state = const AsyncValue.loading();
    final res = await AsyncValue.guard(() async {
      _cachedAllPerformances = await _loadAllUlsanPerformances();
      return _cachedAllPerformances;
    });
    if (ref.mounted) {
      state = res;
    }
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
