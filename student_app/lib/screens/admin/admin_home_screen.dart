import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/api_service.dart';

const Color _adminBrandNavy = Color(0xFF0E3A5D);
const Color _adminBrandOrange = Color(0xFFEF6C00);
const Color _adminBrandSand = Color(0xFFFFE0B2);
const Color _adminBrandSky = Color(0xFF3B82F6);
const Color _adminBrandInk = Color(0xFF1E293B);

class AdminHomeScreen extends StatefulWidget {
  final String? adminName;
  final ValueChanged<int>? onNavigateToTab;

  const AdminHomeScreen({super.key, this.adminName, this.onNavigateToTab});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _recentActivities = const [];
  List<Map<String, dynamic>> _topCompanies = const [];
  List<Map<String, dynamic>> _users = const [];
  List<Map<String, dynamic>> _jobs = const [];
  List<Map<String, dynamic>> _applications = const [];
  List<Map<String, dynamic>> _pendingApplications = const [];

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final responses = await Future.wait([
        _apiService.getAdminStats(),
        _apiService.getAdminLogs(),
        _apiService.getAdminJobs(),
        _apiService.getUsers(),
        _apiService.getApplications(),
      ]);

      final statsResponse = responses[0];
      final logsResponse = responses[1];
      final jobsResponse = responses[2];
      final usersResponse = responses[3];
      final pendingApplicationsResponse = responses[4];

      if (statsResponse['success'] != true) {
        throw Exception(statsResponse['message'] ?? 'Failed to load stats');
      }

      setState(() {
        _stats = statsResponse['data'] is Map<String, dynamic>
            ? statsResponse['data']
            : _fallbackStats();
        _users = _mapRecords(usersResponse['data']);
        _jobs = _mapRecords(jobsResponse['data']);
        _applications = _mapRecords(pendingApplicationsResponse['data']);
        _pendingApplications = _applications
            .where(
              (application) =>
                  _normalizedStatus(application['status']) == 'pending',
            )
            .toList(growable: false);
        _recentActivities = logsResponse['data'] is List
            ? _mapRecentActivities(logsResponse['data'])
            : _fallbackRecentActivities();
        _topCompanies = _jobs.isNotEmpty
            ? _mapTopCompanies(_jobs)
            : _fallbackTopCompanies();
        _isLoading = false;
      });
    } catch (error) {
      _log('Admin dashboard error: $error');
      setState(() {
        _stats = _fallbackStats();
        _recentActivities = _fallbackRecentActivities();
        _topCompanies = _fallbackTopCompanies();
        _users = const [];
        _jobs = const [];
        _applications = const [];
        _pendingApplications = const [];
        _isLoading = false;
        _hasError = true;
        _errorMessage = '$error';
      });
    }
  }

  List<Map<String, dynamic>> _mapRecords(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) {
          final mapped = <String, dynamic>{};
          for (final entry in item.entries) {
            mapped['${entry.key}'] = entry.value;
          }
          return mapped;
        })
        .toList(growable: false);
  }

  Map<String, dynamic> _fallbackStats() {
    return const {
      'total_users': 0,
      'total_students': 0,
      'total_companies': 0,
      'total_jobs': 0,
      'total_applications': 0,
      'pending_applications': 0,
      'approved_applications': 0,
      'rejected_applications': 0,
      'weekly_registrations': [12, 18, 15, 22, 19, 24, 20],
    };
  }

  List<Map<String, dynamic>> _fallbackRecentActivities() {
    return const [
      {
        'action': 'System ready',
        'user': 'Admin',
        'time': 'Just now',
        'type': 'admin',
      },
    ];
  }

  List<Map<String, dynamic>> _fallbackTopCompanies() {
    return const [
      {'name': 'No company data yet', 'jobs': 0, 'logo': '--'},
    ];
  }

  List<Map<String, dynamic>> _mapRecentActivities(List<dynamic> logs) {
    final mapped = logs.whereType<Map>().map((entry) {
      final category = '${entry['category'] ?? 'admin'}'.toLowerCase();
      final actorName =
          '${entry['actor_name'] ?? entry['user_involved_name'] ?? 'System'}';
      final eventType =
          '${entry['event_type'] ?? entry['message'] ?? 'Activity'}';

      return {
        'action': eventType,
        'user': actorName,
        'time': _formatRelativeTime(entry['created_at']?.toString()),
        'type': _mapActivityType(category),
      };
    }).toList();

    return mapped.isEmpty ? _fallbackRecentActivities() : mapped;
  }

  List<Map<String, dynamic>> _mapTopCompanies(List<Map<String, dynamic>> jobs) {
    final counts = <String, int>{};

    for (final job in jobs) {
      final rawName = '${job['company_name'] ?? 'Unknown Company'}'.trim();
      final name = rawName.isEmpty ? 'Unknown Company' : rawName;
      counts.update(name, (count) => count + 1, ifAbsent: () => 1);
    }

    final mapped =
        counts.entries
            .map(
              (entry) => {
                'name': entry.key,
                'jobs': entry.value,
                'logo': _buildInitials(entry.key),
              },
            )
            .toList()
          ..sort((a, b) => (b['jobs'] as int).compareTo(a['jobs'] as int));

    if (mapped.isEmpty) {
      return _fallbackTopCompanies();
    }

    return mapped.take(5).toList(growable: false);
  }

  String _buildInitials(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((part) => part.trim().isNotEmpty)
        .toList();

    if (parts.isEmpty) return '--';
    if (parts.length == 1) {
      final word = parts.first;
      return word.length >= 2 ? word.substring(0, 2).toUpperCase() : word;
    }

    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
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

  int get _newApplicationsToday {
    final today = DateTime.now();
    return _applications.where((application) {
      final appliedDate = _parseDate(
        application['applied_date'] ?? application['created_at'],
      );
      return appliedDate != null && _isSameDay(appliedDate, today);
    }).length;
  }

  List<int> _applicationSeries() {
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));
    final counts = List<int>.filled(7, 0);

    for (final application in _applications) {
      final appliedDate = _parseDate(
        application['applied_date'] ?? application['created_at'],
      );
      if (appliedDate == null) continue;

      final normalizedDate = DateTime(
        appliedDate.year,
        appliedDate.month,
        appliedDate.day,
      );
      final difference = normalizedDate.difference(start).inDays;
      if (difference >= 0 && difference < 7) {
        counts[difference] += 1;
      }
    }

    return counts;
  }

  List<String> _applicationDayLabels() {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now();
    final start = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(const Duration(days: 6));

    return List<String>.generate(7, (index) {
      final date = start.add(Duration(days: index));
      return weekdays[date.weekday - 1];
    }, growable: false);
  }

  int _totalApplicationsThisWeek(List<int> weeklyData) {
    return weeklyData.fold<int>(0, (total, value) => total + value);
  }

  String _peakApplicationsLabel(List<int> weeklyData) {
    if (weeklyData.isEmpty) return 'No peak yet';

    final peak = weeklyData.reduce((a, b) => a > b ? a : b);
    if (peak == 0) return 'No peak yet';

    final labels = _applicationDayLabels();
    final peakIndex = weeklyData.indexOf(peak);
    final dayLabel = peakIndex >= 0 && peakIndex < labels.length
        ? labels[peakIndex]
        : 'Day ${peakIndex + 1}';

    return '$dayLabel • $peak';
  }

  String _mapActivityType(String category) {
    switch (category) {
      case 'login':
        return 'user';
      case 'application':
        return 'application';
      case 'company':
        return 'company';
      case 'job':
        return 'job';
      case 'error':
        return 'error';
      default:
        return 'admin';
    }
  }

  String _formatRelativeTime(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Unknown time';
    }

    try {
      final date = DateTime.parse(value).toLocal();
      final diff = DateTime.now().difference(date);

      if (diff.inMinutes < 1) return 'Just now';
      if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
      if (diff.inHours < 24) return '${diff.inHours} hours ago';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      return '$day/$month/${date.year}';
    } catch (_) {
      return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading dashboard...'),
          ],
        ),
      );
    }

    final applicationSeries = _applicationSeries();

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_hasError)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    'Dashboard loaded with fallback data. $_errorMessage',
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                ),
              ),
            ),
          _buildWelcomeSection(),
          const SizedBox(height: 20),
          _buildNotificationPanel(),
          const SizedBox(height: 20),
          _buildStatsSection(),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 800) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _buildApplicationsChart(applicationSeries),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _buildTopCompaniesList()),
                  ],
                );
              }

              return Column(
                children: [
                  _buildApplicationsChart(applicationSeries),
                  const SizedBox(height: 16),
                  _buildTopCompaniesList(),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          _buildRecentActivities(),
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _adminBrandNavy,
            const Color(0xFF153E63),
            _adminBrandOrange.withValues(alpha: 0.92),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _adminBrandNavy.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome Admin!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _newApplicationsToday == 1
                      ? 'Welcome ${widget.adminName ?? 'Admin'}, there is 1 new application today.'
                      : 'Welcome ${widget.adminName ?? 'Admin'}, there are $_newApplicationsToday new applications today.',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _buildHeroChip(
                      label:
                          '${_pendingApplications.length} pending approval${_pendingApplications.length == 1 ? '' : 's'}',
                      icon: Icons.pending_actions_rounded,
                    ),
                    _buildHeroChip(
                      label:
                          '${_asInt(_stats['total_applications'])} total applications',
                      icon: Icons.description_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Colors.white,
              size: 40,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip({required String label, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0.18),
            _adminBrandSand.withValues(alpha: 0.18),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: _adminBrandOrange.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: Colors.white),
          ),
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

  Widget _buildNotificationPanel() {
    final latestUser = _users.isNotEmpty ? _users.first : null;
    final latestJob = _jobs.isNotEmpty ? _jobs.first : null;
    final latestPending = _pendingApplications.isNotEmpty
        ? _pendingApplications.first
        : null;
    final pendingCount =
        int.tryParse('${_stats['pending_applications'] ?? 0}') ?? 0;

    final items = [
      {
        'title': 'New User Registered',
        'message': latestUser == null
            ? 'No newly registered users yet'
            : '${latestUser['full_name'] ?? latestUser['email'] ?? 'New user'} joined the platform',
        'meta': latestUser == null
            ? 'User updates will appear here'
            : _formatRelativeTime(latestUser['created_at']?.toString()),
        'icon': Icons.person_add_alt_1_rounded,
        'color': Colors.blue,
        'onTap': () => widget.onNavigateToTab?.call(1),
      },
      {
        'title': 'New Job Posted',
        'message': latestJob == null
            ? 'No jobs have been posted yet'
            : '${latestJob['title'] ?? 'New job'} was posted by ${latestJob['company_name'] ?? 'a company'}',
        'meta': latestJob == null
            ? 'Recent job activity appears here'
            : _formatRelativeTime(latestJob['created_at']?.toString()),
        'icon': Icons.campaign_rounded,
        'color': Colors.orange,
        'onTap': null,
      },
      {
        'title': 'Pending Approval',
        'message': pendingCount == 0
            ? 'No pending approvals right now'
            : '$pendingCount application${pendingCount == 1 ? '' : 's'} waiting for review',
        'meta': latestPending == null
            ? 'Open applications to review requests'
            : '${latestPending['user_name'] ?? latestPending['email'] ?? 'Applicant'} for ${latestPending['job_title'] ?? 'a job'}',
        'icon': Icons.pending_actions_rounded,
        'color': Colors.redAccent,
        'onTap': () => widget.onNavigateToTab?.call(2),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Notification Panel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Track new registrations, new jobs, and approvals that need attention.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 16),
          ...items.map((item) {
            final color = item['color'] as Color;
            final onTap = item['onTap'] as void Function()?;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item['icon'] as IconData, color: color),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['title'] as String,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['message'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['meta'] as String,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onTap != null)
                        Icon(
                          Icons.chevron_right_rounded,
                          color: Colors.grey.shade500,
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Stats',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _adminBrandInk,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Overview of users, students, companies, and jobs.',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 14),
        _buildStatsGrid(),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final stats = [
      {
        'title': 'Total Users',
        'value': _stats['total_users'] ?? 0,
        'icon': Icons.people,
        'color': Colors.blue,
      },
      {
        'title': 'Students',
        'value': _stats['total_students'] ?? 0,
        'icon': Icons.school,
        'color': Colors.green,
      },
      {
        'title': 'Companies',
        'value': _stats['total_companies'] ?? 0,
        'icon': Icons.business,
        'color': Colors.purple,
      },
      {
        'title': 'Jobs',
        'value': _stats['total_jobs'] ?? 0,
        'icon': Icons.work_outline,
        'color': Colors.orange,
      },
    ];

    return GridView.count(
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.2,
      children: stats
          .map((stat) {
            return _buildStatCard(
              title: stat['title'] as String,
              value: '${stat['value']}',
              icon: stat['icon'] as IconData,
              color: stat['color'] as Color,
            );
          })
          .toList(growable: false),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildApplicationsChart(List<int> weeklyData) {
    final weeklyTotal = _totalApplicationsThisWeek(weeklyData);
    final maxValue = weeklyData.isEmpty
        ? 0
        : weeklyData.reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _adminBrandNavy.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: _adminBrandNavy.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Applications Per Day',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
              Text(
                'Last 7 days',
                style: TextStyle(
                  fontSize: 12,
                  color: _adminBrandOrange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _ChartStatBadge(
                icon: Icons.insights_rounded,
                label: 'This week',
                value: '$weeklyTotal applications',
                backgroundColor: _adminBrandNavy,
                accentColor: _adminBrandOrange,
              ),
              _ChartStatBadge(
                icon: Icons.local_fire_department_rounded,
                label: 'Peak day',
                value: _peakApplicationsLabel(weeklyData),
                backgroundColor: _adminBrandOrange.withValues(alpha: 0.1),
                accentColor: _adminBrandOrange,
                textColor: _adminBrandInk,
              ),
              _ChartStatBadge(
                icon: Icons.show_chart_rounded,
                label: 'Highest',
                value: '$maxValue per day',
                backgroundColor: _adminBrandNavy.withValues(alpha: 0.08),
                accentColor: _adminBrandSky,
                textColor: _adminBrandInk,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 240,
            child: _ApplicationsTrendChart(
              weeklyData: weeklyData,
              labels: _applicationDayLabels(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopCompaniesList() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top Companies',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          ..._topCompanies.map((company) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => widget.onNavigateToTab?.call(1),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          '${company['logo'] ?? '--'}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF3B82F6),
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${company['name'] ?? 'Unknown Company'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${company['jobs'] ?? 0} active jobs',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${company['jobs'] ?? 0}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => widget.onNavigateToTab?.call(1),
            child: const Text('View All Companies'),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activities',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _recentActivities.length > 5
                ? 5
                : _recentActivities.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final activity = _recentActivities[index];
              final type = '${activity['type'] ?? 'admin'}';
              final color = _getActivityColor(type);

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.1),
                  radius: 20,
                  child: Icon(_getActivityIcon(type), color: color, size: 20),
                ),
                title: Text(
                  '${activity['action'] ?? 'Activity'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: Text(
                  '${activity['user'] ?? 'System'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                trailing: Text(
                  '${activity['time'] ?? 'Unknown time'}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getActivityColor(String type) {
    switch (type) {
      case 'user':
        return Colors.blue;
      case 'job':
        return Colors.green;
      case 'company':
        return Colors.purple;
      case 'application':
        return Colors.orange;
      case 'error':
        return Colors.red;
      default:
        return Colors.indigo;
    }
  }

  IconData _getActivityIcon(String type) {
    switch (type) {
      case 'user':
        return Icons.person_add;
      case 'job':
        return Icons.work_outline;
      case 'company':
        return Icons.business;
      case 'application':
        return Icons.description;
      case 'error':
        return Icons.error_outline;
      default:
        return Icons.admin_panel_settings;
    }
  }
}

class _ChartStatBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color backgroundColor;
  final Color accentColor;
  final Color textColor;

  const _ChartStatBadge({
    required this.icon,
    required this.label,
    required this.value,
    required this.backgroundColor,
    required this.accentColor,
    this.textColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accentColor, size: 16),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: effectiveTextColor.withValues(alpha: 0.74),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: effectiveTextColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicationsTrendChart extends StatelessWidget {
  final List<int> weeklyData;
  final List<String> labels;

  const _ApplicationsTrendChart({
    required this.weeklyData,
    required this.labels,
  });

  @override
  Widget build(BuildContext context) {
    final data = weeklyData.isEmpty ? const [0, 0, 0, 0, 0, 0, 0] : weeklyData;
    final highestValue = data.reduce((a, b) => a > b ? a : b);
    final maxValue = highestValue == 0 ? 4 : highestValue;
    final scaleValues = [
      maxValue,
      (maxValue * 0.66).round(),
      (maxValue * 0.33).round(),
      0,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _adminBrandNavy.withValues(alpha: 0.03),
            _adminBrandOrange.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 34),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: scaleValues
                    .map(
                      (value) => Text(
                        '$value',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: CustomPaint(
                    painter: _ApplicationsTrendPainter(
                      weeklyData: data,
                      maxValue: maxValue,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: List.generate(data.length, (index) {
                    final isPeak =
                        data[index] == highestValue && highestValue > 0;

                    return Expanded(
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: isPeak
                                  ? _adminBrandOrange.withValues(alpha: 0.12)
                                  : _adminBrandNavy.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${data[index]}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: isPeak
                                    ? _adminBrandOrange
                                    : _adminBrandNavy,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            index < labels.length
                                ? labels[index]
                                : 'Day ${index + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ApplicationsTrendPainter extends CustomPainter {
  final List<int> weeklyData;
  final int maxValue;

  const _ApplicationsTrendPainter({
    required this.weeklyData,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weeklyData.isEmpty) return;

    const topPadding = 12.0;
    const bottomPadding = 16.0;
    const leftPadding = 6.0;
    const rightPadding = 6.0;
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

    final stepX = weeklyData.length == 1
        ? 0.0
        : chartWidth / (weeklyData.length - 1);
    final points = <Offset>[];

    for (var i = 0; i < weeklyData.length; i++) {
      final ratio = maxValue == 0 ? 0.0 : weeklyData[i] / maxValue;
      final x = leftPadding + (stepX * i);
      final y = topPadding + chartHeight - (chartHeight * ratio);
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final previous = points[i - 1];
      final current = points[i];
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
      ..lineTo(points.last.dx, size.height - bottomPadding)
      ..lineTo(points.first.dx, size.height - bottomPadding)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          _adminBrandOrange.withValues(alpha: 0.32),
          _adminBrandSky.withValues(alpha: 0.16),
          Colors.transparent,
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(areaPath, fillPaint);

    final linePaint = Paint()
      ..shader = const LinearGradient(
        colors: [_adminBrandOrange, _adminBrandSky, _adminBrandNavy],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    final peakValue = weeklyData.reduce((a, b) => a > b ? a : b);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final isPeak = weeklyData[i] == peakValue && peakValue > 0;

      canvas.drawCircle(point, isPeak ? 7 : 6, Paint()..color = Colors.white);
      canvas.drawCircle(
        point,
        isPeak ? 4.5 : 4,
        Paint()..color = isPeak ? _adminBrandOrange : _adminBrandNavy,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ApplicationsTrendPainter oldDelegate) {
    return oldDelegate.weeklyData != weeklyData ||
        oldDelegate.maxValue != maxValue;
  }
}
