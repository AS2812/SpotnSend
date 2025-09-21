import 'package:flutter/material.dart';

import '../core/theme/typography.dart';
import 'app_button.dart';

Future<bool?> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  ButtonVariant confirmVariant = ButtonVariant.primary,
}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: AppTypography.headingSmall.copyWith(color: Theme.of(context).colorScheme.primary)),
      content: Text(message, style: AppTypography.bodyMedium),
      actions: [
        AppButton(
          label: cancelLabel,
          onPressed: () => Navigator.of(ctx).pop(false),
          variant: ButtonVariant.secondary,
        ),
        AppButton(
          label: confirmLabel,
          onPressed: () => Navigator.of(ctx).pop(true),
          variant: confirmVariant,
        ),
      ],
    ),
  );
}

