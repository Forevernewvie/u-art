import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mockito/mockito.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/ui/features/search/view_models/search_view_model.dart';
import 'package:u_art/ui/features/detail/views/detail_screen.dart';
import 'package:u_art/ui/features/detail/view_models/detail_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart';
import 'package:u_art/ui/features/home/views/home_screen.dart';
import 'package:u_art/ui/features/home/view_models/home_view_model.dart';
import 'package:u_art/ui/features/search/views/search_screen.dart';
import 'package:u_art/ui/features/bookmark/views/bookmark_screen.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_list_view_model.dart';

import 'mock_url_launcher.dart';
import 'mock_add_2_calendar.dart';
import 'view_models_test.mocks.dart';

class MockDetailViewModel extends DetailViewModel {
  final PerformanceDetail _data;
  MockDetailViewModel(this._data);

  @override
  Future<PerformanceDetail> build(String id) async => _data;
}

class MockBookmarkNotifier extends BookmarkNotifier {
  final List<String> _data;
  MockBookmarkNotifier(this._data);

  @override
  List<String> build() => _data;

  @override
  Future<void> toggleBookmark(String id) async {}
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
}

class MockBookmarkListViewModel extends BookmarkListViewModel {
  final List<PerformanceDetail> _data;
  MockBookmarkListViewModel(this._data);
  @override
  Future<List<PerformanceDetail>> build() async => _data;
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    UrlLauncherPlatform.instance = MockUrlLauncherPlatform();
    setupMockAdd2Calendar();
  });

  group('Coverage Boost: SearchViewModel', () {
    test(
      'search triggers _loadAllUlsanPerformances when _cachedAllPerformances is empty',
      () async {
        final mockService = MockUartApiService();
        final mockKopis = MockKopisService();
        final repo = PerformanceRepository(mockService, kopisService: mockKopis);

        final p = Performance(
          id: 'PF_SEARCH_01',
          title: '봄의 소리 음악회',
          startDate: '2026.04.10',
          endDate: '2026.04.10',
          venue: '울산문화예술회관 대공연장',
          posterUrl: '',
          genre: '클래식',
          state: '공연예정',
          district: '남구',
        );

        // Initial build will receive empty list so _cachedAllPerformances remains empty
        when(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        ).thenAnswer((_) async => []);

        final container = ProviderContainer(
          overrides: [
            performanceRepositoryProvider.overrideWithValue(repo),
          ],
        );

        // Wait for build() to complete with empty list
        final initialList = await container.read(searchViewModelProvider.future);
        expect(initialList, isEmpty);

        // Next call during search should return performances
        when(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        ).thenAnswer((_) async => [p]);

        final notifier = container.read(searchViewModelProvider.notifier);

        // Call search when _cachedAllPerformances is empty -> executes lines 45-51
        await notifier.search('봄의 소리', '클래식');

        final searchState = container.read(searchViewModelProvider);
        expect(searchState.hasValue, isTrue);
        expect(searchState.value!.length, 1);
        expect(searchState.value!.first.id, 'PF_SEARCH_01');
      },
    );
  });

  group('Coverage Boost: DetailScreen', () {
    testWidgets(
      'DetailScreen renders with empty bookingLinks and triggers _showNoBookingDialog',
      (tester) async {
        final detailNoBooking = PerformanceDetail(
          id: 'DETAIL_NO_BOOKING',
          title: '무료 기획 공연',
          startDate: '2026.05.01',
          endDate: '2026.05.01',
          venue: '울산중구문화의전당 함월홀',
          cast: '울산예술단',
          runtime: '90분',
          timeGuidance: '19:30',
          ageLimit: '전체관람가',
          price: '무료',
          posterUrl: 'http://test.com/poster.jpg',
          genre: '연극',
          state: '공연예정',
          district: '중구',
          bookingLinks: [], // Empty booking links
          detailImages: [], // Empty detail images to render Junggu info banner (lines 237-242)
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              detailViewModelProvider('DETAIL_NO_BOOKING').overrideWith(
                () => MockDetailViewModel(detailNoBooking),
              ),
              bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
            ],
            child: const MaterialApp(
              home: DetailScreen(id: 'DETAIL_NO_BOOKING'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify Junggu banner info is rendered (lines 237-242)
        expect(find.text('공연 상세 안내'), findsOneWidget);
        expect(
          find.textContaining('중구문화의전당 공식 공연입니다'),
          findsOneWidget,
        );

        // Verify bottom button label for no booking
        final noBookingBtn = find.text('현장 발권 / 공연장 문의 요망');
        expect(noBookingBtn, findsOneWidget);

        // Test CachedNetworkImage errorWidget (line 65)
        final cachedImage = tester.widget<CachedNetworkImage>(
          find.byType(CachedNetworkImage).first,
        );
        final errorWidget = cachedImage.errorWidget?.call(
          tester.element(find.byType(CachedNetworkImage).first),
          'http://test.com/poster.jpg',
          Exception('network error'),
        );
        expect(errorWidget, isNotNull);

        // Tap bottom button to trigger _showNoBookingDialog (lines 292, 419-454)
        await tester.tap(noBookingBtn);
        await tester.pumpAndSettle();

        // Verify dialog is shown with title '예매 안내'
        expect(find.text('예매 안내'), findsOneWidget);
        expect(
          find.textContaining('온라인 예매처가 별도로 등록되지 않은 공연입니다'),
          findsOneWidget,
        );

        // Tap '확인' button to dismiss dialog (lines 449-450)
        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();

        // Verify dialog is dismissed
        expect(find.text('예매 안내'), findsNothing);
      },
    );

    testWidgets(
      'DetailScreen triggers multiple booking links modal bottom sheet',
      (tester) async {
        final detailMultiBooking = PerformanceDetail(
          id: 'DETAIL_MULTI_BOOKING',
          title: '다중 예매처 공연',
          startDate: '2026.06.01',
          endDate: '2026.06.01',
          venue: '울산중구문화의전당 달빛마루',
          cast: '배우A, 배우B',
          runtime: '120분',
          timeGuidance: '14:00, 19:00',
          ageLimit: '8세 이상',
          price: '전석 20,000원',
          posterUrl: 'http://test.com/poster2.jpg',
          genre: '뮤지컬',
          state: '공연중',
          district: '중구',
          bookingLinks: [
            BookingLink(name: '인터파크 티켓', url: 'https://interpark.com'),
            BookingLink(name: '예스24 티켓', url: 'https://yes24.com'),
          ],
          detailImages: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              detailViewModelProvider('DETAIL_MULTI_BOOKING').overrideWith(
                () => MockDetailViewModel(detailMultiBooking),
              ),
              bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
            ],
            child: const MaterialApp(
              home: DetailScreen(id: 'DETAIL_MULTI_BOOKING'),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap bottom button with multiple booking links
        final multiBookingBtn = find.textContaining('예매처 바로가기 (2곳)');
        expect(multiBookingBtn, findsOneWidget);
        await tester.tap(multiBookingBtn);
        await tester.pumpAndSettle();

        // Verify modal bottom sheet appears
        expect(find.text('예매처를 선택해주세요'), findsOneWidget);
        expect(find.text('인터파크 티켓'), findsOneWidget);
        expect(find.text('예스24 티켓'), findsOneWidget);

        // Tap a link to dismiss sheet and trigger URL launch
        await tester.tap(find.text('예스24 티켓'));
        await tester.pumpAndSettle();

        expect(find.text('예매처를 선택해주세요'), findsNothing);
      },
    );
  });

  group('Coverage Boost: PerformanceRepository', () {
    late MockUartApiService mockService;
    late MockKopisService mockKopis;
    late PerformanceRepository repository;

    setUp(() {
      mockService = MockUartApiService();
      mockKopis = MockKopisService();
      repository = PerformanceRepository(mockService, kopisService: mockKopis);
    });

    test(
      'synthesizePerformances reverse match: existingTitle.contains(normTitle) (line 189)',
      () {
        // existingTitle is longer than new normTitle
        final existingLongTitle = Performance(
          id: 'PF_LONG',
          title: '울산시립합창단 제110회 정기연주회 가을의 향기 콘서트',
          startDate: '2026.10.20',
          endDate: '2026.10.20',
          venue: '울산문화예술회관 대공연장',
          posterUrl: 'http://test.com/p1.jpg',
          genre: '클래식',
          state: '공연예정',
          district: '남구',
        );

        final newShortTitle = Performance(
          id: 'CR_SHORT',
          title: '가을의 향기 콘서트',
          startDate: '2026.10.20',
          endDate: '2026.10.20',
          venue: '울산문예회관',
          posterUrl: 'http://test.com/p2.jpg',
          genre: '클래식',
          state: '공연예정',
          district: '남구',
        );

        final result = PerformanceRepository.synthesizePerformances([
          existingLongTitle,
          newShortTitle,
        ]);

        expect(result.length, 1);
        expect(result.first.id, 'PF_LONG');
      },
    );

    test(
      'synthesizePerformances state fallback when kopisItem.state is empty (line 221)',
      () {
        // Case 1: kopisItem.state is empty, crawledItem.state is '공연중'
        final kopisStateEmpty = Performance(
          id: 'PF_NO_STATE',
          title: '상태 없는 공연',
          startDate: '2026.11.01',
          endDate: '2026.11.01',
          venue: '울산문화예술회관',
          posterUrl: '',
          genre: '연극',
          state: '', // Empty state
          district: '전체',
        );

        final crawledWithState = Performance(
          id: 'CR_HAS_STATE',
          title: '상태 없는 공연',
          startDate: '2026.11.01',
          endDate: '2026.11.01',
          venue: '울산문화예술회관 소공연장',
          posterUrl: 'http://test.com/poster.jpg',
          genre: '연극',
          state: '공연중',
          district: '남구',
        );

        final resultWithState = PerformanceRepository.synthesizePerformances([
          kopisStateEmpty,
          crawledWithState,
        ]);

        expect(resultWithState.length, 1);
        expect(resultWithState.first.state, '공연중');

        // Case 2: both kopisItem.state and crawledItem.state are empty -> fallback '공연예정'
        final crawledEmptyState = Performance(
          id: 'CR_NO_STATE',
          title: '상태 없는 공연',
          startDate: '2026.11.01',
          endDate: '2026.11.01',
          venue: '울산문화예술회관 소공연장',
          posterUrl: '',
          genre: '연극',
          state: '', // Also empty
          district: '남구',
        );

        final resultFallback = PerformanceRepository.synthesizePerformances([
          kopisStateEmpty,
          crawledEmptyState,
        ]);

        expect(resultFallback.length, 1);
        expect(resultFallback.first.state, '공연예정');
      },
    );

    test(
      'getPerformanceDetail preserves detail.price when kopisDetail.price is empty or 공연장/기획사 문의 (line 252)',
      () async {
        final primaryDetail = PerformanceDetail(
          id: 'PF_ENRICH_PRICE',
          title: '가격 보존 테스트',
          startDate: '2026.09.20',
          endDate: '2026.09.20',
          venue: '울산문화예술회관',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '',
          price: '전석 25,000원',
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: [], // Triggers enrichment because bookingLinks is empty
          detailImages: [],
        );

        // KOPIS detail returns price as '공연장/기획사 문의'
        final kopisDetail1 = PerformanceDetail(
          id: 'PF_ENRICH_PRICE',
          title: '가격 보존 테스트',
          startDate: '2026.09.20',
          endDate: '2026.09.20',
          venue: '울산문화예술회관',
          cast: '캐스트1',
          runtime: '90분',
          timeGuidance: '19:00',
          ageLimit: '전체',
          price: '공연장/기획사 문의', // Should not override primary price
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: [BookingLink(name: '인터파크', url: 'http://interpark.com')],
          detailImages: [],
        );

        when(mockService.getPerformanceDetail('PF_ENRICH_PRICE'))
            .thenAnswer((_) async => primaryDetail);
        when(mockKopis.getPerformanceDetail('PF_ENRICH_PRICE'))
            .thenAnswer((_) async => kopisDetail1);

        final res1 = await repository.getPerformanceDetail('PF_ENRICH_PRICE');
        expect(res1.price, '전석 25,000원');

        // KOPIS detail returns empty price
        final kopisDetail2 = PerformanceDetail(
          id: 'PF_ENRICH_PRICE',
          title: '가격 보존 테스트',
          startDate: '2026.09.20',
          endDate: '2026.09.20',
          venue: '울산문화예술회관',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '',
          price: '', // Empty price
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: [],
          detailImages: [],
        );

        when(mockKopis.getPerformanceDetail('PF_ENRICH_PRICE'))
            .thenAnswer((_) async => kopisDetail2);

        final res2 = await repository.getPerformanceDetail('PF_ENRICH_PRICE');
        expect(res2.price, '전석 25,000원');
      },
    );

    test(
      'getPerformanceDetail preserves detail.bookingLinks when not empty (line 254)',
      () async {
        final originalLinks = [
          BookingLink(name: '자체예매', url: 'https://venue.com/tickets'),
        ];

        final primaryDetail = PerformanceDetail(
          id: 'PF_ENRICH_LINKS',
          title: '예매링크 보존 테스트',
          startDate: '2026.09.22',
          endDate: '2026.09.22',
          venue: '울산문화예술회관',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '',
          price: '공연장/기획사 문의', // Triggers enrichment because price is 문의
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: originalLinks, // Non-empty booking links
          detailImages: [],
        );

        final kopisDetail = PerformanceDetail(
          id: 'PF_ENRICH_LINKS',
          title: '예매링크 보존 테스트',
          startDate: '2026.09.22',
          endDate: '2026.09.22',
          venue: '울산문화예술회관',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '',
          price: '전석 10,000원',
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: [
            BookingLink(name: 'KOPIS예매처', url: 'https://kopis.or.kr/ticket'),
          ],
          detailImages: [],
        );

        when(mockService.getPerformanceDetail('PF_ENRICH_LINKS'))
            .thenAnswer((_) async => primaryDetail);
        when(mockKopis.getPerformanceDetail('PF_ENRICH_LINKS'))
            .thenAnswer((_) async => kopisDetail);

        final res = await repository.getPerformanceDetail('PF_ENRICH_LINKS');
        expect(res.bookingLinks, originalLinks);
        expect(res.price, '전석 10,000원');
      },
    );

    test(
      'getPerformanceDetail preserves detail.detailImages when not empty (line 283)',
      () async {
        final originalImages = [
          'http://test.com/original_detail1.jpg',
          'http://test.com/original_detail2.jpg',
        ];

        final primaryDetail = PerformanceDetail(
          id: 'PF_ENRICH_IMAGES',
          title: '상세이미지 보존 테스트',
          startDate: '2026.09.25',
          endDate: '2026.09.25',
          venue: '울산문화예술회관',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '',
          price: '공연장/기획사 문의', // Triggers enrichment
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: [],
          detailImages: originalImages, // Non-empty detail images
        );

        final kopisDetail = PerformanceDetail(
          id: 'PF_ENRICH_IMAGES',
          title: '상세이미지 보존 테스트',
          startDate: '2026.09.25',
          endDate: '2026.09.25',
          venue: '울산문화예술회관',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '',
          price: '전석 10,000원',
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
          bookingLinks: [],
          detailImages: ['http://kopis.or.kr/kopis_image.jpg'],
        );

        when(mockService.getPerformanceDetail('PF_ENRICH_IMAGES'))
            .thenAnswer((_) async => primaryDetail);
        when(mockKopis.getPerformanceDetail('PF_ENRICH_IMAGES'))
            .thenAnswer((_) async => kopisDetail);

        final res = await repository.getPerformanceDetail('PF_ENRICH_IMAGES');
        expect(res.detailImages, originalImages);
      },
    );
  });

  group('Coverage Boost: UI errorWidgets and Riverpod boilerplate', () {
    testWidgets('HomeScreen errorWidgets render fallback icons', (tester) async {
      final perf = Performance(
        id: '1',
        title: 'T',
        startDate: 'S',
        endDate: 'E',
        venue: 'V',
        posterUrl: 'invalid',
        genre: 'G',
        state: '공연중',
        district: '전체',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeViewModelProvider.overrideWith(
              () => MockHomeViewModel([perf]),
            ),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );
      await tester.pump();
      final homeImages = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      for (final img in homeImages) {
        if (img.errorWidget != null) {
          final w = img.errorWidget!(
            tester.element(find.byType(HomeScreen)),
            'url',
            'err',
          );
          expect(w, isA<Icon>());
        }
      }
    });

    testWidgets('SearchScreen errorWidget renders fallback icon', (tester) async {
      final perf = Performance(
        id: '1',
        title: 'T',
        startDate: 'S',
        endDate: 'E',
        venue: 'V',
        posterUrl: 'invalid',
        genre: 'G',
        state: '공연중',
        district: '전체',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            searchViewModelProvider.overrideWith(
              () => MockSearchViewModel([perf]),
            ),
          ],
          child: const MaterialApp(home: SearchScreen()),
        ),
      );
      await tester.pump();
      final searchImages = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      for (final img in searchImages) {
        if (img.errorWidget != null) {
          final w = img.errorWidget!(
            tester.element(find.byType(SearchScreen)),
            'url',
            'err',
          );
          expect(w, isA<Icon>());
        }
      }
    });

    testWidgets('BookmarkScreen errorWidget renders fallback icon', (tester) async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'T',
        startDate: 'S',
        endDate: 'E',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'T',
        ageLimit: 'A',
        price: 'P',
        posterUrl: 'invalid',
        genre: 'G',
        state: '공연중',
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
            bookmarkProvider.overrideWith(() => MockBookmarkNotifier(['1'])),
          ],
          child: const MaterialApp(home: BookmarkScreen()),
        ),
      );
      await tester.pump();
      final bmImages = tester.widgetList<CachedNetworkImage>(
        find.byType(CachedNetworkImage),
      );
      for (final img in bmImages) {
        if (img.errorWidget != null) {
          final w = img.errorWidget!(
            tester.element(find.byType(BookmarkScreen)),
            'url',
            'err',
          );
          expect(w, isA<Icon>());
        }
      }
    });

    test('Riverpod generated boilerplate coverage', () {
      expect(
        detailViewModelProvider.toString(),
        contains('detailViewModelProvider'),
      );
      expect(
        detailViewModelProvider('123').toString(),
        contains('detailViewModelProvider'),
      );
      final overrideVal = bookmarkProvider.overrideWithValue(['test']);
      expect(overrideVal, isNotNull);
    });
  });
}
