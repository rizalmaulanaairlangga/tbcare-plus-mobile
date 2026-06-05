import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConstants {
  // ── Backend API base URL ─────────────────────────────────────────────
  //
  // Reads production / local URLs from the bundled .env file via flutter_dotenv.
  // Copy .env.example to .env and adjust for your environment.
  //
  // When USE_LOCAL=true (and in debug mode), the app points to the local
  // backend. Android emulators automatically use 10.0.2.2 instead of localhost.
  static final String _prodUrl =
      dotenv.env['API_BASE_URL'] ?? 'http://localhost:5181';
  static final String _localUrl =
      dotenv.env['API_LOCAL_URL'] ?? 'http://localhost:5181';
  static final bool _useLocal =
      (dotenv.env['USE_LOCAL'] ?? 'false').toLowerCase() == 'true';

  static final String baseUrl = () {
    if (_useLocal && kDebugMode) {
      if (kIsWeb) return _localUrl;
      if (Platform.isAndroid && _detectAndroidEmulator()) {
        return 'http://10.0.2.2:5181';
      }
      return _localUrl;
    }
    return _prodUrl;
  }();

  static bool _detectAndroidEmulator() {
    try {
      return Platform.isAndroid &&
          (Platform.environment.containsKey('ANDROID_EMULATOR') ||
              Platform.localHostname.startsWith('emulator') ||
              Platform.localHostname == 'localhost');
    } catch (_) {
      return false;
    }
  }

  // ── API Paths ────────────────────────────────────────────────────────
  static final String authRegister = '$baseUrl/api/v1/auth/register';
  static final String authLogin = '$baseUrl/api/v1/auth/login';
  static final String authRefresh = '$baseUrl/api/v1/auth/refresh';
  static final String authChangePassword =
      '$baseUrl/api/v1/auth/change-password';
  static final String usersMe = '$baseUrl/api/v1/auth/me';
  static final String usersUpdateMe = '$baseUrl/api/v1/auth/me';
  static final String quickCheckConfig =
      '$baseUrl/api/v1/assessment/quick-check-config';
  static final String fullAssessmentConfig =
      '$baseUrl/api/v1/assessment/full-assessment-config';
  static final String submitAssessment = '$baseUrl/api/v1/assessment/submit';
  static final String assessmentHistory = '$baseUrl/api/v1/assessment/history';
  static final String assessmentHistorySessions =
      '$baseUrl/api/v1/assessment/history-sessions';
  static String assessmentHistorySessionDetail(String sessionKey) =>
      '$baseUrl/api/v1/assessment/history-sessions/$sessionKey';
  static String assessmentHistoryDetail(int id) =>
      '$baseUrl/api/v1/assessment/history/$id';

  // ── SharedPreferences Keys ───────────────────────────────────────────
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  // Epoch milliseconds at which the access token expires. Used to refresh
  // proactively before a request rather than waiting for a 401.
  static const String keyTokenExpiresAt = 'token_expires_at';
  static const String keyUser = 'user_json';

  // Cached "most recent assessment" summary for logged-in users. Namespaced
  // by user id at write time to prevent cross-account leakage on shared
  // devices; cleared on logout.
  static const String keyCachedRecentAssessmentPrefix = 'recent_assessment_';
  // Cached server-fetched config JSON, used as offline fallback after the
  // first successful fetch.
  static const String keyCachedQuickCheckConfig = 'cached_quick_check_config';
  static const String keyCachedFullAssessmentConfig =
      'cached_full_assessment_config';
}
