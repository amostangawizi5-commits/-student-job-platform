import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import 'reset_password_screen.dart';
import 'register_screen.dart';
import '../student/student_dashboard.dart';
import '../company/company_dashboard.dart';
import '../admin/admin_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isPasswordVisible = false;
  bool _isLoggingIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoggingIn = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      if (success) {
        final user = authProvider.user;

        if (user != null) {
          final role = user['role'];

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Login successful!'),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 1),
            ),
          );

          if (mounted) {
            if (role == 'student' || role == 'graduate') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const StudentDashboard()),
                (route) => false,
              );
            } else if (role == 'company') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const CompanyDashboard()),
                (route) => false,
              );
            } else if (role == 'admin') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AdminDashboard()),
                (route) => false,
              );
            }
          }
        } else {
          setState(() => _isLoggingIn = false);
        }
      } else {
        setState(() => _isLoggingIn = false);
        final message =
            authProvider.errorMessage ??
            'Login failed. Check your credentials.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final response = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
        apiService: _apiService,
      ),
    );

    if (!mounted || response == null) return;

    final message =
        response['message']?.toString() ??
        'If an account with that email exists, a reset link has been sent.';
    final debugResetLink = response['debugResetLink']?.toString();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.primaryGreen,
        duration: Duration(seconds: debugResetLink == null ? 4 : 8),
        action: SnackBarAction(
          label: 'Reset Now',
          textColor: Colors.white,
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
            );
          },
        ),
      ),
    );

    if (debugResetLink == null || debugResetLink.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Reset Link Ready',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'If your email app does not open the link, copy this link or open the reset screen and paste it there.',
                style: TextStyle(color: Colors.grey.shade700, height: 1.4),
              ),
              const SizedBox(height: 14),
              SelectableText(
                debugResetLink,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: debugResetLink),
                    );
                    if (!sheetContext.mounted) return;
                    ScaffoldMessenger.of(sheetContext).showSnackBar(
                      const SnackBar(
                        content: Text('Reset link copied'),
                        backgroundColor: AppTheme.primaryGreen,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                  ),
                  child: const Text('COPY RESET LINK'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ResetPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text('OPEN RESET SCREEN'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Logo ya Serikali na Header
                          Column(
                            children: [
                              // Logo ya Serikali
                              Container(
                                height: 80,
                                width: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.grey.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/internshiplogo.png',
                                    height: 80,
                                    width: 80,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.blue.shade100,
                                        child: const Icon(
                                          Icons.verified,
                                          size: 50,
                                          color: Colors.blue,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'THE UNITED REPUBLIC OF TANZANIA',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'INTERNSHIP GOVERNMENT SYSTEM',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Empowering Tanzanian Youth',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          const Text(
                            'LOGIN',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),

                          const SizedBox(height: 32),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: InputDecoration(
                                    labelText: 'Email / Username',
                                    hintText: 'Enter your email address',
                                    prefixIcon: const Icon(
                                      Icons.person_outline,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.borderGrey,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.borderGrey,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(Icons.lock_outline),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _isPasswordVisible
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: AppTheme.textLight,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _isPasswordVisible =
                                              !_isPasswordVisible;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.borderGrey,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppTheme.borderGrey,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppTheme.primaryBlue,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.white,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your password';
                                    }
                                    if (value.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          Material(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(16),
                            child: InkWell(
                              onTap: _isLoggingIn
                                  ? null
                                  : _showForgotPasswordDialog,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.2,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: 0.12,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.lock_reset_rounded,
                                        color: AppTheme.primaryBlue,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Forgot Password?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            'Tap here to get a reset link by email',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4B5563),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      size: 16,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: _isLoggingIn ? null : _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoggingIn
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),

                          const SizedBox(height: 24),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: AppTheme.caption,
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: Text(
                                  'Register',
                                  style: TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          const Divider(),

                          const SizedBox(height: 12),

                          Column(
                            children: [
                              Text(
                                '© 2026 Developed by',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'DEVELOPER GINGER',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryBlue,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Version 1.0.0',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Jamhuri ya Muungano wa Tanzania',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Loading Overlay
          if (_isLoggingIn)
            Container(
              color: Colors.black.withValues(alpha: 0.5),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Logging in...',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String initialEmail;
  final ApiService apiService;

  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.apiService,
  });

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  String? _errorText;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorText = 'Enter a valid email address');
      return;
    }

    setState(() {
      _errorText = null;
      _isSubmitting = true;
    });

    try {
      final response = await widget.apiService.forgotPassword(email);
      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.of(context).pop(response);
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorText =
            response['message']?.toString() ??
            'Failed to send password reset link';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      scrollable: true,
      title: const Text('Forgot Password'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter your email address and we will send you a secure reset link.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSubmitting ? null : _submit(),
              decoration: InputDecoration(
                labelText: 'Email address',
                prefixIcon: const Icon(Icons.email_outlined),
                errorText: _errorText,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(_isSubmitting ? 'Sending...' : 'Send Link'),
        ),
      ],
    );
  }
}
