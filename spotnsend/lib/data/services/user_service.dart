<<<<<<< HEAD
import 'package:dio/dio.dart';
=======
<<<<<<< HEAD
﻿import 'dart:async';
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


=======
﻿import 'package:dio/dio.dart';
>>>>>>> 12476f4562425887d3e031348f0a8cc3344211f0
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/data/services/api_client.dart';

final userServiceProvider = Provider<UserService>((ref) {
  final client = ref.watch(apiClientProvider);
  return UserService(client.dio);
});

class UserService {
  UserService(this._dio);

  final Dio _dio;
  AppUser? _cachedUser;

  Future<AppUser> me() async {
    if (_cachedUser != null) {
      return _cachedUser!;
    }
    return fetchProfile(forceRefresh: true);
  }

  Future<AppUser> fetchProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null) {
      return _cachedUser!;
    }

    final response = await _dio.get('/users/profile');
    final data = response.data as Map<String, dynamic>;
    final profile = (data['profile'] ?? data) as Map<String, dynamic>;
    final stats = data['stats'] as Map<String, dynamic>?;

    if (stats != null) {
      profile['reports_count'] = stats['reports_count'];
      profile['feedback_count'] = stats['feedback_count'];
    }

    final user = AppUser.fromJson(profile);
    _cachedUser = user;
    return user;
  }

  Future<Result<AppUser>> updateEmail(String email) async {
    try {
      final response = await _dio.patch('/users/profile', data: {
        'email': email,
      });
      final data = response.data as Map<String, dynamic>;
      final user = AppUser.fromJson(data);
      _cachedUser = user;
      return Success(user);
    } on DioException catch (error) {
      return Failure(_extractMessage(error));
    }
  }

  Future<Result<AppUser>> updatePhone({required String countryCode, required String phone}) async {
    try {
      final response = await _dio.patch('/users/profile', data: {
        'phoneCountryCode': countryCode,
        'phoneNumber': phone,
      });
      final data = response.data as Map<String, dynamic>;
      final user = AppUser.fromJson(data);
      _cachedUser = user;
      return Success(user);
    } on DioException catch (error) {
      return Failure(_extractMessage(error));
    }
  }

  Future<List<SavedSpot>> listSavedSpots() async {
    final response = await _dio.get('/users/favorite-spots');
    final data = response.data as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map(SavedSpot.fromJson)
        .toList();
  }

  Future<Result<List<SavedSpot>>> addSavedSpot({
    required String name,
    required double lat,
    required double lng,
    double? radiusMeters,
  }) async {
    try {
      final response = await _dio.post('/users/favorite-spots', data: {
        'name': name,
        'latitude': lat,
        'longitude': lng,
        if (radiusMeters != null) 'radiusMeters': radiusMeters,
      });
      final spot = SavedSpot.fromJson(response.data as Map<String, dynamic>);
      if (_cachedUser != null) {
        final updated = List<SavedSpot>.from(_cachedUser!.savedSpots)..add(spot);
        _cachedUser = _cachedUser!.copyWith(savedSpots: updated);
      }
      final spots = await listSavedSpots();
      return Success(spots);
    } on DioException catch (error) {
      return Failure(_extractMessage(error));
    }
  }

  Future<Result<List<SavedSpot>>> removeSavedSpot(String id) async {
    try {
      await _dio.delete('/users/favorite-spots/');
      if (_cachedUser != null) {
        final updated = _cachedUser!.savedSpots.where((spot) => spot.id != id).toList();
        _cachedUser = _cachedUser!.copyWith(savedSpots: updated);
      }
      final spots = await listSavedSpots();
      return Success(spots);
    } on DioException catch (error) {
      return Failure(_extractMessage(error));
    }
  }

  void cacheUser(AppUser user) {
    _cachedUser = user;
  }

  void clearCache() {
    _cachedUser = null;
  }

  Future<AppUser> refreshCachedUser() async {
    _cachedUser = await fetchProfile(forceRefresh: true);
    return _cachedUser!;
  }

  String _extractMessage(DioException error) {
    final responseData = error.response?.data;
    if (responseData is Map<String, dynamic>) {
      return responseData['message']?.toString() ?? responseData['error']?.toString() ?? 'Unexpected error occurred.';
    }
    return error.message ?? 'Unexpected error occurred.';
  }
}
<<<<<<< HEAD


=======
>>>>>>> 3f1d5939b69ebb53fd7acf28c8557f4585162768
>>>>>>> 12476f4562425887d3e031348f0a8cc3344211f0
