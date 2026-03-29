import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSubmitting = false;
  bool _showResetLink = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _extractToken(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return '';

    final uri = Uri.tryParse(trimmed);
    if (uri != null && uri.queryParameters.containsKey('token')) {
      return uri.queryParameters['token']?.trim() ?? '';
    }

    return trimmed;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final token = _extractToken(_tokenController.text);
    final response = await _apiService.completePasswordReset(
      token: token,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (response['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ??
                'Password reset successfully. You can log in now.',
          ),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      Navigator.of(context).pop();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          response['message']?.toString() ?? 'Failed to reset password',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.borderGrey),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.borderGrey),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Reset Password'),
        backgroundColor: Colors.white,
        foregroundColor: AppTheme.textDark,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        margin: const EdgeInsets.only(bottom: 18),
                        decoration: BoxDecoration(
                          gradient: AppTheme.governmentGradient,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(
                          Icons.lock_reset_rounded,
                          color: Colors.white,
                          size: 34,
                        ),
                      ),
                      const Text(
                        'Finish your password reset',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Paste the reset token or the full reset link you received by email, then enter your new password.',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextFormField(
                        controller: _tokenController,
                        obscureText: !_showResetLink,
                        maxLines: _showResetLink ? 2 : 1,
                        decoration: _inputDecoration(
                          label: 'Reset token or link',
                          icon: Icons.link_rounded,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showResetLink = !_showResetLink);
                            },
                            icon: Icon(
                              _showResetLink
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (_extractToken(value ?? '').isEmpty) {
                            return 'Enter the reset token or full reset link';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: !_showPassword,
                        decoration: _inputDecoration(
                          label: 'New password',
                          icon: Icons.lock_outline_rounded,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(() => _showPassword = !_showPassword);
                            },
                            icon: Icon(
                              _showPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: !_showConfirmPassword,
                        decoration: _inputDecoration(
                          label: 'Confirm password',
                          icon: Icons.lock_person_outlined,
                          suffixIcon: IconButton(
                            onPressed: () {
                              setState(
                                () => _showConfirmPassword =
                                    !_showConfirmPassword,
                              );
                            },
                            icon: Icon(
                              _showConfirmPassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 22),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('UPDATE PASSWORD'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
