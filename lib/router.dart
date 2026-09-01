import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:u_art/ui/core/scaffold_with_nav_bar.dart';
import 'package:u_art/ui/features/home/views/home_screen.dart';
import 'package:u_art/ui/features/search/views/search_screen.dart';
import 'package:u_art/ui/features/bookmark/views/bookmark_screen.dart';
import 'package:u_art/ui/features/detail/views/detail_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return ScaffoldWithNavBar(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
              routes: [
                GoRoute(
                  path: 'detail/:id',
                  name: 'home_detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => DetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
              routes: [
                GoRoute(
                  path: 'detail/:id',
                  name: 'search_detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => DetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/bookmark',
              builder: (context, state) => const BookmarkScreen(),
              routes: [
                GoRoute(
                  path: 'detail/:id',
                  name: 'bookmark_detail',
                  parentNavigatorKey: rootNavigatorKey,
                  builder: (context, state) => DetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ],
);
