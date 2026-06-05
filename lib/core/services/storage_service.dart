import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../models/auth_models.dart';

class StorageService {
  static UserModel? _cachedUser;
  static Map<String, dynamic>? lastAssessmentResult;
  static Map<String, dynamic>? guestSessionResult;

  static UserModel? get cachedUser => _cachedUser;

  // ── Token ────────────────────────────────────────────────────────────
  static Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required int expiresIn,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyAccessToken, accessToken);
    await prefs.setString(AppConstants.keyRefreshToken, refreshToken);
    final expiresAt =
        DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;
    await prefs.setInt(AppConstants.keyTokenExpiresAt, expiresAt);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyAccessToken);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyRefreshToken);
  }

  /// When the stored access token expires, or null if unknown (e.g. a session
  /// created before token-expiry tracking existed).
  static Future<DateTime?> getAccessTokenExpiry() async {
    final prefs = await SharedPreferences.getInstance();
    final ms = prefs.getInt(AppConstants.keyTokenExpiresAt);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// True if the access token is expired (or within [leeway] of expiring).
  /// Returns false when expiry is unknown — we don't force a proactive refresh
  /// for legacy sessions; the reactive 401 path still covers them.
  static Future<bool> isAccessTokenExpired({
    Duration leeway = const Duration(seconds: 60),
  }) async {
    final expiry = await getAccessTokenExpiry();
    if (expiry == null) return false;
    return DateTime.now().add(leeway).isAfter(expiry);
  }

  // ── User ─────────────────────────────────────────────────────────────
  static Future<void> saveUser(UserModel user) async {
    _cachedUser = user;
    final prefs = await SharedPreferences.getInstance();
    // Exclude profilePicture from persistence — data URLs are too large for SharedPreferences
    final lean = user.toJson()..remove('profilePicture');
    await prefs.setString(AppConstants.keyUser, jsonEncode(lean));
  }

  static Future<UserModel?> getUser() async {
    if (_cachedUser != null) return _cachedUser;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.keyUser);
    if (json == null) return null;
    try {
      _cachedUser = UserModel.fromJsonString(json);
      return _cachedUser;
    } catch (_) {
      // Stored JSON is corrupt or from an incompatible older app version.
      // Drop it so the next login replaces it cleanly.
      await prefs.remove(AppConstants.keyUser);
      return null;
    }
  }

  // ── Clear (logout) ────────────────────────────────────────────────────
  static Future<void> clear() async {
    _cachedUser = null;
    guestSessionResult = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyAccessToken);
    await prefs.remove(AppConstants.keyRefreshToken);
    await prefs.remove(AppConstants.keyTokenExpiresAt);
    await prefs.remove(AppConstants.keyUser);

    // Wipe all per-user cached recent-assessment entries so a logout followed
    // by a different user's login can't briefly surface the previous account's
    // result card.
    final keys = prefs.getKeys()
        .where((k) => k.startsWith(AppConstants.keyCachedRecentAssessmentPrefix))
        .toList();
    for (final k in keys) {
      await prefs.remove(k);
    }
  }

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  // ── Cached Most-Recent Assessment (per-user) ─────────────────────────
  //
  // Stores the last successfully-fetched OR just-submitted assessment summary
  // for a logged-in user. Survives offline pulls so the home card doesn't
  // revert to the fresh "quick check" view when the server is unreachable.
  // Keyed by user id to prevent leakage across accounts on a shared device.

  static String _recentAssessmentKey(String userId) =>
      '${AppConstants.keyCachedRecentAssessmentPrefix}$userId';

  static Future<void> saveCachedRecentAssessment(
    String userId,
    Map<String, dynamic> summary,
  ) async {
    if (userId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_recentAssessmentKey(userId), jsonEncode(summary));
  }

  static Future<Map<String, dynamic>?> getCachedRecentAssessment(
    String userId,
  ) async {
    if (userId.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_recentAssessmentKey(userId));
    if (json == null) return null;
    try {
      final decoded = jsonDecode(json);
      if (decoded is Map<String, dynamic>) return decoded;
      await prefs.remove(_recentAssessmentKey(userId));
      return null;
    } on FormatException {
      await prefs.remove(_recentAssessmentKey(userId));
      return null;
    }
  }
}
