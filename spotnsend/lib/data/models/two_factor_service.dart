import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'package:spotnsend/main.dart';
import 'package:spotnsend/core/utils/result.dart';

/// Thin wrapper around Supabase MFA TOTP.
/// NOTE: Supabase Flutter exposes `auth.mfa.*`. API surface can vary slightly
/// by SDK version, so this code accesses some fields dynamically.
final twoFactorServiceProvider = Provider<TwoFactorService>((ref) {
  return TwoFactorService(supabase);
});

class EnrollTotp {
  EnrollTotp({required this.factorId, required this.otpauthUri});
  final String factorId; // Save until user enters the 6-digit code
  final String otpauthUri; // Show as QR + text
}

class TwoFactorService {
  TwoFactorService(this._client);
  final sb.SupabaseClient _client;

  /// Start TOTP enrollment, returns a provisioning URI (otpauth://…) + factor id.
  Future<Result<EnrollTotp>> startEnrollTotp() async {
    try {
      // Dart SDK: auth.mfa.enroll(factorType: FactorType.totp)
      final enroll =
          await _client.auth.mfa.enroll(factorType: sb.FactorType.totp);

      // Extract fields defensively (SDK versions may differ a bit).
      final dyn = enroll as dynamic;
      final String factorId = (dyn.id as String?) ?? (dyn['id'] as String);
      String? uri;

      // common shapes: dyn.totp.uri  | dyn['totp']['uri']  | dyn.uri
      if (dyn.totp != null) {
        final totp = dyn.totp;
        if (totp is Map && totp['uri'] is String) uri = totp['uri'] as String;
        if (uri == null) {
          try {
            uri = (totp.uri as String?);
          } catch (_) {}
        }
      }
      uri ??= (dyn.uri as String?);
      if (uri == null) throw StateError('No TOTP URI returned');

      return Success(EnrollTotp(factorId: factorId, otpauthUri: uri));
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Verify the 6-digit code to activate TOTP for this factor id.
  Future<Result<void>> verifyTotp(
      {required String factorId, required String code}) async {
    try {
      // Start a challenge for the enrolled factor, then verify with challengeId + code
      final challenge = await _client.auth.mfa.challenge(factorId: factorId);
      final dyn = challenge as dynamic;
      final String challengeId = (dyn.id as String?) ?? (dyn['id'] as String);

      await _client.auth.mfa
          .verify(factorId: factorId, challengeId: challengeId, code: code);

      // Optional: reflect in your UI flag
      try {
        await _client.rpc('update_two_factor', params: {'p_enabled': true});
      } catch (_) {}
      return const Success(null);
    } on sb.AuthException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Disable all TOTP factors for the current user.
  Future<Result<void>> disableTotp() async {
    try {
      final listed = await _client.auth.mfa.listFactors();
      final dyn = listed as dynamic;
      final List factors =
          (dyn.totp as List?) ?? (dyn['totp'] as List?) ?? const [];

      for (final f in factors) {
        final id = (f as dynamic).id as String? ?? f['id'] as String?;
        if (id != null) {
          // Some SDK versions take positional argument
          await _client.auth.mfa.unenroll(id);
        }
      }
      try {
        await _client.rpc('update_two_factor', params: {'p_enabled': false});
      } catch (_) {}
      return const Success(null);
    } on sb.AuthException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure(e.toString());
    }
  }

  /// Is there any active TOTP factor?
  Future<bool> isEnabled() async {
    try {
      final listed = await _client.auth.mfa.listFactors();
      final dyn = listed as dynamic;
      final List factors =
          (dyn.totp as List?) ?? (dyn['totp'] as List?) ?? const [];
      return factors.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
