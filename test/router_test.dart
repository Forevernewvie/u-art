import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:u_art/router.dart';
import 'package:u_art/ui/features/home/view_models/home_view_model.dart';
import 'package:u_art/ui/features/search/view_models/search_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_list_view_model.dart';
import 'package:u_art/ui/features/detail/view_models/detail_view_model.dart';
import 'package:u_art/ui/features/bookmark/view_models/bookmark_view_model.dart';
import 'package:u_art/data/models/performance.dart';

void main() {
  testWidgets('Router navigates correctly', (tester) async {
    final performance = Performance(
      id: '1',
      title: 'T',
      startDate: 'S',
      endDate: 'E',
      venue: 'V',
      posterUrl: '',
      genre: 'G',
      state: 'S',
      district: '전체',
    );
    final detail = PerformanceDetail(
      id: '1',
      title: 'T',
      startDate: '2023.01.01',
      endDate: '2023.12.31',
      venue: 'V',
      cast: 'C',
      runtime: '120m',
      timeGuidance: '19:30',
      ageLimit: '12+',
      price: '10000',
      posterUrl: '',
      genre: 'G',
      state: 'S',
      district: '전체',
      bookingLinks: [],
      detailImages: [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeViewModelProvider.overrideWith(
            () => MockHomeViewModel([performance]),
          ),
          searchViewModelProvider.overrideWith(
            () => MockSearchViewModel([performance]),
          ),
          bookmarkListViewModelProvider.overrideWith(
            () => MockBookmarkListViewModel([detail]),
          ),
          detailViewModelProvider(
            '1',
          ).overrideWith(() => MockDetailViewModel(detail)),
          bookmarkProvider.overrideWith(() => MockBookmarkNotifier(['1'])),
        ],
        child: MaterialApp.router(routerConfig: appRouter),
      ),
    );

    await tester.pumpAndSettle();

    // Tap on detail from home
    appRouter.goNamed('home_detail', pathParameters: {'id': '1'});
    await tester.pumpAndSettle();
    expect(find.text('T'), findsWidgets);

    appRouter.go('/search');
    await tester.pumpAndSettle();

    appRouter.goNamed('search_detail', pathParameters: {'id': '1'});
    await tester.pumpAndSettle();

    appRouter.go('/bookmark');
    await tester.pumpAndSettle();

    appRouter.goNamed('bookmark_detail', pathParameters: {'id': '1'});
    await tester.pumpAndSettle();
  });
}

class MockHomeViewModel extends HomeViewModel {
  final List<Performance> _data;
  MockHomeViewModel(this._data);
  @override
  Future<List<Performance>> build() async => _data;
}

class MockSearchViewModel extends SearchViewModel {
  final List<Performance> _data;
  MockSearchViewModel(this._data);
  @override
  Future<List<Performance>> build() async => _data;
}

class MockBookmarkListViewModel extends BookmarkListViewModel {
  final List<PerformanceDetail> _data;
  MockBookmarkListViewModel(this._data);
  @override
  Future<List<PerformanceDetail>> build() async => _data;
}

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
