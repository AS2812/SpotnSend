String? validateEmail(String? value) {
  if (value == null || value.isEmpty) {
    return 'Email is required';
  }
  final trimmed = value.trim();
  if (!trimmed.contains('@') || !trimmed.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}

String? validatePassword(String? value) {
  if (value == null || value.isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  return null;
}

String? validatePhone(String? value) {
  if (value == null || value.isEmpty) {
    return 'Phone number is required';
  }
  final normalized = value.replaceAll(' ', '');
  final body = normalized.startsWith('+') ? normalized.substring(1) : normalized;
  final digitsOnly = !RegExp(r'[^0-9]').hasMatch(body);
  if (!digitsOnly || body.length < 8 || body.length > 15) {
    return 'Enter a valid phone number';
  }
  return null;
}

String? validateNotEmpty(String? value, {String fieldName = 'Field'}) {
  if (value == null || value.trim().isEmpty) {
    return '${fieldName} is required';
  }
  return null;
}

String? validateOtp(String? value) {
  if (value == null || value.length != 6) {
    return 'Enter the 6-digit code';
  }
  if (int.tryParse(value) == null) {
    return 'Only numbers are allowed';
  }
  return null;
}
