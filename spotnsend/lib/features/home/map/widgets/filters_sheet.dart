import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/data/services/report_service.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';

class MapFiltersSheet extends ConsumerWidget {
  const MapFiltersSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportService = ref.watch(reportServiceProvider);
    final filters = ref.watch(mapFiltersProvider);
    final savedSpots = ref.watch(accountSavedSpotsProvider);

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
              decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: Theme.of(context).textTheme.titleLarge),
              TextButton(
                onPressed: () => ref.read(mapFiltersProvider.notifier).clearCategories(),
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final category in reportService.categories)
                FilterChip(
                  label: Text(category.name),
                  selected: filters.categories.contains(category.name),
                  onSelected: (_) => ref.read(mapFiltersProvider.notifier).toggleCategory(category.name),
                ),
            ],
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('Include saved spots'),
            subtitle: Text(savedSpots.isEmpty ? 'Add saved spots from account to get proactive alerts.' : 'Your saved spots will always alert you.'),
            value: filters.includeSavedSpots,
            onChanged: (value) => ref.read(mapFiltersProvider.notifier).toggleSavedSpots(value),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Done',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}



