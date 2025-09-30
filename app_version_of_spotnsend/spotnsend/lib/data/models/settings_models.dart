import 'package:flutter/material.dart';

enum AppLanguage { english, arabic }

enum AppThemeMode { system, light, dark }

class AppSettings {
  const AppSettings({
    required this.notificationsOn,
    required this.twoFactorEnabled,
    required this.language,
    required this.themeMode,
    required this.contactEmail,
    required this.appVersion,
  });

  final bool notificationsOn;
  final bool twoFactorEnabled;
  final AppLanguage language;
  final AppThemeMode themeMode;
  final String contactEmail;
  final String appVersion;

  Locale get locale => language == AppLanguage.arabic ? const Locale('ar') : const Locale('en');

  ThemeMode get themeModeValue {
    switch (themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  AppSettings copyWith({
    bool? notificationsOn,
    bool? twoFactorEnabled,
    AppLanguage? language,
    AppThemeMode? themeMode,
    String? contactEmail,
    String? appVersion,
  }) {
    return AppSettings(
      notificationsOn: notificationsOn ?? this.notificationsOn,
      twoFactorEnabled: twoFactorEnabled ?? this.twoFactorEnabled,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
      contactEmail: contactEmail ?? this.contactEmail,
      appVersion: appVersion ?? this.appVersion,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      notificationsOn: json['notificationsOn'] as bool? ?? true,
      twoFactorEnabled: json['twoFactorEnabled'] as bool? ?? false,
      language: (json['language'] as String?) == 'ar' ? AppLanguage.arabic : AppLanguage.english,
      themeMode: AppThemeMode.values.firstWhere(
        (mode) => mode.name == (json['themeMode'] as String? ?? AppThemeMode.system.name),
        orElse: () => AppThemeMode.system,
      ),
      contactEmail: json['contactEmail'] as String? ?? 'support@spotnsend.com',
      appVersion: json['appVersion'] as String? ?? 'v1.0.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'notificationsOn': notificationsOn,
        'twoFactorEnabled': twoFactorEnabled,
        'language': language == AppLanguage.arabic ? 'ar' : 'en',
        'themeMode': themeMode.name,
        'contactEmail': contactEmail,
        'appVersion': appVersion,
      };
}
