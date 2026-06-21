// lib/screens/auth/register_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';

import '../../data/tanzania_locations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import '../../utils/user_role.dart';
import '../admin/admin_dashboard.dart';
import '../home_screen.dart' as public_home;
import '../organization/organization_dashboard.dart';
import '../student/student_dashboard.dart';
import '../university/university_dashboard.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiService = ApiService();
  final PageController _trainingPreviewController = PageController();

  final _firstNameController = TextEditingController();
  final _secondNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _programController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _studentInstitutionController = TextEditingController();
  final _universityNameController = TextEditingController();
  final _collegeRegNoController = TextEditingController();
  final _collegeEmailController = TextEditingController();
  final _collegePhoneController = TextEditingController();
  final _collegeAddressController = TextEditingController();
  final _collegeRegionController = TextEditingController();
  final _collegeDistrictController = TextEditingController();
  final _collegeWebsiteController = TextEditingController();
  final _coordinatorFirstNameController = TextEditingController();
  final _coordinatorSecondNameController = TextEditingController();
  final _coordinatorPhoneController = TextEditingController();
  final _coordinatorEmailController = TextEditingController();
  final _universityPasswordController = TextEditingController();
  final _universityConfirmPasswordController = TextEditingController();

  final _organizationNameController = TextEditingController();
  final _organizationLocationController = TextEditingController();
  final _organizationTinController = TextEditingController();
  final _organizationBrelaController = TextEditingController();
  final _organizationBusinessLicenseController = TextEditingController();
  final _organizationDepartmentController = TextEditingController();
  final _organizationSectorController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isUniversityPasswordVisible = false;
  bool _isUniversityConfirmPasswordVisible = false;
  bool _isLoading = false;
  bool _isSubmitting = false;
  bool _showStudentIdError = false;
  bool _showCollegeLogoError = false;
  int _trainingPreviewIndex = 0;

  String? _selectedRole;
  String? _selectedUniversityId;
  String? _selectedCollegeUniversityId;
  int? _expectedGraduationYear;
  String? _selectedOrganizationSubtype;
  String? _selectedGovernmentCategory;
  String? _selectedCollegeType;
  String? _selectedCollegeRegion;
  String? _selectedCollegeDistrict;
  String? _universitiesError;
  String? _governmentError;
  PlatformFile? _selectedStudentIdFile;
  PlatformFile? _selectedCollegeLogoFile;
  List<dynamic> _institutions = [];
  List<dynamic> _universities = [];
  List<dynamic> _government = [];

  final List<Map<String, String>> _organizationSubtypes = const [
    {'value': 'private_sector', 'label': 'Private Sector'},
    {'value': 'government_sector', 'label': 'Government Sector'},
  ];

  final List<String> _governmentSectorCategories = const [
    'Ministry',
    'Agency',
    'Authority',
    'Local Government',
    'Public Institution',
  ];

  final List<String> _collegeTypes = ['TCU'];
  final List<String> _institutionTypes = [
    'Government Office',
    'Regional Office',
    'District Office',
    'Council',
    'Agency',
    'Authority',
    'Commission',
    'Public Institution',
  ];

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
    _firstNameController.dispose();
    _secondNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _programController.dispose();
    _registrationNumberController.dispose();
    _studentInstitutionController.dispose();
    _universityNameController.dispose();
    _collegeRegNoController.dispose();
    _collegeEmailController.dispose();
    _collegePhoneController.dispose();
    _collegeAddressController.dispose();
    _collegeRegionController.dispose();
    _collegeDistrictController.dispose();
    _collegeWebsiteController.dispose();
    _coordinatorFirstNameController.dispose();
    _coordinatorSecondNameController.dispose();
    _coordinatorPhoneController.dispose();
    _coordinatorEmailController.dispose();
    _universityPasswordController.dispose();
    _universityConfirmPasswordController.dispose();
    _organizationNameController.dispose();
    _organizationLocationController.dispose();
    _organizationTinController.dispose();
    _organizationBrelaController.dispose();
    _organizationBusinessLicenseController.dispose();
    _organizationDepartmentController.dispose();
    _organizationSectorController.dispose();
    _trainingPreviewController.dispose();
    super.dispose();
  }

  void _goHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const public_home.HomeScreen()),
      (route) => false,
    );
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _apiService.get('/api/auth/', requiresAuth: false),
        _apiService.getUniversities(forceRefresh: forceRefresh),
        _apiService.getGovernment(forceRefresh: forceRefresh),
      ]);
      if (!mounted) return;

      final institutionsResponse = responses[0];
      final universitiesResponse = responses[1];
      final governmentResponse = responses[2];
      final dynamic raw = institutionsResponse['data'];
      List<dynamic> institutions = [];
      if (raw is List) {
        institutions = raw;
      } else if (raw is Map && raw['institutions'] is List) {
        institutions = raw['institutions'] as List<dynamic>;
      }

      final dynamic rawUniversities = universitiesResponse['data'];
      List<dynamic> universities = [];
      if (rawUniversities is List) {
        universities = rawUniversities;
      } else if (rawUniversities is Map &&
          rawUniversities['universities'] is List) {
        universities = rawUniversities['universities'] as List<dynamic>;
      }

      final dynamic rawGovernment = governmentResponse['data'];
      List<dynamic> government = [];
      if (rawGovernment is List) {
        government = rawGovernment;
      } else if (rawGovernment is Map && rawGovernment['government'] is List) {
        government = rawGovernment['government'] as List<dynamic>;
      }

      setState(() {
        _institutions = _dedupeInstitutionList(institutions);
        _universities = _dedupeInstitutionList(universities);
        _government = _dedupeInstitutionList(government);
        _universitiesError = universities.isEmpty
            ? (universitiesResponse['message']?.toString() ??
                  context.read<LanguageProvider>().tr(
                    'no_universities_available_right_now',
                  ))
            : null;
        _governmentError = government.isEmpty
            ? (governmentResponse['message']?.toString() ??
                  context.read<LanguageProvider>().tr(
                    'no_government_offices_available_right_now',
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
        _governmentError = ApiService.normalizeErrorMessage(
          e,
          fallback: context.read<LanguageProvider>().tr(
            'no_government_offices_available_right_now',
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
      _selectedUniversityId = null;
      _selectedOrganizationSubtype = null;
      _selectedGovernmentCategory = null;
      _showStudentIdError = false;
      _showCollegeLogoError = false;
      _selectedCollegeRegion = null;
      _selectedCollegeDistrict = null;
      _selectedCollegeUniversityId = null;
      _studentInstitutionController.clear();
      _organizationNameController.clear();
      _organizationLocationController.clear();
      _organizationTinController.clear();
      _organizationBrelaController.clear();
      _organizationBusinessLicenseController.clear();
      _organizationDepartmentController.clear();
      _organizationSectorController.clear();
      _collegeRegionController.clear();
      _collegeDistrictController.clear();
      _universityNameController.clear();
    });
  }

  String _institutionDedupeKey(dynamic value) {
    final name = value is Map ? '${value['name'] ?? ''}' : '';
    final normalized = name
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    if (normalized == 'university of dodoma' ||
        normalized == 'university of dodoma (udom)' ||
        normalized == 'udom') {
      return 'university of dodoma (udom)';
    }
    return normalized;
  }

  List<dynamic> _dedupeInstitutionList(List<dynamic> institutions) {
    final byName = <String, dynamic>{};

    for (final institution in institutions) {
      final key = _institutionDedupeKey(institution);
      if (key.isEmpty) continue;

      final current = byName[key];
      final candidateName = institution is Map
          ? '${institution['name'] ?? ''}'.trim()
          : '';
      final currentName = current is Map
          ? '${current['name'] ?? ''}'.trim()
          : '';
      final candidateIsOfficialUdom =
          candidateName == 'University of Dodoma (UDOM)';
      final currentIsOfficialUdom =
          currentName == 'University of Dodoma (UDOM)';
      if (current == null ||
          (candidateIsOfficialUdom && !currentIsOfficialUdom)) {
        byName[key] = institution;
      }
    }

    return byName.values.toList(growable: false);
  }

  Map<String, dynamic>? _findInstitutionById(
    List<dynamic> institutions,
    String? institutionId,
  ) {
    if (institutionId == null || institutionId.trim().isEmpty) {
      return null;
    }

    for (final institution in institutions) {
      if (institution is Map &&
          institution['university_id']?.toString() == institutionId) {
        return Map<String, dynamic>.from(institution);
      }
    }
    return null;
  }

  void _selectInstitutionFromList(
    String? institutionId,
    List<dynamic> institutions,
  ) {
    final selectedInstitution = _findInstitutionById(
      institutions,
      institutionId,
    );
    setState(() {
      _selectedCollegeUniversityId = institutionId;
      _universityNameController.text =
          selectedInstitution?['name']?.toString() ?? '';
    });
  }

  Map<String, dynamic>? _findInstitutionByName(
    List<dynamic> institutions,
    String? institutionName,
  ) {
    final normalizedName = institutionName?.trim().toLowerCase() ?? '';
    if (normalizedName.isEmpty) {
      return null;
    }

    for (final institution in institutions) {
      if (institution is Map &&
          institution['name']?.toString().trim().toLowerCase() ==
              normalizedName) {
        return Map<String, dynamic>.from(institution);
      }
    }
    return null;
  }

  void _syncSelectedStudentInstitutionFromInput() {
    final match = _findInstitutionByName(
      _institutions,
      _studentInstitutionController.text,
    );
    _selectedUniversityId = match?['university_id']?.toString();
    if (match != null) {
      _studentInstitutionController.text = match['name']?.toString() ?? '';
    }
  }

  String _studentDisplayName() {
    final parts = [
      _firstNameController.text.trim(),
      _secondNameController.text.trim(),
    ].where((value) => value.isNotEmpty).toList(growable: false);
    return parts.join(' ');
  }

  String _normalizeLocationText(Object? value) {
    return '$value'.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  List<String> get _institutionRegions {
    final regions = tanzaniaRegionDistricts.keys.toList(growable: false);
    regions.sort();
    return regions;
  }

  List<String> get _institutionDistricts {
    final region = _selectedCollegeRegion;
    if (region == null || region.trim().isEmpty) {
      return const [];
    }

    final districts = List<String>.from(
      tanzaniaRegionDistricts[region] ?? const <String>[],
    );
    districts.sort();
    return districts;
  }

  bool get _isPrivateSectorOrganization =>
      _selectedOrganizationSubtype == 'private_sector';

  bool get _isGovernmentSectorOrganization =>
      _selectedOrganizationSubtype == 'government_sector';

  void _setOrganizationSubtype(String? subtype) {
    setState(() {
      _selectedOrganizationSubtype = subtype;

      if (subtype == 'private_sector') {
        _selectedGovernmentCategory = null;
        _organizationDepartmentController.clear();
        _organizationSectorController.clear();
      } else if (subtype == 'government_sector') {
        _organizationTinController.clear();
        _organizationBrelaController.clear();
        _organizationBusinessLicenseController.clear();
      } else {
        _selectedGovernmentCategory = null;
        _organizationTinController.clear();
        _organizationBrelaController.clear();
        _organizationBusinessLicenseController.clear();
        _organizationDepartmentController.clear();
        _organizationSectorController.clear();
      }
    });
  }

  bool _isNationwideInstitutionLocation(Object? location) {
    final normalized = _normalizeLocationText(location);
    if (normalized.isEmpty) return false;

    return normalized.contains('all regions') ||
        normalized.contains('nationwide') ||
        normalized.contains('all districts') ||
        normalized.contains('all wards') ||
        normalized.contains('all villages');
  }

  bool _isDistrictWideInstitutionLocation(Object? location) {
    final normalized = _normalizeLocationText(location);
    if (normalized.isEmpty) return false;

    return normalized.contains('district councils') ||
        normalized.contains('district hospitals') ||
        normalized.contains('city councils') ||
        normalized.contains('municipal councils') ||
        normalized.contains('town councils');
  }

  String? _resolveRegionFromLocation(Object? location) {
    final normalized = _normalizeLocationText(location);
    if (normalized.isEmpty) return null;

    for (final region in _institutionRegions) {
      final normalizedRegion = _normalizeLocationText(region);
      if (normalized == normalizedRegion ||
          normalized.contains(normalizedRegion)) {
        return region;
      }

      for (final district
          in tanzaniaRegionDistricts[region] ?? const <String>[]) {
        final normalizedDistrict = _normalizeLocationText(district);
        if (normalized == normalizedDistrict ||
            normalized.contains(normalizedDistrict)) {
          return region;
        }
      }
    }

    return null;
  }

  String? _resolveDistrictFromLocation(Object? location, String? region) {
    final normalized = _normalizeLocationText(location);
    if (normalized.isEmpty || region == null || region.trim().isEmpty) {
      return null;
    }

    for (final district
        in tanzaniaRegionDistricts[region] ?? const <String>[]) {
      final normalizedDistrict = _normalizeLocationText(district);
      if (normalized == normalizedDistrict ||
          normalized.contains(normalizedDistrict)) {
        return district;
      }
    }

    return null;
  }

  bool _matchesInstitutionRegion(
    Map<String, dynamic> institution,
    String region,
  ) {
    final location = institution['location'];
    if (_isNationwideInstitutionLocation(location)) {
      return true;
    }

    final resolvedRegion = _resolveRegionFromLocation(location);
    if (resolvedRegion != null) {
      return resolvedRegion == region;
    }

    return _normalizeLocationText(
      location,
    ).contains(_normalizeLocationText(region));
  }

  bool _matchesInstitutionDistrict(
    Map<String, dynamic> institution,
    String district,
  ) {
    final location = institution['location'];
    if (_isNationwideInstitutionLocation(location) ||
        _isDistrictWideInstitutionLocation(location)) {
      return true;
    }

    final resolvedDistrict = _resolveDistrictFromLocation(
      location,
      _selectedCollegeRegion,
    );
    if (resolvedDistrict != null) {
      return resolvedDistrict == district;
    }

    return _normalizeLocationText(
      location,
    ).contains(_normalizeLocationText(district));
  }

  List<dynamic> get _filteredGovernment {
    final region = _selectedCollegeRegion;
    if (region == null || region.trim().isEmpty) {
      return const [];
    }

    final district = _selectedCollegeDistrict;
    final filtered = _government
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .where((institution) => _matchesInstitutionRegion(institution, region))
        .where(
          (institution) =>
              district == null ||
              district.trim().isEmpty ||
              _matchesInstitutionDistrict(institution, district),
        )
        .toList(growable: false);

    filtered.sort((left, right) {
      int score(Map<String, dynamic> institution) {
        var value = 0;
        final location = institution['location'];
        final resolvedRegion = _resolveRegionFromLocation(location);
        final resolvedDistrict = _resolveDistrictFromLocation(
          location,
          _selectedCollegeRegion,
        );

        if (resolvedRegion == _selectedCollegeRegion) {
          value += 4;
        } else if (_isNationwideInstitutionLocation(location)) {
          value += 1;
        }

        if (_selectedCollegeDistrict != null &&
            _selectedCollegeDistrict!.trim().isNotEmpty) {
          if (resolvedDistrict == _selectedCollegeDistrict) {
            value += 4;
          } else if (_isDistrictWideInstitutionLocation(location)) {
            value += 1;
          }
        }

        return value;
      }

      final scoreCompare = score(right).compareTo(score(left));
      if (scoreCompare != 0) return scoreCompare;

      return '${left['name']}'.toLowerCase().compareTo(
        '${right['name']}'.toLowerCase(),
      );
    });

    return filtered;
  }

  void _setCollegeRegion(String? region) {
    setState(() {
      _selectedCollegeRegion = region;
      _collegeRegionController.text = region ?? '';
      _selectedCollegeDistrict = null;
      _collegeDistrictController.clear();
      _selectedCollegeUniversityId = null;
      _universityNameController.clear();
    });
  }

  void _setCollegeDistrict(String? district) {
    setState(() {
      _selectedCollegeDistrict = district;
      _collegeDistrictController.text = district ?? '';
      _selectedCollegeUniversityId = null;
      _universityNameController.clear();
    });
  }

  void _selectRole(String role) {
    setState(() {
      _selectedRole = role;
      _selectedUniversityId = null;
      _selectedOrganizationSubtype = null;
      _selectedGovernmentCategory = null;
      _showStudentIdError = false;
      _showCollegeLogoError = false;
      _selectedCollegeRegion = null;
      _selectedCollegeDistrict = null;
      _selectedCollegeUniversityId = null;
      _selectedCollegeType = null;
      _studentInstitutionController.clear();
      _organizationNameController.clear();
      _organizationLocationController.clear();
      _organizationTinController.clear();
      _organizationBrelaController.clear();
      _organizationBusinessLicenseController.clear();
      _organizationDepartmentController.clear();
      _organizationSectorController.clear();
      _collegeRegionController.clear();
      _collegeDistrictController.clear();
      _universityNameController.clear();
      _coordinatorFirstNameController.clear();
      _coordinatorSecondNameController.clear();
    });
  }

  String _coordinatorDisplayName() {
    return [
      _coordinatorFirstNameController.text.trim(),
      _coordinatorSecondNameController.text.trim(),
    ].where((part) => part.isNotEmpty).join(' ');
  }

  bool get _isUniversityLikeRole =>
      _selectedRole == 'university' || _selectedRole == 'institution';

  String _accountRoleLabel(LanguageProvider language, String? role) {
    switch (role) {
      case 'student':
        return language.tr('student');
      case 'organization':
        return 'Organization';
      case 'institution':
        return language.tr('other_institution');
      case 'university':
      default:
        return language.tr('university');
    }
  }

  String _accountSubtitle(LanguageProvider language) {
    switch (_selectedRole) {
      case 'student':
        return language.tr('student_registration_subtitle');
      case 'organization':
        return ' ';
      case 'institution':
        return language.tr('institution_registration_subtitle');
      case 'university':
      default:
        return language.tr('university_registration_subtitle');
    }
  }

  String _detailSectionLabel(LanguageProvider language) {
    switch (_selectedRole) {
      case 'student':
        return language.tr('student_details');
      case 'organization':
        return 'Organization Details';
      case 'institution':
        return language.tr('institution_details');
      case 'university':
      default:
        return language.tr('university_details');
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showAppSnackBar(
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
    if (_selectedRole == 'student') {
      _syncSelectedStudentInstitutionFromInput();
    }

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

    if (_isUniversityLikeRole && _selectedCollegeLogoFile == null) {
      setState(() => _showCollegeLogoError = true);
      _showSnackBar(
        context.read<LanguageProvider>().tr(
          _selectedRole == 'institution'
              ? 'upload_institution_logo_required'
              : 'upload_college_logo_required',
        ),
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final registrationRole = switch (_selectedRole) {
      'institution' => 'university',
      'organization' => 'company',
      _ => _selectedRole,
    };

    final userData = <String, dynamic>{'role': registrationRole};

    if (_selectedRole == 'student') {
      final studentName = _studentDisplayName();
      userData.addAll({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'first_name': _firstNameController.text.trim(),
        'second_name': _secondNameController.text.trim(),
        'full_name': studentName,
        'phone': _phoneController.text.trim(),
      });
      userData.addAll({
        'university_id': _selectedUniversityId,
        'institution_name': _studentInstitutionController.text.trim(),
        'program': _programController.text.trim(),
        'student_type': 'current',
        'expected_graduation_year': _expectedGraduationYear,
        'registration_number': _registrationNumberController.text.trim(),
      });
    } else if (_selectedRole == 'organization') {
      final organizationName = _organizationNameController.text.trim();
      userData.addAll({
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        'full_name': organizationName,
        'phone': _phoneController.text.trim(),
      });
      userData.addAll({
        'company_name': organizationName,
        'organization_name': organizationName,
        'organization_subtype': _selectedOrganizationSubtype,
        'government_category': _selectedGovernmentCategory,
        'tin_number': _organizationTinController.text.trim(),
        'brela_number': _organizationBrelaController.text.trim(),
        'business_license_number': _organizationBusinessLicenseController.text
            .trim(),
        'department': _organizationDepartmentController.text.trim(),
        'sector': _organizationSectorController.text.trim(),
        'location': _organizationLocationController.text.trim(),
      });
    } else if (_isUniversityLikeRole) {
      final coordinatorName = _coordinatorDisplayName();
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
        'coordinator_name': coordinatorName,
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
    final displayName = _isUniversityLikeRole
        ? _universityNameController.text.trim()
        : _selectedRole == 'student'
        ? _studentDisplayName()
        : _organizationNameController.text.trim();
    final displayEmail = _isUniversityLikeRole
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
                    final role = normalizeUserRole(authProvider.user?['role']);

                    if (isStudentRole(role)) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StudentDashboard(),
                        ),
                        (route) => false,
                      );
                    } else if (isCompanyRole(role)) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const OrganizationDashboard(),
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
          style: const TextStyle(fontSize: 10, color: Color(0xFF888888)),
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
        title: 'Organization',
        onTap: () => _selectRole('organization'),
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

  Widget _buildOrganizationTypeField() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedOrganizationSubtype,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Organization Type',
        prefixIcon: const Icon(Icons.account_tree_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      items: _organizationSubtypes.map((subtype) {
        return DropdownMenuItem<String>(
          value: subtype['value'],
          child: Text(subtype['label'] ?? ''),
        );
      }).toList(),
      onChanged: _setOrganizationSubtype,
      validator: (value) {
        if (_selectedRole != 'organization') {
          return null;
        }
        return value == null ? 'Please select organization type' : null;
      },
    );
  }

  Widget _buildCommonFields(LanguageProvider language, bool isDesktop) {
    final isGovernmentOrganization = _isGovernmentSectorOrganization;
    final children = <_ResponsiveField>[
      _ResponsiveField(
        child: TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: isGovernmentOrganization
                ? 'Official Email'
                : 'Email Address',
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return isGovernmentOrganization
                  ? 'Official email is required'
                  : 'Email address is required';
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
            labelText: 'Phone Number',
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

  Widget _buildStudentBasicFields(LanguageProvider language, bool isDesktop) {
    final children = [
      _ResponsiveField(
        child: TextFormField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: language.tr('first_name'),
            prefixIcon: const Icon(Icons.person_outline),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return language.tr('first_name_required');
            }
            if (value.trim().length < 2) {
              return language.tr('first_name_min_2');
            }
            return null;
          },
        ),
      ),
      _ResponsiveField(
        child: TextFormField(
          controller: _secondNameController,
          decoration: InputDecoration(
            labelText: language.tr('second_name'),
            prefixIcon: const Icon(Icons.badge_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return language.tr('second_name_required');
            }
            if (value.trim().length < 2) {
              return language.tr('second_name_min_2');
            }
            return null;
          },
        ),
      ),
      ..._buildBasicContactAndPasswordFields(language),
    ];

    return _buildResponsiveFields(children, isDesktop: isDesktop);
  }

  List<_ResponsiveField> _buildBasicContactAndPasswordFields(
    LanguageProvider language,
  ) {
    return [
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
  }

  Widget _buildStudentFields(LanguageProvider language, bool isDesktop) {
    final children = [
      _ResponsiveField(child: _buildStudentearchField(language)),
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

  Widget _buildStudentearchField(LanguageProvider language) {
    final universityOptions = _universities
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);

    return DropdownButtonFormField<String>(
      initialValue: _selectedUniversityId,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: language.tr('university'),
        hintText: language.tr('select_your_university'),
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
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        helperText: _universitiesError,
      ),
      items: universityOptions.map((university) {
        final universityId = university['university_id']?.toString();
        final location = '${university['location'] ?? ''}'.trim();
        final name = '${university['name'] ?? ''}'.trim();

        return DropdownMenuItem<String>(
          value: universityId,
          child: Text(
            location.isNotEmpty ? '$name • $location' : name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: universityOptions.isEmpty
          ? null
          : (value) {
              final selected = universityOptions
                  .cast<Map<String, dynamic>?>()
                  .firstWhere(
                    (item) => item?['university_id']?.toString() == value,
                    orElse: () => null,
                  );

              setState(() {
                _selectedUniversityId = value;
                _studentInstitutionController.text =
                    selected?['name']?.toString() ?? '';
              });
            },
      validator: (value) {
        if (universityOptions.isEmpty) {
          return language.tr('universities_unavailable_refresh');
        }
        if (value == null || value.trim().isEmpty) {
          return language.tr('please_select_university');
        }
        return null;
      },
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

  Widget _buildOrganizationNameField() {
    return TextFormField(
      controller: _organizationNameController,
      decoration: InputDecoration(
        labelText: 'Organization Name',
        hintText: 'Enter organization name',
        prefixIcon: const Icon(Icons.business_outlined),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      validator: (value) {
        return value?.trim().isEmpty ?? true
            ? 'Organization name is required'
            : null;
      },
    );
  }

  Widget _buildOrganizationFields(LanguageProvider language, bool isDesktop) {
    return _buildResponsiveFields([
      _ResponsiveField(child: _buildOrganizationNameField()),
      if (_isPrivateSectorOrganization)
        _ResponsiveField(
          child: TextFormField(
            controller: _organizationBrelaController,
            decoration: InputDecoration(
              labelText: 'BRELA Number',
              prefixIcon: const Icon(Icons.verified_user_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              return value?.trim().isEmpty ?? true
                  ? 'BRELA number is required'
                  : null;
            },
          ),
        ),
      if (_isPrivateSectorOrganization)
        _ResponsiveField(
          child: TextFormField(
            controller: _organizationTinController,
            decoration: InputDecoration(
              labelText: 'TIN Number',
              prefixIcon: const Icon(Icons.badge_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              return value?.trim().isEmpty ?? true
                  ? 'TIN number is required'
                  : null;
            },
          ),
        ),
      if (_isPrivateSectorOrganization)
        _ResponsiveField(
          child: TextFormField(
            controller: _organizationBusinessLicenseController,
            decoration: InputDecoration(
              labelText: 'Business License Number',
              prefixIcon: const Icon(Icons.workspace_premium_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              return value?.trim().isEmpty ?? true
                  ? 'Business license number is required'
                  : null;
            },
          ),
        ),
      if (_isGovernmentSectorOrganization)
        _ResponsiveField(
          child: DropdownButtonFormField<String>(
            initialValue: _selectedGovernmentCategory,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Category',
              prefixIcon: const Icon(Icons.account_balance_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _governmentSectorCategories.map((category) {
              return DropdownMenuItem<String>(
                value: category,
                child: Text(category, overflow: TextOverflow.ellipsis),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedGovernmentCategory = value);
            },
            validator: (value) {
              return value == null ? 'Please select category' : null;
            },
          ),
        ),
      if (_isGovernmentSectorOrganization)
        _ResponsiveField(
          child: TextFormField(
            controller: _organizationDepartmentController,
            decoration: InputDecoration(
              labelText: 'Department',
              prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              return value?.trim().isEmpty ?? true
                  ? 'Department is required'
                  : null;
            },
          ),
        ),
      if (_isGovernmentSectorOrganization)
        _ResponsiveField(
          child: TextFormField(
            controller: _organizationSectorController,
            decoration: InputDecoration(
              labelText: 'Sector',
              prefixIcon: const Icon(Icons.domain_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            validator: (value) {
              return value?.trim().isEmpty ?? true
                  ? 'Sector is required'
                  : null;
            },
          ),
        ),
      _ResponsiveField(
        fullWidth: true,
        child: TextFormField(
          controller: _organizationLocationController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Physical Address',
            prefixIcon: const Icon(Icons.location_on_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (value) {
            return value?.trim().isEmpty ?? true
                ? 'Physical address is required'
                : null;
          },
        ),
      ),
    ], isDesktop: isDesktop);
  }

  Widget _buildUniversityFields(LanguageProvider language, bool isDesktop) {
    final isGovernmentInstitution = _selectedRole == 'institution';
    final institutions = isGovernmentInstitution
        ? _filteredGovernment
        : _universities;
    final institutionError = isGovernmentInstitution
        ? _governmentError
        : _universitiesError;
    final sectionTitle = isGovernmentInstitution
        ? language.tr('government_office_information')
        : language.tr('college_information');
    final nameLabel = isGovernmentInstitution
        ? language.tr('government_office')
        : language.tr('college_name');
    final nameHint = isGovernmentInstitution
        ? (_selectedCollegeRegion == null
              ? language.tr('select_region_first')
              : (_selectedCollegeDistrict == null
                    ? language.tr('select_district_first')
                    : language.tr('select_government_office')))
        : language.tr('select_your_university');
    final loadingLabel = isGovernmentInstitution
        ? language.tr('loading_government_offices')
        : language.tr('loading_universities');
    final tapRefreshLabel = isGovernmentInstitution
        ? language.tr('tap_refresh_to_load_government_offices')
        : language.tr('tap_refresh_to_load_universities');
    final unavailableLabel = isGovernmentInstitution
        ? language.tr('government_offices_unavailable_refresh')
        : language.tr('universities_unavailable_refresh');
    final selectionRequiredLabel = isGovernmentInstitution
        ? language.tr('please_select_government_office')
        : language.tr('please_select_university');
    final regNoLabel = isGovernmentInstitution
        ? language.tr('institution_reg_no')
        : language.tr('college_reg_no');
    final regNoRequired = isGovernmentInstitution
        ? language.tr('institution_reg_no_required')
        : language.tr('college_reg_no_required');
    final emailLabel = isGovernmentInstitution
        ? language.tr('institution_email')
        : language.tr('college_email');
    final emailRequired = isGovernmentInstitution
        ? language.tr('institution_email_required')
        : language.tr('college_email_required');
    final phoneLabel = isGovernmentInstitution
        ? language.tr('institution_phone')
        : language.tr('college_phone');
    final phoneRequired = isGovernmentInstitution
        ? language.tr('institution_phone_required')
        : language.tr('college_phone_required');
    final addressLabel = isGovernmentInstitution
        ? language.tr('institution_address')
        : language.tr('college_address');
    final addressRequired = isGovernmentInstitution
        ? language.tr('institution_address_required')
        : language.tr('college_address_required');
    final regionLabel = isGovernmentInstitution
        ? language.tr('institution_region')
        : language.tr('college_region');
    final regionRequired = isGovernmentInstitution
        ? language.tr('institution_region_required')
        : language.tr('college_region_required');
    final districtLabel = isGovernmentInstitution
        ? language.tr('institution_district')
        : language.tr('college_district');
    final districtRequired = isGovernmentInstitution
        ? language.tr('institution_district_required')
        : language.tr('college_district_required');
    final districtHint = isGovernmentInstitution
        ? (_selectedCollegeRegion == null
              ? language.tr('select_region_first')
              : language.tr('select_institution_district'))
        : language.tr('select_college_district');
    final regionHint = isGovernmentInstitution
        ? language.tr('select_institution_region')
        : language.tr('select_college_region');
    final websiteLabel = isGovernmentInstitution
        ? language.tr('institution_website')
        : language.tr('college_website');
    final typeLabel = isGovernmentInstitution
        ? language.tr('institution_type')
        : language.tr('college_type');
    final typeRequired = isGovernmentInstitution
        ? language.tr('institution_type_required')
        : language.tr('college_type_required');
    final typeOptions = isGovernmentInstitution
        ? _institutionTypes
        : _collegeTypes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle(sectionTitle),
        const SizedBox(height: 12),
        _buildResponsiveFields([
          if (isGovernmentInstitution)
            _ResponsiveField(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollegeRegion,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: regionLabel,
                  hintText: regionHint,
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _institutionRegions
                    .map(
                      (region) => DropdownMenuItem<String>(
                        value: region,
                        child: Text(region),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _setCollegeRegion(value),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return regionRequired;
                  }
                  return null;
                },
              ),
            ),
          if (isGovernmentInstitution)
            _ResponsiveField(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollegeDistrict,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: districtLabel,
                  hintText: districtHint,
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _institutionDistricts
                    .map(
                      (district) => DropdownMenuItem<String>(
                        value: district,
                        child: Text(
                          district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _selectedCollegeRegion == null
                    ? null
                    : (value) => _setCollegeDistrict(value),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return districtRequired;
                  }
                  return null;
                },
              ),
            ),
          _ResponsiveField(
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollegeUniversityId,
                decoration: InputDecoration(
                  labelText: nameLabel,
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
                      : (institutionError != null
                            ? IconButton(
                                tooltip: isGovernmentInstitution
                                    ? language.tr(
                                        'retry_loading_government_offices',
                                      )
                                    : language.tr('retry_loading_universities'),
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
                hint: Text(nameHint),
                isExpanded: true,
                items: institutions.isEmpty
                    ? [
                        DropdownMenuItem<String>(
                          value: null,
                          child: Text(
                            _isLoading
                                ? loadingLabel
                                : isGovernmentInstitution
                                ? (_selectedCollegeRegion == null
                                      ? language.tr('select_region_first')
                                      : (_selectedCollegeDistrict == null
                                            ? language.tr(
                                                'select_district_first',
                                              )
                                            : language.tr(
                                                'no_government_offices_match_selected_location',
                                              )))
                                : tapRefreshLabel,
                          ),
                        ),
                      ]
                    : institutions.map<DropdownMenuItem<String>>((uni) {
                        return DropdownMenuItem<String>(
                          value: uni['university_id'].toString(),
                          child: Text(
                            isGovernmentInstitution &&
                                    '${uni['location'] ?? ''}'.trim().isNotEmpty
                                ? '${uni['name']} • ${uni['location']}'
                                : '${uni['name']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                onChanged: institutions.isEmpty
                    ? null
                    : (value) {
                        _selectInstitutionFromList(value, institutions);
                      },
                validator: (value) {
                  if (institutions.isEmpty) {
                    return isGovernmentInstitution
                        ? (_selectedCollegeRegion == null
                              ? regionRequired
                              : (_selectedCollegeDistrict == null
                                    ? districtRequired
                                    : language.tr(
                                        'no_government_offices_match_selected_location',
                                      )))
                        : unavailableLabel;
                  }
                  return value == null ? selectionRequiredLabel : null;
                },
              ),
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              decoration: InputDecoration(
                labelText: regNoLabel,
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              controller: _collegeRegNoController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return regNoRequired;
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
                labelText: emailLabel,
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return emailRequired;
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
                labelText: phoneLabel,
                prefixIcon: const Icon(Icons.phone_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return phoneRequired;
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
                labelText: addressLabel,
                prefixIcon: const Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return addressRequired;
                }
                return null;
              },
            ),
          ),
          if (!isGovernmentInstitution)
            _ResponsiveField(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollegeRegion,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: regionLabel,
                  hintText: regionHint,
                  prefixIcon: const Icon(Icons.map_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _institutionRegions
                    .map(
                      (region) => DropdownMenuItem<String>(
                        value: region,
                        child: Text(region),
                      ),
                    )
                    .toList(),
                onChanged: (value) => _setCollegeRegion(value),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return regionRequired;
                  }
                  return null;
                },
              ),
            ),
          if (!isGovernmentInstitution)
            _ResponsiveField(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedCollegeDistrict,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: districtLabel,
                  hintText: districtHint,
                  prefixIcon: const Icon(Icons.place_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _institutionDistricts
                    .map(
                      (district) => DropdownMenuItem<String>(
                        value: district,
                        child: Text(
                          district,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _selectedCollegeRegion == null
                    ? null
                    : (value) => _setCollegeDistrict(value),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return districtRequired;
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
                labelText: websiteLabel,
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
                labelText: typeLabel,
                prefixIcon: const Icon(Icons.apartment_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              items: typeOptions.map((type) {
                return DropdownMenuItem<String>(value: type, child: Text(type));
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCollegeType = value);
              },
              validator: (value) {
                return value == null ? typeRequired : null;
              },
            ),
          ),
        ], isDesktop: isDesktop),
        if (isGovernmentInstitution &&
            _selectedCollegeRegion != null &&
            _selectedCollegeDistrict != null &&
            !_isLoading &&
            institutions.isEmpty) ...[
          const SizedBox(height: 8),
          Text(
            language.tr('no_government_offices_match_selected_location'),
            style: const TextStyle(color: Colors.red, fontSize: 12),
          ),
        ],
        const SizedBox(height: 14),
        _buildUploadCard(
          title: isGovernmentInstitution
              ? language.tr('institution_logo')
              : language.tr('college_logo'),
          hint: isGovernmentInstitution
              ? language.tr('upload_institution_logo_hint')
              : language.tr('upload_college_logo_hint'),
          buttonLabel: isGovernmentInstitution
              ? language.tr('upload_institution_logo')
              : language.tr('upload_college_logo'),
          file: _selectedCollegeLogoFile,
          hasError: _showCollegeLogoError,
          errorText: isGovernmentInstitution
              ? language.tr('upload_institution_logo_required')
              : language.tr('upload_college_logo_required'),
          onPick: _pickCollegeLogo,
          onClear: () {
            setState(() => _selectedCollegeLogoFile = null);
          },
          icon: Icons.image_outlined,
        ),
        const SizedBox(height: 22),
        _buildSectionTitle(language.tr('coordinator_information')),
        const SizedBox(height: 12),
        _buildResponsiveFields([
          _ResponsiveField(
            child: TextFormField(
              controller: _coordinatorFirstNameController,
              decoration: InputDecoration(
                labelText: 'Coordinator First Name',
                prefixIcon: const Icon(Icons.person_outline),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Coordinator first name is required';
                }
                return null;
              },
            ),
          ),
          _ResponsiveField(
            child: TextFormField(
              controller: _coordinatorSecondNameController,
              decoration: InputDecoration(
                labelText: 'Coordinator Second Name',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Coordinator second name is required';
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
    final roleLabel = _accountRoleLabel(language, _selectedRole);
    final shouldShowOrganizationFields =
        _selectedRole != 'organization' || _selectedOrganizationSubtype != null;

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
            _accountSubtitle(language),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          if (_selectedRole == 'organization') ...[
            _buildSectionTitle('Organization Setup'),
            const SizedBox(height: 12),
            _buildOrganizationTypeField(),
            const SizedBox(height: 22),
          ],
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
                  language.tr('loading_'),
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (!_isUniversityLikeRole && shouldShowOrganizationFields) ...[
            _buildSectionTitle(language.tr('basic_information')),
            const SizedBox(height: 12),
            _selectedRole == 'student'
                ? _buildStudentBasicFields(language, isDesktop)
                : _buildCommonFields(language, isDesktop),
            const SizedBox(height: 22),
          ],
          if (_selectedRole != 'organization' ||
              shouldShowOrganizationFields) ...[
            _buildSectionTitle(_detailSectionLabel(language)),
            const SizedBox(height: 12),
            if (_selectedRole == 'student')
              _buildStudentFields(language, isDesktop)
            else if (_selectedRole == 'organization')
              _buildOrganizationFields(language, isDesktop)
            else
              _buildUniversityFields(language, isDesktop),
          ],
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

  void _moveTrainingPreview(int direction) {
    const slideCount = 4;
    final nextIndex = (_trainingPreviewIndex + direction) % slideCount;
    final resolvedIndex = nextIndex < 0 ? slideCount - 1 : nextIndex;

    if (_trainingPreviewController.hasClients) {
      _trainingPreviewController.animateToPage(
        resolvedIndex,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
      );
    }
    setState(() => _trainingPreviewIndex = resolvedIndex);
  }

  Widget _buildTrainingPreviewPanel(bool isDesktop) {
    final slides = const <(IconData, String, String, Color, String?)>[
      (
        Icons.engineering_outlined,
        'Industrial Practical Training',
        'Hands-on workplace learning in companies, government institutions, '
            'industries, and NGOs.',
        Color(0xFF155A99),
        'assets/images/ipt.png',
      ),
      (
        Icons.terrain_outlined,
        'Field Practical Training',
        'Field visits, surveys, community work, and professional observation.',
        Color(0xFF047545),
        'assets/images/pt.png',
      ),
      (
        Icons.local_hospital_outlined,
        'Clinical Practice',
        'Supervised practical exposure in hospitals and health facilities.',
        Color(0xFF0F766E),
        null,
      ),
      (
        Icons.school_outlined,
        'Teaching Practice',
        'Classroom practice and academic mentorship for education students.',
        Color(0xFF7C3AED),
        null,
      ),
    ];

    return Container(
      height: isDesktop ? 720 : 430,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFC8ECF8), Color(0xFFE2F4D9)],
        ),
        borderRadius: BorderRadius.circular(isDesktop ? 28 : 22),
      ),
      padding: EdgeInsets.all(isDesktop ? 34 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Practical Training',
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Explore pathways that connect classroom learning with real '
            'workplace experience.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.88),
              fontSize: 14,
              height: 1.45,
              letterSpacing: 0,
            ),
          ),
          const Spacer(),
          SizedBox(
            height: isDesktop ? 390 : 250,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _trainingPreviewController,
                  itemCount: slides.length,
                  onPageChanged: (index) {
                    setState(() => _trainingPreviewIndex = index);
                  },
                  itemBuilder: (context, index) {
                    final slide = slides[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _TrainingPreviewCard(
                        icon: slide.$1,
                        title: slide.$2,
                        body: slide.$3,
                        color: slide.$4,
                        imageAsset: slide.$5,
                      ),
                    );
                  },
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _TrainingPreviewArrow(
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => _moveTrainingPreview(-1),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: _TrainingPreviewArrow(
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => _moveTrainingPreview(1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < slides.length; index++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 10,
                  width: _trainingPreviewIndex == index ? 22 : 10,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _trainingPreviewIndex == index
                        ? AppTheme.primaryBlue
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _buildRegisterCard(LanguageProvider language, bool isDesktop) {
    return Card(
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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 4),
            Text(
              language.tr('united_republic_of_tanzania'),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 9, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isDesktop = screenWidth >= 900;
    final showPortalChrome = kIsWeb && isDesktop;
    final contentMaxWidth = isDesktop ? 1480.0 : 640.0;

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: showPortalChrome
          ? null
          : AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                tooltip: 'Back to home',
                onPressed: _goHome,
              ),
              title: Text(language.tr('create_account')),
              backgroundColor: Colors.transparent,
              elevation: 0,
              foregroundColor: AppTheme.textDark,
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    isDesktop ? 32 : 16,
                    showPortalChrome ? 112 : 16,
                    isDesktop ? 32 : 16,
                    16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: contentMaxWidth),
                      child: isDesktop
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: _buildTrainingPreviewPanel(isDesktop),
                                ),
                                const SizedBox(width: 30),
                                SizedBox(
                                  width: 600,
                                  child: _buildRegisterCard(
                                    language,
                                    isDesktop,
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                _buildRegisterCard(language, isDesktop),
                              ],
                            ),
                    ),
                  ),
                ),
                if (showPortalChrome)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: public_home.PublicPortalHeader(
                      isCompact: false,
                      onHomePressed: _goHome,
                      onVacanciesPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const public_home.TrainingPortalScreen(),
                          ),
                          (route) => false,
                        );
                      },
                      onLoginPressed: () {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LoginScreen(),
                          ),
                          (route) => false,
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TrainingPreviewCard extends StatelessWidget {
  const _TrainingPreviewCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.imageAsset,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final String? imageAsset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Stack(
                children: [
                  if (imageAsset != null) ...[
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          imageAsset!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    Positioned(
                      right: -24,
                      top: -24,
                      child: Icon(
                        icon,
                        size: 160,
                        color: color.withValues(alpha: 0.12),
                      ),
                    ),
                    Center(
                      child: Container(
                        height: 128,
                        width: 128,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.24),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Icon(icon, size: 64, color: Colors.white),
                      ),
                    ),
                  ],
                  Positioned(
                    left: 18,
                    bottom: 18,
                    right: 18,
                    child: Row(
                      children: [
                        _TrainingPreviewMiniIcon(
                          icon: Icons.business_center_outlined,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        _TrainingPreviewMiniIcon(
                          icon: Icons.groups_outlined,
                          color: color,
                        ),
                        const SizedBox(width: 8),
                        _TrainingPreviewMiniIcon(
                          icon: Icons.assignment_turned_in_outlined,
                          color: color,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textDark,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingPreviewMiniIcon extends StatelessWidget {
  const _TrainingPreviewMiniIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 34,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 18),
    );
  }
}

class _TrainingPreviewArrow extends StatelessWidget {
  const _TrainingPreviewArrow({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: AppTheme.textDark),
        tooltip: 'Change training preview',
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
