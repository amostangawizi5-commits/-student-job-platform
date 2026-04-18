// lib/screens/auth/register_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../admin/admin_dashboard.dart';
import '../company/company_dashboard.dart';
import '../student/student_dashboard.dart';
import '../university/university_dashboard.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _programController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _universityNameController = TextEditingController();
  final _collegeRegNoController = TextEditingController();
  final _collegeEmailController = TextEditingController();
  final _collegePhoneController = TextEditingController();
  final _collegeAddressController = TextEditingController();
  final _collegeRegionController = TextEditingController();
  final _collegeDistrictController = TextEditingController();
  final _collegeWebsiteController = TextEditingController();
  final _coordinatorNameController = TextEditingController();
  final _coordinatorPhoneController = TextEditingController();
  final _coordinatorEmailController = TextEditingController();
  final _universityPasswordController = TextEditingController();
  final _universityConfirmPasswordController = TextEditingController();

  final _companyNameController = TextEditingController();
  final _companyLocationController = TextEditingController();
  final _companyDescriptionController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isUniversityPasswordVisible = false;
  bool _isUniversityConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showStudentIdError = false;
  bool _showCollegeLogoError = false;

  String? _selectedRole;
  String? _selectedUniversityId;
  String? _selectedCollegeUniversityId;
  int? _expectedGraduationYear;
  String? _selectedIndustry;
  String? _selectedCompanySize;
  String? _selectedCollegeType;
  String? _universitiesError;
  PlatformFile? _selectedStudentIdFile;
  PlatformFile? _selectedCollegeLogoFile;
  List<dynamic> _universities = [];

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

  final List<String> _collegeTypes = ['TCU'];

  late final List<int> _studentExpectedYears = List<int>.generate(
    11,
    (i) => DateTime.now().year + i,
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
    _registrationNumberController.dispose();
    _universityNameController.dispose();
    _collegeRegNoController.dispose();
    _collegeEmailController.dispose();
    _collegePhoneController.dispose();
    _collegeAddressController.dispose();
    _collegeRegionController.dispose();
    _collegeDistrictController.dispose();
    _collegeWebsiteController.dispose();
    _coordinatorNameController.dispose();
    _coordinatorPhoneController.dispose();
    _coordinatorEmailController.dispose();
    _universityPasswordController.dispose();
    _universityConfirmPasswordController.dispose();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _universitiesError = ApiService.normalizeErrorMessage(
          e,
          fallback: context.read<LanguageProvider>().tr(
            'no_universities_available_right_now',
          ),
        );
      });
    }
  }

  Future<void> _pickStudentIdCard() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > 5 * 1024 * 1024) {
        _showSnackBar('File size should be less than 5MB', isError: true);
        return;
      }

      if (!_isPdfFile(file)) {
        _showSnackBar(
          'Only PDF files are allowed for identification cards.',
          isError: true,
        );
        return;
      }

      if ((file.path == null || file.path!.isEmpty) && file.bytes == null) {
        _showSnackBar('Selected file could not be read', isError: true);
        return;
      }

      setState(() {
        _selectedStudentIdFile = file;
        _showStudentIdError = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        ApiService.normalizeErrorMessage(
          e,
          fallback: 'Failed to pick identification card.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _pickCollegeLogo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.size > 5 * 1024 * 1024) {
        _showSnackBar('File size should be less than 5MB', isError: true);
        return;
      }

      if ((file.path == null || file.path!.isEmpty) && file.bytes == null) {
        _showSnackBar('Selected file could not be read', isError: true);
        return;
      }

      setState(() {
        _selectedCollegeLogoFile = file;
        _showCollegeLogoError = false;
      });
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        ApiService.normalizeErrorMessage(
          e,
          fallback: 'Failed to pick college logo.',
        ),
        isError: true,
      );
    }
  }

  void _resetRoleSelection() {
    setState(() {
      _selectedRole = null;
      _showStudentIdError = false;
      _showCollegeLogoError = false;
    });
  }

  Map<String, dynamic>? _findUniversityById(String? universityId) {
    if (universityId == null || universityId.trim().isEmpty) {
      return null;
    }

    for (final university in _universities) {
      if (university is Map &&
          university['university_id']?.toString() == universityId) {
        return Map<String, dynamic>.from(university);
      }
    }
    return null;
  }

  void _selectCollegeUniversity(String? universityId) {
    final selectedUniversity = _findUniversityById(universityId);
    setState(() {
      _selectedCollegeUniversityId = universityId;
      _universityNameController.text =
          selectedUniversity?['name']?.toString() ?? '';
    });
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _showStudentIdError = false;
      _showCollegeLogoError = false;
    });
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : AppTheme.primaryBlue,
      ),
    );
  }

  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes >= 1024 * 1024) {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    if (sizeInBytes >= 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$sizeInBytes B';
  }

  bool _isPdfFile(PlatformFile file) {
    final fileName = file.name.trim().toLowerCase();
    final filePath = (file.path ?? '').trim().toLowerCase();
    return fileName.endsWith('.pdf') || filePath.endsWith('.pdf');
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedRole == 'student' && _selectedStudentIdFile == null) {
      setState(() => _showStudentIdError = true);
      _showSnackBar(
        context.read<LanguageProvider>().tr('upload_identification_required'),
        isError: true,
      );
      return;
    }

    if (_selectedRole == 'student' &&
        _selectedStudentIdFile != null &&
        !_isPdfFile(_selectedStudentIdFile!)) {
      setState(() => _showStudentIdError = true);
      _showSnackBar(
        'Only PDF files are allowed for identification cards.',
        isError: true,
      );
      return;
    }

    if (_selectedRole == 'university' && _selectedCollegeLogoFile == null) {
      setState(() => _showCollegeLogoError = true);
      _showSnackBar(
        context.read<LanguageProvider>().tr('upload_college_logo_required'),
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final userData = <String, dynamic>{'role': _selectedRole};

    if (_selectedRole == 'student') {
      userData.addAll({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      userData.addAll({
        'university_id': _selectedUniversityId,
        'program': _programController.text.trim(),
        'student_type': 'current',
        'expected_graduation_year': _expectedGraduationYear,
        'registration_number': _registrationNumberController.text.trim(),
      });
    } else if (_selectedRole == 'company') {
      userData.addAll({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      });
      userData.addAll({
        'company_name': _companyNameController.text.trim(),
        'industry': _selectedIndustry,
        'company_size': _selectedCompanySize,
        'location': _companyLocationController.text.trim(),
        'description': _companyDescriptionController.text.trim(),
      });
    } else if (_selectedRole == 'university') {
      userData.addAll({
        'email': _collegeEmailController.text.trim(),
        'password': _universityPasswordController.text,
        'full_name': _universityNameController.text.trim(),
        'phone': _collegePhoneController.text.trim(),
        'university_id': _selectedCollegeUniversityId,
        'college_name': _universityNameController.text.trim(),
        'registration_number': _collegeRegNoController.text.trim(),
        'college_email': _collegeEmailController.text.trim(),
        'college_phone': _collegePhoneController.text.trim(),
        'address': _collegeAddressController.text.trim(),
        'region': _collegeRegionController.text.trim(),
        'district': _collegeDistrictController.text.trim(),
        'website_url': _collegeWebsiteController.text.trim(),
        'college_type': _selectedCollegeType,
        'coordinator_name': _coordinatorNameController.text.trim(),
        'coordinator_phone': _coordinatorPhoneController.text.trim(),
        'coordinator_email': _coordinatorEmailController.text.trim(),
      });
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.register(
      userData,
      identificationCardFilePath: _selectedStudentIdFile?.path,
      identificationCardFileBytes: _selectedStudentIdFile?.bytes,
      identificationCardFileName: _selectedStudentIdFile?.name,
      collegeLogoFilePath: _selectedCollegeLogoFile?.path,
      collegeLogoFileBytes: _selectedCollegeLogoFile?.bytes,
      collegeLogoFileName: _selectedCollegeLogoFile?.name,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      _showSuccessDialog(authProvider);
      return;
    }

    final language = context.read<LanguageProvider>();
    final errorMessage =
        authProvider.errorMessage ??
        language.tr('please_check_information_try_again');

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                style: const TextStyle(
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
                    style: const TextStyle(
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

  void _showSuccessDialog(AuthProvider authProvider) {
    final language = context.read<LanguageProvider>();
    final displayName = _selectedRole == 'university'
        ? _universityNameController.text.trim()
        : _fullNameController.text.trim();
    final displayEmail = _selectedRole == 'university'
        ? _collegeEmailController.text.trim()
        : _emailController.text.trim();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
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
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                language.tr('registration_successful'),
                style: const TextStyle(
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
                  style: const TextStyle(
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
                        displayName,
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
                        displayEmail,
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
                    } else if (role == 'university') {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UniversityDashboard(),
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
                    style: const TextStyle(
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
  }

  Widget _buildHeader(LanguageProvider language) {
    return Column(
      children: [
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
    );
  }

  Widget _buildRoleSelection(LanguageProvider language, bool isWideScreen) {
    final cards = [
      _RoleCardData(
        title: language.tr('student'),
        onTap: () => _selectRole('student'),
      ),
      _RoleCardData(
        title: language.tr('company'),
        onTap: () => _selectRole('company'),
      ),
      _RoleCardData(
        title: language.tr('university'),
        onTap: () => _selectRole('university'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          language.tr('choose_account_type'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          language.tr('choose_account_type_subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final cardWidth = isWideScreen
                ? 160.0
                : ((maxWidth - 12) / 2).clamp(140.0, maxWidth);

            return Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: cards.map((card) {
                return SizedBox(
                  width: cardWidth,
                  child: _RegisterRoleCard(data: card),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCommonFields(LanguageProvider language, bool isDesktop) {
    final children = [
      _ResponsiveField(
        child: TextFormField(
          controller: _fullNameController,
          decoration: InputDecoration(
            labelText: language.tr('full_name'),
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: language.tr('email'),
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
              r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
            ).hasMatch(value)) {
              return language.tr('enter_valid_email_address');
            }
            return null;
          },
        ),
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: language.tr('phone_number'),
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            hintText: language.tr('phone_hint_tz'),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return language.tr('phone_number_required');
            }
            final phone = value.replaceAll(RegExp(r'[\s\-]'), '');
            if (!RegExp(r'^(0|\+255)[0-9]{9}$').hasMatch(phone)) {
              return language.tr('enter_valid_tanzanian_phone');
            }
            return null;
          },
        ),
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: language.tr('password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textLight,
              ),
              onPressed: () {
                setState(() {
                  _isPasswordVisible = !_isPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
      _ResponsiveField(
        child: TextFormField(
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
                  _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                });
              },
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
      ),
    ];

    return _buildResponsiveFields(children, isDesktop: isDesktop);
  }

  Widget _buildStudentFields(LanguageProvider language, bool isDesktop) {
    final children = [
      _ResponsiveField(
        child: Container(
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
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : (_universitiesError != null
                        ? IconButton(
                            tooltip: language.tr('retry_loading_universities'),
                            icon: const Icon(Icons.refresh),
                            onPressed: () => _loadData(forceRefresh: true),
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
                    DropdownMenuItem<String>(
                      value: null,
                      child: Text(
                        _isLoading
                            ? language.tr('loading_universities')
                            : language.tr('tap_refresh_to_load_universities'),
                      ),
                    ),
                  ]
                : _universities.map<DropdownMenuItem<String>>((uni) {
                    return DropdownMenuItem<String>(
                      value: uni['university_id'].toString(),
                      child: Text(
                        '${uni['name']}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
            onChanged: _universities.isEmpty
                ? null
                : (value) {
                    setState(() => _selectedUniversityId = value);
                  },
            validator: (value) {
              if (_universities.isEmpty) {
                return language.tr('universities_unavailable_refresh');
              }
              return value == null
                  ? language.tr('please_select_university')
                  : null;
            },
          ),
        ),
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _programController,
          decoration: InputDecoration(
            labelText: language.tr('program_course'),
            prefixIcon: const Icon(Icons.book_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return language.tr('program_required');
            }
            return null;
          },
        ),
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _registrationNumberController,
          decoration: InputDecoration(
            labelText: language.tr('registration_number'),
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return language.tr('registration_number_required');
            }
            return null;
          },
        ),
      ),
      _ResponsiveField(
        child: DropdownButtonFormField<int>(
          initialValue: _expectedGraduationYear,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: language.tr('expected_graduation_year'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _studentExpectedYears.map((year) {
            return DropdownMenuItem<int>(
              value: year,
              child: Text(year.toString()),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _expectedGraduationYear = value);
          },
          validator: (value) {
            return value == null
                ? language.tr('please_select_graduation_year')
                : null;
          },
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildResponsiveFields(children, isDesktop: isDesktop),
        const SizedBox(height: 14),
        _buildStudentIdUploader(language),
      ],
    );
  }

  Widget _buildStudentIdUploader(LanguageProvider language) {
    return _buildUploadCard(
      title: language.tr('identification_card'),
      hint: language.tr('upload_identification_hint'),
      buttonLabel: language.tr('upload_identification_card'),
      file: _selectedStudentIdFile,
      hasError: _showStudentIdError,
      errorText: language.tr('upload_identification_required'),
      onPick: _pickStudentIdCard,
      onClear: () {
        setState(() => _selectedStudentIdFile = null);
      },
      icon: Icons.badge_outlined,
    );
  }

  Widget _buildCollegeLogoUploader(LanguageProvider language) {
    return _buildUploadCard(
      title: language.tr('college_logo'),
      hint: language.tr('upload_college_logo_hint'),
      buttonLabel: language.tr('upload_college_logo'),
      file: _selectedCollegeLogoFile,
      hasError: _showCollegeLogoError,
      errorText: language.tr('upload_college_logo_required'),
      onPick: _pickCollegeLogo,
      onClear: () {
        setState(() => _selectedCollegeLogoFile = null);
      },
      icon: Icons.image_outlined,
    );
  }

  Widget _buildUploadCard({
    required String title,
    required String hint,
    required String buttonLabel,
    required PlatformFile? file,
    required bool hasError,
    required String errorText,
    required VoidCallback onPick,
    required VoidCallback onClear,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasError ? Colors.red : Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : onPick,
            icon: const Icon(Icons.upload_file_outlined),
            label: Text(buttonLabel),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (file != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatFileSize(file.size),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting ? null : onClear,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ],
          if (hasError) ...[
            const SizedBox(height: 10),
            Text(
              errorText,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompanyFields(LanguageProvider language, bool isDesktop) {
    return _buildResponsiveFields([
      _ResponsiveField(
        child: TextFormField(
          controller: _companyNameController,
          decoration: InputDecoration(
            labelText: language.tr('company_name'),
            prefixIcon: const Icon(Icons.business_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            return value?.isEmpty ?? true
                ? language.tr('company_name_required')
                : null;
          },
        ),
      ),
      _ResponsiveField(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedIndustry,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: language.tr('industry'),
            prefixIcon: const Icon(Icons.factory_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _industries.map((industry) {
            return DropdownMenuItem<String>(
              value: industry,
              child: Text(
                industry,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedIndustry = value);
          },
          validator: (value) {
            return value == null ? language.tr('please_select_industry') : null;
          },
        ),
      ),
      _ResponsiveField(
        child: DropdownButtonFormField<String>(
          initialValue: _selectedCompanySize,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: language.tr('company_size'),
            prefixIcon: const Icon(Icons.people_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: _companySizes.map((size) {
            return DropdownMenuItem<String>(
              value: size,
              child: Text(language.tr('employees_count', {'size': size})),
            );
          }).toList(),
          onChanged: (value) {
            setState(() => _selectedCompanySize = value);
          },
          validator: (value) {
            return value == null
                ? language.tr('please_select_company_size')
                : null;
          },
        ),
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _companyLocationController,
          decoration: InputDecoration(
            labelText: language.tr('location'),
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            return value?.isEmpty ?? true
                ? language.tr('location_required')
                : null;
          },
        ),
      ),
      _ResponsiveField(
        fullWidth: true,
        child: TextFormField(
          controller: _companyDescriptionController,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: language.tr('company_description'),
            prefixIcon: const Icon(Icons.description_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    ], isDesktop: isDesktop);
  }

  Widget _buildUniversityFields(LanguageProvider language, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(language.tr('college_information')),
        const SizedBox(height: 12),
        _buildResponsiveFields([
          _ResponsiveField(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollegeUniversityId,
                decoration: InputDecoration(
                  labelText: language.tr('college_name'),
                  prefixIcon: const Icon(Icons.account_balance_outlined),
                  suffixIcon: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_universitiesError != null
                            ? IconButton(
                                tooltip: language.tr(
                                  'retry_loading_universities',
                                ),
                                icon: const Icon(Icons.refresh),
                                onPressed: () => _loadData(forceRefresh: true),
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
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            _isLoading
                                ? language.tr('loading_universities')
                                : language.tr(
                                    'tap_refresh_to_load_universities',
                                  ),
                          ),
                        ),
                      ]
                    : _universities.map<DropdownMenuItem<String>>((uni) {
                        return DropdownMenuItem<String>(
                          value: uni['university_id'].toString(),
                          child: Text(
                            '${uni['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                onChanged: _universities.isEmpty
                    ? null
                    : (value) {
                        _selectCollegeUniversity(value);
                      },
                validator: (value) {
                  if (_universities.isEmpty) {
                    return language.tr('universities_unavailable_refresh');
                  }
                  return value == null
                      ? language.tr('college_name_required')
                      : null;
                },
              ),
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: language.tr('college_reg_no'),
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              controller: _collegeRegNoController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('college_reg_no_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _collegeEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: language.tr('college_email'),
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('college_email_required');
                }
                if (!RegExp(
                  r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return language.tr('enter_valid_email_address');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _collegePhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: language.tr('college_phone'),
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('college_phone_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            fullWidth: true,
            child: TextFormField(
              controller: _collegeAddressController,
              decoration: InputDecoration(
                labelText: language.tr('college_address'),
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('college_address_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _collegeRegionController,
              decoration: InputDecoration(
                labelText: language.tr('college_region'),
                prefixIcon: const Icon(Icons.map_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('college_region_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _collegeDistrictController,
              decoration: InputDecoration(
                labelText: language.tr('college_district'),
                prefixIcon: const Icon(Icons.place_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('college_district_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _collegeWebsiteController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: language.tr('college_website'),
                prefixIcon: const Icon(Icons.language_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          _ResponsiveField(
            child: DropdownButtonFormField<String>(
              initialValue: _selectedCollegeType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: language.tr('college_type'),
                prefixIcon: const Icon(Icons.apartment_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: _collegeTypes.map((type) {
                return DropdownMenuItem<String>(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCollegeType = value);
              },
              validator: (value) {
                return value == null
                    ? language.tr('college_type_required')
                    : null;
              },
            ),
          ),
        ], isDesktop: isDesktop),
        const SizedBox(height: 14),
        _buildCollegeLogoUploader(language),
        const SizedBox(height: 22),
        _buildSectionTitle(language.tr('coordinator_information')),
        const SizedBox(height: 12),
        _buildResponsiveFields([
          _ResponsiveField(
            child: TextFormField(
              controller: _coordinatorNameController,
              decoration: InputDecoration(
                labelText: language.tr('coordinator_name'),
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('coordinator_name_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _coordinatorPhoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: language.tr('coordinator_phone'),
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('coordinator_phone_required');
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            fullWidth: true,
            child: TextFormField(
              controller: _coordinatorEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: language.tr('coordinator_email'),
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return language.tr('coordinator_email_required');
                }
                if (!RegExp(
                  r'^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$',
                ).hasMatch(value.trim())) {
                  return language.tr('enter_valid_email_address');
                }
                return null;
              },
            ),
          ),
        ], isDesktop: isDesktop),
        const SizedBox(height: 22),
        _buildSectionTitle(language.tr('account_security')),
        const SizedBox(height: 12),
        _buildResponsiveFields([
          _ResponsiveField(
            child: TextFormField(
              controller: _universityPasswordController,
              obscureText: !_isUniversityPasswordVisible,
              decoration: InputDecoration(
                labelText: language.tr('password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isUniversityPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppTheme.textLight,
                  ),
                  onPressed: () {
                    setState(() {
                      _isUniversityPasswordVisible =
                          !_isUniversityPasswordVisible;
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
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _universityConfirmPasswordController,
              obscureText: !_isUniversityConfirmPasswordVisible,
              decoration: InputDecoration(
                labelText: language.tr('confirm_password'),
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isUniversityConfirmPasswordVisible
                        ? Icons.visibility_off
                        : Icons.visibility,
                    color: AppTheme.textLight,
                  ),
                  onPressed: () {
                    setState(() {
                      _isUniversityConfirmPasswordVisible =
                          !_isUniversityConfirmPasswordVisible;
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
                if (value != _universityPasswordController.text) {
                  return language.tr('passwords_do_not_match');
                }
                return null;
              },
            ),
          ),
        ], isDesktop: isDesktop),
      ],
    );
  }

  Widget _buildResponsiveFields(
    List<_ResponsiveField> fields, {
    required bool isDesktop,
  }) {
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:
            fields
                .expand((field) => [field.child, const SizedBox(height: 14)])
                .toList()
              ..removeLast(),
      );
    }

    final rows = <Widget>[];
    int index = 0;

    while (index < fields.length) {
      final current = fields[index];
      if (current.fullWidth) {
        rows.add(current.child);
        index++;
      } else if (index + 1 < fields.length && !fields[index + 1].fullWidth) {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: current.child),
              const SizedBox(width: 14),
              Expanded(child: fields[index + 1].child),
            ],
          ),
        );
        index += 2;
      } else {
        rows.add(
          Row(
            children: [
              Expanded(child: current.child),
              const SizedBox(width: 14),
              const Expanded(child: SizedBox.shrink()),
            ],
          ),
        );
        index++;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: rows.expand((row) => [row, const SizedBox(height: 14)]).toList()
        ..removeLast(),
    );
  }

  Widget _buildForm(LanguageProvider language, bool isDesktop) {
    final roleLabel = _selectedRole == 'student'
        ? language.tr('student')
        : _selectedRole == 'company'
        ? language.tr('company')
        : language.tr('university');

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _isSubmitting ? null : _resetRoleSelection,
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                label: Text(language.tr('change_account_type')),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  roleLabel,
                  style: const TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            language.tr('create_new_account'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedRole == 'student'
                ? language.tr('student_registration_subtitle')
                : _selectedRole == 'company'
                ? language.tr('company_registration_subtitle')
                : language.tr('university_registration_subtitle'),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (_isLoading && _selectedRole == 'student') ...[
            Row(
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 8),
                Text(
                  language.tr('loading_universities'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (_selectedRole != 'university') ...[
            _buildSectionTitle(language.tr('basic_information')),
            const SizedBox(height: 12),
            _buildCommonFields(language, isDesktop),
            const SizedBox(height: 22),
          ],
          _buildSectionTitle(
            _selectedRole == 'student'
                ? language.tr('student_details')
                : _selectedRole == 'company'
                ? language.tr('company_details')
                : language.tr('university_details'),
          ),
          const SizedBox(height: 12),
          if (_selectedRole == 'student')
            _buildStudentFields(language, isDesktop)
          else if (_selectedRole == 'company')
            _buildCompanyFields(language, isDesktop)
          else
            _buildUniversityFields(language, isDesktop),
          const SizedBox(height: 28),
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
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final contentMaxWidth = isDesktop ? 960.0 : 640.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: Text(language.tr('create_account')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTheme.textDark,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 32 : 16,
                vertical: 16,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
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
                      padding: EdgeInsets.all(isDesktop ? 32 : 22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeader(language),
                          const SizedBox(height: 24),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: _selectedRole == null
                                ? _buildRoleSelection(language, isDesktop)
                                : _buildForm(language, isDesktop),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${language.tr('already_have_account')} ',
                                style: AppTheme.caption,
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: Text(
                                  language.tr('login'),
                                  style: const TextStyle(
                                    color: AppTheme.primaryBlue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
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
            );
          },
        ),
      ),
    );
  }
}

class _ResponsiveField {
  const _ResponsiveField({required this.child, this.fullWidth = false});

  final Widget child;
  final bool fullWidth;
}

class _RoleCardData {
  const _RoleCardData({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;
}

class _RegisterRoleCard extends StatelessWidget {
  const _RegisterRoleCard({required this.data});

  final _RoleCardData data;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: data.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: 88,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
          border: Border.all(color: const Color(0xFFD9DEE7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            data.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2F3A4A),
            ),
          ),
        ),
      ),
    );
  }
}
