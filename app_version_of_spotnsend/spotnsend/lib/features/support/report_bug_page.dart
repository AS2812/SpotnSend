import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/core/utils/validators.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/app_text_field.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/data/services/supabase_bugs_service.dart';

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final res = await ref.read(supabaseBugsServiceProvider).submit(
          title: _titleController.text.trim(),
          description:
              '${_descriptionController.text.trim()}\n\nSteps to reproduce:\n${_stepsController.text.trim()}',
          severity: _severity.name,
        );

    if (!mounted) return;
    setState(() => _isLoading = false);

    res.when(
      success: (_) {
        showSuccessToast(
            context, 'Bug report submitted successfully. Thank you!'.tr());
        Navigator.of(context).maybePop();
      },
      failure: (msg) {
        showErrorToast(
            context, msg.isEmpty ? 'Failed to submit bug report'.tr() : msg);
      },
    );
  }

  String _label(BugSeverity s) => switch (s) {
        BugSeverity.low => 'Low',
        BugSeverity.medium => 'Medium',
        BugSeverity.high => 'High',
        BugSeverity.critical => 'Critical',
      }
          .tr();

  Color _color(BuildContext c, BugSeverity s) => switch (s) {
        BugSeverity.low => Colors.green,
        BugSeverity.medium => Colors.orange,
        BugSeverity.high => Colors.red,
        BugSeverity.critical => Colors.red.shade900,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Report a Bug'.tr())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // header card ...
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.bug_report_rounded,
                        size: 48, color: Theme.of(context).colorScheme.error),
                    const SizedBox(height: 12),
                    Text('Help Us Improve SpotnSend'.tr(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center),
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

              AppTextField(
                controller: _titleController,
                label: 'Bug Title'.tr(),
                hint: 'Brief description of the issue'.tr(),
                validator: (v) =>
                    validateNotEmpty(context, v, fieldName: 'Bug Title'.tr()),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Severity Level'.tr(),
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: BugSeverity.values.map((s) {
                          final selected = _severity == s;
                          final col = _color(context, s);
                          return FilterChip(
                            label: Text(_label(s)),
                            selected: selected,
                            onSelected: (v) => setState(() => _severity = s),
                            backgroundColor: col.withOpacity(0.08),
                            selectedColor: col.withOpacity(0.22),
                            checkmarkColor: col,
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _descriptionController,
                label: 'Description'.tr(),
                hint: 'Describe what happened and what you expected'.tr(),
                maxLines: 4,
                validator: (v) =>
                    validateNotEmpty(context, v, fieldName: 'Description'.tr()),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 16),

              AppTextField(
                controller: _stepsController,
                label: 'Steps to Reproduce'.tr(),
                hint: '1. Open the app\n2. Navigate to...\n3. Click on...'.tr(),
                maxLines: 4,
                validator: (v) => validateNotEmpty(context, v,
                    fieldName: 'Steps to Reproduce'.tr()),
                textInputAction: TextInputAction.newline,
              ),
              const SizedBox(height: 32),

              AppButton(
                label: 'Submit Bug Report'.tr(),
                onPressed: _isLoading ? null : _submitBugReport,
                loading: _isLoading,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
