import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/supabase_reports_service.dart';
import 'package:spotnsend/data/services/supabase_user_service.dart';
import 'package:spotnsend/features/home/account/providers/account_providers.dart';

/// =============== Data sources ===============

final reportCategoriesProvider =
    FutureProvider<List<ReportCategory>>((ref) async {
  final svc = ref.watch(supabaseReportServiceProvider);
  return svc.loadCategories();
});

/// Currently selected category (derived from form state + categories)
final selectedCategoryProvider = Provider<ReportCategory?>((ref) {
  final form = ref.watch(reportFormProvider);
  final cats = ref.watch(reportCategoriesProvider);

  return cats.maybeWhen(
    data: (list) {
      if (form.categoryId == null) return null;
      try {
        return list.firstWhere((c) => c.id == form.categoryId);
      } catch (_) {
        return null;
      }
    },
    orElse: () => null,
  );
});

/// Subcategories for the selected category
final reportSubcategoriesProvider = Provider<List<ReportSubcategory>>((ref) {
  final selected = ref.watch(selectedCategoryProvider);
  return selected?.subcategories ?? const <ReportSubcategory>[];
});

/// =============== Form state ===============

final reportFormProvider =
    NotifierProvider<ReportFormNotifier, ReportFormData>(() {
  return ReportFormNotifier();
});

class ReportFormNotifier extends Notifier<ReportFormData> {
  @override
  ReportFormData build() => ReportFormData();

  void setCategory(ReportCategory? category) {
    state = state.copyWith(
      categoryId: category?.id,
      categoryName: category?.name,
      categorySlug: category?.slug,
      // reset subcategory when category changes
      subcategoryId: null,
      subcategoryName: null,
    );
  }

  void setSubcategory(ReportSubcategory? sub) {
    state = state.copyWith(
      subcategoryId: sub?.id,
      subcategoryName: sub?.name,
    );
  }

  void setDescription(String value) {
    state = state.copyWith(description: value);
  }

  void setAudience(ReportAudience value) {
    final adjustedGender =
        value == ReportAudience.people ? state.peopleGender : null;
    state = state.copyWith(
      audience: value,
      peopleGender: value == ReportAudience.people
          ? (adjustedGender ?? ReportAudienceGender.both)
          : null,
    );
  }

  void setUseCurrentLocation(bool value) {
    state = state.copyWith(
      useCurrentLocation: value,
      selectedLat: value ? null : state.selectedLat,
      selectedLng: value ? null : state.selectedLng,
    );
  }

  void setCoordinates(double lat, double lng) {
    state = state.copyWith(selectedLat: lat, selectedLng: lng);
  }

  void setAgreedToTerms(bool value) {
    state = state.copyWith(agreedToTerms: value);
  }

  void setMedia(List<String> paths) {
    state = state.copyWith(mediaPaths: paths);
  }

  void setPeopleGender(ReportAudienceGender? value) {
    state = state.copyWith(peopleGender: value);
  }

  void reset() => state = ReportFormData();

  /// Convenience: submit the *current* form via the controller.
  Future<Result<Report>> submit(WidgetRef ref) async {
    final user = await ref.read(accountUserProvider.future);
    if (user == null) {
      return const Failure('You must be logged in to submit a report.');
    }
    final ctrl = ref.read(reportControllerProvider);
    final res = await ctrl.submit(state, user);
    return res.when(
      success: (report) {
        reset();
        return Success(report);
      },
      failure: Failure.new,
    );
  }
}

/// =============== Submit controller ===============

final reportControllerProvider = Provider<ReportController>((ref) {
  final svc = ref.read(supabaseReportServiceProvider);
  return ReportController(ref, svc);
});

class ReportController {
  ReportController(this.ref, this._svc);
  final Ref ref;
  final SupabaseReportService _svc;

  /// Submits a report, refreshes profile counters on success.
  Future<Result<Report>> submit(ReportFormData form, AppUser user) async {
    final res = await _svc.submit(formData: form, user: user);
    return res.when(
      success: (report) {
        // Refresh account counters immediately after a successful submit
        ref.read(supabaseUserServiceProvider).clearCache();
        ref.invalidate(accountUserProvider);
        return Success(report);
      },
      failure: (msg) => Failure(msg),
    );
  }
}
