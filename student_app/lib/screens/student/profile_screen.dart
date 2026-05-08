import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService();
  Map<String, dynamic>? _user;
  List<dynamic> _projects = [];
  bool _isLoading = true;
  bool _isDownloadingIdentificationCard = false;
  bool _isUploadingProfileImage = false;
  bool _isDeletingProfileImage = false;
  int _profileImageVersion = 0;
  Uint8List? _profileImagePreviewBytes;
  bool _hasProfileImageOverride = false;
  String? _profileImageUrlOverride;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  bool _isSuccessResponse(Map<String, dynamic> response) {
    final success = response['success'];
    if (success == true || success == 1) return true;
    if (success is String && success.toLowerCase() == 'true') return true;

    final status = response['status'];
    if (status is String && status.toLowerCase() == 'success') return true;

    return false;
  }

  List<dynamic> _extractListFromResponse(
    Map<String, dynamic> response, {
    required List<String> nestedKeys,
  }) {
    final data = response['data'];
    if (data is List) return data;

    if (data is Map<String, dynamic>) {
      for (final key in nestedKeys) {
        final value = data[key];
        if (value is List) return value;
      }
    }

    for (final key in nestedKeys) {
      final value = response[key];
      if (value is List) return value;
    }

    return [];
  }

  List<dynamic> _normalizeTechnologies(dynamic value) {
    if (value is List) return value;
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((tech) => tech.trim())
          .where((tech) => tech.isNotEmpty)
          .toList();
    }
    return [];
  }

  List<dynamic> _normalizeProjects(List<dynamic> rawProjects) {
    return rawProjects.map((project) {
      if (project is! Map<String, dynamic>) return project;

      return {
        ...project,
        'project_id':
            project['project_id'] ?? project['id'] ?? project['projectId'],
        'title':
            project['title'] ??
            project['project_title'] ??
            project['name'] ??
            'Untitled',
        'description': project['description'] ?? project['details'] ?? '',
        'technologies': _normalizeTechnologies(
          project['technologies'] ?? project['tech_stack'],
        ),
        'github_link':
            project['github_link'] ??
            project['githubUrl'] ??
            project['repo_url'],
        'live_demo_link':
            project['live_demo_link'] ??
            project['liveDemoLink'] ??
            project['project_url'] ??
            project['url'],
      };
    }).toList();
  }

  Map<String, dynamic>? _extractUserFromProfileResponse(
    Map<String, dynamic> response,
  ) {
    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final nestedUser = data['user'];
      if (nestedUser is Map<String, dynamic>) return nestedUser;
      return data;
    }
    final user = response['user'];
    if (user is Map<String, dynamic>) return user;
    return null;
  }

  Map<String, dynamic>? _mergeUserData(
    Map<String, dynamic>? primary,
    Map<String, dynamic>? fallback,
  ) {
    if (primary == null && fallback == null) return null;

    final merged = <String, dynamic>{
      if (fallback != null) ...fallback,
      if (primary != null) ...primary,
    };

    for (final nestedKey in const [
      'student_data',
      'company_data',
      'university_data',
    ]) {
      final primaryNested = primary?[nestedKey];
      final fallbackNested = fallback?[nestedKey];
      if (primaryNested is Map<String, dynamic> ||
          fallbackNested is Map<String, dynamic>) {
        merged[nestedKey] = {
          ...?(fallbackNested is Map<String, dynamic> ? fallbackNested : null),
          ...?(primaryNested is Map<String, dynamic> ? primaryNested : null),
        };
      }
    }

    if (_hasProfileImageOverride) {
      merged['profile_image_url'] = _profileImageUrlOverride;
    }

    return merged;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final provider = Provider.of<AuthProvider>(context, listen: false);
      final profileResponse = await _apiService.getProfile(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      final freshUser = _extractUserFromProfileResponse(profileResponse);
      final user = _mergeUserData(
        freshUser,
        _mergeUserData(provider.user, _user),
      );

      final projectsResponse = await _apiService.getStudentProjects();
      if (!mounted) return;

      setState(() {
        _user = user;
        _projects = _normalizeProjects(
          _extractListFromResponse(
            projectsResponse,
            nestedKeys: const ['projects', 'student_projects'],
          ),
        );
        _isLoading = false;
      });
    } catch (e) {
      _log('Error loading profile data: $e');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  String _fileNameFromUrl(String? url) {
    if (url == null || url.isEmpty) return '';
    return url.split('/').last;
  }

  String _resolveFileUrl(String path, {int? cacheBust}) {
    final trimmed = path.trim();
    if (trimmed.isEmpty) return trimmed;

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      if (cacheBust == null) return trimmed;
      final separator = trimmed.contains('?') ? '&' : '?';
      return '$trimmed${separator}v=$cacheBust';
    }
    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    final resolvedUrl = '${_apiService.baseUrl}$normalized';
    if (cacheBust == null) {
      return resolvedUrl;
    }
    final separator = resolvedUrl.contains('?') ? '&' : '?';
    return '$resolvedUrl${separator}v=$cacheBust';
  }

  String _resolveIdentificationCardUrl(String filePath) {
    return _resolveFileUrl(filePath);
  }

  int? _deriveAcademicYear(
    Map<String, dynamic>? studentData,
    bool isLegacyStudentRole,
  ) {
    if (isLegacyStudentRole) {
      return 4;
    }

    final expectedYear = int.tryParse(
      '${studentData?['expected_graduation_year'] ?? ''}',
    );
    if (expectedYear == null) return null;

    final currentYear = DateTime.now().year;
    final remainingYears = expectedYear - currentYear;
    if (remainingYears <= 0) return 3;
    if (remainingYears == 1) return 2;
    return 1;
  }

  String _academicYearLabel(
    Map<String, dynamic>? studentData,
    bool isLegacyStudentRole,
  ) {
    final academicYear = _deriveAcademicYear(studentData, isLegacyStudentRole);
    if (academicYear == null) {
      return 'Not specified';
    }

    if (isLegacyStudentRole) {
      return '';
    }

    return academicYear >= 3 ? 'Year 3+' : 'Year $academicYear';
  }

  String _gpaLabel(Map<String, dynamic>? studentData) {
    final value = '${studentData?['gpa'] ?? ''}'.trim();
    if (value.isEmpty || value == 'null') {
      return 'Not specified';
    }

    return value;
  }

  bool _isValidHttpUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        uri.hasScheme &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<void> _pickAndUploadProfileImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (!mounted || result == null) return;

      final file = result.files.single;
      final filePath = file.path;
      final fileBytes = file.bytes;
      if ((filePath == null || filePath.isEmpty) && fileBytes == null) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Unable to read selected image.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (file.size > 5 * 1024 * 1024) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Profile image must be less than 5MB'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isUploadingProfileImage = true);
      final response = await _apiService.uploadStudentProfileImage(
        filePath: filePath,
        fileBytes: fileBytes,
        fileName: file.name,
      );
      if (!mounted) return;

      if (_isSuccessResponse(response)) {
        final uploadedImageUrl =
            response['data']?['profile_image_url']?.toString() ??
            response['profile_image_url']?.toString();
        if (uploadedImageUrl != null && uploadedImageUrl.trim().isNotEmpty) {
          final refreshedAt = DateTime.now().millisecondsSinceEpoch;
          setState(() {
            _user = {...?_user, 'profile_image_url': uploadedImageUrl.trim()};
            _hasProfileImageOverride = true;
            _profileImageUrlOverride = uploadedImageUrl.trim();
            _profileImagePreviewBytes = fileBytes;
            _profileImageVersion = refreshedAt;
          });
        }
        await context.read<AuthProvider>().loadProfile();
        await _loadData(forceRefresh: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Profile photo uploaded successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Failed to upload profile image',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingProfileImage = false);
      }
    }
  }

  Future<void> _deleteProfileImage() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Profile Photo'),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      setState(() => _isDeletingProfileImage = true);
      final response = await _apiService.deleteStudentProfileImage();
      if (!mounted) return;

      if (_isSuccessResponse(response)) {
        final refreshedAt = DateTime.now().millisecondsSinceEpoch;
        setState(() {
          _user = {...?_user, 'profile_image_url': null};
          _hasProfileImageOverride = true;
          _profileImageUrlOverride = null;
          _profileImagePreviewBytes = null;
          _profileImageVersion = refreshedAt;
        });
        await context.read<AuthProvider>().loadProfile();
        await _loadData(forceRefresh: true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Profile photo removed successfully!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Failed to remove profile image',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() => _isDeletingProfileImage = false);
      }
    }
  }

  Future<void> _openProjectLink(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !_isValidHttpUrl(url)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Invalid project link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Unable to open project link'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      final androidDownload = Directory('/storage/emulated/0/Download');
      if (await androidDownload.exists()) {
        return androidDownload;
      }
    }

    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;

    return getApplicationDocumentsDirectory();
  }

  Future<void> _openIdentificationCard(String filePath) async {
    final fullUrl = _resolveIdentificationCardUrl(filePath);
    final uri = Uri.tryParse(fullUrl);
    if (uri == null) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Invalid identification card link'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Unable to open identification card'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadIdentificationCard(String filePath) async {
    if (_isDownloadingIdentificationCard) return;

    if (kIsWeb) {
      await _openIdentificationCard(filePath);
      return;
    }

    setState(() => _isDownloadingIdentificationCard = true);

    try {
      final fullUrl = _resolveIdentificationCardUrl(filePath);
      final token = await _apiService.getToken();
      final rawFileName = _fileNameFromUrl(filePath).isNotEmpty
          ? _fileNameFromUrl(filePath)
          : 'identification_card_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final safeFileName = rawFileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final directories = <Directory>[];
      final preferredDirectory = await _getDownloadDirectory();
      directories.add(preferredDirectory);
      final appDirectory = await getApplicationDocumentsDirectory();
      if (!directories.any(
        (directory) => directory.path == appDirectory.path,
      )) {
        directories.add(appDirectory);
      }

      final headers = <String, dynamic>{};
      if (token != null &&
          token.isNotEmpty &&
          fullUrl.startsWith(_apiService.baseUrl)) {
        headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
      }

      String? savePath;
      Object? lastError;

      for (final directory in directories) {
        final candidatePath = '${directory.path}/$safeFileName';

        try {
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          await Dio().download(
            fullUrl,
            candidatePath,
            options: Options(
              headers: headers.isEmpty ? null : headers,
              receiveTimeout: const Duration(seconds: 60),
              sendTimeout: const Duration(seconds: 60),
              followRedirects: true,
            ),
            deleteOnError: true,
          );
          savePath = candidatePath;
          break;
        } catch (error) {
          lastError = error;
          _log(
            'Identification card download failed for $candidatePath: $error',
          );
        }
      }

      if (savePath == null) {
        throw lastError ?? Exception('Unable to save identification card');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Identification card downloaded to: $savePath'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
    } catch (e) {
      final message = ApiService.normalizeErrorMessage(
        e,
        fallback: 'Failed to download identification card',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to download identification card: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isDownloadingIdentificationCard = false);
      }
    }
  }

  // ============ PROJECT METHODS ============
  void _showAddProjectDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final liveDemoController = TextEditingController();
    final techController = TextEditingController();
    List<String> technologies = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Add Project'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Project Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: liveDemoController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'Hosted Project Link',
                      hintText: 'https://your-project.com',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: techController,
                          decoration: const InputDecoration(
                            labelText: 'Technologies',
                            hintText: 'e.g., Flutter, Dart',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: AppTheme.primaryBlue,
                        ),
                        onPressed: () {
                          if (techController.text.isNotEmpty) {
                            setStateDialog(() {
                              technologies.add(techController.text);
                              techController.clear();
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  if (technologies.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: technologies
                          .map(
                            (tech) => Chip(
                              label: Text(tech),
                              onDeleted: () {
                                setStateDialog(() {
                                  technologies.remove(tech);
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty) {
                    final liveDemoLink = liveDemoController.text.trim();
                    if (liveDemoLink.isNotEmpty &&
                        !_isValidHttpUrl(liveDemoLink)) {
                      ScaffoldMessenger.of(context).showAppSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a valid hosted project link',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }
                    await _addProject(
                      titleController.text,
                      descriptionController.text,
                      technologies,
                      liveDemoLink,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showAppSnackBar(
                      const SnackBar(
                        content: Text('Please enter project title'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                child: const Text('Add Project'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addProject(
    String title,
    String description,
    List<String> technologies,
    String liveDemoLink,
  ) async {
    try {
      final response = await _apiService.addStudentProject({
        'title': title.trim(),
        'description': description.trim(),
        'technologies': technologies,
        'live_demo_link': liveDemoLink.isEmpty ? null : liveDemoLink,
      });
      if (!mounted) return;
      if (_isSuccessResponse(response)) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Project added!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        await _loadData();
      } else {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to add project'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _removeProject(String projectId) async {
    try {
      final response = await _apiService.removeStudentProject(projectId);
      if (!mounted) return;
      if (response['success']) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Project removed!'),
            backgroundColor: AppTheme.primaryGreen,
          ),
        );
        await _loadData();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openEditProfile() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (!mounted) return;
    if (result == true) {
      _loadData();
    }
  }

  Widget _buildProfileAvatar(String? profileImageUrl) {
    final resolvedUrl = (profileImageUrl ?? '').trim().isEmpty
        ? null
        : _resolveFileUrl(
            profileImageUrl!,
            cacheBust: _profileImageVersion > 0 ? _profileImageVersion : null,
          );
    final initials = _user?['full_name']?.toString().trim().isNotEmpty == true
        ? _user!['full_name'].toString().trim()[0].toUpperCase()
        : 'U';

    return Container(
      width: 104,
      height: 104,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.primaryBlue.withValues(alpha: 0.1),
      ),
      clipBehavior: Clip.antiAlias,
      child: _profileImagePreviewBytes != null
          ? Image.memory(
              _profileImagePreviewBytes!,
              key: ValueKey('memory-$_profileImageVersion'),
              fit: BoxFit.cover,
            )
          : resolvedUrl == null
          ? Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            )
          : Image.network(
              key: ValueKey('$resolvedUrl-$_profileImageVersion'),
              resolvedUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final studentData = _user?['student_data'];
    final isLegacyStudentRole = _user?['role'] == '';
    final profileImageUrl = _user?['profile_image_url']?.toString() ?? '';
    final hasProfileImage = profileImageUrl.trim().isNotEmpty;
    final identificationCardUrl =
        studentData?['identification_card_url']?.toString() ?? '';
    final hasIdentificationCard = identificationCardUrl.isNotEmpty;
    final identificationCardName =
        studentData?['identification_card_name']?.toString().trim() ?? '';
    final displayedIdentificationCardName = identificationCardName.isNotEmpty
        ? identificationCardName
        : _fileNameFromUrl(identificationCardUrl);

    final program = studentData?['program'] ?? 'Program not specified';
    final institution =
        studentData?['institution_name'] ??
        studentData?['university_name'] ??
        'Institution not specified';
    final expectedYear = studentData?['expected_graduation_year'];
    final graduationYear = studentData?['graduation_year'];
    final gpa = _gpaLabel(studentData);
    final academicYear = _academicYearLabel(studentData, isLegacyStudentRole);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: AppTheme.primaryBlue),
            onPressed: _openEditProfile,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              // Profile Header Card
              Container(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildProfileAvatar(profileImageUrl),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          alignment: WrapAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  _isUploadingProfileImage ||
                                      _isDeletingProfileImage
                                  ? null
                                  : _pickAndUploadProfileImage,
                              icon: _isUploadingProfileImage
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : Icon(
                                      hasProfileImage
                                          ? Icons.edit_outlined
                                          : Icons.camera_alt_outlined,
                                    ),
                              label: Text(
                                _isUploadingProfileImage
                                    ? 'Uploading...'
                                    : hasProfileImage
                                    ? 'Change Profile Photo'
                                    : 'Upload Profile Photo',
                              ),
                            ),
                            if (hasProfileImage)
                              TextButton.icon(
                                onPressed:
                                    _isUploadingProfileImage ||
                                        _isDeletingProfileImage
                                    ? null
                                    : _deleteProfileImage,
                                icon: _isDeletingProfileImage
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.delete_outline,
                                        color: Colors.red,
                                      ),
                                label: Text(
                                  _isDeletingProfileImage
                                      ? 'Removing...'
                                      : 'Remove Photo',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _user?['full_name'] ?? 'Student Name',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _user?['email'] ?? 'student@example.com',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            isLegacyStudentRole
                                ? 'Industrial Practical Training'
                                : 'Current Student',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.security_rounded,
                                size: 24,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Text(
                                'Profile',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _openEditProfile,
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Container(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 24,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'Identification Card',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: hasIdentificationCard
                              ? Row(
                                  children: [
                                    const Icon(
                                      Icons.badge_outlined,
                                      size: 20,
                                      color: AppTheme.primaryBlue,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () => _openIdentificationCard(
                                          identificationCardUrl,
                                        ),
                                        child: Text(
                                          displayedIdentificationCardName
                                                  .isNotEmpty
                                              ? 'Uploaded ID: $displayedIdentificationCardName (tap to open)'
                                              : 'Identification card uploaded successfully',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: AppTheme.primaryBlue,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Open ID',
                                      onPressed: () => _openIdentificationCard(
                                        identificationCardUrl,
                                      ),
                                      icon: const Icon(
                                        Icons.open_in_new,
                                        color: AppTheme.primaryBlue,
                                        size: 20,
                                      ),
                                    ),
                                    _isDownloadingIdentificationCard
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : IconButton(
                                            tooltip: 'Download ID',
                                            onPressed: () =>
                                                _downloadIdentificationCard(
                                                  identificationCardUrl,
                                                ),
                                            icon: const Icon(
                                              Icons.download,
                                              color: AppTheme.primaryBlue,
                                              size: 20,
                                            ),
                                          ),
                                  ],
                                )
                              : Text(
                                  'Your uploaded identification card will appear here after registration.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Education Section Card
              Container(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.school,
                                size: 24,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Text(
                              'Education',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _buildInfoRow('Institution', institution),
                        _buildInfoRow('Program', program),
                        _buildInfoRow('GPA', gpa),
                        _buildInfoRow('Academic Year', academicYear),
                        _buildInfoRow(
                          isLegacyStudentRole
                              ? 'Graduation Year'
                              : 'Expected Graduation',
                          isLegacyStudentRole
                              ? (graduationYear?.toString() ?? 'Not specified')
                              : (expectedYear?.toString() ?? 'Not specified'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Portfolio Projects Section Card (FIXED - NO OVERFLOW)
              Container(
                constraints: const BoxConstraints(maxWidth: 1300),
                child: Card(
                  elevation: 6,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentOrange.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.folder,
                                    size: 24,
                                    color: AppTheme.accentOrange,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                const Text(
                                  'Portfolio Projects',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: _showAddProjectDialog,
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.accentOrange,
                              ),
                              child: const Text(
                                '+ Add Project',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _projects.isEmpty
                            ? Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No projects added.\nShowcase your work!',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              )
                            : Column(
                                // FIXED: Changed from ListView.builder to Column
                                children: _projects.map((project) {
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 16),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  project['title'] ??
                                                      'Untitled',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete,
                                                  size: 20,
                                                  color: Colors.red,
                                                ),
                                                onPressed: () => _removeProject(
                                                  project['project_id'],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            project['description'] ??
                                                'No description',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if ((project['live_demo_link'] ?? '')
                                              .toString()
                                              .trim()
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children: [
                                                ActionChip(
                                                  avatar: const Icon(
                                                    Icons.open_in_new,
                                                    size: 16,
                                                    color: AppTheme.primaryBlue,
                                                  ),
                                                  label: const Text(
                                                    'Open Hosted Project',
                                                  ),
                                                  onPressed: () =>
                                                      _openProjectLink(
                                                        project['live_demo_link']
                                                            .toString(),
                                                      ),
                                                ),
                                              ],
                                            ),
                                          ],
                                          if (project['technologies'] != null &&
                                              project['technologies']
                                                  .isNotEmpty) ...[
                                            const SizedBox(height: 12),
                                            Wrap(
                                              spacing: 8,
                                              runSpacing: 8,
                                              children:
                                                  (project['technologies']
                                                          as List)
                                                      .map(
                                                        (tech) => Chip(
                                                          label: Text(
                                                            tech,
                                                            style:
                                                                const TextStyle(
                                                                  fontSize: 12,
                                                                ),
                                                          ),
                                                          materialTapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          backgroundColor:
                                                              AppTheme
                                                                  .accentOrange
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                        ),
                                                      )
                                                      .toList(),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
