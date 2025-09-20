import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/data/models/settings_models.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/home/settings/providers/settings_providers.dart';

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
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            title: const Text('Notifications'),
            subtitle: const Text('Receive push notifications about nearby incidents and alerts.'),
            value: settings.notificationsOn,
            onChanged: (value) async {
              await controller.updateNotifications(value);
              showSuccessToast(context, value ? 'Notifications enabled.' : 'Notifications disabled.');
            },
          ),
          SwitchListTile(
            title: const Text('Two-factor authentication'),
            subtitle: const Text('Add a verified phone for an extra security step.'),
            value: settings.twoFactorEnabled,
            onChanged: (value) async {
              await controller.updateTwoFactor(value);
              showSuccessToast(context, value ? '2FA enabled.' : '2FA disabled.');
            },
          ),
          const SizedBox(height: 24),
          ListTile(
            title: const Text('Language'),
            subtitle: Text(settings.language == AppLanguage.arabic ? 'Arabic' : 'English'),
            trailing: DropdownButton<AppLanguage>(
              value: settings.language,
              onChanged: (value) async {
                if (value != null) {
                  await controller.updateLanguage(value);
                  showSuccessToast(context, 'Language updated.');
                }
              },
              items: const [
                DropdownMenuItem(value: AppLanguage.english, child: Text('English')),
                DropdownMenuItem(value: AppLanguage.arabic, child: Text('Arabic')),
              ],
            ),
          ),
          ListTile(
            title: const Text('Theme'),
            subtitle: Text(settings.themeMode.name),
            trailing: SegmentedButton<AppThemeMode>(
              segments: const [
                ButtonSegment(value: AppThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                ButtonSegment(value: AppThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                ButtonSegment(value: AppThemeMode.system, icon: Icon(Icons.phone_iphone_rounded), label: Text('System')),
              ],
              selected: <AppThemeMode>{settings.themeMode},
              onSelectionChanged: (selection) => controller.updateThemeMode(selection.first),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.lock_reset_rounded),
            title: const Text('Change password'),
            onTap: () => showSuccessToast(context, 'Password reset flow coming soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.support_agent_rounded),
            title: const Text('Contact support'),
            subtitle: Text(settings.contactEmail),
            onTap: () => showSuccessToast(context, 'Contact us at '),
          ),
          ListTile(
            leading: const Icon(Icons.menu_book_rounded),
            title: const Text('User guide'),
            onTap: () => showSuccessToast(context, 'User guide will open in a future update.'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_rounded),
            title: const Text('Report a bug'),
            onTap: () => showSuccessToast(context, 'Bug report form coming soon.'),
          ),
          ListTile(
            leading: const Icon(Icons.article_rounded),
            title: const Text('Terms & Conditions'),
            onTap: () => showSuccessToast(context, 'Terms & Conditions screen placeholder.'),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Enable Arabic RTL preview',
            variant: ButtonVariant.secondary,
            onPressed: () => controller.updateLanguage(AppLanguage.arabic),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Back to English',
            variant: ButtonVariant.secondary,
            onPressed: () => controller.updateLanguage(AppLanguage.english),
          ),
          const SizedBox(height: 24),
          Center(child: Text('App version ')),
        ],
      ),
    );
  }
}


