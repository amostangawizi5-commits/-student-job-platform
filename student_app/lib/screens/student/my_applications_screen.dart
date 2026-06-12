import 'dart:convert';
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
import 'test_attempt_screen.dart';

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
      case 'assigned':
      case 'shortlisted':
      case 'review':
      case 'accepted':
      case 'confirmed':
      case 'expired':
      case 'rejected':
        return filter.toLowerCase();
      default:
        return 'all';
    }
  }

  bool _matchesSelectedFilter(Map<String, dynamic> app) {
    if (_selectedFilter == 'all') return true;

    final status = _effectiveStudentStatus(app);
    if (_selectedFilter == 'review') {
      return status == 'shortlisted' ||
          status == 'review' ||
          status == 'under_review';
    }
    if (_selectedFilter == 'shortlisted') {
      return status == 'shortlisted';
    }
    return status == _selectedFilter;
  }

  bool _sameEmail(Object? left, Object? right) {
    return '$left'.trim().toLowerCase() == '$right'.trim().toLowerCase();
  }

  Map<String, dynamic> _mapManualPlacementToApplication(
    Map<String, dynamic> placement,
  ) {
    final placementId = '${placement['id'] ?? ''}'.trim();
    final applicationId = '${placement['application_id'] ?? ''}'.trim();
    final assignmentId = applicationId.isNotEmpty
        ? applicationId
        : placementId.isEmpty
        ? 'manual-placement'
        : 'manual-placement:$placementId';
    final placementStatus = '${placement['status'] ?? 'assigned'}'
        .trim()
        .toLowerCase();
    final companyResponseStatus =
        '${placement['company_response_status'] ?? placementStatus}'
            .trim()
            .toLowerCase();
    final studentStatus = companyResponseStatus == 'accepted'
        ? 'confirmed'
        : placementStatus.isEmpty
        ? 'assigned'
        : placementStatus;

    return {
      'application_id': assignmentId,
      'status': studentStatus,
      'company_response_status': companyResponseStatus,
      'raw_manual_status': placementStatus,
      'title': '${placement['training_title'] ?? 'Placement'}',
      'job_title': '${placement['training_title'] ?? 'Placement'}',
      'company_name': '${placement['company_name'] ?? 'Organization'}',
      'location': '${placement['placement_location'] ?? ''}',
      'applied_date':
          '${placement['assigned_at'] ?? placement['updated_at'] ?? placement['created_at'] ?? ''}',
      'assigned_at':
          '${placement['assigned_at'] ?? placement['updated_at'] ?? placement['created_at'] ?? ''}',
      'company_feedback':
          '${placement['company_response_notes'] ?? placement['coordinator_notes'] ?? ''}',
      'reporting_start_date':
          '${placement['reporting_start_date'] ?? placement['start_date'] ?? ''}',
      'reporting_end_date':
          '${placement['reporting_end_date'] ?? placement['end_date'] ?? ''}',
      'university_name': '${placement['university_name'] ?? ''}',
      'is_manual_assignment': true,
      'coordinator_name': '${placement['coordinator_name'] ?? ''}',
      'student_phone': '${placement['student_phone'] ?? ''}',
      'registration_number': '${placement['registration_number'] ?? ''}',
      'placement_location': '${placement['placement_location'] ?? ''}',
      'placement_department': '${placement['placement_department'] ?? ''}',
      'company_phone': '${placement['company_phone'] ?? ''}',
    };
  }

  Map<String, dynamic>? _buildConfirmedSelectionFromPlacement(
    List<Map<String, dynamic>> placements,
  ) {
    final confirmedPlacements = placements
        .where((placement) {
          final status = '${placement['status'] ?? ''}'.trim().toLowerCase();
          final companyResponseStatus =
              '${placement['company_response_status'] ?? status}'
                  .trim()
                  .toLowerCase();
          return status == 'confirmed' || companyResponseStatus == 'accepted';
        })
        .toList(growable: false);
    if (confirmedPlacements.isEmpty) return null;
    final latest = confirmedPlacements.first;
    final applicationId = '${latest['application_id'] ?? ''}'.trim();
    return {
      'selected_application_id': applicationId.isNotEmpty
          ? applicationId
          : 'manual-placement:${latest['id'] ?? 'placement'}',
      'selected_company_name': '${latest['company_name'] ?? 'Organization'}',
      'selected_training_title': '${latest['training_title'] ?? 'Placement'}',
      'confirmed_at':
          '${latest['company_accepted_at'] ?? latest['updated_at'] ?? latest['assigned_at'] ?? latest['created_at'] ?? ''}',
    };
  }

  List<dynamic> _mergeStudentApplications({
    required List<dynamic> apiApplications,
    required List<Map<String, dynamic>> manualPlacements,
  }) {
    final merged = <Map<String, dynamic>>[];
    final seenApplicationIds = <String>{};

    void addApplication(Map<String, dynamic> app) {
      final applicationId = '${app['application_id'] ?? ''}'.trim();
      if (applicationId.isNotEmpty && !seenApplicationIds.add(applicationId)) {
        return;
      }
      merged.add(app);
    }

    for (final app in apiApplications.whereType<Map>()) {
      addApplication(app.map((key, value) => MapEntry('$key', value)));
    }
    for (final placement in manualPlacements) {
      addApplication(_mapManualPlacementToApplication(placement));
    }

    DateTime parseSortDate(dynamic item) {
      if (item is Map<String, dynamic>) {
        final candidates = [
          item['assigned_at'],
          item['updated_at'],
          item['applied_date'],
          item['created_at'],
        ];
        for (final candidate in candidates) {
          final parsed = DateTime.tryParse('${candidate ?? ''}');
          if (parsed != null) return parsed;
        }
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    merged.sort(
      (left, right) => parseSortDate(right).compareTo(parseSortDate(left)),
    );
    return merged;
  }

  List<dynamic> _attachOnlineTestAttempts({
    required List<dynamic> applications,
    required List<dynamic> attempts,
  }) {
    final attemptByJobId = <String, Map<String, dynamic>>{};
    for (final attempt in attempts.whereType<Map>()) {
      final normalizedAttempt = attempt.map(
        (key, value) => MapEntry('$key', value),
      );
      final jobId = '${normalizedAttempt['job_id'] ?? ''}'.trim();
      final token = '${normalizedAttempt['online_test_token'] ?? ''}'.trim();
      if (jobId.isEmpty || token.isEmpty || attemptByJobId.containsKey(jobId)) {
        continue;
      }
      attemptByJobId[jobId] = normalizedAttempt;
    }

    return applications
        .map((item) {
          if (item is! Map) return item;
          final app = item.map((key, value) => MapEntry('$key', value));
          if (_onlineTestToken(app).isNotEmpty) {
            return app;
          }

          final jobId = '${app['job_id'] ?? ''}'.trim();
          final attempt = attemptByJobId[jobId];
          if (attempt == null) {
            return app;
          }

          return {
            ...app,
            'online_test_attempt_id': attempt['online_test_attempt_id'],
            'online_test_id': attempt['online_test_id'],
            'online_test_title': attempt['online_test_title'],
            'online_test_token': attempt['online_test_token'],
            'online_test_status': attempt['online_test_status'],
            'online_test_deadline': attempt['online_test_deadline'],
            'online_test_submitted_at': attempt['online_test_submitted_at'],
          };
        })
        .toList(growable: false);
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
      case 'assigned':
        return 'Assigned';
      case 'shortlisted':
        return 'Shortlisted';
      case 'review':
        return 'Review';
      case 'accepted':
        return 'Accepted';
      case 'confirmed':
        return 'Confirmed';
      case 'expired':
        return 'Expired';
      case 'rejected':
        return 'Rejected';
      default:
        return 'All';
    }
  }

  List<Widget> _buildAppBarActions() {
    return [
      PopupMenuButton<String>(
        tooltip: 'Filter',
        initialValue: _selectedFilter,
        icon: const Icon(Icons.filter_list),
        onSelected: (value) {
          setState(() {
            _selectedFilter = value;
          });
        },
        itemBuilder: (context) => const [
          PopupMenuItem(value: 'all', child: Text('All')),
          PopupMenuItem(value: 'pending', child: Text('Pending')),
          PopupMenuItem(value: 'assigned', child: Text('Assigned')),
          PopupMenuItem(value: 'shortlisted', child: Text('Shortlisted')),
          PopupMenuItem(value: 'accepted', child: Text('Accepted')),
          PopupMenuItem(value: 'confirmed', child: Text('Confirmed')),
          PopupMenuItem(value: 'expired', child: Text('Expired')),
          PopupMenuItem(value: 'rejected', child: Text('Rejected')),
        ],
      ),
      IconButton(icon: const Icon(Icons.refresh), onPressed: _loadApplications),
    ];
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    final currentUser = context.read<AuthProvider>().user;
    final studentEmail = currentUser?['email']?.toString() ?? '';
    try {
      final response = await _apiService.getMyApplications();
      final testAttemptsResponse = await _apiService.getMyTestAttempts();
      final testAttempts =
          testAttemptsResponse['success'] == true &&
              testAttemptsResponse['data'] is List
          ? testAttemptsResponse['data'] as List<dynamic>
          : const <dynamic>[];
      final approvalRecords = await _workspaceService.getApprovalRecords();
      final manualPlacements = (await _workspaceService.getManualPlacements())
          .where(
            (placement) => _sameEmail(placement['student_email'], studentEmail),
          )
          .toList(growable: false);
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
        final apiApplications =
            (response['data'] as List<dynamic>? ?? const []);
        final applications = _mergeStudentApplications(
          apiApplications: apiApplications,
          manualPlacements: manualPlacements,
        );
        final applicationsWithTests = _attachOnlineTestAttempts(
          applications: applications,
          attempts: testAttempts,
        );
        if (!mounted) return;
        setState(() {
          _applications = applicationsWithTests;
          _confirmedSelection =
              selection ??
              _buildConfirmedSelectionFromPlacement(manualPlacements);
          _approvalByApplicationId = approvalsByApplicationId;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _applications = manualPlacements
              .map(_mapManualPlacementToApplication)
              .toList();
          _confirmedSelection =
              selection ??
              _buildConfirmedSelectionFromPlacement(manualPlacements);
          _approvalByApplicationId = approvalsByApplicationId;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
      final manualPlacements = (await _workspaceService.getManualPlacements())
          .where(
            (placement) => _sameEmail(placement['student_email'], studentEmail),
          )
          .toList(growable: false);
      final selection = await _workspaceService.getStudentSelection(
        studentEmail,
      );
      if (!mounted) return;
      setState(() {
        _applications = manualPlacements
            .map(_mapManualPlacementToApplication)
            .toList();
        _confirmedSelection =
            selection ??
            _buildConfirmedSelectionFromPlacement(manualPlacements);
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

  bool _isBackendConfirmedApplication(Map<String, dynamic> app) {
    return '${app['status'] ?? ''}'.trim().toLowerCase() == 'accepted' &&
        '${app['student_confirmation_status'] ?? ''}'.trim().toLowerCase() ==
            'confirmed';
  }

  bool _isConfirmedPlacement(Map<String, dynamic> app) {
    return _isBackendConfirmedApplication(app) ||
        _isConfirmedApplication('${app['application_id'] ?? ''}');
  }

  String _effectiveStudentStatus(Map<String, dynamic> app) {
    if (_isOfferConfirmationExpired('${app['application_id'] ?? ''}')) {
      return 'expired';
    }

    final status = '${app['status'] ?? ''}'.trim().toLowerCase();
    if (app['is_manual_assignment'] == true &&
        '${app['company_response_status'] ?? ''}'.trim().toLowerCase() ==
            'accepted') {
      return 'confirmed';
    }
    if (status == 'accepted' && _isConfirmedPlacement(app)) {
      return 'confirmed';
    }
    return status;
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
        title: const Text('Confirm'),
        content: Text(
          _acceptedApplications.length > 1
              ? 'Confirm $companyName? Other companies will be notified.'
              : 'Confirm $companyName?',
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
      final isManualAssignment =
          app['is_manual_assignment'] == true ||
          applicationId.startsWith('manual-placement');

      if (!isManualAssignment) {
        final response = await _apiService.confirmApplicationSelection(
          applicationId,
        );
        if (response['success'] != true) {
          throw StateError(
            response['message']?.toString() ?? 'Failed to confirm placement.',
          );
        }
      }

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
      await _loadApplications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Confirmed successfully.'),
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

  String _onlineTestToken(Map<String, dynamic> app) {
    for (final key in const [
      'online_test_token',
      'test_token',
      'test_unique_link',
      'unique_link',
    ]) {
      final value = '${app[key] ?? ''}'.trim();
      if (value.isNotEmpty && value.toLowerCase() != 'null') {
        return value;
      }
    }
    return '';
  }

  String _onlineTestStatus(Map<String, dynamic> app) {
    final status = '${app['online_test_status'] ?? app['test_status'] ?? ''}'
        .trim()
        .toLowerCase();
    return status;
  }

  bool _hasOnlineTestInvitation(Map<String, dynamic> app) {
    return _onlineTestToken(app).isNotEmpty;
  }

  bool _isOnlineTestCompleted(Map<String, dynamic> app) {
    final status = _onlineTestStatus(app);
    return status == 'completed' || status == 'submitted';
  }

  Future<void> _openOnlineTest(Map<String, dynamic> app) async {
    var token = _onlineTestToken(app);
    if (token.isEmpty) {
      final attemptsResponse = await _apiService.getMyTestAttempts();
      if (!mounted) return;
      final attempts =
          attemptsResponse['success'] == true &&
              attemptsResponse['data'] is List
          ? attemptsResponse['data'] as List<dynamic>
          : const <dynamic>[];
      final refreshed = _attachOnlineTestAttempts(
        applications: [app],
        attempts: attempts,
      );
      if (refreshed.isNotEmpty && refreshed.first is Map) {
        final refreshedApp = Map<String, dynamic>.from(refreshed.first as Map);
        token = _onlineTestToken(refreshedApp);
        if (token.isNotEmpty && mounted) {
          setState(() {
            _applications = _attachOnlineTestAttempts(
              applications: _applications,
              attempts: attempts,
            );
          });
        }
      }
    }

    if (token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Test link is not ready yet. Please refresh.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_isOnlineTestCompleted(app)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('This test has already been submitted.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => TestAttemptScreen(token: token)));
    if (mounted) {
      await _loadApplications();
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'shortlisted':
        return Colors.blue;
      case '':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'confirmed':
        return const Color(0xFF0F766E);
      case 'expired':
        return const Color(0xFFD97706);
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
      case 'assigned':
        return 'Assigned';
      case 'shortlisted':
        return 'Shortlisted';
      case '':
        return ' Scheduled';
      case 'accepted':
        return 'Accepted';
      case 'confirmed':
        return 'Confirmed';
      case 'expired':
        return 'Expired';
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
      case 'assigned':
        return Icons.assignment_turned_in_rounded;
      case 'shortlisted':
        return Icons.star;
      case '':
        return Icons.calendar_today;
      case 'accepted':
        return Icons.check_circle;
      case 'confirmed':
        return Icons.verified_rounded;
      case 'expired':
        return Icons.hourglass_disabled_rounded;
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

  String _pdfSafeText(Object? value) {
    return '${value ?? ''}'
        .replaceAll('\\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll(RegExp(r'[^\x20-\x7E]'), '?')
        .trim();
  }

  List<String> _wrapPdfText(String value, {int maxLength = 82}) {
    final words = value.trim().split(RegExp(r'\s+'));
    final lines = <String>[];
    var current = '';

    for (final word in words) {
      if (word.isEmpty) continue;
      final next = current.isEmpty ? word : '$current $word';
      if (next.length > maxLength && current.isNotEmpty) {
        lines.add(current);
        current = word;
      } else {
        current = next;
      }
    }

    if (current.isNotEmpty) lines.add(current);
    return lines.isEmpty ? [''] : lines;
  }

  Uint8List _buildManualResponseLetterPdf(Map<String, dynamic> app) {
    final studentName = _pdfSafeText(
      app['student_name'] ?? app['full_name'] ?? 'Student',
    );
    final companyName = _pdfSafeText(app['company_name'] ?? 'Company');
    final trainingTitle = _pdfSafeText(app['job_title'] ?? app['title']);
    final universityName = _pdfSafeText(app['university_name'] ?? 'University');
    final registrationNumber = _pdfSafeText(app['registration_number']);
    final location = _pdfSafeText(app['placement_location'] ?? app['location']);
    final department = _pdfSafeText(app['placement_department']);
    final startDate = _formatDate('${app['reporting_start_date'] ?? ''}');
    final endDate = _formatDate('${app['reporting_end_date'] ?? ''}');
    final feedback = _pdfSafeText(app['company_feedback']);
    final generatedDate = _formatDate(DateTime.now().toIso8601String());

    final lines = <String>[
      'FIELD PLACEMENT RESPONSE LETTER',
      '',
      'Date: $generatedDate',
      'Student: $studentName',
      if (registrationNumber.isNotEmpty)
        'Registration Number: $registrationNumber',
      'University: $universityName',
      'Company: $companyName',
      'Placement: $trainingTitle',
      if (location.isNotEmpty) 'Location: $location',
      if (department.isNotEmpty) 'Department: $department',
      if (startDate.trim().isNotEmpty) 'Reporting Start: $startDate',
      if (endDate.trim().isNotEmpty) 'Reporting End: $endDate',
      '',
      'Dear $studentName,',
      ..._wrapPdfText(
        '$companyName has accepted the coordinator assigned placement for $trainingTitle. Please report according to the placement details above and follow any additional instructions from the company and university coordinator.',
      ),
      if (feedback.isNotEmpty) ...[
        '',
        'Company Notes:',
        ..._wrapPdfText(feedback),
      ],
      '',
      'Prepared for student records.',
    ];

    final content = StringBuffer();
    var y = 760;
    for (var index = 0; index < lines.length; index++) {
      final line = _pdfSafeText(lines[index]);
      final fontSize = index == 0 ? 17 : 11;
      content.writeln('BT /F1 $fontSize Tf 72 $y Td ($line) Tj ET');
      y -= index == 0 ? 28 : 18;
    }

    final stream = content.toString();
    final streamLength = ascii.encode(stream).length;
    final objects = <String>[
      '1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n',
      '2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n',
      '3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 4 0 R >> >> /Contents 5 0 R >>\nendobj\n',
      '4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n',
      '5 0 obj\n<< /Length $streamLength >>\nstream\n$stream\nendstream\nendobj\n',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[0];
    var byteOffset = ascii.encode(buffer.toString()).length;
    for (final object in objects) {
      offsets.add(byteOffset);
      buffer.write(object);
      byteOffset += ascii.encode(object).length;
    }

    final xrefOffset = byteOffset;
    buffer.write('xref\n0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets.skip(1)) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefOffset\n%%EOF',
    );

    return Uint8List.fromList(ascii.encode(buffer.toString()));
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

  Future<String> _saveBytesToAvailableDirectory(
    Uint8List bytes, {
    required String fileName,
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
        await File(savePath).writeAsBytes(bytes, flush: true);
        return savePath;
      } catch (error) {
        lastError = error;
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

  Future<void> _downloadManualResponseLetter(Map<String, dynamic> app) async {
    final applicationId = '${app['application_id'] ?? 'manual-placement'}';
    final fileName = _sanitizeFileName(
      '${app['student_name'] ?? app['full_name'] ?? 'student'}_response_letter.pdf',
    );
    setState(() => _downloadingResponseLetters.add(applicationId));

    try {
      final bytes = _buildManualResponseLetterPdf(app);
      if (kIsWeb) {
        final opened = await openPdfBytesInBrowser(bytes, fileName: fileName);
        if (!opened) {
          throw Exception('Unable to open response letter.');
        }
        return;
      }

      final savePath = await _saveBytesToAvailableDirectory(
        bytes,
        fileName: fileName,
      );
      final finalPath = Platform.isAndroid
          ? await LocalFileService.copyFileToDownloads(
              savePath,
              fileName: fileName,
            )
          : savePath;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Response letter downloaded to: $finalPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      final message = ApiService.normalizeErrorMessage(
        error,
        fallback: 'Failed to download response letter',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to download response letter: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingResponseLetters.remove(applicationId));
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
    String subtitle = '',
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
                      if (subtitle.trim().isNotEmpty) ...[
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
    final isManualAssignment = app['is_manual_assignment'] == true;
    final status = '${app['status'] ?? ''}'.trim().toLowerCase();
    final companyResponseStatus = '${app['company_response_status'] ?? ''}'
        .trim()
        .toLowerCase();
    final hasManualResponseLetter =
        isManualAssignment &&
        (status == 'accepted' ||
            status == 'confirmed' ||
            companyResponseStatus == 'accepted');
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
                  if ((app['placement_department'] ?? '').toString().isNotEmpty)
                    infoTile(
                      icon: Icons.apartment_outlined,
                      label: 'Placement Department',
                      value: app['placement_department']?.toString() ?? '',
                    ),
                  if ((app['company_phone'] ?? '').toString().isNotEmpty)
                    infoTile(
                      icon: Icons.call_outlined,
                      label: 'Placement Phone',
                      value: app['company_phone']?.toString() ?? '',
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
                      if (responseLetterUrl.isNotEmpty ||
                          hasManualResponseLetter)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(0, 0),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed: hasManualResponseLetter
                              ? () => _downloadManualResponseLetter(app)
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
          actions: _buildAppBarActions(),
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
        actions: _buildAppBarActions(),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredApplications.length,
        itemBuilder: (context, index) {
          final app = filteredApplications[index];
          final applicationMap = Map<String, dynamic>.from(app);
          final rawStatus = '${app['status'] ?? 'pending'}'
              .trim()
              .toLowerCase();
          final status = _effectiveStudentStatus(applicationMap);
          final applicationId = '${app['application_id'] ?? ''}';
          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final statusIcon = _getStatusIcon(status);
          final hasConfirmedSelection = _confirmedSelection != null;
          final isConfirmedThisApplication = _isConfirmedPlacement(
            applicationMap,
          );
          final isOfferExpired = _isOfferConfirmationExpired(applicationId);
          final offerExpiresAt = _offerConfirmationExpiresAt(applicationId);
          final confirmedCompanyName =
              '${_confirmedSelection?['selected_company_name'] ?? ''}';
          final isConfirming = _confirmingApplicationId == applicationId;
          final title = '${app['title'] ?? app['job_title'] ?? 'Placement'}';
          final companyName = '${app['company_name'] ?? 'Unknown Company'}';
          final location = '${app['location'] ?? 'Location not specified'}';
          final isManualAssignment = app['is_manual_assignment'] == true;
          final hasOnlineTestInvitation = _hasOnlineTestInvitation(
            applicationMap,
          );
          final isOnlineTestCompleted = _isOnlineTestCompleted(applicationMap);
          final onlineTestTitle = '${app['online_test_title'] ?? 'Online Test'}'
              .trim();

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
                          onTap: () => _showApplicationPreview(applicationMap),
                        ),
                      ],
                    ),
                  ),
                  if (hasOnlineTestInvitation || rawStatus == 'assigned') ...[
                    const SizedBox(height: 12),
                    _buildApplicationActionTile(
                      icon: isOnlineTestCompleted
                          ? Icons.fact_check_rounded
                          : Icons.quiz_outlined,
                      label: isOnlineTestCompleted
                          ? 'Test Submitted'
                          : 'Open Test',
                      subtitle: isOnlineTestCompleted
                          ? '$onlineTestTitle has already been submitted.'
                          : onlineTestTitle,
                      backgroundColor: isOnlineTestCompleted
                          ? const Color(0xFFF1F5F9)
                          : const Color(0xFFEFF6FF),
                      borderColor: isOnlineTestCompleted
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF93C5FD),
                      iconColor: isOnlineTestCompleted
                          ? const Color(0xFF64748B)
                          : const Color(0xFF1D4ED8),
                      textColor: isOnlineTestCompleted
                          ? const Color(0xFF475569)
                          : const Color(0xFF1D4ED8),
                      onTap: isOnlineTestCompleted
                          ? null
                          : () => _openOnlineTest(applicationMap),
                      showChevron: !isOnlineTestCompleted,
                      trailing: isOnlineTestCompleted
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF64748B),
                              size: 22,
                            )
                          : null,
                    ),
                  ],
                  if (rawStatus == 'accepted') ...[
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
                          ? 'Offer Expired'
                          : isConfirmedThisApplication
                          ? 'Confirmed Placement'
                          : hasConfirmedSelection
                          ? 'Placement Confirmed Elsewhere'
                          : 'Confirm',
                      subtitle: isOfferExpired
                          ? offerExpiresAt == null
                                ? 'This accepted offer expired because it was not confirmed within 48 hours.'
                                : 'This accepted offer expired because it was not confirmed within 48 hours. Deadline was ${_formatDate(offerExpiresAt.toIso8601String())}.'
                          : isConfirmedThisApplication
                          ? 'You selected ${app['company_name'] ?? 'this company'}.'
                          : hasConfirmedSelection
                          ? 'You already confirmed $confirmedCompanyName, so this offer is no longer active.'
                          : '',
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
                      onTap:
                          !isConfirmedThisApplication &&
                              !hasConfirmedSelection &&
                              !isOfferExpired
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
                  ] else if (rawStatus == 'assigned' &&
                      isManualAssignment &&
                      !hasOnlineTestInvitation) ...[
                    const SizedBox(height: 12),
                    _buildApplicationActionTile(
                      icon: Icons.assignment_turned_in_rounded,
                      label: 'Assigned Placement',
                      subtitle:
                          '${app['coordinator_name'] ?? 'Coordinator'} assigned you to $companyName. Waiting for company acceptance.${('${app['company_feedback'] ?? ''}').trim().isEmpty ? '' : ' Notes: ${app['company_feedback']}'}',
                      backgroundColor: const Color(0xFFEFF6FF),
                      borderColor: const Color(0xFFBFDBFE),
                      iconColor: const Color(0xFF2563EB),
                      textColor: const Color(0xFF1D4ED8),
                      onTap: null,
                      showChevron: false,
                      trailing: const Icon(
                        Icons.hourglass_top_rounded,
                        color: Color(0xFF2563EB),
                        size: 22,
                      ),
                    ),
                  ] else if (status == 'confirmed' && isManualAssignment) ...[
                    const SizedBox(height: 12),
                    _buildApplicationActionTile(
                      icon: Icons.verified_rounded,
                      label: 'Confirmed Placement',
                      subtitle:
                          '${app['coordinator_name'] ?? 'Coordinator'} assigned you to $companyName.${('${app['company_feedback'] ?? ''}').trim().isEmpty ? '' : ' Notes: ${app['company_feedback']}'}',
                      backgroundColor: const Color(0xFFEAF7F2),
                      borderColor: const Color(0xFF7BC9A8),
                      iconColor: const Color(0xFF0F766E),
                      textColor: const Color(0xFF0F766E),
                      onTap: null,
                      showChevron: false,
                      trailing: const Icon(
                        Icons.assignment_turned_in_rounded,
                        color: Color(0xFF0F766E),
                        size: 22,
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
