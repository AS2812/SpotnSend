import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/core/utils/validators.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/app_text_field.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/l10n/app_localizations.dart';
import 'package:spotnsend/data/models/two_factor_service.dart';

class EnableTwoFactorPage extends ConsumerStatefulWidget {
  const EnableTwoFactorPage({super.key});

  @override
  ConsumerState<EnableTwoFactorPage> createState() =>
      _EnableTwoFactorPageState();
}

class _EnableTwoFactorPageState extends ConsumerState<EnableTwoFactorPage> {
  bool _loading = true;
  String? _uri;
  String? _factorId;
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _loading = true);
    final svc = ref.read(twoFactorServiceProvider);
    final res = await svc.startEnrollTotp();
    res.when(
      success: (enroll) {
        _uri = enroll.otpauthUri;
        _factorId = enroll.factorId;
      },
      failure: (msg) => showErrorToast(context, msg),
    );
    setState(() => _loading = false);
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      showErrorToast(context, 'Enter the 6-digit code'.tr());
      return;
    }
    final svc = ref.read(twoFactorServiceProvider);
    final res = await svc.verifyTotp(factorId: _factorId!, code: code);
    res.when(
      success: (_) {
        showSuccessToast(context, 'Two-factor enabled'.tr());
        Navigator.of(context).pop(true); // return true => enabled
      },
      failure: (msg) => showErrorToast(context, msg),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text('Enable two-factor'.tr())),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _uri == null
              ? Center(
                  child: Text('Unable to start enrollment'.tr()),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: ListView(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 200,
                              height: 200,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: cs.outlineVariant),
                                borderRadius: BorderRadius.circular(8),
                                color: cs.surface,
                              ),
                              child: Icon(Icons.qr_code_2_rounded,
                                  size: 96, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Scan this URI in your authenticator app, then enter the code.'
                                  .tr(),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              _uri!,
                              style: Theme.of(context).textTheme.bodySmall,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AppTextField(
                        controller: _codeController,
                        label: '6-digit code'.tr(),
                        hint: '123456',
                        keyboardType: TextInputType.number,
                        validator: (v) => validateNotEmpty(context, v,
                            fieldName: 'Code'.tr()),
                      ),
                      const SizedBox(height: 16),
                      AppButton(
                        label: 'Verify & Enable'.tr(),
                        onPressed:
                            (_loading || _factorId == null) ? null : _verify,
                      ),
                    ],
                  ),
                ),
    );
  }
}
