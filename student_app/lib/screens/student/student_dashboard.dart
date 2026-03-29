import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/language_picker_dialog.dart';
import 'browse_jobs_screen.dart';
import 'my_applications_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import '../auth/login_screen.dart';

enum _StudentMoreAction { settings, language, logout }

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
          backgroundColor: const Color(0xFFE3F2FD),
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
                        color: Colors.blue,
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
                    color: Color(0xFF1976D2),
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
                color: Color(0xFF1976D2),
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
                color: const Color(0xFFE3F2FD),
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
                      color: Color(0xFF1976D2),
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
                      border: Border.all(color: const Color(0xFF90CAF9)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 15,
                          color: Color(0xFF1976D2),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          today,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1976D2),
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
          selectedItemColor: const Color(0xFF1976D2),
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
  double _skillMatchScore = 0.0;
  String _skillMatchMessage = 'Add your skills to see your market match';
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
        _apiService.getStudentSkills(),
        _apiService.getJobs(limit: '100'),
      ]);

      final appsResponse = responses[0];
      final studentSkillsResponse = responses[1];
      final jobsResponse = responses[2];

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

      final studentSkills = _extractStudentSkillNames(studentSkillsResponse);
      final jobSkillSets = _extractJobSkillSets(jobsResponse);
      final jobsWithSkills = jobSkillSets.length;
      final matchedJobs = jobSkillSets
          .where((requiredSkills) => requiredSkills.any(studentSkills.contains))
          .length;

      final skillMatchScore = jobsWithSkills > 0
          ? matchedJobs / jobsWithSkills
          : 0.0;
      final skillMatchMessage = _buildSkillMatchMessage(
        studentSkillsCount: studentSkills.length,
        jobsWithSkills: jobsWithSkills,
        matchedJobs: matchedJobs,
      );

      if (mounted) {
        setState(() {
          _applicationsCount = applications;
          _interviewsCount = interviews;
          _pendingCount = pending;
          _reviewCount = review;
          _profileViewsCount = profileViews;
          _skillMatchScore = skillMatchScore.clamp(0.0, 1.0);
          _skillMatchMessage = skillMatchMessage;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  Set<String> _extractStudentSkillNames(Map<String, dynamic> response) {
    final data = response['data'];
    if (response['success'] != true || data is! List) {
      return <String>{};
    }

    return data
        .map((item) {
          if (item is Map<String, dynamic>) {
            final name = item['name'];
            if (name is String) return name.trim().toLowerCase();
          }
          return '';
        })
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  List<Set<String>> _extractJobSkillSets(Map<String, dynamic> response) {
    final data = response['data'];
    if (response['success'] != true || data is! List) {
      return <Set<String>>[];
    }

    final List<Set<String>> jobSkillSets = [];

    for (final job in data) {
      if (job is! Map<String, dynamic>) continue;
      final requiredSkills = _extractRequiredSkillNames(job['required_skills']);
      if (requiredSkills.isNotEmpty) {
        jobSkillSets.add(requiredSkills);
      }
    }

    return jobSkillSets;
  }

  Set<String> _extractRequiredSkillNames(dynamic rawValue) {
    if (rawValue == null) return <String>{};

    if (rawValue is List) {
      return rawValue
          .map((item) {
            if (item is Map<String, dynamic>) {
              final name = item['name'];
              if (name is String) return name.trim().toLowerCase();
            }
            if (item is String) return item.trim().toLowerCase();
            return '';
          })
          .where((name) => name.isNotEmpty)
          .toSet();
    }

    if (rawValue is String) {
      return rawValue
          .split(',')
          .map((skill) => skill.trim().toLowerCase())
          .where((skill) => skill.isNotEmpty)
          .toSet();
    }

    return <String>{};
  }

  String _buildSkillMatchMessage({
    required int studentSkillsCount,
    required int jobsWithSkills,
    required int matchedJobs,
  }) {
    if (studentSkillsCount == 0) {
      return 'Add your skills in profile to get personalized matching';
    }
    if (jobsWithSkills == 0) {
      return 'No open jobs with required skills found right now';
    }
    return 'Your skills match $matchedJobs of $jobsWithSkills open jobs';
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

          // Skill Match Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.grey.shade200, blurRadius: 10),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.analytics,
                        color: Colors.purple.shade700,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Skill Match Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _isLoadingStats
                          ? '...'
                          : '${(_skillMatchScore * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: _isLoadingStats ? 0.0 : _skillMatchScore,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation(Colors.purple),
                  borderRadius: BorderRadius.circular(10),
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                Text(
                  _isLoadingStats
                      ? 'Calculating skill match...'
                      : _skillMatchMessage,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Recommended Jobs Section
          const Text(
            'Recommended for you',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          // Job Cards
          _buildJobCard(
            context,
            'Software Developer Intern',
            'NMB Bank',
            'Dar es Salaam',
            'Full-time',
            'Today',
            Icons.work,
          ),
          const SizedBox(height: 12),
          _buildJobCard(
            context,
            'Data Analyst',
            'Vodacom Tanzania',
            'Dar es Salaam',
            'Part-time',
            'Yesterday',
            Icons.analytics,
          ),
          const SizedBox(height: 12),
          _buildJobCard(
            context,
            'IT Support Specialist',
            'CRDB Bank',
            'Dar es Salaam',
            'Contract',
            '2 days ago',
            Icons.support_agent,
          ),
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

  Widget _buildJobCard(
    BuildContext context,
    String title,
    String company,
    String location,
    String type,
    String time,
    IconData icon,
  ) {
    return Container(
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
            child: Icon(icon, color: const Color(0xFF1976D2), size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  company,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      location,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
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
                    Icon(Icons.access_time, size: 12, color: Colors.grey[500]),
                    const SizedBox(width: 4),
                    Text(
                      time,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: type == 'Full-time'
                  ? Colors.green.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: type == 'Full-time'
                    ? Colors.green.shade700
                    : Colors.blue.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
