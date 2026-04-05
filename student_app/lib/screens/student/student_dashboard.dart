import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/role_theme.dart';
import '../../widgets/language_picker_dialog.dart';
import 'browse_jobs_screen.dart';
import 'job_details_screen.dart';
import 'my_applications_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import '../auth/login_screen.dart';

enum _StudentMoreAction { settings, language, logout }

const Color _studentBrandPrimary = StudentRoleTheme.primary;
const Color _studentBrandSurface = StudentRoleTheme.surface;
const Color _studentBrandBorder = StudentRoleTheme.border;

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentTabState {
  final int index;
  final String applicationsFilter;

  const _StudentTabState({
    required this.index,
    required this.applicationsFilter,
  });
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _currentIndex = 0;
  final ApiService _apiService = ApiService();
  int _unreadNotifications = 0;
  String _applicationsFilter = 'all';
  int _homeRefreshToken = 0;
  int _applicationsRefreshToken = 0;
  final List<_StudentTabState> _tabHistory = [];

  String _formatToday() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];

    final now = DateTime.now();
    final weekday = weekdays[now.weekday - 1];
    final month = months[now.month - 1];
    return '$weekday, ${now.day} $month ${now.year}';
  }

  List<Widget> _buildScreens() {
    return [
      HomeScreen(refreshToken: _homeRefreshToken),
      const BrowseJobsScreen(),
      MyApplicationsScreen(
        key: ValueKey(_applicationsFilter),
        initialFilter: _applicationsFilter,
        refreshToken: _applicationsRefreshToken,
      ),
      const ProfileScreen(),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabHistory.add(
      _StudentTabState(
        index: _currentIndex,
        applicationsFilter: _applicationsFilter,
      ),
    );
    _loadUnreadNotifications();
  }

  void _navigateToTab(int index, {String? applicationsFilter}) {
    final nextFilter = index == 2
        ? (applicationsFilter ?? 'all')
        : _applicationsFilter;
    final shouldRefreshHome = index == 0;
    final shouldRefreshApplications = index == 2;

    setState(() {
      final currentState = _tabHistory.isNotEmpty ? _tabHistory.last : null;
      final nextState = _StudentTabState(
        index: index,
        applicationsFilter: nextFilter,
      );

      if (currentState == null ||
          currentState.index != nextState.index ||
          currentState.applicationsFilter != nextState.applicationsFilter) {
        _tabHistory.add(nextState);
      }

      _currentIndex = index;
      if (shouldRefreshHome) {
        _homeRefreshToken++;
      }
      if (index == 2) {
        _applicationsFilter = nextFilter;
        if (shouldRefreshApplications) {
          _applicationsRefreshToken++;
        }
      }
    });
  }

  void _switchTab(int index) {
    _navigateToTab(index);
  }

  void _openApplicationsWithFilter(String filter) {
    _navigateToTab(2, applicationsFilter: filter);
  }

  bool _handleBackPress() {
    if (_tabHistory.length > 1) {
      final previousState = _tabHistory[_tabHistory.length - 2];
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = previousState.index;
        _applicationsFilter = previousState.applicationsFilter;
      });
      return false;
    }

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _applicationsFilter = 'all';
        _tabHistory
          ..clear()
          ..add(const _StudentTabState(index: 0, applicationsFilter: 'all'));
      });
      return false;
    }

    return true;
  }

  Future<void> _loadUnreadNotifications({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.getUnreadNotificationCount(
        forceRefresh: forceRefresh,
      );
      if (response['success'] == true) {
        final rawCount = response['data']?['count'];
        final count = rawCount is int
            ? rawCount
            : int.tryParse('$rawCount') ?? 0;
        if (mounted) {
          setState(() => _unreadNotifications = count);
        }
      }
    } catch (e) {
      // Ignore errors; badge can stay hidden.
    }
  }

  void _showTopSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 100,
          left: 16,
          right: 16,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final language = context.read<LanguageProvider>();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.tr('logout_title')),
        content: Text(language.tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              language.tr('logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirmed == true) {
      await authProvider.logout();
      if (!mounted) return;
      _showTopSnackBar(language.tr('logout_success'), Colors.green);
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
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
    _showTopSnackBar(
      updatedLanguage.tr('language_changed_to', {
        'language': updatedLanguage.nativeLanguageName(selectedLanguage),
      }),
      Colors.green,
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
                  language.tr('student_settings'),
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
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(language.tr('notifications')),
                  subtitle: Text(language.tr('open_your_notifications')),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                    _loadUnreadNotifications(forceRefresh: true);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.assignment_outlined),
                  title: Text(language.tr('my_applications')),
                  subtitle: Text(language.tr('open_applications_tab')),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _navigateToTab(2, applicationsFilter: 'all');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMoreAction(_StudentMoreAction action) async {
    switch (action) {
      case _StudentMoreAction.settings:
        await _showSettingsSheet();
        break;
      case _StudentMoreAction.language:
        await _showLanguageDialog();
        break;
      case _StudentMoreAction.logout:
        await _logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final user = Provider.of<AuthProvider>(context).user;
    final fullName = user?['full_name'] ?? language.tr('student');
    final email = user?['email'] ?? 'student@example.com';
    final firstName = fullName.split(' ')[0];
    final today = _formatToday();

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
        backgroundColor: Colors.grey.shade50,
        appBar: AppBar(
          backgroundColor: _studentBrandSurface,
          elevation: 0,
          titleSpacing: 8,
          title: Row(
            children: [
              // Logo kubwa - 55x55
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
                        color: _studentBrandPrimary,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
          actions: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.notifications_outlined,
                    color: _studentBrandPrimary,
                    size: 24,
                  ),
                  tooltip: language.tr('notifications'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                    _loadUnreadNotifications(forceRefresh: true);
                  },
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
            PopupMenuButton<_StudentMoreAction>(
              tooltip: language.tr('more_actions'),
              onSelected: _handleMoreAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _StudentMoreAction.settings,
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(language.tr('settings')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _StudentMoreAction.language,
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
                  value: _StudentMoreAction.logout,
                  child: Row(
                    children: [
                      const Icon(Icons.logout_rounded, size: 18),
                      const SizedBox(width: 10),
                      Text(language.tr('logout')),
                    ],
                  ),
                ),
              ],
              icon: const Icon(
                Icons.more_vert_rounded,
                color: _studentBrandPrimary,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        // Second bar - Hello name na email KATIKATI
        body: Column(
          children: [
            // Second bar - Greeting (CENTERED)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _studentBrandSurface,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                ),
              ),
              child: Column(
                children: [
                  // Hello name - katikati
                  Text(
                    language.tr('hello_name', {'name': firstName}),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _studentBrandPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Email - katikati
                  Text(
                    email,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _studentBrandBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: _studentBrandPrimary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          today,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _studentBrandPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Main content
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _buildScreens(),
              ),
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          currentIndex: _currentIndex,
          onTap: _switchTab,
          selectedItemColor: _studentBrandPrimary,
          unselectedItemColor: Colors.grey.shade600,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home_outlined),
              activeIcon: const Icon(Icons.home),
              label: language.tr('home'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.search_outlined),
              activeIcon: const Icon(Icons.search),
              label: language.tr('browse'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.assignment_outlined),
              activeIcon: const Icon(Icons.assignment),
              label: language.tr('my_apps'),
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.person_outline),
              activeIcon: const Icon(Icons.person),
              label: language.tr('profile'),
            ),
          ],
        ),
      ),
    );
  }
}

// HomeScreen
class HomeScreen extends StatefulWidget {
  final int refreshToken;

  const HomeScreen({super.key, this.refreshToken = 0});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService();
  int _applicationsCount = 0;
  int _interviewsCount = 0;
  int _pendingCount = 0;
  int _reviewCount = 0;
  int _profileViewsCount = 0;
  List<Job> _recentJobs = const [];
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadStats();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final user = Provider.of<AuthProvider>(context, listen: false).user;
      final responses = await Future.wait([
        _apiService.getMyApplications(),
        _apiService.getJobs(limit: '100'),
      ]);

      final appsResponse = responses[0];
      final jobsResponse = responses[1];

      int applications = 0;
      int interviews = 0;
      int pending = 0;
      int review = 0;

      if (appsResponse['success'] == true && appsResponse['data'] is List) {
        final apps = appsResponse['data'] as List<dynamic>;
        applications = apps.length;
        interviews = apps.where((app) {
          final status = '${app['status'] ?? ''}'.toLowerCase();
          return status == 'interview';
        }).length;
        pending = apps.where((app) {
          final status = '${app['status'] ?? ''}'.toLowerCase();
          return status == 'pending';
        }).length;
        review = apps.where((app) {
          final status = '${app['status'] ?? ''}'.toLowerCase();
          return status == 'shortlisted' ||
              status == 'review' ||
              status == 'under_review';
        }).length;
      }

      final rawViews = user?['student_data']?['profile_views'];
      final profileViews = rawViews is int
          ? rawViews
          : int.tryParse('$rawViews') ?? 0;
      final recentJobs = _extractRecentJobs(jobsResponse);

      if (mounted) {
        setState(() {
          _applicationsCount = applications;
          _interviewsCount = interviews;
          _pendingCount = pending;
          _reviewCount = review;
          _profileViewsCount = profileViews;
          _recentJobs = recentJobs;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  List<Job> _extractRecentJobs(Map<String, dynamic> response) {
    final data = response['data'];
    if (response['success'] != true || data is! List) {
      return const [];
    }

    final jobs =
        data
            .whereType<Map<String, dynamic>>()
            .map(Job.fromJson)
            .where((job) => job.status == 'open')
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    final seenCompanies = <String>{};
    final recentJobs = <Job>[];

    for (final job in jobs) {
      final companyKey = job.companyId.isNotEmpty
          ? job.companyId
          : job.companyName.toLowerCase();
      if (!seenCompanies.add(companyKey)) {
        continue;
      }

      recentJobs.add(job);
      if (recentJobs.length == 4) {
        break;
      }
    }

    return recentJobs;
  }

  void _goToTab(int index) {
    final dashboard = context.findAncestorStateOfType<_StudentDashboardState>();
    dashboard?._switchTab(index);
  }

  void _goToApplicationsFilter(String filter) {
    final dashboard = context.findAncestorStateOfType<_StudentDashboardState>();
    dashboard?._openApplicationsWithFilter(filter);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stats Cards (5 widgets)
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 24) / 3;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.assignment,
                      'Applications',
                      _isLoadingStats ? '...' : '$_applicationsCount',
                      Colors.blue,
                      () => _goToApplicationsFilter('all'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.calendar_today,
                      'Interviews',
                      _isLoadingStats ? '...' : '$_interviewsCount',
                      Colors.green,
                      () => _goToApplicationsFilter('interview'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.hourglass_empty,
                      'Pending',
                      _isLoadingStats ? '...' : '$_pendingCount',
                      Colors.orange,
                      () => _goToApplicationsFilter('pending'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.rate_review_outlined,
                      'Review',
                      _isLoadingStats ? '...' : '$_reviewCount',
                      Colors.indigo,
                      () => _goToApplicationsFilter('review'),
                    ),
                  ),
                  SizedBox(
                    width: cardWidth,
                    child: _buildStatCard(
                      Icons.visibility,
                      'Profile Views',
                      _isLoadingStats ? '...' : '$_profileViewsCount',
                      Colors.purple,
                      () => _goToTab(3),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          const Text(
            'Recent Posted Jobs',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          if (_isLoadingStats)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
                ],
              ),
              child: const Text(
                'Loading recent jobs...',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else if (_recentJobs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.grey.shade200, blurRadius: 8),
                ],
              ),
              child: const Text(
                'No recent jobs available right now.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._recentJobs.asMap().entries.map((entry) {
              final index = entry.key;
              final job = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _recentJobs.length - 1 ? 0 : 12,
                ),
                child: _buildRecentJobCard(job),
              );
            }),
          const SizedBox(height: 24),

          // Quick Actions
          const Text(
            'Quick Actions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildActionCard(
                  Icons.search,
                  'Browse Jobs',
                  Colors.blue,
                  () => _goToTab(1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActionCard(
                  Icons.person,
                  'My Profile',
                  Colors.green,
                  () => _goToTab(3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    IconData icon,
    String label,
    String value,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 8)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  String _formatRecentPostingTime(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes} min ago';
    if (difference.inDays < 1) return '${difference.inHours} hr ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String _formatJobTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'full-time':
        return 'Full-time';
      case 'part-time':
        return 'Part-time';
      case 'graduate_program':
        return 'Graduate Program';
      case 'internship':
        return 'Internship';
      default:
        return type.isEmpty ? 'Job' : type;
    }
  }

  IconData _recentJobIcon(String type) {
    switch (type.toLowerCase()) {
      case 'full-time':
        return Icons.work;
      case 'part-time':
        return Icons.schedule;
      case 'graduate_program':
        return Icons.rocket_launch_outlined;
      case 'internship':
        return Icons.school_outlined;
      default:
        return Icons.business_center_outlined;
    }
  }

  Widget _buildRecentJobCard(Job job) {
    final typeLabel = _formatJobTypeLabel(job.type);
    final timeLabel = _formatRecentPostingTime(job.createdAt);
    final icon = _recentJobIcon(job.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => JobDetailsScreen(jobId: job.jobId),
            ),
          );
          _loadStats();
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.08),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: _studentBrandPrimary, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      job.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _studentBrandPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      job.companyName,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          job.location,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.access_time,
                          size: 12,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: typeLabel == 'Full-time'
                      ? Colors.green.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: typeLabel == 'Full-time'
                        ? Colors.green.shade700
                        : Colors.blue.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
