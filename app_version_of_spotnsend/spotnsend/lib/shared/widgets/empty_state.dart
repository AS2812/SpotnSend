import 'package:flutter/material.dart';

import '../../core/theme/typography.dart';

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key, required this.icon, required this.title, this.message});

  final IconData icon;
  final String title;
  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 48,
              color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
          const SizedBox(height: 12),
          Text(title,
              style: AppTypography.headingSmall
                  .copyWith(color: Theme.of(context).colorScheme.primary)),
          if (message != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: 260,
              child: Text(
                message!,
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
