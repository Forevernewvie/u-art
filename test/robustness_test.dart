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
