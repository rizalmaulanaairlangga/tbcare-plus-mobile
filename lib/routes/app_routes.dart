import 'package:flutter/material.dart';
import '../features/auth/pages/cover_page.dart';
import '../features/auth/pages/login_page.dart';
import '../features/auth/pages/register_page.dart';
import '../features/home/pages/home_page.dart';
import '../features/assessment/pages/full_assessment_page.dart';
// import '../features/assessment/pages/symptom_info_page.dart';
import '../features/result/pages/result_page.dart';
import '../features/history/pages/history_page.dart';
import '../features/history/pages/history_detail_page.dart';
import '../features/profile/pages/profile_page.dart';
import '../features/profile/pages/edit_profile_page.dart';
import '../features/profile/pages/change_password_page.dart';
import '../features/about/pages/about_page.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static const String cover = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String fullAssessment = '/full-assessment';
  // static const String symptomInfo = '/symptom-info';
  static const String result = '/result';
  static const String history = '/history';
  static const String historyDetail = '/history-detail';
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String changePassword = '/change-password';
  static const String about = '/about';

  static Map<String, WidgetBuilder> get routes => {
    cover: (context) => const CoverPage(),
    login: (context) => const LoginPage(),
    register: (context) => const RegisterPage(),
    home: (context) => const HomePage(),
    fullAssessment: (context) => const FullAssessmentPage(),
    // symptomInfo: (context) => const SymptomInfoPage(),
    result: (context) => const ResultPage(),
    history: (context) => const HistoryPage(),
    historyDetail: (context) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      return HistoryDetailPage(item: args);
    },
    profile: (context) => const ProfilePage(),
    editProfile: (context) => const EditProfilePage(),
    changePassword: (context) => const ChangePasswordPage(),
    about: (context) => const AboutPage(),
  };
}
