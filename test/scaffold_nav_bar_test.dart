import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:u_art/ui/core/scaffold_with_nav_bar.dart';

void main() {
  testWidgets('ScaffoldWithNavBar navigation works', (tester) async {
    // Just mock StatefulNavigationShell
    // Actually simpler to just build GoRouter with it
    final router = GoRouter(
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              ScaffoldWithNavBar(navigationShell: navigationShell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/a', builder: (c, s) => const Text('Screen A')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/b', builder: (c, s) => const Text('Screen B')),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/c', builder: (c, s) => const Text('Screen C')),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    expect(find.text('Screen A'), findsOneWidget);

    await tester.tap(find.text('검색'));
    await tester.pumpAndSettle();
    expect(find.text('Screen B'), findsOneWidget);

    await tester.tap(find.text('찜'));
    await tester.pumpAndSettle();
    expect(find.text('Screen C'), findsOneWidget);

    await tester.tap(find.text('홈'));
    await tester.pumpAndSettle();
    expect(find.text('Screen A'), findsOneWidget);
  });
}
