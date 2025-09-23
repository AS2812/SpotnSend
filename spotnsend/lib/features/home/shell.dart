import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/widgets/app_badge.dart';
import '../../shared/widgets/toasts.dart';
import '../auth/providers/auth_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

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
              showErrorToast(context, 'Reporting is locked until verification is complete.'.tr());
              return;
            }
            navigationShell.goBranch(index);
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map_rounded),
              label: 'Map'.tr(),
            ),
            NavigationDestination(
              icon: authState.isPendingVerification
                  ? const _LockedReportIcon()
                  : const Icon(Icons.report_gmailerrorred_outlined),
              selectedIcon: const Icon(Icons.report_gmailerrorred_rounded),
              label: 'Report'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.notifications_outlined),
              selectedIcon: const Icon(Icons.notifications_rounded),
              label: 'Alerts'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: 'Account'.tr(),
            ),
            NavigationDestination(
              icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings),
              label: 'Settings'.tr(),
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
            label: 'Pending'.tr(),
            variant: BadgeVariant.pending,
          ),
        ),
      ],
    );
  }
}
