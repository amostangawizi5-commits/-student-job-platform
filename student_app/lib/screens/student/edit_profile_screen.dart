import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _programController = TextEditingController();
  final _gpaController = TextEditingController();
  String? _selectedUniversityId;
  int? _expectedGraduationYear;
  int? _graduationYear;
  String _experienceLevel = 'no_experience';
  PlatformFile? _selectedStudentIdFile;
  String _currentIdentificationCardName = '';

  List<dynamic> _universities = [];
  List<int> _years = [];
  bool _isLoading = true;
  bool _isSaving = false;

  bool _isGraduate = false;

  void _ensureCurrentUniversityOption({
    required String? universityId,
    required String? universityName,
  }) {
    final normalizedId = universityId?.trim();
    if (normalizedId == null || normalizedId.isEmpty) {
      return;
    }

    final alreadyPresent = _universities.any(
      (uni) => uni['university_id']?.toString() == normalizedId,
    );
    if (alreadyPresent) {
      return;
    }

    _universities = [
      ..._universities,
      {
        'university_id': normalizedId,
        'name': (universityName?.trim().isNotEmpty ?? false)
            ? universityName!.trim()
            : 'Current University',
      },
    ];
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _programController.dispose();
    _gpaController.dispose();
    super.dispose();
  }

  bool _isPdfFile(PlatformFile file) {
    final fileName = file.name.trim().toLowerCase();
    final filePath = (file.path ?? '').trim().toLowerCase();
    return fileName.endsWith('.pdf') || filePath.endsWith('.pdf');
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

  // Helper method to show top SnackBar
  void _showTopSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              backgroundColor == Colors.green
                  ? Icons.check_circle
                  : Icons.error,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      _isGraduate = user?['role'] == 'graduate';

      // Load universities
      final uniResponse = await _apiService.getUniversities();
      _universities = uniResponse['data'] ?? [];

      // Cover historical and future years for both graduates and current students.
      final currentYear = DateTime.now().year;
      _years = List<int>.generate(
        currentYear - 2000 + 11,
        (i) => currentYear + 10 - i,
      );

      // Fill controllers
      _fullNameController.text = user?['full_name'] ?? '';
      _phoneController.text = user?['phone'] ?? '';
      _programController.text = user?['student_data']?['program'] ?? '';
      _gpaController.text = '${user?['student_data']?['gpa'] ?? ''}'.replaceAll(
        'null',
        '',
      );
      _selectedUniversityId = user?['student_data']?['university_id']
          ?.toString();
      _currentIdentificationCardName =
          user?['student_data']?['identification_card_name']?.toString() ?? '';
      _ensureCurrentUniversityOption(
        universityId: _selectedUniversityId,
        universityName: user?['student_data']?['university_name']?.toString(),
      );

      if (_isGraduate) {
        int? gradYear = user?['student_data']?['graduation_year'];
        if (gradYear != null && !_years.contains(gradYear)) {
          _years.add(gradYear);
          _years.sort();
        }
        _graduationYear = gradYear;
        _experienceLevel =
            user?['student_data']?['experience_level'] ?? 'no_experience';
      } else {
        int? expectedYear = user?['student_data']?['expected_graduation_year'];
        if (expectedYear != null && !_years.contains(expectedYear)) {
          _years.add(expectedYear);
          _years.sort();
        }
        _expectedGraduationYear = expectedYear;
      }

      setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  int? _getSafeYearValue(int? value) {
    if (value == null) return null;
    if (_years.contains(value)) return value;
    return null;
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
      if (!_isPdfFile(file)) {
        _showTopSnackBar(
          'Only PDF files are allowed for identification cards.',
          Colors.red,
        );
        return;
      }

      if (file.size > 5 * 1024 * 1024) {
        _showTopSnackBar('File size should be less than 5MB', Colors.red);
        return;
      }

      if ((file.path == null || file.path!.isEmpty) && file.bytes == null) {
        _showTopSnackBar('Selected file could not be read', Colors.red);
        return;
      }

      setState(() => _selectedStudentIdFile = file);
    } catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        ApiService.normalizeErrorMessage(
          e,
          fallback: 'Failed to pick identification card.',
        ),
        Colors.red,
      );
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSaving = true);

      Map<String, dynamic> updateData = {
        'full_name': _fullNameController.text.trim(),
        'phone': _phoneController.text.trim(),
      };

      Map<String, dynamic> studentData = {
        'program': _programController.text.trim(),
        'university_id': _selectedUniversityId,
        'student_type': _isGraduate ? 'graduate' : 'current',
        'gpa': _gpaController.text.trim().isEmpty
            ? null
            : double.tryParse(_gpaController.text.trim()),
      };

      if (_isGraduate) {
        studentData['expected_graduation_year'] = null;
        studentData['graduation_year'] = _graduationYear;
        studentData['experience_level'] = _experienceLevel;
      } else {
        studentData['graduation_year'] = null;
        studentData['experience_level'] = null;
        studentData['expected_graduation_year'] = _expectedGraduationYear;
      }

      updateData['student_data'] = studentData;

      try {
        final response = await _apiService.updateProfile(
          updateData,
          identificationCardFilePath: _selectedStudentIdFile?.path,
          identificationCardFileBytes: _selectedStudentIdFile?.bytes,
          identificationCardFileName: _selectedStudentIdFile?.name,
        );
        if (!mounted) return;

        if (response['success']) {
          // Show success message at TOP
          _showTopSnackBar('Profile updated successfully!', Colors.green);

          // Refresh user data
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.loadProfile();
          if (!mounted) return;

          // Wait for snackbar to show before popping
          await Future.delayed(const Duration(seconds: 1));
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          _showTopSnackBar(response['message'] ?? 'Update failed', Colors.red);
        }
      } catch (e) {
        if (!mounted) return;
        _showTopSnackBar('Error: $e', Colors.red);
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              'Save',
              style: TextStyle(
                color: AppTheme.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),

              // Main Card with elevation 5 and LARGE horizontal margin
              Card(
                elevation: 5,
                margin: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 8,
                ), // Increased to 32
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24), // Increased padding
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        const Row(
                          children: [
                            Icon(
                              Icons.person_outline,
                              color: Color(0xFF2C3E50),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Personal Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: const Icon(
                              Icons.person_outline,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Phone
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: const Icon(
                              Icons.phone_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            helperText: 'Format: 0712345678 or +255712345678',
                            helperStyle: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final phone = v.replaceAll(RegExp(r'[\s\-]'), '');
                            if (!RegExp(
                              r'^(0|\+255)[0-9]{9}$',
                            ).hasMatch(phone)) {
                              return 'Enter valid Tanzanian phone';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // University
                        DropdownButtonFormField<String>(
                          initialValue: _selectedUniversityId,
                          isExpanded: true,
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'University',
                            prefixIcon: const Icon(
                              Icons.school_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black,
                          ),
                          items: _universities.map((uni) {
                            return DropdownMenuItem(
                              value: uni['university_id'].toString(),
                              child: Text(
                                uni['name'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.black),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedUniversityId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    color: Color(0xFF2C3E50),
                                    size: 20,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    'Student Identification Card',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2C3E50),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _selectedStudentIdFile != null
                                    ? 'New PDF selected. It will replace the current ID after you save.'
                                    : 'Upload a PDF copy of your student ID. Maximum 5MB.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 14),
                              OutlinedButton.icon(
                                onPressed: _isSaving
                                    ? null
                                    : _pickStudentIdCard,
                                icon: const Icon(Icons.upload_file_outlined),
                                label: Text(
                                  _selectedStudentIdFile == null
                                      ? 'Upload Student ID (PDF)'
                                      : 'Replace Student ID (PDF)',
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: BorderSide(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.35,
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_selectedStudentIdFile != null)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _selectedStudentIdFile!.name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              _formatFileSize(
                                                _selectedStudentIdFile!.size,
                                              ),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: _isSaving
                                            ? null
                                            : () => setState(
                                                () => _selectedStudentIdFile =
                                                    null,
                                              ),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                    ],
                                  ),
                                )
                              else if (_currentIdentificationCardName
                                  .trim()
                                  .isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.picture_as_pdf_outlined,
                                        color: Colors.redAccent,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _currentIdentificationCardName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Program
                        TextFormField(
                          controller: _programController,
                          decoration: InputDecoration(
                            labelText: 'Program / Course',
                            prefixIcon: const Icon(
                              Icons.book_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _gpaController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: 'GPA',
                            prefixIcon: const Icon(
                              Icons.auto_graph_outlined,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            helperText: 'Optional. Use 0.0 to 5.0 scale.',
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (value) {
                            final trimmed = value?.trim() ?? '';
                            if (trimmed.isEmpty) return null;
                            final parsed = double.tryParse(trimmed);
                            if (parsed == null || parsed < 0 || parsed > 5) {
                              return 'Enter GPA between 0.0 and 5.0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Divider
                        const Divider(height: 32, thickness: 1),

                        // Academic Information Header
                        const Row(
                          children: [
                            Icon(
                              Icons.school,
                              color: Color(0xFF2C3E50),
                              size: 24,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Academic Information',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Graduation Year (for graduates)
                        if (_isGraduate) ...[
                          DropdownButtonFormField<int>(
                            initialValue: _getSafeYearValue(_graduationYear),
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Graduation Year',
                              prefixIcon: const Icon(
                                Icons.calendar_today,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            items: _years.map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year.toString(),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _graduationYear = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                          const SizedBox(height: 16),

                          // Experience Level
                          DropdownButtonFormField<String>(
                            initialValue: _experienceLevel,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Experience Level',
                              prefixIcon: const Icon(
                                Icons.work_outline,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            style: const TextStyle(fontSize: 14),
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
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ] else ...[
                          // Expected Graduation Year (for current students)
                          DropdownButtonFormField<int>(
                            initialValue: _getSafeYearValue(
                              _expectedGraduationYear,
                            ),
                            isExpanded: true,
                            dropdownColor: Colors.white,
                            decoration: InputDecoration(
                              labelText: 'Expected Graduation Year',
                              prefixIcon: const Icon(
                                Icons.calendar_today,
                                size: 20,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                            items: _years.map((year) {
                              return DropdownMenuItem(
                                value: year,
                                child: Text(
                                  year.toString(),
                                  style: const TextStyle(color: Colors.black),
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _expectedGraduationYear = v),
                            validator: (v) => v == null ? 'Required' : null,
                          ),
                        ],

                        const SizedBox(height: 32),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSaving ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSaving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'SAVE CHANGES',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
