import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:u_art/data/repositories/bookmark_repository.dart';
import 'package:riverpod/riverpod.dart';

void main() {
  group('BookmarkRepository', () {
    late SharedPreferences prefs;
    late BookmarkRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'bookmarked_performances': ['1', '2']});
      prefs = await SharedPreferences.getInstance();
      repository = BookmarkRepository(prefs);
    });

    test('getBookmarks returns list', () {
      expect(repository.getBookmarks(), ['1', '2']);
    });

    test('toggleBookmark adds if not present', () async {
      await repository.toggleBookmark('3');
      expect(repository.getBookmarks(), ['1', '2', '3']);
    });

    test('toggleBookmark removes if present', () async {
      await repository.toggleBookmark('2');
      expect(repository.getBookmarks(), ['1']);
    });

    test('removeBookmarks removes specific ids', () async {
      await repository.removeBookmarks(['1', '3']);
      expect(repository.getBookmarks(), ['2']);
    });

    test('isBookmarked returns correctly', () {
      expect(repository.isBookmarked('1'), isTrue);
      expect(repository.isBookmarked('3'), isFalse);
    });

    test('bookmarkRepository provider throws unimplemented', () {
      final container = ProviderContainer();
      expect(
        () => container.read(bookmarkRepositoryProvider),
        throwsException,
      );
    });
  });
}
