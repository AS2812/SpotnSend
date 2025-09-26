import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/router/routes.dart';
import '../../shared/widgets/app_button.dart';
import '../../shared/widgets/toasts.dart';
import 'providers/auth_providers.dart';
import 'widgets/auth_scaffold.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class SignupStep3SelfiePage extends ConsumerStatefulWidget {
  const SignupStep3SelfiePage({super.key});

  @override
  ConsumerState<SignupStep3SelfiePage> createState() =>
      _SignupStep3SelfiePageState();
}

class _SignupStep3SelfiePageState extends ConsumerState<SignupStep3SelfiePage> {
  final ImagePicker _picker = ImagePicker();
  String? _selfiePath;

  Future<void> _captureSelfie() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      showErrorToast(
          context, 'Camera permission is required to capture a selfie.'.tr());
      return;
    }

    final result = await _picker.pickImage(
        source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (result != null) {
      setState(() => _selfiePath = result.path);
    }
  }

  Future<void> _submit() async {
    if (_selfiePath == null) {
      showErrorToast(context, 'Please capture a selfie to continue'.tr());
      return;
    }

    await ref
        .read(authControllerProvider.notifier)
        .signupStep3(SignupStep3Data(selfiePath: _selfiePath!));

    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.error != null) {
      showErrorToast(context, state.error!);
      return;
    }

    showSuccessToast(
        context, 'Thank you! Your account is pending verification.'.tr());
    context.go(RoutePaths.homeMap);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.error != next.error && next.error != null) {
        showErrorToast(context, next.error!);
      }
    });

    return AuthScaffold(
      title: 'Final step: Selfie verification'.tr(),
      subtitle: 'Capture a quick selfie so we can match it with your ID.'.tr(),
      showBackButton: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SelfiePreview(path: _selfiePath),
          const SizedBox(height: 20),
          AppButton(
            label:
                (_selfiePath == null ? 'Capture selfie' : 'Retake selfie').tr(),
            onPressed: authState.isLoading ? null : _captureSelfie,
            variant: ButtonVariant.secondary,
          ),
          const SizedBox(height: 28),
          const _PendingInfoCard(),
          const SizedBox(height: 20),
          AppButton(
            label: 'Submit for verification'.tr(),
            onPressed: authState.isLoading ? null : _submit,
            loading: authState.isLoading,
          ),
        ],
      ),
    );
  }
}

class _SelfiePreview extends StatelessWidget {
  const _SelfiePreview({required this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 260,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.15)),
        image: path != null
            ? DecorationImage(
                image: FileImage(File(path!)),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: path == null
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.camera_alt_rounded,
                    size: 52, color: theme.colorScheme.primary),
                const SizedBox(height: 14),
                Text(
                  'Tap capture to take your selfie'.tr(),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            )
          : Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Preview'.tr(),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );
  }
}

class _PendingInfoCard extends StatelessWidget {
  const _PendingInfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What happens next?'.tr(),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'Our team will verify your details shortly. You can explore reports but reporting will unlock once you are verified.'
                .tr(),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
