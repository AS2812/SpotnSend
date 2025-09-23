import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/empty_state.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class MapListView extends ConsumerWidget {
  const MapListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(mapReportsControllerProvider);

    Future<void> _refresh() async {
      // Rebuild the provider (fetch latest & keep realtime)
      ref.invalidate(mapReportsControllerProvider);
      // give it a micro tick to avoid returning before a new state emits
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Latest reports nearby'.tr()),
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
      body: reportsAsync.when(
        data: (reports) {
          if (reports.isEmpty) {
            return EmptyState(
              icon: Icons.location_off_rounded,
              title: 'No reports in range'.tr(),
              message:
                  'Try increasing your radius or adjust filters to see more activity.'
                      .tr(),
            );
          }

          return RefreshIndicator.adaptive(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: reports.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final report = reports[index];
                return _ReportTile(report: report);
              },
            ),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Failed to load reports: {error}'.tr(params: {'error': '$error'}),
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
}

class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final Report report;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Optional: friendly labels (Report.model already handles parsing)
    final priority = report.priority.name; // low/normal/high/critical
    final status = report.status.name; // submitted/underReview/approved/...

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
                    Text(
                      (report.subcategory.isEmpty
                          ? ''
                          : report.subcategory.tr()),
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Wrap(
                spacing: 6,
                children: [
                  _Chip(
                    label: priority.tr(),
                    color: theme.colorScheme.primary.withOpacity(0.10),
                    textColor: theme.colorScheme.primary,
                  ),
                  _Chip(
                    label: status.tr(),
                    color: theme.colorScheme.secondary.withOpacity(0.10),
                    textColor: theme.colorScheme.secondary,
                  ),
                ],
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
          if (report.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.mediaUrls
                  .map((url) => Chip(
                        avatar: const Icon(Icons.attachment_rounded, size: 18),
                        label: Text(url.split('/').last),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
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
