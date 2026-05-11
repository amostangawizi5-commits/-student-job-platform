import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/browser_pdf_opener.dart';
import '../../services/coordinator_workspace_service.dart';
import '../../services/local_file_service.dart';

class MyApplicationsScreen extends StatefulWidget {
  final String initialFilter;
  final int refreshToken;

  const MyApplicationsScreen({
    super.key,
    this.initialFilter = 'all',
    this.refreshToken = 0,
  });

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  final ApiService _apiService = ApiService();
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  List<dynamic> _applications = [];
  Map<String, dynamic>? _confirmedSelection;
  Map<String, Map<String, dynamic>> _approvalByApplicationId = const {};
  bool _isLoading = true;
  String _selectedFilter = 'all';
  String? _confirmingApplicationId;
  final Set<String> _downloadingResponseLetters = <String>{};

  bool _canUseDirectFallback(String? fileUrl) {
    final trimmed = (fileUrl ?? '').trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFilter = _normalizeFilter(widget.initialFilter);
    _loadApplications();
  }

  @override
  void didUpdateWidget(covariant MyApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _selectedFilter = _normalizeFilter(widget.initialFilter);
      });
    }

    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadApplications();
    }
  }

  String _normalizeFilter(String filter) {
    switch (filter.toLowerCase()) {
      case '':
      case 'pending':
      case 'review':
      case 'accepted':
      case 'rejected':
        return filter.toLowerCase();
      default:
        return 'all';
    }
  }

  bool _matchesSelectedFilter(Map<String, dynamic> app) {
    if (_selectedFilter == 'all') return true;

    final status = '${app['status'] ?? ''}'.toLowerCase();
    if (_selectedFilter == 'review') {
      return status == 'shortlisted' ||
          status == 'review' ||
          status == 'under_review';
    }
    return status == _selectedFilter;
  }

  List<dynamic> _getFilteredApplications() {
    return _applications.where((app) {
      if (app is! Map<String, dynamic>) return false;
      return _matchesSelectedFilter(app);
    }).toList();
  }

  String _filterTitle() {
    switch (_selectedFilter) {
      case '':
        return '';
      case 'pending':
        return 'Pending';
      case 'review':
        return 'Review';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'All';
    }
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final currentUser = context.read<AuthProvider>().user;
    final studentEmail = currentUser?['email']?.toString() ?? '';
    try {
      final response = await _apiService.getMyApplications();
      final approvalRecords = await _workspaceService.getApprovalRecords();
      final selection = await _workspaceService.getStudentSelection(
        studentEmail,
      );
      final approvalsByApplicationId = <String, Map<String, dynamic>>{};
      for (final approval in approvalRecords) {
        final applicationId = '${approval['application_id'] ?? ''}'.trim();
        if (applicationId.isEmpty ||
            approvalsByApplicationId.containsKey(applicationId)) {
          continue;
        }
        approvalsByApplicationId[applicationId] = approval;
      }
      debugPrint('Applications: ${response['data']?.length ?? 0}');
      if (response['success']) {
        final applications = (response['data'] as List<dynamic>? ?? const []);
        if (!mounted) return;
        setState(() {
          _applications = applications;
          _confirmedSelection = selection;
          _approvalByApplicationId = approvalsByApplicationId;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _confirmedSelection = selection;
          _approvalByApplicationId = approvalsByApplicationId;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      final selection = await _workspaceService.getStudentSelection(
        studentEmail,
      );
      if (!mounted) return;
      setState(() {
        _confirmedSelection = selection;
        _isLoading = false;
      });
    }
  }

  bool _isOfferConfirmationExpired(String applicationId) {
    final approval = _approvalByApplicationId[applicationId.trim()];
    if (approval == null) return false;

    final choiceStatus = '${approval['student_choice_status'] ?? ''}'
        .trim()
        .toLowerCase();
    final companyStatus = '${approval['company_selection_status'] ?? ''}'
        .trim()
        .toLowerCase();

    return choiceStatus == 'expired' || companyStatus == 'expired';
  }

  DateTime? _offerConfirmationExpiresAt(String applicationId) {
    final raw =
        _approvalByApplicationId[applicationId
            .trim()]?['confirmation_expires_at'];
    final normalized = '$raw'.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized)?.toLocal();
  }

  List<Map<String, dynamic>> get _acceptedApplications {
    return _applications
        .whereType<Map>()
        .map((item) => item.map((key, value) => MapEntry('$key', value)))
        .where((app) => '${app['status'] ?? ''}'.toLowerCase() == 'accepted')
        .toList(growable: false);
  }

  bool _isConfirmedApplication(String applicationId) {
    return '${_confirmedSelection?['selected_application_id'] ?? ''}' ==
        applicationId;
  }

  Future<void> _confirmCompanySelection(Map<String, dynamic> app) async {
    final currentUser = context.read<AuthProvider>().user;
    final studentData = currentUser?['student_data'] as Map<String, dynamic>?;
    final studentEmail = currentUser?['email']?.toString() ?? '';
    final studentName = currentUser?['full_name']?.toString() ?? 'Student';
    final universityName = studentData?['university_name']?.toString() ?? '';
    final applicationId = '${app['application_id'] ?? ''}';
    final companyName = '${app['company_name'] ?? 'Company'}';
    final jobTitle = '${app['title'] ?? app['job_title'] ?? 'Placement'}';
    final isOfferExpired = _isOfferConfirmationExpired(applicationId);

    if (isOfferExpired) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'This offer expired because it was not confirmed within 48 hours.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (studentEmail.trim().isEmpty || universityName.trim().isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Missing student or university details.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final existingApplicationId =
        '${_confirmedSelection?['selected_application_id'] ?? ''}';
    if (existingApplicationId.isNotEmpty &&
        existingApplicationId != applicationId) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'You already confirmed ${_confirmedSelection?['selected_company_name'] ?? 'another company'}.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Confirm Company Placement'),
        content: Text(
          _acceptedApplications.length > 1
              ? 'You were accepted by ${_acceptedApplications.length} companies. Confirming $companyName will notify the other companies that you chose another placement.'
              : 'Confirm $companyName as the company you will join for this placement?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _confirmingApplicationId = applicationId);
    try {
      await _workspaceService.confirmStudentCompanySelection(
        studentName: studentName,
        studentEmail: studentEmail,
        universityName: universityName,
        chosenApplicationId: applicationId,
        chosenCompanyName: companyName,
        chosenTrainingTitle: jobTitle,
        reportingStartDate: app['reporting_start_date']?.toString(),
        reportingEndDate: app['reporting_end_date']?.toString(),
        acceptedApplications: _acceptedApplications,
      );
      final selection = await _workspaceService.getStudentSelection(
        studentEmail,
      );
      if (!mounted) return;
      setState(() => _confirmedSelection = selection);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'You confirmed $companyName successfully. The coordinator has been notified.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } on StateError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(error.message), backgroundColor: Colors.orange),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to confirm company: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _confirmingApplicationId = null);
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'shortlisted':
        return Colors.blue;
      case '':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'shortlisted':
        return 'Shortlisted';
      case '':
        return ' Scheduled';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'shortlisted':
        return Icons.star;
      case '':
        return Icons.calendar_today;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _resolveFileUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${_apiService.baseUrl}$normalized';
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return getApplicationDocumentsDirectory();
    }

    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;

    return getApplicationDocumentsDirectory();
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    final fallback =
        'response_letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final normalized = trimmed.isEmpty ? fallback : trimmed;
    return normalized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<String> _downloadToAvailableDirectory(
    String pathOrUrl, {
    required String fileName,
    bool requiresAuth = false,
  }) async {
    final directories = <Directory>[];

    final preferredDirectory = await _getDownloadDirectory();
    directories.add(preferredDirectory);

    final appDirectory = await getApplicationDocumentsDirectory();
    if (!directories.any((directory) => directory.path == appDirectory.path)) {
      directories.add(appDirectory);
    }

    Object? lastError;

    for (final directory in directories) {
      final savePath = '${directory.path}/$fileName';

      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final bytes = await _apiService.downloadFileBytes(
          pathOrUrl,
          requiresAuth: requiresAuth,
        );
        await File(savePath).writeAsBytes(bytes, flush: true);
        return savePath;
      } catch (error) {
        lastError = error;
        _log('Download failed for $savePath: $error');
      }
    }

    throw lastError ?? Exception('Unable to save file');
  }

  Future<bool> _openLocalFile(String filePath) async {
    return LocalFileService.openFile(filePath);
  }

  Future<void> _openAuthenticatedPdf(
    String pathOrUrl, {
    required String fileName,
    required String failureMessage,
  }) async {
    if (kIsWeb) {
      final bytes = await _apiService.downloadFileBytes(
        pathOrUrl,
        requiresAuth: true,
      );
      final launched = await openPdfBytesInBrowser(
        bytes,
        fileName: _sanitizeFileName(fileName),
      );
      if (!launched) {
        throw Exception(failureMessage);
      }
      return;
    }

    final savePath = await _downloadToAvailableDirectory(
      pathOrUrl,
      fileName: _sanitizeFileName(fileName),
      requiresAuth: true,
    );
    final opened = await _openLocalFile(savePath);
    if (!opened) {
      throw Exception('Unable to open downloaded file.');
    }
  }

  Future<void> _openFile(
    String? fileUrl, {
    String? authenticatedUrl,
    String? fileName,
    required String invalidMessage,
    required String failureMessage,
  }) async {
    final effectiveUrl = authenticatedUrl ?? fileUrl;

    if (authenticatedUrl != null) {
      if (effectiveUrl == null || effectiveUrl.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
        );
        return;
      }

      try {
        await _openAuthenticatedPdf(
          effectiveUrl,
          fileName: fileName ?? 'document.pdf',
          failureMessage: failureMessage,
        );
      } catch (error) {
        if (_canUseDirectFallback(fileUrl)) {
          await _openFile(
            fileUrl,
            fileName: fileName,
            invalidMessage: invalidMessage,
            failureMessage: failureMessage,
          );
          return;
        }

        final message = ApiService.normalizeErrorMessage(
          error,
          fallback: failureMessage,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (fileUrl == null || fileUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final uri = Uri.tryParse(_resolveFileUrl(fileUrl));
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(failureMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _downloadFile(
    String? fileUrl, {
    String? authenticatedUrl,
    required String fileName,
    required String invalidMessage,
    required String failureMessage,
    required String successLabel,
    bool saveToDownloadsOnAndroid = false,
  }) async {
    final effectiveUrl = authenticatedUrl ?? fileUrl;

    if (effectiveUrl == null || effectiveUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    if (kIsWeb) {
      if (authenticatedUrl != null) {
        try {
          await _openAuthenticatedPdf(
            authenticatedUrl,
            fileName: fileName,
            failureMessage: failureMessage,
          );
        } catch (error) {
          if (_canUseDirectFallback(fileUrl)) {
            await _downloadFile(
              fileUrl,
              fileName: fileName,
              invalidMessage: invalidMessage,
              failureMessage: failureMessage,
              successLabel: successLabel,
              saveToDownloadsOnAndroid: saveToDownloadsOnAndroid,
            );
            return;
          }

          final message = ApiService.normalizeErrorMessage(
            error,
            fallback: failureMessage,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showAppSnackBar(
            SnackBar(content: Text(message), backgroundColor: Colors.red),
          );
        }
      } else {
        await _openFile(
          fileUrl ?? effectiveUrl,
          invalidMessage: invalidMessage,
          failureMessage: failureMessage,
        );
      }
      return;
    }

    final resolvedUrl = _resolveFileUrl(effectiveUrl);
    final requiresAuth = authenticatedUrl != null;

    setState(() => _downloadingResponseLetters.add(resolvedUrl));

    try {
      final safeFileName = _sanitizeFileName(fileName);
      final savePath = await _downloadToAvailableDirectory(
        authenticatedUrl ?? resolvedUrl,
        fileName: safeFileName,
        requiresAuth: requiresAuth,
      );
      final finalPath = Platform.isAndroid && saveToDownloadsOnAndroid
          ? await LocalFileService.copyFileToDownloads(
              savePath,
              fileName: safeFileName,
            )
          : savePath;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('$successLabel: $finalPath'),
          backgroundColor: Colors.green,
        ),
      );
    } on DioException catch (e) {
      if (authenticatedUrl != null && _canUseDirectFallback(fileUrl)) {
        await _downloadFile(
          fileUrl,
          fileName: fileName,
          invalidMessage: invalidMessage,
          failureMessage: failureMessage,
          successLabel: successLabel,
          saveToDownloadsOnAndroid: saveToDownloadsOnAndroid,
        );
        return;
      }

      final responseData = e.response?.data;
      final message = ApiService.normalizeErrorMessage(
        responseData is Map<String, dynamic>
            ? (responseData['message'] ?? responseData['error'] ?? e.message)
            : e,
        fallback: failureMessage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('$failureMessage: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (authenticatedUrl != null && _canUseDirectFallback(fileUrl)) {
        await _downloadFile(
          fileUrl,
          fileName: fileName,
          invalidMessage: invalidMessage,
          failureMessage: failureMessage,
          successLabel: successLabel,
          saveToDownloadsOnAndroid: saveToDownloadsOnAndroid,
        );
        return;
      }

      final message = ApiService.normalizeErrorMessage(
        e,
        fallback: failureMessage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('$failureMessage: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingResponseLetters.remove(resolvedUrl));
      }
    }
  }

  String _documentReviewText(dynamic verifiedValue) {
    if (verifiedValue == true) return 'Authentic';
    if (verifiedValue == false) return 'Not Authentic';
    return 'Pending Review';
  }

  Color _documentReviewColor(dynamic verifiedValue) {
    if (verifiedValue == true) return Colors.green;
    if (verifiedValue == false) return Colors.red;
    return Colors.orange;
  }

  Widget _buildApplicationActionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color backgroundColor,
    required Color borderColor,
    required Color iconColor,
    required Color textColor,
    VoidCallback? onTap,
    Widget? trailing,
    bool showChevron = true,
    bool isLoading = false,
  }) {
    final isEnabled = onTap != null && !isLoading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onTap : null,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          width: double.infinity,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: iconColor,
                            ),
                          )
                        : Icon(icon, color: iconColor, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: textColor.withValues(alpha: 0.82),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                trailing ??
                    (showChevron
                        ? Icon(
                            Icons.chevron_right_rounded,
                            color: textColor,
                            size: 24,
                          )
                        : const SizedBox.shrink()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInlineInfoPill({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineActionPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color backgroundColor = const Color(0xFFEAF3FF),
    Color borderColor = const Color(0xFFB8D4FF),
    Color textColor = const Color(0xFF1D4ED8),
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: textColor),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showApplicationPreview(Map<String, dynamic> app) async {
    final reviewColor = _documentReviewColor(
      app['supportive_document_verified'],
    );
    final reviewText = _documentReviewText(app['supportive_document_verified']);
    final verificationNotes =
        app['supportive_document_verification_notes']?.toString() ?? '';
    final companyFeedback = app['company_feedback']?.toString() ?? '';
    final responseLetterUrl = app['response_letter_url']?.toString() ?? '';
    final responseLetterName =
        app['response_letter_name']?.toString() ?? 'response_letter.pdf';
    final coverLetterUrl = app['cover_letter']?.toString() ?? '';
    final supportiveDocumentUrl =
        app['supportive_document_url']?.toString() ?? '';
    final supportiveDocumentName =
        app['supportive_document_name']?.toString() ?? 'supportive_document';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        Widget infoTile({
          required IconData icon,
          required String label,
          required String value,
        }) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: 18, color: const Color(0xFF334155)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value.isEmpty ? '-' : value,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app['title']?.toString() ?? 'Application Preview',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    app['company_name']?.toString() ?? 'Unknown Company',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  infoTile(
                    icon: Icons.location_on_outlined,
                    label: 'Location',
                    value: app['location']?.toString() ?? '',
                  ),
                  infoTile(
                    icon: Icons.work_outline_rounded,
                    label: 'Training Type',
                    value: app['type']?.toString() ?? 'Job',
                  ),
                  infoTile(
                    icon: Icons.calendar_today_outlined,
                    label: 'Applied Date',
                    value: _formatDate(app['applied_date']?.toString() ?? ''),
                  ),
                  infoTile(
                    icon: Icons.verified_outlined,
                    label: 'Supportive Document Review',
                    value: supportiveDocumentUrl.isEmpty
                        ? 'No supportive document attached'
                        : reviewText,
                  ),
                  if ((app['reporting_start_date'] ?? '').toString().isNotEmpty)
                    infoTile(
                      icon: Icons.event_available_outlined,
                      label: 'Reporting Start',
                      value: _formatDate(
                        app['reporting_start_date']?.toString() ?? '',
                      ),
                    ),
                  if ((app['reporting_end_date'] ?? '').toString().isNotEmpty)
                    infoTile(
                      icon: Icons.event_busy_outlined,
                      label: 'Reporting End',
                      value: _formatDate(
                        app['reporting_end_date']?.toString() ?? '',
                      ),
                    ),
                  if (verificationNotes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: reviewColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: reviewColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        'Verification notes: $verificationNotes',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  if (companyFeedback.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Company feedback: $companyFeedback',
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Text(
                    'Documents',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (coverLetterUrl.isNotEmpty &&
                          (coverLetterUrl.startsWith('http://') ||
                              coverLetterUrl.startsWith('https://') ||
                              coverLetterUrl.startsWith('/')))
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _openFile(
                            coverLetterUrl,
                            authenticatedUrl: app['application_id'] == null
                                ? null
                                : '/api/applications/${app['application_id']}/cover-letter',
                            fileName: 'cover_letter.pdf',
                            invalidMessage: 'Cover letter link is invalid.',
                            failureMessage: 'Unable to open cover letter.',
                          ),
                          icon: const Icon(Icons.description_outlined),
                          label: const Flexible(
                            child: Text(
                              'Open Cover Letter',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      if (supportiveDocumentUrl.isNotEmpty)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _openFile(
                            supportiveDocumentUrl,
                            authenticatedUrl: app['application_id'] == null
                                ? null
                                : '/api/applications/${app['application_id']}/supportive-document',
                            fileName: supportiveDocumentName,
                            invalidMessage:
                                'Supportive document link is invalid.',
                            failureMessage:
                                'Unable to open supportive document.',
                          ),
                          icon: const Icon(Icons.picture_as_pdf_outlined),
                          label: const Flexible(
                            child: Text(
                              'Open Supportive Document',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                      if (responseLetterUrl.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: () => _downloadFile(
                            responseLetterUrl,
                            authenticatedUrl: app['application_id'] == null
                                ? null
                                : '/api/applications/${app['application_id']}/response-letter',
                            fileName: responseLetterName,
                            invalidMessage: 'Response letter link is invalid.',
                            failureMessage:
                                'Failed to download response letter',
                            successLabel: 'Response letter downloaded to',
                            saveToDownloadsOnAndroid: true,
                          ),
                          icon: const Icon(Icons.download_rounded),
                          label: const Flexible(
                            child: Text(
                              'Download Response Letter',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredApplications = _getFilteredApplications();
    final acceptedApplications = _acceptedApplications;
    final title = _selectedFilter == 'all'
        ? 'My Applications'
        : 'My Applications (${_filterTitle()})';

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (filteredApplications.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_turned_in,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'all'
                    ? 'No applications yet'
                    : 'No ${_filterTitle().toLowerCase()} applications yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFilter == 'all'
                    ? 'Start applying for training to see them here'
                    : 'Try another filter or apply to more training',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Use pop until first to avoid navigation stack issues
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: '', child: Text('')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'review', child: Text('Review')),
              PopupMenuItem(value: 'accepted', child: Text('Accepted')),
              PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredApplications.length,
        itemBuilder: (context, index) {
          final app = filteredApplications[index];
          final status = app['status'] ?? 'pending';
          final applicationId = '${app['application_id'] ?? ''}';
          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final statusIcon = _getStatusIcon(status);
          final hasConfirmedSelection = _confirmedSelection != null;
          final isConfirmedThisApplication = _isConfirmedApplication(
            applicationId,
          );
          final isOfferExpired = _isOfferConfirmationExpired(applicationId);
          final offerExpiresAt = _offerConfirmationExpiresAt(applicationId);
          final confirmedCompanyName =
              '${_confirmedSelection?['selected_company_name'] ?? ''}';
          final isConfirming = _confirmingApplicationId == applicationId;
          final title = '${app['title'] ?? app['job_title'] ?? 'Placement'}';
          final companyName = '${app['company_name'] ?? 'Unknown Company'}';
          final location = '${app['location'] ?? 'Location not specified'}';

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(
                                  Icons.business_outlined,
                                  size: 15,
                                  color: Colors.grey.shade600,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    companyName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildInlineInfoPill(
                          icon: Icons.location_on_outlined,
                          label: location,
                          backgroundColor: const Color(0xFFF8FAFC),
                          borderColor: const Color(0xFFE2E8F0),
                          textColor: const Color(0xFF475569),
                        ),
                        const SizedBox(width: 8),
                        _buildInlineInfoPill(
                          icon: statusIcon,
                          label: statusText,
                          backgroundColor: statusColor.withValues(alpha: 0.1),
                          borderColor: statusColor.withValues(alpha: 0.3),
                          textColor: statusColor,
                        ),
                        const SizedBox(width: 8),
                        _buildInlineActionPill(
                          icon: Icons.visibility_outlined,
                          label: 'Preview',
                          onTap: () => _showApplicationPreview(
                            Map<String, dynamic>.from(app),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (status == 'accepted') ...[
                    const SizedBox(height: 12),
                    _buildApplicationActionTile(
                      icon: isOfferExpired
                          ? Icons.hourglass_disabled_rounded
                          : isConfirmedThisApplication
                          ? Icons.verified_rounded
                          : hasConfirmedSelection
                          ? Icons.lock_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      label: isOfferExpired
                          ? 'Confirmation Window Expired'
                          : isConfirmedThisApplication
                          ? 'Confirmed Placement'
                          : hasConfirmedSelection
                          ? 'Placement Confirmed Elsewhere'
                          : acceptedApplications.length > 1
                          ? 'Choose This Company'
                          : 'Confirm This Company',
                      subtitle: isOfferExpired
                          ? offerExpiresAt == null
                                ? 'This accepted offer expired because it was not confirmed within 48 hours while you had multiple accepted companies.'
                                : 'This accepted offer expired because it was not confirmed within 48 hours while you had multiple accepted companies. Deadline was ${_formatDate(offerExpiresAt.toIso8601String())}.'
                          : isConfirmedThisApplication
                          ? 'You selected ${app['company_name'] ?? 'this company'}.'
                          : hasConfirmedSelection
                          ? 'You already confirmed $confirmedCompanyName, so this offer is no longer active.'
                          : acceptedApplications.length > 1
                          ? 'You have ${acceptedApplications.length} accepted offers. Confirm the company you will join so the other companies can be notified.'
                          : 'Confirm this accepted offer to continue with university review.',
                      backgroundColor: isOfferExpired
                          ? const Color(0xFFFFF4EC)
                          : isConfirmedThisApplication
                          ? const Color(0xFFEAF7F2)
                          : hasConfirmedSelection
                          ? const Color(0xFFFFF4EC)
                          : const Color(0xFFEAF6EE),
                      borderColor: isOfferExpired
                          ? const Color(0xFFF2BE8C)
                          : isConfirmedThisApplication
                          ? const Color(0xFF7BC9A8)
                          : hasConfirmedSelection
                          ? const Color(0xFFF2BE8C)
                          : const Color(0xFFA7D7BA),
                      iconColor: isOfferExpired
                          ? const Color(0xFFD97706)
                          : isConfirmedThisApplication
                          ? const Color(0xFF0F766E)
                          : hasConfirmedSelection
                          ? const Color(0xFFD97706)
                          : const Color(0xFF0F766E),
                      textColor: isOfferExpired
                          ? const Color(0xFFB45309)
                          : isConfirmedThisApplication
                          ? const Color(0xFF0F766E)
                          : hasConfirmedSelection
                          ? const Color(0xFFB45309)
                          : const Color(0xFF0F766E),
                      onTap: !hasConfirmedSelection && !isOfferExpired
                          ? () => _confirmCompanySelection(
                              Map<String, dynamic>.from(app),
                            )
                          : null,
                      isLoading: isConfirming,
                      trailing: isOfferExpired
                          ? const Icon(
                              Icons.lock_clock_rounded,
                              color: Color(0xFFD97706),
                              size: 22,
                            )
                          : isConfirmedThisApplication
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF0F766E),
                              size: 22,
                            )
                          : hasConfirmedSelection
                          ? const Icon(
                              Icons.block_rounded,
                              color: Color(0xFFD97706),
                              size: 22,
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
