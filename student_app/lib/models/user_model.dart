// lib/models/user_model.dart
import '../utils/user_role.dart';

class UserModel {
  final String userId;
  final String email;
  final String role;
  final String fullName;
  final String? phone;
  final String? profileImageUrl;
  final bool isVerified;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? studentData;
  final Map<String, dynamic>? companyData;
  final Map<String, dynamic>? universityData;

  UserModel({
    required this.userId,
    required this.email,
    required this.role,
    required this.fullName,
    this.phone,
    this.profileImageUrl,
    required this.isVerified,
    required this.isActive,
    required this.createdAt,
    this.studentData,
    this.companyData,
    this.universityData,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      userId: json['user_id'] ?? json['id'] ?? '',
      email: json['email'] ?? '',
      role: json['role'] ?? '',
      fullName: json['full_name'] ?? json['name'] ?? '',
      phone: json['phone'],
      profileImageUrl: json['profile_image_url'],
      isVerified: json['is_verified'] ?? false,
      isActive: json['is_active'] ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      studentData: json['student_data'],
      companyData: json['company_data'],
      universityData: json['university_data'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'email': email,
      'role': role,
      'full_name': fullName,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'is_verified': isVerified,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'student_data': studentData,
      'company_data': companyData,
      'university_data': universityData,
    };
  }

  bool get isStudent => isStudentRole(role);
  bool get isCompany => isCompanyRole(role);
  bool get isUniversity => isUniversityRole(role);
  bool get isAdmin => isAdminRole(role);

  String get displayName =>
      fullName.isNotEmpty ? fullName : email.split('@').first;
}
