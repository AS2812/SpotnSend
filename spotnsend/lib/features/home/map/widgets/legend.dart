import 'package:flutter/material.dart';

class MapLegend extends StatelessWidget {
  const MapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final entries = [
      _LegendEntry(color: const Color(0xFFEB3E50), label: 'Active reports'),
      _LegendEntry(color: Theme.of(context).colorScheme.primary, label: 'Saved spots'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: entries
            .map(
              (entry) => Row(
                children: [
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: entry.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.label),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}

class _LegendEntry {
  const _LegendEntry({required this.color, required this.label});

  final Color color;
  final String label;
}
