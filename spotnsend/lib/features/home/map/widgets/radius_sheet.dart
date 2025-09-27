import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class MapRadiusSheet extends ConsumerWidget {
  const MapRadiusSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filters = ref.watch(mapFiltersProvider);
    final radiusKm = filters.radiusKm;
    final media = MediaQuery.of(context);

    String radiusLabel(double value) {
      if (value >= 1) {
        return '${value.toStringAsFixed(1)} km';
      }
      return '${(value * 1000).round()} m';
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        media.padding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          Text(
            'Search radius'.tr(),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider.adaptive(
                  min: kMinSearchRadiusKm,
                  max: kMaxSearchRadiusKm,
                  divisions: ((kMaxSearchRadiusKm - kMinSearchRadiusKm) /
                          kRadiusStepKm)
                      .round(),
                  value: radiusKm,
                  label: radiusLabel(radiusKm),
                  onChanged: (value) =>
                      ref.read(mapFiltersProvider.notifier).setRadius(value),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                radiusLabel(radiusKm),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Radius only changes what you see on the map. Alerts are still delivered based on their own reach.'
                .tr(),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
