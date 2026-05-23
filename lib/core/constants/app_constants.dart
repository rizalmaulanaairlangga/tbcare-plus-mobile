class AppConstants {
  // ── Backend API base URL ─────────────────────────────────────────────
  // Ganti dengan URL Railway/Render production saat deploy.
  // Untuk emulator Android, gunakan 10.0.2.2 sebagai pengganti localhost.
  static const String baseUrl = 'http://localhost:5181';

  // ── API Paths ────────────────────────────────────────────────────────
  static const String authRegister = '$baseUrl/api/v1/auth/register';
  static const String authLogin    = '$baseUrl/api/v1/auth/login';
  static const String usersMe      = '$baseUrl/api/v1/users/me';
  static const String quickCheckConfig = '$baseUrl/api/v1/assessment/quick-check-config';

  // ── SharedPreferences Keys ───────────────────────────────────────────
  static const String keyAccessToken  = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUser         = 'user_json';
  static const String keyGuestAssessment = 'guest_assessment_json';
}
