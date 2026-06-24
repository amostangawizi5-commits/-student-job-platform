import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../utils/user_role.dart';
import '../utils/assets.dart';
import '../utils/theme.dart';
import 'admin/admin_dashboard.dart';
import 'home_screen.dart' as public_home;
import 'auth/login_screen.dart';
import 'organization/organization_dashboard.dart';
import 'student/student_dashboard.dart';
import 'university/university_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _logoAnimationController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<Offset> _logoSlideAnimation;
  bool _hasStartedAnimation = false;

  bool get _isMobileDevice =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void initState() {
    super.initState();

    _logoAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    final parent = CurvedAnimation(
      parent: _logoAnimationController,
      curve: Curves.easeOutCubic,
    );

    _logoScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.32,
          end: 1.16,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 68,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.16,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 32,
      ),
    ]).animate(parent);

    _logoFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _logoAnimationController,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      ),
    );

    _logoSlideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _logoAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasStartedAnimation) return;
      _hasStartedAnimation = true;
      _logoAnimationController.forward(from: 0);
    });

    _bootstrapApp();
  }

  Future<void> _bootstrapApp() async {
    final nextScreen = await _resolveNextScreen();
    if (!mounted) return;

    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (context) => nextScreen));
  }

  Future<Widget> _resolveNextScreen() async {
    final authProvider = context.read<AuthProvider>();

    await authProvider.checkAuthStatus();

    if (authProvider.isAuthenticated && authProvider.user != null) {
      final role = normalizeUserRole(authProvider.user!['role']);

      if (isStudentRole(role)) {
        return const StudentDashboard();
      }
      if (isCompanyRole(role)) {
        return const OrganizationDashboard();
      }
      if (role == 'university') {
        return const UniversityDashboard();
      }
      if (role == 'admin') {
        return const AdminDashboard();
      }
    }

    return _isMobileDevice
        ? const LoginScreen()
        : const public_home.HomeScreen();
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0xFF0B2C47), Color(0xFF1C5A88)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              right: -50,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -40,
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGold.withValues(alpha: 0.09),
                ),
              ),
            ),
            Center(
              child: FadeTransition(
                opacity: _logoFadeAnimation,
                child: SlideTransition(
                  position: _logoSlideAnimation,
                  child: ScaleTransition(
                    scale: _logoScaleAnimation,
                    child: Container(
                      width: 190,
                      height: 190,
                      padding: const EdgeInsets.all(26),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.18),
                            blurRadius: 28,
                            offset: const Offset(0, 18),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryDark.withValues(
                                alpha: 0.1,
                              ),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(22),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.94, end: 1),
                          duration: const Duration(milliseconds: 720),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Transform.scale(scale: value, child: child);
                          },
                          child: Image.asset(
                            AppAssets.splashLogo,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
