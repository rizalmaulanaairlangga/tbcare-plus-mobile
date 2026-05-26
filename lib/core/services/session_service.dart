import '../../routes/app_routes.dart';
import 'storage_service.dart';

class SessionService {
  static bool _redirecting = false;

  static Future<void> logoutAndRedirectToLogin() async {
    await StorageService.clear();

    if (_redirecting) return;
    _redirecting = true;

    final nav = AppRoutes.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
    }

    _redirecting = false;
  }
}

