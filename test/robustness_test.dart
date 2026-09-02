import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/repositories/performance_repository.dart';
import 'package:u_art/ui/features/search/view_models/search_view_model.dart';

import 'performance_repository_test.mocks.dart';

void main() {
  group('Robustness: Performance Model Serialization & Deserialization', () {
    test('toJson and fromJson round-trip perfectly preserves all fields', () {
      final original = Performance(
        id: 'PF_TEST_99',
        title: '테스트 뮤지컬 [울산]',
        startDate: '2026.10.15',
        endDate: '2026.10.20',
        venue: '울산문화예술회관 (대공연장)',
        posterUrl: 'https://example.com/poster.jpg',
        genre: '뮤지컬',
        state: '매진',
        district: '남구',
      );

      final jsonMap = original.toJson();
      expect(jsonMap['id'], 'PF_TEST_99');
      expect(jsonMap['isSoldOut'], isTrue);

      final restored = Performance.fromJson(jsonMap);
      expect(restored.id, original.id);
      expect(restored.title, original.title);
      expect(restored.startDate, original.startDate);
      expect(restored.endDate, original.endDate);
      expect(restored.venue, original.venue);
      expect(restored.posterUrl, original.posterUrl);
      expect(restored.genre, original.genre);
      expect(restored.state, '매진');
      expect(restored.isSoldOut, isTrue);
      expect(restored.district, original.district);
    });

    test(
      'fromJson handles null and missing fields gracefully with safe fallbacks',
      () {
        final corruptedJson = <String, dynamic>{
          'id': null,
          'title': null,
          'startDate': null,
          'state': null,
        };

        final perf = Performance.fromJson(corruptedJson);
        expect(perf.id, isEmpty);
        expect(perf.title, isEmpty);
        expect(perf.startDate, isEmpty);
        expect(perf.state, '공연예정');
        expect(perf.district, '전체');
        expect(perf.isSoldOut, isFalse);
      },
    );

    test('isSoldOut detects various sold-out keywords across cases', () {
      expect(
        Performance(
          id: '1',
          title: 'T',
          startDate: 'S',
          endDate: 'E',
          venue: 'V',
          posterUrl: '',
          genre: 'G',
          state: '매진',
          district: 'D',
        ).isSoldOut,
        isTrue,
      );

      expect(
        Performance(
          id: '2',
          title: 'T',
          startDate: 'S',
          endDate: 'E',
          venue: 'V',
          posterUrl: '',
          genre: 'G',
          state: 'SOLD OUT',
          district: 'D',
        ).isSoldOut,
        isTrue,
      );

      expect(
        Performance(
          id: '3',
          title: 'T',
          startDate: 'S',
          endDate: 'E',
          venue: 'V',
          posterUrl: '',
          genre: 'G',
          state: '공연완료',
          district: 'D',
        ).isSoldOut,
        isTrue,
      );

      expect(
        Performance(
          id: '4',
          title: 'T',
          startDate: 'S',
          endDate: 'E',
          venue: 'V',
          posterUrl: '',
          genre: 'G',
          state: '예매마감',
          district: 'D',
        ).isSoldOut,
        isTrue,
      );

      expect(
        Performance(
          id: '5',
          title: 'T',
          startDate: 'S',
          endDate: 'E',
          venue: 'V',
          posterUrl: '',
          genre: 'G',
          state: '공연중',
          district: 'D',
        ).isSoldOut,
        isFalse,
      );
    });
  });

  group('Robustness: PerformanceRepository Fallbacks & Edge Cases', () {
    late MockUartApiService mockService;
    late MockKopisService mockKopis;
    late PerformanceRepository repo;

    setUp(() {
      mockService = MockUartApiService();
      mockKopis = MockKopisService();
      repo = PerformanceRepository(mockService, kopisService: mockKopis);
      PerformanceRepository.clearCache();
    });

    test(
      'gracefully recovers with empty list when both Backend and KOPIS completely fail',
      () async {
        when(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
            venue: anyNamed('venue'),
          ),
        ).thenThrow(Exception('Backend network down'));

        when(
          mockKopis.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
            shprfnmfct: anyNamed('shprfnmfct'),
          ),
        ).thenThrow(Exception('KOPIS API timeout'));

        final results = await repo.getUpcomingPerformances(forceRefresh: true);
        expect(results, isEmpty);
      },
    );

    test(
      'booking links are merged with official venue links first and no duplicates',
      () async {
        final p1 = Performance(
          id: 'PF1',
          title: '울산 오페라 축제 [울산]',
          startDate: '2026.11.01',
          endDate: '2026.11.01',
          venue: '울산문화예술회관',
          posterUrl: 'http://kopis.or.kr/1.jpg',
          genre: '클래식',
          state: '공연예정',
          district: '남구',
        );

        final p2 = Performance(
          id: 'CRAWLED1',
          title: '울산 오페라 축제',
          startDate: '2026.11.01',
          endDate: '2026.11.01',
          venue: '울산문화예술회관 (대공연장)',
          posterUrl: '',
          genre: '',
          state: '공연예정',
          district: '남구',
        );

        when(
          mockService.getPerformances(
            stdate: anyNamed('stdate'),
            eddate: anyNamed('eddate'),
          ),
        ).thenAnswer((_) async => [p1, p2]);

        final results = await repo.getUpcomingPerformances(forceRefresh: true);
        expect(results.length, 1);
        final merged = results.first;
        expect(merged.id, 'PF1');
        expect(merged.title, '울산 오페라 축제 [울산]');
        expect(merged.venue, '울산문화예술회관 (대공연장)');
      },
    );

    test('PerformanceDetail.fromJson prevents false free price fallback', () {
      final nullPriceDetail = PerformanceDetail.fromJson({
        'id': 'PF99',
        'title': '임윤찬 리사이틀',
        'price': null,
      });
      expect(nullPriceDetail.price, '공연장/기획사 문의');

      final nonePriceDetail = PerformanceDetail.fromJson({
        'id': 'PF99',
        'title': '임윤찬 리사이틀',
        'price': 'None',
      });
      expect(nonePriceDetail.price, '공연장/기획사 문의');

      final freeDetail = PerformanceDetail.fromJson({
        'id': 'PF99',
        'title': '울산시민 무료음악회',
        'price': '전석 무료',
      });
      expect(freeDetail.price, '전석 무료');

      final paidDetail = PerformanceDetail.fromJson({
        'id': 'PF99',
        'title': '임윤찬 리사이틀',
        'price': 'R석 150,000원',
      });
      expect(paidDetail.price, 'R석 150,000원');
    });

    test(
      'getPerformanceDetail enriches missing price and booking links for KOPIS ID',
      () async {
        final backendDoc = PerformanceDetail(
          id: 'PF299102',
          title: '임윤찬 피아노 리사이틀 [울산]',
          startDate: '2026.10.06',
          endDate: '2026.10.06',
          venue: 'HD아트센터(구 현대예술관)',
          cast: '임윤찬',
          runtime: '100분',
          timeGuidance: '19:30',
          ageLimit: '만 7세 이상',
          price: '공연장/기획사 문의', // missing in backend
          posterUrl: '',
          genre: '클래식',
          state: '공연예정',
          district: '동구',
          bookingLinks: [], // missing in backend
          detailImages: [],
        );

        final kopisDoc = PerformanceDetail(
          id: 'PF299102',
          title: '임윤찬 피아노 리사이틀 [울산]',
          startDate: '2026.10.06',
          endDate: '2026.10.06',
          venue: 'HD아트센터(구 현대예술관)',
          cast: '임윤찬',
          runtime: '100분',
          timeGuidance: '19:30',
          ageLimit: '만 7세 이상',
          price: 'R석 150,000원, S석 135,000원',
          posterUrl: 'http://kopis.or.kr/poster.jpg',
          genre: '클래식',
          state: '공연예정',
          district: '동구',
          bookingLinks: [
            BookingLink(name: '현대예술관', url: 'https://www.hd-artscenter.co.kr'),
          ],
          detailImages: [],
        );

        when(
          mockService.getPerformanceDetail('PF299102'),
        ).thenAnswer((_) async => backendDoc);
        when(
          mockKopis.getPerformanceDetail('PF299102'),
        ).thenAnswer((_) async => kopisDoc);

        final enriched = await repo.getPerformanceDetail('PF299102');
        expect(enriched.price, 'R석 150,000원, S석 135,000원');
        expect(enriched.bookingLinks.length, 1);
        expect(enriched.bookingLinks.first.name, '현대예술관');
      },
    );

    test(
      'getPerformanceDetail always prioritizes Junggu official booking link as primary link',
      () async {
        final jungguDoc = PerformanceDetail(
          id: 'PF_JUNGGU_01',
          title: '중구 클래식 연주회',
          startDate: '2026.10.01',
          endDate: '2026.10.01',
          venue: '중구문화의전당 함월홀',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '전체 관람가',
          price: '전석 20,000원',
          posterUrl: '',
          genre: '클래식',
          state: '공연예정',
          district: '중구',
          bookingLinks: [
            BookingLink(
              name: '인터파크 티켓 검색',
              url: 'https://tickets.interpark.com/search?keyword=test',
            ),
          ],
          detailImages: [],
        );

        when(
          mockService.getPerformanceDetail('PF_JUNGGU_01'),
        ).thenAnswer((_) async => jungguDoc);

        final result = await repo.getPerformanceDetail('PF_JUNGGU_01');
        expect(result.bookingLinks.first.name, '중구문화의전당 공식 예매');
        expect(
          result.bookingLinks.first.url,
          'https://artscenter.junggu.ulsan.kr/01_Menu/01.do',
        );
        expect(result.bookingLinks.length, 2);
        expect(result.bookingLinks[1].name, '인터파크 티켓 검색');
      },
    );

    test(
      'Joint Recital (조인트 리사이틀) with paid price but no online buy button is NOT marked as sold out',
      () async {
        final jointRecital = PerformanceDetail(
          id: 'PF_JOINT_RECITAL',
          title: '조인트 리사이틀',
          startDate: '2026.10.15',
          endDate: '2026.10.15',
          venue: '중구문화의전당 함월홀',
          cast: '피아노 연주자',
          runtime: '90분',
          timeGuidance: '19:30',
          ageLimit: '초등학생 이상',
          price: '일반 10,000원',
          posterUrl: '',
          genre: '클래식',
          state: '공연중',
          district: '중구',
          bookingLinks: [
            BookingLink(
              name: '중구문화의전당 공식 안내',
              url: 'https://artscenter.junggu.ulsan.kr/01_Menu/01.do',
            ),
          ],
          detailImages: [],
        );

        when(
          mockService.getPerformanceDetail('PF_JOINT_RECITAL'),
        ).thenAnswer((_) async => jointRecital);

        final result = await repo.getPerformanceDetail('PF_JOINT_RECITAL');
        expect(result.isSoldOut, isFalse);
        expect(result.state, '공연중');
        expect(result.bookingLinks.first.name, '중구문화의전당 공식 안내');
      },
    );

    test(
      'Performance with Naver Booking link prioritizes direct reservation over general info',
      () async {
        final naverDoc = PerformanceDetail(
          id: 'PF_BEAUTY_BEAST',
          title: '가족뮤지컬 미녀와야수 [울산]',
          startDate: '2026.09.20',
          endDate: '2026.09.20',
          venue: '중구문화의전당 함월홀',
          cast: '',
          runtime: '60분',
          timeGuidance: '11:00, 14:00',
          ageLimit: '전체 관람가',
          price: '사전예약 9,900원',
          posterUrl: '',
          genre: '뮤지컬',
          state: '공연예정',
          district: '중구',
          bookingLinks: [
            BookingLink(
              name: '네이버N예약',
              url: 'https://booking.naver.com/booking/12/bizes/1698367',
            ),
          ],
          detailImages: [],
        );

        when(
          mockService.getPerformanceDetail('PF_BEAUTY_BEAST'),
        ).thenAnswer((_) async => naverDoc);

        final result = await repo.getPerformanceDetail('PF_BEAUTY_BEAST');
        expect(result.isSoldOut, isFalse);
        expect(result.bookingLinks.first.name, '네이버N예약');
        expect(
          result.bookingLinks.first.url,
          'https://booking.naver.com/booking/12/bizes/1698367',
        );
        expect(result.bookingLinks[1].name, '중구문화의전당 공식 예매');
      },
    );

    test(
      'PerformanceRepository strictly deduplicates duplicate URLs and sets official info name for free shows',
      () async {
        final doc = PerformanceDetail(
          id: 'PF_DUPLICATE_TEST',
          title: '무료 야외 영화 콘서트',
          startDate: '2026.09.25',
          endDate: '2026.09.25',
          venue: '중구문화의전당 달빛마루',
          cast: '',
          runtime: '',
          timeGuidance: '',
          ageLimit: '전체 관람가',
          price: '전석 무료',
          posterUrl: '',
          genre: '영화',
          state: '공연예정',
          district: '중구',
          bookingLinks: [
            BookingLink(name: '중구 홈', url: 'https://artscenter.junggu.ulsan.kr'),
            BookingLink(name: '중구 홈 중복', url: 'https://artscenter.junggu.ulsan.kr/01_Menu/01.do'),
            BookingLink(name: '인터파크 1', url: 'https://tickets.interpark.com/search?keyword=movie'),
            BookingLink(name: '인터파크 1 중복', url: 'https://tickets.interpark.com/search?keyword=movie'),
          ],
          detailImages: [],
        );

        when(
          mockService.getPerformanceDetail('PF_DUPLICATE_TEST'),
        ).thenAnswer((_) async => doc);

        final result = await repo.getPerformanceDetail('PF_DUPLICATE_TEST');
        expect(result.bookingLinks.first.name, '중구문화의전당 공식 안내');
        expect(result.bookingLinks.first.url, 'https://artscenter.junggu.ulsan.kr/01_Menu/01.do');
        // Total links should be 2: Junggu official link + 1 deduplicated Interpark link
        expect(result.bookingLinks.length, 2);
        expect(result.bookingLinks[1].url, 'https://tickets.interpark.com/search?keyword=movie');
      },
    );
  });

  group('Robustness: SearchViewModel Date Calculation', () {
    test('calculateEndDate returns end of year or next February', () {
      final vm = SearchViewModel();
      final sepDate = DateTime(2026, 9, 2);
      final endOfSep = vm.calculateEndDate(sepDate);
      expect(endOfSep.year, 2026);
      expect(endOfSep.month, 12);
      expect(endOfSep.day, 31);

      final novDate = DateTime(2026, 11, 15);
      final endOfNov = vm.calculateEndDate(novDate);
      expect(endOfNov.year, 2027);
      expect(endOfNov.month, 2);
      expect(endOfNov.day, 28);
    });
  });
}
