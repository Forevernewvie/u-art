import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:riverpod/riverpod.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/bookmark_repository.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:u_art/data/services/notification_service.dart';
import 'package:u_art/data/services/uart_api_service.dart';
import 'package:u_art/ui/features/home/view_models/home_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_list_view_model.dart';
import 'package:u_art/ui/features/search/view_models/search_view_model.dart';
import 'package:u_art/ui/features/detail/view_models/detail_view_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'view_models_test.mocks.dart';

class MockNotificationService extends NotificationService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> cancelNotification(String id) async {}

  @override
  Future<void> scheduleD1Notification(PerformanceDetail detail) async {}

  @override
  Future<void> scheduleTicketOpenNotification(PerformanceDetail detail) async {}
}

@GenerateMocks([KopisService, UartApiService])
void main() {
  group('ViewModels', () {
    late MockUartApiService mockService;
    late MockNotificationService mockNotiService;
    late ProviderContainer container;
    late SharedPreferences prefs;
    late BookmarkRepository bookmarkRepo;

    setUp(() async {
      mockService = MockUartApiService();
      mockNotiService = MockNotificationService();
      SharedPreferences.setMockInitialValues({
        'bookmarked_performances': ['1'],
      });
      prefs = await SharedPreferences.getInstance();
      bookmarkRepo = BookmarkRepository(prefs);

      container = ProviderContainer(
        overrides: [
          uartApiServiceProvider.overrideWithValue(mockService),
          bookmarkRepositoryProvider.overrideWithValue(bookmarkRepo),
          notificationServiceProvider.overrideWithValue(mockNotiService),
        ],
      );
    });

    test('HomeViewModel fetches performances', () async {
      when(
        mockService.getPerformances(
          stdate: anyNamed('stdate'),
          eddate: anyNamed('eddate'),
          venue: anyNamed('venue'),
          genre: anyNamed('genre'),
        ),
      ).thenAnswer((_) async => []);

      final state = await container.read(homeViewModelProvider.future);
      expect(state, isEmpty);

      await container.read(homeViewModelProvider.notifier).refresh();
      final refreshedState = await container.read(homeViewModelProvider.future);
      expect(refreshedState, isEmpty);
    });

    test('BookmarkNotifier toggles bookmark', () async {
      final notifier = container.read(bookmarkProvider.notifier);
      expect(container.read(bookmarkProvider), ['1']);

      final detail2 = PerformanceDetail(
        id: '2',
        title: 'T2',
        startDate: '2026.01.01',
        endDate: '2026.12.31',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );
      when(
        mockService.getPerformanceDetail('2'),
      ).thenAnswer((_) async => detail2);

      await notifier.toggleBookmark('2');
      expect(container.read(bookmarkProvider), ['1', '2']);

      await notifier.toggleBookmark('1');
      expect(container.read(bookmarkProvider), ['2']);
    });

    test('BookmarkListViewModel fetches details and removes expired', () async {
      // Mock past end date for ID 1
      final expiredDetail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: '2020.01.01',
        endDate: '2020.01.01',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: 'S',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );
      when(
        mockService.getPerformanceDetail('1'),
      ).thenAnswer((_) async => expiredDetail);

      final state = await container.read(bookmarkListViewModelProvider.future);
      expect(state, isEmpty);

      await Future.delayed(Duration.zero);
      expect(container.read(bookmarkProvider), isEmpty);
    });

    test('BookmarkListViewModel returns valid details', () async {
      final validDetail = PerformanceDetail(
        id: '2',
        title: 'T',
        startDate: '2099.01.01',
        endDate: '2099.01.01',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );
      when(
        mockService.getPerformanceDetail('2'),
      ).thenAnswer((_) async => validDetail);
      await container.read(bookmarkProvider.notifier).toggleBookmark('2');

      when(mockService.getPerformanceDetail('1')).thenThrow(Exception('Error'));

      final state = await container.read(bookmarkListViewModelProvider.future);
      expect(state.length, 1);
      expect(state.first.id, '2');
    });

    test(
      'SearchViewModel searches with query, venue name, and genre',
      () async {
        final p1 = Performance(
          id: '1',
          title: 'Test Musical',
          startDate: '2023.01.01',
          endDate: '2023.01.01',
          venue: '울산문화예술회관',
          posterUrl: '',
          genre: '뮤지컬',
          state: 'S',
          district: '전체',
        );
        final p2 = Performance(
          id: '2',
          title: 'Test Play',
          startDate: '2023.01.02',
          endDate: '2023.01.02',
          venue: '중구문화의전당',
          posterUrl: '',
          genre: '연극',
          state: 'S',
          district: '전체',
        );

        when(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        ).thenAnswer((_) async => [p1, p2]);

        // Wait for initial build to complete
        await container.read(searchViewModelProvider.future);

        final notifier = container.read(searchViewModelProvider.notifier);

        // Search by title
        await notifier.search('Musical', '전체');
        var state = container.read(searchViewModelProvider).value!;
        expect(state.length, 1);
        expect(state.first.id, '1');

        // Search by venue name
        await notifier.search('중구', '전체');
        state = container.read(searchViewModelProvider).value!;
        expect(state.length, 1);
        expect(state.first.id, '2');

        // Search by genre
        await notifier.search('', '연극');
        state = container.read(searchViewModelProvider).value!;
        expect(state.length, 1);
        expect(state.first.id, '2');

        // Refresh
        await notifier.refresh();
        state = container.read(searchViewModelProvider).value!;
        expect(state.length, 2);
      },
    );

    test('SearchViewModel calculates date correctly', () {
      final notifier = container.read(searchViewModelProvider.notifier);

      // Jan-Oct
      final dateMay = DateTime(2026, 5, 1);
      expect(notifier.calculateEndDate(dateMay), DateTime(2026, 12, 31));

      // Nov-Dec (non-leap year)
      final dateNov = DateTime(2025, 11, 15);
      expect(notifier.calculateEndDate(dateNov), DateTime(2026, 2, 28));

      // Nov-Dec (leap year 2028 has 29 days)
      final dateNovLeap = DateTime(2027, 11, 15);
      expect(notifier.calculateEndDate(dateNovLeap), DateTime(2028, 2, 29));
    });

    test('DetailViewModel fetches single detail', () async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: 'S',
        endDate: 'E',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'TG',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'P',
        genre: 'G',
        state: 'S',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );
      when(
        mockService.getPerformanceDetail('1'),
      ).thenAnswer((_) async => detail);

      final state = await container.read(detailViewModelProvider('1').future);
      expect(state.id, '1');
    });
  });
}
