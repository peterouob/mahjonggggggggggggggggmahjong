import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/pages/onboarding_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/room/pages/room_detail_page.dart';
import '../../shared/widgets/main_shell.dart';
import '../storage/session.dart';

abstract class AppRoutes {
  static const onboarding = '/onboarding';
  static const login = '/login';
  static const map = '/';
  static const roomBase = '/room';

  static String room(String id) => '/room/$id';
}

class AppRouter {
  AppRouter._();

  static final router = GoRouter(
    initialLocation: Session.instance.isLoggedIn ? AppRoutes.map : AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        pageBuilder: (ctx, state) => const NoTransitionPage(
          child: OnboardingPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (ctx, state) => const MaterialPage(
          child: LoginPage(),
        ),
      ),
      GoRoute(
        path: AppRoutes.map,
        pageBuilder: (ctx, state) => const NoTransitionPage(
          child: MainShell(),
        ),
      ),
      GoRoute(
        path: '/room/:id',
        pageBuilder: (ctx, state) => MaterialPage(
          child: RoomDetailPage(
            roomId: state.pathParameters['id']!,
          ),
        ),
      ),
    ],
  );

  static void go(BuildContext context, String location) {
    context.go(location);
  }

  static void push(BuildContext context, String location) {
    context.push(location);
  }
}
