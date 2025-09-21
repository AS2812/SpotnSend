import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  Future<Result<AppUser>> updatePhone(String phoneInput) async {
    final parts = _parsePhone(phoneInput);
    final result = await userService.updatePhone(
      countryCode: parts['countryCode']!,
      phone: parts['phone']!,
    );
    result.when(success: (user) => ref.read(authControllerProvider.notifier).updateUser(user), failure: (_) {});
    return result;
  }

  Future<Result<AppUser>> addSavedSpot(String name, double lat, double lng) async {
    final result = await userService.addSavedSpot(name: name, lat: lat, lng: lng);
    if (result is Success<List<SavedSpot>>) {
      final user = await userService.refreshCachedUser();
      ref.read(authControllerProvider.notifier).updateUser(user);
      return Success(user);
    }
    if (result is Failure<List<SavedSpot>>) {
      return Failure(result.message);
    }
    return const Failure<AppUser>('Unable to update saved spots.');
  }

  Future<Result<AppUser>> removeSavedSpot(String id) async {
    final result = await userService.removeSavedSpot(id);
    if (result is Success<List<SavedSpot>>) {
      final user = await userService.refreshCachedUser();
      ref.read(authControllerProvider.notifier).updateUser(user);
      return Success(user);
    }
    if (result is Failure<List<SavedSpot>>) {
      return Failure(result.message);
    }
    return const Failure<AppUser>('Unable to update saved spots.');
  }

  Map<String, String> _parsePhone(String input) {
    final trimmed = input.trim();
    final match = RegExp(r'^\+?(\d{1,4})\s*(.*)$').firstMatch(trimmed);
    if (match == null) {
      final digitsOnly = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      return {'countryCode': '+966', 'phone': digitsOnly};
    }
    final code = match.group(1)!;
    final remainder = match.group(2)!.replaceAll(RegExp(r'[^0-9]'), '');
    final phone = remainder.isEmpty ? trimmed.replaceAll(RegExp(r'[^0-9]'), '') : remainder;
    return {'countryCode': '+$code', 'phone': phone};
  }
}

