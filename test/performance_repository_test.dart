import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    late MockKopisService mockKopis;
    late PerformanceRepository repository;

    setUp(() {
      mockService = MockUartApiService();
      mockKopis = MockKopisService();
      repository = PerformanceRepository(mockService, kopisService: mockKopis);
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

    test(
      'in-memory cache returns data without calling service again',
      () async {
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
        verify(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        ).called(1);

        // Second call: served from memory cache (0ms, no service call)
        final res2 = await repository.getUpcomingPerformances();
        expect(res2.length, 1);
        verifyNever(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        );

        // Third call with forceRefresh: true calls service again
        final res3 = await repository.getUpcomingPerformances(
          forceRefresh: true,
        );
        expect(res3.length, 1);
        verify(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        ).called(1);
      },
    );

    test(
      'smart synthesis merges KOPIS title/poster with crawled venue/sold-out',
      () async {
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

        final results = await repository.getUpcomingPerformances(
          forceRefresh: true,
        );

        // Should be merged into exactly 1 performance card
        expect(results.length, 1);
        final merged = results.first;
        expect(merged.id, 'PF296392');
        expect(merged.title, '긴긴밤 [울산]');
        expect(merged.venue, '중구문화의전당 (함월홀(2층))');
        expect(merged.state, '매진');
        expect(merged.isSoldOut, isTrue);
        expect(merged.posterUrl, 'http://kopis.or.kr/poster.jpg');
      },
    );

    test(
      'getPerformanceDetail enriches Ginginbam price and sold out status',
      () async {
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

        when(
          mockKopis.getPerformanceDetail('PF296392'),
        ).thenAnswer((_) async => rawDetail);

        final enriched = await repository.getPerformanceDetail('PF296392');
        expect(enriched.price, '일반 10,000원');
        expect(enriched.state, '매진');
        expect(enriched.isSoldOut, isTrue);
        expect(enriched.bookingLinks, isNotEmpty);
        expect(enriched.bookingLinks.first.name, '중구문화의전당 공식 예매');
      },
    );

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

    test('PerformanceRepository defaults to concrete KopisService and JungguCrawlerService', () {
      final repo = PerformanceRepository(mockService);
      expect(repo, isNotNull);
    });

    test('getUpcomingPerformances loads from SharedPreferences disk cache when memory cache is cold', () async {
      SharedPreferences.setMockInitialValues({
        'cached_upcoming_performances_v1': jsonEncode([
          {
            'id': 'PF_DISK_01',
            'title': '디스크 캐시 공연',
            'startDate': '2026.09.10',
            'endDate': '2026.09.10',
            'venue': '울산문예회관',
            'posterUrl': '',
            'genre': '연극',
            'state': '공연중',
            'district': '남구',
          }
        ]),
      });

      PerformanceRepository.clearCache();
      final diskRepo = PerformanceRepository(
        mockService,
        kopisService: mockKopis,
      );
      final list = await diskRepo.getUpcomingPerformances();
      expect(list.length, 1);
      expect(list.first.id, 'PF_DISK_01');
    });

    test('getPerformanceDetail falls back to KOPIS service when backend service throws', () async {
      when(mockService.getPerformanceDetail('PF_FALLBACK'))
          .thenThrow(Exception('Backend 500'));
      when(mockKopis.getPerformanceDetail('PF_FALLBACK'))
          .thenAnswer((_) async => PerformanceDetail(
                id: 'PF_FALLBACK',
                title: '폴백 공연',
                startDate: '2026.09.10',
                endDate: '2026.09.10',
                venue: '울산문화예술회관 대공연장',
                cast: '출연진 정보 없음',
                runtime: '',
                timeGuidance: '',
                ageLimit: '',
                price: '전석 10,000원',
                posterUrl: '',
                genre: '클래식',
                state: '공연중',
                district: '남구',
                bookingLinks: [
                  BookingLink(name: '인터파크', url: 'http://interpark.com')
                ],
                detailImages: [],
              ));

      final detail = await repository.getPerformanceDetail('PF_FALLBACK');
      expect(detail.id, 'PF_FALLBACK');
      expect(detail.title, '폴백 공연');
    });

    test('synthesizePerformances handles kopis item with empty poster and genre and venue without parentheses', () {
      final crawled = Performance(
        id: 'CR01',
        title: '테스트 오페라',
        startDate: '2026.10.10',
        endDate: '2026.10.10',
        venue: '울산문예회관 대공연장',
        posterUrl: 'http://crawled.com/poster.jpg',
        genre: '오페라',
        state: '공연중',
        district: '남구',
      );
      final kopis = Performance(
        id: 'PF9999',
        title: '테스트 오페라 [울산]',
        startDate: '2026.10.10',
        endDate: '2026.10.10',
        venue: '울산문예회관',
        posterUrl: '',
        genre: '',
        state: '공연중',
        district: '전체',
      );

      final result = PerformanceRepository.synthesizePerformances([crawled, kopis]);
      expect(result.length, 1);
      expect(result.first.id, 'PF9999');
      expect(result.first.posterUrl, 'http://crawled.com/poster.jpg');
      expect(result.first.genre, '오페라');
      expect(result.first.venue, '울산문예회관');
      expect(result.first.district, '남구');
    });

    test('getPerformanceDetail enriches cast, runtime, time guidance, ageLimit, detailImages from KOPIS when primary detail has missing values', () async {
      final sparseDetail = PerformanceDetail(
        id: 'PF_SPARSE',
        title: '빈약한 공연',
        startDate: '2026.11.01',
        endDate: '2026.11.01',
        venue: '',
        cast: '출연진 정보 없음',
        runtime: '',
        timeGuidance: '',
        ageLimit: '',
        price: '공연장/기획사 문의',
        posterUrl: '',
        genre: '',
        state: '공연중',
        district: '중구',
        bookingLinks: [],
        detailImages: [],
      );

      final richKopis = PerformanceDetail(
        id: 'PF_SPARSE',
        title: '빈약한 공연',
        startDate: '2026.11.01',
        endDate: '2026.11.01',
        venue: '중구문화의전당 달빛마루',
        cast: '유명 배우',
        runtime: '120분',
        timeGuidance: '14:00, 18:00',
        ageLimit: '8세 이상',
        price: 'R석 50,000원',
        posterUrl: 'http://kopis.or.kr/poster2.jpg',
        genre: '뮤지컬',
        state: '공연중',
        district: '중구',
        bookingLinks: [
          BookingLink(name: '인터파크', url: 'http://interpark.com')
        ],
        detailImages: ['http://kopis.or.kr/detail.jpg'],
      );

      when(mockService.getPerformanceDetail('PF_SPARSE'))
          .thenAnswer((_) async => sparseDetail);
      when(mockKopis.getPerformanceDetail('PF_SPARSE'))
          .thenAnswer((_) async => richKopis);

      final enriched = await repository.getPerformanceDetail('PF_SPARSE');
      expect(enriched.cast, '유명 배우');
      expect(enriched.runtime, '120분');
      expect(enriched.timeGuidance, '14:00, 18:00');
      expect(enriched.ageLimit, '8세 이상');
      expect(enriched.price, 'R석 50,000원');
      expect(enriched.posterUrl, 'http://kopis.or.kr/poster2.jpg');
      expect(enriched.genre, '뮤지컬');
      expect(enriched.detailImages, ['http://kopis.or.kr/detail.jpg']);
    });

    test('getPerformancesInRange fetches from KOPIS when backend service returns empty or fails', () async {
      when(mockService.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
        venue: anyNamed('venue'),
      )).thenThrow(Exception('Backend 500'));
      when(mockKopis.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
        shprfnmfct: anyNamed('shprfnmfct'),
      )).thenAnswer((_) async => [
        Performance(
          id: 'PF_RANGE_01',
          title: '범위 공연',
          startDate: '2026.09.15',
          endDate: '2026.09.15',
          venue: '울산문화예술회관',
          posterUrl: '',
          genre: '무용',
          state: '공연예정',
          district: '남구',
        )
      ]);

      final results = await repository.getPerformancesInRange(
        startDate: DateTime(2026, 9, 1),
        endDate: DateTime(2026, 9, 30),
      );
      expect(results, isNotEmpty);
      expect(results.first.id, 'PF_RANGE_01');
    });
  });
}
