import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/change_pin_dialog.dart';
import '../../widgets/reset_pin_dialog.dart';
import '../../widgets/language_picker_dialog.dart';
import '../auth/login_screen.dart';
import 'post_job_screen.dart';
import 'edit_company_profile_screen.dart';
import 'company_notifications_screen.dart';

enum _CompanyMoreAction { settings, language, logout }

class CompanyDashboard extends StatefulWidget {
  final int initialIndex;
  final String? initialJobId;
  final String? initialJobTitle;

  const CompanyDashboard({
    super.key,
    this.initialIndex = 0,
    this.initialJobId,
    this.initialJobTitle,
  });

  @override
  State<CompanyDashboard> createState() => _CompanyDashboardState();
}

class _PickedPdfFile {
  final String? filePath;
  final Uint8List? fileBytes;
  final String fileName;

  const _PickedPdfFile({
    required this.filePath,
    required this.fileBytes,
    required this.fileName,
  });
}

typedef _AcceptanceInputBuilder =
    Widget Function({
      required TextEditingController controller,
      required String label,
      String? hint,
      TextInputType keyboardType,
      int maxLines,
    });

class _CompanyDashboardState extends State<CompanyDashboard> {
  final ApiService _apiService = ApiService();
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  final List<int> _tabHistory = [];

  String? _selectedJobId;
  String? _selectedJobTitle;

  String _formatToday(BuildContext context) {
    return MaterialLocalizations.of(context).formatFullDate(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex >= 0 && widget.initialIndex <= 3
        ? widget.initialIndex
        : 0;
    _selectedJobId = widget.initialJobId;
    _selectedJobTitle = widget.initialJobTitle;
    _tabHistory.add(_currentIndex);
    _loadUnreadNotificationCount();
  }

  void _selectJob(String jobId, String jobTitle) {
    navigateToTab(2, jobId: jobId, jobTitle: jobTitle);
  }

  void navigateToTab(int index, {String? jobId, String? jobTitle}) {
    setState(() {
      if (_currentIndex != index) {
        _tabHistory.add(index);
      }
      _currentIndex = index;
      _selectedJobId = jobId;
      _selectedJobTitle = jobTitle;
    });
  }

  bool _handleBackPress() {
    if (_tabHistory.length > 1) {
      final previousTab = _tabHistory[_tabHistory.length - 2];
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = previousTab;
        if (previousTab != 2) {
          _selectedJobId = null;
          _selectedJobTitle = null;
        }
      });
      return false;
    }

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _selectedJobId = null;
        _selectedJobTitle = null;
        _tabHistory
          ..clear()
          ..add(0);
      });
      return false;
    }

    return true;
  }

  Future<void> _loadUnreadNotificationCount({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.getUnreadNotificationCount(
        forceRefresh: forceRefresh,
      );
      if (response['success'] == true && mounted) {
        final rawCount = response['data']?['count'];
        setState(() => _unreadNotifications = int.tryParse('$rawCount') ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CompanyNotificationsScreen()),
    );
    _loadUnreadNotificationCount(forceRefresh: true);
  }

  void _handleRouteNavigationResult(dynamic result) {
    if (result is Map && result['targetIndex'] is int) {
      navigateToTab(result['targetIndex'] as int);
    }
  }

  List<Widget> _buildScreens() {
    return [
      const CompanyHomeScreen(),
      CompanyJobsScreen(selectJob: _selectJob),
      CompanyApplicationsTab(
        key: ValueKey(_selectedJobId),
        jobId: _selectedJobId,
        jobTitle: _selectedJobTitle,
        onGoToJobs: () => navigateToTab(1),
      ),
      const CompanyProfileScreen(),
    ];
  }

  Future<void> _logout() async {
    final language = context.read<LanguageProvider>();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(language.tr('logout_title')),
        content: Text(language.tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(language.tr('logout')),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await authProvider.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(language.tr('logout_success')),
        backgroundColor: Colors.green,
      ),
    );
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _showLanguageDialog() async {
    final language = context.read<LanguageProvider>();
    final currentLanguageCode = language.localeCode;
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (_) => LanguagePickerDialog(
        titleText: language.tr('change_language_title'),
        cancelText: language.tr('cancel'),
        applyText: language.tr('apply'),
        currentLanguageCode: currentLanguageCode,
        options: [
          LanguageOption(code: 'en', label: language.nativeLanguageName('en')),
          LanguageOption(code: 'sw', label: language.nativeLanguageName('sw')),
        ],
      ),
    );

    if (selectedLanguage == null ||
        selectedLanguage == currentLanguageCode ||
        !mounted) {
      return;
    }

    await context.read<LanguageProvider>().setLocaleCode(selectedLanguage);
    if (!mounted) return;
    final updatedLanguage = context.read<LanguageProvider>();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          updatedLanguage.tr('language_changed_to', {
            'language': updatedLanguage.nativeLanguageName(selectedLanguage),
          }),
        ),
      ),
    );
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final language = sheetContext.watch<LanguageProvider>();
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  language.tr('company_settings'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_outlined),
                  title: Text(language.tr('language')),
                  subtitle: Text(language.selectedLanguageName),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showLanguageDialog();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline),
                  title: Text(language.tr('company_profile')),
                  subtitle: Text(language.tr('open_profile_tab')),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    navigateToTab(3);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(language.tr('notifications')),
                  subtitle: Text(language.tr('open_company_notifications')),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openNotifications();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMoreAction(_CompanyMoreAction action) async {
    switch (action) {
      case _CompanyMoreAction.settings:
        await _showSettingsSheet();
        break;
      case _CompanyMoreAction.language:
        await _showLanguageDialog();
        break;
      case _CompanyMoreAction.logout:
        await _logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final today = _formatToday(context);

    return PopScope(
      canPop: _tabHistory.length <= 1 && _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final shouldExit = _handleBackPress();
        if (shouldExit && mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF2C3E50),
          elevation: 0,
          titleSpacing: 8,
          title: Row(
            children: [
              Container(
                height: 55,
                width: 55,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withValues(alpha: 0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/internshiplogo.png',
                    height: 55,
                    width: 55,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.verified,
                        size: 35,
                        color: Colors.blue,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: language.tr('notifications'),
              onPressed: _openNotifications,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: Colors.white,
                    size: 24,
                  ),
                  if (_unreadNotifications > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        child: Text(
                          _unreadNotifications > 99
                              ? '99+'
                              : '$_unreadNotifications',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<_CompanyMoreAction>(
              tooltip: language.tr('more_actions'),
              onSelected: _handleMoreAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _CompanyMoreAction.settings,
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(language.tr('settings')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _CompanyMoreAction.language,
                  child: Row(
                    children: [
                      const Icon(Icons.language_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(language.tr('change_language')),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _CompanyMoreAction.logout,
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(language.tr('logout')),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            ),
            const SizedBox(width: 4),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(42),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      today,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: IndexedStack(index: _currentIndex, children: _buildScreens()),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: (index) {
            navigateToTab(index);
            _loadUnreadNotificationCount();
          },
          selectedItemColor: const Color(0xFF2C3E50),
          unselectedItemColor: Colors.grey.shade600,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.dashboard_outlined),
              activeIcon: const Icon(Icons.dashboard),
              label: language.tr('dashboard'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.work_outline),
              activeIcon: const Icon(Icons.work),
              label: language.tr('my_jobs'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.people_outline),
              activeIcon: const Icon(Icons.people),
              label: language.tr('applications'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.business_outlined),
              activeIcon: const Icon(Icons.business),
              label: language.tr('profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// ============ HELPER FUNCTIONS ============
int getApplicantsCount(dynamic count) {
  if (count is int) return count;
  if (count is String) return int.tryParse(count) ?? 0;
  return 0;
}

String getDaysLeft(String? deadlineStr, LanguageProvider language) {
  if (deadlineStr == null) return language.tr('no_deadline');
  try {
    final deadline = DateTime.parse(deadlineStr);
    final difference = deadline.difference(DateTime.now());
    final daysLeft = difference.inDays;
    if (difference.isNegative) return language.tr('expired');
    if (daysLeft > 0) {
      return language.tr('days_left', {'count': '$daysLeft'});
    }
    return language.tr('closes_today');
  } catch (e) {
    return language.tr('invalid_date');
  }
}

String formatDeadlineDateTime(String? deadlineStr, LanguageProvider language) {
  if (deadlineStr == null) return language.tr('no_deadline');
  try {
    final deadline = DateTime.parse(deadlineStr);
    final day = deadline.day.toString().padLeft(2, '0');
    final month = deadline.month.toString().padLeft(2, '0');
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$day/$month/${deadline.year} $hour:$minute';
  } catch (e) {
    return language.tr('invalid_date');
  }
}

String formatCompanyStatus(String status, LanguageProvider language) {
  return status == 'open'
      ? language.tr('status_active')
      : language.tr('status_closed');
}

String formatTargetAudience(String target, LanguageProvider language) {
  switch (target) {
    case 'current_students':
      return language.tr('current_students');
    case 'fresh_graduates':
      return language.tr('fresh_graduates');
    case '1-2_years':
      return language.tr('experience_1_2_years_short');
    case '2-3_years':
      return language.tr('experience_2_3_years_short');
    case '3+_years':
      return language.tr('experience_3_plus_years_short');
    default:
      return target;
  }
}

String formatApplicationStatus(String status, LanguageProvider language) {
  switch (status) {
    case 'shortlisted':
      return language.tr('status_shortlisted');
    case 'interview':
      return language.tr('status_interview');
    case 'accepted':
      return language.tr('status_accepted');
    case 'rejected':
      return language.tr('status_rejected');
    case 'pending':
    default:
      return language.tr('status_pending');
  }
}

// ============ COMPANY HOME SCREEN ============
class CompanyHomeScreen extends StatefulWidget {
  const CompanyHomeScreen({super.key});

  @override
  State<CompanyHomeScreen> createState() => _CompanyHomeScreenState();
}

class _CompanyHomeScreenState extends State<CompanyHomeScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _jobs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final jobsResponse = await _apiService.getCompanyJobs(
        forceRefresh: forceRefresh,
      );
      if (jobsResponse['success']) {
        setState(() {
          _jobs = jobsResponse['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _goToJobsTab() {
    final dashboard = context.findAncestorStateOfType<_CompanyDashboardState>();
    dashboard?.navigateToTab(1);
  }

  void _goToApplicationsTab() {
    final dashboard = context.findAncestorStateOfType<_CompanyDashboardState>();
    dashboard?.navigateToTab(2);
  }

  void _showJobDetailsDialog(BuildContext context, dynamic job) {
    final language = context.read<LanguageProvider>();
    final isActive = job['status'] == 'open';
    final applicantsCount = getApplicantsCount(job['applications_count']);
    final daysLeft = getDaysLeft(job['application_deadline'], language);
    final deadlineLabel = formatDeadlineDateTime(
      job['application_deadline'],
      language,
    );
    final requiredApplicants = getApplicantsCount(job['required_applicants']);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.work,
                      color: const Color(0xFF2C3E50),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job['title'],
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          job['company_name'] ?? language.tr('company'),
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
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      formatCompanyStatus(job['status'] ?? 'closed', language),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isActive
                            ? Colors.green.shade700
                            : Colors.red.shade700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              _buildDetailRow(
                Icons.location_on,
                language.tr('location'),
                job['location'] ?? language.tr('not_provided'),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.attach_money,
                language.tr('salary'),
                job['salary_range'] ?? language.tr('not_provided'),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.work,
                language.tr('job_type'),
                job['type'] ?? language.tr('not_provided'),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.people,
                language.tr('applications'),
                language.tr('applicants_count', {'count': '$applicantsCount'}),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.groups,
                language.tr('needed_count', {'count': ''}).trim(),
                language.tr('needed_count', {'count': '$requiredApplicants'}),
              ),
              const SizedBox(height: 8),
              _buildDetailRow(
                Icons.access_time,
                language.tr('deadline'),
                '$deadlineLabel ($daysLeft)',
              ),
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 12),
              Text(
                language.tr('description'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                job['description'] ?? language.tr('no_description_provided'),
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                language.tr('target_candidates'),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (job['target_candidates'] as List? ?? []).map((
                  target,
                ) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      formatTargetAudience('$target', language),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C3E50),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(language.tr('close')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _showStatsDialog(BuildContext context) {
    final language = context.read<LanguageProvider>();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final companyName =
        user?['company_data']?['company_name'] ?? language.tr('company');

    int totalApplicants = 0;
    int activeJobs = 0;
    int closedJobs = 0;

    for (var job in _jobs) {
      if (job['status'] == 'open') {
        activeJobs++;
      } else {
        closedJobs++;
      }
      totalApplicants += getApplicantsCount(job['applications_count']);
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.analytics, color: Colors.purple),
            ),
            const SizedBox(width: 12),
            Text(
              language.tr('company_statistics'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(language.tr('company_name'), companyName),
            const Divider(),
            _buildStatRow(language.tr('total_jobs'), '${_jobs.length}'),
            _buildStatRow(
              language.tr('active_jobs'),
              activeJobs.toString(),
              color: Colors.green,
            ),
            _buildStatRow(
              language.tr('closed_jobs'),
              closedJobs.toString(),
              color: Colors.red,
            ),
            const Divider(),
            _buildStatRow(
              language.tr('total_applicants'),
              totalApplicants.toString(),
              color: Colors.blue,
            ),
            _buildStatRow(
              language.tr('average_per_job'),
              _jobs.isEmpty
                  ? '0'
                  : (totalApplicants / _jobs.length).toStringAsFixed(1),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(language.tr('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyHeaderCard({
    required String companyName,
    required int activeJobs,
    required int totalApplicants,
  }) {
    final language = context.read<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFF34495E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.business,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      language.tr('welcome_back'),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    Text(
                      companyName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _goToJobsTab,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          activeJobs.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          language.tr('active_jobs'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: _goToApplicationsTab,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          totalApplicants.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          language.tr('total_applicants'),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final user = Provider.of<AuthProvider>(context).user;
    final companyName =
        user?['company_data']?['company_name'] ?? language.tr('company');

    int totalApplicants = 0;
    int activeJobs = 0;

    for (var job in _jobs) {
      if (job['status'] == 'open') activeJobs++;
      totalApplicants += getApplicantsCount(job['applications_count']);
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.grey.shade50, Colors.white],
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _buildCompanyHeaderCard(
              companyName: companyName,
              activeJobs: activeJobs,
              totalApplicants: totalApplicants,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    language.tr('quick_actions'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _buildActionCard(
                        icon: Icons.add_circle_outline,
                        title: language.tr('post_job'),
                        color: Colors.blue,
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PostJobScreen(),
                            ),
                          );
                          if (!context.mounted) return;
                          final dashboard = context
                              .findAncestorStateOfType<
                                _CompanyDashboardState
                              >();
                          dashboard?._handleRouteNavigationResult(result);
                          _loadData(forceRefresh: true);
                        },
                      ),
                      _buildActionCard(
                        icon: Icons.people_outline,
                        title: language.tr('view_jobs'),
                        color: Colors.green,
                        onTap: () {
                          final dashboard = context
                              .findAncestorStateOfType<
                                _CompanyDashboardState
                              >();
                          dashboard?.navigateToTab(1);
                        },
                      ),
                      _buildActionCard(
                        icon: Icons.search,
                        title: language.tr('find_talent'),
                        color: Colors.orange,
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                language.tr('find_talent_coming_soon'),
                              ),
                              backgroundColor: Colors.orange,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                      _buildActionCard(
                        icon: Icons.analytics,
                        title: language.tr('statistics'),
                        color: Colors.purple,
                        onTap: () {
                          _showStatsDialog(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        language.tr('recent_job_postings'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final dashboard = context
                              .findAncestorStateOfType<
                                _CompanyDashboardState
                              >();
                          dashboard?.navigateToTab(1);
                        },
                        child: Text('${language.tr('view_all')} ->'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _jobs.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(40),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.work_off,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(language.tr('no_jobs_posted_yet')),
                              Text(language.tr('click_create_first_job')),
                            ],
                          ),
                        )
                      : Column(
                          children: _jobs.take(3).map((job) {
                            return _buildJobCard(job);
                          }).toList(),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardWidth = ((MediaQuery.of(context).size.width - 44) / 2)
        .clamp(120.0, 220.0)
        .toDouble();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              blurRadius: 4,
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
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(dynamic job) {
    final language = context.read<LanguageProvider>();
    final deadlineText = getDaysLeft(job['application_deadline'], language);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C3E50).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.work,
                  color: const Color(0xFF2C3E50),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job['title'],
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job['location'] ?? language.tr('location_not_specified'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: job['status'] == 'open'
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  formatCompanyStatus('${job['status'] ?? 'closed'}', language),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: job['status'] == 'open'
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildInfoBadge(
                icon: Icons.people,
                label: language.tr('applicants_count', {
                  'count': '${getApplicantsCount(job['applications_count'])}',
                }),
                color: Colors.blue,
              ),
              const SizedBox(width: 10),
              _buildInfoBadge(
                icon: Icons.groups,
                label: language.tr('needed_count', {
                  'count': '${getApplicantsCount(job['required_applicants'])}',
                }),
                color: Colors.teal,
              ),
              const SizedBox(width: 10),
              _buildInfoBadge(
                icon: Icons.access_time,
                label: deadlineText,
                color:
                    deadlineText == language.tr('expired') ||
                        deadlineText == language.tr('invalid_date')
                    ? Colors.red
                    : Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  _showJobDetailsDialog(context, job);
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  minimumSize: const Size(80, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  language.tr('details'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () {
                  context
                      .findAncestorStateOfType<_CompanyDashboardState>()
                      ?.navigateToTab(
                        2,
                        jobId: '${job['job_id']}',
                        jobTitle: '${job['title']}',
                      );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2C3E50),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  minimumSize: const Size(90, 38),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  language.tr('view_jobs'),
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class CompanyJobsScreen extends StatefulWidget {
  final void Function(String jobId, String jobTitle) selectJob;

  const CompanyJobsScreen({super.key, required this.selectJob});

  @override
  State<CompanyJobsScreen> createState() => _CompanyJobsScreenState();
}

class _CompanyJobsScreenState extends State<CompanyJobsScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _jobs = [];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs({bool forceRefresh = false}) async {
    final language = context.read<LanguageProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getCompanyJobs(
        forceRefresh: forceRefresh,
      );
      if (response['success'] == true) {
        setState(() {
          _jobs = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              response['message']?.toString() ??
              language.tr('failed_to_load_jobs');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openPostJob({Map<String, dynamic>? job}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PostJobScreen(
          jobId: job?['job_id']?.toString(),
          initialJobData: job,
        ),
      ),
    );
    if (!mounted) return;
    final dashboard = context.findAncestorStateOfType<_CompanyDashboardState>();
    dashboard?._handleRouteNavigationResult(result);
    _loadJobs(forceRefresh: true);
  }

  void _goToApplicationsTab() {
    final dashboard = context.findAncestorStateOfType<_CompanyDashboardState>();
    dashboard?.navigateToTab(2);
  }

  Widget _buildTopNavigationBar() {
    final language = context.read<LanguageProvider>();

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
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: language.tr('my_jobs'),
            icon: Icons.work_rounded,
            selected: true,
            onTap: () {},
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: language.tr('applications'),
            icon: Icons.groups_rounded,
            selected: false,
            onTap: _goToApplicationsTab,
            color: const Color(0xFF2C3E50),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final isActive = status == 'open';
    final language = context.read<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        formatCompanyStatus(status, language),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _buildJobsList() {
    final language = context.read<LanguageProvider>();
    if (_jobs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(language.tr('no_jobs_posted_yet')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PostJobScreen()),
                  );
                  if (!mounted) return;
                  final dashboard = context
                      .findAncestorStateOfType<_CompanyDashboardState>();
                  dashboard?._handleRouteNavigationResult(result);
                  _loadJobs(forceRefresh: true);
                },
                icon: const Icon(Icons.add),
                label: Text(language.tr('post_job')),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadJobs(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _jobs.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openPostJob(),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(language.tr('post_job')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _loadJobs(forceRefresh: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(language.tr('refresh_unread_count')),
                    ),
                  ),
                ],
              ),
            );
          }

          final job = _jobs[index - 1];
          final title = '${job['title'] ?? language.tr('untitled_job')}';
          final jobId = '${job['job_id']}';
          final applicants = getApplicantsCount(job['applications_count']);
          final requiredApplicants = getApplicantsCount(
            job['required_applicants'],
          );

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      _buildStatusChip('${job['status'] ?? 'closed'}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${job['location'] ?? language.tr('location_not_specified')}',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (job['target_candidates'] as List? ?? []).map((
                      target,
                    ) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          formatTargetAudience('$target', language),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 10,
                    spacing: 10,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.42,
                        ),
                        child: Text(
                          '${language.tr('applicants_count', {'count': '$applicants'})} • ${language.tr('needed_count', {'count': '$requiredApplicants'})}',
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: () => _openPostJob(job: job),
                            child: Text(language.tr('edit_job')),
                          ),
                          ElevatedButton(
                            onPressed: () => widget.selectJob(jobId, title),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2C3E50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(language.tr('applications')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _loadJobs(forceRefresh: true),
                child: Text(language.tr('try_again')),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildTopNavigationBar(),
        Expanded(child: _buildJobsList()),
      ],
    );
  }
}

class CompanyApplicationsTab extends StatefulWidget {
  final String? jobId;
  final String? jobTitle;
  final VoidCallback? onGoToJobs;

  const CompanyApplicationsTab({
    super.key,
    required this.jobId,
    required this.jobTitle,
    this.onGoToJobs,
  });

  @override
  State<CompanyApplicationsTab> createState() => _CompanyApplicationsTabState();
}

class _CompanyApplicationsTabState extends State<CompanyApplicationsTab> {
  final ApiService _apiService = ApiService();
  bool _isLoading = false;
  String? _error;
  List<dynamic> _applications = [];

  String _formatErrorMessage(Object error) {
    final language = context.read<LanguageProvider>();
    final message = error.toString().replaceFirst('Exception: ', '');
    if (message.toLowerCase().contains('network')) {
      return language.tr('network_error');
    }
    return message;
  }

  String _resolveFileUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '${_apiService.baseUrl}$normalized';
  }

  Future<void> _openFileUrl(
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

  Future<_PickedPdfFile?> _pickPdfFile({required String emptyMessage}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: kIsWeb,
    );

    if (!mounted || result == null) return null;

    final file = result.files.single;
    final filePath = file.path;
    final fileBytes = file.bytes;

    if ((filePath == null || filePath.isEmpty) && fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(emptyMessage), backgroundColor: Colors.red),
      );
      return null;
    }

    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PDF must be 5MB or less.'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }

    return _PickedPdfFile(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: file.name,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  @override
  void didUpdateWidget(covariant CompanyApplicationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.jobId != widget.jobId ||
        oldWidget.jobTitle != widget.jobTitle) {
      _loadApplications();
    }
  }

  bool get _showAllApplications => widget.jobId == null;

  int _countByStatus(String status) {
    return _applications
        .where((app) => '${app['status'] ?? 'pending'}' == status)
        .length;
  }

  Future<void> _loadApplications() async {
    final language = context.read<LanguageProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = _showAllApplications
          ? await _apiService.getCompanyApplications()
          : await _apiService.getJobApplications(widget.jobId!);

      if (response['success'] == true) {
        setState(() {
          _applications = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              response['message']?.toString() ??
              language.tr('failed_to_load_applications');
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = _formatErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<DateTime?> _pickInterviewDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
    );
    if (pickedDate == null) return null;
    if (!mounted) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  String _formatDateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  Future<String?> _promptForVenue() async {
    return showDialog<String>(
      context: context,
      builder: (_) => const _InterviewVenueDialog(),
    );
  }

  Future<Map<String, String>?> _collectReportingDates() async {
    final language = context.read<LanguageProvider>();
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: language.tr('select_reporting_start_date'),
    );
    if (startDate == null || !mounted) return null;

    final endDate = await showDatePicker(
      context: context,
      initialDate: startDate.add(const Duration(days: 1)),
      firstDate: startDate,
      lastDate: DateTime(now.year + 3),
      helpText: language.tr('select_reporting_end_date'),
    );
    if (endDate == null) return null;

    return {
      'reporting_start_date': _formatDateOnly(startDate),
      'reporting_end_date': _formatDateOnly(endDate),
    };
  }

  Widget _buildAcceptanceLetterInput({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Future<Map<String, String>?> _collectAcceptanceLetterData(
    Map<String, dynamic> application,
  ) async {
    final studentName =
        application['full_name']?.toString() ??
        application['student_name']?.toString() ??
        'the student';
    final jobTitle = application['job_title']?.toString() ?? 'this position';
    final companyAssets =
        context.read<AuthProvider>().user?['company_data']
            as Map<String, dynamic>?;
    final hasDigitalStamp = '${companyAssets?['stamp_url'] ?? ''}'
        .trim()
        .isNotEmpty;
    final hasDigitalSignature = '${companyAssets?['signature_url'] ?? ''}'
        .trim()
        .isNotEmpty;
    return showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _AcceptanceLetterDialog(
        initialOrganizationName: application['company_name']?.toString() ?? '',
        initialCollegeName: 'College of Informatics and Virtual Education',
        initialLetterDate: _formatDateOnly(DateTime.now()),
        studentName: studentName,
        jobTitle: jobTitle,
        hasDigitalStamp: hasDigitalStamp,
        hasDigitalSignature: hasDigitalSignature,
        buildInput: _buildAcceptanceLetterInput,
      ),
    );
  }

  Future<void> _scheduleInterview(String applicationId) async {
    final selectedDateTime = await _pickInterviewDateTime();
    if (selectedDateTime == null || !mounted) return;
    final interviewVenue = await _promptForVenue();
    if (interviewVenue == null || interviewVenue.isEmpty) return;
    await _updateStatus(
      applicationId,
      'interview',
      interviewDate: selectedDateTime.toIso8601String(),
      interviewVenue: interviewVenue,
    );
  }

  Future<void> _acceptApplicant(Map<String, dynamic> application) async {
    final applicationId = '${application['application_id'] ?? ''}';
    if (applicationId.isEmpty) return;

    final reportingDates = await _collectReportingDates();
    if (reportingDates == null) return;
    final acceptanceLetterData = await _collectAcceptanceLetterData(
      application,
    );
    if (acceptanceLetterData == null) return;

    await _updateStatus(
      applicationId,
      'accepted',
      reportingStartDate: reportingDates['reporting_start_date'],
      reportingEndDate: reportingDates['reporting_end_date'],
      acceptanceLetterData: acceptanceLetterData,
    );
  }

  Future<void> _rejectApplicant(String applicationId) async {
    final responseLetter = await _pickPdfFile(
      emptyMessage: 'Unable to read the selected response letter PDF.',
    );
    if (responseLetter == null || !mounted) return;

    final feedbackController = TextEditingController();
    try {
      final feedback = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rejection Notes'),
          content: TextField(
            controller: feedbackController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Feedback',
              hintText: 'Optional explanation for the student',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, feedbackController.text),
              child: const Text('Continue'),
            ),
          ],
        ),
      );

      if (!mounted || feedback == null) return;
      await _updateStatus(
        applicationId,
        'rejected',
        feedback: feedback.trim(),
        responseLetter: responseLetter,
      );
    } finally {
      feedbackController.dispose();
    }
  }

  Future<void> _reviewSupportiveDocument(
    String applicationId, {
    required bool isAuthentic,
  }) async {
    final notesController = TextEditingController();
    try {
      final notes = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            isAuthentic ? 'Verify as Authentic' : 'Mark as Not Authentic',
          ),
          content: TextField(
            controller: notesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Review notes',
              hintText: isAuthentic
                  ? 'Optional note about the verified document'
                  : 'Explain why the document is not authentic',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, notesController.text),
              child: const Text('Save Review'),
            ),
          ],
        ),
      );

      if (notes == null) return;

      final response = await _apiService.reviewApplicationDocument(
        applicationId: applicationId,
        isAuthentic: isAuthentic,
        verificationNotes: notes,
      );

      if (!mounted) return;
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ?? 'Document reviewed',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadApplications();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ??
                  'Failed to review supportive document',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      notesController.dispose();
    }
  }

  Future<void> _updateStatus(
    String applicationId,
    String status, {
    String? feedback,
    String? interviewDate,
    String? interviewVenue,
    String? reportingStartDate,
    String? reportingEndDate,
    Map<String, dynamic>? acceptanceLetterData,
    _PickedPdfFile? responseLetter,
  }) async {
    final language = context.read<LanguageProvider>();
    try {
      final response = await _apiService.updateApplicationStatusWithLetter(
        applicationId: applicationId,
        status: status,
        feedback: feedback,
        interviewDate: interviewDate,
        interviewVenue: interviewVenue,
        reportingStartDate: reportingStartDate,
        reportingEndDate: reportingEndDate,
        acceptanceLetterData: acceptanceLetterData,
        responseLetterPath: responseLetter?.filePath,
        responseLetterBytes: responseLetter?.fileBytes,
        responseLetterName: responseLetter?.fileName,
      );

      if (response['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              language.tr('application_updated_to', {
                'status': formatApplicationStatus(status, language),
              }),
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadApplications();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ??
                  language.tr('failed_to_update_status'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_formatErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'shortlisted':
        return const Color(0xFF5C7FA3);
      case 'interview':
        return const Color(0xFF7D6AA8);
      case 'accepted':
        return const Color(0xFF5D8D73);
      case 'rejected':
        return const Color(0xFFB26B6B);
      default:
        return const Color(0xFFB38A45);
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'shortlisted':
        return const Color(0xFFEAF1F7);
      case 'interview':
        return const Color(0xFFF1ECF8);
      case 'accepted':
        return const Color(0xFFEAF4EE);
      case 'rejected':
        return const Color(0xFFF8ECEC);
      default:
        return const Color(0xFFF8F1E3);
    }
  }

  bool _hasReachedStatus(String currentStatus, String targetStatus) {
    const order = ['pending', 'shortlisted', 'interview', 'accepted'];
    final currentIndex = order.indexOf(currentStatus);
    final targetIndex = order.indexOf(targetStatus);
    if (currentStatus == 'rejected') return false;
    if (currentIndex == -1 || targetIndex == -1) return false;
    return currentIndex >= targetIndex;
  }

  Widget _buildActionButton({
    required String label,
    required Color color,
    required bool isActive,
    required bool isEnabled,
    required VoidCallback? onPressed,
  }) {
    final foreground = isEnabled || isActive ? color : Colors.grey.shade500;
    final background = isActive
        ? color.withValues(alpha: 0.14)
        : (isEnabled ? Colors.white : Colors.grey.shade100);

    return OutlinedButton(
      onPressed: isEnabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: foreground,
        backgroundColor: background,
        side: BorderSide(
          color: isEnabled || isActive
              ? color.withValues(alpha: 0.55)
              : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 0,
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
    final language = context.read<LanguageProvider>();
    final total = _applications.length;
    final shortlisted = _countByStatus('shortlisted');
    final interviewed = _countByStatus('interview');
    final accepted = _countByStatus('accepted');
    final rejected = _countByStatus('rejected');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(language.tr('applications_summary')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSummaryLine(language.tr('total'), total.toString()),
            _buildSummaryLine(
              language.tr('shortlisted'),
              shortlisted.toString(),
            ),
            _buildSummaryLine(
              language.tr('interviewed'),
              interviewed.toString(),
            ),
            _buildSummaryLine(language.tr('accepted'), accepted.toString()),
            _buildSummaryLine(language.tr('rejected'), rejected.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(language.tr('close')),
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

  void _showAllApplicationsFromTop() {
    final dashboard = context.findAncestorStateOfType<_CompanyDashboardState>();
    dashboard?.navigateToTab(2);
  }

  Widget _buildTopNavigationBar() {
    final language = context.read<LanguageProvider>();

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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: _showAllApplications
                ? language.tr('all_applications')
                : language.tr('this_job'),
            icon: Icons.grid_view_rounded,
            selected: true,
            onTap: () {
              if (!_showAllApplications) {
                _showAllApplicationsFromTop();
              }
            },
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: language.tr('my_jobs'),
            icon: Icons.work_outline_rounded,
            selected: false,
            onTap: () => widget.onGoToJobs?.call(),
            color: const Color(0xFF2C3E50),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
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
    );
  }

  Widget _buildApplicationCard(dynamic app) {
    final language = context.read<LanguageProvider>();
    final fullName = '${app['full_name'] ?? language.tr('unknown_applicant')}';
    final email = '${app['email'] ?? language.tr('no_email')}';
    final status = '${app['status'] ?? 'pending'}';
    final statusColor = _statusColor(status);
    final applicationId = '${app['application_id']}';
    final jobTitle =
        '${app['job_title'] ?? widget.jobTitle ?? language.tr('selected_job')}';
    final supportiveDocumentUrl = app['supportive_document_url']?.toString();
    final supportiveDocumentName =
        app['supportive_document_name']?.toString() ??
        'supportive_document.pdf';
    final responseLetterUrl = app['response_letter_url']?.toString();
    final responseLetterName =
        app['response_letter_name']?.toString() ?? 'response_letter.pdf';
    final verificationNotes = app['supportive_document_verification_notes']
        ?.toString();
    final documentReviewed = app['supportive_document_verified'] != null;
    final isDocumentAuthentic = app['supportive_document_verified'] == true;
    final canShortlist = status == 'pending' && isDocumentAuthentic;
    final canInterview = status == 'shortlisted' && isDocumentAuthentic;
    final canAccept = status == 'interview' && isDocumentAuthentic;
    final canReject =
        (status == 'pending' ||
            status == 'shortlisted' ||
            status == 'interview') &&
        documentReviewed;
    final reviewLabel = !documentReviewed
        ? 'Pending document review'
        : isDocumentAuthentic
        ? 'Document verified'
        : 'Document not authentic';
    final reviewColor = !documentReviewed
        ? const Color(0xFFB38A45)
        : isDocumentAuthentic
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        email,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBackground(status),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatApplicationStatus(status, language),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              language.tr('university_value', {
                'value': '${app['university_name'] ?? 'N/A'}',
              }),
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 4),
            Text(
              language.tr('job_value', {'value': jobTitle}),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: reviewColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: reviewColor.withValues(alpha: 0.24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_outlined,
                        size: 18,
                        color: reviewColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          reviewLabel,
                          style: TextStyle(
                            color: reviewColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Supportive PDF: $supportiveDocumentName',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                  ),
                  if (verificationNotes != null &&
                      verificationNotes.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Review notes: $verificationNotes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _openFileUrl(
                          supportiveDocumentUrl,
                          invalidMessage:
                              'Supportive document link is invalid.',
                          failureMessage: 'Unable to open supportive document.',
                        ),
                        icon: const Icon(Icons.open_in_new, size: 16),
                        label: const Text('Open PDF'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _reviewSupportiveDocument(
                          applicationId,
                          isAuthentic: true,
                        ),
                        icon: const Icon(Icons.check_circle_outline, size: 16),
                        label: const Text('Authentic'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _reviewSupportiveDocument(
                          applicationId,
                          isAuthentic: false,
                        ),
                        icon: const Icon(Icons.gpp_bad_outlined, size: 16),
                        label: const Text('Not Authentic'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (responseLetterUrl != null && responseLetterUrl.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFD6E0EA)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Response letter: $responseLetterName',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openFileUrl(
                        responseLetterUrl,
                        invalidMessage: 'Response letter link is invalid.',
                        failureMessage: 'Unable to open response letter.',
                      ),
                      child: const Text('Open'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  label: language.tr('shortlist'),
                  color: Colors.blue,
                  isActive: _hasReachedStatus(status, 'shortlisted'),
                  isEnabled: canShortlist,
                  onPressed: () => _updateStatus(applicationId, 'shortlisted'),
                ),
                _buildActionButton(
                  label: language.tr('interview'),
                  color: Colors.purple,
                  isActive: _hasReachedStatus(status, 'interview'),
                  isEnabled: canInterview,
                  onPressed: () => _scheduleInterview(applicationId),
                ),
                _buildActionButton(
                  label: language.tr('accept'),
                  color: Colors.green,
                  isActive: status == 'accepted',
                  isEnabled: canAccept,
                  onPressed: () => _acceptApplicant(app),
                ),
                _buildActionButton(
                  label: language.tr('reject'),
                  color: Colors.red,
                  isActive: status == 'rejected',
                  isEnabled: canReject,
                  onPressed: () => _rejectApplicant(applicationId),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadApplications,
                child: Text(language.tr('try_again')),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApplications,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2C3E50),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.assignment_ind, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _showAllApplications
                        ? language.tr('all_company_applications')
                        : language.tr('applications_for_job', {
                            'job':
                                widget.jobTitle ?? language.tr('selected_job'),
                          }),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadApplications,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
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
                  label: Text(language.tr('statistics')),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadApplications,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(language.tr('refresh_unread_count')),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final cards = [
                _buildSummaryCard(
                  label: language.tr('total'),
                  value: '${_applications.length}',
                  icon: Icons.groups_2_outlined,
                  color: const Color(0xFF2C3E50),
                ),
                _buildSummaryCard(
                  label: language.tr('interviewed'),
                  value: '${_countByStatus('interview')}',
                  icon: Icons.event_available_outlined,
                  color: Colors.purple,
                ),
                _buildSummaryCard(
                  label: language.tr('accepted'),
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
          const SizedBox(height: 14),
          if (_applications.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _showAllApplications
                        ? language.tr('no_applications_for_jobs_yet')
                        : language.tr('no_applications_for_this_job_yet'),
                  ),
                  if (_showAllApplications) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: widget.onGoToJobs,
                      child: Text(language.tr('go_to_my_jobs')),
                    ),
                  ],
                ],
              ),
            ),
          ..._applications.map(_buildApplicationCard),
        ],
      ),
    );
  }
}

class _AcceptanceLetterDialog extends StatefulWidget {
  final String initialOrganizationName;
  final String initialCollegeName;
  final String initialLetterDate;
  final String studentName;
  final String jobTitle;
  final bool hasDigitalStamp;
  final bool hasDigitalSignature;
  final _AcceptanceInputBuilder buildInput;

  const _AcceptanceLetterDialog({
    required this.initialOrganizationName,
    required this.initialCollegeName,
    required this.initialLetterDate,
    required this.studentName,
    required this.jobTitle,
    required this.hasDigitalStamp,
    required this.hasDigitalSignature,
    required this.buildInput,
  });

  @override
  State<_AcceptanceLetterDialog> createState() =>
      _AcceptanceLetterDialogState();
}

class _AcceptanceLetterDialogState extends State<_AcceptanceLetterDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _organizationNameController;
  late final TextEditingController _registrationNumberController;
  late final TextEditingController _collegeNameController;
  late final TextEditingController _sectionDepartmentController;
  late final TextEditingController _officerNameController;
  late final TextEditingController _officerDesignationController;
  late final TextEditingController _officerPhoneController;
  late final TextEditingController _officerEmailController;
  late final TextEditingController _officerRegionController;
  late final TextEditingController _officerDistrictController;
  late final TextEditingController _officerAreaController;
  late final TextEditingController _letterDateController;

  @override
  void initState() {
    super.initState();
    _organizationNameController = TextEditingController(
      text: widget.initialOrganizationName,
    );
    _registrationNumberController = TextEditingController();
    _collegeNameController = TextEditingController(
      text: widget.initialCollegeName,
    );
    _sectionDepartmentController = TextEditingController();
    _officerNameController = TextEditingController();
    _officerDesignationController = TextEditingController();
    _officerPhoneController = TextEditingController();
    _officerEmailController = TextEditingController();
    _officerRegionController = TextEditingController();
    _officerDistrictController = TextEditingController();
    _officerAreaController = TextEditingController();
    _letterDateController = TextEditingController(
      text: widget.initialLetterDate,
    );
  }

  @override
  void dispose() {
    _organizationNameController.dispose();
    _registrationNumberController.dispose();
    _collegeNameController.dispose();
    _sectionDepartmentController.dispose();
    _officerNameController.dispose();
    _officerDesignationController.dispose();
    _officerPhoneController.dispose();
    _officerEmailController.dispose();
    _officerRegionController.dispose();
    _officerDistrictController.dispose();
    _officerAreaController.dispose();
    _letterDateController.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    Navigator.of(context).pop({
      'organization_name': _organizationNameController.text.trim(),
      'student_registration_number': _registrationNumberController.text.trim(),
      'college_name': _collegeNameController.text.trim(),
      'section_department': _sectionDepartmentController.text.trim(),
      'officer_name': _officerNameController.text.trim(),
      'officer_designation': _officerDesignationController.text.trim(),
      'officer_phone': _officerPhoneController.text.trim(),
      'officer_email': _officerEmailController.text.trim(),
      'officer_region': _officerRegionController.text.trim(),
      'officer_district': _officerDistrictController.text.trim(),
      'officer_area': _officerAreaController.text.trim(),
      'letter_date': _letterDateController.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final buildInput = widget.buildInput;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: screenSize.height * 0.86,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Acceptance Letter Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fill in the response letter details for ${widget.studentName} (${widget.jobTitle}).',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.hasDigitalStamp || widget.hasDigitalSignature
                              ? 'Saved company stamp/signature will be inserted automatically where available.'
                              : 'No digital stamp or signature uploaded yet. The PDF will keep manual spaces for stamping and signing.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 16),
                        buildInput(
                          controller: _organizationNameController,
                          label: 'Organization / Institution',
                          hint: 'Example: ABC Company Limited',
                        ),
                        buildInput(
                          controller: _registrationNumberController,
                          label: 'Student Registration Number',
                          hint: 'Example: UDOM/2023/12345',
                        ),
                        buildInput(
                          controller: _collegeNameController,
                          label: 'College Name',
                        ),
                        buildInput(
                          controller: _sectionDepartmentController,
                          label: 'Section / Department',
                          hint: 'Example: ICT Department',
                        ),
                        buildInput(
                          controller: _officerNameController,
                          label: 'Authorizing Officer Name',
                        ),
                        buildInput(
                          controller: _officerDesignationController,
                          label: 'Officer Designation',
                        ),
                        buildInput(
                          controller: _officerPhoneController,
                          label: 'Officer Phone Number',
                          keyboardType: TextInputType.phone,
                        ),
                        buildInput(
                          controller: _officerEmailController,
                          label: 'Officer Email Address',
                          keyboardType: TextInputType.emailAddress,
                        ),
                        buildInput(
                          controller: _officerRegionController,
                          label: 'Region',
                        ),
                        buildInput(
                          controller: _officerDistrictController,
                          label: 'District',
                        ),
                        buildInput(
                          controller: _officerAreaController,
                          label: 'Area / Physical Address',
                          hint: 'Example: Mtumba, Dodoma',
                        ),
                        buildInput(
                          controller: _letterDateController,
                          label: 'Letter Date',
                          hint: 'YYYY-MM-DD',
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _submit,
                      child: const Text('Generate Letter'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InterviewVenueDialog extends StatefulWidget {
  const _InterviewVenueDialog();

  @override
  State<_InterviewVenueDialog> createState() => _InterviewVenueDialogState();
}

class _InterviewVenueDialogState extends State<_InterviewVenueDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final language = context.read<LanguageProvider>();
    final venue = _controller.text.trim();
    if (venue.isEmpty) {
      setState(() {
        _errorText = language.tr('venue_required');
      });
      return;
    }

    Navigator.of(context).pop(venue);
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      scrollable: true,
      title: Text(language.tr('interview_venue')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: TextField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          maxLines: 2,
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            labelText: language.tr('venue_hall'),
            hintText: language.tr('venue_hint'),
            errorText: _errorText,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(language.tr('cancel')),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(language.tr('continue')),
        ),
      ],
    );
  }
}

class CompanyProfileScreen extends StatelessWidget {
  const CompanyProfileScreen({super.key});

  Widget _buildTopNavigationBar(BuildContext context) {
    final language = context.read<LanguageProvider>();
    final dashboard = context.findAncestorStateOfType<_CompanyDashboardState>();

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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: language.tr('home'),
            icon: Icons.dashboard_rounded,
            selected: false,
            onTap: () => dashboard?.navigateToTab(0),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: language.tr('my_jobs'),
            icon: Icons.work_rounded,
            selected: false,
            onTap: () => dashboard?.navigateToTab(1),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: language.tr('applications'),
            icon: Icons.groups_rounded,
            selected: false,
            onTap: () => dashboard?.navigateToTab(2),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: language.tr('profile'),
            icon: Icons.business_rounded,
            selected: true,
            onTap: () {},
            color: const Color(0xFF2C3E50),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String value,
  }) {
    final language = context.read<LanguageProvider>();
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2C3E50)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  value.isEmpty ? language.tr('not_provided') : value,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final user = Provider.of<AuthProvider>(context).user;
    final company = user?['company_data'] ?? {};
    final companyName = '${company['company_name'] ?? language.tr('company')}';
    final rawLogoUrl = company['logo_url']?.toString();
    final logoUrl = rawLogoUrl == null || rawLogoUrl.isEmpty
        ? null
        : (rawLogoUrl.startsWith('http://') || rawLogoUrl.startsWith('https://')
              ? rawLogoUrl
              : '${ApiService().baseUrl}$rawLogoUrl');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTopNavigationBar(context),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: const Color(
                    0xFF2C3E50,
                  ).withValues(alpha: 0.1),
                  backgroundImage: logoUrl != null && logoUrl.isNotEmpty
                      ? NetworkImage(logoUrl)
                      : null,
                  child: logoUrl == null || logoUrl.isEmpty
                      ? Text(
                          companyName.isNotEmpty
                              ? companyName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2C3E50),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  companyName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${company['industry'] ?? language.tr('industry_not_set')}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EditCompanyProfileScreen(),
                        ),
                      );
                      if (!context.mounted) return;
                      final dashboard = context
                          .findAncestorStateOfType<_CompanyDashboardState>();
                      dashboard?._handleRouteNavigationResult(result);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2C3E50),
                    ),
                    icon: const Icon(Icons.edit),
                    label: Text(language.tr('edit_profile')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final changed = await showChangePinDialog(context);
                      if (!context.mounted || changed != true) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            language.tr('pin_updated_successfully'),
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2C3E50),
                      side: const BorderSide(color: Color(0xFF2C3E50)),
                    ),
                    icon: const Icon(Icons.pin_outlined),
                    label: Text(language.tr('change_pin')),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final email = user?['email']?.toString() ?? '';
                      if (email.isEmpty) return;
                      final changed = await showResetPinDialog(
                        context,
                        email: email,
                      );
                      if (!context.mounted || changed != true) return;
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange.shade800,
                      side: BorderSide(color: Colors.orange.shade400),
                    ),
                    icon: const Icon(Icons.lock_reset_rounded),
                    label: Text(language.tr('reset_pin')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            context: context,
            icon: Icons.location_on_outlined,
            label: language.tr('location'),
            value: '${company['location'] ?? ''}',
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.language_outlined,
            label: language.tr('website'),
            value: '${company['website_url'] ?? ''}',
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.groups_outlined,
            label: language.tr('company_size'),
            value: '${company['company_size'] ?? ''}',
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.email_outlined,
            label: language.tr('email'),
            value: '${user?['email'] ?? ''}',
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.phone_outlined,
            label: language.tr('phone'),
            value: '${user?['phone'] ?? ''}',
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${company['description'] ?? language.tr('no_company_description_added_yet')}',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
