import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/role_theme.dart';
import '../../widgets/language_picker_dialog.dart';
import '../auth/login_screen.dart';
import 'admin_application_filter.dart';
import 'admin_applications_screen.dart';
import 'admin_home_screen.dart';
import 'admin_logs_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_students_screen.dart';
import 'admin_user_filter.dart';
import 'admin_users_screen.dart';

enum _AdminMoreAction { settings, language, logout }

const Color _adminBrandNavy = AdminRoleTheme.primary;
const Color _adminBrandOrange = AdminRoleTheme.accent;
const Color _adminSidebarSurface = Color(0xFFF8FAFC);
const Color _adminSidebarBorder = Color(0xFFD8E2EF);
const Color _adminSidebarText = Color(0xFF44566C);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  int _homeRefreshToken = 0;
  AdminUserFilter _selectedUserFilter = AdminUserFilter.all;
  AdminApplicationFilter _selectedApplicationFilter =
      AdminApplicationFilter.all;
  final ApiService _apiService = ApiService();

  bool _isDesktopWidth(double width) => width >= 1100;

  String _formatToday(BuildContext context) {
    return MaterialLocalizations.of(context).formatFullDate(DateTime.now());
  }

  List<Widget> _buildScreens() {
    return [
      AdminHomeScreen(
        adminName: _adminName,
        onNavigateToTab: _navigateToTab,
        refreshToken: _homeRefreshToken,
      ),
      AdminUsersScreen(
        selectedFilter: _selectedUserFilter,
        onUserDataChanged: _refreshHomeStats,
      ),
      AdminApplicationsScreen(selectedFilter: _selectedApplicationFilter),
      const AdminStudentsScreen(),
      const AdminLogsScreen(),
    ];
  }

  List<_AdminNavigationItem> _navigationItems() {
    return [
      const _AdminNavigationItem(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
      ),
      const _AdminNavigationItem(label: 'Users', icon: Icons.people_rounded),
      const _AdminNavigationItem(
        label: 'Applications',
        icon: Icons.assignment_rounded,
      ),
      const _AdminNavigationItem(label: 'Students', icon: Icons.school_rounded),
      const _AdminNavigationItem(
        label: 'Reports',
        icon: Icons.receipt_long_rounded,
      ),
    ];
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

    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text('Language changed successfully.')),
    );
  }

  Future<void> _showSettingsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final language = sheetContext.watch<LanguageProvider>();
        final maxHeight = MediaQuery.of(sheetContext).size.height * 0.82;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Admin Settings',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.account_circle_outlined),
                      title: const Text('Admin Profile'),
                      subtitle: Text(_adminName),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.language_outlined),
                      title: const Text('Language'),
                      subtitle: Text(language.selectedLanguageName),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _showLanguageDialog();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_outlined),
                      title: const Text('Notifications'),
                      subtitle: const Text('Open admin notifications.'),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _openNotifications();
                      },
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.refresh_rounded),
                      title: const Text('Refresh Counters'),
                      subtitle: const Text(
                        'Sync the latest notification badge.',
                      ),
                      onTap: () {
                        Navigator.of(sheetContext).pop();
                        _loadUnreadNotifications(forceRefresh: true);
                      },
                    ),
                  ],
                ),
              ),
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

  void _refreshHomeStats() {
    setState(() => _homeRefreshToken++);
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

  Widget _buildDesktopSidebar(List<_AdminNavigationItem> items) {
    return Container(
      width: 256,
      margin: const EdgeInsets.fromLTRB(16, 0, 0, 16),
      decoration: BoxDecoration(
        color: _adminSidebarSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _adminSidebarBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ADMIN PANEL',
                  style: TextStyle(
                    color: _adminBrandOrange,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Management Navigation',
                  style: TextStyle(
                    color: _adminBrandNavy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
                      color: isSelected ? _adminBrandNavy : Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isSelected
                            ? _adminBrandNavy
                            : _adminSidebarBorder.withValues(alpha: 0.65),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.16)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            item.icon,
                            size: 20,
                            color: isSelected ? Colors.white : _adminBrandNavy,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : _adminSidebarText,
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
    final auth = context.watch<AuthProvider>();
    final isDesktop = _isDesktopWidth(MediaQuery.sizeOf(context).width);
    final adminEmail = '${auth.user?['email'] ?? 'admin@example.com'}';
    final navigationItems = _navigationItems();
    final today = _formatToday(context);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: _adminBrandNavy,
        surfaceTintColor: _adminBrandNavy,
        elevation: 0,
        toolbarHeight: 104,
        leadingWidth: 84,
        titleSpacing: 12,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(color: _adminBrandNavy),
        ),
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: Container(
              height: 56,
              width: 56,
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
                  'assets/images/splash_logo.png',
                  height: 64,
                  width: 64,
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
          ),
        ),
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'INDUSTRIAL PRACTICAL TRAINING',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              adminEmail,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                  ),
                  child: Text(
                    navigationItems[_currentIndex].label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (isDesktop)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                    ),
                    child: Text(
                      today,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
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
            tooltip: 'More actions',
            onSelected: _handleMoreAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _AdminMoreAction.settings,
                child: Row(
                  children: const [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Settings')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _AdminMoreAction.language,
                child: Row(
                  children: const [
                    Icon(Icons.language_outlined, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Language')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _AdminMoreAction.logout,
                child: Row(
                  children: const [
                    Icon(Icons.logout_rounded, size: 18),
                    SizedBox(width: 10),
                    Expanded(child: Text('Logout')),
                  ],
                ),
              ),
            ],
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                _buildDesktopSidebar(navigationItems),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: IndexedStack(
                      index: _currentIndex,
                      children: _buildScreens(),
                    ),
                  ),
                ),
              ],
            )
          : IndexedStack(index: _currentIndex, children: _buildScreens()),
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _currentIndex,
              onTap: _switchTab,
              selectedItemColor: _adminBrandOrange,
              unselectedItemColor: Colors.grey.shade600,
              items: navigationItems
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(
                        item.icon == Icons.dashboard_rounded
                            ? Icons.dashboard_outlined
                            : item.icon == Icons.people_rounded
                            ? Icons.people_outline_rounded
                            : item.icon == Icons.assignment_rounded
                            ? Icons.assignment_outlined
                            : item.icon == Icons.school_rounded
                            ? Icons.school_outlined
                            : Icons.receipt_long_outlined,
                      ),
                      activeIcon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _AdminNavigationItem {
  const _AdminNavigationItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}
