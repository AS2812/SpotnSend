import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:spotnsend/features/auth/login_page.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/auth/signup_step1_page.dart';
import 'package:spotnsend/features/auth/signup_step2_id_page.dart';
import 'package:spotnsend/features/auth/signup_step3_selfie_page.dart';
import 'package:spotnsend/features/home/account/account_page.dart';
import 'package:spotnsend/features/home/map/map_page.dart';
import 'package:spotnsend/features/home/map/map_list_view.dart';
import 'package:spotnsend/features/home/notifications/notifications_page.dart';
import 'package:spotnsend/features/home/report/report_page.dart';
import 'package:spotnsend/features/home/settings/settings_page.dart';
import 'package:spotnsend/features/home/settings/providers/settings_providers.dart';
import 'package:spotnsend/features/home/shell.dart';
import 'package:spotnsend/features/legal/terms_conditions_page.dart';
import 'package:spotnsend/features/legal/user_guide_page.dart';
import 'package:spotnsend/features/home/account/change_password_page.dart';
import 'package:spotnsend/features/support/report_bug_page.dart';
import 'routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _mapNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'map');
final _reportNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'report');
final _alertsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'alerts');
final _accountNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'account');
final _settingsNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: RoutePaths.login,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        redirect: (_, __) => RoutePaths.login,
      ),
      GoRoute(
        path: RoutePaths.login,
        name: AppRoute.login.name,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: RoutePaths.signupStep1,
        name: AppRoute.signupStep1.name,
        builder: (context, state) => const SignupStep1Page(),
      ),
      GoRoute(
        path: RoutePaths.signupStep2,
        name: AppRoute.signupStep2.name,
        builder: (context, state) => const SignupStep2IdPage(),
      ),
      GoRoute(
        path: RoutePaths.signupStep3,
        name: AppRoute.signupStep3.name,
        builder: (context, state) => const SignupStep3SelfiePage(),
      ),
      GoRoute(
        path: RoutePaths.termsConditions,
        name: AppRoute.termsConditions.name,
        builder: (context, state) => const TermsConditionsPage(),
      ),
      GoRoute(
        path: RoutePaths.userGuide,
        name: AppRoute.userGuide.name,
        builder: (context, state) => const UserGuidePage(),
      ),
      GoRoute(
        path: RoutePaths.changePassword,
        name: AppRoute.changePassword.name,
        builder: (context, state) => const ChangePasswordPage(),
      ),
      GoRoute(
        path: RoutePaths.reportBug,
        name: AppRoute.reportBug.name,
        builder: (context, state) => const ReportBugPage(),
      ),
      GoRoute(
        path: RoutePaths.home,
        redirect: (_, __) => RoutePaths.homeMap,
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _mapNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.homeMap,
                name: AppRoute.homeMap.name,
                builder: (context, state) => const MapPage(),
                routes: [
                  GoRoute(
                    path: 'list',
                    name: 'map_list_view',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) => const MapListView(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _reportNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.homeReport,
                name: AppRoute.homeReport.name,
                builder: (context, state) => const ReportPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _alertsNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.homeNotifications,
                name: AppRoute.homeNotifications.name,
                builder: (context, state) => const NotificationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _accountNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.homeAccount,
                name: AppRoute.homeAccount.name,
                builder: (context, state) => const AccountPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _settingsNavigatorKey,
            routes: [
              GoRoute(
                path: RoutePaths.homeSettings,
                name: AppRoute.homeSettings.name,
                builder: (context, state) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this.ref) {
    ref.listen<AuthState>(authControllerProvider, (_, __) => notifyListeners());
    ref.listen<SettingsState>(settingsControllerProvider, (previous, next) {
      if (previous?.locale != next.locale) {
        notifyListeners();
      }
    });
  }

  final Ref ref;

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = ref.read(authControllerProvider);
    final location = state.uri.path;
    final isAuthRoute = location == RoutePaths.login ||
        location == RoutePaths.signupStep1 ||
        location == RoutePaths.signupStep2 ||
        location == RoutePaths.signupStep3 ||
        location == '/';

    if (!authState.isAuthenticated) {
      if (isAuthRoute) {
        return null;
      }
      return RoutePaths.login;
    }

    if (location == '/' || location == RoutePaths.home) {
      return RoutePaths.homeMap;
    }

    if (authState.isAuthenticated && isAuthRoute) {
      return RoutePaths.homeMap;
    }

    if (authState.isPendingVerification && location == RoutePaths.homeReport) {
      return RoutePaths.homeMap;
    }

    return null;
  }
}
