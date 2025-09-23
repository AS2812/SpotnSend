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
    final isLoading = async is AsyncLoading;

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
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _ErrorView(
          message: 'Failed to load notifications: $error',
          onRetry: () =>
              ref.read(notificationsControllerProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return RefreshIndicator(
              onRefresh: () =>
                  ref.read(notificationsControllerProvider.notifier).refresh(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  const SizedBox(height: 40),
                  EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No notifications yet'.tr(),
                    message: 'When alerts arrive, they will show up here.'.tr(),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () =>
                ref.read(notificationsControllerProvider.notifier).refresh(),
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemBuilder: (_, i) => _NotificationTile(notification: items[i]),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: items.length,
            ),
          );
        },
      ),
      bottomNavigationBar: async.maybeWhen(
        data: (items) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Mark all read'.tr(),
                    variant: ButtonVariant.secondary,
                    onPressed: items.isEmpty || isLoading
                        ? null
                        : () async {
                            await ref
                                .read(notificationsControllerProvider.notifier)
                                .markAll(seen: true);
                            showSuccessToast(context,
                                'All notifications marked as read.'.tr());
                          },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppButton(
                    label: 'Clear all'.tr(),
                    variant: ButtonVariant.secondary,
                    onPressed: items.isEmpty || isLoading
                        ? null
                        : () async {
                            await ref
                                .read(notificationsControllerProvider.notifier)
                                .deleteAll();
                            showSuccessToast(
                                context, 'Notifications cleared.'.tr());
                          },
                  ),
                ),
              ],
            ),
          ),
        ),
        orElse: () => const SizedBox.shrink(),
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
