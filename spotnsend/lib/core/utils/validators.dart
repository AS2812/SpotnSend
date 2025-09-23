import 'package:flutter/widgets.dart';

import 'package:spotnsend/l10n/app_localizations.dart';

String? validateEmail(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required'.tr();
  }
  final trimmed = value.trim();
  if (!trimmed.contains('@') || !trimmed.contains('.')) {
    return 'Enter a valid email'.tr();
  }
  return null;
}

String? validatePassword(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required'.tr();
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters'.tr();
  }
  return null;
}

String? validatePhone(BuildContext context, String? value) {
  if (value == null || value.isEmpty) {
    return 'Phone number is required'.tr();
  }
  final normalized = value.replaceAll(' ', '');
  final body = normalized.startsWith('+') ? normalized.substring(1) : normalized;
  final digitsOnly = !RegExp(r'[^0-9]').hasMatch(body);
  if (!digitsOnly || body.length < 8 || body.length > 15) {
    return 'Enter a valid phone number'.tr();
  }
  return null;
}

String? validateNotEmpty(BuildContext context, String? value, {required String fieldName}) {
  if (value == null || value.trim().isEmpty) {
    return '{field} is required'.tr(params: {'field': fieldName});
  }
  return null;
}

String? validateOtp(BuildContext context, String? value) {
  if (value == null || value.length != 6) {
    return 'Enter the 6-digit code'.tr();
  }
  if (int.tryParse(value) == null) {
    return 'Only numbers are allowed'.tr();
  }
  return null;
}
