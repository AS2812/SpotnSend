import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/routes.dart';
import '../../core/utils/validators.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/back_footer_button.dart';
import 'providers/auth_providers.dart';
import 'widgets/auth_header.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _identifierController;
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _identifierController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).login(
          identifier: _identifierController.text.trim(),
          password: _passwordController.text,
        );
  }

  Future<void> _loginTester() async {
    _identifierController.text = 'admin';
    _passwordController.text = 'admin12345';
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).loginTester();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if ((previous?.isAuthenticated ?? false) == false &&
          next.isAuthenticated) {
        context.go(RoutePaths.homeMap);
      }
    });

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text('Login'.tr()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            AuthGradientHeader(
              title: 'Welcome back to SpotnSend'.tr(),
              subtitle:
                  'Log in to monitor live reports and stay informed.'.tr(),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppTextField(
                      controller: _identifierController,
                      label: 'Email or username'.tr(),
                      hint: 'Enter your email or username'.tr(),
                      validator: (value) => validateNotEmpty(context, value,
                          fieldName: 'Identifier'.tr()),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: _passwordController,
                      label: 'Password'.tr(),
                      hint: 'Enter your password'.tr(),
                      obscureText: true,
                      validator: (value) => validatePassword(context, value),
                      textInputAction: TextInputAction.done,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: authState.keepSignedIn,
                          onChanged: (value) => ref
                              .read(authControllerProvider.notifier)
                              .setKeepSignedIn(value ?? false),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Keep me signed in'.tr())),
                      ],
                    ),
                    if (authState.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          authState.error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                    AppButton(
                      label: 'Log in'.tr(),
                      onPressed: authState.isLoading ? null : _submit,
                      loading: authState.isLoading,
                    ),
                    const SizedBox(height: 12),
                    AppButton(
                      label: 'Use tester account'.tr(),
                      variant: ButtonVariant.secondary,
                      onPressed: authState.isLoading ? null : _loginTester,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: RichText(
                        text: TextSpan(
                          text: "Don't have an account? ".tr(),
                          style: Theme.of(context).textTheme.bodyMedium,
                          children: [
                            TextSpan(
                              text: 'Sign up'.tr(),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700),
                              recognizer: TapGestureRecognizer()
                                ..onTap =
                                    () => context.go(RoutePaths.signupStep1),
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
      bottomNavigationBar: const BackFooterButton(),
    );
  }
}
