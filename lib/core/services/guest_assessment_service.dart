import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';

class GuestAssessmentService {
  static Future<void> save(Map<String, dynamic> assessment) async {
    final prefs = await SharedPreferences.getInstance();
    assessment['savedAt'] = DateTime.now().toIso8601String();
    await prefs.setString(AppConstants.keyGuestAssessment, jsonEncode(assessment));
  }

  static Future<Map<String, dynamic>?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.keyGuestAssessment);
    if (json == null) return null;
    return jsonDecode(json) as Map<String, dynamic>;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.keyGuestAssessment);
  }
}
