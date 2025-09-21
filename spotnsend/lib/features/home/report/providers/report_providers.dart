import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/services/report_service.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';

final reportCategoriesProvider = Provider<List<ReportCategory>>((ref) {
  final service = ref.watch(reportServiceProvider);
  return service.categories;
});

final selectedCategoryProvider = Provider<ReportCategory?>((ref) {
  final categories = ref.watch(reportCategoriesProvider);
  if (categories.isEmpty) {
    return null;
  }
  return categories.first;
});

final reportSubcategoriesProvider = Provider<List<ReportSubcategory>>((ref) {
  final selectedCategory = ref.watch(selectedCategoryProvider);
  return selectedCategory?.subcategories ?? [];
});

final reportFormProvider =
    NotifierProvider<ReportFormNotifier, ReportFormData>(() {
  return ReportFormNotifier();
});

class ReportFormNotifier extends Notifier<ReportFormData> {
  @override
  ReportFormData build() {
    return ReportFormData();
  }

  void updateCategory(ReportCategory? category) {
    state = state.copyWith(
      categoryId: category?.id,
      categoryName: category?.name,
    );
  }

  void updateSubcategory(ReportSubcategory? subcategory) {
    state = state.copyWith(
      subcategoryId: subcategory?.id,
      subcategoryName: subcategory?.name,
    );
  }

  void updateLocation(double? lat, double? lng) {
    state = state.copyWith(
      selectedLat: lat,
      selectedLng: lng,
    );
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setAudience(ReportAudience audience) {
    state = state.copyWith(audience: audience);
  }

  void toggleAudience(ReportAudience audience) {
    state = state.copyWith(audience: audience);
  }

  void setCurrentLocation(bool value) {
    state = state.copyWith(useCurrentLocation: value);
  }

  void setUseCurrentLocation(bool value) {
    state = state.copyWith(useCurrentLocation: value);
  }

  void setCoordinates(double lat, double lng) {
    state = state.copyWith(selectedLat: lat, selectedLng: lng);
  }

  void setAgreedToTerms(bool agreed) {
    state = state.copyWith(agreedToTerms: agreed);
  }

  void setAgreement(bool agreed) {
    state = state.copyWith(agreedToTerms: agreed);
  }

  void setMedia(List<String> mediaPaths) {
    state = state.copyWith(mediaPaths: mediaPaths);
  }

  void reset() {
    state = ReportFormData();
  }

  Future<Result<Report>> submit() async {
    final authState = ref.read(authControllerProvider);
    final user = authState.user;
    if (user == null)
      return const Failure('You must be logged in to submit a report.');

    final reportService = ref.read(reportServiceProvider);
    final result = await reportService.submit(formData: state, user: user);
    if (result is Success) {
      reset();
    }
    return result;
  }
}
