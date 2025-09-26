import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
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

class SignupStep2IdPage extends ConsumerStatefulWidget {
  const SignupStep2IdPage({super.key});

  @override
  ConsumerState<SignupStep2IdPage> createState() => _SignupStep2IdPageState();
}

class _SignupStep2IdPageState extends ConsumerState<SignupStep2IdPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idNumberController;
  String? _frontPath;
  String? _backPath;

  @override
  void initState() {
    super.initState();
    _idNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickFile(bool isFront) async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: false);
    if (result != null && result.files.single.path != null) {
      setState(() {
        if (isFront) {
          _frontPath = result.files.single.path;
        } else {
          _backPath = result.files.single.path;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_frontPath == null || _backPath == null) {
      showErrorToast(context, 'Please upload both sides of your ID'.tr());
      return;
    }

    await ref.read(authControllerProvider.notifier).signupStep2({
      'idNumber': _idNumberController.text.trim(),
      'frontIdPath': _frontPath!,
      'backIdPath': _backPath!,
    });

    final state = ref.read(authControllerProvider);
    if (mounted && state.error == null) {
      context.go(RoutePaths.signupStep3);
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

    return AuthScaffold(
      title: 'Verify your identity'.tr(),
      subtitle:
          'Upload your national ID so we can keep reporting trusted.'.tr(),
      showBackButton: true,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _idNumberController,
              label: 'National ID number'.tr(),
              keyboardType: TextInputType.number,
              validator: (value) => validateNotEmpty(context, value,
                  fieldName: 'National ID number'.tr()),
            ),
            const SizedBox(height: 22),
            _UploadTile(
              title: 'Front of ID'.tr(),
              subtitle:
                  _frontPath ?? 'Upload a clear image of the front side'.tr(),
              onTap: () => _pickFile(true),
            ),
            const SizedBox(height: 16),
            _UploadTile(
              title: 'Back of ID'.tr(),
              subtitle:
                  _backPath ?? 'Upload a clear image of the back side'.tr(),
              onTap: () => _pickFile(false),
            ),
            const SizedBox(height: 28),
            AppButton(
              label: 'Continue to selfie verification'.tr(),
              onPressed: authState.isLoading ? null : _submit,
              loading: authState.isLoading,
            ),
            const SizedBox(height: 14),
            AppButton(
              label: 'Back to info'.tr(),
              variant: ButtonVariant.secondary,
              onPressed: () => context.go(RoutePaths.signupStep1),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile(
      {required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.upload_file_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}
