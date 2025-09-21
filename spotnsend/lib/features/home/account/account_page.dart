import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/formatters.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/widgets/app_badge.dart';
import 'package:spotnsend/widgets/app_button.dart';
import 'package:spotnsend/widgets/toasts.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';

class AccountPage extends ConsumerWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(accountUserProvider);

    if (user == null) {
      return Scaffold(
        body: Center(
          child: AppButton(
            label: 'Reload profile',
            onPressed: () => ref.read(accountControllerProvider).refresh(),
          ),
        ),
      );
    }

    final badge = user.isVerified
        ? AppBadge(label: 'Verified', variant: BadgeVariant.verified)
        : AppBadge(label: 'Pending', variant: BadgeVariant.pending);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 18, offset: const Offset(0, 12)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      child: const Icon(Icons.person, size: 36),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 4),
                          Text(user.username, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                    badge,
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: _StatTile(label: 'Reports', value: user.reportsSubmitted.toString())),
                    const SizedBox(width: 12),
                    Expanded(child: _StatTile(label: 'Feedback', value: user.feedbackGiven.toString())),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _EditableTile(
            icon: Icons.phone_rounded,
            label: 'Phone number',
            value: user.phone,
            onSave: (value) async {
              final result = await ref.read(accountControllerProvider).updatePhone(value);
              result.when(
                success: (_) => showSuccessToast(context, 'Phone updated.'),
                failure: (message) => showErrorToast(context, message),
              );
            },
          ),
          _EditableTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
            onSave: (value) async {
              final result = await ref.read(accountControllerProvider).updateEmail(value);
              result.when(
                success: (_) => showSuccessToast(context, 'Email updated.'),
                failure: (message) => showErrorToast(context, message),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.badge_rounded),
            title: const Text('National ID'),
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
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(value, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EditableTile extends StatefulWidget {
  const _EditableTile({required this.icon, required this.label, required this.value, required this.onSave});

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
        title: Text('Update ${widget.label.toLowerCase()}'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Save')),
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
      trailing: IconButton(icon: const Icon(Icons.edit_rounded), onPressed: _edit),
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
            Text('Saved spots', style: Theme.of(context).textTheme.titleLarge),
            TextButton(
              onPressed: () => _addSpot(context, ref),
              child: const Text('Add new spot'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (savedSpots.isEmpty)
          const Text('No saved spots yet. Add your home, office, or loved ones to stay alerted.'),
        for (final spot in savedSpots)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.place_rounded),
              title: Text(spot.name),
              subtitle: Text('Lat ${spot.lat.toStringAsFixed(4)}, Lng ${spot.lng.toStringAsFixed(4)}'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  final result = await ref.read(accountControllerProvider).removeSavedSpot(spot.id);
                  result.when(
                    success: (_) => showSuccessToast(context, 'Saved spot removed.'),
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
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add saved spot'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: latController, decoration: const InputDecoration(labelText: 'Latitude'), keyboardType: TextInputType.number),
            TextField(controller: lngController, decoration: const InputDecoration(labelText: 'Longitude'), keyboardType: TextInputType.number),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (result == true) {
      final lat = double.tryParse(latController.text.trim());
      final lng = double.tryParse(lngController.text.trim());
      if (lat == null || lng == null) {
        showErrorToast(context, 'Enter valid coordinates.');
        return;
      }
      final response = await ref.read(accountControllerProvider).addSavedSpot(nameController.text.trim(), lat, lng);
      response.when(
        success: (_) => showSuccessToast(context, 'Saved spot added.'),
        failure: (message) => showErrorToast(context, message),
      );
    }
  }
}














