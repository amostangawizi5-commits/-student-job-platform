import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';

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
  List<dynamic> _applications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';
  final Set<String> _downloadingResponseLetters = <String>{};

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
      case 'interview':
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
      case 'interview':
        return 'Interview';
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
    try {
      final response = await _apiService.getMyApplications();
      debugPrint('Applications: ${response['data']?.length ?? 0}');
      if (response['success']) {
        setState(() {
          _applications = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
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
      case 'interview':
        return 'Interview Scheduled';
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
      case 'interview':
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
      final androidDownload = Directory('/storage/emulated/0/Download');
      if (await androidDownload.exists()) {
        return androidDownload;
      }
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

  Options _downloadOptions(String resolvedUrl, String? token) {
    final headers = <String, dynamic>{};
    if (token != null &&
        token.isNotEmpty &&
        resolvedUrl.startsWith(_apiService.baseUrl)) {
      headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    return Options(
      headers: headers.isEmpty ? null : headers,
      receiveTimeout: const Duration(seconds: 60),
      sendTimeout: const Duration(seconds: 60),
      followRedirects: true,
    );
  }

  Future<String> _downloadToAvailableDirectory(
    String resolvedUrl, {
    required String fileName,
  }) async {
    final token = await _apiService.getToken();
    final options = _downloadOptions(resolvedUrl, token);
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

        await Dio().download(
          resolvedUrl,
          savePath,
          options: options,
          deleteOnError: true,
        );
        return savePath;
      } catch (error) {
        lastError = error;
        _log('Download failed for $savePath: $error');
      }
    }

    throw lastError ?? Exception('Unable to save file');
  }

  Future<void> _openFile(
    String? fileUrl, {
    required String invalidMessage,
    required String failureMessage,
  }) async {
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final uri = Uri.tryParse(_resolveFileUrl(fileUrl));
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
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
  }) async {
    final effectiveUrl = authenticatedUrl ?? fileUrl;

    if (effectiveUrl == null || effectiveUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    if (kIsWeb) {
      await _openFile(
        fileUrl ?? effectiveUrl,
        invalidMessage: invalidMessage,
        failureMessage: failureMessage,
      );
      return;
    }

    final resolvedUrl = _resolveFileUrl(effectiveUrl);

    setState(() => _downloadingResponseLetters.add(resolvedUrl));

    try {
      final safeFileName = _sanitizeFileName(fileName);
      final savePath = await _downloadToAvailableDirectory(
        resolvedUrl,
        fileName: safeFileName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$successLabel: $savePath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      final message = ApiService.normalizeErrorMessage(
        e,
        fallback: failureMessage,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
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

  @override
  Widget build(BuildContext context) {
    final filteredApplications = _getFilteredApplications();
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
                    ? 'Start applying for jobs to see them here'
                    : 'Try another filter or apply to more jobs',
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
              PopupMenuItem(value: 'interview', child: Text('Interview')),
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
          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final statusIcon = _getStatusIcon(status);
          final reviewColor = _documentReviewColor(
            app['supportive_document_verified'],
          );
          final reviewText = _documentReviewText(
            app['supportive_document_verified'],
          );
          final verificationNotes =
              app['supportive_document_verification_notes']?.toString();
          final companyFeedback = app['company_feedback']?.toString();
          final responseLetterUrl = app['response_letter_url']?.toString();
          final responseLetterName =
              app['response_letter_name']?.toString() ?? 'response_letter.pdf';
          final isDownloadingResponseLetter =
              responseLetterUrl != null &&
              _downloadingResponseLetters.contains(
                _resolveFileUrl(responseLetterUrl),
              );
          final profileResumeUrl = app['resume_url']?.toString();
          final hasProfileResume =
              profileResumeUrl != null && profileResumeUrl.isNotEmpty;
          final supportiveDocumentUrl = app['supportive_document_url']
              ?.toString();
          final supportiveDocumentName =
              app['supportive_document_name']?.toString() ??
              'supportive_document';
          final hasSupportiveDocument =
              supportiveDocumentUrl != null && supportiveDocumentUrl.isNotEmpty;
          final displayReviewText = hasSupportiveDocument
              ? reviewText
              : 'Cover letter only';
          final displayReviewColor = hasSupportiveDocument
              ? reviewColor
              : Colors.blueGrey;

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
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app['company_name'] ?? 'Unknown Company',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (hasProfileResume) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD9E2EC)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profile CV attached automatically',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openFile(
                                profileResumeUrl,
                                invalidMessage: 'Profile CV link is invalid.',
                                failureMessage: 'Unable to open profile CV.',
                              ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open Profile CV'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: displayReviewColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: displayReviewColor.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              size: 16,
                              color: displayReviewColor,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              hasSupportiveDocument
                                  ? 'Supportive Document: $displayReviewText'
                                  : 'Supportive Document: Not attached',
                              style: TextStyle(
                                color: displayReviewColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        if (verificationNotes != null &&
                            verificationNotes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Verification notes: $verificationNotes',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ],
                        const SizedBox(height: 8),
                        if (hasSupportiveDocument) ...[
                          Text(
                            'Supportive document file: $supportiveDocumentName',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _openFile(
                                supportiveDocumentUrl,
                                invalidMessage:
                                    'Supportive document link is invalid.',
                                failureMessage:
                                    'Unable to open supportive document.',
                              ),
                              icon: const Icon(Icons.open_in_new, size: 16),
                              label: const Text('Open Supportive PDF'),
                            ),
                          ),
                        ] else
                          Text(
                            'No supportive document was attached to this application.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          app['location'] ?? 'Location not specified',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.work, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        app['type'] ?? 'Job',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Applied: ${_formatDate(app['applied_date'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  if (companyFeedback != null &&
                      companyFeedback.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        'Company feedback: $companyFeedback',
                        style: TextStyle(color: Colors.grey.shade800),
                      ),
                    ),
                  ],
                  if (responseLetterUrl != null &&
                      responseLetterUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFD7E0EA)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_outlined),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Response letter: $responseLetterName',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: isDownloadingResponseLetter
                                ? null
                                : () => _downloadFile(
                                    responseLetterUrl,
                                    authenticatedUrl:
                                        app['application_id'] == null
                                        ? null
                                        : '/api/applications/${app['application_id']}/response-letter',
                                    fileName: responseLetterName,
                                    invalidMessage:
                                        'Response letter link is invalid.',
                                    failureMessage:
                                        'Failed to download response letter',
                                    successLabel:
                                        'Response letter downloaded to',
                                  ),
                            child: Text(
                              isDownloadingResponseLetter
                                  ? 'Downloading...'
                                  : 'Download',
                            ),
                          ),
                        ],
                      ),
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
