import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../models/auth_models.dart';
import 'session_service.dart';
import 'storage_service.dart';

class AuthApiService {
  static const _headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // ── Register ──────────────────────────────────────────────────────────
  static Future<AuthResponse> register({
    required String email,
    required String password,
    String? nickname,
  }) async {
    final body = jsonEncode({
      'email':    email,
      'password': password,
      if (nickname != null && nickname.isNotEmpty) 'nickname': nickname,
    });

    try {
      final response = await http
          .post(Uri.parse(AppConstants.authRegister), headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));

      return _handleAuthResponse(response);
    } on TimeoutException {
      throw Exception('Server tidak merespons. Pastikan backend sedang berjalan.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on HttpException {
      throw Exception('Terjadi kesalahan jaringan. Coba lagi.');
    } on FormatException {
      throw Exception('Respons server tidak valid.');
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────
  static Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final body = jsonEncode({'email': email, 'password': password});

    try {
      final response = await http
          .post(Uri.parse(AppConstants.authLogin), headers: _headers, body: body)
          .timeout(const Duration(seconds: 30));

      return _handleAuthResponse(response);
    } on TimeoutException {
      throw Exception('Server tidak merespons. Pastikan backend sedang berjalan.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on HttpException {
      throw Exception('Terjadi kesalahan jaringan. Coba lagi.');
    } on FormatException {
      throw Exception('Respons server tidak valid.');
    }
  }

  // ── Fetch Current User (Profile) ──────────────────────────────────────
  static Future<UserModel> fetchCurrentUser() async {
    final token = await StorageService.getAccessToken();
    if (token == null || token.isEmpty) {
      throw Exception('Token tidak ditemukan. Silakan login kembali.');
    }

    final headers = {
      ..._headers,
      'Authorization': 'Bearer $token',
    };

    try {
      final response = await http
          .get(Uri.parse(AppConstants.usersMe), headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        await SessionService.logoutAndRedirectToLogin();
        throw Exception('Sesi login telah berakhir. Silakan login kembali.');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final data = json['data'] as Map<String, dynamic>;
        final user = UserModel.fromJson(data);
        await StorageService.saveUser(user); // Cache updated user profile locally
        return user;
      }

      final message = json['message'] as String? ?? 'Gagal memuat profil.';
      throw Exception(message);
    } on TimeoutException {
      throw Exception('Server tidak merespons. Pastikan backend sedang berjalan.');
    } on SocketException {
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } on HttpException {
      throw Exception('Terjadi kesalahan jaringan. Coba lagi.');
    } on FormatException {
      throw Exception('Respons server tidak valid.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────
  static Future<void> logout() async {
    await StorageService.clear();
  }

  // ── Private Helper ────────────────────────────────────────────────────
  static AuthResponse _handleAuthResponse(http.Response response) {
    final json = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = json['data'] as Map<String, dynamic>;
      return AuthResponse.fromJson(data);
    }

    // Extract error message from backend ApiResponse shape
    final message = json['message'] as String? ?? 'Terjadi kesalahan.';
    final errors  = (json['errors'] as List?)?.cast<String>();
    final detail  = errors != null && errors.isNotEmpty
        ? '${message}\n${errors.join('\n')}'
        : message;

    throw Exception(detail);
  }
}
