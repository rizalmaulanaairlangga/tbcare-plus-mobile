import 'dart:convert';

class UserModel {
  final String id;
  final String? fullName;
  final String? email;
  final String? role;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    this.fullName,
    this.email,
    this.role,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:        json['id'] as String,
      fullName:  json['fullName'] as String?,
      email:     json['email'] as String?,
      role:      json['role'] as String?,
      isActive:  json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id':        id,
    'fullName':  fullName,
    'email':     email,
    'role':      role,
    'isActive':  isActive,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  String toJsonString() => jsonEncode(toJson());

  static UserModel fromJsonString(String s) =>
      UserModel.fromJson(jsonDecode(s) as Map<String, dynamic>);
}

class AuthResponse {
  final String accessToken;
  final String refreshToken;
  final int expiresIn;
  final UserModel user;

  const AuthResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.expiresIn,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken:  json['accessToken']  as String,
      refreshToken: json['refreshToken'] as String,
      expiresIn:    (json['expiresIn'] as num).toInt(),
      user:         UserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}
