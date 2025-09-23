import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/report/providers/report_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class MapFiltersSheet extends ConsumerWidget {
  const MapFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(mapFiltersProvider);
    final savedSpotsAsync = ref.watch(accountSavedSpotsProvider);
    final categoriesAsync = ref.watch(reportCategoriesProvider);

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).padding.bottom + 24,
      ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters'.tr(),
                  style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: () =>
                    ref.read(mapFiltersProvider.notifier).clearCategories(),
                child: Text('Clear'.tr()),
              ),
            ],
          ),
          const SizedBox(height: 16),
          categoriesAsync.when(
            data: (categories) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final category in categories)
                  FilterChip(
                    label: Text(
                        category.name.replaceAll('_', ' ').toUpperCase().tr()),
                    selected: filters.categoryIds.contains(category.id),
                    onSelected: (_) => ref
                        .read(mapFiltersProvider.notifier)
                        .toggleCategory(category.id),
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Text('Error loading categories'.tr()),
          ),
          const SizedBox(height: 24),
          savedSpotsAsync.when(
            data: (savedSpots) => SwitchListTile(
              title: Text('Include saved spots'.tr()),
              subtitle: Text(savedSpots.isEmpty
                  ? 'Add saved spots from account to get proactive alerts.'.tr()
                  : 'Your saved spots will always alert you.'.tr()),
              value: filters.includeSavedSpots,
              onChanged: (value) =>
                  ref.read(mapFiltersProvider.notifier).toggleSavedSpots(value),
            ),
            loading: () => SwitchListTile(
              title: Text('Include saved spots'.tr()),
              subtitle: Text('Loading saved spots...'.tr()),
              value: filters.includeSavedSpots,
              onChanged: (value) =>
                  ref.read(mapFiltersProvider.notifier).toggleSavedSpots(value),
            ),
            error: (error, stack) => SwitchListTile(
              title: Text('Include saved spots'.tr()),
              subtitle: Text('Error loading saved spots'.tr()),
              value: filters.includeSavedSpots,
              onChanged: (value) =>
                  ref.read(mapFiltersProvider.notifier).toggleSavedSpots(value),
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Done'.tr(),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}
