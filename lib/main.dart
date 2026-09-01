import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:flutter_web_plugins/url_strategy.dart'; // Removed for testability
import 'package:shared_preferences/shared_preferences.dart';
import 'package:u_art/data/repositories/bookmark_repository.dart';
import 'router.dart';
import 'ui/core/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  // usePathUrlStrategy();
  runApp(
    ProviderScope(
      overrides: [
        bookmarkRepositoryProvider.overrideWithValue(BookmarkRepository(prefs)),
      ],
      child: const UArtApp(),
    ),
  );
}

class UArtApp extends StatelessWidget {
  const UArtApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'U-Art',
      theme: AppTheme.darkTheme,
      routerConfig: appRouter,
    );
  }
}
