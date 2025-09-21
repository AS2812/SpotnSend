import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/typography.dart';

enum BadgeVariant { pending, verified, warning }

class AppBadge extends StatelessWidget {
  const AppBadge({super.key, required this.label, this.variant = BadgeVariant.pending});

  final String label;
  final BadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = _BadgeColors.fromVariant(variant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.border),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(color: colors.foreground, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _BadgeColors {
  const _BadgeColors({required this.background, required this.foreground, required this.border});

  final Color background;
  final Color foreground;
  final Color border;

  static _BadgeColors fromVariant(BadgeVariant variant) {
    switch (variant) {
      case BadgeVariant.verified:
        return const _BadgeColors(
          background: Color(0xFFE6F9F1),
          foreground: AppColors.success,
          border: Color(0xFF9DDFC3),
        );
      case BadgeVariant.warning:
        return const _BadgeColors(
          background: Color(0xFFFFF4E0),
          foreground: AppColors.warning,
          border: Color(0xFFFFD49B),
        );
      case BadgeVariant.pending:
      default:
        return const _BadgeColors(
          background: Color(0xFFEAE5F6),
          foreground: AppColors.primaryMagenta,
          border: Color(0xFFCBB6E5),
        );
    }
  }
}
