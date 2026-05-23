import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/assessment_config_models.dart';

class AssessmentApiService {
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
}
