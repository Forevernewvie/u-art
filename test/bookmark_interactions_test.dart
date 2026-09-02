import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:u_art/ui/features/bookmark/views/bookmark_screen.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_list_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart';
import 'package:u_art/ui/common_widgets/sold_out_stamp.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  testWidgets('BookmarkScreen interactions', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final detail = PerformanceDetail(
      id: '1',
      title: 'T',
      startDate: 'S',
      endDate: 'E',
      venue: 'V',
      cast: 'C',
      runtime: 'R',
      timeGuidance: 'TG',
      ageLimit: 'A',
      price: 'P',
      posterUrl: 'invalid_url',
      genre: 'G',
      state: 'S',
      district: '전체',
      bookingLinks: [],
      detailImages: [],
    );

    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const BookmarkScreen()),
        GoRoute(
          path: '/detail/:id',
          name: 'bookmark_detail',
          builder: (context, state) =>
              Text('Detail ${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarkListViewModelProvider.overrideWith(
            () => MockBookmarkListViewModel([detail]),
          ),
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier(['1'])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    // tap item
    await tester.tap(find.text('T'));
    await tester.pumpAndSettle();
    expect(find.text('Detail 1'), findsOneWidget);
  });

  testWidgets('BookmarkScreen error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarkListViewModelProvider.overrideWith(
            () => MockBookmarkListViewModelError(),
          ),
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier([])),
        ],
        child: const MaterialApp(home: BookmarkScreen()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('찜 목록을 불러오는 중 오류가 발생했습니다.'), findsOneWidget);

    // Tap refresh
    await tester.tap(find.text('새로고침'));
    await tester.pumpAndSettle();
  });

  testWidgets('BookmarkScreen renders SoldOutStamp for sold out item', (tester) async {
    final detail = PerformanceDetail(
      id: 'SOLD_BM',
      title: '매진 북마크',
      startDate: '2026.10.10',
      endDate: '2026.10.10',
      venue: '문예회관',
      cast: '배우',
      runtime: '60분',
      timeGuidance: '19:00',
      ageLimit: '전체',
      price: '무료',
      posterUrl: 'invalid_url',
      genre: '연극',
      state: '매진',
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
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier(['SOLD_BM'])),
        ],
        child: const MaterialApp(home: BookmarkScreen()),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.byType(SoldOutStamp), findsOneWidget);

    final bmImg = tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage).first);
    final err = bmImg.errorWidget!(tester.element(find.byType(BookmarkScreen)), 'url', 'err');
    expect(err, isA<Icon>());
  });
}

class MockBookmarkListViewModel extends BookmarkListViewModel {
  final List<PerformanceDetail> _data;
  MockBookmarkListViewModel(this._data);
  @override
  Future<List<PerformanceDetail>> build() async => _data;
}

class MockBookmarkListViewModelError extends BookmarkListViewModel {
  @override
  Future<List<PerformanceDetail>> build() async => throw Exception('error');
}

class MockBookmarkNotifier extends BookmarkNotifier {
  final List<String> _data;
  MockBookmarkNotifier(this._data);
  @override
  List<String> build() => _data;
  @override
  Future<void> toggleBookmark(String id) async {
    if (state.contains(id)) {
      state = [...state]..remove(id);
    } else {
      state = [...state, id];
    }
  }
}
