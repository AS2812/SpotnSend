import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/notification_models.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/empty_state.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/features/home/notifications/providers/notification_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsControllerProvider);
    final notifier = ref.read(notificationsControllerProvider.notifier);
    final isLoading = async is AsyncLoading;
    final items = async.value ?? const <AppNotification>[];

    Future<void> markAllRead() async {
      if (items.isEmpty || isLoading) return;
      await notifier.markAll(seen: true);
      showSuccessToast(context, 'All notifications marked as read.'.tr());
    }

    Future<void> clearAll() async {
      if (items.isEmpty || isLoading) return;
      await notifier.deleteAll();
      showSuccessToast(context, 'Notifications cleared.'.tr());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'.tr()),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: isLoading
                ? null
                : () => ref
                    .read(notificationsControllerProvider.notifier)
                    .refresh(),
            tooltip: 'Refresh'.tr(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget content = async.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => _ErrorView(
                message: 'Failed to load notifications: $error',
                onRetry: () => notifier.refresh(),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: EmptyState(
                      icon: Icons.notifications_off_outlined,
                      title: 'No notifications yet'.tr(),
                      message: 'When alerts arrive, they will show up here.'.tr(),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemBuilder: (_, i) =>
                      _NotificationTile(notification: items[i]),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: items.length,
                );
              },
            );

            return RefreshIndicator(
              onRefresh: () => notifier.refresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: ConstrainedBox(
                  constraints:
                      BoxConstraints(minHeight: constraints.maxHeight),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _NotificationsActionBar(
                        canAct: items.isNotEmpty && !isLoading,
                        onMarkAllRead: markAllRead,
                        onClearAll: clearAll,
                      ),
                      const SizedBox(height: 16),
                      content,
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _NotificationsActionBar extends StatelessWidget {
  const _NotificationsActionBar({
    required this.canAct,
    required this.onMarkAllRead,
    required this.onClearAll,
  });

  final bool canAct;
  final Future<void> Function() onMarkAllRead;
  final Future<void> Function() onClearAll;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxButtonWidth = width > 420 ? 180.0 : double.infinity;
    final secondaryWidth = width > 420 ? 140.0 : double.infinity;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            SizedBox(
              width: maxButtonWidth,
              child: OutlinedButton(
                onPressed: canAct ? onMarkAllRead : null,
                child: Text('Mark all read'.tr()),
              ),
            ),
            SizedBox(
              width: secondaryWidth,
              child: OutlinedButton(
                onPressed: canAct ? onClearAll : null,
                child: Text('Clear all'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.notification});
  final AppNotification notification;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seen = notification.seen;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: seen
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .primary
              .withOpacity(seen ? 0.15 : 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                seen
                    ? Icons.notifications_none_rounded
                    : Icons.notifications_active_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title,
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.formatDateTime(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete'.tr(),
                onPressed: () async {
                  await ref
                      .read(notificationsControllerProvider.notifier)
                      .delete(notification.id);
                  showSuccessToast(context, 'Notification removed.'.tr());
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(notification.body,
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () async {
                  await ref
                      .read(notificationsControllerProvider.notifier)
                      .markRead(notification.id, seen: !seen);
                  showSuccessToast(
                    context,
                    seen ? 'Marked as unread.'.tr() : 'Marked as read.'.tr(),
                  );
                },
                icon: Icon(
                  seen ? Icons.markunread_rounded : Icons.check_circle_outline,
                ),
                label: Text(seen ? 'Mark unread'.tr() : 'Mark read'.tr()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            AppButton(
              label: 'Try again'.tr(),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
