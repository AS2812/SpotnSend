import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';

final userServiceProvider = Provider<UserService>((ref) {
  return UserService();
});

class UserService {
  AppUser? _currentUser;

  Future<AppUser> me() async {
    await Future<void>.delayed(const Duration(milliseconds: 400));

    _currentUser ??= const AppUser(
      id: 'user-guest',
      name: 'Guest User',
      username: 'guest',
      email: 'guest@spotnsend.com',
      phone: '+966500000000',
      idNumber: '1234567890',
      selfieUrl: '',
      status: VerificationStatus.pending,
      reportsSubmitted: 0,
      feedbackGiven: 0,
      savedSpots: [],
    );

    return _currentUser!;
  }

  void setCurrentUser(AppUser user) {
    _currentUser = user;
  }

  Future<Result<AppUser>> updateEmail(String email) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_currentUser == null) {
      return const Failure('No active user');
    }
    _currentUser = _currentUser!.copyWith(email: email);
    return Success(_currentUser!);
  }

  Future<Result<AppUser>> updatePhone(String phone) async {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (_currentUser == null) {
      return const Failure('No active user');
    }
    _currentUser = _currentUser!.copyWith(phone: phone);
    return Success(_currentUser!);
  }

  Future<Result<AppUser>> addSavedSpot(String name, double lat, double lng) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_currentUser == null) {
      return const Failure('No active user');
    }
    final spot = SavedSpot(
      id: 'spot-',
      name: name,
      lat: lat,
      lng: lng,
    );
    final updatedSpots = List<SavedSpot>.from(_currentUser!.savedSpots)..add(spot);
    _currentUser = _currentUser!.copyWith(savedSpots: updatedSpots);
    return Success(_currentUser!);
  }

  Future<Result<AppUser>> removeSavedSpot(String id) async {
    await Future<void>.delayed(const Duration(milliseconds: 400));
    if (_currentUser == null) {
      return const Failure('No active user');
    }
    final updatedSpots = _currentUser!.savedSpots.where((spot) => spot.id != id).toList();
    _currentUser = _currentUser!.copyWith(savedSpots: updatedSpots);
    return Success(_currentUser!);
  }
}


