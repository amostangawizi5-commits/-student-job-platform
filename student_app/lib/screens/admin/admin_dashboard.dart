import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/role_theme.dart';
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

const Color _adminBrandNavy = AdminRoleTheme.primary;
const Color _adminBrandOrange = AdminRoleTheme.accent;

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

  String _formatToday(BuildContext context) {
    return MaterialLocalizations.of(context).formatFullDate(DateTime.now());
  }

  List<Widget> _buildScreens() {
    return [
      AdminHomeScreen(adminName: _adminName, onNavigateToTab: _navigateToTab),
      AdminUsersScreen(selectedFilter: _selectedUserFilter),
      AdminApplicationsScreen(selectedFilter: _selectedApplicationFilter),
      const AdminLogsScreen(),
    ];
  }

  List<String> _titles(LanguageProvider language) {
    return [
      language.tr('dashboard'),
      language.tr('users'),
      language.tr('applications'),
      language.tr('report'),
    ];
  }

  String get _adminName {
    final auth = context.read<AuthProvider>();
    final language = context.read<LanguageProvider>();
    return '${auth.user?['full_name'] ?? auth.user?['email'] ?? language.tr('admin')}'
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
                  title: Text(language.tr('admin_profile')),
                  subtitle: Text(_adminName),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.pin_outlined),
                  title: Text(language.tr('change_pin')),
                  subtitle: Text(language.tr('update_4_digit_app_pin')),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    final changed = await showChangePinDialog(context);
                    if (!mounted || changed != true) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(language.tr('pin_updated_successfully')),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: Text(language.tr('reset_pin')),
                  subtitle: Text(
                    language.tr('verify_with_password_create_new_pin'),
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
                  subtitle: Text(language.tr('open_admin_notifications')),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _openNotifications();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.refresh_rounded),
                  title: Text(language.tr('refresh_counters')),
                  subtitle: Text(language.tr('sync_latest_notification_badge')),
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
        '${auth.user?['full_name'] ?? auth.user?['email'] ?? language.tr('admin')}'
            .trim();
    final adminEmail = '${auth.user?['email'] ?? 'admin@example.com'}';
    final firstName = adminName.isEmpty
        ? language.tr('admin')
        : adminName.split(' ').first;
    final titles = _titles(language);
    final today = _formatToday(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _adminBrandNavy,
        surfaceTintColor: _adminBrandNavy,
        elevation: 0,
        toolbarHeight: 92,
        titleSpacing: 8,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(color: _adminBrandNavy),
        ),
        title: Row(
          children: [
            Container(
              height: 58,
              width: 58,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
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
            tooltip: language.tr('more_actions'),
            onSelected: _handleMoreAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AdminMoreAction.settings,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(language.tr('settings')),
                ),
              ),
              PopupMenuItem(
                value: _AdminMoreAction.language,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.language_outlined),
                  title: Text(language.tr('language')),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _AdminMoreAction.logout,
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.logout_rounded),
                  title: Text(language.tr('logout')),
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
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
            decoration: const BoxDecoration(color: AdminRoleTheme.warmSurface),
            child: Center(
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 540),
                padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(26),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x120E3A5D),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.85),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      language.tr('welcome_back_name', {'name': firstName}),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _adminBrandNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      adminEmail,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AdminRoleTheme.chipSurface,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AdminRoleTheme.chipBorder,
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
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: _adminBrandNavy,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: _adminBrandNavy,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            titles[_currentIndex],
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
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
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.dashboard_outlined),
            activeIcon: const Icon(Icons.dashboard_rounded),
            label: language.tr('dashboard'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.people_outline_rounded),
            activeIcon: const Icon(Icons.people_rounded),
            label: language.tr('users'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.assignment_outlined),
            activeIcon: const Icon(Icons.assignment_rounded),
            label: language.tr('applications'),
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.receipt_long_outlined),
            activeIcon: const Icon(Icons.receipt_long_rounded),
            label: language.tr('report'),
          ),
        ],
      ),
    );
  }
}
