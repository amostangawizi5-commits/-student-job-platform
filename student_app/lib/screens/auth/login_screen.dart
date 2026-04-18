import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../utils/user_role.dart';
import 'register_screen.dart';
import '../student/student_dashboard.dart';
import '../company/company_dashboard.dart';
import '../admin/admin_dashboard.dart';
import '../university/university_dashboard.dart';

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

  Future<void> _resendForgotPasswordEmail(String email) async {
    final language = context.read<LanguageProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final normalizedEmail = email.trim();

    if (!normalizedEmail.contains('@')) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(language.tr('enter_valid_email_address')),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final response = await _apiService.forgotPassword(normalizedEmail);
      if (!mounted) return;

      final success = response['success'] == true;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? language.tr('reset_email_resent')
                : response['message']?.toString() ??
                      language.tr('failed_send_password_reset_link'),
          ),
          backgroundColor: success ? AppTheme.primaryGreen : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ApiService.normalizeErrorMessage(
              e,
              fallback: language.tr('failed_send_password_reset_link'),
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoggingIn = true);

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final language = context.read<LanguageProvider>();
      final success = await authProvider.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (!mounted) return;

      if (success) {
        final user = authProvider.user;

        if (user != null) {
          final role = normalizeUserRole(user['role']);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(language.tr('login_success')),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 1),
            ),
          );

          if (mounted) {
            if (isStudentRole(role)) {
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
            } else if (role == 'university') {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const UniversityDashboard()),
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
            language.tr('login_failed_check_credentials');
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
    final language = context.read<LanguageProvider>();
    final response = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => _ForgotPasswordDialog(
        initialEmail: _emailController.text.trim(),
        apiService: _apiService,
      ),
    );

    if (!mounted || response == null) return;

    final message =
        response['message']?.toString() ?? language.tr('reset_email_sent');
    final isEmailSent = response['emailSent'] != false;
    final requestEmail =
        response['requestEmail']?.toString() ?? _emailController.text.trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isEmailSent ? AppTheme.primaryGreen : Colors.orange,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: language.tr('resend'),
          textColor: Colors.white,
          onPressed: () => _resendForgotPasswordEmail(requestEmail),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();

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
                    elevation: 4,
                    surfaceTintColor: Colors.transparent,
                    shadowColor: AppTheme.primaryBlue.withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                      side: BorderSide(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.28),
                        width: 1.2,
                      ),
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
                                height: 108,
                                width: 108,
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
                                    'assets/images/splash_logo.png',
                                    height: 108,
                                    width: 108,
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
                              Text(
                                language.tr('united_republic_of_tanzania'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4A90E2),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                language.tr('internship_government_system'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF666666),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                language.tr('empowering_tanzanian_youth'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                  color: Color(0xFF888888),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 32),

                          Text(
                            language.tr('login'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                                    labelText: language.tr('email_or_username'),
                                    hintText: language.tr(
                                      'enter_your_email_address',
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.email_outlined,
                                    ),
                                    filled: true,
                                    fillColor: AppTheme.surfaceSoft,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return language.tr(
                                        'please_enter_your_email',
                                      );
                                    }
                                    if (!value.contains('@')) {
                                      return language.tr(
                                        'enter_valid_email_address',
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),

                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: !_isPasswordVisible,
                                  decoration: InputDecoration(
                                    labelText: language.tr('password'),
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
                                    filled: true,
                                    fillColor: AppTheme.surfaceSoft,
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return language.tr(
                                        'please_enter_your_password',
                                      );
                                    }
                                    if (value.length < 6) {
                                      return language.tr('password_min_6');
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),

                          Material(
                            color: Colors.white,
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
                                  color: const Color(0xFFF6FAFF),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.shadow.withValues(
                                        alpha: 0.04,
                                      ),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
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
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            language.tr('forgot_password'),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppTheme.primaryBlue,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            language.tr(
                                              'forgot_password_prompt',
                                            ),
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
                                : Text(
                                    language.tr('login'),
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
                                '${language.tr('dont_have_account')} ',
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
                                  language.tr('register'),
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
                                '© 2026 ${language.tr('IPTkiganjani', {'name': 'IPTkiganjani'})}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                language.tr('version_value', {
                                  'value': '1.2.1',
                                }),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                language.tr('united_republic_of_tanzania'),
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      language.tr('logging_in'),
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
    final language = context.read<LanguageProvider>();
    final email = _emailController.text.trim();
    if (!email.contains('@')) {
      setState(() => _errorText = language.tr('enter_valid_email_address'));
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
        Navigator.of(context).pop({...response, 'requestEmail': email});
        return;
      }

      setState(() {
        _isSubmitting = false;
        _errorText =
            response['message']?.toString() ??
            language.tr('failed_send_password_reset_link');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorText = ApiService.normalizeErrorMessage(
          e,
          fallback: language.tr('failed_send_password_reset_link'),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();

    return AlertDialog(
      scrollable: true,
      title: Text(language.tr('forgot_password')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(language.tr('forgot_password_description')),
            const SizedBox(height: 14),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _isSubmitting ? null : _submit(),
              decoration: InputDecoration(
                labelText: language.tr('email_address'),
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
          child: Text(language.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          child: Text(
            _isSubmitting ? language.tr('sending') : language.tr('send_link'),
          ),
        ),
      ],
    );
  }
}
