import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/coordinator_workspace_service.dart';
import '../../utils/assets.dart';
import '../../utils/role_theme.dart';
import '../../utils/theme.dart';
import '../../widgets/language_picker_dialog.dart';
import 'browse_jobs_screen.dart';
import 'job_details_screen.dart';
import 'my_applications_screen.dart';
import 'profile_screen.dart';
import 'notifications_screen.dart';
import '../auth/login_screen.dart';

enum _StudentMoreAction { settings, language, logout }

const Color _studentBrandPrimary = StudentRoleTheme.primary;
const Color _studentBrandNavy = StudentRoleTheme.navy;
const Color _studentBrandAccent = StudentRoleTheme.accent;
const Color _studentBrandSurface = StudentRoleTheme.surface;
const Color _studentBrandSurfaceSoft = StudentRoleTheme.surfaceSoft;
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
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  int _unreadNotifications = 0;
  String _applicationsFilter = 'all';
  int _homeRefreshToken = 0;
  int _applicationsRefreshToken = 0;
  final List<_StudentTabState> _tabHistory = [];

  bool _isDesktopWidth(double width) => width >= 1100;

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

  List<String> _studentInstitutionNames(Map<String, dynamic>? studentData) {
    final values = [
      studentData?['college_name'],
      studentData?['institution_name'],
      studentData?['university_name'],
    ];

    final seen = <String>{};
    final names = <String>[];
    for (final value in values) {
      final name = '${value ?? ''}'.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (!seen.add(normalized)) continue;
      names.add(name);
    }
    return names;
  }

  List<String> _studentInstitutionIds(Map<String, dynamic>? studentData) {
    final values = [studentData?['university_id']];

    final seen = <String>{};
    final ids = <String>[];
    for (final value in values) {
      final id = '${value ?? ''}'.trim();
      if (id.isEmpty) continue;
      final normalized = id.toLowerCase();
      if (!seen.add(normalized)) continue;
      ids.add(id);
    }
    return ids;
  }

  List<Widget> _buildScreens() {
    return [
      HomeScreen(refreshToken: _homeRefreshToken),
      const BrowsetrainingScreen(),
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

  List<_StudentNavigationItem> _navigationItems(LanguageProvider language) {
    return [
      _StudentNavigationItem(
        label: language.tr('home'),
        icon: Icons.home_rounded,
        inactiveIcon: Icons.home_outlined,
      ),
      _StudentNavigationItem(
        label: language.tr('Apply'),
        icon: Icons.search_rounded,
        inactiveIcon: Icons.search_outlined,
      ),
      _StudentNavigationItem(
        label: language.tr('my_apps'),
        icon: Icons.assignment_rounded,
        inactiveIcon: Icons.assignment_outlined,
      ),
      _StudentNavigationItem(
        label: language.tr('profile'),
        icon: Icons.person_rounded,
        inactiveIcon: Icons.person_outline,
      ),
    ];
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
    final currentUser = context.read<AuthProvider>().user;
    final studentEmail = currentUser?['email']?.toString();
    final studentData = currentUser?['student_data'] as Map<String, dynamic>?;
    final universityId = studentData?['university_id']?.toString();
    final universityName = studentData?['university_name']?.toString();
    final institutionIds = _studentInstitutionIds(studentData);
    final institutionNames = _studentInstitutionNames(studentData);

    try {
      final response = await _apiService.getUnreadNotificationCount(
        forceRefresh: forceRefresh,
      );
      final localNotifications = await _workspaceService
          .getNotificationsForRole(
            role: 'student',
            studentEmail: studentEmail,
            universityId: universityId,
            universityName: universityName,
            institutionIds: institutionIds,
            institutionNames: institutionNames,
          );
      final localUnreadCount = localNotifications
          .where((item) => item['is_read'] != true)
          .length;
      if (response['success'] == true) {
        final rawCount = response['data']?['count'];
        final count = rawCount is int
            ? rawCount
            : int.tryParse('$rawCount') ?? 0;
        if (mounted) {
          setState(() => _unreadNotifications = count + localUnreadCount);
        }
      } else if (mounted) {
        setState(() => _unreadNotifications = localUnreadCount);
      }
    } catch (e) {
      try {
        final localNotifications = await _workspaceService
            .getNotificationsForRole(
              role: 'student',
              studentEmail: studentEmail,
              universityId: universityId,
              universityName: universityName,
              institutionIds: institutionIds,
              institutionNames: institutionNames,
            );
        if (mounted) {
          setState(() {
            _unreadNotifications = localNotifications
                .where((item) => item['is_read'] != true)
                .length;
          });
        }
      } catch (_) {
        // Ignore errors; badge can stay hidden.
      }
    }
  }

  void _showTopSnackBar(String message, Color backgroundColor) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showAppSnackBar(
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
      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      await authProvider.logout();
      if (!mounted) return;
      messenger.showAppSnackBar(
        SnackBar(
          content: Text(language.tr('logout_success')),
          backgroundColor: Colors.green,
        ),
      );
      navigator.pushAndRemoveUntil(
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

  Widget _buildDesktopSidebar(
    List<_StudentNavigationItem> items,
    String firstName,
    String email,
  ) {
    return Container(
      width: 278,
      margin: const EdgeInsets.fromLTRB(16, 16, 0, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _studentBrandPrimary.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: _studentBrandPrimary.withValues(alpha: 0.06),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _studentBrandSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.school_rounded,
                    color: _studentBrandPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'STUDENT PANEL',
                  style: TextStyle(
                    color: _studentBrandPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  firstName,
                  style: const TextStyle(
                    color: Color(0xFF10233F),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(14),
              itemCount: items.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = index == _currentIndex;
                return InkWell(
                  onTap: () => _switchTab(index),
                  borderRadius: BorderRadius.circular(18),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _studentBrandPrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? _studentBrandPrimary
                            : _studentBrandPrimary.withValues(alpha: 0.12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.14)
                                : _studentBrandSurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            isSelected ? item.icon : item.inactiveIcon,
                            size: 20,
                            color: isSelected
                                ? Colors.white
                                : _studentBrandPrimary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFF44566C),
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
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
    final fullName = user?['full_name'] ?? language.tr('student');
    final email = '${user?['email'] ?? ''}';
    final firstName = fullName.split(' ')[0];
    final today = _formatToday();
    final isDesktop = _isDesktopWidth(MediaQuery.sizeOf(context).width);
    final navigationItems = _navigationItems(language);

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
        backgroundColor: _studentBrandSurfaceSoft,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(isDesktop ? 74 : 108),
          child: _StudentPortalHeader(
            isCompact: !isDesktop,
            unreadNotifications: _unreadNotifications,
            language: language,
            onNotificationsPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsScreen()),
              );
              _loadUnreadNotifications(forceRefresh: true);
            },
            onMoreSelected: _handleMoreAction,
          ),
        ),
        body: Row(
          children: [
            if (isDesktop)
              _buildDesktopSidebar(navigationItems, firstName, email),
            Expanded(
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    margin: EdgeInsets.fromLTRB(
                      isDesktop ? 16 : 0,
                      isDesktop ? 16 : 0,
                      isDesktop ? 16 : 0,
                      0,
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isDesktop ? 24 : 0),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.shadow.withValues(alpha: 0.04),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
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
                        Text(
                          email,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
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
                            color: _studentBrandSurface,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.shadow.withValues(alpha: 0.03),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isDesktop ? 16 : 0,
                        0,
                        isDesktop ? 16 : 0,
                        isDesktop ? 16 : 0,
                      ),
                      child: IndexedStack(
                        index: _currentIndex,
                        children: _buildScreens(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: isDesktop
            ? null
            : BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: _switchTab,
                selectedItemColor: _studentBrandPrimary,
                unselectedItemColor: Colors.grey.shade600,
                items: navigationItems
                    .map(
                      (item) => BottomNavigationBarItem(
                        icon: Icon(item.inactiveIcon),
                        activeIcon: Icon(item.icon),
                        label: item.label,
                      ),
                    )
                    .toList(growable: false),
              ),
      ),
    );
  }
}

class _StudentNavigationItem {
  const _StudentNavigationItem({
    required this.label,
    required this.icon,
    required this.inactiveIcon,
  });

  final String label;
  final IconData icon;
  final IconData inactiveIcon;
}

class _StudentPortalHeader extends StatelessWidget {
  const _StudentPortalHeader({
    required this.isCompact,
    required this.unreadNotifications,
    required this.language,
    required this.onNotificationsPressed,
    required this.onMoreSelected,
  });

  final bool isCompact;
  final int unreadNotifications;
  final LanguageProvider language;
  final VoidCallback onNotificationsPressed;
  final PopupMenuItemSelected<_StudentMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _studentBrandSurfaceSoft,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _studentBrandSurfaceSoft,
            boxShadow: [
              BoxShadow(
                color: AppTheme.shadow.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 58,
            vertical: isCompact ? 6 : 12,
          ),
          child: isCompact
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const _StudentHeaderBrand(),
                        const Spacer(),
                        _StudentHeaderActions(
                          unreadNotifications: unreadNotifications,
                          language: language,
                          onNotificationsPressed: onNotificationsPressed,
                          onMoreSelected: onMoreSelected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const _StudentHeaderCenterTitle(isCompact: true),
                  ],
                )
              : Row(
                  children: [
                    const _StudentHeaderBrand(),
                    const Expanded(child: _StudentHeaderCenterTitle()),
                    _StudentHeaderActions(
                      unreadNotifications: unreadNotifications,
                      language: language,
                      onNotificationsPressed: onNotificationsPressed,
                      onMoreSelected: onMoreSelected,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _StudentHeaderBrand extends StatelessWidget {
  const _StudentHeaderBrand();

  static const Color _brandNavy = StudentRoleTheme.navy;
  static const Color _brandOrange = StudentRoleTheme.accentOrange;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 46,
          width: 78,
          child: Image.asset(
            AppAssets.homeLogo,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return Image.asset(
                AppAssets.splashLogo,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.school_rounded,
                    color: _brandNavy,
                    size: 30,
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(width: 10),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
            children: [
              TextSpan(
                text: 'IPT ',
                style: TextStyle(color: _brandNavy),
              ),
              TextSpan(
                text: 'Kiganjani',
                style: TextStyle(color: _brandOrange),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StudentHeaderCenterTitle extends StatelessWidget {
  const _StudentHeaderCenterTitle({this.isCompact = false});

  final bool isCompact;

  static const Color _brandNavy = StudentRoleTheme.navy;

  @override
  Widget build(BuildContext context) {
    return Text(
      'THE UNITED REPUBLIC OF TANZANIA\nPRACTICAL TRAINING SYSTEM',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _brandNavy,
        fontSize: isCompact ? 12 : 15,
        height: 1.25,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _StudentHeaderActions extends StatelessWidget {
  const _StudentHeaderActions({
    required this.unreadNotifications,
    required this.language,
    required this.onNotificationsPressed,
    required this.onMoreSelected,
  });

  final int unreadNotifications;
  final LanguageProvider language;
  final VoidCallback onNotificationsPressed;
  final PopupMenuItemSelected<_StudentMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StudentNotificationButton(
          unreadNotifications: unreadNotifications,
          tooltip: language.tr('notifications'),
          onPressed: onNotificationsPressed,
        ),
        const SizedBox(width: 8),
        _StudentHeaderMenuButton(
          language: language,
          onSelected: onMoreSelected,
        ),
      ],
    );
  }
}

class _StudentNotificationButton extends StatelessWidget {
  const _StudentNotificationButton({
    required this.unreadNotifications,
    required this.tooltip,
    required this.onPressed,
  });

  final int unreadNotifications;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          height: 38,
          width: 38,
          child: TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: _studentBrandAccent,
              backgroundColor: _studentBrandPrimary,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            child: Tooltip(
              message: tooltip,
              child: const Icon(Icons.notifications_outlined, size: 21),
            ),
          ),
        ),
        if (unreadNotifications > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1.4),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _StudentHeaderMenuButton extends StatelessWidget {
  const _StudentHeaderMenuButton({
    required this.language,
    required this.onSelected,
  });

  final LanguageProvider language;
  final PopupMenuItemSelected<_StudentMoreAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_StudentMoreAction>(
      tooltip: language.tr('more_actions'),
      onSelected: onSelected,
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
      icon: const Icon(Icons.more_vert_rounded),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconColor: _studentBrandNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  int _applicationsCount = 0;
  int _pendingCount = 0;
  int _reviewCount = 0;
  int _profileViewsCount = 0;
  List<Job> _recenttraining = const [];
  List<Map<String, dynamic>> _announcements = const [];
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
      final studentData = user?['student_data'] as Map<String, dynamic>?;
      final universityId = studentData?['university_id']?.toString();
      final universityName = studentData?['university_name']?.toString();
      final institutionIds = _studentInstitutionIds(studentData);
      final institutionNames = _studentInstitutionNames(studentData);
      final responses = await Future.wait<dynamic>([
        _apiService.getMyApplications(),
        _apiService.gettraining(limit: '100'),
        _workspaceService.getAnnouncements(
          audience: 'student',
          universityId: universityId,
          universityName: universityName,
          institutionIds: institutionIds,
          institutionNames: institutionNames,
        ),
      ]);

      final appsResponse = responses[0] as Map<String, dynamic>;
      final trainingResponse = responses[1] as Map<String, dynamic>;
      final announcements = responses[2] as List<Map<String, dynamic>>;

      int applications = 0;
      int pending = 0;
      int review = 0;

      if (appsResponse['success'] == true && appsResponse['data'] is List) {
        final apps = appsResponse['data'] as List<dynamic>;
        applications = apps.length;
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
      final recenttraining = _extractRecenttraining(trainingResponse);

      if (mounted) {
        setState(() {
          _applicationsCount = applications;
          _pendingCount = pending;
          _reviewCount = review;
          _profileViewsCount = profileViews;
          _recenttraining = recenttraining;
          _announcements = announcements;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingStats = false);
      }
    }
  }

  List<Job> _extractRecenttraining(Map<String, dynamic> response) {
    final data = response['data'];
    if (response['success'] != true || data is! List) {
      return const [];
    }

    final training =
        data
            .whereType<Map<String, dynamic>>()
            .map(Job.fromJson)
            .where((job) => job.status == 'open')
            .toList()
          ..sort((left, right) => right.createdAt.compareTo(left.createdAt));

    final seenCompanies = <String>{};
    final recenttraining = <Job>[];

    for (final job in training) {
      final companyKey = job.companyId.isNotEmpty
          ? job.companyId
          : job.companyName.toLowerCase();
      if (!seenCompanies.add(companyKey)) {
        continue;
      }

      recenttraining.add(job);
      if (recenttraining.length == 4) {
        break;
      }
    }

    return recenttraining;
  }

  void _goToTab(int index) {
    final dashboard = context.findAncestorStateOfType<_StudentDashboardState>();
    dashboard?._switchTab(index);
  }

  void _goToApplicationsFilter(String filter) {
    final dashboard = context.findAncestorStateOfType<_StudentDashboardState>();
    dashboard?._openApplicationsWithFilter(filter);
  }

  Future<void> _openAnnouncements() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
  }

  String _formatAnnouncementDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  List<String> _studentInstitutionNames(Map<String, dynamic>? studentData) {
    final values = [
      studentData?['college_name'],
      studentData?['institution_name'],
      studentData?['university_name'],
    ];

    final seen = <String>{};
    final names = <String>[];
    for (final value in values) {
      final name = '${value ?? ''}'.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (!seen.add(normalized)) continue;
      names.add(name);
    }
    return names;
  }

  List<String> _studentInstitutionIds(Map<String, dynamic>? studentData) {
    final values = [studentData?['university_id']];

    final seen = <String>{};
    final ids = <String>[];
    for (final value in values) {
      final id = '${value ?? ''}'.trim();
      if (id.isEmpty) continue;
      final normalized = id.toLowerCase();
      if (!seen.add(normalized)) continue;
      ids.add(id);
    }
    return ids;
  }

  Widget _buildAnnouncementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Institution Announcements',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1F2937),
              ),
            ),
            TextButton(
              onPressed: _openAnnouncements,
              style: TextButton.styleFrom(
                foregroundColor: _studentBrandPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
              child: const Text(
                'View all',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_announcements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _studentBrandBorder),
              boxShadow: [
                BoxShadow(
                  color: _studentBrandPrimary.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _studentBrandSurface,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(
                    Icons.campaign_outlined,
                    color: _studentBrandPrimary,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'No institution announcements yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF334155),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Announcements posted by your institution coordinators will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          )
        else
          ..._announcements.take(3).map((announcement) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: _studentBrandPrimary.withValues(alpha: 0.12),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _studentBrandPrimary.withValues(alpha: 0.05),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: _studentBrandSurface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.campaign_rounded,
                            color: _studentBrandPrimary,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: _studentBrandSurface,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  '${announcement['university_name'] ?? announcement['institution_name'] ?? 'Institution'}',
                                  style: const TextStyle(
                                    color: _studentBrandPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _formatAnnouncementDate(
                                    '${announcement['created_at'] ?? ''}',
                                  ),
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      '${announcement['title'] ?? 'Announcement'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _studentBrandPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${announcement['message'] ?? ''}',
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Stats Overview',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1F2937),
            ),
          ),

          const SizedBox(height: 14),
          // Stats cards
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;
              final spacing = isCompact ? 8.0 : 12.0;
              final itemWidth = isCompact
                  ? (constraints.maxWidth - spacing) / 2
                  : (constraints.maxWidth - (spacing * 3)) / 4;
              final cards = [
                _buildStatCard(
                  Icons.assignment,
                  isCompact ? 'Apps' : 'Applications',
                  _isLoadingStats ? '...' : '$_applicationsCount',
                  _studentBrandPrimary,
                  () => _goToApplicationsFilter('all'),
                  compact: isCompact,
                ),
                _buildStatCard(
                  Icons.hourglass_empty,
                  'Pending',
                  _isLoadingStats ? '...' : '$_pendingCount',
                  Colors.orange,
                  () => _goToApplicationsFilter('pending'),
                  compact: isCompact,
                ),
                _buildStatCard(
                  Icons.rate_review_outlined,
                  'Review',
                  _isLoadingStats ? '...' : '$_reviewCount',
                  _studentBrandNavy,
                  () => _goToApplicationsFilter('review'),
                  compact: isCompact,
                ),
                _buildStatCard(
                  Icons.visibility,
                  isCompact ? 'Views' : 'Profile Views',
                  _isLoadingStats ? '...' : '$_profileViewsCount',
                  _studentBrandAccent,
                  () => _goToTab(3),
                  compact: isCompact,
                ),
              ];

              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final card in cards)
                    SizedBox(width: itemWidth, child: card),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          _buildAnnouncementSection(),
          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent practical Postings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 4),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _goToTab(1),
                style: TextButton.styleFrom(
                  foregroundColor: _studentBrandPrimary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                child: const Text(
                  'View All',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

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
                'Loading recent training...',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else if (_recenttraining.isEmpty)
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
                'No recent training available right now.',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ..._recenttraining.asMap().entries.map((entry) {
              final index = entry.key;
              final job = entry.value;
              return Padding(
                padding: EdgeInsets.only(
                  bottom: index == _recenttraining.length - 1 ? 0 : 12,
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
                  'Browse training',
                  _studentBrandPrimary,
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
    VoidCallback onTap, {
    bool compact = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 12,
            vertical: compact ? 12 : 14,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: compact ? 38 : 42,
                height: compact ? 38 : 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: const Color(0xFF475569),
                  size: compact ? 18 : 20,
                ),
              ),
              SizedBox(height: compact ? 8 : 10),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 18 : 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: compact ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: compact ? 10 : 11,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
            ],
          ),
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
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.borderGrey.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.shadow.withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

  String _formatDeadlineChip(DateTime deadline) {
    final day = deadline.day.toString().padLeft(2, '0');
    final month = deadline.month.toString().padLeft(2, '0');
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$day/$month/${deadline.year} $hour:$minute';
  }

  String _formatDeadlineCountdown(DateTime deadline) {
    final now = DateTime.now();
    final difference = deadline.difference(now);
    if (difference.isNegative) return 'Closed';
    if (difference.inDays >= 1) {
      final days = difference.inDays;
      return '$days day${days == 1 ? '' : 's'} left';
    }
    if (difference.inHours >= 1) {
      final hours = difference.inHours;
      return '$hours hr${hours == 1 ? '' : 's'} left';
    }
    final minutes = difference.inMinutes.clamp(0, 59);
    return '$minutes min left';
  }

  String _formatApplicantsNeeded(int count) {
    return '$count needed';
  }

  Widget _buildRecentJobCard(Job job) {
    final timeLabel = _formatRecentPostingTime(job.createdAt);
    final deadlineLabel = _formatDeadlineChip(job.applicationDeadline);
    final deadlineCountdown = _formatDeadlineCountdown(job.applicationDeadline);
    final isOpen =
        job.status.toLowerCase() == 'open' &&
        job.applicationDeadline.isAfter(DateTime.now());
    final visibleTargets = job.targetCandidates.take(3).toList(growable: false);

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _studentBrandPrimary.withValues(alpha: 0.26),
          ),
          boxShadow: [
            BoxShadow(
              color: _studentBrandPrimary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final itemWidth = compact
                ? ((constraints.maxWidth - 8) / 2).clamp(0, 132).toDouble()
                : 138.0;

            return Column(
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
                            job.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: _studentBrandPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            job.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 5),
                              Flexible(
                                child: Text(
                                  job.location,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color:
                            (isOpen
                                    ? const Color(0xFF2E9C6E)
                                    : const Color(0xFFD97706))
                                .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        isOpen ? 'Active' : 'Closed',
                        style: TextStyle(
                          color: isOpen
                              ? const Color(0xFF2E9C6E)
                              : const Color(0xFFD97706),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _studentBrandSurface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: _studentBrandPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    '$deadlineLabel · $deadlineCountdown',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _studentBrandPrimary,
                    ),
                  ),
                ),
                if (visibleTargets.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: visibleTargets
                        .map(
                          (target) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              target.replaceAll('_', ' '),
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 14),
                if (compact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _StudentRecentMetaCard(
                          icon: Icons.group_add_outlined,
                          label: _formatApplicantsNeeded(
                            job.requiredApplicants,
                          ),
                          tint: const Color(0xFFC58A16),
                          background: const Color(0xFFFFF8EA),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _StudentRecentMetaCard(
                          icon: Icons.schedule_rounded,
                          label: timeLabel,
                          tint: const Color(0xFF5B6C84),
                        ),
                      ),
                      SizedBox(
                        width: itemWidth,
                        child: _StudentRecentMetaCard(
                          icon: Icons.arrow_outward_rounded,
                          label: 'Open training',
                          tint: _studentBrandPrimary,
                          isAction: true,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    JobDetailsScreen(jobId: job.jobId),
                              ),
                            );
                            _loadStats();
                          },
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      SizedBox(
                        width: itemWidth,
                        child: _StudentRecentMetaCard(
                          icon: Icons.group_add_outlined,
                          label: _formatApplicantsNeeded(
                            job.requiredApplicants,
                          ),
                          tint: const Color(0xFFC58A16),
                          background: const Color(0xFFFFF8EA),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: itemWidth,
                        child: _StudentRecentMetaCard(
                          icon: Icons.schedule_rounded,
                          label: timeLabel,
                          tint: const Color(0xFF5B6C84),
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: itemWidth,
                        child: _StudentRecentMetaCard(
                          icon: Icons.arrow_outward_rounded,
                          label: 'Open training',
                          tint: _studentBrandPrimary,
                          isAction: true,
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    JobDetailsScreen(jobId: job.jobId),
                              ),
                            );
                            _loadStats();
                          },
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StudentRecentMetaCard extends StatelessWidget {
  const _StudentRecentMetaCard({
    required this.icon,
    required this.label,
    required this.tint,
    this.background,
    this.isAction = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color tint;
  final Color? background;
  final bool isAction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: background ?? tint.withValues(alpha: isAction ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 18, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tint,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
          if (isAction)
            Icon(Icons.chevron_right_rounded, color: tint, size: 18),
        ],
      ),
    );

    if (!isAction || onTap == null) return card;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: card,
      ),
    );
  }
}
