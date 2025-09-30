import 'package:flutter/material.dart';

import 'package:spotnsend/core/theme/gradients.dart';
import 'package:spotnsend/core/theme/typography.dart';

class AuthGradientHeader extends StatelessWidget {
  const AuthGradientHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.compact = false,
  });

  final String title;
  final String? subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final topPadding = compact ? 32.0 : 56.0;
    final bottomPadding = compact ? 24.0 : 32.0;
    final logoHeight = compact ? 70.0 : 84.0;
    final titleSpacing = compact ? 18.0 : 24.0;
    final subtitleSpacing = compact ? 8.0 : 12.0;

    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.heading,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: EdgeInsets.fromLTRB(24, topPadding, 24, bottomPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: logoHeight,
            child: Image.asset('assets/images/logo_spotnsend.png'),
          ),
          SizedBox(height: titleSpacing),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headingLarge.copyWith(color: Colors.white),
          ),
          if (subtitle != null) ...[
            SizedBox(height: subtitleSpacing),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }
}
