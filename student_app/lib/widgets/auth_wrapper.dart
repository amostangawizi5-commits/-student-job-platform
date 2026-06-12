import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home_screen.dart' as public_home;
import '../screens/student/student_dashboard.dart';
import '../screens/organization/organization_dashboard.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/university/university_dashboard.dart';
import '../utils/user_role.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  bool get _isMobileDevice =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.checkAuthStatus();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isAuthenticated && authProvider.user != null) {
          final role = normalizeUserRole(authProvider.user!['role']);

          if (isStudentRole(role)) {
            return const StudentDashboard();
          } else if (isCompanyRole(role)) {
            return const OrganizationDashboard();
          } else if (role == 'university') {
            return const UniversityDashboard();
          } else if (role == 'admin') {
            return const AdminDashboard();
          }
        }

        return _isMobileDevice
            ? const LoginScreen()
            : const public_home.HomeScreen();
      },
    );
  }
}
