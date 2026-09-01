import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:u_art/data/services/uart_api_service.dart';
import 'uart_api_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('UartApiService', () {
    late UartApiService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = UartApiService('http://test', client: mockClient);
    });

    test('getPerformances returns list of Performance on success', () async {
      final jsonResponse = [
        {
          "id": "PF123",
          "title": "Test Title",
          "startDate": "2023.01.01",
          "endDate": "2023.12.31",
          "venue": "Test Venue",
          "posterUrl": "http://test.com/poster.jpg",
          "genre": "Musical",
          "state": "Playing",
        },
      ];

      when(mockClient.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response.bytes(utf8.encode(json.encode(jsonResponse)), 200),
      );

      final result = await service.getPerformances(
        stdate: '20230101',
        eddate: '20231231',
        venue: 'test_venue',
        genre: 'Musical',
      );

      expect(result.length, 1);
      expect(result.first.id, 'PF123');
      expect(result.first.title, 'Test Title');
    });

    test('getPerformances throws on error', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Error', 404));

      expect(
        () => service.getPerformances(stdate: 'a', eddate: 'b'),
        throwsException,
      );
    });

    test('getPerformanceDetail returns PerformanceDetail on success', () async {
      final jsonResponse = {
        "id": "PF123",
        "title": "Test Title",
        "startDate": "2023.01.01",
        "endDate": "2023.12.31",
        "venue": "Test Venue",
        "cast": "Test Cast",
        "runtime": "120m",
        "timeGuidance": "금요일(19:30)",
        "ageLimit": "All",
        "price": "10000",
        "posterUrl": "http://test.com/poster.jpg",
        "genre": "Musical",
        "state": "Playing",
        "bookingLinks": [
          {"name": "예매처", "url": "http://test.com/book"},
        ],
        "detailImages": ["http://test.com/detail.jpg"],
      };

      when(mockClient.get(any, headers: anyNamed('headers'))).thenAnswer(
        (_) async =>
            http.Response.bytes(utf8.encode(json.encode(jsonResponse)), 200),
      );

      final result = await service.getPerformanceDetail('PF123');

      expect(result.id, 'PF123');
      expect(result.title, 'Test Title');
      expect(result.cast, 'Test Cast');
      expect(result.timeGuidance, '금요일(19:30)');
      expect(result.bookingLinks.length, 1);
      expect(result.bookingLinks.first.name, '예매처');
      expect(result.detailImages.length, 1);
    });

    test('getPerformanceDetail throws on error', () async {
      when(
        mockClient.get(any, headers: anyNamed('headers')),
      ).thenAnswer((_) async => http.Response('Error', 404));

      expect(() => service.getPerformanceDetail('PF123'), throwsException);
    });
  });
}
