import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/widgets/app_badge.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/location_picker.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(accountUserProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: AppButton(
            label: 'Reload profile'.tr(),
            onPressed: () => ref.read(accountControllerProvider).refresh(),
          ),
        ),
      );
    }

    final badge = user.isVerified
        ? AppBadge(label: 'Verified'.tr(), variant: BadgeVariant.verified)
        : AppBadge(label: 'Pending'.tr(), variant: BadgeVariant.pending);

    return Scaffold(
      appBar: AppBar(title: Text('Account'.tr())),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: const Icon(Icons.person, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name,
                              style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(user.username,
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                        child: _StatTile(
                            label: 'Reports'.tr(),
                            value: user.reportsSubmitted.toString())),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _StatTile(
                            label: 'Feedback'.tr(),
                            value: user.feedbackGiven.toString())),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _EditableTile(
            icon: Icons.phone_rounded,
            label: 'Phone number'.tr(),
            value: user.phone,
            onSave: (value) async {
              final result =
                  await ref.read(accountControllerProvider).updatePhone(value);
              result.when(
                success: (_) =>
                    showSuccessToast(context, 'Phone updated.'.tr()),
                failure: (message) => showErrorToast(context, message),
              );
            },
          ),
          _EditableTile(
            icon: Icons.email_outlined,
            label: 'Email'.tr(),
            value: user.email,
            onSave: (value) async {
              final result =
                  await ref.read(accountControllerProvider).updateEmail(value);
              result.when(
                success: (_) =>
                    showSuccessToast(context, 'Email updated.'.tr()),
                failure: (message) => showErrorToast(context, message),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.badge_rounded),
            title: Text('National ID'.tr()),
            subtitle: Text(maskIdNumber(user.idNumber)),
          ),
          const SizedBox(height: 24),
          const _SavedSpotsSection(),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _EditableTile extends StatefulWidget {
  const _EditableTile(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onSave});

  final IconData icon;
  final String label;
  final String value;
  final Future<void> Function(String value) onSave;

  @override
  State<_EditableTile> createState() => _EditableTileState();
}

class _EditableTileState extends State<_EditableTile> {
  Future<void> _edit() async {
    final controller = TextEditingController(text: widget.value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.updateFieldTitle(widget.label)),
        content: TextField(controller: controller),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'.tr())),
          TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: Text('Save'.tr())),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await widget.onSave(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(widget.icon),
      title: Text(widget.label),
      subtitle: Text(widget.value),
      trailing:
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: _edit),
    );
  }
}

class _SavedSpotsSection extends ConsumerWidget {
  const _SavedSpotsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSpots = ref.watch(accountSavedSpotsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Saved spots'.tr(),
                style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => _addSpot(context, ref),
              child: Text('Add new spot'.tr()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (savedSpots.isEmpty)
          Text(
              'No saved spots yet. Add your home, office, or loved ones to stay alerted.'
                  .tr()),
        for (final spot in savedSpots)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(spot.name),
              subtitle:
                  Text(context.l10n.formatCoordinates(spot.lat, spot.lng)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final result = await ref
                      .read(accountControllerProvider)
                      .removeSavedSpot(spot.id);
                  result.when(
                    success: (_) =>
                        showSuccessToast(context, 'Saved spot removed.'.tr()),
                    failure: (message) => showErrorToast(context, message),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _addSpot(BuildContext context, WidgetRef ref) async {
    // First, let user select location on map
    final selectedLocation = await context.showLocationPicker();
    if (selectedLocation == null) return;

    // Then ask for the name
    final nameController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Name this location'.tr()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Name'.tr(),
                hintText: 'e.g., Home, Office, School'.tr(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Selected Location'.tr(),
                            style: Theme.of(context).textTheme.labelMedium),
                        Text(
                          'Lat: ${selectedLocation.latitude.toStringAsFixed(4)}, '
                          'Lng: ${selectedLocation.longitude.toStringAsFixed(4)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Save'.tr())),
        ],
      ),
    );

    if (result == true && nameController.text.trim().isNotEmpty) {
      final response = await ref.read(accountControllerProvider).addSavedSpot(
            nameController.text.trim(),
            selectedLocation.latitude,
            selectedLocation.longitude,
          );
      response.when(
        success: (_) => showSuccessToast(context, 'Saved spot added.'.tr()),
        failure: (message) => showErrorToast(context, message),
      );
    }
  }
}
