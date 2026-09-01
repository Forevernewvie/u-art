import 'dart:async';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';

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
    final now = DateTime.now();
    final endDate = calculateEndDate(now);

    final dateFormat = DateFormat('yyyy.MM.dd');
    final stdateStr = dateFormat.format(now);
    final eddateStr = dateFormat.format(endDate);

    final list = await service.getPerformances(
      stdate: stdateStr,
      eddate: eddateStr,
    );

    list.sort((a, b) => a.startDate.compareTo(b.startDate));
    return list;
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
