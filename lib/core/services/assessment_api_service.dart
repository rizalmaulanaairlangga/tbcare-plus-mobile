import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/assessment_config_models.dart';
import 'session_service.dart';
import 'storage_service.dart';

class AssessmentApiService {
  static Future<void> _handleUnauthorized() async {
    await SessionService.logoutAndRedirectToLogin();
    throw Exception('Sesi login telah berakhir. Silakan login kembali.');
  }

  static Future<QuickCheckConfig> fetchQuickCheckConfig() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.quickCheckConfig))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          return QuickCheckConfig.fromJson(data);
        }
      }
      return QuickCheckConfig.fallback();
    } catch (_) {
      return QuickCheckConfig.fallback();
    }
  }

  static Future<QuickCheckConfig> fetchFullAssessmentConfig() async {
    try {
      final response = await http
          .get(Uri.parse(AppConstants.fullAssessmentConfig))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final data = json['data'] as Map<String, dynamic>?;
        if (data != null) {
          return QuickCheckConfig.fromJson(data);
        }
      }
      throw Exception('Gagal memuat konfigurasi penilaian dari server.');
    } catch (_) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> submitAssessment({
    required int assessmentTypeId,
    required List<Map<String, dynamic>> answers,
  }) async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final payload = {
      'assessmentTypeId': assessmentTypeId,
      'answers': answers,
    };

    final response = await http
        .post(
          Uri.parse(AppConstants.submitAssessment),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _handleUnauthorized();
    }

    if (response.statusCode != 200) {
      try {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final message = (json['message'] as String?) ?? 'Gagal menyimpan assessment.';
        throw Exception('[${response.statusCode}] $message');
      } catch (_) {
        final body = response.body.trim();
        final snippet = body.length > 500 ? body.substring(0, 500) : body;
        throw Exception('[${response.statusCode}] Gagal menyimpan assessment. Response: $snippet');
      }
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['data'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchHistory() async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final response = await http.get(
      Uri.parse(AppConstants.assessmentHistory),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _handleUnauthorized();
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>?;
      if (data != null) {
        return data.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> fetchHistorySessions() async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final response = await http.get(
      Uri.parse(AppConstants.assessmentHistorySessions),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _handleUnauthorized();
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final data = json['data'] as List<dynamic>?;
      if (data != null) {
        return data.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchHistorySessionDetail(String sessionKey) async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final response = await http.get(
      Uri.parse(AppConstants.assessmentHistorySessionDetail(sessionKey)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _handleUnauthorized();
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  static Future<Map<String, dynamic>?> fetchHistoryDetail(int id) async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final response = await http.get(
      Uri.parse(AppConstants.assessmentHistoryDetail(id)),
      headers: {
        'Authorization': 'Bearer $token',
      },
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 401) {
      await _handleUnauthorized();
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return json['data'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// Fetch the most recent assessment session for the current user
  /// Returns a map with assessment type, risk level, and score info
  /// Returns null if no assessment history exists
  static Future<Map<String, dynamic>?> fetchMostRecentAssessment() async {
    try {
      final sessions = await fetchHistorySessions();
      if (sessions.isEmpty) return null;

      // Get the most recent session (already sorted in fetchHistorySessions)
      final mostRecent = sessions.first;
      final sessionKey = mostRecent['sessionKey'] as String?;
      if (sessionKey == null) return null;

      // Fetch the full details of this session
      final details = await fetchHistorySessionDetail(sessionKey);
      if (details == null) return null;

      // The session detail contains an "items" list. Pick the first item
      // and normalize keys so callers can read expected fields.
      final items = details['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      // Helper to read either camelCase or PascalCase keys from payloads
      dynamic getField(Map<String, dynamic> src, List<String> keys) {
        for (final k in keys) {
          if (src.containsKey(k)) return src[k];
        }
        return null;
      }

      int riskRankFromCode(String? code) {
        final c = (code ?? '').toUpperCase();
        if (c.contains('HIGH')) return 3;
        if (c.contains('MEDIUM') || c.contains('MODERATE')) return 2;
        return 1;
      }

      // Pick the best item: highest risk rank, then highest total score
      Map<String, dynamic>? best;
      for (final it in items) {
        if (it is! Map) continue;
        final m = Map<String, dynamic>.from(it.cast<String, dynamic>());
        final rl = getField(m, ['riskLevel', 'riskLevel']) as Map<String, dynamic>? ??
            getField(m, ['riskLevelMap', 'RiskLevel']) as Map<String, dynamic>?;
        String? code;
        if (rl is Map<String, dynamic>) {
          code = getField(rl, ['code', 'Code', 'riskCode']) as String?;
        }
        final scoreVal = getField(m, ['totalScore', 'TotalScore', 'total_score']);
        final score = (scoreVal is num) ? scoreVal.toDouble() : (double.tryParse(scoreVal?.toString() ?? '') ?? 0.0);

        if (best == null) {
          best = m;
          continue;
        }

        final bestRl = getField(best, ['riskLevel', 'riskLevel']) as Map<String, dynamic>?;
        String? bestCode;
        if (bestRl is Map<String, dynamic>) {
          bestCode = getField(bestRl, ['code', 'Code', 'riskCode']) as String?;
        }
        final bestScoreVal = getField(best, ['totalScore', 'TotalScore', 'total_score']);
        final bestScore = (bestScoreVal is num) ? bestScoreVal.toDouble() : (double.tryParse(bestScoreVal?.toString() ?? '') ?? 0.0);

        final r1 = riskRankFromCode(code);
        final r2 = riskRankFromCode(bestCode);
        if (r1 > r2 || (r1 == r2 && score > bestScore)) {
          best = m;
        }
      }

      final first = best ?? (items.first as Map<String, dynamic>);

      final mapped = <String, dynamic>{
        'sessionKey': details['sessionKey'] ?? mostRecent['sessionKey'],
        'createdAt': details['createdAt'] ?? mostRecent['createdAt'],
        'assessmentTypeId': getField(details, ['assessmentTypeId', 'AssessmentTypeId']) ?? getField(first, ['assessmentTypeId', 'AssessmentTypeId']),
        'assessmentTypeName': getField(details, ['assessmentTypeName', 'AssessmentTypeName']) ?? getField(first, ['assessmentTypeName', 'AssessmentTypeName']),
        'riskLevelCode': getField(first, ['riskLevelCode', 'RiskLevelCode', 'riskCode']) ?? (getField(getField(first, ['riskLevel', 'riskLevel']) as Map<String, dynamic>? ?? <String,dynamic>{}, ['code', 'Code', 'riskCode']) ?? ''),
        'riskLevelTitle': getField(first, ['riskLevelTitle', 'RiskLevelTitle', 'riskTitle']) ?? (getField(getField(first, ['riskLevel', 'riskLevel']) as Map<String, dynamic>? ?? <String,dynamic>{}, ['title', 'Title']) ?? ''),
        'totalScore': getField(first, ['totalScore', 'TotalScore']) ?? 0,
        'primaryTbTypeId': getField(first, ['primaryTbTypeId', 'PrimaryTbTypeId']) ?? getField(first, ['tbTypeId', 'TbTypeId']),
        'primaryTbTypeName': getField(first, ['primaryTbTypeName', 'PrimaryTbTypeName']) ?? getField(first, ['tbTypeName', 'TbTypeName']),
        'detailItem': first,
      };

      return mapped;
    } catch (_) {
      return null;
    }
  }

  /// Check if user has completed a full assessment
  static Future<bool> hasCompletedFullAssessment() async {
    try {
      final sessions = await fetchHistorySessions();
      // Check if any session is a full assessment (assessmentTypeId == 2)
      return sessions.any((s) => (s['assessmentTypeId'] as int?) == 2);
    } catch (_) {
      return false;
    }
  }

  /// Check if the most recent assessment is a quick assessment (not full)
  static Future<bool> isMostRecentQuickAssessment() async {
    try {
      final sessions = await fetchHistorySessions();
      if (sessions.isEmpty) return false;
      final mostRecent = sessions.first;
      return (mostRecent['assessmentTypeId'] as int?) == 1;
    } catch (_) {
      return false;
    }
  }
}
