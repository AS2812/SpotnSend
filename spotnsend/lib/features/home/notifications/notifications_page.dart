import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/notification_models.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/empty_state.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/home/notifications/providers/notification_providers.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(notificationsControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.read(notificationsControllerProvider.notifier).load(),
          ),
        ],
      ),
      body: state.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No notifications yet',
              message: 'When alerts arrive, they will show up here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _NotificationTile(notification: notification);
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: notifications.length,
          );
        },
        error: (error, _) => Center(child: Text('Failed to load notifications: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Mark all read',
                  variant: ButtonVariant.secondary,
                  onPressed: () async {
                    await ref.read(notificationsControllerProvider.notifier).markAll(seen: true);
                    showSuccessToast(context, 'All notifications marked as read.');
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppButton(
                  label: 'Clear all',
                  variant: ButtonVariant.secondary,
                  onPressed: () async {
                    await ref.read(notificationsControllerProvider.notifier).deleteAll();
                    showSuccessToast(context, 'Notifications cleared.');
                  },
                ),
              ),
            ],
          ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: notification.seen
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(notification.seen ? 0.15 : 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(notification.seen ? Icons.notifications_none_rounded : Icons.notifications_active_rounded,
                  color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(notification.title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(formatDateTime(notification.createdAt), style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  await ref.read(notificationsControllerProvider.notifier).delete(notification.id);
                  showSuccessToast(context, 'Notification removed.');
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(notification.body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => ref.read(notificationsControllerProvider.notifier).markRead(notification.id, seen: !notification.seen),
                icon: Icon(notification.seen ? Icons.markunread_rounded : Icons.check_circle_outline),
                label: Text(notification.seen ? 'Mark unread' : 'Mark read'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

