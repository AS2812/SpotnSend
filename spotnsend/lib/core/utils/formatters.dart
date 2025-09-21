import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime) {
  final formatter = DateFormat('MMM d • h:mm a');
  return formatter.format(dateTime.toLocal());
}

String formatShortDate(DateTime dateTime) {
  final formatter = DateFormat('MM/dd/yyyy');
  return formatter.format(dateTime.toLocal());
}

String formatDistanceKm(double distanceKm) {
  final formatted = distanceKm % 1 == 0 ? distanceKm.toStringAsFixed(0) : distanceKm.toStringAsFixed(1);
  return '$formatted km';
}

String maskIdNumber(String idNumber) {
  if (idNumber.length <= 4) {
    return idNumber;
  }
  final masked = '*' * (idNumber.length - 4);
  return '$masked${idNumber.substring(idNumber.length - 4)}';
}
