import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/core/utils/validators.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/app_text_field.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

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
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_newPasswordController.text != _confirmPasswordController.text) {
      showErrorToast(context, 'New passwords do not match'.tr());
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate API call - replace with actual implementation
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implement actual password change API call here
      // final result = await ref.read(authControllerProvider.notifier).changePassword(
      //   currentPassword: _currentPasswordController.text,
      //   newPassword: _newPasswordController.text,
      // );

      showSuccessToast(context, 'Password changed successfully'.tr());
      Navigator.of(context).pop();
    } catch (error) {
      showErrorToast(
          context, 'Failed to change password. Please try again.'.tr());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password'.tr()),
        elevation: 0,
      ),
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
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.lock_reset_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
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

              // Current Password
              AppTextField(
                controller: _currentPasswordController,
                label: 'Current Password'.tr(),
                hint: 'Enter your current password'.tr(),
                obscureText: true,
                validator: (value) => validateNotEmpty(context, value,
                    fieldName: 'Current Password'.tr()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // New Password
              AppTextField(
                controller: _newPasswordController,
                label: 'New Password'.tr(),
                hint: 'Enter your new password'.tr(),
                obscureText: true,
                validator: (value) => validatePassword(context, value),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Confirm Password
              AppTextField(
                controller: _confirmPasswordController,
                label: 'Confirm New Password'.tr(),
                hint: 'Confirm your new password'.tr(),
                obscureText: true,
                validator: (value) {
                  if (value != _newPasswordController.text) {
                    return 'Passwords do not match'.tr();
                  }
                  return validatePassword(context, value);
                },
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: 32),

              // Submit Button
              AppButton(
                label: 'Change Password'.tr(),
                onPressed: _isLoading ? null : _changePassword,
                loading: _isLoading,
              ),

              const SizedBox(height: 16),

              // Security Tips
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.tips_and_updates_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Password Security Tips'.tr(),
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'password_security_tips'.tr(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            height: 1.5,
                          ),
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
