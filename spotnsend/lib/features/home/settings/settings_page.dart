import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/data/models/settings_models.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/home/settings/providers/settings_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(settingsControllerProvider);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final controller = ref.read(settingsControllerProvider.notifier);
    final settings = state.settings;

    return Scaffold(
      appBar: AppBar(title: Text('Settings'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: Text('Notifications'.tr()),
            subtitle: Text(
                'Receive push notifications about nearby incidents and alerts.'
                    .tr()),
            value: settings.notificationsOn,
            onChanged: (value) async {
              await controller.updateNotifications(value);
              showSuccessToast(context,
                  value ? 'Notifications enabled.' : 'Notifications disabled.');
            },
          ),
          SwitchListTile(
            title: Text('Two-factor authentication'.tr()),
            subtitle:
                Text('Add a verified phone for an extra security step.'.tr()),
            value: settings.twoFactorEnabled,
            onChanged: (value) async {
              await controller.updateTwoFactor(value);
              showSuccessToast(
                  context, value ? '2FA enabled.' : '2FA disabled.');
            },
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: Text('Arabic Language'.tr()),
            subtitle: Text(settings.language == AppLanguage.arabic
                ? 'Using Arabic interface'.tr()
                : 'Using English interface'.tr()),
            value: settings.language == AppLanguage.arabic,
            onChanged: (value) async {
              final newLanguage =
                  value ? AppLanguage.arabic : AppLanguage.english;
              await controller.updateLanguage(newLanguage);
              showSuccessToast(context, 'Language updated.'.tr());
            },
          ),
          ListTile(
            title: Text('Theme'.tr()),
            subtitle: Text(_getThemeModeDisplayName(settings.themeMode)),
            trailing: SegmentedButton<AppThemeMode>(
              segments: [
                ButtonSegment(
                    value: AppThemeMode.light,
                    icon: const Icon(Icons.light_mode_rounded),
                    label: Text('Light'.tr())),
                ButtonSegment(
                    value: AppThemeMode.dark,
                    icon: const Icon(Icons.dark_mode_rounded),
                    label: Text('Dark'.tr())),
                ButtonSegment(
                    value: AppThemeMode.system,
                    icon: const Icon(Icons.phone_iphone_rounded),
                    label: Text('System'.tr())),
              ],
              selected: <AppThemeMode>{settings.themeMode},
              onSelectionChanged: (selection) =>
                  controller.updateThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: Text('Change password'.tr()),
            onTap: () => showSuccessToast(
                context, 'Password reset flow coming soon.'.tr()),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: Text('Contact support'.tr()),
            subtitle: Text(settings.contactEmail),
            onTap: () => showSuccessToast(context, 'Contact us at '.tr()),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: Text('User guide'.tr()),
            onTap: () => showSuccessToast(
                context, 'User guide will open in a future update.'.tr()),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_rounded),
            title: Text('Report a bug'.tr()),
            onTap: () =>
                showSuccessToast(context, 'Bug report form coming soon.'.tr()),
          ),
          ListTile(
            leading: const Icon(Icons.article_rounded),
            title: Text('Terms & Conditions'.tr()),
            onTap: () => showSuccessToast(
                context, 'Terms & Conditions screen placeholder.'.tr()),
          ),
          const SizedBox(height: 24),
          Center(child: Text('App version '.tr() + settings.appVersion)),
        ],
      ),
    );
  }

  String _getThemeModeDisplayName(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.light:
        return 'Light'.tr();
      case AppThemeMode.dark:
        return 'Dark'.tr();
      case AppThemeMode.system:
        return 'System'.tr();
    }
  }
}
