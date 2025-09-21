import 'package:intl/intl.dart';

import 'package:spotnsend/l10n/app_localizations.dart';

String formatDateTime(DateTime dateTime) {
  final locale = AppLocalizations.current.locale.languageCode;
  final pattern = locale == 'ar' ? 'd MMM · h:mm a' : 'MMM d · h:mm a';
  final formatter = DateFormat(pattern, locale);
  return formatter.format(dateTime.toLocal());
}

String formatShortDate(DateTime dateTime) {
  final locale = AppLocalizations.current.locale.languageCode;
  final pattern = locale == 'ar' ? 'dd/MM/yyyy' : 'MM/dd/yyyy';
  final formatter = DateFormat(pattern, locale);
  return formatter.format(dateTime.toLocal());
}

String formatDistanceKm(double distanceKm) {
  final formatted = distanceKm % 1 == 0 ? distanceKm.toStringAsFixed(0) : distanceKm.toStringAsFixed(1);
  return AppLocalizations.current.translate('{value} km', params: {'value': formatted});
}

String maskIdNumber(String idNumber) {
  if (idNumber.length <= 4) {
    return idNumber;
  }
  final masked = '*' * (idNumber.length - 4);
  return '$masked${idNumber.substring(idNumber.length - 4)}';
}
