import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:spotnsend/data/models/auth_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/router/routes.dart';
import '../../widgets/app_button.dart';
import '../../widgets/toasts.dart';
import 'providers/auth_providers.dart';
import 'widgets/auth_header.dart';

class SignupStep3SelfiePage extends ConsumerStatefulWidget {
  const SignupStep3SelfiePage({super.key});

  @override
  ConsumerState<SignupStep3SelfiePage> createState() => _SignupStep3SelfiePageState();
}

class _SignupStep3SelfiePageState extends ConsumerState<SignupStep3SelfiePage> {
  final ImagePicker _picker = ImagePicker();
  String? _selfiePath;

  Future<void> _captureSelfie() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      if (!mounted) return;
      showErrorToast(context, 'Camera permission is required to capture a selfie.');
      return;
    }

    final result = await _picker.pickImage(source: ImageSource.camera, preferredCameraDevice: CameraDevice.front);
    if (result != null) {
      setState(() => _selfiePath = result.path);
    }
  }

  Future<void> _submit() async {
    if (_selfiePath == null) {
      showErrorToast(context, 'Please capture a selfie to continue');
      return;
    }

    await ref.read(authControllerProvider.notifier).signupStep3(SignupStep3Data(selfiePath: _selfiePath!));

    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.error != null) {
      showErrorToast(context, state.error!);
      return;
    }

    showSuccessToast(context, 'Thank you! Your account is pending verification.');
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

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthGradientHeader(
              title: 'Final step: Selfie verification',
              subtitle: 'Capture a quick selfie so we can match it with your ID.',
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
                      image: _selfiePath != null
                          ? DecorationImage(image: FileImage(File(_selfiePath!)), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _selfiePath == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt_rounded, size: 48, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 12),
                              Text('Tap capture to take your selfie', style: Theme.of(context).textTheme.bodyMedium),
                            ],
                          )
                        : null,
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    label: _selfiePath == null ? 'Capture selfie' : 'Retake selfie',
                    onPressed: authState.isLoading ? null : _captureSelfie,
                    variant: ButtonVariant.secondary,
                  ),
                  const SizedBox(height: 32),
                  const _PendingInfoCard(),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Submit for verification',
                    onPressed: authState.isLoading ? null : _submit,
                    loading: authState.isLoading,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingInfoCard extends StatelessWidget {
  const _PendingInfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'What happens next?',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text('Our team will verify your details shortly. You can explore reports but reporting will unlock once you are verified.'),
        ],
      ),
    );
  }
}

