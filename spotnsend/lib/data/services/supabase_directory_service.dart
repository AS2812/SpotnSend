import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:spotnsend/data/models/authority_models.dart';
import 'package:spotnsend/main.dart';

final supabaseDirectoryServiceProvider =
    Provider<SupabaseDirectoryService>((ref) {
  return SupabaseDirectoryService(supabase);
});

class SupabaseDirectoryService {
  SupabaseDirectoryService(this._client);

  final SupabaseClient _client;

  Future<List<AuthorityContact>> findNearby({
    required double lat,
    required double lng,
    double radiusKm = 50,
    Set<int>? categoryIds,
    int limit = 20,
  }) async {
    final params = <String, dynamic>{
      'p_latitude': lat,
      'p_longitude': lng,
      'p_radius_meters': (radiusKm * 1000).round(),
      'p_limit': limit,
      if (categoryIds != null && categoryIds.isNotEmpty)
        'p_category_ids': categoryIds.toList(),
    };

    final result = await _client.rpc('find_authorities_nearby', params: params);
    final rows = (result is List) ? result : const <dynamic>[];

    return rows
        .whereType<Map<String, dynamic>>()
        .map(AuthorityContact.fromJson)
        .toList(growable: false);
  }
}
