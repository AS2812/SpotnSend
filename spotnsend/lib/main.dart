import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'app.dart';

// Single shared Supabase client
late final sb.SupabaseClient supabase;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load .env if present (safe to skip in prod)
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // ignore missing .env
  }

  final supabaseUrl =
      dotenv.env['SUPABASE_URL'] ?? 'https://kinybiydycmiddueiaiv.supabase.co';
  final supabaseAnonKey = dotenv.env['SUPABASE_PUBLISHABLE_KEY'] ??
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtpbnliaXlkeWNtaWRkdWVpYWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTg0OTE4NDQsImV4cCI6MjA3NDA2Nzg0NH0.gxXXw7v40ZSp-NwT8TaTAQzEYkltUdgv9EC9-XtSTPM';

  // Init Supabase
  await sb.Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    debug: kDebugMode,
  );

  supabase = sb.Supabase.instance.client;

  // Ensure a civic profile exists as soon as the user is (or becomes) authenticated
  _wireAuthProfileBootstrap();

  runApp(const ProviderScope(child: SpotnSendApp()));
}

/// Listens for auth changes and calls the ensure_profile RPC so a civic_app.users row always exists.
/// This removes the need for any "Reload profile" button in the UI.
void _wireAuthProfileBootstrap() {
  // If already signed in (hot restart / app resume), ensure once
  if (supabase.auth.currentSession != null) {
    _ensureProfileSilently();
  }

  // On sign-in or token refresh, ensure again (covers fresh logins & session refresh)
  supabase.auth.onAuthStateChange.listen((data) {
    final event = data.event;
    if (event == sb.AuthChangeEvent.signedIn ||
        event == sb.AuthChangeEvent.tokenRefreshed) {
      _ensureProfileSilently();
    }
  });
}

/// Calls public.ensure_profile(username, full_name, email) and ignores errors in production.
/// Your RLS/SECURITY DEFINER function will create/update the row deterministically.
Future<void> _ensureProfileSilently() async {
  final u = supabase.auth.currentUser;
  if (u == null) return;

  try {
    try {
      await supabase.rpc('civic_app.ensure_profile', params: {
        'p_username': (u.userMetadata?['username'] as String?) ?? '',
        'p_full_name': (u.userMetadata?['full_name'] as String?) ?? u.email ?? '',
        'p_email': u.email ?? '',
      });
      return;
    } catch (err) {
      if (kDebugMode) {
        debugPrint('ensure_profile civic_app schema failed: $err');
      }
    }

    await supabase.rpc('ensure_profile', params: {
      'p_username': (u.userMetadata?['username'] as String?) ?? '',
      'p_full_name': (u.userMetadata?['full_name'] as String?) ?? u.email ?? '',
      'p_email': u.email ?? '',
    });
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('ensure_profile failed: $e');
      debugPrintStack(stackTrace: st);
    }
    // Non-fatal: UI will still fetch via profile_me and can auto-create on demand
  }
}

// Handy snackbar extension for quick feedback
extension BuildContextExtension on BuildContext {
  void showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }
}
