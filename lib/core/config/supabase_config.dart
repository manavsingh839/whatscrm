import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String defaultUrl = 'https://okiocrxyxrzzyqhzsnmw.supabase.co';
  static const String defaultAnonKey = 'sb_publishable_BIZXS9a333ZZF8Id0gJ3ZA_y2UEV4Hf';

  static String _url = defaultUrl;
  static String _anonKey = defaultAnonKey;

  static String get url => _url;
  static String get anonKey => _anonKey;

  static bool get isConfigured =>
      _url.isNotEmpty &&
      _anonKey.isNotEmpty &&
      _url != defaultUrl &&
      _anonKey != defaultAnonKey;

  static Future<void> loadSavedConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUrl = prefs.getString('supabase_url');
      final savedKey = prefs.getString('supabase_anon_key');
      if (savedUrl != null && savedUrl.isNotEmpty) _url = savedUrl;
      if (savedKey != null && savedKey.isNotEmpty) _anonKey = savedKey;
    } catch (e) {
      debugPrint('Error loading saved Supabase config: $e');
    }
  }

  static Future<void> saveConfig({
    required String url,
    required String anonKey,
  }) async {
    _url = url.trim();
    _anonKey = anonKey.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('supabase_url', _url);
    await prefs.setString('supabase_anon_key', _anonKey);
  }

  static Future<void> initialize() async {
    await loadSavedConfig();
    try {
      await Supabase.initialize(
        url: _url,
        // ignore: deprecated_member_use
        anonKey: _anonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          eventsPerSecond: 10,
        ),
      );
    } catch (e) {
      debugPrint('Supabase initialize note: $e');
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
