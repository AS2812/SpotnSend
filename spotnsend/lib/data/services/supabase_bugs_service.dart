import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/core/utils/result.dart';
import 'package:spotnsend/main.dart';

final supabaseBugsServiceProvider = Provider<SupabaseBugsService>((ref) {
  return SupabaseBugsService(supabase);
});

class SupabaseBugsService {
  SupabaseBugsService(this._client);
  final SupabaseClient _client;

  SupabaseQueryBuilder _bugs() =>
      _client.schema('civic_app').from('bug_reports');

  /// Create a bug report. We resolve the numeric civic_app.users.user_id via RPC
  /// so we never try to insert the Supabase UUID (type mismatch).
  Future<Result<void>> submit({
    required String title,
    required String description,
    required String severity, // "low" | "medium" | "high" | "critical"
  }) async {
    try {
      int? userId;
      try {
        final r = await _client.rpc('civic_app.current_user_id');
        if (r is int) userId = r;
        if (r is num) userId = r.toInt();
      } catch (_) {
        // If the RPC isn’t available or not granted, we’ll insert without user_id
        // (see SQL below to set DEFAULT current_user_id()).
      }

      final payload = <String, dynamic>{
        if (userId != null) 'user_id': userId, // BIGINT
        'title': title,
        'description':
            '[${severity.toUpperCase()}]\n$description', // keep severity tag in body
      };

      await _bugs().insert(payload);
      return const Success(null);
    } on PostgrestException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }
}
