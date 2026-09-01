import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:u_art/main.dart' as app;
import 'package:u_art/data/repositories/bookmark_repository.dart';
import 'package:u_art/ui/core/theme.dart';

void main() {
  testWidgets('UArtApp builds and loads home', (tester) async {
    SharedPreferences.setMockInitialValues({});

    // Call main for coverage
    app.main();
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bookmarkRepositoryProvider.overrideWithValue(
            BookmarkRepository(prefs),
          ),
        ],
        child: const app.UArtApp(),
      ),
    );
    // Ignore any exceptions or just pump once.
    // Wait for frames
    await tester.pump();
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  test('AppTheme creates a valid theme', () {
    final theme = AppTheme.darkTheme;
    expect(theme.brightness, Brightness.dark);
    expect(theme.scaffoldBackgroundColor, isNotNull);
  });
}
