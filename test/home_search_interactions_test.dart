import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:u_art/ui/features/home/views/home_screen.dart';
import 'package:u_art/ui/features/search/views/search_screen.dart';
import 'package:u_art/data/models/performance.dart';
import 'package:u_art/ui/features/home/view_models/home_view_model.dart';
import 'package:u_art/ui/features/search/view_models/search_view_model.dart';
import 'package:go_router/go_router.dart';
import 'package:carousel_slider/carousel_slider.dart';

void main() {
  testWidgets('HomeScreen interactions and error states', (tester) async {
    final performance = Performance(
      id: '1', title: 'T', startDate: 'S', endDate: 'E', venue: 'V', posterUrl: 'invalid_url', genre: 'G', state: 'S'
    , district: '전체');

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/search',
          builder: (context, state) => const Text('Search Page'),
        ),
        GoRoute(
          path: '/detail/:id',
          name: 'home_detail',
          builder: (context, state) => Text('Detail ${state.pathParameters['id']}'),
        ),
      ]
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeViewModelProvider.overrideWith(() => MockHomeViewModel([performance])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    
    // tap search icon in app bar
    await tester.tap(find.byIcon(Icons.search));
    await tester.pumpAndSettle();
    expect(find.text('Search Page'), findsOneWidget);
    
    // Go back to home
    router.go('/');
    await tester.pumpAndSettle();

    // tap carousel item
    final carouselGesture = find.descendant(
      of: find.byType(CarouselSlider),
      matching: find.byType(GestureDetector),
    ).first;
    tester.widget<GestureDetector>(carouselGesture).onTap!();
    await tester.pumpAndSettle();
    
    // Should navigate to detail
    expect(find.text('Detail 1'), findsOneWidget);
    
    // Go back
    router.go('/');
    await tester.pumpAndSettle();
    
    // tap list item
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
    await tester.pumpAndSettle();
    
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Detail 1'), findsOneWidget);
  });
  
  testWidgets('HomeScreen loading and error', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeViewModelProvider.overrideWith(() => MockHomeViewModelError()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    await tester.pump();
    // loading
    
    await tester.pumpAndSettle();
    expect(find.textContaining('오류가 발생했습니다.'), findsOneWidget);
  });
  
  testWidgets('SearchScreen interactions and error states', (tester) async {
    final performance = Performance(
      id: '1', title: 'T', startDate: 'S', endDate: 'E', venue: 'V', posterUrl: 'invalid_url', genre: 'G', state: 'S'
    , district: '전체');

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const SearchScreen(),
        ),
        GoRoute(
          path: '/detail/:id',
          name: 'search_detail',
          builder: (context, state) => Text('Detail ${state.pathParameters['id']}'),
        ),
      ]
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchViewModelProvider.overrideWith(() => MockSearchViewModel([performance])),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();
    
    // tap list item
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Detail 1'), findsOneWidget);
  });
  
  testWidgets('SearchScreen error state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchViewModelProvider.overrideWith(() => MockSearchViewModelError()),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.textContaining('네트워크 오류가 발생했습니다.'), findsOneWidget);
    
    // Tap retry button
    await tester.tap(find.text('재시도'));
    await tester.pumpAndSettle();
  });
  
  testWidgets('SearchScreen refresh indicator', (tester) async {
    final performance = Performance(
      id: '1', title: 'T', startDate: 'S', endDate: 'E', venue: 'V', posterUrl: 'invalid_url', genre: 'G', state: 'S'
    , district: '전체');
    
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          searchViewModelProvider.overrideWith(() => MockSearchViewModel([performance])),
        ],
        child: const MaterialApp(home: SearchScreen()),
      ),
    );

    await tester.pumpAndSettle();
    
    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();
  });
}

class MockHomeViewModel extends HomeViewModel {
  final List<Performance> _data;
  MockHomeViewModel(this._data);
  @override
  Future<List<Performance>> build() async => _data;
}

class MockHomeViewModelError extends HomeViewModel {
  @override
  Future<List<Performance>> build() async => throw Exception('error');
}

class MockSearchViewModel extends SearchViewModel {
  final List<Performance> _data;
  MockSearchViewModel(this._data);
  @override
  Future<List<Performance>> build() async => _data;
  @override
  Future<void> search(String query, String genre) async {
    state = AsyncData(_data);
  }
  @override
  Future<void> refresh() async {
    state = AsyncData(_data);
  }
}

class MockSearchViewModelError extends SearchViewModel {
  @override
  Future<List<Performance>> build() async => throw Exception('error');
  @override
  Future<void> refresh() async {}
}
