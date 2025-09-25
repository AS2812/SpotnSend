import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../main.dart';
import '../utils/result.dart';

final connectivityServiceProvider = Provider<ConnectivityService>((ref) {
  return ConnectivityService(supabase);
});

/// Service that handles database connectivity issues and retries
class ConnectivityService {
  ConnectivityService(this._client);
  
  final sb.SupabaseClient _client;
  bool _isConnected = true;
  
  /// Whether the database connection is active
  bool get isConnected => _isConnected;
  
  /// Execute a database operation with retry logic
  Future<Result<T>> executeWithRetry<T>({
    required Future<T> Function() operation,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        final result = await operation();
        _isConnected = true; // Mark as connected on success
        return Success(result);
      } on sb.PostgrestException catch (e) {
        attempts++;
        debugPrint('Database operation failed (attempt $attempts): ${e.message}');
        
        // Only handle schema issues for tables in public schema
        if ((e.message.contains('schema') && e.message.contains('does not exist')) ||
            (e.message.contains('relation') && e.message.contains('does not exist'))) {
          _isConnected = false;
          debugPrint('Schema error detected: ${e.message}');
          return Failure('Schema configuration error: ensure your Supabase references point to the public schema tables and functions.');
        }
        
        // Schema cache errors should trigger a retry
        if (e.code == 'PGRST002') {
          _isConnected = false;
          
          if (attempts >= maxRetries) {
            return Failure('Database connection error: ${e.message}');
          }
          
          // Try to refresh the schema cache
          try {
            await _client.rpc('clear_schema_cache');
          } catch (_) {
            // Ignore error, just delay and retry
          }
          
          await Future.delayed(retryDelay * attempts);
          continue;
        }
        
        return Failure(e.message);
      } catch (e) {
        _isConnected = false;
        attempts++;
        debugPrint('Operation failed (attempt $attempts): $e');
        
        if (attempts >= maxRetries) {
          return Failure('Operation failed: $e');
        }
        
        await Future.delayed(retryDelay * attempts);
      }
    }
    
    return const Failure('Maximum retry attempts reached');
  }
  
  /// Test if the database is reachable
  Future<bool> testConnection() async {
    try {
      // Try to make a simple query
      await _client.from('_schema_version').select('version').limit(1).maybeSingle();
      _isConnected = true;
      return true;
    } catch (e) {
      _isConnected = false;
      debugPrint('Database connection test failed: $e');
      return false;
    }
  }
  
  /// Refresh the connection and schema cache
  Future<bool> refreshConnection() async {
    try {
      // Try to refresh the schema cache
      await _client.rpc('clear_schema_cache');
      return await testConnection();
    } catch (e) {
      debugPrint('Failed to refresh connection: $e');
      return false;
    }
  }
}
