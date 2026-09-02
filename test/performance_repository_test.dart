import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:u_art/data/services/uart_api_service.dart';
import 'package:riverpod/riverpod.dart';

import 'performance_repository_test.mocks.dart';

@GenerateMocks([KopisService, UartApiService])
void main() {
  group('PerformanceRepository', () {
    late MockUartApiService mockService;
    late PerformanceRepository repository;

    setUp(() {
      mockService = MockUartApiService();
      repository = PerformanceRepository(mockService);
    });

    test('getUpcomingPerformances returns sorted combined list', () async {
      final p1 = Performance(
        id: '1',
        title: 'A',
        startDate: '2023.01.02',
        endDate: '2023.01.02',
        venue: 'V',
        posterUrl: '',
        genre: 'G',
        state: 'S',
        district: '전체',
      );
      final p2 = Performance(
        id: '2',
        title: 'B',
        startDate: '2023.01.01',
        endDate: '2023.01.01',
        venue: 'V',
        posterUrl: '',
        genre: 'G',
        state: 'S',
        district: '전체',
      );

      when(
        mockService.getPerformances(
          stdate: anyNamed('stdate'),
          eddate: anyNamed('eddate'),
          venue: '울산문화예술회관',
        ),
      ).thenAnswer((_) async => [p1]);

      when(
        mockService.getPerformances(
          stdate: anyNamed('stdate'),
          eddate: anyNamed('eddate'),
          venue: '중구문화의전당',
        ),
      ).thenAnswer((_) async => [p2]);

      final result = await repository.getUpcomingPerformances();

      expect(result.length, 2);
      expect(result.first.id, '2');
      expect(result.last.id, '1');
    });

    test('getPerformanceDetail calls service', () async {
      final detail = PerformanceDetail(
        id: '1',
        title: 'A',
        startDate: 'S',
        endDate: 'E',
        venue: 'V',
        cast: 'C',
        runtime: 'R',
        timeGuidance: 'T',
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

      final result = await repository.getPerformanceDetail('1');
      expect(result, detail);
    });

    test('in-memory cache returns data without calling service again', () async {
      PerformanceRepository.clearCache();
      final p1 = Performance(
        id: '1',
        title: 'Cached Perf',
        startDate: '2026.09.02',
        endDate: '2026.09.02',
        venue: '울산문화예술회관',
        posterUrl: '',
        genre: '뮤지컬',
        state: '공연예정',
        district: '전체',
      );

      when(
        mockService.getPerformances(
          stdate: anyNamed('stdate'),
          eddate: anyNamed('eddate'),
        ),
      ).thenAnswer((_) async => [p1]);

      // First call: hits service
      final res1 = await repository.getUpcomingPerformances();
      expect(res1.length, 1);
      verify(mockService.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
      )).called(1);

      // Second call: served from memory cache (0ms, no service call)
      final res2 = await repository.getUpcomingPerformances();
      expect(res2.length, 1);
      verifyNever(mockService.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
      ));

      // Third call with forceRefresh: true calls service again
      final res3 = await repository.getUpcomingPerformances(forceRefresh: true);
      expect(res3.length, 1);
      verify(mockService.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
      )).called(1);
    });

    test('smart synthesis merges KOPIS title/poster with crawled venue/sold-out', () async {
      PerformanceRepository.clearCache();
      final kopisItem = Performance(
        id: 'PF296392',
        title: '긴긴밤 [울산]',
        startDate: '2026.09.05',
        endDate: '2026.09.05',
        venue: '울산중구문화의전당',
        posterUrl: 'http://kopis.or.kr/poster.jpg',
        genre: '한국음악(국악)',
        state: '공연예정',
        district: '전체',
      );
      final crawledItem = Performance(
        id: 'junggu_8735792628459320356',
        title: '입과손스튜디오 <긴긴밤>',
        startDate: '2026.09.05',
        endDate: '2026.09.05',
        venue: '중구문화의전당 (함월홀(2층))',
        posterUrl: '',
        genre: '',
        state: '매진',
        district: '전체',
      );

      when(
        mockService.getPerformances(
          stdate: anyNamed('stdate'),
          eddate: anyNamed('eddate'),
        ),
      ).thenAnswer((_) async => [kopisItem, crawledItem]);

      final results = await repository.getUpcomingPerformances(forceRefresh: true);

      // Should be merged into exactly 1 performance card
      expect(results.length, 1);
      final merged = results.first;
      expect(merged.id, 'PF296392');
      expect(merged.title, '긴긴밤 [울산]');
      expect(merged.venue, '중구문화의전당 (함월홀(2층))');
      expect(merged.state, '매진');
      expect(merged.isSoldOut, isTrue);
      expect(merged.posterUrl, 'http://kopis.or.kr/poster.jpg');
    });

    test('getPerformanceDetail enriches Ginginbam price and sold out status', () async {
      final rawDetail = PerformanceDetail(
        id: 'PF296392',
        title: '긴긴밤 [울산]',
        startDate: '2026.09.05',
        endDate: '2026.09.05',
        venue: '울산중구문화의전당',
        cast: '입과손스튜디오',
        runtime: '70분',
        timeGuidance: '15:00',
        ageLimit: '만 7세 이상',
        price: '무료',
        posterUrl: 'http://kopis.or.kr/poster.jpg',
        genre: '국악',
        state: '공연예정',
        district: '전체',
        bookingLinks: [],
        detailImages: [],
      );

      when(
        mockService.getPerformanceDetail('PF296392'),
      ).thenAnswer((_) async => rawDetail);

      final enriched = await repository.getPerformanceDetail('PF296392');
      expect(enriched.price, '일반 10,000원');
      expect(enriched.state, '매진');
      expect(enriched.isSoldOut, isTrue);
      expect(enriched.bookingLinks, isNotEmpty);
      expect(enriched.bookingLinks.first.name, '중구문화의전당 공식 예매');
    });

    test('uartApiService provider works', () {
      final container = ProviderContainer();
      final service = container.read(uartApiServiceProvider);
      expect(service, isA<UartApiService>());
    });

    test('performanceRepository provider works', () {
      final container = ProviderContainer();
      final repo = container.read(performanceRepositoryProvider);
      expect(repo, isA<PerformanceRepository>());
    });
  });
}
