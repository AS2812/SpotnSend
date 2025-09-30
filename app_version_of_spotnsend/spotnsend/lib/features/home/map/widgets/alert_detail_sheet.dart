import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/features/home/map/providers/alerts_providers.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class AlertDetailSheet extends ConsumerWidget {
  const AlertDetailSheet({super.key, required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomPadding + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getSeverityColor(alert.severity).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getSeverityIcon(alert.severity),
                    color: _getSeverityColor(alert.severity),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: theme.textTheme.titleLarge),
                      Text(
                        _getSeverityText(alert.severity),
                        style: theme.textTheme.bodyMedium?.copyWith(
                              color: _getSeverityColor(alert.severity),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: alert.status == AlertStatus.active
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    alert.status.name.toUpperCase(),
                    style: TextStyle(
                      color: alert.status == AlertStatus.active
                          ? Colors.green
                          : Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (alert.description.isNotEmpty) ...[
              Text('Description'.tr(), style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(alert.description, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.category,
                    label: 'Category'.tr(),
                    value:
                        alert.category.replaceAll('_', ' ').toUpperCase(),
                  ),
                ),
                const SizedBox(width: 8),
                if (alert.subcategory.isNotEmpty)
                  Expanded(
                    child: _InfoChip(
                      icon: Icons.label,
                      label: 'Subcategory'.tr(),
                      value: alert.subcategory
                          .replaceAll('_', ' ')
                          .toUpperCase(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _InfoChip(
                    icon: Icons.location_on,
                    label: 'Location'.tr(),
                    value:
                        '${alert.latitude.toStringAsFixed(4)}, ${alert.longitude.toStringAsFixed(4)}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _InfoChip(
                    icon: Icons.radio_button_unchecked,
                    label: 'Radius'.tr(),
                    value: '${(alert.radiusMeters / 1000).toStringAsFixed(1)} km',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoChip(
              icon: Icons.access_time,
              label: 'Created'.tr(),
              value: _formatDateTime(alert.createdAt),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: alert.status == AlertStatus.active
                    ? 'Mark as Resolved'.tr()
                    : 'Alert Resolved'.tr(),
                variant: ButtonVariant.secondary,
                icon: Icons.check_circle,
                onPressed: alert.status == AlertStatus.active
                    ? () => _resolveAlert(context, ref)
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getSeverityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Colors.green;
      case AlertSeverity.medium:
        return Colors.orange;
      case AlertSeverity.high:
        return Colors.red;
      case AlertSeverity.critical:
        return Colors.purple;
    }
  }

  IconData _getSeverityIcon(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return Icons.info;
      case AlertSeverity.medium:
        return Icons.warning;
      case AlertSeverity.high:
        return Icons.error;
      case AlertSeverity.critical:
        return Icons.dangerous;
    }
  }

  String _getSeverityText(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return 'Low Priority'.tr();
      case AlertSeverity.medium:
        return 'Medium Priority'.tr();
      case AlertSeverity.high:
        return 'High Priority'.tr();
      case AlertSeverity.critical:
        return 'Critical Priority'.tr();
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now'.tr();
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago'.tr();
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago'.tr();
    } else {
      return '${difference.inDays}d ago'.tr();
    }
  }

  Future<void> _resolveAlert(BuildContext context, WidgetRef ref) async {
    final success =
        await ref.read(alertsControllerProvider.notifier).resolveAlert(alert.id);

    if (!context.mounted) return;

    if (success) {
      showSuccessToast(context, 'Alert marked as resolved.'.tr());
      Navigator.of(context).pop();
    } else {
      showErrorToast(context, 'Failed to resolve alert. Try again.'.tr());
    }
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon,
                  size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
