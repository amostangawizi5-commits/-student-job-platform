import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../widgets/statistic_card.dart';
import 'admin_application_filter.dart';
import 'admin_export_utils.dart';
import 'admin_user_filter.dart';

const Color _adminBrandNavy = Color(0xFF0E3A5D);
const Color _adminBrandOrange = Color(0xFFEF6C00);
const Color _adminBrandOrangeSoft = Color(0xFFFFEDD5);
const Color _adminBrandNavySoft = Color(0xFFEAF2F8);
const Color _adminBrandSuccess = Color(0xFF1D8F5A);
const Color _adminBrandDanger = Color(0xFFD84315);

class AdminHomeScreen extends StatefulWidget {
  final String adminName;
  final void Function(
    int index, {
    AdminUserFilter? userFilter,
    AdminApplicationFilter? applicationFilter,
  })?
  onNavigateToTab;

  const AdminHomeScreen({
    super.key,
    required this.adminName,
    this.onNavigateToTab,
  });

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _selectedDashboardFilter = 'all';
  String _searchQuery = '';
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _applications = [];
  List<dynamic> _reports = [];

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      _log('Fetching admin dashboard data');
      final responses = await Future.wait<Map<String, dynamic>>([
        _apiService.getAdminStats(),
        _apiService.getUsers(),
        _apiService.getApplications(),
        _apiService.getAdminLogs(),
      ]);

      if (!mounted) return;

      final statsResponse = responses[0];
      final usersResponse = responses[1];
      final applicationsResponse = responses[2];
      final reportsResponse = responses[3];

      final stats =
          statsResponse['success'] == true && statsResponse['data'] is Map
          ? Map<String, dynamic>.from(statsResponse['data'])
          : <String, dynamic>{};
      final users =
          usersResponse['success'] == true && usersResponse['data'] is List
          ? List<dynamic>.from(usersResponse['data'])
          : <dynamic>[];
      final applications =
          applicationsResponse['success'] == true &&
              applicationsResponse['data'] is List
          ? List<dynamic>.from(applicationsResponse['data'])
          : <dynamic>[];
      final reports =
          reportsResponse['success'] == true && reportsResponse['data'] is List
          ? List<dynamic>.from(reportsResponse['data'])
          : <dynamic>[];

      final hasAnyData =
          stats.isNotEmpty ||
          users.isNotEmpty ||
          applications.isNotEmpty ||
          reports.isNotEmpty;

      setState(() {
        _stats = stats;
        _users = users;
        _applications = applications;
        _reports = reports;
        _isLoading = false;
        _hasError = !hasAnyData;
        _errorMessage =
            statsResponse['message']?.toString() ?? 'Failed to load dashboard';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _exportDashboardReport() async {
    final stats = _stats ?? <String, dynamic>{};
    await AdminExportUtils.showExportDialog(
      context,
      title: 'dashboard report',
      filePrefix: 'dashboard_report',
      headers: const ['Metric', 'Value'],
      rows: [
        ['Total users', '${_totalUsers(stats)}'],
        ['Pending applications', '${_pendingApplications(stats)}'],
        ['Approved applications', '${_approvedApplications(stats)}'],
        ['Rejected applications', '${_rejectedApplications(stats)}'],
        ['Total applications', '${_totalApplications(stats)}'],
        ['Total companies', '${_asInt(stats['total_companies'])}'],
        ['Total jobs', '${_asInt(stats['total_jobs'])}'],
        ['New applications today', '$_newApplicationsToday'],
      ],
    );
  }

  void _openUsers([AdminUserFilter filter = AdminUserFilter.all]) {
    widget.onNavigateToTab?.call(1, userFilter: filter);
  }

  void _openApplications([
    AdminApplicationFilter filter = AdminApplicationFilter.all,
  ]) {
    widget.onNavigateToTab?.call(2, applicationFilter: filter);
  }

  void _openReports() {
    widget.onNavigateToTab?.call(3);
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _normalizedStatus(dynamic value) {
    return '$value'.trim().toLowerCase();
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String _weekdayLabel(DateTime date) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[date.weekday - 1];
  }

  int _totalUsers(Map<String, dynamic> stats) {
    return _asInt(stats['total_users']) == 0
        ? _users.length
        : _asInt(stats['total_users']);
  }

  int _totalApplications(Map<String, dynamic> stats) {
    return _asInt(stats['total_applications']) == 0
        ? _applications.length
        : _asInt(stats['total_applications']);
  }

  int _pendingApplications(Map<String, dynamic> stats) {
    final fromStats = _asInt(stats['pending_applications']);
    if (fromStats > 0) return fromStats;
    return _applications
        .where((app) => _normalizedStatus(app['status']) == 'pending')
        .length;
  }

  int _approvedApplications(Map<String, dynamic> stats) {
    final fromStats = _asInt(stats['approved_applications']);
    if (fromStats > 0) return fromStats;
    return _applications
        .where((app) => _normalizedStatus(app['status']) == 'approved')
        .length;
  }

  int _rejectedApplications(Map<String, dynamic> stats) {
    final fromStats = _asInt(stats['rejected_applications']);
    if (fromStats > 0) return fromStats;
    return _applications
        .where((app) => _normalizedStatus(app['status']) == 'rejected')
        .length;
  }

  int get _newApplicationsToday {
    final today = DateTime.now();
    return _applications.where((application) {
      final appliedDate = _parseDate(
        application['applied_date'] ?? application['created_at'],
      );
      return appliedDate != null && _isSameDay(appliedDate, today);
    }).length;
  }

  int get _applicationsThisWeek {
    return _applicationSeries().fold<int>(
      0,
      (total, point) => total + point.count,
    );
  }

  double get _averageApplicationsPerDay {
    return _applicationsThisWeek / 7;
  }

  _DailyApplicationsPoint? get _peakApplicationDay {
    final series = _applicationSeries();
    if (series.isEmpty) return null;

    _DailyApplicationsPoint peak = series.first;
    for (final point in series.skip(1)) {
      if (point.count > peak.count) {
        peak = point;
      }
    }
    return peak;
  }

  List<_DailyApplicationsPoint> _applicationSeries() {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    final counts = <DateTime, int>{};

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      counts[DateTime(day.year, day.month, day.day)] = 0;
    }

    for (final application in _applications) {
      final appliedDate = _parseDate(
        application['applied_date'] ?? application['created_at'],
      );
      if (appliedDate == null) continue;
      final key = DateTime(
        appliedDate.year,
        appliedDate.month,
        appliedDate.day,
      );
      if (counts.containsKey(key)) {
        counts[key] = (counts[key] ?? 0) + 1;
      }
    }

    return counts.entries
        .map(
          (entry) =>
              _DailyApplicationsPoint(date: entry.key, count: entry.value),
        )
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  bool _matchesUserSearch(dynamic user) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return false;

    final searchable = [
      '${user['full_name'] ?? ''}',
      '${user['company_name'] ?? ''}',
      '${user['email'] ?? ''}',
      '${user['role'] ?? ''}',
      '${user['phone'] ?? ''}',
      '${user['location'] ?? ''}',
    ];

    return searchable.any((value) => value.toLowerCase().contains(query));
  }

  bool _matchesApplicationSearch(dynamic application) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchable = [
      '${application['user_name'] ?? ''}',
      '${application['email'] ?? ''}',
      '${application['company_name'] ?? ''}',
      '${application['job_title'] ?? ''}',
      '${application['status'] ?? ''}',
    ];

    return searchable.any((value) => value.toLowerCase().contains(query));
  }

  bool _matchesApplicationFilter(dynamic application) {
    if (_selectedDashboardFilter == 'all') return true;
    return _normalizedStatus(application['status']) == _selectedDashboardFilter;
  }

  List<dynamic> _applicationsForDashboardCards() {
    if (_searchQuery.trim().isEmpty) {
      return List<dynamic>.from(_applications);
    }

    return _applications.where(_matchesApplicationSearch).toList();
  }

  int _applicationCountForCard(String filter) {
    final applications = _applicationsForDashboardCards();
    if (filter == 'all') return applications.length;

    return applications
        .where(
          (application) => _normalizedStatus(application['status']) == filter,
        )
        .length;
  }

  void _setDashboardFilter(String filter) {
    if (_selectedDashboardFilter == filter) return;
    setState(() => _selectedDashboardFilter = filter);
  }

  List<dynamic> _filteredApplications() {
    final filtered = _applications
        .where(_matchesApplicationFilter)
        .where(_matchesApplicationSearch)
        .toList();

    filtered.sort((a, b) {
      final first = _parseDate(b['applied_date'] ?? b['created_at']);
      final second = _parseDate(a['applied_date'] ?? a['created_at']);
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });

    return filtered;
  }

  List<dynamic> _filteredUsers() {
    final filtered = _users.where(_matchesUserSearch).toList();
    filtered.sort((a, b) {
      final first = '${a['full_name'] ?? a['company_name'] ?? ''}'
          .toLowerCase();
      final second = '${b['full_name'] ?? b['company_name'] ?? ''}'
          .toLowerCase();
      return first.compareTo(second);
    });
    return filtered;
  }

  List<dynamic> _recentReports() {
    final reports = List<dynamic>.from(_reports);
    reports.sort((a, b) {
      final first = _parseDate(b['created_at']);
      final second = _parseDate(a['created_at']);
      if (first == null && second == null) return 0;
      if (first == null) return 1;
      if (second == null) return -1;
      return first.compareTo(second);
    });
    return reports.take(5).toList();
  }

  String _formatRelativeTime(dynamic rawDate) {
    final parsed = _parseDate(rawDate);
    if (parsed == null) return 'Unknown time';

    final difference = DateTime.now().difference(parsed);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hr ago';
    if (difference.inDays == 1) return 'Yesterday';
    return '${difference.inDays} days ago';
  }

  String _formatAppliedDate(dynamic rawDate) {
    final parsed = _parseDate(rawDate);
    if (parsed == null) return 'No date';
    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  double _percentage(int value, int total) {
    if (total <= 0) return 0;
    return value / total;
  }

  Widget _buildQuickAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.12)),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                color.withValues(alpha: 0.05),
                color.withValues(alpha: 0.12),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.18),
                      color.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade700, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroChip({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _adminBrandOrange.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _adminBrandNavy.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
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
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              ...?trailing == null ? null : [trailing],
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildApplicationsPerDayCard() {
    final series = _applicationSeries();
    final peakDay = _peakApplicationDay;
    final totalWeeklyApplications = _applicationsThisWeek;
    final averagePerDay = _averageApplicationsPerDay;
    final currentStats = _stats ?? <String, dynamic>{};
    final totalJobs = _asInt(currentStats['total_jobs']);
    final totalCompanies = _asInt(currentStats['total_companies']);

    return _buildAnalyticsCard(
      title: 'Applications per day',
      subtitle:
          '$totalWeeklyApplications submissions captured over the last 7 days.',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _adminBrandOrangeSoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          peakDay == null ? '7 days' : 'Peak ${_weekdayLabel(peakDay.date)}',
          style: const TextStyle(
            color: _adminBrandOrange,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InsightMetricTile(
                  label: 'This week',
                  value: '$totalWeeklyApplications',
                  color: _adminBrandNavy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetricTile(
                  label: 'Avg / day',
                  value: averagePerDay.toStringAsFixed(
                    averagePerDay >= 10 ? 0 : 1,
                  ),
                  color: _adminBrandOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetricTile(
                  label: 'Open system',
                  value: '$totalJobs jobs',
                  color: _adminBrandSuccess,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _adminBrandNavySoft,
                  Colors.white,
                  _adminBrandOrangeSoft.withValues(alpha: 0.42),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _adminBrandNavy.withValues(alpha: 0.08),
              ),
            ),
            child: SizedBox(
              height: 210,
              child: _ApplicationsLineChart(points: series),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniInsightChip(
                  label: 'Today',
                  value: '$_newApplicationsToday',
                  color: _adminBrandOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInsightChip(
                  label: 'Peak day',
                  value: peakDay == null
                      ? 'N/A'
                      : '${_weekdayLabel(peakDay.date)} • ${peakDay.count}',
                  color: _adminBrandNavy,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MiniInsightChip(
                  label: 'Companies',
                  value: '$totalCompanies active',
                  color: _adminBrandSuccess,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalSplitCard(
    int approved,
    int rejected,
    int pending,
    int totalApplications,
  ) {
    final approvalRate = _percentage(approved, totalApplications);
    final pendingRate = _percentage(pending, totalApplications);
    final decisionRate = _percentage(approved + rejected, totalApplications);
    final dominantLabel = () {
      final counts = <String, int>{
        'Approved': approved,
        'Rejected': rejected,
        'Pending': pending,
      };
      counts.removeWhere((_, value) => value <= 0);
      if (counts.isEmpty) return 'No outcome yet';
      final top = counts.entries.reduce(
        (current, next) => next.value > current.value ? next : current,
      );
      return '${top.key} leads';
    }();

    return _buildAnalyticsCard(
      title: 'Approved vs rejected',
      subtitle: 'Dynamic split based on the latest application statuses.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _InsightMetricTile(
                  label: 'Approval rate',
                  value: '${(approvalRate * 100).round()}%',
                  color: _adminBrandSuccess,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetricTile(
                  label: 'Pending share',
                  value: '${(pendingRate * 100).round()}%',
                  color: _adminBrandOrange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _InsightMetricTile(
                  label: 'Decisions made',
                  value: '${(decisionRate * 100).round()}%',
                  color: _adminBrandNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  _adminBrandNavySoft,
                  _adminBrandOrangeSoft.withValues(alpha: 0.3),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _adminBrandNavy.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ApprovalDonutChart(
                    approved: approved,
                    rejected: rejected,
                    pending: pending,
                    total: totalApplications,
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _StatusMetricRow(
                        label: 'Approved',
                        value: '$approved',
                        percentage: approvalRate,
                        color: _adminBrandSuccess,
                      ),
                      const SizedBox(height: 12),
                      _StatusMetricRow(
                        label: 'Rejected',
                        value: '$rejected',
                        percentage: _percentage(rejected, totalApplications),
                        color: _adminBrandDanger,
                      ),
                      const SizedBox(height: 12),
                      _StatusMetricRow(
                        label: 'Pending',
                        value: '$pending',
                        percentage: pendingRate,
                        color: _adminBrandOrange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: const [
              _InsightLegendChip(label: 'Approved', color: _adminBrandSuccess),
              _InsightLegendChip(label: 'Rejected', color: _adminBrandDanger),
              _InsightLegendChip(label: 'Pending', color: _adminBrandOrange),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _adminBrandNavySoft,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              totalApplications == 0
                  ? 'No application outcomes yet.'
                  : '$dominantLabel across $totalApplications applications. $approved approved, $rejected rejected, and $pending pending.',
              style: const TextStyle(
                color: _adminBrandNavy,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterPanel(
    List<dynamic> matchedUsers,
    List<dynamic> matchedApplications,
  ) {
    final resultsCount = matchedUsers.length + matchedApplications.length;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Search and filter',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Search any user or application, then narrow application results by status.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 700;

              if (stacked) {
                return Column(
                  children: [
                    _buildSearchField(),
                    const SizedBox(height: 12),
                    _buildFilterDropdown(),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 3, child: _buildSearchField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildFilterDropdown()),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _DashboardBadge(
                icon: Icons.manage_search_rounded,
                label: '$resultsCount matches',
                color: _adminBrandNavy,
              ),
              _DashboardBadge(
                icon: Icons.assignment_rounded,
                label: '${matchedApplications.length} applications',
                color: _adminBrandOrange,
              ),
              _DashboardBadge(
                icon: Icons.people_alt_rounded,
                label: '${matchedUsers.length} users',
                color: _adminBrandNavy,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: 'Search user, email, company, application...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _adminBrandOrange, width: 1.5),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedDashboardFilter,
      onChanged: (value) {
        if (value == null) return;
        setState(() => _selectedDashboardFilter = value);
      },
      decoration: InputDecoration(
        labelText: 'Filter',
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _adminBrandOrange, width: 1.5),
        ),
      ),
      items: const [
        DropdownMenuItem(value: 'all', child: Text('All')),
        DropdownMenuItem(value: 'pending', child: Text('Pending')),
        DropdownMenuItem(value: 'approved', child: Text('Approved')),
        DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
      ],
    );
  }

  Widget _buildSearchResultsSection(
    List<dynamic> matchedUsers,
    List<dynamic> matchedApplications,
  ) {
    final showUsers = matchedUsers.isNotEmpty;
    final showApplications = matchedApplications.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Dashboard results',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton.icon(
                onPressed: _openReports,
                icon: const Icon(Icons.insights_rounded, size: 18),
                label: const Text('Open report'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _searchQuery.trim().isEmpty
                ? 'Latest application updates based on the selected filter.'
                : 'Showing matches for "${_searchQuery.trim()}".',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          if (!showApplications && !showUsers)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text(
                'No users or applications match the current search and filter.',
              ),
            )
          else ...[
            if (showApplications) ...[
              _SectionHeader(
                title: 'Applications',
                actionLabel: 'Open applications',
                onTap: () => _openApplications(
                  _selectedDashboardFilter == 'pending'
                      ? AdminApplicationFilter.pending
                      : _selectedDashboardFilter == 'approved'
                      ? AdminApplicationFilter.approved
                      : _selectedDashboardFilter == 'rejected'
                      ? AdminApplicationFilter.rejected
                      : AdminApplicationFilter.all,
                ),
              ),
              const SizedBox(height: 12),
              ...matchedApplications.take(4).map((application) {
                final status = _normalizedStatus(application['status']);
                final color = status == 'approved'
                    ? _adminBrandSuccess
                    : status == 'rejected'
                    ? _adminBrandDanger
                    : _adminBrandOrange;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultTile(
                    icon: Icons.assignment_turned_in_rounded,
                    color: color,
                    title:
                        '${application['user_name'] ?? 'Applicant'} • ${application['job_title'] ?? 'Job'}',
                    subtitle:
                        '${application['company_name'] ?? 'Unknown company'} • ${_formatAppliedDate(application['applied_date'] ?? application['created_at'])}',
                    badge: status.isEmpty ? 'pending' : status,
                    onTap: () => _openApplications(
                      status == 'approved'
                          ? AdminApplicationFilter.approved
                          : status == 'rejected'
                          ? AdminApplicationFilter.rejected
                          : status == 'pending'
                          ? AdminApplicationFilter.pending
                          : AdminApplicationFilter.all,
                    ),
                  ),
                );
              }),
            ],
            if (showApplications && showUsers) const SizedBox(height: 18),
            if (showUsers) ...[
              _SectionHeader(
                title: 'Users',
                actionLabel: 'Open users',
                onTap: () => _openUsers(AdminUserFilter.all),
              ),
              const SizedBox(height: 12),
              ...matchedUsers.take(4).map((user) {
                final role = '${user['role'] ?? 'user'}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ResultTile(
                    icon: Icons.person_search_rounded,
                    color: _adminBrandNavy,
                    title:
                        '${user['full_name'] ?? user['company_name'] ?? 'User'}',
                    subtitle:
                        '${user['email'] ?? ''} • ${user['location'] ?? 'No location'}',
                    badge: role,
                    onTap: () => _openUsers(
                      role == 'company'
                          ? AdminUserFilter.companies
                          : role == 'student' || role == 'graduate'
                          ? AdminUserFilter.registeredUsers
                          : AdminUserFilter.all,
                    ),
                  ),
                );
              }),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildRecentActivitySection(List<dynamic> reports) {
    return _buildAnalyticsCard(
      title: 'Recent activity',
      subtitle: 'Latest system and admin report events.',
      trailing: TextButton.icon(
        onPressed: _openReports,
        icon: const Icon(Icons.receipt_long_rounded, size: 18),
        label: const Text('Open report'),
      ),
      child: reports.isEmpty
          ? Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('No recent report activity available yet.'),
            )
          : Column(
              children: reports.map((report) {
                final category = '${report['category'] ?? 'admin_action'}'
                    .toLowerCase();
                final color = category == 'error'
                    ? _adminBrandDanger
                    : category == 'login'
                    ? _adminBrandNavy
                    : _adminBrandSuccess;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          category == 'error'
                              ? Icons.error_outline_rounded
                              : category == 'login'
                              ? Icons.login_rounded
                              : Icons.insights_rounded,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${report['event_type'] ?? 'System event'}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _formatRelativeTime(report['created_at']),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${report['message'] ?? ''}',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 56,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              const Text(
                'Failed to load dashboard',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboardData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = _stats ?? <String, dynamic>{};
    final totalUsers = _totalUsers(stats);
    final totalApplications = _totalApplications(stats);
    final pending = _pendingApplications(stats);
    final approved = _approvedApplications(stats);
    final rejected = _rejectedApplications(stats);
    final matchedUsers = _filteredUsers();
    final matchedApplications = _filteredApplications();
    final recentReports = _recentReports();
    final firstName = widget.adminName.trim().isEmpty
        ? 'Admin'
        : widget.adminName.trim().split(' ').first;

    return RefreshIndicator(
      onRefresh: _loadDashboardData,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: const LinearGradient(
                colors: [_adminBrandNavy, Color(0xFF11466F), _adminBrandOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -22,
                  top: -26,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Positioned(
                  right: 46,
                  bottom: -34,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: _adminBrandOrange.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 66,
                          width: 66,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/internshiplogo.png',
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.verified_rounded,
                                  color: _adminBrandNavy,
                                  size: 34,
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'Government Internship Platform',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Welcome back, $firstName',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.96),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 24,
                                  height: 1.1,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'You have $_newApplicationsToday new application${_newApplicationsToday == 1 ? '' : 's'} today.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.84),
                                  height: 1.4,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildHeroChip(
                          label: '$totalUsers total users',
                          icon: Icons.groups_rounded,
                        ),
                        _buildHeroChip(
                          label: '$pending pending reviews',
                          icon: Icons.hourglass_top_rounded,
                        ),
                        _buildHeroChip(
                          label: '$approved approvals',
                          icon: Icons.check_circle_rounded,
                        ),
                        _buildHeroChip(
                          label: '${recentReports.length} recent reports',
                          icon: Icons.receipt_long_rounded,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildSearchAndFilterPanel(matchedUsers, matchedApplications),
          const SizedBox(height: 22),
          const Text(
            'Statistics',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Tap a card to filter the dashboard or open its full data view.',
            style: TextStyle(color: Colors.grey.shade600, height: 1.35),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 1180
                  ? 4
                  : constraints.maxWidth >= 760
                  ? 3
                  : 2;
              final spacing = constraints.maxWidth < 520 ? 8.0 : 10.0;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
              final visibleApplications = _applicationCountForCard('all');
              final pendingApplications = _applicationCountForCard('pending');
              final approvedApplications = _applicationCountForCard('approved');
              final rejectedApplications = _applicationCountForCard('rejected');

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: StatisticCard(
                      title: 'Total users',
                      value: totalUsers,
                      subtitle: _searchQuery.trim().isEmpty
                          ? 'All registered users'
                          : '${matchedUsers.length} matched by current search',
                      icon: Icons.people_rounded,
                      color: _adminBrandNavy,
                      trend: 'Open users',
                      onTap: () => _openUsers(AdminUserFilter.all),
                      compact: true,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatisticCard(
                      title: 'Pending',
                      value: pendingApplications,
                      subtitle: _searchQuery.trim().isEmpty
                          ? 'Needs review from admin team'
                          : 'Pending applications matching current search',
                      icon: Icons.hourglass_top_rounded,
                      color: _adminBrandOrange,
                      trend: _selectedDashboardFilter == 'pending'
                          ? 'Current filter'
                          : 'Filter pending',
                      onTap: () => _setDashboardFilter('pending'),
                      compact: true,
                      selected: _selectedDashboardFilter == 'pending',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatisticCard(
                      title: 'Approved',
                      value: approvedApplications,
                      subtitle: visibleApplications == 0
                          ? 'No approvals yet'
                          : '${(_percentage(approvedApplications, visibleApplications) * 100).round()}% approval rate',
                      icon: Icons.check_circle_rounded,
                      color: _adminBrandSuccess,
                      trend: _selectedDashboardFilter == 'approved'
                          ? 'Current filter'
                          : 'Filter approved',
                      onTap: () => _setDashboardFilter('approved'),
                      compact: true,
                      selected: _selectedDashboardFilter == 'approved',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatisticCard(
                      title: 'Rejected',
                      value: rejectedApplications,
                      subtitle: visibleApplications == 0
                          ? 'No rejections yet'
                          : '${(_percentage(rejectedApplications, visibleApplications) * 100).round()}% rejection rate',
                      icon: Icons.cancel_rounded,
                      color: _adminBrandDanger,
                      trend: _selectedDashboardFilter == 'rejected'
                          ? 'Current filter'
                          : 'Filter rejected',
                      onTap: () => _setDashboardFilter('rejected'),
                      compact: true,
                      selected: _selectedDashboardFilter == 'rejected',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatisticCard(
                      title: 'Applications',
                      value: visibleApplications,
                      subtitle: _searchQuery.trim().isEmpty
                          ? 'All submissions in the system'
                          : 'Applications matching current search',
                      icon: Icons.assignment_rounded,
                      color: _adminBrandOrange,
                      trend: _selectedDashboardFilter == 'all'
                          ? 'Current filter'
                          : 'Show all',
                      onTap: () => _setDashboardFilter('all'),
                      compact: true,
                      selected: _selectedDashboardFilter == 'all',
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: StatisticCard(
                      title: 'Reports',
                      value: recentReports.length,
                      subtitle: 'Recent activity in report feed',
                      icon: Icons.receipt_long_rounded,
                      color: _adminBrandNavy,
                      trend: 'Open report',
                      onTap: _openReports,
                      compact: true,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          const Text(
            'Insights',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final singleColumn = constraints.maxWidth < 860;
              final itemWidth = singleColumn
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 12) / 2;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildApplicationsPerDayCard(),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildApprovalSplitCard(
                      approved,
                      rejected,
                      pending,
                      totalApplications,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 22),
          _buildSearchResultsSection(matchedUsers, matchedApplications),
          const SizedBox(height: 22),
          _buildRecentActivitySection(recentReports),
          const SizedBox(height: 22),
          const Text(
            'Quick actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth < 760 ? 1 : 3;
              final itemWidth =
                  (constraints.maxWidth - ((columns - 1) * 12)) / columns;

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildQuickAction(
                      title: 'View users',
                      subtitle: 'Open user management and review access.',
                      icon: Icons.manage_accounts_rounded,
                      color: _adminBrandNavy,
                      onTap: () => _openUsers(AdminUserFilter.all),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQuickAction(
                      title: 'View applications',
                      subtitle: 'Review pending, approved, and rejected cases.',
                      icon: Icons.assignment_turned_in_rounded,
                      color: _adminBrandOrange,
                      onTap: () =>
                          _openApplications(AdminApplicationFilter.all),
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildQuickAction(
                      title: 'Export report',
                      subtitle: 'Download the latest admin summary as a file.',
                      icon: Icons.download_rounded,
                      color: _adminBrandNavy,
                      onTap: _exportDashboardReport,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _DailyApplicationsPoint {
  final DateTime date;
  final int count;

  const _DailyApplicationsPoint({required this.date, required this.count});
}

class _DashboardBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _DashboardBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MiniInsightChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniInsightChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _InsightMetricTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightLegendChip extends StatelessWidget {
  final String label;
  final Color color;

  const _InsightLegendChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsLineChart extends StatelessWidget {
  final List<_DailyApplicationsPoint> points;

  const _ApplicationsLineChart({required this.points});

  @override
  Widget build(BuildContext context) {
    final maxCount = points.fold<int>(
      1,
      (current, point) => point.count > current ? point.count : current,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '7-day trend',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            Text(
              'Max $maxCount / day',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: CustomPaint(
              size: Size.infinite,
              painter: _ApplicationsChartPainter(
                points: points,
                maxCount: maxCount,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: points
              .map(
                (point) => Expanded(
                  child: Column(
                    children: [
                      Text(
                        _shortStaticLabel(point.date),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.black54,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${point.count}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _adminBrandOrange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  static String _shortStaticLabel(DateTime date) {
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return '${weekdays[date.weekday - 1]}\n${date.day}';
  }
}

class _ApprovalDonutChart extends StatelessWidget {
  final int approved;
  final int rejected;
  final int pending;
  final int total;

  const _ApprovalDonutChart({
    required this.approved,
    required this.rejected,
    required this.pending,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        CustomPaint(
          size: const Size.square(160),
          painter: _ApprovalDonutPainter(
            approved: approved,
            rejected: rejected,
            pending: pending,
            total: total,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$total',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: _adminBrandNavy,
              ),
            ),
            Text(
              total == 0 ? 'No applications' : 'Application outcomes',
              style: TextStyle(
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _ResultTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge,
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusMetricRow extends StatelessWidget {
  final String label;
  final String value;
  final double percentage;
  final Color color;

  const _StatusMetricRow({
    required this.label,
    required this.value,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: 8),
            Text(
              '${(percentage * 100).round()}%',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _ApplicationsChartPainter extends CustomPainter {
  final List<_DailyApplicationsPoint> points;
  final int maxCount;

  const _ApplicationsChartPainter({
    required this.points,
    required this.maxCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const leftPadding = 10.0;
    const rightPadding = 10.0;
    const topPadding = 16.0;
    const bottomPadding = 18.0;
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final gridPaint = Paint()
      ..color = _adminBrandNavy.withValues(alpha: 0.08)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = topPadding + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width - rightPadding, y),
        gridPaint,
      );
    }

    final dxStep = points.length == 1 ? 0.0 : chartWidth / (points.length - 1);
    final chartPoints = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final ratio = maxCount == 0 ? 0.0 : points[i].count / maxCount;
      final x = leftPadding + (dxStep * i);
      final y = topPadding + chartHeight - (chartHeight * ratio);
      chartPoints.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(chartPoints.first.dx, chartPoints.first.dy);
    for (var i = 1; i < chartPoints.length; i++) {
      final previous = chartPoints[i - 1];
      final current = chartPoints[i];
      final controlX = (previous.dx + current.dx) / 2;
      linePath.cubicTo(
        controlX,
        previous.dy,
        controlX,
        current.dy,
        current.dx,
        current.dy,
      );
    }

    final areaPath = Path.from(linePath)
      ..lineTo(chartPoints.last.dx, size.height - bottomPadding)
      ..lineTo(chartPoints.first.dx, size.height - bottomPadding)
      ..close();

    final fillPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0x55EF6C00), Color(0x220E3A5D), Colors.transparent],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [_adminBrandOrange, _adminBrandNavy],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    for (final point in chartPoints) {
      canvas.drawCircle(point, 6, Paint()..color = Colors.white);
      canvas.drawCircle(point, 4, Paint()..color = _adminBrandOrange);
    }
  }

  @override
  bool shouldRepaint(covariant _ApplicationsChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxCount != maxCount;
  }
}

class _ApprovalDonutPainter extends CustomPainter {
  final int approved;
  final int rejected;
  final int pending;
  final int total;

  const _ApprovalDonutPainter({
    required this.approved,
    required this.rejected,
    required this.pending,
    required this.total,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 18.0;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - (strokeWidth / 2),
    );

    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, 6.28318, false, backgroundPaint);

    if (total <= 0) return;

    final segments = <({int value, Color color})>[
      (value: approved, color: _adminBrandSuccess),
      (value: rejected, color: _adminBrandDanger),
      (value: pending, color: _adminBrandOrange),
    ];

    var startAngle = -1.5708;
    for (final segment in segments) {
      if (segment.value <= 0) continue;
      final sweepAngle = (segment.value / total) * 6.28318;
      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle + 0.06;
    }
  }

  @override
  bool shouldRepaint(covariant _ApprovalDonutPainter oldDelegate) {
    return oldDelegate.approved != approved ||
        oldDelegate.rejected != rejected ||
        oldDelegate.pending != pending ||
        oldDelegate.total != total;
  }
}
