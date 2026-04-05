import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class EditCompanyProfileScreen extends StatefulWidget {
  const EditCompanyProfileScreen({super.key});

  @override
  State<EditCompanyProfileScreen> createState() =>
      _EditCompanyProfileScreenState();
}

class _EditCompanyProfileScreenState extends State<EditCompanyProfileScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _companyNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _websiteController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();

  // Password controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  // Password visibility states
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  String? _selectedCompanySize;
  String? _selectedIndustry;
  String? _logoUrl;
  String? _stampUrl;
  String? _signatureUrl;
  bool _isLoading = false;
  bool _isChangingPassword = false;

  final List<String> _companySizes = [
    '1-10',
    '11-50',
    '51-200',
    '201-500',
    '501-1000',
    '1000+',
  ];

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

  @override
  void initState() {
    super.initState();
    _loadCompanyData();
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _websiteController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadCompanyData() async {
    setState(() => _isLoading = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final companyData = user?['company_data'];

      _companyNameController.text = companyData?['company_name'] ?? '';
      _logoUrl = companyData?['logo_url']?.toString();
      _stampUrl = companyData?['stamp_url']?.toString();
      _signatureUrl = companyData?['signature_url']?.toString();

      String? industry = companyData?['industry'];
      if (industry != null && !_industries.contains(industry)) {
        industry = null;
      }
      _selectedIndustry = industry;

      _locationController.text = companyData?['location'] ?? '';
      _descriptionController.text = companyData?['description'] ?? '';
      _websiteController.text = companyData?['website_url'] ?? '';
      _phoneController.text = user?['phone'] ?? '';
      _emailController.text = user?['email'] ?? '';

      String? companySize = companyData?['company_size'];
      if (companySize != null && !_companySizes.contains(companySize)) {
        companySize = null;
      }
      _selectedCompanySize = companySize;

      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
      debugPrint('Error loading company data: $e');
    }
  }

  String? _resolveAssetUrl(String? assetPath) {
    if (assetPath == null || assetPath.isEmpty) return null;
    if (assetPath.startsWith('http://') || assetPath.startsWith('https://')) {
      return assetPath;
    }
    return '${_apiService.baseUrl}$assetPath';
  }

  Future<void> _uploadLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        withData: kIsWeb,
      );
      if (!mounted) return;

      if (result != null) {
        PlatformFile file = result.files.first;

        if (file.size > 5 * 1024 * 1024) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('File size should be less than 5MB'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        final filePath = file.path;
        final fileBytes = file.bytes;
        if ((filePath == null || filePath.isEmpty) && fileBytes == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Selected file path is invalid'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        setState(() => _isLoading = true);

        final response = await _apiService.uploadCompanyLogo(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: file.name,
        );
        if (!mounted) return;

        if (response['success']) {
          final uploadedLogo =
              response['data']?['logo_url']?.toString() ??
              response['logo_url']?.toString();
          if (uploadedLogo != null && uploadedLogo.isNotEmpty) {
            setState(() => _logoUrl = uploadedLogo);
          }

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logo uploaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.loadProfile();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Upload failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.normalizeErrorMessage(
              e,
              fallback: 'Failed to upload logo. Please try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final updateData = {
        'full_name': _companyNameController.text,
        'phone': _phoneController.text,
        'email': _emailController.text,
        'company_data': {
          'company_name': _companyNameController.text,
          'industry': _selectedIndustry,
          'location': _locationController.text,
          'description': _descriptionController.text,
          'website_url': _websiteController.text,
          'company_size': _selectedCompanySize,
        },
      };

      try {
        final response = await _apiService.put(
          '/api/auth/profile',
          updateData,
          requiresAuth: true,
        );
        if (!mounted) return;

        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profile updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.loadProfile();
          if (!mounted) return;
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Update failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.normalizeErrorMessage(
                e,
                fallback: 'Failed to update profile. Please try again.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('New passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_currentPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter current password'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isChangingPassword = true);

    try {
      final response = await _apiService.put('/api/auth/change-password', {
        'current_password': _currentPasswordController.text,
        'new_password': _newPasswordController.text,
      }, requiresAuth: true);
      if (!mounted) return;

      if (response['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Password change failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.normalizeErrorMessage(
              e,
              fallback: 'Failed to change password. Please try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isChangingPassword = false);
      }
    }
  }

  void _goToSection(int index) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, {'targetIndex': index});
    }
  }

  Widget _buildTopNavigationBar() {
    Widget navItem({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
      required Color color,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey.shade800,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.85,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: 'Home',
            icon: Icons.dashboard_rounded,
            selected: false,
            onTap: () => _goToSection(0),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: 'My Jobs',
            icon: Icons.work_rounded,
            selected: false,
            onTap: () => _goToSection(1),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: 'Applications',
            icon: Icons.groups_rounded,
            selected: false,
            onTap: () => _goToSection(2),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: 'Profile',
            icon: Icons.business_rounded,
            selected: true,
            onTap: () => _goToSection(3),
            color: const Color(0xFF2C3E50),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _companyNameController.text.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Edit Company Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 16),
                _buildTopNavigationBar(),
                const SizedBox(height: 12),

                // ========== CARD 1: COMPANY LOGO ==========
                Container(
                  width:
                      MediaQuery.of(context).size.width *
                      0.85, // 85% of screen width
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.08),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.image,
                              color: Color(0xFF2C3E50),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Company Logo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Center(
                          child: GestureDetector(
                            onTap: _uploadLogo,
                            child: Container(
                              height: 80,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final logoPreviewUrl = _resolveAssetUrl(
                                    _logoUrl,
                                  );
                                  if (logoPreviewUrl != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: Image.network(
                                        logoPreviewUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                              return const Center(
                                                child: Icon(
                                                  Icons.camera_alt,
                                                  size: 24,
                                                  color: Colors.grey,
                                                ),
                                              );
                                            },
                                      ),
                                    );
                                  }
                                  return const Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.camera_alt,
                                          size: 24,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Upload',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Tap to upload logo',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ========== CARD 2: ACCEPTANCE LETTER ASSETS ==========
                Container(
                  width: MediaQuery.of(context).size.width * 0.85,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.08),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.approval_rounded,
                              color: Color(0xFF2C3E50),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Acceptance Letter Assets',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload a JPG/JPEG company stamp and signature once. Accepted response letters will use them automatically.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            _buildLetterAssetTile(
                              title: 'Company Stamp',
                              subtitle:
                                  'Used on the official rubber stamp area',
                              assetUrl: _stampUrl,
                              emptyIcon: Icons.verified_outlined,
                              onTap: () => _uploadAcceptanceLetterAsset(
                                isSignature: false,
                              ),
                            ),
                            const SizedBox(width: 12),
                            _buildLetterAssetTile(
                              title: 'Digital Signature',
                              subtitle:
                                  'Placed on the authorizing officer signature line',
                              assetUrl: _signatureUrl,
                              emptyIcon: Icons.draw_outlined,
                              onTap: () => _uploadAcceptanceLetterAsset(
                                isSignature: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'If these are not uploaded yet, the PDF will still be generated with blank spaces for manual stamping and signing.',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ========== CARD 3: COMPANY INFORMATION ==========
                Container(
                  width:
                      MediaQuery.of(context).size.width *
                      0.85, // 85% of screen width
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.08),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.business,
                              color: Color(0xFF2C3E50),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Company Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Company Name
                        TextFormField(
                          controller: _companyNameController,
                          decoration: InputDecoration(
                            labelText: 'Company Name',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.business, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),

                        // Company Size
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCompanySize,
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Company Size',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            prefixIcon: const Icon(Icons.people, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          iconEnabledColor: Colors.black87,
                          items: _companySizes.map((size) {
                            return DropdownMenuItem(
                              value: size,
                              child: Text(
                                '$size employees',
                                style: const TextStyle(color: Colors.black87),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedCompanySize = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),

                        // Industry
                        DropdownButtonFormField<String>(
                          initialValue: _selectedIndustry,
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            labelText: 'Industry',
                            labelStyle: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            prefixIcon: const Icon(Icons.factory, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          iconEnabledColor: Colors.black87,
                          items: _industries.map((industry) {
                            return DropdownMenuItem(
                              value: industry,
                              child: Text(
                                industry,
                                style: const TextStyle(color: Colors.black87),
                              ),
                            );
                          }).toList(),
                          onChanged: (v) =>
                              setState(() => _selectedIndustry = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),

                        // Location
                        TextFormField(
                          controller: _locationController,
                          decoration: InputDecoration(
                            labelText: 'Location',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.location_on, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),

                        // Website
                        TextFormField(
                          controller: _websiteController,
                          decoration: InputDecoration(
                            labelText: 'Website',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.link, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 10),

                        // Phone
                        TextFormField(
                          controller: _phoneController,
                          decoration: InputDecoration(
                            labelText: 'Phone',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.phone, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.email, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Description
                        TextFormField(
                          controller: _descriptionController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.description, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ========== CARD 4: CHANGE PASSWORD ==========
                Container(
                  width:
                      MediaQuery.of(context).size.width *
                      0.85, // 85% of screen width
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.08),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock,
                              color: Color(0xFF2C3E50),
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2C3E50),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Current Password
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: !_showCurrentPassword,
                          decoration: InputDecoration(
                            labelText: 'Current Password',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(
                              Icons.lock_outline,
                              size: 18,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showCurrentPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showCurrentPassword = !_showCurrentPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 10),

                        // New Password
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: !_showNewPassword,
                          decoration: InputDecoration(
                            labelText: 'New Password',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.lock_open, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showNewPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showNewPassword = !_showNewPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            helperText: 'Min. 6 characters',
                            helperStyle: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 10),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          decoration: InputDecoration(
                            labelText: 'Confirm New Password',
                            labelStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.lock, size: 18),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() {
                                  _showConfirmPassword = !_showConfirmPassword;
                                });
                              },
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),

                        // Change Password Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isChangingPassword
                                ? null
                                : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _isChangingPassword
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Change Password',
                                    style: TextStyle(fontSize: 14),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ========== SAVE BUTTON ==========
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.85,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updateProfile,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'SAVE CHANGES',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _uploadAcceptanceLetterAsset({required bool isSignature}) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg'],
        withData: kIsWeb,
      );
      if (!mounted || result == null) return;

      final file = result.files.first;
      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File size should be less than 5MB'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final filePath = file.path;
      final fileBytes = file.bytes;
      if ((filePath == null || filePath.isEmpty) && fileBytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Selected file path is invalid'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);
      final response = isSignature
          ? await _apiService.uploadCompanySignature(
              filePath: filePath,
              fileBytes: fileBytes,
              fileName: file.name,
            )
          : await _apiService.uploadCompanyStamp(
              filePath: filePath,
              fileBytes: fileBytes,
              fileName: file.name,
            );
      if (!mounted) return;

      if (response['success'] == true) {
        final uploadedUrl =
            response['data']?[isSignature ? 'signature_url' : 'stamp_url']
                ?.toString();
        setState(() {
          if (isSignature) {
            _signatureUrl = uploadedUrl;
          } else {
            _stampUrl = uploadedUrl;
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isSignature
                  ? 'Digital signature uploaded successfully!'
                  : 'Company stamp uploaded successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        await Provider.of<AuthProvider>(context, listen: false).loadProfile();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Upload failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ApiService.normalizeErrorMessage(
              e,
              fallback: 'Failed to upload file. Please try again.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildLetterAssetTile({
    required String title,
    required String subtitle,
    required String? assetUrl,
    required IconData emptyIcon,
    required VoidCallback onTap,
    double previewWidth = 110,
    double previewHeight = 72,
  }) {
    final previewUrl = _resolveAssetUrl(assetUrl);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2C3E50),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              Container(
                height: previewHeight,
                width: previewWidth,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                alignment: Alignment.center,
                child: previewUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(emptyIcon, color: Colors.grey.shade500),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload JPG',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.network(
                          previewUrl,
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(emptyIcon, color: Colors.grey.shade500);
                          },
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                previewUrl == null ? 'Tap to upload' : 'Tap to replace',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
