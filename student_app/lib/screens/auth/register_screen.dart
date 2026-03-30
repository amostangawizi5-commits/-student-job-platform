// lib/screens/auth/register_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../admin/admin_dashboard.dart';
import '../company/company_dashboard.dart';
import '../student/student_dashboard.dart';

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

  final List<int> _years = List<int>.generate(
    DateTime.now().year - 2000 + 11,
    (i) => DateTime.now().year + 10 - i,
  );

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
                  context.read<LanguageProvider>().tr(
                    'no_universities_available_right_now',
                  ))
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
        final language = context.read<LanguageProvider>();
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
                  Text(
                    language.tr('registration_successful'),
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
                    child: Text(
                      language.tr('welcome_to_government_internship_system'),
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
                        final role = authProvider.user?['role'];

                        if (role == 'student' || role == 'graduate') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const StudentDashboard(),
                            ),
                            (route) => false,
                          );
                        } else if (role == 'company') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CompanyDashboard(),
                            ),
                            (route) => false,
                          );
                        } else if (role == 'admin') {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminDashboard(),
                            ),
                            (route) => false,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        language.tr('continue'),
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
                    language.tr('next_create_app_pin'),
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        );
      } else if (mounted) {
        final language = context.read<LanguageProvider>();
        final errorMessage =
            authProvider.errorMessage ??
            language.tr('please_check_information_try_again');
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
                  Text(
                    language.tr('registration_failed'),
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
                      child: Text(
                        language.tr('try_again'),
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
    final language = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(language.tr('create_account')),
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
                            Text(
                              language.tr('united_republic_of_tanzania'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
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
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF666666),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              language.tr('empowering_tanzanian_youth'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                color: Color(0xFF888888),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Title
                        Text(
                          language.tr('create_new_account'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
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
                                language.tr('loading_universities'),
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
                        Text(
                          language.tr('i_am_a'),
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
                          segments: [
                            ButtonSegment(
                              value: 'student',
                              label: Text(language.tr('student')),
                            ),
                            ButtonSegment(
                              value: 'graduate',
                              label: Text(language.tr('graduate')),
                            ),
                            ButtonSegment(
                              value: 'company',
                              label: Text(language.tr('company')),
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
                            labelText: language.tr('full_name'),
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return language.tr('full_name_required');
                            }
                            if (value.trim().length < 3) {
                              return language.tr('full_name_min_3');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            labelText: language.tr('email'),
                            prefixIcon: const Icon(Icons.email_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return language.tr('email_required');
                            }
                            if (!value.contains('@')) {
                              return language.tr('email_must_contain_at');
                            }
                            if (!value.contains('.')) {
                              return language.tr('email_must_contain_domain');
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return language.tr('enter_valid_email_address');
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: language.tr('phone_number'),
                            prefixIcon: const Icon(Icons.phone_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: language.tr('phone_hint_tz'),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return language.tr('phone_number_required');
                            }
                            final phone = value.replaceAll(
                              RegExp(r'[\s\-]'),
                              '',
                            );
                            if (!RegExp(
                              r'^(0|\+255)[0-9]{9}$',
                            ).hasMatch(phone)) {
                              return language.tr('enter_valid_tanzanian_phone');
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
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            helperText: language.tr('password_helper'),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return language.tr('password_required');
                            }
                            if (value.length < 8) {
                              return language.tr('password_min_8');
                            }
                            if (!RegExp(r'[A-Z]').hasMatch(value)) {
                              return language.tr('password_uppercase_required');
                            }
                            if (!RegExp(r'[a-z]').hasMatch(value)) {
                              return language.tr('password_lowercase_required');
                            }
                            if (!RegExp(r'[0-9]').hasMatch(value)) {
                              return language.tr('password_number_required');
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
                            labelText: language.tr('confirm_password'),
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
                              return language.tr('please_confirm_password');
                            }
                            if (value != _passwordController.text) {
                              return language.tr('passwords_do_not_match');
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
                                labelText: language.tr('university'),
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
                                              tooltip: language.tr(
                                                'retry_loading_universities',
                                              ),
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
                              hint: Text(language.tr('select_your_university')),
                              isExpanded: true,
                              items: _universities.isEmpty
                                  ? [
                                      DropdownMenuItem(
                                        value: null,
                                        child: Text(
                                          _isLoading
                                              ? language.tr(
                                                  'loading_universities',
                                                )
                                              : language.tr(
                                                  'tap_refresh_to_load_universities',
                                                ),
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
                                  return language.tr(
                                    'universities_unavailable_refresh',
                                  );
                                }
                                return v == null
                                    ? language.tr('please_select_university')
                                    : null;
                              },
                            ),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _programController,
                            decoration: InputDecoration(
                              labelText: language.tr('program_course'),
                              prefixIcon: const Icon(Icons.book_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return language.tr('program_required');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 14),

                          if (_selectedRole == 'student') ...[
                            Text(language.tr('student_type')),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                  value: 'current',
                                  label: Text(language.tr('current_student')),
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
                                labelText: language.tr(
                                  'expected_graduation_year',
                                ),
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
                                  ? language.tr('please_select_graduation_year')
                                  : null,
                            ),
                          ],

                          if (_selectedRole == 'graduate') ...[
                            Text(language.tr('graduate_type')),
                            const SizedBox(height: 8),
                            SegmentedButton<String>(
                              segments: [
                                ButtonSegment(
                                  value: 'graduate',
                                  label: Text(language.tr('graduate')),
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
                                labelText: language.tr('graduation_year'),
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
                                  ? language.tr('please_select_graduation_year')
                                  : null,
                            ),
                            const SizedBox(height: 14),

                            DropdownButtonFormField<String>(
                              initialValue: _experienceLevel,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: language.tr('experience_level'),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'no_experience',
                                  child: Text(language.tr('no_experience')),
                                ),
                                DropdownMenuItem(
                                  value: '0-1',
                                  child: Text(
                                    language.tr('experience_0_1_year'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '1-2',
                                  child: Text(
                                    language.tr('experience_1_2_years'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '2-3',
                                  child: Text(
                                    language.tr('experience_2_3_years'),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: '3+',
                                  child: Text(
                                    language.tr('experience_3_plus_years'),
                                  ),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _experienceLevel = v!),
                              validator: (v) => v == null
                                  ? language.tr(
                                      'please_select_experience_level',
                                    )
                                  : null,
                            ),
                          ],
                        ],

                        // Company Fields
                        if (_selectedRole == 'company') ...[
                          TextFormField(
                            controller: _companyNameController,
                            decoration: InputDecoration(
                              labelText: language.tr('company_name'),
                              prefixIcon: const Icon(Icons.business_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v?.isEmpty ?? true
                                ? language.tr('company_name_required')
                                : null,
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedIndustry,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: language.tr('industry'),
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
                            validator: (v) => v == null
                                ? language.tr('please_select_industry')
                                : null,
                          ),
                          const SizedBox(height: 14),

                          DropdownButtonFormField<String>(
                            initialValue: _selectedCompanySize,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: language.tr('company_size'),
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
                                child: Text(
                                  language.tr('employees_count', {
                                    'size': size,
                                  }),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCompanySize = v),
                            validator: (v) => v == null
                                ? language.tr('please_select_company_size')
                                : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _companyLocationController,
                            decoration: InputDecoration(
                              labelText: language.tr('location'),
                              prefixIcon: const Icon(
                                Icons.location_on_outlined,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v?.isEmpty ?? true
                                ? language.tr('location_required')
                                : null,
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _companyDescriptionController,
                            maxLines: 3,
                            decoration: InputDecoration(
                              labelText: language.tr('company_description'),
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
                              : Text(
                                  language.tr('register'),
                                  style: const TextStyle(
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
                              '${language.tr('already_have_account')} ',
                              style: AppTheme.caption,
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                language.tr('login'),
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
                          '© 2026 ${language.tr('developed_by_name', {'name': 'DEVELOPER GINGER'})}',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          language.tr('united_republic_of_tanzania'),
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
