import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/ui/features/detail/views/detail_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  });

  group('DetailScreen Sold Out UI Tests', () {
    testWidgets('DetailScreen displays disabled button for sold out performance', (
      tester,
    ) async {
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
        bookingLinks: [BookingLink(name: '인터파크', url: 'https://interpark.com')],
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
          child: const MaterialApp(
            home: DetailScreen(id: 'detail_soldout'),
          ),
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
    });
  });
}
