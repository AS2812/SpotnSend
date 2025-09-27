import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/features/home/map/category_icon_helpers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/map/widgets/alert_detail_sheet.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/empty_state.dart';

class MapListView extends ConsumerWidget {
  const MapListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(mapListContentProvider);

    Future<void> _refresh() async {
      ref.invalidate(mapReportsControllerProvider);
      ref.invalidate(accountSavedSpotsProvider);
      ref.invalidate(mapAlertsControllerProvider);
      // wait for dependent futures so the refresh indicator feels responsive
      await Future.wait([
        ref.read(mapReportsControllerProvider.future),
        ref.read(accountSavedSpotsProvider.future),
        ref.read(mapAlertsControllerProvider.future),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Nearby activity'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _refresh,
          ),
        ],
      ),
      body: contentAsync.when(
        data: (content) {
          final sections = _buildSections(context, content);

          if (sections.isEmpty) {
            return EmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'Nothing to show yet'.tr(),
              message:
                  'Adjust your radius or add saved spots to see more updates.'
                      .tr(),
            );
          }

          return RefreshIndicator.adaptive(
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (_, index) => sections[index],
            ),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load list: {error}'.tr(params: {'error': '$error'}),
              textAlign: TextAlign.center,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: AppButton(
            label: 'Back to map'.tr(),
            onPressed: () => context.pop(),
            variant: ButtonVariant.secondary,
            icon: Icons.map_rounded,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSections(BuildContext context, MapListContent content) {
    final sections = <Widget>[];

    if (content.savedSpotSummaries.isNotEmpty) {
      sections.add(
        _SectionHeader(
          icon: Icons.place_rounded,
          title: 'Saved spots with activity'.tr(),
        ),
      );
      sections.addAll(
        content.savedSpotSummaries
            .map((summary) => _SavedSpotCard(summary: summary))
            .toList(),
      );
    }

    if (content.reports.isNotEmpty) {
      sections.add(
        _SectionHeader(
          icon: Icons.report_rounded,
          title: 'Active reports nearby'.tr(),
        ),
      );
      sections.addAll(
        content.reports.map((report) => _ReportCard(report: report)).toList(),
      );
    }

    if (content.alerts.isNotEmpty) {
      sections.add(
        _SectionHeader(
          icon: Icons.notifications_active_rounded,
          title: 'Alerts & updates'.tr(),
        ),
      );
      sections.addAll(
        content.alerts.map((alert) => _AlertCard(alert: alert)).toList(),
      );
    }

    return sections;
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _SavedSpotCard extends StatelessWidget {
  const _SavedSpotCard({required this.summary});

  final SavedSpotSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spot = summary.spot;
    final reports = summary.reports;
    final radiusMeters = (spot.radiusMeters ?? 5000).toDouble();
    final radiusLabel = radiusMeters >= 1000
        ? '${(radiusMeters / 1000).toStringAsFixed(1)} km'
        : '${radiusMeters.toStringAsFixed(0)} m';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.place_rounded,
                  color: theme.colorScheme.primary.withOpacity(0.8)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(spot.name, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.formatCoordinates(spot.lat, spot.lng),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              _Chip(
                label: '${reports.length} ${'reports'.tr()}',
                color: theme.colorScheme.primary.withOpacity(0.12),
                textColor: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Monitoring radius: {radius}'.tr(params: {'radius': radiusLabel}),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          ...reports.take(3).map((report) => _MiniReportRow(report: report)),
          if (reports.length > 3) ...[
            const SizedBox(height: 6),
            Text(
              '+${reports.length - 3} ${'more reports'.tr()}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniReportRow extends StatelessWidget {
  const _MiniReportRow({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final iconAsset = iconAssetForSlug(report.categorySlug) ??
        iconAssetForCategoryName(report.category);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (iconAsset != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Image.asset(iconAsset, width: 18, height: 18),
            )
          else
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.brightness_1, size: 12),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.category.tr(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (report.description.isNotEmpty)
                  Text(
                    report.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final priority = report.priority.name;
    final iconAsset = iconAssetForSlug(report.categorySlug) ??
        iconAssetForCategoryName(report.category);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconAsset != null)
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Image.asset(iconAsset, fit: BoxFit.contain),
                )
              else
                Icon(Icons.report_gmailerrorred_rounded,
                    color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(report.category.tr(),
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    if (report.subcategory.isNotEmpty)
                      Text(
                        report.subcategory.tr(),
                        style: theme.textTheme.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Chip(
                label: priority.tr(),
                color: theme.colorScheme.primary.withOpacity(0.10),
                textColor: theme.colorScheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (report.description.trim().isNotEmpty)
            Text(report.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16),
              const SizedBox(width: 8),
              Text(AppFormatters.formatDateTime(report.createdAt)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert});

  final Alert alert;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final severityColor = _severityColor(theme, alert.severity);

    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (_) => AlertDetailSheet(alert: alert),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active_rounded, color: severityColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(alert.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(alert.category.tr(),
                          style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
                _Chip(
                  label: alert.severity.name.tr(),
                  color: severityColor.withOpacity(0.1),
                  textColor: severityColor,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (alert.description.isNotEmpty)
              Text(alert.description, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16),
                const SizedBox(width: 8),
                Text(AppFormatters.formatDateTime(alert.createdAt)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _severityColor(ThemeData theme, AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.low:
        return const Color(0xFF4CAF50);
      case AlertSeverity.medium:
        return const Color(0xFFFF9800);
      case AlertSeverity.high:
        return const Color(0xFFF44336);
      case AlertSeverity.critical:
        return const Color(0xFF9C27B0);
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.color,
    required this.textColor,
  });

  final String label;
  final Color color;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
      ),
    );
  }
}
