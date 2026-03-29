// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  // Controllers
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Password visibility
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Student specific
  String? _selectedUniversityId;
  final _programController = TextEditingController();
  final String _studentType = 'current';
  int? _expectedGraduationYear;
  int? _graduationYear;
  String _experienceLevel = 'no_experience';

  // Company specific
  final _companyNameController = TextEditingController();
  String? _selectedIndustry;
  String? _selectedCompanySize;
  final _companyLocationController = TextEditingController();
  final _companyDescriptionController = TextEditingController();

  String _selectedRole = 'student';
  List<dynamic> _universities = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _universitiesError;

  final List<String> _industries = [
    'Technology / Software Development',
    'Banking / Finance',
    'Telecommunications',
    'Healthcare',
    'Education',
    'Manufacturing',
    'Retail',
    'Agriculture',
    'Construction',
    'Hospitality',
    'Consulting',
    'Other',
  ];

  final List<String> _companySizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    '1000+',
  ];

  final List<int> _years = List.generate(10, (i) => DateTime.now().year + i);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _programController.dispose();
    _companyNameController.dispose();
    _companyLocationController.dispose();
    _companyDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final universitiesResponse = await _apiService.getUniversities(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final dynamic rawUniversities = universitiesResponse['data'];

      List<dynamic> universities = [];
      if (rawUniversities is List) {
        universities = rawUniversities;
      } else if (rawUniversities is Map &&
          rawUniversities['universities'] is List) {
        universities = rawUniversities['universities'] as List<dynamic>;
      }

      setState(() {
        _universities = universities;
        _universitiesError = universities.isEmpty
            ? (universitiesResponse['message']?.toString() ??
                  'No universities available right now')
            : null;
        _isLoading = false;
      });
      debugPrint('Universities loaded: ${_universities.length}');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _universitiesError = e.toString();
      });
      debugPrint('Error loading data: $e');
    }
  }

  Future<void> _handleRegister() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      Map<String, dynamic> userData = {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'role': _selectedRole,
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      if (_selectedRole == 'student' || _selectedRole == 'graduate') {
        userData.addAll({
          'university_id': _selectedUniversityId,
          'program': _programController.text.trim(),
          'student_type': _studentType,
        });

        if (_studentType == 'current') {
          userData['expected_graduation_year'] = _expectedGraduationYear;
        } else {
          userData['graduation_year'] = _graduationYear;
          userData['experience_level'] = _experienceLevel;
        }
      } else if (_selectedRole == 'company') {
        userData.addAll({
          'company_name': _companyNameController.text.trim(),
          'industry': _selectedIndustry,
          'company_size': _selectedCompanySize,
          'location': _companyLocationController.text.trim(),
          'description': _companyDescriptionController.text.trim(),
        });
      }

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final success = await authProvider.register(userData);
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      if (success) {
        // Success Dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Container(
              padding: const EdgeInsets.all(20),
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4A90E2), Color(0xFF6C63FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Registration Successful!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Welcome to Government Internship System',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF4A90E2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: Color(0xFF4A90E2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _fullNameController.text.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Color(0xFF4A90E2),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _emailController.text.trim(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Account created successfully! Please login.',
                            ),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue to Login',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You can now login with your credentials',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (mounted) {
        final errorMessage =
            authProvider.errorMessage ??
            'Please check your information and try again.';
        // Error Dialog
        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 320),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 70,
                    width: 70,
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Registration Failed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Try Again',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Create Account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Form(
                    key: _formKey,
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
                                fontSize: 13,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Empowering Tanzanian Youth',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Title
                        const Text(
                          'Create New Account',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_isLoading) ...[
                          Row(
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Loading universities...',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                        ],

                        // Role Selection
                        const Text(
                          'I am a:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SegmentedButton<String>(
                          style: ButtonStyle(
                            backgroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return AppTheme.primaryBlue;
                              }
                              return Colors.grey.shade100;
                            }),
                            foregroundColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return Colors.white;
                              }
                              return AppTheme.textDark;
                            }),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: 'student',
                              label: Text('Student'),
                            ),
                            ButtonSegment(
                              value: 'graduate',
                              label: Text('Graduate'),
                            ),
                            ButtonSegment(
                              value: 'company',
                              label: Text('Company'),
                            ),
                          ],
                          selected: {_selectedRole},
                          onSelectionChanged: (Set<String> selection) {
                            setState(() {
                              _selectedRole = selection.first;
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // Common Fields with Validations
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Full name is required';
                            }
                            if (value.trim().length < 3) {
                              return 'Full name must be at least 3 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email is required';
                            }
                            if (!value.contains('@')) {
                              return 'Email must contain @';
                            }
                            if (!value.contains('.')) {
                              return 'Email must contain domain (e.g., .com, .ac.tz)';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: 'e.g., 0712345678 or +255712345678',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Phone number is required';
                            }
                            final phone = value.replaceAll(
                              RegExp(r'[\s\-]'),
                              '',
                            );
                            if (!RegExp(
                              r'^(0|\+255)[0-9]{9}$',
                            ).hasMatch(phone)) {
                              return 'Enter valid Tanzanian phone (e.g., 0712345678 or +255712345678)';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Password Field with Show/Hide
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
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            helperText:
                                'At least 8 chars, 1 uppercase, 1 lowercase, 1 number',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 8) {
                              return 'Password must be at least 8 characters';
                            }
                            if (!RegExp(r'[A-Z]').hasMatch(value)) {
                              return 'Password must contain at least one uppercase letter';
                            }
                            if (!RegExp(r'[a-z]').hasMatch(value)) {
                              return 'Password must contain at least one lowercase letter';
                            }
                            if (!RegExp(r'[0-9]').hasMatch(value)) {
                              return 'Password must contain at least one number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Confirm Password Field with Show/Hide
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_isConfirmPasswordVisible,
                          decoration: InputDecoration(
                            labelText: 'Confirm Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _isConfirmPasswordVisible
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: AppTheme.textLight,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isConfirmPasswordVisible =
                                      !_isConfirmPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),

                        // Student/Graduate Fields
                        if (_selectedRole == 'student' ||
                            _selectedRole == 'graduate') ...[
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedUniversityId,
                              decoration: InputDecoration(
                                labelText: 'University',
                                prefixIcon: const Icon(Icons.school_outlined),
                                suffixIcon: _isLoading
                                    ? const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : (_universitiesError != null
                                          ? IconButton(
                                              tooltip:
                                                  'Retry loading universities',
                                              icon: const Icon(Icons.refresh),
                                              onPressed: () =>
                                                  _loadData(forceRefresh: true),
                                            )
                                          : null),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              hint: const Text('Select your university'),
                              isExpanded: true,
                              items: _universities.isEmpty
                                  ? [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          _isLoading
                                              ? 'Loading universities...'
                                              : 'Tap refresh to load universities',
                                        ),
                                      ),
                                    ]
                                  : _universities.map<DropdownMenuItem<String>>(
                                      (uni) {
                                        return DropdownMenuItem<String>(
                                          value: uni['university_id']
                                              .toString(),
                                          child: Text(
                                            uni['name'],
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        );
                                      },
                                    ).toList(),
                              onChanged: _universities.isEmpty
                                  ? null
                                  : (v) {
                                      setState(() {
                                        _selectedUniversityId = v;
                                      });
                                    },
                              validator: (v) {
                                if (_universities.isEmpty) {
                                  return 'Universities unavailable. Tap refresh icon.';
                                }
                                return v == null
                                    ? 'Please select a university'
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _programController,
                            decoration: InputDecoration(
                              labelText: 'Program / Course',
                              prefixIcon: const Icon(Icons.book_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Program is required';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          if (_selectedRole == 'student') ...[
                            const Text('Student Type:'),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'current',
                                  label: Text('Current Student'),
                                ),
                              ],
                              selected: {'current'},
                              onSelectionChanged: (_) {},
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<int>(
                              initialValue: _expectedGraduationYear,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Expected Graduation Year',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _years.map<DropdownMenuItem<int>>((year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _expectedGraduationYear = v),
                              validator: (v) => v == null
                                  ? 'Please select graduation year'
                                  : null,
                            ),
                          ],

                          if (_selectedRole == 'graduate') ...[
                            const Text('Graduate Type:'),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'graduate',
                                  label: Text('Graduate'),
                                ),
                              ],
                              selected: {'graduate'},
                              onSelectionChanged: (_) {},
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<int>(
                              initialValue: _graduationYear,
                              isExpanded: true,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black),
                              decoration: InputDecoration(
                                labelText: 'Graduation Year',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: _years.map<DropdownMenuItem<int>>((year) {
                                return DropdownMenuItem<int>(
                                  value: year,
                                  child: Text(
                                    year.toString(),
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) =>
                                  setState(() => _graduationYear = v),
                              validator: (v) => v == null
                                  ? 'Please select graduation year'
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: _experienceLevel,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: 'Experience Level',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'no_experience',
                                  child: Text('No Experience'),
                                ),
                                DropdownMenuItem(
                                  value: '0-1',
                                  child: Text('0-1 Year'),
                                ),
                                DropdownMenuItem(
                                  value: '1-2',
                                  child: Text('1-2 Years'),
                                ),
                                DropdownMenuItem(
                                  value: '2-3',
                                  child: Text('2-3 Years'),
                                ),
                                DropdownMenuItem(
                                  value: '3+',
                                  child: Text('3+ Years'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _experienceLevel = v!),
                              validator: (v) => v == null
                                  ? 'Please select experience level'
                                  : null,
                            ),
                          ],
                        ],

                        // Company Fields
                        if (_selectedRole == 'company') ...[
                          TextFormField(
                            controller: _companyNameController,
                            decoration: InputDecoration(
                              labelText: 'Company Name',
                              prefixIcon: const Icon(Icons.business_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v?.isEmpty ?? true
                                ? 'Company name is required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedIndustry,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Industry',
                              prefixIcon: const Icon(Icons.factory_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _industries.map<DropdownMenuItem<String>>((
                              industry,
                            ) {
                              return DropdownMenuItem<String>(
                                value: industry,
                                child: Text(
                                  industry,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            selectedItemBuilder: (context) {
                              return _industries.map((industry) {
                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    industry,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            },
                            onChanged: (v) =>
                                setState(() => _selectedIndustry = v),
                            validator: (v) =>
                                v == null ? 'Please select industry' : null,
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedCompanySize,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Company Size',
                              prefixIcon: const Icon(Icons.people_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: _companySizes.map<DropdownMenuItem<String>>((
                              size,
                            ) {
                              return DropdownMenuItem<String>(
                                value: size,
                                child: Text('$size employees'),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCompanySize = v),
                            validator: (v) =>
                                v == null ? 'Please select company size' : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _companyLocationController,
                            decoration: InputDecoration(
                              labelText: 'Location',
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v?.isEmpty ?? true
                                ? 'Location is required'
                                : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _companyDescriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Company Description',
                              prefixIcon: const Icon(
                                Icons.description_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 28),

                        // Register Button
                        ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleRegister,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  'REGISTER',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // Back to Login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Already have an account? ",
                              style: AppTheme.caption,
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'Login',
                                style: TextStyle(
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // Divider
                        const Divider(),

                        const SizedBox(height: 8),

                        // Copyright
                        Text(
                          '© 2026 Developed by DEVELOPER GINGER',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jamhuri ya Muungano wa Tanzania',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 9,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
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
