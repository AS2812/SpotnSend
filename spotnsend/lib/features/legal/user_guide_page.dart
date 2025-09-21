import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class UserGuidePage extends ConsumerWidget {
  const UserGuidePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('User Guide'.tr()),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'SpotnSend User Guide'.tr(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Overview Section
            _buildSection(
              context,
              icon: Icons.info_rounded,
              title: 'Overview of Purpose and Value'.tr(),
              content: 'app_overview_content'.tr(),
            ),

            // Sign-up Section
            _buildSection(
              context,
              icon: Icons.person_add_rounded,
              title: 'Sign-Up'.tr(),
              content: 'signup_guide_content'.tr(),
            ),

            // ID Upload Section
            _buildSection(
              context,
              icon: Icons.upload_file_rounded,
              title: 'ID Upload'.tr(),
              content: 'id_upload_guide_content'.tr(),
            ),

            // Reporting Section
            _buildSection(
              context,
              icon: Icons.report_rounded,
              title: 'Reporting Hazards'.tr(),
              content: 'reporting_guide_content'.tr(),
            ),

            // Map & Notifications Section
            _buildSection(
              context,
              icon: Icons.map_rounded,
              title: 'Viewing Map and Notifications'.tr(),
              content: 'map_notifications_guide_content'.tr(),
            ),

            // Verification Section
            _buildSection(
              context,
              icon: Icons.verified_rounded,
              title: 'Verification of Reports'.tr(),
              content: 'verification_guide_content'.tr(),
            ),

            // Safety Principles Section
            _buildSection(
              context,
              icon: Icons.security_rounded,
              title: 'Safety Principles & User Responsibilities'.tr(),
              content: 'safety_principles_content'.tr(),
            ),

            const SizedBox(height: 32),

            // Emergency Numbers
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.emergency_rounded, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    'Emergency Numbers'.tr(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Police: 122 | Ambulance: 123 | Fire: 180'.tr(),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
