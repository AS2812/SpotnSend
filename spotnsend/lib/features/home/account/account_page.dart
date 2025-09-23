import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/shared/widgets/app_badge.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/location_picker.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(accountUserProvider);

    return userAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stack) => Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error loading profile: ${error.toString()}'.tr(),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              AppButton(
                label: 'Try again'.tr(), // no �Reload profile� anymore
                onPressed: () => ref.invalidate(accountUserProvider),
              ),
            ],
          ),
        ),
      ),
      data: (user) {
        // If your provider autogenerates the profile when missing,
        // just show a spinner while it resolves to a real user.
        if (user == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _ProfileView(user: user);
      },
    );
  }
}

class _ProfileView extends ConsumerWidget {
  const _ProfileView({required this.user});
  final AppUser user;

  String _maskIdNumber(String idNumber) {
    if (idNumber.isEmpty) return 'Not provided';
    if (idNumber.length <= 4) return idNumber;
    return '${'*' * (idNumber.length - 4)}${idNumber.substring(idNumber.length - 4)}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  offset: const Offset(0, 12),
                ),
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
                          Text('@${user.username}',
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
                        value: user.reportsSubmitted.toString(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatTile(
                        label: 'Feedback'.tr(),
                        value: user.feedbackGiven.toString(),
                      ),
                    ),
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
            keyboardType: TextInputType.phone,
            onSave: (value) async {
              final res =
                  await ref.read(accountControllerProvider).updatePhone(value);
              res.when(
                success: (_) {
                  showSuccessToast(context, 'Phone updated.'.tr());
                  ref.invalidate(accountUserProvider);
                },
                failure: (message) => showErrorToast(context, message),
              );
            },
          ),
          _EditableTile(
            icon: Icons.email_outlined,
            label: 'Email'.tr(),
            value: user.email,
            keyboardType: TextInputType.emailAddress,
            onSave: (value) async {
              final res =
                  await ref.read(accountControllerProvider).updateEmail(value);
              res.when(
                success: (_) {
                  showSuccessToast(context, 'Email updated.'.tr());
                  ref.invalidate(accountUserProvider);
                },
                failure: (message) => showErrorToast(context, message),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.badge_rounded),
            title: Text('National ID'.tr()),
            subtitle: Text(_maskIdNumber(user.idNumber)),
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
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
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
  const _EditableTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSave,
    this.keyboardType,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextInputType? keyboardType;
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
        content: TextField(
          controller: controller,
          keyboardType: widget.keyboardType,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'.tr()),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text('Save'.tr()),
          ),
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
      subtitle: Text(widget.value.isEmpty ? 'Not set'.tr() : widget.value),
      trailing: IconButton(
        icon: const Icon(Icons.edit_rounded),
        onPressed: _edit,
      ),
    );
  }
}

class _SavedSpotsSection extends ConsumerWidget {
  const _SavedSpotsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedSpotsAsync = ref.watch(accountSavedSpotsProvider);

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
        savedSpotsAsync.when(
          data: (savedSpots) {
            if (savedSpots.isEmpty) {
              return Text(
                'No saved spots yet. Add your home, office, or loved ones to stay alerted.'
                    .tr(),
              );
            }
            return Column(
              children: [
                for (final spot in savedSpots)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.place_rounded),
                      title: Text(spot.name),
                      subtitle: Text(
                        context.l10n.formatCoordinates(spot.lat, spot.lng),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline_rounded),
                        onPressed: () async {
                          final result = await ref
                              .read(accountControllerProvider)
                              .removeSavedSpot(spot.id);
                          result.when(
                            success: (_) {
                              showSuccessToast(
                                  context, 'Saved spot removed.'.tr());
                              ref.invalidate(accountSavedSpotsProvider);
                            },
                            failure: (message) =>
                                showErrorToast(context, message),
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Text('Error loading saved spots: $error'),
        ),
      ],
    );
  }

  Future<void> _addSpot(BuildContext context, WidgetRef ref) async {
    final selectedLocation = await context.showLocationPicker();
    if (selectedLocation == null) return;

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
        success: (_) {
          showSuccessToast(context, 'Saved spot added.'.tr());
          ref.invalidate(accountSavedSpotsProvider);
          ref.invalidate(accountUserProvider); // refresh stats
        },
        failure: (message) => showErrorToast(context, message),
      );
    }
  }
}
