import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/core/utils/validators.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/app_text_field.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

enum BugSeverity { low, medium, high, critical }

class ReportBugPage extends ConsumerStatefulWidget {
  const ReportBugPage({super.key});

  @override
  ConsumerState<ReportBugPage> createState() => _ReportBugPageState();
}

class _ReportBugPageState extends ConsumerState<ReportBugPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _stepsController = TextEditingController();
  BugSeverity _severity = BugSeverity.medium;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _stepsController.dispose();
    super.dispose();
  }

  Future<void> _submitBugReport() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Simulate API call - replace with actual implementation
      await Future.delayed(const Duration(seconds: 2));

      // TODO: Implement actual bug report submission
      // final result = await bugReportService.submit(
      //   title: _titleController.text,
      //   description: _descriptionController.text,
      //   steps: _stepsController.text,
      //   severity: _severity,
      // );

      showSuccessToast(
          context, 'Bug report submitted successfully. Thank you!'.tr());
      Navigator.of(context).pop();
    } catch (error) {
      showErrorToast(
          context, 'Failed to submit bug report. Please try again.'.tr());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  String _getSeverityLabel(BugSeverity severity) {
    switch (severity) {
      case BugSeverity.low:
        return 'Low'.tr();
      case BugSeverity.medium:
        return 'Medium'.tr();
      case BugSeverity.high:
        return 'High'.tr();
      case BugSeverity.critical:
        return 'Critical'.tr();
    }
  }

  Color _getSeverityColor(BugSeverity severity) {
    switch (severity) {
      case BugSeverity.low:
        return Colors.green;
      case BugSeverity.medium:
        return Colors.orange;
      case BugSeverity.high:
        return Colors.red;
      case BugSeverity.critical:
        return Colors.red.shade900;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report a Bug'.tr()),
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
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.bug_report_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Help Us Improve SpotnSend'.tr(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Report bugs to help us make the app better for everyone.'
                          .tr(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Bug Title
              AppTextField(
                controller: _titleController,
                label: 'Bug Title'.tr(),
                hint: 'Brief description of the issue'.tr(),
                validator: (value) => validateNotEmpty(context, value,
                    fieldName: 'Bug Title'.tr()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              // Severity Selection
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Severity Level'.tr(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: BugSeverity.values.map((severity) {
                          final isSelected = _severity == severity;
                          return FilterChip(
                            selected: isSelected,
                            label: Text(_getSeverityLabel(severity)),
                            backgroundColor:
                                _getSeverityColor(severity).withOpacity(0.1),
                            selectedColor:
                                _getSeverityColor(severity).withOpacity(0.3),
                            checkmarkColor: _getSeverityColor(severity),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _severity = severity);
                              }
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bug Description
              AppTextField(
                controller: _descriptionController,
                label: 'Description'.tr(),
                hint: 'Describe what happened and what you expected'.tr(),
                maxLines: 4,
                validator: (value) => validateNotEmpty(context, value,
                    fieldName: 'Description'.tr()),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),

              // Steps to Reproduce
              AppTextField(
                controller: _stepsController,
                label: 'Steps to Reproduce'.tr(),
                hint: '1. Open the app\n2. Navigate to...\n3. Click on...'.tr(),
                maxLines: 4,
                validator: (value) => validateNotEmpty(context, value,
                    fieldName: 'Steps to Reproduce'.tr()),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 32),

              // Submit Button
              AppButton(
                label: 'Submit Bug Report'.tr(),
                onPressed: _isLoading ? null : _submitBugReport,
                loading: _isLoading,
                icon: Icons.send_rounded,
              ),

              const SizedBox(height: 16),

              // Contact Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.contact_support_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Need immediate help?'.tr(),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact support at support@spotnsend.com'.tr(),
                      style: Theme.of(context).textTheme.bodySmall,
                      textAlign: TextAlign.center,
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
