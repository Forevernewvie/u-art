import 'dart:async';
import 'package:intl/intl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart'; 

part 'bookmark_list_view_model.g.dart';

@riverpod
class BookmarkListViewModel extends _$BookmarkListViewModel {
  @override
  Future<List<PerformanceDetail>> build() async {
    return _fetchBookmarkedDetails();
  }

  Future<List<PerformanceDetail>> _fetchBookmarkedDetails() async {
    final bookmarks = ref.watch(bookmarkProvider);
    if (bookmarks.isEmpty) return [];

    final service = ref.read(uartApiServiceProvider);
    final List<PerformanceDetail> details = [];
    final List<String> expiredIds = [];

    final nowStr = DateFormat('yyyy.MM.dd').format(DateTime.now());

    for (final id in bookmarks) {
      try {
        final detail = await service.getPerformanceDetail(id);
        if (detail.endDate.compareTo(nowStr) < 0) {
          expiredIds.add(id);
        } else {
          details.add(detail);
        }
      } catch (e) {
        // Ignored
      }
    }

    if (expiredIds.isNotEmpty) {
      Future.microtask(() {
        for(final id in expiredIds) {
          ref.read(bookmarkProvider.notifier).toggleBookmark(id);
        }
      });
    }

    details.sort((a, b) => a.startDate.compareTo(b.startDate));
    return details;
  }
}
