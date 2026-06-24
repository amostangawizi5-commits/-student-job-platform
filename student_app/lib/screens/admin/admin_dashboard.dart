import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../utils/assets.dart';
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
    final language = context.read<LanguageProvider>();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final confirmed = await showDialog<bool>(
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

    if (!mounted || confirmed != true) return;

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
    final language = context.watch<LanguageProvider>();
    final isDesktop = _isDesktopWidth(MediaQuery.sizeOf(context).width);
    final navigationItems = _navigationItems();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(isDesktop ? 74 : 108),
        child: _AdminPortalHeader(
          isCompact: !isDesktop,
          unreadNotifications: _unreadNotifications,
          language: language,
          onNotificationsPressed: _openNotifications,
          onMoreSelected: _handleMoreAction,
        ),
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

class _AdminPortalHeader extends StatelessWidget {
  const _AdminPortalHeader({
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
  final PopupMenuItemSelected<_AdminMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: StudentRoleTheme.surfaceSoft,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: StudentRoleTheme.surfaceSoft,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
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
                        const _AdminHeaderBrand(),
                        const Spacer(),
                        _AdminHeaderActions(
                          unreadNotifications: unreadNotifications,
                          language: language,
                          onNotificationsPressed: onNotificationsPressed,
                          onMoreSelected: onMoreSelected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const _AdminHeaderCenterTitle(isCompact: true),
                  ],
                )
              : Row(
                  children: [
                    const _AdminHeaderBrand(),
                    const Expanded(child: _AdminHeaderCenterTitle()),
                    _AdminHeaderActions(
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

class _AdminHeaderBrand extends StatelessWidget {
  const _AdminHeaderBrand();

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
              return const Icon(
                Icons.admin_panel_settings_rounded,
                color: StudentRoleTheme.navy,
                size: 30,
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
                style: TextStyle(color: StudentRoleTheme.navy),
              ),
              TextSpan(
                text: 'Kiganjani',
                style: TextStyle(color: StudentRoleTheme.accentOrange),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminHeaderCenterTitle extends StatelessWidget {
  const _AdminHeaderCenterTitle({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'THE UNITED REPUBLIC OF TANZANIA\nPRACTICAL TRAINING SYSTEM',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: StudentRoleTheme.navy,
        fontSize: isCompact ? 12 : 15,
        height: 1.25,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _AdminHeaderActions extends StatelessWidget {
  const _AdminHeaderActions({
    required this.unreadNotifications,
    required this.language,
    required this.onNotificationsPressed,
    required this.onMoreSelected,
  });

  final int unreadNotifications;
  final LanguageProvider language;
  final VoidCallback onNotificationsPressed;
  final PopupMenuItemSelected<_AdminMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _AdminNotificationButton(
          unreadNotifications: unreadNotifications,
          tooltip: 'Notifications',
          onPressed: onNotificationsPressed,
        ),
        const SizedBox(width: 8),
        _AdminHeaderMenuButton(language: language, onSelected: onMoreSelected),
      ],
    );
  }
}

class _AdminNotificationButton extends StatelessWidget {
  const _AdminNotificationButton({
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
              foregroundColor: StudentRoleTheme.accent,
              backgroundColor: StudentRoleTheme.primary,
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

class _AdminHeaderMenuButton extends StatelessWidget {
  const _AdminHeaderMenuButton({
    required this.language,
    required this.onSelected,
  });

  final LanguageProvider language;
  final PopupMenuItemSelected<_AdminMoreAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_AdminMoreAction>(
      tooltip: 'More actions',
      onSelected: onSelected,
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
            children: [
              const Icon(Icons.logout_rounded, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(language.tr('logout'))),
            ],
          ),
        ),
      ],
      icon: const Icon(Icons.more_vert_rounded),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconColor: StudentRoleTheme.navy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}
