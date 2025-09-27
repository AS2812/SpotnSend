import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/utils/validators.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/toasts.dart';
import 'providers/auth_providers.dart';
import 'widgets/auth_scaffold.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class SignupStep1Page extends ConsumerStatefulWidget {
  const SignupStep1Page({super.key});

  @override
  ConsumerState<SignupStep1Page> createState() => _SignupStep1PageState();
}

class _SignupStep1PageState extends ConsumerState<SignupStep1Page> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _passwordController;
  late final TextEditingController _otpController;
  late final TextEditingController _nationalIdDisplayController;
  late final TextEditingController _genderDisplayController;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _passwordController = TextEditingController();
    _otpController = TextEditingController(text: '123456');
    _nationalIdDisplayController = TextEditingController();
    _genderDisplayController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _nationalIdDisplayController.dispose();
    _genderDisplayController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref.read(authControllerProvider.notifier).signupStep1({
      'fullName': _fullNameController.text.trim(),
      'email': _emailController.text.trim(),
      'phoneCountryCode': '+966',
      'phoneNumber': _phoneController.text.trim(),
      'password': _passwordController.text,
      'otp': _otpController.text.trim(),
    });

    final state = ref.read(authControllerProvider);
    if (mounted && state.error == null) {
      context.go(RoutePaths.signupStep2);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    final nationalIdText = authState.draftNationalId ?? '';
    if (_nationalIdDisplayController.text != nationalIdText) {
      _nationalIdDisplayController.text = nationalIdText;
    }

    final genderText = authState.draftGender == null
        ? 'Will autofill after ID upload'.tr()
        : (authState.draftGender == 'male' ? 'Male'.tr() : 'Female'.tr());
    if (_genderDisplayController.text != genderText) {
      _genderDisplayController.text = genderText;
    }

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.error != next.error && next.error != null) {
        showErrorToast(context, next.error!);
      }
    });

    return AuthScaffold(
      title: 'Create your SpotnSend account'.tr(),
      subtitle: 'We need a few details to set up your secure profile.'.tr(),
      showBackButton: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _fullNameController,
              label: 'Full name'.tr(),
              validator: (value) =>
                  validateNotEmpty(context, value, fieldName: 'Full name'.tr()),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _emailController,
              label: 'Email'.tr(),
              keyboardType: TextInputType.emailAddress,
              validator: (value) => validateEmail(context, value),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _phoneController,
              label: 'Phone number'.tr(),
              keyboardType: TextInputType.phone,
              validator: (value) => validatePhone(context, value),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _passwordController,
              label: 'Password'.tr(),
              obscureText: true,
              validator: (value) => validatePassword(context, value),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _otpController,
              label: 'SMS verification code'.tr(),
              keyboardType: TextInputType.number,
              validator: (value) => validateOtp(context, value),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _nationalIdDisplayController,
              label: 'National ID number'.tr(),
              hint: 'Will autofill after ID upload'.tr(),
              readOnly: true,
            ),
            const SizedBox(height: 18),
            AppTextField(
              controller: _genderDisplayController,
              label: 'Gender'.tr(),
              readOnly: true,
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Continue to ID verification'.tr(),
              onPressed: authState.isLoading ? null : _submit,
              loading: authState.isLoading,
            ),
          ],
        ),
      ),
      footer: Column(
        children: [
          const SizedBox(height: 12),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              text: 'Already have an account? '.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: 'Log in'.tr(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => context.go(RoutePaths.login),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
