import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/data/models/user_models.dart';
import 'package:spotnsend/main.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final supabaseUserServiceProvider = Provider<SupabaseUserService>((ref) {
  return SupabaseUserService(supabase);
});

class SupabaseUserService {
  SupabaseUserService(this._client);

  final SupabaseClient _client;
  AppUser? _cachedUser;

  AppUser? get cachedUser => _cachedUser;

  Future<AppUser> me() async {
    if (_cachedUser != null) return _cachedUser!;
    return fetchProfile(forceRefresh: true);
  }

  Future<AppUser> fetchProfile({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedUser != null) return _cachedUser!;

    final result = await _callRpc('profile_me');
    final payload = _unwrapSingleRow(result);

    if (payload == null) {
      throw const PostgrestException(message: 'No profile data found');
    }

    final enriched = await _injectSavedSpots(payload);
    final user = AppUser.fromJson(enriched);
    _cachedUser = user;
    return user;
  }

  Future<Result<AppUser>> updateEmail(String email) async {
    try {
      final result = await _callRpc('update_profile_email', params: {
        'p_email': email,
      });
      final payload = _unwrapSingleRow(result);
      if (payload == null) {
        return const Failure('No profile data returned');
      }

      final enriched = await _injectSavedSpots(payload);
      final user = AppUser.fromJson(enriched);
      _cachedUser = user;
      return Success(user);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return const Failure('Unexpected error occurred.');
    }
  }

  Future<Result<AppUser>> updatePhone({
    required String countryCode,
    required String phone,
  }) async {
    try {
      final result = await _callRpc('update_profile_phone', params: {
        'p_country': countryCode,
        'p_number': phone,
      });
      final payload = _unwrapSingleRow(result);
      if (payload == null) {
        return const Failure('No profile data returned');
      }

      final enriched = await _injectSavedSpots(payload);
      final user = AppUser.fromJson(enriched);
      _cachedUser = user;
      return Success(user);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return const Failure('Unexpected error occurred.');
    }
  }

  /// RLS scopes rows to the current user; no need to pass user_id.
  Future<List<SavedSpot>> listSavedSpots() async {
    final rows = await _client
        .schema('civic_app')
        .from('favorite_spots')
        .select()
        .order('created_at', ascending: false) as List<dynamic>;

    return rows
        .whereType<Map<String, dynamic>>()
        .map(SavedSpot.fromJson)
        .toList();
  }

  /// Insert without user_id (DEFAULT civic_app.current_user_id() handles it).
  Future<Result<List<SavedSpot>>> addSavedSpot({
    required String name,
    required double lat,
    required double lng,
    double? radiusMeters,
  }) async {
    try {
      await _client.schema('civic_app').from('favorite_spots').insert({
        'name': name,
        'latitude': lat,
        'longitude': lng,
        if (radiusMeters != null) 'radius_meters': radiusMeters.round(),
      });
      final spots = await listSavedSpots();
      if (_cachedUser != null) {
        _cachedUser = _cachedUser!.copyWith(savedSpots: spots);
      }
      return Success(spots);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (_) {
      return const Failure('Unexpected error occurred.');
    }
  }

  /// Delete by id only; RLS prevents deleting others’ rows.
  Future<Result<List<SavedSpot>>> removeSavedSpot(String id) async {
    try {
      await _client
          .schema('civic_app')
          .from('favorite_spots')
          .delete()
          .eq('favorite_spot_id', id);

      final spots = await listSavedSpots();
      if (_cachedUser != null) {
        _cachedUser = _cachedUser!.copyWith(savedSpots: spots);
      }
      return Success(spots);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (_) {
      return const Failure('Unexpected error occurred.');
    }
  }

  void clearCache() {
    _cachedUser = null;
  }

  Future<dynamic> _callRpc(String fn,
      {Map<String, dynamic>? params}) async {
    try {
      return await _client.rpc('civic_app.$fn', params: params);
    } on PostgrestException catch (e) {
      final message = e.message.toLowerCase();
      if (message.contains('function') && message.contains('does not exist')) {
        if (kDebugMode) {
          debugPrint(
              'RPC civic_app.$fn not found, retrying without schema prefix');
        }
        return _client.rpc(fn, params: params);
      }
      rethrow;
    }
  }

  Map<String, dynamic>? _unwrapSingleRow(dynamic result) {
    if (result is Map<String, dynamic>) return result;
    if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map<String, dynamic>) return first;
    }
    return null;
  }

  Future<Map<String, dynamic>> _injectSavedSpots(
      Map<String, dynamic> payload) async {
    final spots = await listSavedSpots();
    return {
      ...payload,
      'favoriteSpots': spots.map((e) => e.toJson()).toList(),
    };
  }
}

extension PasswordApi on SupabaseUserService {
  /// Re-authenticate with the current password, then update to [newPassword].
  Future<Result<void>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final user = _client.auth.currentUser;
      final email = user?.email;
      if (email == null) {
        return const Failure('Not signed in.');
      }

      // 1) Verify the current password
      await _client.auth
          .signInWithPassword(email: email, password: currentPassword);

      // 2) Update to the new password
      await _client.auth.updateUser(
        sb.UserAttributes(password: newPassword),
      );

      // Optional: clear local cache if you keep any auth-derived state
      // clearCache();

      return const Success(null);
    } on sb.AuthException catch (e) {
      // Wrong current password, weak password, etc.
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
