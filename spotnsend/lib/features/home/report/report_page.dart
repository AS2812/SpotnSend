import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:location/location.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'package:go_router/go_router.dart';
import 'package:spotnsend/core/router/routes.dart';
import 'package:spotnsend/data/models/alert_models.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/services/supabase_alerts_service.dart';
import 'package:spotnsend/shared/widgets/app_button.dart';
import 'package:spotnsend/shared/widgets/confirm_dialog.dart';
import 'package:spotnsend/shared/widgets/location_picker.dart';
import 'package:spotnsend/shared/widgets/toasts.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';
import 'package:spotnsend/features/home/map/providers/map_providers.dart';
import 'package:spotnsend/features/home/report/providers/report_providers.dart';
import 'package:spotnsend/l10n/app_localizations.dart';

class ReportPage extends ConsumerStatefulWidget {
  const ReportPage({super.key});

  @override
  ConsumerState<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends ConsumerState<ReportPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  ProviderSubscription<ReportFormData>? _formSubscription;
  ProviderSubscription<AsyncValue<LocationData?>>? _locationSubscription;
  bool _isSubmitting = false;

  String _humanize(String value) {
    if (value.isEmpty) return value;
    final withSpaces = value.replaceAll('_', ' ').toLowerCase();
    return withSpaces
        .split(' ')
        .map((w) => w.isEmpty ? w : (w[0].toUpperCase() + w.substring(1)))
        .join(' ');
  }

  String _formatCoordinates(double lat, double lng) {
    return 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';
  }

  @override
  void initState() {
    super.initState();
    _descriptionController.text = ref.read(reportFormProvider).description;
    _formSubscription =
        ref.listenManual<ReportFormData>(reportFormProvider, (previous, next) {
      if (_descriptionController.text != next.description) {
        _descriptionController.text = next.description;
      }
    });
    _locationSubscription = ref.listenManual<AsyncValue<LocationData?>>(
        currentLocationProvider, (previous, next) {
      next.whenOrNull(data: (location) {
        if (location == null) return;
        final lat = location.latitude;
        final lng = location.longitude;
        if (lat == null || lng == null) return;
        final form = ref.read(reportFormProvider);
        if (!form.useCurrentLocation) return;
        final currentLat = form.selectedLat;
        final currentLng = form.selectedLng;
        if (currentLat != null &&
            currentLng != null &&
            (currentLat - lat).abs() < 1e-6 &&
            (currentLng - lng).abs() < 1e-6) {
          return;
        }
        ref.read(reportFormProvider.notifier).setCoordinates(lat, lng);
      });
    });
  }

  @override
  void dispose() {
    _formSubscription?.close();
    _locationSubscription?.close();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, type: FileType.media);
    if (result != null) {
      final paths = result.files
          .where((file) => file.path != null)
          .map((file) => file.path!)
          .toList();
      ref.read(reportFormProvider.notifier).setMedia(paths);
    }
  }

  AlertSeverity _mapSeverity(ReportPriority priority) {
    switch (priority) {
      case ReportPriority.low:
        return AlertSeverity.low;
      case ReportPriority.normal:
        return AlertSeverity.medium;
      case ReportPriority.high:
        return AlertSeverity.high;
      case ReportPriority.critical:
        return AlertSeverity.critical;
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    var formState = ref.read(reportFormProvider);
    if (!formState.agreedToTerms) {
      showErrorToast(
          context, 'You must agree to the warning before submitting.'.tr());
      return;
    }

    if (!formState.useCurrentLocation &&
        (formState.selectedLat == null || formState.selectedLng == null)) {
      LatLng? initial;
      if (formState.selectedLat != null && formState.selectedLng != null) {
        initial = LatLng(formState.selectedLat!, formState.selectedLng!);
      } else {
        try {
          final location = await ref.read(currentLocationProvider.future);
          final lat = location?.latitude;
          final lng = location?.longitude;
          if (lat != null && lng != null) {
            initial = LatLng(lat, lng);
          }
        } catch (_) {
          // ignore; user will choose manually
        }
      }

      final picked = await context.showLocationPicker(
        initialLocation: initial,
      );
      if (picked == null) {
        showErrorToast(
          context,
          'Select a location on the map before submitting.'.tr(),
        );
        return;
      }
      ref
          .read(reportFormProvider.notifier)
          .setCoordinates(picked.latitude, picked.longitude);
      formState = ref.read(reportFormProvider);
    }

    if (formState.useCurrentLocation) {
      try {
        final location = await ref.read(currentLocationProvider.future);
        final lat = location?.latitude;
        final lng = location?.longitude;
        if (lat == null || lng == null) {
          showErrorToast(
            context,
            'Turn on location services to submit a report.'.tr(),
          );
          return;
        }
        ref.read(reportFormProvider.notifier).setCoordinates(lat, lng);
        formState = ref.read(reportFormProvider);
      } catch (_) {
        showErrorToast(
          context,
          'Turn on location services to submit a report.'.tr(),
        );
        return;
      }
    }

    final confirm = await showConfirmDialog(
      context: context,
      title: 'Before you submit'.tr(),
      message:
          'Government reports share your name, ID, and phone. False or misleading reports may result in legal action and 3-month account suspension. Proceed?'
              .tr(),
      confirmLabel: 'I understand'.tr(),
    );

    if (confirm != true) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final submittedForm = formState;

    try {
      final result = await ref.read(reportFormProvider.notifier).submit(ref);

      await result.when<Future<void>>(
        success: (report) async {
          if (!mounted) return;

          ref.read(mapReportsControllerProvider.notifier).addOrReplace(report);
          ref.invalidate(mapReportsControllerProvider);
          ref.invalidate(nearbyReportsProvider);

          final audience = submittedForm.notifyScope ?? submittedForm.audience;
          final severity =
              _mapSeverity(submittedForm.priority ?? ReportPriority.normal);
          const radiusMeters = 500;

          String? alertError;

          if (audience != ReportAudience.government) {
            final alertsService = ref.read(supabaseAlertsServiceProvider);
            final alertResult = await alertsService.createFromReport(
              reportId: report.id,
              title: _humanize(report.subcategory.isNotEmpty
                  ? report.subcategory
                  : report.categoryName),
              description: report.description.isNotEmpty
                  ? report.description
                  : 'A new incident was reported nearby.'.tr(),
              category: report.categoryName,
              subcategory: report.subcategory.isNotEmpty
                  ? report.subcategory
                  : report.categoryName,
              latitude: report.lat,
              longitude: report.lng,
              radiusMeters: radiusMeters,
              severity: severity.name,
              notifyScope: audience.name,
            );
            alertResult.when(
              success: (_) {},
              failure: (msg) => alertError = msg,
            );
          }

          final successMessage = audience == ReportAudience.government
              ? 'Report submitted. Officials will review shortly.'.tr()
              : 'Report submitted and nearby users have been alerted.'.tr();

          if (!mounted) return;
          showSuccessToast(context, successMessage);

          if (alertError != null && mounted) {
            final failureMessage = 'Failed to notify nearby users.'.tr();
            showErrorToast(context, '$failureMessage ${alertError!}');
          }
        },
        failure: (message) async {
          if (!mounted) return;
          showErrorToast(context, message);
        },
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    if (authState.isPendingVerification) {
      return const _PendingVerificationLock();
    }

    final formState = ref.watch(reportFormProvider);
    final categoriesAsync = ref.watch(reportCategoriesProvider);
    final subcategories = ref.watch(reportSubcategoriesProvider);
    final currentLocationAsync = ref.watch(currentLocationProvider);

    LatLng? currentLatLng;
    currentLocationAsync.whenOrNull(data: (location) {
      final lat = location?.latitude;
      final lng = location?.longitude;
      if (lat != null && lng != null) {
        currentLatLng = LatLng(lat, lng);
      }
    });

    final effectiveAudience = formState.notifyScope ?? formState.audience;

    final bottomPadding = MediaQuery.of(context).padding.bottom + 24;

    return Scaffold(
      appBar: AppBar(title: Text('Submit a report'.tr())),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, 24, 24, bottomPadding),
                children: [
                  categoriesAsync.when(
                    data: (categories) => DropdownButtonFormField<int>(
                      decoration: InputDecoration(labelText: 'Category'.tr()),
                      isExpanded: true,
                      value: formState.categoryId,
                      items: [
                        for (final category in categories)
                          DropdownMenuItem<int>(
                            value: category.id,
                            child: Text(_humanize(category.name).tr()),
                          ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          ref
                              .read(reportFormProvider.notifier)
                              .setCategory(null);
                          return;
                        }
                        final selected = categories
                            .firstWhere((category) => category.id == value);
                        ref
                            .read(reportFormProvider.notifier)
                            .setCategory(selected);
                      },
                      validator: (value) =>
                          value == null ? 'Select a category'.tr() : null,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    decoration: InputDecoration(labelText: 'Sub-category'.tr()),
                    isExpanded: true,
                    value: subcategories
                            .any((sub) => sub.id == formState.subcategoryId)
                        ? formState.subcategoryId
                        : null, // Reset value if it doesn't exist in current subcategories
                    items: subcategories.isEmpty
                        ? const []
                        : [
                            for (final subcategory in subcategories)
                              DropdownMenuItem<int>(
                                value: subcategory.id,
                                child: Text(_humanize(subcategory.name).tr()),
                              ),
                          ],
                    onChanged: subcategories.isEmpty
                        ? null
                        : (value) {
                            if (value == null) {
                              ref
                                  .read(reportFormProvider.notifier)
                                  .setSubcategory(null);
                              return;
                            }
                            final selected = subcategories.firstWhere(
                                (subcategory) => subcategory.id == value);
                            ref
                                .read(reportFormProvider.notifier)
                                .setSubcategory(selected);
                          },
                    validator: (value) => subcategories.isEmpty
                        ? 'Select category first'.tr()
                        : (value == null ? 'Select a sub-category'.tr() : null),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Description'.tr(),
                      hintText: 'Describe what is happening...'.tr(),
                    ),
                    onChanged: (value) => ref
                        .read(reportFormProvider.notifier)
                        .setDescription(value),
                    validator: (value) => null, // Description is optional
                  ),
                  const SizedBox(height: 16),
                  _AudienceSelector(selected: formState.audience),
                  if (effectiveAudience == ReportAudience.people) ...[
                    const SizedBox(height: 16),
                    _AudienceGenderSelector(
                      selected: formState.peopleGender,
                    ),
                  ],
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.photo_library_rounded),
                    title: Text('Add photos or videos'.tr()),
                    subtitle: Text(
                      formState.mediaPaths.isEmpty
                          ? 'Optional evidence helps responders assess severity.'
                              .tr()
                          : context.l10n.formatWithCount(
                              '{count} attachment(s) selected',
                              formState.mediaPaths.length,
                            ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_a_photo_rounded),
                      onPressed: _pickMedia,
                    ),
                    onTap: _pickMedia,
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    title: Text('Use current location'.tr()),
                    subtitle: Text('Disable to drop a manual pin later.'.tr()),
                    value: formState.useCurrentLocation,
                    onChanged: (value) async {
                      final notifier = ref.read(reportFormProvider.notifier);
                      if (value) {
                        notifier.setUseCurrentLocation(true);
                        try {
                          final location =
                              await ref.read(currentLocationProvider.future);
                          final lat = location?.latitude;
                          final lng = location?.longitude;
                          if (lat != null && lng != null) {
                            notifier.setCoordinates(lat, lng);
                          }
                        } catch (_) {
                          // ignore when location services are unavailable
                        }
                        return;
                      }

                      final currentForm = ref.read(reportFormProvider);
                      LatLng? initial;
                      if (currentForm.selectedLat != null &&
                          currentForm.selectedLng != null) {
                        initial = LatLng(
                          currentForm.selectedLat!,
                          currentForm.selectedLng!,
                        );
                      } else {
                        try {
                          final location =
                              await ref.read(currentLocationProvider.future);
                          final lat = location?.latitude;
                          final lng = location?.longitude;
                          if (lat != null && lng != null) {
                            initial = LatLng(lat, lng);
                          }
                        } catch (_) {
                          // ignore; use default map center
                        }
                      }

                      final picked = await context.showLocationPicker(
                        initialLocation: initial,
                      );
                      if (picked != null) {
                        notifier.setUseCurrentLocation(false);
                        notifier.setCoordinates(
                          picked.latitude,
                          picked.longitude,
                        );
                        return;
                      }

                      notifier.setUseCurrentLocation(true);
                      try {
                        final location =
                            await ref.read(currentLocationProvider.future);
                        final lat = location?.latitude;
                        final lng = location?.longitude;
                        if (lat != null && lng != null) {
                          notifier.setCoordinates(lat, lng);
                        }
                      } catch (_) {
                        // ignore when GPS is unavailable
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  if (formState.useCurrentLocation)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.my_location_outlined),
                      title: Text('Current location'.tr()),
                      subtitle: Text(
                        formState.selectedLat != null &&
                                formState.selectedLng != null
                            ? _formatCoordinates(
                                formState.selectedLat!,
                                formState.selectedLng!,
                              )
                            : 'Waiting for GPS fix...'.tr(),
                      ),
                    )
                  else ...[
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.push_pin_outlined),
                      title: Text(
                        formState.selectedLat != null &&
                                formState.selectedLng != null
                            ? 'Location selected'.tr()
                            : 'Select location on map'.tr(),
                      ),
                      subtitle: Text(
                        formState.selectedLat != null &&
                                formState.selectedLng != null
                            ? _formatCoordinates(
                                formState.selectedLat!,
                                formState.selectedLng!,
                              )
                            : 'Tap to drop a pin anywhere.'.tr(),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final initial = formState.selectedLat != null &&
                                formState.selectedLng != null
                            ? LatLng(
                                formState.selectedLat!,
                                formState.selectedLng!,
                              )
                            : currentLatLng ?? const LatLng(24.7136, 46.6753);
                        final picked = await context.showLocationPicker(
                          initialLocation: initial,
                        );
                        if (picked != null) {
                          ref
                              .read(reportFormProvider.notifier)
                              .setUseCurrentLocation(false);
                          ref.read(reportFormProvider.notifier).setCoordinates(
                                picked.latitude,
                                picked.longitude,
                              );
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          final notifier =
                              ref.read(reportFormProvider.notifier);
                          notifier.setUseCurrentLocation(true);
                          ref
                              .read(currentLocationProvider.future)
                              .then((location) {
                            final lat = location?.latitude;
                            final lng = location?.longitude;
                            if (lat != null && lng != null) {
                              notifier.setCoordinates(lat, lng);
                            }
                          });
                        },
                        child: Text('Use current location instead'.tr()),
                      ),
                    ),
                  ],
                  CheckboxListTile(
                    title:
                        Text('I agree to the SpotnSend reporting policy'.tr()),
                    subtitle: Text(
                      'False reports can lead to legal consequences and a 3-month ban.'
                          .tr(),
                    ),
                    value: formState.agreedToTerms,
                    onChanged: (value) => ref
                        .read(reportFormProvider.notifier)
                        .setAgreedToTerms(value ?? false),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    label: 'Continue'.tr(),
                    onPressed: _isSubmitting ? null : _submit,
                    loading: _isSubmitting,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudienceSelector extends ConsumerWidget {
  const _AudienceSelector({required this.selected});

  final ReportAudience selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = {
      ReportAudience.people: 'People'.tr(),
      ReportAudience.government: 'Government'.tr(),
      ReportAudience.both: 'Both'.tr(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Who should be notified?'.tr()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: entry.key == selected,
                onSelected: (_) => ref
                    .read(reportFormProvider.notifier)
                    .setAudience(entry.key),
              ),
          ],
        ),
      ],
    );
  }
}

class _AudienceGenderSelector extends ConsumerWidget {
  const _AudienceGenderSelector({required this.selected});

  final ReportAudienceGender? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = {
      ReportAudienceGender.male: 'Men'.tr(),
      ReportAudienceGender.female: 'Women'.tr(),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Notify which group?'.tr()),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: [
            for (final entry in options.entries)
              ChoiceChip(
                label: Text(entry.value),
                selected: selected == entry.key,
                onSelected: (isSelected) =>
                    ref.read(reportFormProvider.notifier).setPeopleGender(
                          isSelected ? entry.key : null,
                        ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Choose who should receive alerts when notifying people.'.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _PendingVerificationLock extends StatelessWidget {
  const _PendingVerificationLock();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, size: 72),
              const SizedBox(height: 24),
              Text(
                'Verification Required'.tr(),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(
                'Reporting is locked until your account has been verified. You can still browse live map updates and notifications.'
                    .tr(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              AppButton(
                label: 'Review account status'.tr(),
                onPressed: () => context.go(RoutePaths.homeAccount),
                variant: ButtonVariant.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
