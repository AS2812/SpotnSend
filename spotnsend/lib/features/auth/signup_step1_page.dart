import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spotnsend/data/models/auth_models.dart';

import '../../core/router/routes.dart';
import '../../core/utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/toasts.dart';
import 'providers/auth_providers.dart';
import 'widgets/auth_header.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class SignupStep1Page extends ConsumerStatefulWidget {
  const SignupStep1Page({super.key});

  @override
  ConsumerState<SignupStep1Page> createState() => _SignupStep1PageState();
}

class _SignupStep1PageState extends ConsumerState<SignupStep1Page> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _otpController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _otpController = TextEditingController(text: '123456');
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signupStep1(
          SignupStep1Data(
            fullName: _fullNameController.text.trim(),
            username: _usernameController.text.trim(),
            email: _emailController.text.trim(),
            phone: _phoneController.text.trim(),
            password: _passwordController.text,
            otp: _otpController.text.trim(),
          ),
        );

    final state = ref.read(authControllerProvider);
    if (mounted && state.error == null) {
      context.go(RoutePaths.signupStep2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.error != next.error && next.error != null) {
        showErrorToast(context, next.error!);
      }
    });

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthGradientHeader(
              title: 'Create your SpotnSend account'.tr(),
              subtitle: 'We need a few details to set up your secure profile.'.tr(),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _fullNameController,
                      label: 'Full name'.tr(),
                      validator: (value) => validateNotEmpty(context, value, fieldName: 'Full name'.tr()),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _usernameController,
                      label: 'Username'.tr(),
                      validator: (value) => validateNotEmpty(context, value, fieldName: 'Username'.tr()),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _emailController,
                      label: 'Email'.tr(),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) => validateEmail(context, value),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _phoneController,
                      label: 'Phone number'.tr(),
                      keyboardType: TextInputType.phone,
                      validator: (value) => validatePhone(context, value),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password'.tr(),
                      obscureText: true,
                      validator: (value) => validatePassword(context, value),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _otpController,
                      label: 'SMS verification code'.tr(),
                      keyboardType: TextInputType.number,
                      validator: (value) => validateOtp(context, value),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Continue to ID verification'.tr(),
                      onPressed: authState.isLoading ? null : _submit,
                      loading: authState.isLoading,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: 'Already have an account? '.tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: 'Log in'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700),
                              recognizer: TapGestureRecognizer()..onTap = () => context.go(RoutePaths.login),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
