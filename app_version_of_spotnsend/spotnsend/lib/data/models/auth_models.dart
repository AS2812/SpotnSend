class AuthTokens {
  const AuthTokens({required this.accessToken, required this.refreshToken, required this.expiresAt});

  final String accessToken;
  final String refreshToken;
  final DateTime expiresAt;

  factory AuthTokens.fromJson(Map<String, dynamic> json) {
    return AuthTokens(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}

class SignupStep1Data {
  const SignupStep1Data({
    required this.fullName,
    required this.username,
    required this.email,
    required this.phoneCountryCode,
    required this.phoneNumber,
    required this.password,
    required this.otp,
    this.nationalId,
    this.gender,
  });

  final String fullName;
  final String username;
  final String email;
  final String phoneCountryCode;
  final String phoneNumber;
  final String password;
  final String otp;
  final String? nationalId;
  final String? gender;
}

class SignupStep2Data {
  const SignupStep2Data({
    required this.verificationCode,
    this.idNumber,
    this.gender,
    required this.frontIdPath,
    required this.backIdPath,
  });

  final String verificationCode;
  final String? idNumber;
  final String? gender;
  final String frontIdPath;
  final String backIdPath;
}

class SignupStep3Data {
  const SignupStep3Data({required this.selfiePath});

  final String selfiePath;
}
