import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/data/models/settings_models.dart';
import 'package:spotnsend/data/services/settings_service.dart';

final settingsControllerProvider =
    NotifierProvider<SettingsController, SettingsState>(() {
  return SettingsController();
});

class SettingsState {
  const SettingsState({required this.settings, this.isLoading = true});

  final AppSettings settings;
  final bool isLoading;

  ThemeMode get themeMode {
    switch (settings.themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  Locale get locale => settings.locale;

  SettingsState copyWith({AppSettings? settings, bool? isLoading}) {
    return SettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsController extends Notifier<SettingsState> {
  late SettingsService service;

  @override
  SettingsState build() {
    service = ref.watch(settingsServiceProvider);
    load();
    return const SettingsState(
      settings: AppSettings(
        notificationsOn: true,
        twoFactorEnabled: false,
        language: AppLanguage.english,
        themeMode: AppThemeMode.system,
        contactEmail: 'support@spotnsend.com',
        appVersion: 'v1.0.0',
      ),
      isLoading: true,
    );
  }

  Future<void> load() async {
    final settings = await service.get();
    state = state.copyWith(settings: settings, isLoading: false);
  }

  Future<void> updateNotifications(bool value) async {
    final updated = state.settings.copyWith(notificationsOn: value);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }

  Future<void> updateTwoFactor(bool value) async {
    final updated = state.settings.copyWith(twoFactorEnabled: value);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }

  Future<void> updateLanguage(AppLanguage language) async {
    final updated = state.settings.copyWith(language: language);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }

  Future<void> updateThemeMode(AppThemeMode mode) async {
    final updated = state.settings.copyWith(themeMode: mode);
    state = state.copyWith(settings: updated);
    await service.update(updated);
  }
}
