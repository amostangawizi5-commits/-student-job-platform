import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../utils/role_theme.dart';

const Color _companyEditPrimary = CompanyRoleTheme.primary;
const Color _companyEditPrimaryDark = CompanyRoleTheme.primaryDark;
const Color _companyEditSurfaceSoft = CompanyRoleTheme.surfaceSoft;
const Color _companyEditBorder = CompanyRoleTheme.border;

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
  Uint8List? _logoPreviewBytes;
  Uint8List? _stampPreviewBytes;
  Uint8List? _signaturePreviewBytes;
  int _logoPreviewVersion = DateTime.now().millisecondsSinceEpoch;
  int _stampPreviewVersion = DateTime.now().millisecondsSinceEpoch;
  int _signaturePreviewVersion = DateTime.now().millisecondsSinceEpoch;
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
      final refreshedAt = DateTime.now().millisecondsSinceEpoch;
      _logoPreviewVersion = refreshedAt;
      _stampPreviewVersion = refreshedAt;
      _signaturePreviewVersion = refreshedAt;

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

  void _syncUploadedAssetState({
    String? logoUrl,
    String? stampUrl,
    String? signatureUrl,
    Uint8List? logoPreviewBytes,
    Uint8List? stampPreviewBytes,
    Uint8List? signaturePreviewBytes,
    bool refreshLogoVersion = false,
    bool refreshStampVersion = false,
    bool refreshSignatureVersion = false,
  }) {
    final refreshedAt = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      if (logoUrl != null && logoUrl.isNotEmpty) {
        _logoUrl = logoUrl;
      }
      if (stampUrl != null && stampUrl.isNotEmpty) {
        _stampUrl = stampUrl;
      }
      if (signatureUrl != null && signatureUrl.isNotEmpty) {
        _signatureUrl = signatureUrl;
      }
      if (logoPreviewBytes != null) {
        _logoPreviewBytes = logoPreviewBytes;
      }
      if (stampPreviewBytes != null) {
        _stampPreviewBytes = stampPreviewBytes;
      }
      if (signaturePreviewBytes != null) {
        _signaturePreviewBytes = signaturePreviewBytes;
      }
      if (refreshLogoVersion) {
        _logoPreviewVersion = refreshedAt;
      }
      if (refreshStampVersion) {
        _stampPreviewVersion = refreshedAt;
      }
      if (refreshSignatureVersion) {
        _signaturePreviewVersion = refreshedAt;
      }
    });
  }

  Future<void> _reloadUploadedAssetsFromProfile() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.loadProfile();
    if (!mounted) return;

    final companyData = authProvider.user?['company_data'];
    _syncUploadedAssetState(
      logoUrl: companyData?['logo_url']?.toString(),
      stampUrl: companyData?['stamp_url']?.toString(),
      signatureUrl: companyData?['signature_url']?.toString(),
      refreshLogoVersion: true,
      refreshStampVersion: true,
      refreshSignatureVersion: true,
    );
  }

  String? _resolveAssetUrl(String? assetPath, {int? cacheBust}) {
    return _apiService.resolveAssetUrl(assetPath, cacheBust: cacheBust);
  }

  List<String> _resolveAssetUrlCandidates(String? assetPath, {int? cacheBust}) {
    return _apiService.resolveAssetUrlCandidates(
      assetPath,
      cacheBust: cacheBust,
    );
  }

  Future<void> _uploadLogo() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
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
        final previousLogoUrl = _logoUrl;
        setState(() => _isLoading = true);

        final response = await _apiService.uploadCompanyLogo(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: file.name,
        );
        if (!mounted) return;

        if (response['success']) {
          final uploadedCompany = response['data']?['company'];
          final uploadedLogo =
              uploadedCompany?['logo_url']?.toString() ??
              response['data']?['logo_url']?.toString() ??
              response['logo_url']?.toString();
          _syncUploadedAssetState(
            logoUrl: uploadedLogo,
            logoPreviewBytes: fileBytes,
            refreshLogoVersion: true,
          );
          await _reloadUploadedAssetsFromProfile();
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _logoUrl != null && _logoUrl != previousLogoUrl
                    ? 'Logo uploaded successfully!'
                    : 'Logo upload saved successfully.',
              ),
              backgroundColor: Colors.green,
            ),
          );
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _companyEditBorder.withValues(alpha: 0.7)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 3),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({
    required String labelText,
    required IconData icon,
    Widget? suffixIcon,
    String? helperText,
    bool enabled = true,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        fontSize: 12,
        color: enabled ? _companyEditPrimaryDark : Colors.grey.shade600,
      ),
      prefixIcon: Icon(icon, size: 18, color: _companyEditPrimary),
      suffixIcon: suffixIcon,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _companyEditBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _companyEditPrimary),
      ),
      filled: true,
      fillColor: enabled ? _companyEditSurfaceSoft : Colors.grey.shade100,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      helperText: helperText,
      helperStyle: TextStyle(fontSize: 10, color: Colors.grey.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _companyNameController.text.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F2),
      appBar: AppBar(
        title: const Text('Edit Company Profile'),
        backgroundColor: Colors.white,
        foregroundColor: _companyEditPrimaryDark,
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

                // ========== CARD 1: COMPANY LOGO ==========
                Container(
                  width:
                      MediaQuery.of(context).size.width *
                      0.85, // 85% of screen width
                  decoration: _cardDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.image,
                              color: _companyEditPrimary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Company Logo',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _companyEditPrimaryDark,
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
                                color: _companyEditSurfaceSoft,
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: _companyEditBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Builder(
                                builder: (context) {
                                  final logoPreviewUrls =
                                      _resolveAssetUrlCandidates(
                                        _logoUrl,
                                        cacheBust: _logoPreviewVersion,
                                      );
                                  if (_logoPreviewBytes != null) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: Image.memory(
                                        _logoPreviewBytes!,
                                        key: ValueKey(
                                          'logo-memory-$_logoPreviewVersion',
                                        ),
                                        fit: BoxFit.cover,
                                      ),
                                    );
                                  }
                                  if (logoPreviewUrls.isNotEmpty) {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(40),
                                      child: _AssetImageWithFallbacks(
                                        imageUrls: logoPreviewUrls,
                                        fit: BoxFit.cover,
                                        emptyChild: const Center(
                                          child: Icon(
                                            Icons.camera_alt,
                                            size: 24,
                                            color: _companyEditPrimary,
                                          ),
                                        ),
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
                                          color: _companyEditPrimary,
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
                              color: Colors.grey[600],
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
                  decoration: _cardDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.approval_rounded,
                              color: _companyEditPrimary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Acceptance Letter Assets',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _companyEditPrimaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload a JPG/JPEG/PNG company stamp and signature once. Accepted response letters will use them automatically.',
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
                              previewBytes: _stampPreviewBytes,
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
                              previewBytes: _signaturePreviewBytes,
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
                  decoration: _cardDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.business,
                              color: _companyEditPrimary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Company Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _companyEditPrimaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Company Name
                        TextFormField(
                          controller: _companyNameController,
                          decoration: _inputDecoration(
                            labelText: 'Company Name',
                            icon: Icons.business,
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
                          decoration: _inputDecoration(
                            labelText: 'Company Size',
                            icon: Icons.people,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _companyEditPrimaryDark,
                          ),
                          iconEnabledColor: _companyEditPrimaryDark,
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
                          decoration: _inputDecoration(
                            labelText: 'Industry',
                            icon: Icons.factory,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: _companyEditPrimaryDark,
                          ),
                          iconEnabledColor: _companyEditPrimaryDark,
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
                          decoration: _inputDecoration(
                            labelText: 'Location',
                            icon: Icons.location_on,
                          ),
                          style: const TextStyle(fontSize: 14),
                          validator: (v) =>
                              v?.isEmpty ?? true ? 'Required' : null,
                        ),
                        const SizedBox(height: 10),

                        // Website
                        TextFormField(
                          controller: _websiteController,
                          decoration: _inputDecoration(
                            labelText: 'Website',
                            icon: Icons.link,
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 10),

                        // Phone
                        TextFormField(
                          controller: _phoneController,
                          decoration: _inputDecoration(
                            labelText: 'Phone',
                            icon: Icons.phone,
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 10),

                        // Email
                        TextFormField(
                          controller: _emailController,
                          enabled: false,
                          decoration: _inputDecoration(
                            labelText: 'Email',
                            icon: Icons.email,
                            enabled: false,
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
                          decoration: _inputDecoration(
                            labelText: 'Description',
                            icon: Icons.description,
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
                  decoration: _cardDecoration(),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.lock,
                              color: _companyEditPrimary,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _companyEditPrimaryDark,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Current Password
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: !_showCurrentPassword,
                          decoration: _inputDecoration(
                            labelText: 'Current Password',
                            icon: Icons.lock_outline,
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
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 10),

                        // New Password
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: !_showNewPassword,
                          decoration: _inputDecoration(
                            labelText: 'New Password',
                            icon: Icons.lock_open,
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
                            helperText: 'Min. 6 characters',
                          ),
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 10),

                        // Confirm Password
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: !_showConfirmPassword,
                          decoration: _inputDecoration(
                            labelText: 'Confirm New Password',
                            icon: Icons.lock,
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
                              backgroundColor: _companyEditPrimary,
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
                      backgroundColor: _companyEditPrimaryDark,
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
        allowedExtensions: const ['jpg', 'jpeg', 'png'],
        withData: true,
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

      final previousAssetUrl = isSignature ? _signatureUrl : _stampUrl;
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
        final uploadedCompany = response['data']?['company'];
        final uploadedUrl =
            uploadedCompany?[isSignature ? 'signature_url' : 'stamp_url']
                ?.toString() ??
            response['data']?[isSignature ? 'signature_url' : 'stamp_url']
                ?.toString();
        _syncUploadedAssetState(
          stampUrl: isSignature ? null : uploadedUrl,
          signatureUrl: isSignature ? uploadedUrl : null,
          stampPreviewBytes: isSignature ? null : fileBytes,
          signaturePreviewBytes: isSignature ? fileBytes : null,
          refreshStampVersion: !isSignature,
          refreshSignatureVersion: isSignature,
        );
        await _reloadUploadedAssetsFromProfile();
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              (isSignature ? _signatureUrl : _stampUrl) != null &&
                      (isSignature ? _signatureUrl : _stampUrl) !=
                          previousAssetUrl
                  ? (isSignature
                        ? 'Digital signature uploaded successfully!'
                        : 'Company stamp uploaded successfully!')
                  : (isSignature
                        ? 'Digital signature saved successfully.'
                        : 'Company stamp saved successfully.'),
            ),
            backgroundColor: Colors.green,
          ),
        );
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
    Uint8List? previewBytes,
    required IconData emptyIcon,
    required VoidCallback onTap,
    double previewWidth = 110,
    double previewHeight = 72,
  }) {
    final previewUrl = _resolveAssetUrl(
      assetUrl,
      cacheBust: title == 'Company Stamp'
          ? _stampPreviewVersion
          : _signaturePreviewVersion,
    );
    final previewUrls = _resolveAssetUrlCandidates(
      assetUrl,
      cacheBust: title == 'Company Stamp'
          ? _stampPreviewVersion
          : _signaturePreviewVersion,
    );

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _companyEditSurfaceSoft,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _companyEditBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _companyEditPrimaryDark,
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
                  border: Border.all(color: _companyEditBorder),
                ),
                alignment: Alignment.center,
                child: previewBytes != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.memory(
                          previewBytes,
                          key: ValueKey(
                            '$title-memory-${title == 'Company Stamp' ? _stampPreviewVersion : _signaturePreviewVersion}',
                          ),
                          fit: BoxFit.contain,
                          width: double.infinity,
                          height: double.infinity,
                        ),
                      )
                    : previewUrl == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(emptyIcon, color: _companyEditPrimary),
                          const SizedBox(height: 4),
                          const Text(
                            'Upload JPG',
                            style: TextStyle(fontSize: 11),
                          ),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _AssetImageWithFallbacks(
                          imageUrls: previewUrls,
                          fit: BoxFit.contain,
                          emptyChild: Icon(
                            emptyIcon,
                            color: _companyEditPrimary,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 10),
              Text(
                previewUrl == null ? 'Tap to upload' : 'Tap to replace',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _companyEditPrimaryDark,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssetImageWithFallbacks extends StatefulWidget {
  final List<String> imageUrls;
  final BoxFit fit;
  final Widget emptyChild;

  const _AssetImageWithFallbacks({
    required this.imageUrls,
    required this.fit,
    required this.emptyChild,
  });

  @override
  State<_AssetImageWithFallbacks> createState() =>
      _AssetImageWithFallbacksState();
}

class _AssetImageWithFallbacksState extends State<_AssetImageWithFallbacks> {
  int _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _AssetImageWithFallbacks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.join('|') != widget.imageUrls.join('|')) {
      _imageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty || _imageIndex >= widget.imageUrls.length) {
      return widget.emptyChild;
    }

    final currentUrl = widget.imageUrls[_imageIndex];
    return Image.network(
      currentUrl,
      key: ValueKey('$currentUrl-$_imageIndex'),
      fit: widget.fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        if (_imageIndex < widget.imageUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _imageIndex += 1);
          });
          return const SizedBox.expand();
        }
        return widget.emptyChild;
      },
    );
  }
}
