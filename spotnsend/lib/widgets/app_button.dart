import 'package:flutter/material.dart';

import '../core/theme/colors.dart';
import '../core/theme/gradients.dart';
import '../core/theme/typography.dart';

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.loading = false,
    this.variant = ButtonVariant.primary,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final ButtonVariant variant;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || loading;

    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(variant == ButtonVariant.primary ? Colors.white : AppColors.primaryBlue),
              strokeWidth: 2.2,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: variant == ButtonVariant.primary ? AppColors.white : AppColors.primaryBlue,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          );

    switch (variant) {
      case ButtonVariant.primary:
        return DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppGradients.heading,
            borderRadius: BorderRadius.all(Radius.circular(18)),
          ),
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: AppColors.grey.withOpacity(0.3),
              shadowColor: Colors.transparent,
              fixedSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: child,
          ),
        );
      case ButtonVariant.secondary:
        return OutlinedButton(
          onPressed: isDisabled ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primaryBlue,
            side: const BorderSide(color: AppColors.primaryBlue, width: 1.4),
            fixedSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: child,
        );
    }
  }
}

enum ButtonVariant { primary, secondary }
