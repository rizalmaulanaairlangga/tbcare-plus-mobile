import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConstants {
  // ── Backend API base URL ─────────────────────────────────────────────
  // Ganti dengan URL Railway/Render production saat deploy.
  // Untuk emulator Android, gunakan 10.0.2.2 sebagai pengganti localhost.
  static final String baseUrl = (!kIsWeb && Platform.isAndroid)
      ? 'http://10.0.2.2:5181'
      : 'http://localhost:5181';

  // ── API Paths ────────────────────────────────────────────────────────
  static final String authRegister = '$baseUrl/api/v1/auth/register';
  static final String authLogin    = '$baseUrl/api/v1/auth/login';
  static final String usersMe      = '$baseUrl/api/v1/auth/me';
  static final String quickCheckConfig = '$baseUrl/api/v1/assessment/quick-check-config';
  static final String fullAssessmentConfig = '$baseUrl/api/v1/assessment/full-assessment-config';

  // ── SharedPreferences Keys ───────────────────────────────────────────
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser         = 'user_json';
  static const String keyGuestAssessment = 'guest_assessment_json';
}
