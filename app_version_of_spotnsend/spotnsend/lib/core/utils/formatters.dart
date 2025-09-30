import 'package:intl/intl.dart';

class AppFormatters {
  static final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  static final DateFormat _timeFormat = DateFormat('HH:mm');
  static final DateFormat _dateTimeFormat = DateFormat('MMM dd, yyyy HH:mm');
  static final DateFormat _shortDateFormat = DateFormat('MM/dd/yy');
  static final DateFormat _longDateFormat = DateFormat('EEEE, MMMM dd, yyyy');

  /// Format a DateTime to a readable date string
  static String formatDate(DateTime? date) {
    if (date == null) return '';
    return _dateFormat.format(date);
  }

  /// Format a DateTime to a time string
  static String formatTime(DateTime? date) {
    if (date == null) return '';
    return _timeFormat.format(date);
  }

  /// Format a DateTime to a date and time string
  static String formatDateTime(DateTime? date) {
    if (date == null) return '';
    return _dateTimeFormat.format(date);
  }

  /// Format a DateTime to a short date string
  static String formatShortDate(DateTime? date) {
    if (date == null) return '';
    return _shortDateFormat.format(date);
  }

  /// Format a DateTime to a long date string
  static String formatLongDate(DateTime? date) {
    if (date == null) return '';
    return _longDateFormat.format(date);
  }

  /// Format a number to currency
  static String formatCurrency(double? amount, {String symbol = '\$'}) {
    if (amount == null) return '${symbol}0.00';
    return NumberFormat.currency(symbol: symbol).format(amount);
  }

  /// Format a number with commas
  static String formatNumber(int? number) {
    if (number == null) return '0';
    return NumberFormat('#,###').format(number);
  }

  /// Format a double with specified decimal places
  static String formatDouble(double? value, {int decimalPlaces = 2}) {
    if (value == null) return '0.00';
    return NumberFormat('#,##0.${'0' * decimalPlaces}').format(value);
  }

  /// Format a percentage
  static String formatPercentage(double? value, {int decimalPlaces = 1}) {
    if (value == null) return '0%';
    return NumberFormat('#,##0.${'0' * decimalPlaces}%').format(value);
  }

  /// Format a file size in bytes to human readable format
  static String formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '0 B';

    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${NumberFormat('#,##0.${i == 0 ? '0' : '1'}').format(size)} ${suffixes[i]}';
  }

  /// Format a duration to human readable format
  static String formatDuration(Duration? duration) {
    if (duration == null) return '0s';

    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes % 60}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }

  /// Format a phone number
  static String formatPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return '';

    // Remove all non-digit characters
    String digits = phone.replaceAll(RegExp(r'[^\d]'), '');

    if (digits.length == 10) {
      return '(${digits.substring(0, 3)}) ${digits.substring(3, 6)}-${digits.substring(6)}';
    } else if (digits.length == 11 && digits.startsWith('1')) {
      return '+1 (${digits.substring(1, 4)}) ${digits.substring(4, 7)}-${digits.substring(7)}';
    }

    return phone; // Return original if can't format
  }

  /// Format a relative time (e.g., "2 hours ago")
  static String formatRelativeTime(DateTime? date) {
    if (date == null) return '';

    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 7) {
      return formatDate(date);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
