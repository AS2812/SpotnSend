import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/report_models.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/report_service.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';

final reportCategoriesProvider = Provider<List<ReportCategory>>((ref) {
  final service = ref.watch(reportServiceProvider);
  return service.categories;
});

final selectedCategoryProvider = Provider<String?>((ref) => ref.watch(reportFormProvider).category);

final reportFormProvider = StateNotifierProvider<ReportFormNotifier, ReportFormData>((ref) {
  return ReportFormNotifier(ref);
});

class ReportFormNotifier extends StateNotifier<ReportFormData> {
  ReportFormNotifier(this.ref) : super(ReportFormData());

  final Ref ref;

  void updateCategory(String? category) {
    state = state.copyWith(categoryName: category, subcategoryId: null, subcategoryName: null);
  }

  void updateSubcategory(String? subcategory) {
    state = state.copyWith(subcategoryName: subcategory);
  }

  void updateDescription(String description) {
    state = state.copyWith(description: description);
  }

  void toggleAudience(ReportAudience audience) {
    state = state.copyWith(audience: audience);
  }

  void setUseCurrentLocation(bool value) {
    state = state.copyWith(useCurrentLocation: value);
  }

  void setSelectedLocation(double lat, double lng) {
    state = state.copyWith(selectedLat: lat, selectedLng: lng);
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
    final reportService = ref.read(reportServiceProvider);
    final authState = ref.read(authControllerProvider);
    final user = authState.user;
    if (user == null) {
      return const Failure('You must be signed in to submit a report');
    }
    final result = await reportService.submit(formData: state, user: user);
    if (result.isSuccess) {
      reset();
    }
    return result;
  }
}

final reportSubcategoriesProvider = Provider<List<String>>((ref) {
  final category = ref.watch(selectedCategoryProvider);
  final categories = ref.watch(reportCategoriesProvider);
  final match = categories.where((element) => element.name == category);
  if (match.isEmpty) {
    return const [];
  }
  return match.first.subcategories.map((item) => item.name).toList();
});





