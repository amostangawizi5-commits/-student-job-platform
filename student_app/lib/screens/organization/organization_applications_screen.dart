import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import '../../services/api_service.dart';
import 'company_test_management_screen.dart';

class CompanyApplicationsScreen extends StatefulWidget {
  final String jobId;
  final String jobTitle;

  const CompanyApplicationsScreen({
    super.key,
    required this.jobId,
    required this.jobTitle,
  });

  @override
  State<CompanyApplicationsScreen> createState() =>
      _CompanyApplicationsScreenState();
}

class _TestSelectionSummary {
  const _TestSelectionSummary({
    required this.testedStudentIds,
    required this.testedApplicationIds,
    required this.testedEmails,
    required this.testedCount,
    required this.selectedCount,
    required this.notSelectedCount,
    required this.pendingCount,
  });

  const _TestSelectionSummary.empty()
    : testedStudentIds = const <String>{},
      testedApplicationIds = const <String>{},
      testedEmails = const <String>{},
      testedCount = 0,
      selectedCount = 0,
      notSelectedCount = 0,
      pendingCount = 0;

  final Set<String> testedStudentIds;
  final Set<String> testedApplicationIds;
  final Set<String> testedEmails;
  final int testedCount;
  final int selectedCount;
  final int notSelectedCount;
  final int pendingCount;
}

class _CompanyApplicationsScreenState extends State<CompanyApplicationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _applications = [];
  _TestSelectionSummary _testSelectionSummary =
      const _TestSelectionSummary.empty();
  bool _isLoading = true;
  String? _error;

  String _formatErrorMessage(Object error) {
    final message = ApiService.normalizeErrorMessage(
      error,
      fallback: 'Failed to load applications',
    );
    if (message.toLowerCase().contains('network')) {
      return 'Network error';
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  Future<void> _loadApplications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.get(
        '/api/applications/job/${widget.jobId}',
        requiresAuth: true,
      );
      final testSelectionSummary = await _fetchTestSelectionSummary();

      if (response['success']) {
        setState(() {
          _applications = response['data'] ?? [];
          _testSelectionSummary = testSelectionSummary;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = response['message'] ?? 'Failed to load applications';
          _testSelectionSummary = testSelectionSummary;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e);
        _testSelectionSummary = const _TestSelectionSummary.empty();
        _isLoading = false;
      });
    }
  }

  Future<_TestSelectionSummary> _fetchTestSelectionSummary() async {
    final response = await _apiService.getOrganizationTests(
      jobId: widget.jobId,
    );
    final tests = response['success'] == true && response['data'] is List
        ? List<dynamic>.from(response['data'])
        : <dynamic>[];
    final seenKeys = <String>{};
    final studentIds = <String>{};
    final applicationIds = <String>{};
    final emails = <String>{};
    var selectedCount = 0;
    var notSelectedCount = 0;
    var pendingCount = 0;

    for (final test in tests) {
      final testId = '${test['id'] ?? ''}'.trim();
      if (testId.isEmpty) continue;
      final resultsResponse = await _apiService.getOrganizationTestResults(
        testId,
      );
      final results =
          resultsResponse['success'] == true && resultsResponse['data'] is List
          ? List<dynamic>.from(resultsResponse['data'])
          : <dynamic>[];

      for (final result in results) {
        if ('${result['attempt_status'] ?? ''}'.trim().toLowerCase() !=
            'completed') {
          continue;
        }
        final studentId = '${result['student_id'] ?? ''}'.trim();
        final applicationId = '${result['application_id'] ?? ''}'.trim();
        final email = '${result['email'] ?? ''}'.trim().toLowerCase();
        final key = applicationId.isNotEmpty
            ? 'application:$applicationId'
            : studentId.isNotEmpty
            ? 'student:$studentId'
            : email.isNotEmpty
            ? 'email:$email'
            : 'attempt:${result['attempt_id'] ?? seenKeys.length}';
        if (!seenKeys.add(key)) continue;

        final selectionStatus = '${result['selection_status'] ?? 'pending'}'
            .trim()
            .toLowerCase();
        if (selectionStatus == 'accepted') continue;

        if (studentId.isNotEmpty) {
          studentIds.add(studentId);
        }
        if (applicationId.isNotEmpty) {
          applicationIds.add(applicationId);
        }
        if (email.isNotEmpty) {
          emails.add(email);
        }

        if (selectionStatus == 'selected' || selectionStatus == 'shortlisted') {
          selectedCount += 1;
        } else if (selectionStatus == 'not_selected' ||
            selectionStatus == 'rejected') {
          notSelectedCount += 1;
        } else {
          pendingCount += 1;
        }
      }
    }

    return _TestSelectionSummary(
      testedStudentIds: studentIds,
      testedApplicationIds: applicationIds,
      testedEmails: emails,
      testedCount: selectedCount + notSelectedCount + pendingCount,
      selectedCount: selectedCount,
      notSelectedCount: notSelectedCount,
      pendingCount: pendingCount,
    );
  }

  Future<void> _updateStatus(
    String applicationId,
    String status, {
    String? feedback,
    String? reportingStartDate,
    String? reportingEndDate,
  }) async {
    try {
      final payload = <String, dynamic>{'status': status, 'feedback': feedback};
      if (reportingStartDate != null) {
        payload['reporting_start_date'] = reportingStartDate;
      }
      if (reportingEndDate != null) {
        payload['reporting_end_date'] = reportingEndDate;
      }

      final response = await _apiService.put(
        '/api/applications/$applicationId',
        payload,
        requiresAuth: true,
      );

      if (!mounted) return;
      if (response['success']) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text('Application ${_getStatusText(status)}'),
            backgroundColor: status == 'rejected' ? Colors.red : Colors.green,
          ),
        );
        _loadApplications();
      } else {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Update failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(_formatErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatDateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<Map<String, String>?> _collectReportingDates() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'Select reporting start date',
    );
    if (startDate == null || !mounted) return null;

    final endDate = await showDatePicker(
      context: context,
      initialDate: startDate.add(const Duration(days: 1)),
      firstDate: startDate,
      lastDate: DateTime(now.year + 3),
      helpText: 'Select reporting end date',
    );
    if (endDate == null) return null;

    return {
      'reporting_start_date': _formatDateOnly(startDate),
      'reporting_end_date': _formatDateOnly(endDate),
    };
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
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFB38A45);
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'shortlisted':
        return const Color(0xFF5C7FA3);
      case '':
        return const Color(0xFF7D6AA8);
      case 'accepted':
        return const Color(0xFF5D8D73);
      case 'rejected':
        return const Color(0xFFB26B6B);
      default:
        return Colors.grey;
    }
  }

  Color _getStatusBackground(String status) {
    switch (status) {
      case 'pending':
        return const Color(0xFFF8F1E3);
      case 'assigned':
        return const Color(0xFFEFF6FF);
      case 'shortlisted':
        return const Color(0xFFEAF1F7);
      case '':
        return const Color(0xFFF1ECF8);
      case 'accepted':
        return const Color(0xFFEAF4EE);
      case 'rejected':
        return const Color(0xFFF8ECEC);
      default:
        return Colors.grey.shade100;
    }
  }

  int _countByStatus(String status) {
    if (status == 'pending') return _pendingApplications.length;
    if (status == 'accepted') return _acceptedApplications.length;
    if (status == 'shortlisted') return _shortlistedApplications.length;
    if (status == 'assigned') return _assignedApplications.length;

    return _applications
        .where((app) => '${app['status'] ?? 'pending'}' == status)
        .length;
  }

  bool _isTestedApplication(dynamic app) {
    final applicationId = '${app['application_id'] ?? ''}'.trim();
    final studentId = '${app['student_id'] ?? app['user_id'] ?? ''}'.trim();
    final email = '${app['email'] ?? app['student_email'] ?? ''}'
        .trim()
        .toLowerCase();

    return (applicationId.isNotEmpty &&
            _testSelectionSummary.testedApplicationIds.contains(
              applicationId,
            )) ||
        (studentId.isNotEmpty &&
            _testSelectionSummary.testedStudentIds.contains(studentId)) ||
        (email.isNotEmpty &&
            _testSelectionSummary.testedEmails.contains(email));
  }

  List<dynamic> get _pendingApplications => _applications
      .where(
        (app) =>
            !_acceptedApplications.contains(app) &&
            !_assignedApplications.contains(app) &&
            !_shortlistedApplications.contains(app) &&
            !_isTestedApplication(app),
      )
      .toList(growable: false);

  List<dynamic> get _acceptedApplications => _applications
      .where((app) => '${app['status'] ?? 'pending'}' == 'accepted')
      .toList(growable: false);

  List<dynamic> get _shortlistedApplications => _applications
      .where(
        (app) =>
            '${app['status'] ?? 'pending'}' == 'shortlisted' &&
            !_isTestedApplication(app) &&
            !_acceptedApplications.contains(app),
      )
      .toList(growable: false);

  List<dynamic> get _assignedApplications => _applications
      .where(
        (app) =>
            '${app['status'] ?? 'pending'}' == 'assigned' &&
            !_isTestedApplication(app) &&
            !_acceptedApplications.contains(app),
      )
      .toList(growable: false);

  bool _hasReachedStatus(String currentStatus, String targetStatus) {
    const order = ['pending', 'assigned', 'shortlisted', '', 'accepted'];
    final currentIndex = order.indexOf(currentStatus);
    final targetIndex = order.indexOf(targetStatus);
    if (currentStatus == 'rejected') return false;
    if (currentIndex == -1 || targetIndex == -1) return false;
    return currentIndex >= targetIndex;
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openTestSelection() async {
    final eligibleApplicants = [
      ..._assignedApplications,
      ..._shortlistedApplications,
    ];
    if (eligibleApplicants.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Assign or shortlist at least one student before assigning a test.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyTestManagementScreen(
          jobId: widget.jobId,
          jobTitle: widget.jobTitle,
          applicants: eligibleApplicants,
        ),
      ),
    );

    if (!mounted) return;
    await _loadApplications();
  }

  Future<void> _openCompletedTestTakers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyTestManagementScreen(
          jobId: widget.jobId,
          jobTitle: widget.jobTitle,
          applicants: _applications,
          resultsOnly: true,
        ),
      ),
    );

    if (!mounted) return;
    await _loadApplications();
  }

  Widget _buildShortlistedTestAction() {
    final assignedCount = _assignedApplications.length;
    final shortlistedCount = _shortlistedApplications.length;
    final eligibleCount = assignedCount + shortlistedCount;
    final hasEligibleApplicants = eligibleCount > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD8E6F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE9F2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.quiz_outlined,
                  color: Color(0xFF2563EB),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Shortlisted Students Action',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasEligibleApplicants
                      ? '$eligibleCount student(s) assigned/shortlisted and ready for test'
                      : 'No assigned or shortlisted students yet',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: hasEligibleApplicants
                        ? _openTestSelection
                        : null,
                    icon: const Icon(Icons.science_outlined),
                    label: Text(
                      hasEligibleApplicants
                          ? 'Assign Test'
                          : 'Assign or Shortlist Students First',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      disabledForegroundColor: Colors.grey.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openCompletedTestTakers,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('View tested students'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required bool isActive,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: isEnabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: isEnabled || isActive ? color : Colors.grey.shade500,
        backgroundColor: isActive
            ? color.withValues(alpha: 0.14)
            : (isEnabled ? Colors.white : Colors.grey.shade100),
        side: BorderSide(
          color: isEnabled || isActive
              ? color.withValues(alpha: 0.55)
              : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  void _showApplicationsSummary() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Applications Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryLine('Total', '${_applications.length}'),
            _buildSummaryLine(
              'Shortlisted',
              '${_countByStatus('shortlisted')}',
            ),
            _buildSummaryLine('Accepted', '${_countByStatus('accepted')}'),
            _buildSummaryLine('Rejected', '${_countByStatus('rejected')}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade700)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _buildTopNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF2C3E50),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_turned_in_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Applications',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.work_outline_rounded,
                      color: Colors.grey.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'My training',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  void _showRejectDialog(String applicationId) {
    final feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Provide feedback to the applicant (optional):'),
            const SizedBox(height: 12),
            TextField(
              controller: feedbackController,
              decoration: const InputDecoration(
                hintText: 'Reason for rejection...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _updateStatus(
                applicationId,
                'rejected',
                feedback: feedbackController.text,
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _acceptApplicant(String applicationId) async {
    final reportingDates = await _collectReportingDates();
    if (reportingDates == null) return;

    await _updateStatus(
      applicationId,
      'accepted',
      reportingStartDate: reportingDates['reporting_start_date'],
      reportingEndDate: reportingDates['reporting_end_date'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Applications - ${widget.jobTitle}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadApplications,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _applications.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No applications yet'),
                  SizedBox(height: 8),
                  Text('Check back later'),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;
                    final cards = [
                      _buildSummaryCard(
                        label: 'Total',
                        value: '${_applications.length}',
                        icon: Icons.groups_2_outlined,
                        color: const Color(0xFF2C3E50),
                      ),
                      _buildSummaryCard(
                        label: 'Pending',
                        value: '${_countByStatus('pending')}',
                        icon: Icons.hourglass_empty_rounded,
                        color: const Color(0xFFB38A45),
                      ),
                      _buildSummaryCard(
                        label: 'Assigned',
                        value: '${_countByStatus('assigned')}',
                        icon: Icons.assignment_ind_outlined,
                        color: const Color(0xFF2563EB),
                      ),
                      _buildSummaryCard(
                        label: 'Shortlisted',
                        value: '${_countByStatus('shortlisted')}',
                        icon: Icons.playlist_add_check_circle_outlined,
                        color: Colors.blue,
                      ),
                      _buildSummaryCard(
                        label: 'Tested',
                        value: '${_testSelectionSummary.testedCount}',
                        icon: Icons.fact_check_outlined,
                        color: const Color(0xFF0F766E),
                        onTap: _openCompletedTestTakers,
                      ),
                      _buildSummaryCard(
                        label: 'Accepted',
                        value: '${_countByStatus('accepted')}',
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                    ];

                    if (compact) {
                      return Column(
                        children: [
                          for (final card in cards) ...[
                            card,
                            const SizedBox(height: 10),
                          ],
                        ],
                      );
                    }

                    return Row(
                      children: [
                        for (int i = 0; i < cards.length; i++) ...[
                          Expanded(child: cards[i]),
                          if (i != cards.length - 1) const SizedBox(width: 10),
                        ],
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildShortlistedTestAction(),
                const SizedBox(height: 12),
                _buildTopNavigationBar(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _showApplicationsSummary,
                        icon: const Icon(
                          Icons.insert_chart_outlined_rounded,
                          size: 18,
                        ),
                        label: const Text('Statistics'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loadApplications,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final app in _applications) ...[
                  Builder(
                    builder: (context) {
                      final status = app['status'] ?? 'pending';
                      final statusColor = _getStatusColor(status);
                      final canShortlist =
                          status == 'pending' || status == 'assigned';
                      final canAccept =
                          status == 'assigned' ||
                          status == 'shortlisted' ||
                          status == '';
                      final canReject =
                          status == 'pending' ||
                          status == 'assigned' ||
                          status == 'shortlisted' ||
                          status == '';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 20,
                                    backgroundColor: Colors.blue.shade100,
                                    child: Text(
                                      app['full_name']?[0]?.toUpperCase() ??
                                          '?',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue.shade700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          app['full_name'] ?? 'Unknown',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          app['email'] ?? 'No email',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getStatusBackground(status),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      _getStatusText(status),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                        color: statusColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.school,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: Text(
                                            app['program'] ??
                                                'Program not specified',
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 14,
                                          color: Colors.grey.shade500,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Applied: ${_formatDate(app['applied_date'])}',
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  _buildActionButton(
                                    label: 'Shortlist',
                                    color: Colors.blue,
                                    isActive: _hasReachedStatus(
                                      status,
                                      'shortlisted',
                                    ),
                                    isEnabled: canShortlist,
                                    onPressed: () => _updateStatus(
                                      app['application_id'],
                                      'shortlisted',
                                    ),
                                  ),
                                  _buildActionButton(
                                    label: 'Accept',
                                    color: Colors.green,
                                    isActive: status == 'accepted',
                                    isEnabled: canAccept,
                                    onPressed: () =>
                                        _acceptApplicant(app['application_id']),
                                  ),
                                  _buildActionButton(
                                    label: 'Reject',
                                    color: Colors.red,
                                    isActive: status == 'rejected',
                                    isEnabled: canReject,
                                    onPressed: () => _showRejectDialog(
                                      app['application_id'],
                                    ),
                                  ),
                                ],
                              ),
                              if (status == 'rejected' &&
                                  app['company_feedback'] != null) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.feedback,
                                        size: 14,
                                        color: Colors.red.shade400,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          app['company_feedback'],
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red.shade700,
                                          ),
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
                ],
              ],
            ),
    );
  }
}
