import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:spotnsend/core/router/routes.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/confirm_dialog.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/report/providers/report_providers.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.media);
    if (result != null) {
      final paths = result.files.where((file) => file.path != null).map((file) => file.path!).toList();
      ref.read(reportFormProvider.notifier).setMedia(paths);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final formState = ref.read(reportFormProvider);
    if (!formState.agreedToTerms) {
      showErrorToast(context, 'You must agree to the warning before submitting.');
      return;
    }

    final confirm = await showConfirmDialog(
      context: context,
      title: 'Before you submit',
      message:
          'Government reports share your name, ID, and phone. False or misleading reports may result in legal action and 3-month account suspension. Proceed?',
      confirmLabel: 'I understand',
    );

    if (confirm != true) {
      return;
    }

    final result = await ref.read(reportFormProvider.notifier).submit();
    result.when(
      success: (report) {
        showSuccessToast(context, 'Report submitted. Officials will review shortly.');
        ref.invalidate(nearbyReportsProvider);
      },
      failure: (message) => showErrorToast(context, message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState.isPendingVerification) {
      return const _PendingVerificationLock();
    }

    final formState = ref.watch(reportFormProvider);
    final categories = ref.watch(reportCategoriesProvider);
    final subcategories = ref.watch(reportSubcategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Submit a report')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Category'),
              value: formState.category,
              items: [
                for (final category in categories)
                  DropdownMenuItem(value: category.name, child: Text(category.name)),
              ],
              onChanged: (value) => ref.read(reportFormProvider.notifier).updateCategory(value),
              validator: (value) => value == null ? 'Select a category' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(labelText: 'Sub-category'),
              value: formState.subcategory,
              items: [
                for (final subcategory in subcategories)
                  DropdownMenuItem(value: subcategory, child: Text(subcategory)),
              ],
              onChanged: (value) => ref.read(reportFormProvider.notifier).updateSubcategory(value),
              validator: (value) => value == null ? 'Select a sub-category' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'Describe what is happening...'),
              onChanged: (value) => ref.read(reportFormProvider.notifier).updateDescription(value),
              validator: (value) => value == null || value.isEmpty ? 'Add a description' : null,
            ),
            const SizedBox(height: 16),
            _AudienceSelector(selected: formState.audience),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_rounded), 
              title: const Text('Add photos or videos'),
              subtitle: Text(formState.mediaPaths.isEmpty
                  ? 'Optional evidence helps responders assess severity.'
                  : ' attachment(s) selected'),
              trailing: IconButton(
                icon: const Icon(Icons.add_a_photo_rounded),
                onPressed: _pickMedia,
              ),
              onTap: _pickMedia,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Use current location'),
              subtitle: const Text('Disable to drop a manual pin later.'),
              value: formState.useCurrentLocation,
              onChanged: (value) => ref.read(reportFormProvider.notifier).setUseCurrentLocation(value),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('I agree to the SpotnSend reporting policy'),
              subtitle: const Text('False reports can lead to legal consequences and a 3-month ban.'),
              value: formState.agreedToTerms,
              onChanged: (value) => ref.read(reportFormProvider.notifier).setAgreement(value ?? false),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Continue',
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _AudienceSelector extends ConsumerWidget {
  const _AudienceSelector({required this.selected});

  final ReportAudience selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = {
      ReportAudience.people: 'People',
      ReportAudience.government: 'Government',
      ReportAudience.both: 'Both',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Who should be notified?'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == selected,
                onSelected: (_) => ref.read(reportFormProvider.notifier).toggleAudience(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _PendingVerificationLock extends StatelessWidget {
  const _PendingVerificationLock();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 72),
              const SizedBox(height: 24),
              Text('Verification Required', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              const Text(
                'Reporting is locked until your account has been verified. You can still browse live map updates and notifications.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Review account status',
                onPressed: () => context.go(RoutePaths.homeAccount),
                variant: ButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}





