import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/data/services/kopis_service.dart';
import 'package:xml/xml.dart';
import 'kopis_service_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  group('KopisService', () {
    late KopisService service;
    late MockClient mockClient;

    setUp(() {
      mockClient = MockClient();
      service = KopisService('test_api_key', client: mockClient);
    });

    test(
      'getPerformances returns list of Performance on success with all params',
      () async {
        final xmlResponse = '''
      <dbs>
        <db>
          <mt20id>PF123</mt20id>
          <prfnm>Test Title</prfnm>
          <prfpdfrom>2023.01.01</prfpdfrom>
          <prfpdto>2023.12.31</prfpdto>
          <fcltynm>Test Venue</fcltynm>
          <poster>http://test.com/poster.jpg</poster>
          <genrenm>Musical</genrenm>
          <prfstate>Playing</prfstate>
        </db>
      </dbs>
      ''';

        when(mockClient.get(any)).thenAnswer(
          (_) async => http.Response.bytes(utf8.encode(xmlResponse), 200),
        );

        final result = await service.getPerformances(
          stdate: '20230101',
          eddate: '20231231',
          shprfnmfct: 'test_venue',
          signgucode: '31',
          cpage: 1,
          rows: 10,
        );

        expect(result.length, 1);
        expect(result.first.id, 'PF123');
        expect(result.first.title, 'Test Title');
      },
    );

    test('getAllPerformancesByRegion paginates until complete', () async {
      final p1Xml = List.generate(
        100,
        (i) => '<db><mt20id>P$i</mt20id><prfnm>T$i</prfnm></db>',
      ).join('');
      final page1Xml = '<dbs>$p1Xml</dbs>';
      final page2Xml =
          '<dbs><db><mt20id>P101</mt20id><prfnm>T101</prfnm></db></dbs>';

      int callCount = 0;
      when(mockClient.get(any)).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) {
          return http.Response.bytes(utf8.encode(page1Xml), 200);
        } else {
          return http.Response.bytes(utf8.encode(page2Xml), 200);
        }
      });

      final result = await service.getAllPerformancesByRegion(
        stdate: '20260101',
        eddate: '20261231',
      );

      expect(result.length, 101);
      expect(callCount, 2);
    });

    test('getAllPerformancesByRegion stops if first page is empty', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response.bytes(utf8.encode('<dbs></dbs>'), 200),
      );

      final result = await service.getAllPerformancesByRegion(
        stdate: '20260101',
        eddate: '20261231',
      );

      expect(result, isEmpty);
    });

    test('getPerformances throws on error', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Error', 404));

      expect(
        () =>
            service.getPerformances(stdate: 'a', eddate: 'b', shprfnmfct: 'c'),
        throwsException,
      );
    });

    test('getPerformanceDetail returns PerformanceDetail on success', () async {
      final xmlResponse = '''
      <dbs>
        <db>
          <mt20id>PF123</mt20id>
          <prfnm>Test Title</prfnm>
          <prfpdfrom>2023.01.01</prfpdfrom>
          <prfpdto>2023.12.31</prfpdto>
          <fcltynm>Test Venue</fcltynm>
          <prfcast>Test Cast</prfcast>
          <prfruntime>120m</prfruntime>
          <dtguidance>금요일(19:30)</dtguidance>
          <prfage>All</prfage>
          <pcseguidance>10000</pcseguidance>
          <poster>http://test.com/poster.jpg</poster>
          <genrenm>Musical</genrenm>
          <prfstate>Playing</prfstate>
          <relates>
            <relate>
              <relatenm>예매처</relatenm>
              <relateurl>http://test.com/book</relateurl>
            </relate>
          </relates>
          <styurls>
            <styurl>http://test.com/detail.jpg</styurl>
          </styurls>
        </db>
      </dbs>
      ''';

      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response.bytes(utf8.encode(xmlResponse), 200),
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

    test('PerformanceDetail fallbacks based on venue', () {
      final doc1 = XmlDocument.parse(
        '<db><fcltynm>울산문화예술회관</fcltynm><prfnm>A</prfnm></db>',
      );
      final d1 = PerformanceDetail.fromXml(doc1.rootElement);
      expect(d1.bookingLinks.first.name, '울산문화예술회관 공식 예매');

      final doc2 = XmlDocument.parse(
        '<db><fcltynm>중구문화의전당</fcltynm><prfnm>B</prfnm></db>',
      );
      final d2 = PerformanceDetail.fromXml(doc2.rootElement);
      expect(d2.bookingLinks.first.name, '중구문화의전당 공식 예매');

      final doc3 = XmlDocument.parse(
        '<db><fcltynm>HD아트센터</fcltynm><prfnm>C</prfnm></db>',
      );
      final d3 = PerformanceDetail.fromXml(doc3.rootElement);
      expect(d3.bookingLinks.first.name, '인터파크 티켓 검색');
    });

    test('getPerformanceDetail throws on error', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('Error', 404));

      expect(() => service.getPerformanceDetail('PF123'), throwsException);
    });
  });
}
