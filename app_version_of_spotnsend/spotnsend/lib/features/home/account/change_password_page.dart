import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/app_text_field.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/data/services/supabase_user_service.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? value) {
    return (value == null || value.trim().isEmpty) ? 'Required'.tr() : null;
  }

  String? _weakPasswordValidator(String? value) {
    final s = (value ?? '').trim();
    final okLen = s.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(s);
    final hasLower = RegExp(r'[a-z]').hasMatch(s);
    final hasDigit = RegExp(r'\d').hasMatch(s);
    final hasSymbol = RegExp(r'[^\w\s]').hasMatch(s);
    return (okLen && hasUpper && hasLower && hasDigit && hasSymbol)
        ? null
        : 'Weak password'.tr();
  }

  String? _confirmValidator(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Required'.tr();
    }
    if (trimmed != _newController.text.trim()) {
      return 'Passwords do not match'.tr();
    }
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final svc = ref.read(supabaseUserServiceProvider);
    final result = await svc.changePassword(
      currentPassword: _currentController.text.trim(),
      newPassword: _newController.text.trim(),
    );

    if (!mounted) return;

    setState(() => _isSubmitting = false);

    result.when(
      success: (_) {
        _currentController.clear();
        _newController.clear();
        _confirmController.clear();
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('Password updated'.tr())),
          );
      },
      failure: (message) {
        final text = message.trim().isEmpty
            ? 'Failed to change password'.tr()
            : message;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text(text)),
          );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: Text('Change Password'.tr())),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bottomPadding =
                MediaQuery.of(context).viewInsets.bottom + 24;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
              child: ConstrainedBox(
                constraints:
                    BoxConstraints(minHeight: constraints.maxHeight),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            Icon(Icons.lock_reset_rounded,
                                size: 48, color: cs.primary),
                            const SizedBox(height: 12),
                            Text(
                              'Update Your Password'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enter your current password and choose a new secure password.'
                                  .tr(),
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        controller: _currentController,
                        label: 'Current Password'.tr(),
                        hint: 'Enter your current password'.tr(),
                        obscureText: true,
                        validator: _requiredValidator,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _newController,
                        label: 'New Password'.tr(),
                        hint: 'Enter your new password'.tr(),
                        obscureText: true,
                        validator: _weakPasswordValidator,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 16),
                      AppTextField(
                        controller: _confirmController,
                        label: 'Confirm New Password'.tr(),
                        hint: 'Confirm your new password'.tr(),
                        obscureText: true,
                        validator: _confirmValidator,
                        textInputAction: TextInputAction.done,
                      ),
                      const SizedBox(height: 24),
                      AppButton(
                        label: 'Change Password'.tr(),
                        onPressed: _isSubmitting ? null : _submit,
                        loading: _isSubmitting,
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.tips_and_updates_rounded,
                                  color: cs.primary,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Password Security Tips'.tr(),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'password_security_tips'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
