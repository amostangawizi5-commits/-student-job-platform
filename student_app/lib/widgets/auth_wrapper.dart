import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/student/student_dashboard.dart';
import '../screens/company/company_dashboard.dart';
import '../screens/admin/admin_dashboard.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

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
          final role = authProvider.user!['role'];

          if (role == 'student' || role == 'graduate') {
            return const StudentDashboard();
          } else if (role == 'company') {
            return const CompanyDashboard();
          } else if (role == 'admin') {
            return const AdminDashboard();
          }
        }

        return const LoginScreen();
      },
    );
  }
}
