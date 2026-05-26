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
}
