import 'package:shared_preferences/shared_preferences.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'bookmark_repository.g.dart';

@riverpod
BookmarkRepository bookmarkRepository(Ref ref) {
  throw UnimplementedError(
    'Initialize with SharedPreferences in main.dart or use FutureProvider',
  );
}

class BookmarkRepository {
  static const String _key = 'bookmarked_performances';
  final SharedPreferences _prefs;

  BookmarkRepository(this._prefs);

  List<String> getBookmarks() {
    return _prefs.getStringList(_key) ?? [];
  }

  Future<void> toggleBookmark(String id) async {
    final bookmarks = getBookmarks();
    if (bookmarks.contains(id)) {
      bookmarks.remove(id);
    } else {
      bookmarks.add(id);
    }
    await _prefs.setStringList(_key, bookmarks);
  }

  Future<void> removeBookmarks(List<String> idsToRemove) async {
    final bookmarks = getBookmarks();
    bookmarks.removeWhere((id) => idsToRemove.contains(id));
    await _prefs.setStringList(_key, bookmarks);
  }

  bool isBookmarked(String id) {
    return getBookmarks().contains(id);
  }
}
