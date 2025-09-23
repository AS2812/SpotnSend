import 'package:flutter/material.dart';

import 'package:spotnsend/l10n/app_localizations.dart';

class BackFooterButton extends StatelessWidget {
  const BackFooterButton({super.key});

  Future<void> _handleBack(BuildContext context) async {
    final navigator = Navigator.of(context);
    final popped = await navigator.maybePop();
    if (!popped) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('No previous page to return to.'.tr())),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.all(16),
      child: TextButton.icon(
        onPressed: () => _handleBack(context),
        icon: const Icon(Icons.arrow_back_ios_new_rounded),
        label: Text('Back'.tr()),
      ),
    );
  }
}
