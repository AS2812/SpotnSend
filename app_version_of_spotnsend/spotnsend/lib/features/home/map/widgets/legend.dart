import 'package:flutter/material.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chipTextStyle = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: FontWeight.w600,
    );

    final entries = [
      _LegendEntry(
        color: const Color(0xFFEB3E50),
        label: 'Active reports'.tr(),
      ),
      _LegendEntry(
        color: theme.colorScheme.primary,
        label: 'Saved spots'.tr(),
      ),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: entries
          .map(
            (entry) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface.withOpacity(0.9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: entry.color.withOpacity(0.22)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: entry.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      entry.label,
                      style: chipTextStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _LegendEntry {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;
}
