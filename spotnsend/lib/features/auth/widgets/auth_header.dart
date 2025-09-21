import 'package:flutter/material.dart';

import 'package:spotnsend/core/theme/gradients.dart';
import 'package:spotnsend/core/theme/typography.dart';

class AuthGradientHeader extends StatelessWidget {
  const AuthGradientHeader({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppGradients.heading,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 84,
            child: Image.asset('assets/images/logo_spotnsend.png'),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headingLarge.copyWith(color: Colors.white),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 12),
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

