import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../widgets/change_pin_dialog.dart';
import '../../widgets/language_picker_dialog.dart';
import '../../widgets/reset_pin_dialog.dart';
import '../auth/login_screen.dart';
import 'admin_application_filter.dart';
import 'admin_applications_screen.dart';
import 'admin_home_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_user_filter.dart';
import 'admin_users_screen.dart';

enum _AdminMoreAction { settings, language, logout }

const Color _adminBrandNavy = Color(0xFF0E3A5D);
const Color _adminBrandOrange = Color(0xFFEF6C00);
const Color _adminBrandSand = Color(0xFFFFE0B2);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  AdminUserFilter _selectedUserFilter = AdminUserFilter.all;
  AdminApplicationFilter _selectedApplicationFilter =
      AdminApplicationFilter.all;
  final ApiService _apiService = ApiService();

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
      AdminHomeScreen(adminName: _adminName, onNavigateToTab: _navigateToTab),
      AdminUsersScreen(selectedFilter: _selectedUserFilter),
      AdminApplicationsScreen(selectedFilter: _selectedApplicationFilter),
      const AdminLogsScreen(),
    ];
  }

  List<String> _titles() {
    return const ['Dashboard', 'Users', 'Applications', 'Report'];
  }

  String get _adminName {
    final auth = context.read<AuthProvider>();
    return '${auth.user?['full_name'] ?? auth.user?['email'] ?? 'Admin'}'
        .trim();
  }

  @override
  void initState() {
    super.initState();
    _loadUnreadNotifications();
  }

  Future<void> _loadUnreadNotifications({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.getUnreadNotificationCount(
        forceRefresh: forceRefresh,
      );
      if (!mounted) return;
      if (response['success'] == true) {
        final rawCount = response['data']?['count'];
        setState(() => _unreadNotifications = int.tryParse('$rawCount') ?? 0);
      }
    } catch (_) {}
  }

  Future<void> _openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AdminNotificationsScreen()),
    );
    _loadUnreadNotifications(forceRefresh: true);
  }

  Future<void> _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    if (!mounted) return;

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
                  language.tr('admin_settings'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.account_circle_outlined),
                  title: const Text('Admin profile'),
                  subtitle: Text(_adminName),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pin_outlined),
                  title: const Text('Change PIN'),
                  subtitle: const Text('Update your 4-digit app PIN'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final changed = await showChangePinDialog(context);
                    if (!mounted || changed != true) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PIN updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text('Reset PIN'),
                  subtitle: const Text(
                    'Verify with password and create a new PIN',
                  ),
                  onTap: () async {
                    final email =
                        context
                            .read<AuthProvider>()
                            .user?['email']
                            ?.toString() ??
                        '';
                    Navigator.of(sheetContext).pop();
                    if (email.isEmpty) return;
                    final changed = await showResetPinDialog(
                      context,
                      email: email,
                    );
                    if (!mounted || changed != true) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('PIN reset successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
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
                  subtitle: const Text('Open admin notifications'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openNotifications();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh_rounded),
                  title: const Text('Refresh counters'),
                  subtitle: const Text('Sync the latest unread badge count'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _loadUnreadNotifications(forceRefresh: true);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleMoreAction(_AdminMoreAction action) async {
    switch (action) {
      case _AdminMoreAction.settings:
        await _showSettingsSheet();
        break;
      case _AdminMoreAction.language:
        await _showLanguageDialog();
        break;
      case _AdminMoreAction.logout:
        await _logout();
        break;
    }
  }

  void _switchTab(int index) {
    setState(() => _currentIndex = index);
  }

  void _navigateToTab(
    int index, {
    AdminUserFilter? userFilter,
    AdminApplicationFilter? applicationFilter,
  }) {
    setState(() {
      _currentIndex = index;
      if (userFilter != null) {
        _selectedUserFilter = userFilter;
      }
      if (applicationFilter != null) {
        _selectedApplicationFilter = applicationFilter;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final language = context.watch<LanguageProvider>();
    final adminName =
        '${auth.user?['full_name'] ?? auth.user?['email'] ?? 'Admin'}'.trim();
    final adminEmail = '${auth.user?['email'] ?? 'admin@example.com'}';
    final firstName = adminName.isEmpty ? 'Admin' : adminName.split(' ').first;
    final titles = _titles();
    final today = _formatToday();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _adminBrandNavy,
        surfaceTintColor: _adminBrandNavy,
        elevation: 0,
        titleSpacing: 8,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _adminBrandNavy,
                const Color(0xFF153E63),
                _adminBrandOrange.withValues(alpha: 0.88),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
                      Icons.admin_panel_settings_rounded,
                      size: 34,
                      color: _adminBrandNavy,
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
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _adminBrandOrange,
                        borderRadius: BorderRadius.circular(99),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
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
          PopupMenuButton<_AdminMoreAction>(
            tooltip: 'More',
            onSelected: _handleMoreAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _AdminMoreAction.settings,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                ),
              ),
              PopupMenuItem(
                value: _AdminMoreAction.language,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.language_outlined),
                  title: Text('Language'),
                ),
              ),
              PopupMenuDivider(),
              PopupMenuItem(
                value: _AdminMoreAction.logout,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout_rounded),
                  title: Text('Logout'),
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _adminBrandNavy.withValues(alpha: 0.08),
                  _adminBrandOrange.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 1),
              ),
            ),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: _adminBrandOrange.withValues(alpha: 0.18),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _adminBrandNavy.withValues(alpha: 0.07),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Welcome back, $firstName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _adminBrandNavy,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      adminEmail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _adminBrandSand.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: _adminBrandOrange.withValues(alpha: 0.22),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 15,
                                color: _adminBrandOrange,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                today,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _adminBrandNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _adminBrandNavy,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            titles[_currentIndex],
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
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
        selectedItemColor: _adminBrandOrange,
        unselectedItemColor: Colors.grey.shade600,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_outlined),
            activeIcon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline_rounded),
            activeIcon: Icon(Icons.people_rounded),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined),
            activeIcon: Icon(Icons.assignment_rounded),
            label: 'Applications',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long_rounded),
            label: 'Report',
          ),
        ],
      ),
    );
  }
}
