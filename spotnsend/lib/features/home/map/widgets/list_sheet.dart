import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/features/home/map/category_icon_helpers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/empty_state.dart';

class MapListSheet extends ConsumerWidget {
  const MapListSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(mapListContentProvider);

    Future<void> refresh() async {
      ref.invalidate(mapReportsControllerProvider);
      ref.invalidate(accountSavedSpotsProvider);
      ref.invalidate(mapAlertsControllerProvider);
      await Future.wait([
        ref.read(mapReportsControllerProvider.future),
        ref.read(accountSavedSpotsProvider.future),
        ref.read(mapAlertsControllerProvider.future),
      ]);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (context, controller) {
        final theme = Theme.of(context);
        final surfaceColor = theme.colorScheme.surface;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 24,
                offset: const Offset(0, -12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nearby activity'.tr(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text('Refresh'.tr()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: contentAsync.when(
                  data: (content) {
                    final sections = _buildSections(context, content);
                    if (sections.isEmpty) {
                      return ListView(
                        controller: controller,
                        padding: const EdgeInsets.all(32),
                        children: [
                          EmptyState(
                            icon: Icons.notifications_off_outlined,
                            title: 'Nothing to show yet'.tr(),
                            message:
                                'Adjust your filters or radius to discover more updates.'
                                    .tr(),
                          ),
                        ],
                      );
                    }

                    return RefreshIndicator.adaptive(
                      onRefresh: refresh,
                      child: ListView.separated(
                        controller: controller,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(
                          24,
                          12,
                          24,
                          MediaQuery.of(context).padding.bottom + 32,
                        ),
                        itemCount: sections.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, index) => sections[index],
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator.adaptive(),
                    ),
                  ),
                  error: (error, _) => ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(24),
                    children: [
                      Text(
                        'Failed to load list: {error}'
                            .tr(params: {'error': '$error'}),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Try again'.tr(),
                        onPressed: refresh,
                        icon: Icons.refresh,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
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
    final radiusMeters = (spot.radiusMeters ?? 250).toDouble();
    final radiusLabel = radiusMeters >= 1000
        ? '${(radiusMeters / 1000).toStringAsFixed(1)} km'
        : '${radiusMeters.toStringAsFixed(0)} m';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.35),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.place_rounded, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  spot.name,
                  style: theme.textTheme.titleMedium,
                ),
              ),
              Text(radiusLabel, style: theme.textTheme.labelMedium),
            ],
          ),
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: reports
                  .map(
                    (report) => _ChipEntry(
                      iconKey: mapImageKeyForSlug(report.categorySlug) ??
                          mapImageKeyForCategoryName(report.categoryName),
                      title: report.category,
                      subtitle: report.subcategory,
                    ),
                  )
                  .toList(),
            ),
          ],
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Icon(
                Icons.warning_rounded,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  report.category,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  report.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  AppFormatters.formatRelativeTime(report.createdAt),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
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
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.32),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active,
                  color: theme.colorScheme.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  alert.title,
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            alert.description,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: theme.hintColor),
              const SizedBox(width: 8),
              Text(
                AppFormatters.formatRelativeTime(alert.createdAt),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipEntry extends StatelessWidget {
  const _ChipEntry({this.iconKey, required this.title, required this.subtitle});

  final String? iconKey;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
