import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:u_art/ui/features/home/views/home_screen.dart';
import 'package:u_art/ui/features/search/views/search_screen.dart';
import 'package:u_art/ui/features/bookmark/views/bookmark_screen.dart';
import 'package:u_art/ui/features/detail/views/detail_screen.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/ui/features/home/view_models/home_view_model.dart';
import 'package:u_art/ui/features/search/view_models/search_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_list_view_model.dart';
import 'package:u_art/ui/features/detail/view_models/detail_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';
import 'mock_url_launcher.dart';
import 'mock_add_2_calendar.dart';

void main() {
  setUpAll(() {
    UrlLauncherPlatform.instance = MockUrlLauncherPlatform();
    setupMockAdd2Calendar();
  });

  testWidgets('HomeScreen loads and displays data', (tester) async {
    final performance = Performance(
      id: '1',
      title: 'Test Performance',
      startDate: '2023.01.01',
      endDate: '2023.12.31',
      venue: 'Test Venue',
      posterUrl: 'http://test.com/poster.jpg',
      genre: 'Musical',
      state: 'Playing',
      district: '전체',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeViewModelProvider.overrideWith(
            () => MockHomeViewModel([performance]),
          ),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Performance'), findsWidgets);
  });

  testWidgets('SearchScreen searches and displays data', (tester) async {
    final performance = Performance(
      id: '1',
      title: 'Test Performance',
      startDate: '2023.01.01',
      endDate: '2023.12.31',
      venue: 'Test Venue',
      posterUrl: 'http://test.com/poster.jpg',
      genre: 'Musical',
      state: 'Playing',
      district: '전체',
    );

    final mockSearch = MockSearchViewModel([performance]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchViewModelProvider.overrideWith(() => mockSearch)],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Test Performance'), findsWidgets);

    // Tap genre chip
    await tester.tap(find.text('뮤지컬').first);
    await tester.pumpAndSettle();
  });

  testWidgets('SearchScreen shows empty state', (tester) async {
    final mockSearch = MockSearchViewModel([]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [searchViewModelProvider.overrideWith(() => mockSearch)],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Test');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('해당 조건에 맞는 공연이 없습니다.'), findsOneWidget);
  });

  testWidgets('BookmarkScreen loads and displays data', (tester) async {
    final detail = PerformanceDetail(
      id: '1',
      title: 'Test Performance',
      startDate: '2023.01.01',
      endDate: '2023.12.31',
      venue: 'Test Venue',
      cast: 'Actor 1',
      runtime: '120m',
      timeGuidance: '19:30',
      ageLimit: '12+',
      price: '10000',
      posterUrl: 'http://test.com/poster.jpg',
      genre: 'Musical',
      state: 'Playing',
      district: '전체',
      bookingLinks: [],
      detailImages: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarkListViewModelProvider.overrideWith(
            () => MockBookmarkListViewModel([detail]),
          ),
        ],
        child: const MaterialApp(home: BookmarkScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Test Performance'), findsWidgets);
  });

  testWidgets('HomeScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeViewModelProvider.overrideWith(() => MockHomeViewModel([])),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('예정된 공연이 없습니다.'), findsOneWidget);
  });

  testWidgets('BookmarkScreen shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarkListViewModelProvider.overrideWith(
            () => MockBookmarkListViewModel([]),
          ),
        ],
        child: const MaterialApp(home: BookmarkScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('찜한 공연이 없습니다.'), findsOneWidget);
  });

  testWidgets(
    'DetailScreen loads and displays data with multiple booking links',
    (tester) async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'Test Performance',
        startDate: '2023.01.01',
        endDate: '2023.12.31',
        venue: 'Test Venue',
        cast: 'Actor 1',
        runtime: '120m',
        timeGuidance: '금요일(19:30)',
        ageLimit: '12+',
        price: '10000',
        posterUrl: 'http://test.com/poster.jpg',
        genre: 'Musical',
        state: '공연중',
        district: '전체',
        bookingLinks: [
          BookingLink(name: '인터파크', url: 'http://book.com'),
          BookingLink(name: '예스24', url: 'http://yes24.com'),
        ],
        detailImages: ['http://img.com'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            detailViewModelProvider(
              '1',
            ).overrideWith(() => MockDetailViewModel(detail)),
            bookmarkProvider.overrideWith(() => MockBookmarkNotifier(['1'])),
          ],
          child: const MaterialApp(home: DetailScreen(id: '1')),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Test Performance'), findsWidgets);
      expect(find.text('Actor 1'), findsOneWidget);
      expect(find.text('금요일(19:30)'), findsOneWidget);

      // Tap bookmark icon
      await tester.tap(find.byIcon(Icons.favorite));
      await tester.pump();

      // Tap calendar button with invalid date format (triggers error snackbar)
      await tester.tap(find.text('내 캘린더에 일정 추가'));
      await tester.pump();

      // Tap booking button (multiple vendors)
      await tester.tap(find.textContaining('예매처 바로가기'));
      await tester.pumpAndSettle();
      expect(find.text('예매처를 선택해주세요'), findsOneWidget);

      // Tap first vendor in modal sheet
      await tester.tap(find.text('인터파크'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('DetailScreen with single booking link and valid date calendar', (
    tester,
  ) async {
    final detail = PerformanceDetail(
      id: '2',
      title: 'Single Booking Test',
      startDate: '2026.10.01',
      endDate: '2026.10.02',
      venue: 'Test Venue',
      cast: 'Actor 2',
      runtime: '',
      timeGuidance: '',
      ageLimit: '',
      price: '',
      posterUrl: 'http://test.com/poster2.jpg',
      genre: 'Play',
      state: '공연예정',
      district: '전체',
      bookingLinks: [BookingLink(name: '인터파크', url: 'http://book.com')],
      detailImages: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          detailViewModelProvider(
            '2',
          ).overrideWith(() => MockDetailViewModel(detail)),
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
        ],
        child: const MaterialApp(home: DetailScreen(id: '2')),
      ),
    );

    await tester.pumpAndSettle();

    // Tap single booking button
    await tester.tap(find.textContaining('지금 예매하기'));
    await tester.pump();

    // Tap calendar button with valid date format
    await tester.tap(find.text('내 캘린더에 일정 추가'));
    await tester.pumpAndSettle();
    expect(find.text('캘린더 접근 권한이 필요합니다. 설정에서 권한을 허용해주세요.'), findsOneWidget);
  });

  testWidgets('DetailScreen with invalid calendar date', (tester) async {
    final detail = PerformanceDetail(
      id: '3',
      title: 'Test',
      startDate: 'invalid_date',
      endDate: 'invalid_date',
      venue: 'Test Venue',
      cast: '',
      runtime: '',
      timeGuidance: '',
      ageLimit: '',
      price: '',
      posterUrl: '',
      genre: '',
      state: '',
      district: '전체',
      bookingLinks: [],
      detailImages: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          detailViewModelProvider(
            '3',
          ).overrideWith(() => MockDetailViewModel(detail)),
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
        ],
        child: const MaterialApp(home: DetailScreen(id: '3')),
      ),
    );

    await tester.pumpAndSettle();

    // Tap calendar button with invalid date format (triggers error snackbar)
    await tester.tap(find.text('내 캘린더에 일정 추가'));
    await tester.pump();
    expect(find.text('일정 형식이 올바르지 않아 추가할 수 없습니다.'), findsOneWidget);
  });

  testWidgets('DetailScreen loading and error states', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          detailViewModelProvider(
            'error',
          ).overrideWith(() => MockDetailViewModelError()),
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
        ],
        child: const MaterialApp(home: DetailScreen(id: 'error')),
      ),
    );

    await tester.pump();

    await tester.pumpAndSettle();
    expect(find.textContaining('오류 발생'), findsOneWidget);
  });
}

class MockHomeViewModel extends HomeViewModel {
  final List<Performance> _data;
  MockHomeViewModel(this._data);
  @override
  Future<List<Performance>> build() async => _data;
}

class MockSearchViewModel extends SearchViewModel {
  final List<Performance> _data;
  MockSearchViewModel(this._data);
  @override
  Future<List<Performance>> build() async => _data;
  @override
  Future<void> search(String query, String genre) async {
    state = AsyncData(_data);
  }
}

class MockBookmarkListViewModel extends BookmarkListViewModel {
  final List<PerformanceDetail> _data;
  MockBookmarkListViewModel(this._data);
  @override
  Future<List<PerformanceDetail>> build() async => _data;
}

class MockDetailViewModel extends DetailViewModel {
  final PerformanceDetail _data;
  MockDetailViewModel(this._data);
  @override
  Future<PerformanceDetail> build(String id) async => _data;
}

class MockDetailViewModelError extends DetailViewModel {
  @override
  Future<PerformanceDetail> build(String id) async => throw Exception('error');
}

class MockBookmarkNotifier extends BookmarkNotifier {
  final List<String> _data;
  MockBookmarkNotifier(this._data);
  @override
  List<String> build() => _data;
  @override
  Future<void> toggleBookmark(String id) async {
    if (state.contains(id)) {
      state = [...state]..remove(id);
    } else {
      state = [...state, id];
    }
  }
}
