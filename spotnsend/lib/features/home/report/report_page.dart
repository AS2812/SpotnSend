import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:spotnsend/core/router/routes.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/confirm_dialog.dart';
import 'package:spotnsend/core/utils/validators.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/report/providers/report_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

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
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, type: FileType.media);
    if (result != null) {
      final paths = result.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList();
      ref.read(reportFormProvider.notifier).setMedia(paths);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final formState = ref.read(reportFormProvider);
    if (!formState.agreedToTerms) {
      showErrorToast(
          context, 'You must agree to the warning before submitting.'.tr());
      return;
    }

    final confirm = await showConfirmDialog(
      context: context,
      title: 'Before you submit'.tr(),
      message:
          'Government reports share your name, ID, and phone. False or misleading reports may result in legal action and 3-month account suspension. Proceed?'
              .tr(),
      confirmLabel: 'I understand'.tr(),
    );

    if (confirm != true) {
      return;
    }

    final result = await ref.read(reportFormProvider.notifier).submit();
    result.when(
      success: (report) {
        showSuccessToast(
            context, 'Report submitted. Officials will review shortly.'.tr());
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
      appBar: AppBar(title: Text('Submit a report'.tr())),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: 'Category'.tr()),
              value: formState.categoryId,
              items: [
                for (final category in categories)
                  DropdownMenuItem<int>(
                      value: category.id, child: Text(category.name.tr())),
              ],
              onChanged: (value) {
                if (value == null) {
                  ref.read(reportFormProvider.notifier).updateCategory(null);
                  return;
                }
                final selected =
                    categories.firstWhere((category) => category.id == value);
                ref.read(reportFormProvider.notifier).updateCategory(selected);
              },
              validator: (value) =>
                  value == null ? 'Select a category'.tr() : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: 'Sub-category'.tr()),
              value: formState.subcategoryId,
              items: [
                for (final subcategory in subcategories)
                  DropdownMenuItem<int>(
                      value: subcategory.id,
                      child: Text(subcategory.name.tr())),
              ],
              onChanged: (value) {
                if (value == null) {
                  ref.read(reportFormProvider.notifier).updateSubcategory(null);
                  return;
                }
                final selected = subcategories
                    .firstWhere((subcategory) => subcategory.id == value);
                ref
                    .read(reportFormProvider.notifier)
                    .updateSubcategory(selected);
              },
              validator: (value) =>
                  value == null ? 'Select a sub-category'.tr() : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 4,
              decoration: InputDecoration(
                  labelText: 'Description'.tr(),
                  hintText: 'Describe what is happening...'.tr()),
              onChanged: (value) => ref
                  .read(reportFormProvider.notifier)
                  .updateDescription(value),
              validator: (value) => validateNotEmpty(context, value,
                  fieldName: 'Description'.tr()),
            ),
            const SizedBox(height: 16),
            _AudienceSelector(selected: formState.audience),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.photo_library_rounded),
              title: Text('Add photos or videos'.tr()),
              subtitle: Text(formState.mediaPaths.isEmpty
                  ? 'Optional evidence helps responders assess severity.'.tr()
                  : context.l10n.formatWithCount(
                      '{count} attachment(s) selected',
                      formState.mediaPaths.length)),
              trailing: IconButton(
                icon: const Icon(Icons.add_a_photo_rounded),
                onPressed: _pickMedia,
              ),
              onTap: _pickMedia,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text('Use current location'.tr()),
              subtitle: Text('Disable to drop a manual pin later.'.tr()),
              value: formState.useCurrentLocation,
              onChanged: (value) => ref
                  .read(reportFormProvider.notifier)
                  .setUseCurrentLocation(value),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text('I agree to the SpotnSend reporting policy'.tr()),
              subtitle: Text(
                  'False reports can lead to legal consequences and a 3-month ban.'
                      .tr()),
              value: formState.agreedToTerms,
              onChanged: (value) => ref
                  .read(reportFormProvider.notifier)
                  .setAgreement(value ?? false),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Continue'.tr(),
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
      ReportAudience.people: 'People'.tr(),
      ReportAudience.government: 'Government'.tr(),
      ReportAudience.both: 'Both'.tr(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who should be notified?'.tr()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == selected,
                onSelected: (_) => ref
                    .read(reportFormProvider.notifier)
                    .toggleAudience(entry.key),
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
              Text('Verification Required'.tr(),
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'Reporting is locked until your account has been verified. You can still browse live map updates and notifications.'
                    .tr(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Review account status'.tr(),
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
