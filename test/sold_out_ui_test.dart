import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/ui/features/detail/views/detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:u_art/ui/common_widgets/sold_out_stamp.dart';
import 'package:u_art/ui/features/detail/view_models/detail_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart';

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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Performance Sold Out Model Tests', () {
    test('isSoldOut returns true for 매진 and 공연완료', () {
      final soldOutPerf = Performance(
        id: '1',
        title: '매진 공연',
        startDate: '2026.09.01',
        endDate: '2026.09.01',
        venue: '울산문화예술회관',
        posterUrl: '',
        genre: '뮤지컬',
        state: '매진',
        district: '남구',
      );
      expect(soldOutPerf.isSoldOut, isTrue);

      final completedPerf = Performance(
        id: '2',
        title: '종료된 공연',
        startDate: '2026.08.01',
        endDate: '2026.08.01',
        venue: '중구문화의전당',
        posterUrl: '',
        genre: '클래식',
        state: '공연완료',
        district: '중구',
      );
      expect(completedPerf.isSoldOut, isTrue);

      final activePerf = Performance(
        id: '3',
        title: '진행중 공연',
        startDate: '2026.09.15',
        endDate: '2026.09.15',
        venue: '중구문화의전당',
        posterUrl: '',
        genre: '연극',
        state: '공연중',
        district: '중구',
      );
      expect(activePerf.isSoldOut, isFalse);
    });

    test('fromJson correctly parses isSoldOut field and states', () {
      final json1 = {
        'id': 'j1',
        'title': '매진 공연',
        'isSoldOut': true,
        'state': '공연중',
      };
      final perf1 = Performance.fromJson(json1);
      expect(perf1.isSoldOut, isTrue);

      final json2 = {'id': 'j2', 'title': '마감 공연', 'state': '예매마감'};
      final perf2 = Performance.fromJson(json2);
      expect(perf2.isSoldOut, isTrue);

      final detailJson = {
        'id': 'd1',
        'title': '상세 매진 공연',
        'isSoldOut': true,
        'state': '공연중',
      };
      final detail1 = PerformanceDetail.fromJson(detailJson);
      expect(detail1.isSoldOut, isTrue);
    });
  });

  group('DetailScreen Sold Out UI Tests', () {
    testWidgets(
      'DetailScreen displays disabled button and SoldOutStamp for sold out performance',
      (tester) async {
        final soldOutDetail = PerformanceDetail(
          id: 'detail_soldout',
          title: '매진된 인기 콘서트',
          startDate: '2026.09.10',
          endDate: '2026.09.10',
          venue: '울산문화예술회관 대공연장',
          cast: '유명 가수',
          runtime: '120분',
          timeGuidance: '오후 7시',
          ageLimit: '만 7세 이상',
          price: '전석 50,000원',
          posterUrl: '',
          genre: '콘서트',
          state: '매진',
          district: '남구',
          bookingLinks: [
            BookingLink(name: '인터파크', url: 'https://interpark.com'),
          ],
          detailImages: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              detailViewModelProvider(
                'detail_soldout',
              ).overrideWith(() => MockDetailViewModel(soldOutDetail)),
              bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
            ],
            child: const MaterialApp(home: DetailScreen(id: 'detail_soldout')),
          ),
        );

        await tester.pumpAndSettle();

        // Check for Sold Out label on booking button
        expect(find.text('매진 (Sold Out)'), findsOneWidget);

        // Verify ElevatedButton is disabled (onPressed is null)
        final elevatedButton = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(elevatedButton.onPressed, isNull);

        // Verify SoldOutStamp is rendered on poster
        expect(find.text('SOLD OUT'), findsOneWidget);
      },
    );

    testWidgets(
      'DetailScreen with no booking link displays venue inquiry button and tapping it opens dialog',
      (tester) async {
        final inquiryDetail = PerformanceDetail(
          id: 'detail_inquiry',
          title: '울산 시민 무료 합창제',
          startDate: '2026.09.10',
          endDate: '2026.09.10',
          venue: '울산문화예술회관 야외공연장',
          cast: '울산시립합창단',
          runtime: '90분',
          timeGuidance: '오후 7시 30분',
          ageLimit: '전체 관람가',
          price: '전석 무료',
          posterUrl: '',
          genre: '음악',
          state: '공연예정',
          district: '남구',
          bookingLinks: [],
          detailImages: [],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              detailViewModelProvider(
                'detail_inquiry',
              ).overrideWith(() => MockDetailViewModel(inquiryDetail)),
              bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
            ],
            child: const MaterialApp(home: DetailScreen(id: 'detail_inquiry')),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('현장 발권 / 공연장 문의 요망'), findsOneWidget);
        await tester.tap(find.text('현장 발권 / 공연장 문의 요망'));
        await tester.pumpAndSettle();

        expect(find.text('예매 안내'), findsOneWidget);
        expect(
          find.textContaining('온라인 예매처가 별도로 등록되지 않은 공연입니다'),
          findsOneWidget,
        );

        await tester.tap(find.text('확인'));
        await tester.pumpAndSettle();
        expect(find.text('예매 안내'), findsNothing);
      },
    );
  });

  group('SoldOutStamp Widget Tests', () {
    testWidgets('renders all stamp sizes correctly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SoldOutStamp(size: StampSize.compact, showOverlay: false),
                SoldOutStamp(size: StampSize.regular, showOverlay: false),
                SoldOutStamp(size: StampSize.large, showOverlay: false),
              ],
            ),
          ),
        ),
      );

      expect(find.text('매진'), findsNWidgets(3));
      expect(find.text('SOLD OUT'), findsNWidgets(3));
    });
  });
}
