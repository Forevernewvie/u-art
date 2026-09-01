import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:u_art/data/repositories/bookmark_repository.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/data/services/notification_service.dart';

part 'bookmark_view_model.g.dart';

@riverpod
class BookmarkNotifier extends _$BookmarkNotifier {
  @override
  List<String> build() {
    final repo = ref.watch(bookmarkRepositoryProvider);
    return repo.getBookmarks();
  }

  Future<void> toggleBookmark(String id) async {
    final repo = ref.read(bookmarkRepositoryProvider);
    await repo.toggleBookmark(id);
    state = repo.getBookmarks();

    final notiService = ref.read(notificationServiceProvider);
    if (state.contains(id)) {
      try {
        final uartService = ref.read(uartApiServiceProvider);
        final detail = await uartService.getPerformanceDetail(id);
        
        // Schedule D-1 Notification
        await notiService.scheduleD1Notification(detail);
        
        // Schedule Ticket Open Alert (simulated 5 seconds after bookmarking for Demo)
        if (detail.state.contains('예정')) {
          await notiService.scheduleTicketOpenNotification(detail);
        }
      } catch (e) {
        // Fallback gracefully without breaking bookmark state
      }
    } else {
      await notiService.cancelNotification(id);
    }
  }
}
