import 'package:intl/intl.dart';

String formatDateTime(DateTime dateTime) {
  final formatter = DateFormat('MMM d • h:mm a');
  return formatter.format(dateTime.toLocal());
}

String formatShortDate(DateTime dateTime) {
  final formatter = DateFormat('MM/dd/yyyy');
  return formatter.format(dateTime.toLocal());
}

String formatDistanceKm(double distance) {
  if (distance % 1 == 0) {
    return ' km';
  }
  return ' km';
}

String maskIdNumber(String idNumber) {
  if (idNumber.length <= 4) {
    return idNumber;
  }
  final masked = '*' * (idNumber.length - 4);
  return '';
}
