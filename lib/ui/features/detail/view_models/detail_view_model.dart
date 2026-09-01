import 'dart:async';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';

part 'detail_view_model.g.dart';

@riverpod
class DetailViewModel extends _$DetailViewModel {
  @override
  Future<PerformanceDetail> build(String id) async {
    return _fetchDetail(id);
  }

  Future<PerformanceDetail> _fetchDetail(String id) async {
    final repo = ref.watch(performanceRepositoryProvider);
    return repo.getPerformanceDetail(id);
  }
}
