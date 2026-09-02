import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';

part 'home_view_model.g.dart';

@riverpod
class HomeViewModel extends _$HomeViewModel {
  @override
  Future<List<Performance>> build() async {
    return _fetchPerformances();
  }

  Future<List<Performance>> _fetchPerformances({
    bool forceRefresh = false,
  }) async {
    final repo = ref.watch(performanceRepositoryProvider);
    return repo.getUpcomingPerformances(forceRefresh: forceRefresh);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    final res = await AsyncValue.guard(() {
      final repo = ref.read(performanceRepositoryProvider);
      return repo.getUpcomingPerformances(forceRefresh: true);
    });
    if (ref.mounted) {
      state = res;
    }
  }
}
