import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/validators.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/app_text_field.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/data/services/supabase_user_service.dart';

class ChangePasswordPage extends ConsumerStatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  ConsumerState<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends ConsumerState<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();

  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final newPw = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();
    if (newPw != confirm) {
      showErrorToast(context, 'New passwords do not match'.tr());
      return;
    }

    setState(() => _isLoading = true);

    final svc = ref.read(supabaseUserServiceProvider);
    final res = await svc.changePassword(
      currentPassword: _currentPasswordController.text.trim(),
      newPassword: newPw,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.when(
      success: (_) {
        showSuccessToast(context, 'Password changed successfully'.tr());
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        Navigator.of(context).maybePop();
      },
      failure: (msg) => showErrorToast(
        context,
        msg.isEmpty ? 'Failed to change password'.tr() : msg,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('Change Password'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.lock_reset_rounded, size: 48, color: cs.primary),
                    const SizedBox(height: 12),
                    Text(
                      'Update Your Password'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
              const SizedBox(height: 32),

              // Current password
              AppTextField(
                controller: _currentPasswordController,
                label: 'Current Password'.tr(),
                hint: 'Enter your current password'.tr(),
                obscureText: true,
                validator: (v) => validateNotEmpty(
                  context,
                  v,
                  fieldName: 'Current Password'.tr(),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // New password
              AppTextField(
                controller: _newPasswordController,
                label: 'New Password'.tr(),
                hint: 'Enter your new password'.tr(),
                obscureText: true,
                // Reuse your existing password validator
                validator: (v) => validatePassword(context, v),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Confirm password
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password'.tr(),
                hint: 'Confirm your new password'.tr(),
                obscureText: true,
                validator: (v) {
                  if (v != _newPasswordController.text) {
                    return 'Passwords do not match'.tr();
                  }
                  return validatePassword(context, v);
                },
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: 32),

              AppButton(
                label: 'Change Password'.tr(),
                onPressed: _isLoading ? null : _changePassword,
                loading: _isLoading,
              ),

              const SizedBox(height: 16),

              // Tips
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
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
