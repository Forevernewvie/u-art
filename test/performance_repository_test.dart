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
        id: '1', title: 'A', startDate: '2023.01.02', endDate: '2023.01.02',
        venue: 'V', posterUrl: '', genre: 'G', state: 'S'
      , district: '전체');
      final p2 = Performance(
        id: '2', title: 'B', startDate: '2023.01.01', endDate: '2023.01.01',
        venue: 'V', posterUrl: '', genre: 'G', state: 'S'
      , district: '전체');

      when(mockService.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
        venue: '울산문화예술회관',
      )).thenAnswer((_) async => [p1]);

      when(mockService.getPerformances(
        stdate: anyNamed('stdate'),
        eddate: anyNamed('eddate'),
        venue: '중구문화의전당',
      )).thenAnswer((_) async => [p2]);

      final result = await repository.getUpcomingPerformances();
      
      expect(result.length, 2);
      expect(result.first.id, '2');
      expect(result.last.id, '1');
    });

    test('getPerformanceDetail calls service', () async {
      final detail = PerformanceDetail(
        id: '1', title: 'A', startDate: 'S', endDate: 'E', venue: 'V', cast: 'C',
        runtime: 'R', timeGuidance: 'T', ageLimit: 'A', price: 'P', posterUrl: 'P', genre: 'G', state: 'S', district: '전체',
        bookingLinks: [], detailImages: []
      );
      
      when(mockService.getPerformanceDetail('1')).thenAnswer((_) async => detail);

      final result = await repository.getPerformanceDetail('1');
      expect(result, detail);
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
