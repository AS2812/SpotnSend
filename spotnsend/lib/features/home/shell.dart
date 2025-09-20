import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/app_badge.dart';
import '../../widgets/toasts.dart';
import '../auth/providers/auth_providers.dart';

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: SafeArea(
        child: NavigationBar(
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: (index) {
            if (index == 1 && authState.isPendingVerification) {
              showErrorToast(context, 'Reporting is locked until verification is complete.');
              return;
            }
            navigationShell.goBranch(index);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_rounded),
              label: 'Map',
            ),
            NavigationDestination(
              icon: authState.isPendingVerification
                  ? const _LockedReportIcon()
                  : const Icon(Icons.report_gmailerrorred_outlined),
              selectedIcon: const Icon(Icons.report_gmailerrorred_rounded),
              label: 'Report',
            ),
            const NavigationDestination(
              icon: Icon(Icons.notifications_outlined),
              selectedIcon: Icon(Icons.notifications_rounded),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Account',
            ),
            const NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedReportIcon extends StatelessWidget {
  const _LockedReportIcon();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Icon(Icons.report_gmailerrorred_outlined),
        Positioned(
          right: -6,
          top: -6,
          child: AppBadge(
            label: 'Pending',
            variant: BadgeVariant.pending,
          ),
        ),
      ],
    );
  }
}

