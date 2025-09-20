import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/user_service.dart';
import 'package:spotnsend/features/auth/providers/auth_providers.dart';

final accountUserProvider = Provider<AppUser?>((ref) => ref.watch(authControllerProvider).user);

final accountSavedSpotsProvider = Provider<List<SavedSpot>>((ref) {
  final user = ref.watch(accountUserProvider);
  return user?.savedSpots ?? const [];
});

final accountControllerProvider = Provider<AccountController>((ref) {
  final userService = ref.watch(userServiceProvider);
  return AccountController(ref: ref, userService: userService);
});

class AccountController {
  AccountController({required this.ref, required this.userService});

  final Ref ref;
  final UserService userService;

  Future<void> refresh() async {
    final user = await userService.me();
    ref.read(authControllerProvider.notifier).updateUser(user);
  }

  Future<Result<AppUser>> updateEmail(String email) async {
    final result = await userService.updateEmail(email);
    result.when(success: (user) => ref.read(authControllerProvider.notifier).updateUser(user), failure: (_) {});
    return result;
  }

  Future<Result<AppUser>> updatePhone(String phone) async {
    final result = await userService.updatePhone(phone);
    result.when(success: (user) => ref.read(authControllerProvider.notifier).updateUser(user), failure: (_) {});
    return result;
  }

  Future<Result<AppUser>> addSavedSpot(String name, double lat, double lng) async {
    final result = await userService.addSavedSpot(name, lat, lng);
    result.when(success: (user) => ref.read(authControllerProvider.notifier).updateUser(user), failure: (_) {});
    return result;
  }

  Future<Result<AppUser>> removeSavedSpot(String id) async {
    final result = await userService.removeSavedSpot(id);
    result.when(success: (user) => ref.read(authControllerProvider.notifier).updateUser(user), failure: (_) {});
    return result;
  }
}



