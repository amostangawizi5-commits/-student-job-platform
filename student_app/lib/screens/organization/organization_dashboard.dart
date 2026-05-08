import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/tanzania_locations.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/browser_pdf_opener.dart';
import '../../services/coordinator_workspace_service.dart';
import '../../services/export_file_saver.dart';
import '../../services/local_file_service.dart';
import '../../utils/role_theme.dart';
import '../../widgets/language_picker_dialog.dart';
import '../auth/login_screen.dart';
import 'post_job_screen.dart';
import 'edit_organization_profile_screen.dart';
import 'organization_notifications_screen.dart';

enum _OrganizationMoreAction { settings, language, logout }

const Color _organizationStudentPrimary = OrganizationRoleTheme.primary;
const Color _organizationStudentPrimaryDark = OrganizationRoleTheme.primaryDark;
const Color _organizationStudentSurface = OrganizationRoleTheme.surface;
const Color _organizationStudentBorder = OrganizationRoleTheme.border;
const Color _organizationStudentSurfaceSoft = OrganizationRoleTheme.surfaceSoft;
const Color _organizationSidebarMilk = Color(0xFFF8FAFC);

Map<String, dynamic>? _organizationProfileData(Map<String, dynamic>? user) {
  final companyData = user?['company_data'];
  if (companyData is Map<String, dynamic>) {
    return companyData;
  }

  final organizationData = user?['organization_data'];
  if (organizationData is Map<String, dynamic>) {
    return organizationData;
  }

  return null;
}

String _organizationDisplayName(
  Map<String, dynamic>? user,
  LanguageProvider language,
) {
  final profileData = _organizationProfileData(user);
  final candidates = [
    profileData?['company_name'],
    profileData?['organization_name'],
    user?['full_name'],
    user?['name'],
  ];

  for (final candidate in candidates) {
    final value = '${candidate ?? ''}'.trim();
    if (value.isNotEmpty) {
      return value;
    }
  }

  return language.tr('organization');
}

class OrganizationDashboard extends StatefulWidget {
  final int initialIndex;
  final String? initialTrainingId;
  final String? initialTrainingTitle;

  const OrganizationDashboard({
    super.key,
    this.initialIndex = 0,
    this.initialTrainingId,
    this.initialTrainingTitle,
  });

  @override
  State<OrganizationDashboard> createState() => _OrganizationDashboardState();
}

typedef _AcceptanceInputBuilder =
    Widget Function({
      required TextEditingController controller,
      required String label,
      String? hint,
      TextInputType keyboardType,
      int maxLines,
      bool readOnly,
      String? Function(String?)? validator,
    });

class _AcceptedApplicantsCell extends StatelessWidget {
  final String label;
  final double width;
  final bool isHeader;

  const _AcceptedApplicantsCell({
    required this.label,
    required this.width,
    this.isHeader = false,
  });

  @override
  Widget build(BuildContext context) {
    final text = label.trim().isEmpty ? 'N/A' : label.trim();

    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: isHeader ? 12.5 : 13,
            fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
            color: isHeader
                ? _organizationStudentPrimaryDark
                : Colors.grey.shade800,
          ),
        ),
      ),
    );
  }
}

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ApiService _apiService = ApiService();
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  final List<int> _tabHistory = [];

  String? _selectedTrainingId;
  String? _selectedTrainingTitle;

  String _formatToday(BuildContext context) {
    return MaterialLocalizations.of(context).formatFullDate(DateTime.now());
  }

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex >= 0 && widget.initialIndex <= 3
        ? widget.initialIndex
        : 0;
    _selectedTrainingId = widget.initialTrainingId;
    _selectedTrainingTitle = widget.initialTrainingTitle;
    _tabHistory.add(_currentIndex);
    _loadUnreadNotificationCount();
  }

  void _selectTraining(String trainingId, String trainingTitle) {
    navigateToTab(2, trainingId: trainingId, trainingTitle: trainingTitle);
  }

  void navigateToTab(int index, {String? trainingId, String? trainingTitle}) {
    setState(() {
      if (_currentIndex != index) {
        _tabHistory.add(index);
      }
      _currentIndex = index;
      _selectedTrainingId = trainingId;
      _selectedTrainingTitle = trainingTitle;
    });
  }

  bool _handleBackPress() {
    if (_tabHistory.length > 1) {
      final previousTab = _tabHistory[_tabHistory.length - 2];
      setState(() {
        _tabHistory.removeLast();
        _currentIndex = previousTab;
        if (previousTab != 2) {
          _selectedTrainingId = null;
          _selectedTrainingTitle = null;
        }
      });
      return false;
    }

    if (_currentIndex != 0) {
      setState(() {
        _currentIndex = 0;
        _selectedTrainingId = null;
        _selectedTrainingTitle = null;
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
      MaterialPageRoute(
        builder: (_) => const OrganizationNotificationsScreen(),
      ),
    );
    _loadUnreadNotificationCount(forceRefresh: true);
  }

  void _handleRouteNavigationResult(dynamic result) {
    if (result is Map && result['targetIndex'] is int) {
      navigateToTab(result['targetIndex'] as int);
    }
  }

  bool _isDesktopWidth(double width) => width >= 1100;

  String _tabLabel(LanguageProvider language, int index) {
    switch (index) {
      case 0:
        return language.tr('dashboard');
      case 1:
        return language.tr('my_training');
      case 2:
        return language.tr('applications');
      case 3:
        return language.tr('profile');
      default:
        return language.tr('dashboard');
    }
  }

  IconData _tabIcon(int index) {
    switch (index) {
      case 0:
        return Icons.dashboard_rounded;
      case 1:
        return Icons.work_rounded;
      case 2:
        return Icons.groups_rounded;
      case 3:
        return Icons.business_rounded;
      default:
        return Icons.dashboard_rounded;
    }
  }

  List<Widget> _buildScreens() {
    return [
      const OrganizationHomeScreen(),
      OrganizationtrainingScreen(selectTraining: _selectTraining),
      OrganizationApplicationsTab(
        key: ValueKey(_selectedTrainingId),
        trainingId: _selectedTrainingId,
        trainingTitle: _selectedTrainingTitle,
        onGoTotraining: () => navigateToTab(1),
      ),
      const OrganizationProfileScreen(),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _organizationStudentPrimary,
              foregroundColor: Colors.white,
            ),
            child: Text(language.tr('logout')),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await authProvider.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showAppSnackBar(
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
    ScaffoldMessenger.of(context).showAppSnackBar(
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
                  language.tr('organization_settings'),
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
                  title: Text(language.tr('organization_profile')),
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
                  subtitle: Text(
                    language.tr('open_organization_notifications'),
                  ),
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

  Future<void> _handleMoreAction(_OrganizationMoreAction action) async {
    switch (action) {
      case _OrganizationMoreAction.settings:
        await _showSettingsSheet();
        break;
      case _OrganizationMoreAction.language:
        await _showLanguageDialog();
        break;
      case _OrganizationMoreAction.logout:
        await _logout();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final user = context.watch<AuthProvider>().user;
    final organizationName = _organizationDisplayName(user, language);
    final today = _formatToday(context);
    final screens = _buildScreens();

    return PopScope(
      canPop: _tabHistory.length <= 1 && _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final shouldExit = _handleBackPress();
        if (shouldExit && mounted) {
          Navigator.of(context).pop(result);
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = _isDesktopWidth(constraints.maxWidth);

          Widget buildNotificationButton() {
            return IconButton(
              tooltip: language.tr('notifications'),
              onPressed: _openNotifications,
              icon: Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(
                    Icons.notifications_outlined,
                    color: _organizationStudentPrimary,
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
            );
          }

          Widget buildMoreMenu() {
            return PopupMenuButton<_OrganizationMoreAction>(
              tooltip: language.tr('more_actions'),
              onSelected: _handleMoreAction,
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: _OrganizationMoreAction.settings,
                  child: Row(
                    children: [
                      const Icon(Icons.settings_outlined, size: 18),
                      const SizedBox(width: 10),
                      Text(language.tr('settings')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: _OrganizationMoreAction.language,
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
                  value: _OrganizationMoreAction.logout,
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
                color: _organizationStudentPrimary,
              ),
            );
          }

          Widget buildDashboardHeader() {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: _organizationStudentBorder,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: _organizationStudentBorder),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/splash_logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.verified,
                            size: 32,
                            color: _organizationStudentPrimary,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'INDUSTRIAL PREACTICAL TRAINING',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _organizationStudentPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            organizationName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _organizationStudentPrimary,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: _organizationStudentPrimary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  today,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: _organizationStudentPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  buildNotificationButton(),
                  buildMoreMenu(),
                ],
              ),
            );
          }

          if (!isDesktop) {
            return Scaffold(
              body: SafeArea(
                child: Column(
                  children: [
                    buildDashboardHeader(),
                    Expanded(
                      child: IndexedStack(
                        index: _currentIndex,
                        children: screens,
                      ),
                    ),
                  ],
                ),
              ),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: (index) {
                  navigateToTab(index);
                  _loadUnreadNotificationCount();
                },
                selectedItemColor: _organizationStudentPrimary,
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
                    label: language.tr('my_training'),
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
            );
          }

          return Scaffold(
            backgroundColor: const Color(0xFFF5F7F2),
            body: SafeArea(
              child: Column(
                children: [
                  buildDashboardHeader(),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          width: 288,
                          margin: const EdgeInsets.all(18),
                          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                          decoration: BoxDecoration(
                            color: _organizationSidebarMilk,
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: _organizationStudentBorder.withValues(
                                alpha: 0.9,
                              ),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var index = 0; index < 4; index++) ...[
                                _OrganizationSidebarNavItem(
                                  label: _tabLabel(language, index),
                                  icon: _tabIcon(index),
                                  selected: _currentIndex == index,
                                  onTap: () {
                                    navigateToTab(index);
                                    _loadUnreadNotificationCount();
                                  },
                                ),
                                const SizedBox(height: 10),
                              ],
                              const Spacer(),
                            ],
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 18, 18, 18),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(32),
                                border: Border.all(
                                  color: _organizationStudentBorder.withValues(
                                    alpha: 0.8,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 28,
                                    offset: const Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(32),
                                child: Center(
                                  child: ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 1320,
                                    ),
                                    child: IndexedStack(
                                      index: _currentIndex,
                                      children: screens,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DashboardImageWithFallbacks extends StatefulWidget {
  final List<String> imageUrls;
  final BoxFit fit;
  final Widget emptyChild;

  const _DashboardImageWithFallbacks({
    required this.imageUrls,
    required this.fit,
    required this.emptyChild,
  });

  @override
  State<_DashboardImageWithFallbacks> createState() =>
      _DashboardImageWithFallbacksState();
}

class _DashboardImageWithFallbacksState
    extends State<_DashboardImageWithFallbacks> {
  int _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _DashboardImageWithFallbacks oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.join('|') != widget.imageUrls.join('|')) {
      _imageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty || _imageIndex >= widget.imageUrls.length) {
      return widget.emptyChild;
    }

    final currentUrl = widget.imageUrls[_imageIndex];
    return Image.network(
      currentUrl,
      key: ValueKey('$currentUrl-$_imageIndex'),
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        if (_imageIndex < widget.imageUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _imageIndex += 1);
          });
          return const SizedBox.expand();
        }
        return widget.emptyChild;
      },
    );
  }
}

class _OrganizationSidebarNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _OrganizationSidebarNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              Icon(icon, size: 20, color: _organizationStudentPrimaryDark),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: _organizationStudentPrimaryDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
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

String formatOrganizationStatus(String status, LanguageProvider language) {
  return status == 'open'
      ? language.tr('status_active')
      : language.tr('status_closed');
}

String formatTargetAudience(String target, LanguageProvider language) {
  switch (target) {
    case 'first_year':
      return language.tr('first_year');
    case 'second_year':
      return language.tr('second_year');
    case 'third_year':
    case 'third_year_plus':
      return language.tr('third_year_plus');
    default:
      return target;
  }
}

bool trainingHasApplicantConditions(Map<String, dynamic> training) {
  final targetCandidates = (training['target_candidates'] as List? ?? const [])
      .map((item) => '$item'.trim().toLowerCase())
      .where((item) => item.isNotEmpty)
      .toSet();
  final unrestrictedTargets =
      targetCandidates.contains('first_year') &&
      targetCandidates.contains('second_year') &&
      (targetCandidates.contains('third_year_plus') ||
          targetCandidates.contains('third_year'));

  final eligiblePrograms = (training['eligible_programs'] as List? ?? const [])
      .whereType<Object>()
      .toList();
  final requiredSkills = (training['required_skills'] as List? ?? const [])
      .whereType<Object>()
      .toList();
  final minimumGpa = '${training['minimum_gpa'] ?? ''}'.trim();
  final minimumAcademicYear = '${training['minimum_academic_year'] ?? ''}'
      .trim();
  final eligibilityNotes = '${training['eligibility_notes'] ?? ''}'.trim();

  return !unrestrictedTargets ||
      eligiblePrograms.isNotEmpty ||
      requiredSkills.isNotEmpty ||
      minimumGpa.isNotEmpty && minimumGpa != 'null' ||
      minimumAcademicYear.isNotEmpty && minimumAcademicYear != 'null' ||
      eligibilityNotes.isNotEmpty && eligibilityNotes != 'null';
}

String formatApplicantConditionMode(Map<String, dynamic> training) {
  final mode = '${training['eligibility_match_mode'] ?? 'all'}'
      .trim()
      .toLowerCase();
  return mode == 'any' ? 'Match any condition' : 'Match all conditions';
}

List<String> buildApplicantConditionLabels(
  Map<String, dynamic> training,
  LanguageProvider language,
) {
  final labels = <String>[];
  final targets = (training['target_candidates'] as List? ?? const [])
      .map((item) => '$item')
      .toList(growable: false);
  final unrestrictedTargets = targets
      .map((item) => item.trim().toLowerCase())
      .toSet();
  final isAllYears =
      unrestrictedTargets.contains('first_year') &&
      unrestrictedTargets.contains('second_year') &&
      (unrestrictedTargets.contains('third_year_plus') ||
          unrestrictedTargets.contains('third_year'));

  if (targets.isNotEmpty && !isAllYears) {
    labels.add(
      'Years: ${targets.map((target) => formatTargetAudience(target, language)).join(', ')}',
    );
  }

  final minimumAcademicYear = int.tryParse(
    '${training['minimum_academic_year'] ?? ''}',
  );
  if (minimumAcademicYear != null) {
    labels.add('Minimum year: $minimumAcademicYear+');
  }

  final programs = (training['eligible_programs'] as List? ?? const [])
      .map((item) => '$item'.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (programs.isNotEmpty) {
    labels.add('Programs: ${programs.join(', ')}');
  }

  final minimumGpa = '${training['minimum_gpa'] ?? ''}'.trim();
  if (minimumGpa.isNotEmpty && minimumGpa != 'null') {
    labels.add('Minimum GPA: $minimumGpa');
  }

  final skills = (training['required_skills'] as List? ?? const [])
      .map(
        (item) => item is Map ? '${item['name'] ?? ''}'.trim() : '$item'.trim(),
      )
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
  if (skills.isNotEmpty) {
    labels.add('Skills: ${skills.join(', ')}');
  }

  final notes = '${training['eligibility_notes'] ?? ''}'.trim();
  if (notes.isNotEmpty && notes != 'null') {
    labels.add('Notes: $notes');
  }

  return labels;
}

String formatApplicationStatus(String status, LanguageProvider language) {
  switch (status) {
    case 'shortlisted':
      return language.tr('status_shortlisted');
    case '':
      return language.tr('status_');
    case 'accepted':
      return language.tr('status_accepted');
    case 'rejected':
      return language.tr('status_rejected');
    case 'pending':
    default:
      return language.tr('status_pending');
  }
}

// ============ ORGANIZATION HOME SCREEN ============
class OrganizationHomeScreen extends StatefulWidget {
  const OrganizationHomeScreen({super.key});

  @override
  State<OrganizationHomeScreen> createState() => _OrganizationHomeScreenState();
}

class _OrganizationHomeScreenState extends State<OrganizationHomeScreen> {
  final ApiService _apiService = ApiService();
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  List<dynamic> _training = [];
  List<Map<String, dynamic>> _announcements = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final responses = await Future.wait([
        _apiService.getOrganizationtraining(forceRefresh: forceRefresh),
        _workspaceService.getAnnouncements(audience: 'organization'),
      ]);
      final trainingResponse = responses[0] as Map<String, dynamic>;
      final announcements = responses[1] as List<Map<String, dynamic>>;
      if (trainingResponse['success']) {
        setState(() {
          _training = trainingResponse['data'];
          _announcements = announcements;
          _isLoading = false;
        });
      } else {
        setState(() {
          _announcements = announcements;
          _isLoading = false;
        });
      }
    } catch (e) {
      final announcements = await _workspaceService.getAnnouncements(
        audience: 'organization',
      );
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _isLoading = false;
      });
    }
  }

  void _goTotrainingTab() {
    final dashboard = context
        .findAncestorStateOfType<_OrganizationDashboardState>();
    dashboard?.navigateToTab(1);
  }

  void _goToApplicationsTab() {
    final dashboard = context
        .findAncestorStateOfType<_OrganizationDashboardState>();
    dashboard?.navigateToTab(2);
  }

  Future<void> _openPostTraining({Map<String, dynamic>? training}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Posttrainingcreen(
          jobId:
              training?['training_id']?.toString() ??
              training?['job_id']?.toString(),
          initialJobData: training,
        ),
      ),
    );
    if (!mounted) return;
    final dashboard = context
        .findAncestorStateOfType<_OrganizationDashboardState>();
    dashboard?._handleRouteNavigationResult(result);
    _loadData(forceRefresh: true);
  }

  Future<void> _openAnnouncementFeed() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const OrganizationNotificationsScreen(),
      ),
    );
  }

  String _formatAnnouncementDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    final month = parsed.month.toString().padLeft(2, '0');
    final day = parsed.day.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  Widget _buildRecentTrainingStatusChip(String status) {
    final isActive = status == 'open';
    final language = context.read<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        formatOrganizationStatus(status, language),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }

  void _showStatsDialog(BuildContext context) {
    final language = context.read<LanguageProvider>();
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final organizationName = _organizationDisplayName(user, language);

    int totalApplicants = 0;
    int activetraining = 0;
    int closedtraining = 0;

    for (var training in _training) {
      if (training['status'] == 'open') {
        activetraining++;
      } else {
        closedtraining++;
      }
      totalApplicants += getApplicantsCount(training['applications_count']);
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
              language.tr('organization_statistics'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatRow(language.tr('organization_name'), organizationName),
            const Divider(),
            _buildStatRow(language.tr('total_training'), '${_training.length}'),
            _buildStatRow(
              language.tr('active_training'),
              activetraining.toString(),
              color: Colors.green,
            ),
            _buildStatRow(
              language.tr('closed_training'),
              closedtraining.toString(),
              color: Colors.red,
            ),
            const Divider(),
            _buildStatRow(
              language.tr('total_applicants'),
              totalApplicants.toString(),
              color: Colors.blue,
            ),
            _buildStatRow(
              language.tr('average_per_training'),
              _training.isEmpty
                  ? '0'
                  : (totalApplicants / _training.length).toStringAsFixed(1),
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

  Widget _buildAnnouncementSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'University Announcements',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton(
              onPressed: _openAnnouncementFeed,
              child: const Text('View all'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_announcements.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _organizationStudentBorder),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 42,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(height: 10),
                const Text(
                  'No university announcements yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17324D),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Announcements posted by coordinators for companies will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          )
        else
          Column(
            children: _announcements
                .take(3)
                .map((announcement) {
                  final universityName =
                      '${announcement['university_name'] ?? 'University'}';
                  final title = '${announcement['title'] ?? 'Announcement'}';
                  final message = '${announcement['message'] ?? ''}';
                  final date = _formatAnnouncementDate(
                    '${announcement['created_at'] ?? ''}',
                  );

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: _organizationStudentBorder),
                      boxShadow: [
                        BoxShadow(
                          color: _organizationStudentPrimary.withValues(
                            alpha: 0.06,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _organizationStudentSurface,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                universityName,
                                style: const TextStyle(
                                  color: _organizationStudentPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              date,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17324D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }

  Widget _buildOrganizationHeaderCard({
    required String organizationName,
    required int totaltraining,
    required int totalApplicants,
  }) {
    final language = context.read<LanguageProvider>();
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _organizationStudentPrimary,
            _organizationStudentPrimaryDark,
          ],
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
                      language.tr('welcome_name', {'name': organizationName}),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
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
                  onTap: _goTotrainingTab,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        Text(
                          totaltraining.toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          language.tr('total_training'),
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
    final organizationName = _organizationDisplayName(user, language);

    int totalApplicants = 0;
    final totaltraining = _training.length;

    for (var training in _training) {
      totalApplicants += getApplicantsCount(training['applications_count']);
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
            child: _buildOrganizationHeaderCard(
              organizationName: organizationName,
              totaltraining: totaltraining,
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final actions = [
                        (
                          icon: Icons.add_circle_outline,
                          title: language.tr('post_training'),
                          color: Colors.blue,
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const Posttrainingcreen(),
                              ),
                            );
                            if (!context.mounted) return;
                            final dashboard = context
                                .findAncestorStateOfType<
                                  _OrganizationDashboardState
                                >();
                            dashboard?._handleRouteNavigationResult(result);
                            _loadData(forceRefresh: true);
                          },
                        ),
                        (
                          icon: Icons.people_outline,
                          title: language.tr('view_training'),
                          color: Colors.green,
                          onTap: () {
                            final dashboard = context
                                .findAncestorStateOfType<
                                  _OrganizationDashboardState
                                >();
                            dashboard?.navigateToTab(1);
                          },
                        ),
                        (
                          icon: Icons.analytics,
                          title: language.tr('statistics'),
                          color: Colors.purple,
                          onTap: () {
                            _showStatsDialog(context);
                          },
                        ),
                      ];
                      final columns = constraints.maxWidth >= 780
                          ? 3
                          : constraints.maxWidth >= 360
                          ? 2
                          : 1;
                      final cardWidth =
                          (constraints.maxWidth - ((columns - 1) * 12)) /
                          columns;

                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: actions
                            .map(
                              (action) => SizedBox(
                                width: cardWidth,
                                child: _buildActionCard(
                                  icon: action.icon,
                                  title: action.title,
                                  color: action.color,
                                  onTap: action.onTap,
                                ),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  _buildAnnouncementSection(),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        language.tr('recent_training_postings'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          final dashboard = context
                              .findAncestorStateOfType<
                                _OrganizationDashboardState
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
                      : _training.isEmpty
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
                              Text(language.tr('no_training_posted_yet')),
                              Text(language.tr('click_create_first_training')),
                            ],
                          ),
                        )
                      : Column(
                          children: _training.take(3).map((training) {
                            return _buildTrainingCard(training);
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
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
            SizedBox(
              height: 34,
              child: Center(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainingCard(dynamic training) {
    final language = context.read<LanguageProvider>();
    final deadlineText = getDaysLeft(
      training['application_deadline'],
      language,
    );
    final deadlineLabel = formatDeadlineDateTime(
      training['application_deadline'],
      language,
    );
    final title = '${training['title'] ?? language.tr('untitled_training')}';
    final trainingId = '${training['training_id']}';
    final applicants = getApplicantsCount(training['applications_count']);
    final requiredApplicants = getApplicantsCount(
      training['required_applicants'],
    );
    final targetCandidates =
        (training['target_candidates'] as List? ?? const [])
            .take(3)
            .toList(growable: false);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _organizationStudentBorder.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: _organizationStudentPrimaryDark.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _organizationStudentPrimaryDark,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 14,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${training['location'] ?? language.tr('location_not_specified')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: _organizationStudentSurfaceSoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _organizationStudentBorder),
                        ),
                        child: Text(
                          '$deadlineLabel • $deadlineText',
                          style: const TextStyle(
                            color: _organizationStudentPrimaryDark,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _buildRecentTrainingStatusChip(
                  '${training['status'] ?? 'closed'}',
                ),
              ],
            ),
            if (targetCandidates.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: targetCandidates
                    .map(
                      (target) => Container(
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
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final itemWidth = compact
                    ? (constraints.maxWidth - 8) / 2
                    : (constraints.maxWidth - 24) / 4;

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _OrganizationTrainingMetaActionCard(
                        icon: Icons.groups_rounded,
                        label: language.tr('applicants_count', {
                          'count': '$applicants',
                        }),
                        tint: _organizationStudentPrimary,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _OrganizationTrainingMetaActionCard(
                        icon: Icons.person_add_alt_1_rounded,
                        label: language.tr('needed_count', {
                          'count': '$requiredApplicants',
                        }),
                        tint: const Color(0xFFAF7A0F),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _OrganizationTrainingMetaActionCard(
                        icon: Icons.edit_outlined,
                        label: language.tr('edit_training'),
                        tint: _organizationStudentPrimaryDark,
                        isAction: true,
                        onTap: () => _openPostTraining(
                          training: Map<String, dynamic>.from(training),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _OrganizationTrainingMetaActionCard(
                        icon: Icons.assignment_turned_in_outlined,
                        label: language.tr('applications'),
                        tint: _organizationStudentPrimary,
                        isAction: true,
                        onTap: () {
                          context
                              .findAncestorStateOfType<
                                _OrganizationDashboardState
                              >()
                              ?.navigateToTab(
                                2,
                                trainingId: trainingId,
                                trainingTitle: title,
                              );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class OrganizationtrainingScreen extends StatefulWidget {
  final void Function(String trainingId, String trainingTitle) selectTraining;

  const OrganizationtrainingScreen({super.key, required this.selectTraining});

  @override
  State<OrganizationtrainingScreen> createState() =>
      _OrganizationtrainingScreenState();
}

class _OrganizationtrainingScreenState
    extends State<OrganizationtrainingScreen> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _training = [];

  bool _isOpenTraining(dynamic training) {
    return '${training['status'] ?? ''}'.toLowerCase() == 'open';
  }

  DateTime _parseSortableDate(dynamic value) {
    return DateTime.tryParse('${value ?? ''}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  List<dynamic> get _visibletraining {
    final training = List<dynamic>.from(_training);
    training.sort((a, b) {
      final aOpen = _isOpenTraining(a);
      final bOpen = _isOpenTraining(b);
      if (aOpen != bOpen) {
        return aOpen ? -1 : 1;
      }

      final aCreated = _parseSortableDate(a['created_at']);
      final bCreated = _parseSortableDate(b['created_at']);
      return bCreated.compareTo(aCreated);
    });
    return training;
  }

  @override
  void initState() {
    super.initState();
    _loadtraining();
  }

  Future<void> _loadtraining({bool forceRefresh = false}) async {
    final language = context.read<LanguageProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _apiService.getOrganizationtraining(
        forceRefresh: forceRefresh,
      );
      if (response['success'] == true) {
        setState(() {
          _training = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = ApiService.responseMessage(
            response,
            fallback: language.tr('failed_to_load_training'),
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = ApiService.normalizeErrorMessage(
          e,
          fallback: language.tr('failed_to_load_training'),
        );
        _isLoading = false;
      });
    }
  }

  Future<void> _openPostTraining({Map<String, dynamic>? training}) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Posttrainingcreen(
          jobId:
              training?['training_id']?.toString() ??
              training?['job_id']?.toString(),
          initialJobData: training,
        ),
      ),
    );
    if (!mounted) return;
    final dashboard = context
        .findAncestorStateOfType<_OrganizationDashboardState>();
    dashboard?._handleRouteNavigationResult(result);
    _loadtraining(forceRefresh: true);
  }

  void _goToApplicationsTab() {
    final dashboard = context
        .findAncestorStateOfType<_OrganizationDashboardState>();
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
        color: _organizationStudentSurface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: language.tr('my_training'),
            icon: Icons.work_rounded,
            selected: true,
            onTap: () {},
            color: _organizationStudentPrimary,
          ),
          const SizedBox(width: 6),
          navItem(
            label: language.tr('applications'),
            icon: Icons.groups_rounded,
            selected: false,
            onTap: _goToApplicationsTab,
            color: _organizationStudentPrimary,
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
        formatOrganizationStatus(status, language),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isActive ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }

  Widget _buildtrainingList() {
    final language = context.read<LanguageProvider>();
    final visibletraining = _visibletraining;
    if (visibletraining.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.work_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(language.tr('no_training_posted_yet')),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Posttrainingcreen(),
                    ),
                  );
                  if (!mounted) return;
                  final dashboard = context
                      .findAncestorStateOfType<_OrganizationDashboardState>();
                  dashboard?._handleRouteNavigationResult(result);
                  _loadtraining(forceRefresh: true);
                },
                icon: const Icon(Icons.add),
                label: Text(language.tr('post_training')),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadtraining(forceRefresh: true),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: visibletraining.length,
        itemBuilder: (context, index) {
          final training = visibletraining[index];
          final title =
              '${training['title'] ?? language.tr('untitled_training')}';
          final trainingId = '${training['training_id']}';
          final applicants = getApplicantsCount(training['applications_count']);
          final requiredApplicants = getApplicantsCount(
            training['required_applicants'],
          );
          final deadlineText = getDaysLeft(
            training['application_deadline'],
            language,
          );
          final deadlineLabel = formatDeadlineDateTime(
            training['application_deadline'],
            language,
          );

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _organizationStudentBorder),
              boxShadow: [
                BoxShadow(
                  color: _organizationStudentPrimary.withValues(alpha: 0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
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
                              title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: _organizationStudentPrimaryDark,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${training['location'] ?? language.tr('location_not_specified')}',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: _organizationStudentSurfaceSoft,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: _organizationStudentBorder,
                                ),
                              ),
                              child: Text(
                                '$deadlineLabel • $deadlineText',
                                style: const TextStyle(
                                  color: _organizationStudentPrimaryDark,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _buildStatusChip('${training['status'] ?? 'closed'}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: (training['target_candidates'] as List? ?? [])
                        .map((target) {
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
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 620;
                      final itemWidth = compact
                          ? (constraints.maxWidth - 8) / 2
                          : (constraints.maxWidth - 24) / 4;

                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          SizedBox(
                            width: itemWidth,
                            child: _OrganizationTrainingMetaActionCard(
                              icon: Icons.groups_rounded,
                              label: language.tr('applicants_count', {
                                'count': '$applicants',
                              }),
                              tint: _organizationStudentPrimary,
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _OrganizationTrainingMetaActionCard(
                              icon: Icons.person_add_alt_1_rounded,
                              label: language.tr('needed_count', {
                                'count': '$requiredApplicants',
                              }),
                              tint: const Color(0xFFAF7A0F),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _OrganizationTrainingMetaActionCard(
                              icon: Icons.edit_outlined,
                              label: language.tr('edit_training'),
                              tint: _organizationStudentPrimaryDark,
                              isAction: true,
                              onTap: () =>
                                  _openPostTraining(training: training),
                            ),
                          ),
                          SizedBox(
                            width: itemWidth,
                            child: _OrganizationTrainingMetaActionCard(
                              icon: Icons.assignment_turned_in_outlined,
                              label: language.tr('applications'),
                              tint: _organizationStudentPrimary,
                              isAction: true,
                              onTap: () =>
                                  widget.selectTraining(trainingId, title),
                            ),
                          ),
                        ],
                      );
                    },
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
                onPressed: () => _loadtraining(forceRefresh: true),
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
        Expanded(child: _buildtrainingList()),
      ],
    );
  }
}

class OrganizationApplicationsTab extends StatefulWidget {
  final String? trainingId;
  final String? trainingTitle;
  final VoidCallback? onGoTotraining;
  final String secondaryNavigationLabel;
  final String emptyActionLabel;

  const OrganizationApplicationsTab({
    super.key,
    required this.trainingId,
    required this.trainingTitle,
    this.onGoTotraining,
    this.secondaryNavigationLabel = 'My training',
    this.emptyActionLabel = 'Go to training',
  });

  @override
  State<OrganizationApplicationsTab> createState() =>
      _OrganizationApplicationsTabState();
}

class _OrganizationTrainingMetaActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color tint;
  final bool isAction;
  final VoidCallback? onTap;

  const _OrganizationTrainingMetaActionCard({
    required this.icon,
    required this.label,
    required this.tint,
    this.isAction = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: isAction ? 0.1 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
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

class _OrganizationApplicationsTabState
    extends State<OrganizationApplicationsTab> {
  final ApiService _apiService = ApiService();
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  bool _isLoading = false;
  bool _isExportingAcceptedApplicants = false;
  String _applicationFilter = 'all';
  String? _error;
  List<dynamic> _applications = [];
  Map<String, Map<String, dynamic>> _studentSelectionsByEmail = const {};
  Map<String, Map<String, dynamic>> _approvalByApplicationId = const {};
  final Set<String> _downloadingResponseLetters = <String>{};

  String _formatErrorMessage(Object error) {
    final language = context.read<LanguageProvider>();
    final message = ApiService.normalizeErrorMessage(
      error,
      fallback: language.tr('something_went_wrong'),
    );
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

  bool _canUseDirectFileFallback(String? fileUrl) {
    final trimmed = (fileUrl ?? '').trim();
    return trimmed.startsWith('http://') || trimmed.startsWith('https://');
  }

  Future<void> _openFileUrl(
    String? fileUrl, {
    required String invalidMessage,
    required String failureMessage,
  }) async {
    if (fileUrl == null || fileUrl.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final uri = Uri.tryParse(_resolveFileUrl(fileUrl));
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(invalidMessage), backgroundColor: Colors.red),
      );
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(failureMessage), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _openAuthenticatedPdfInBrowser(
    String pathOrUrl, {
    required String fileName,
    required String failureMessage,
  }) async {
    final bytes = await _apiService.downloadFileBytes(
      pathOrUrl,
      requiresAuth: true,
    );
    final opened = await openPdfBytesInBrowser(bytes, fileName: fileName);
    if (!opened) {
      throw Exception(failureMessage);
    }
  }

  Future<Directory> _getDownloadDirectory() async {
    if (Platform.isAndroid) {
      return getApplicationDocumentsDirectory();
    }

    final downloads = await getDownloadsDirectory();
    if (downloads != null) return downloads;

    return getApplicationDocumentsDirectory();
  }

  String _sanitizeFileName(String fileName) {
    final trimmed = fileName.trim();
    final fallback =
        'response_letter_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final normalized = trimmed.isEmpty ? fallback : trimmed;
    return normalized.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  Future<String> _downloadToAvailableDirectory(
    String pathOrUrl, {
    required String fileName,
    bool requiresAuth = false,
  }) async {
    final directories = <Directory>[];

    final preferredDirectory = await _getDownloadDirectory();
    directories.add(preferredDirectory);

    final appDirectory = await getApplicationDocumentsDirectory();
    if (!directories.any((directory) => directory.path == appDirectory.path)) {
      directories.add(appDirectory);
    }

    Object? lastError;

    for (final directory in directories) {
      final savePath = '${directory.path}/$fileName';

      try {
        if (!await directory.exists()) {
          await directory.create(recursive: true);
        }

        final bytes = await _apiService.downloadFileBytes(
          pathOrUrl,
          requiresAuth: requiresAuth,
        );
        await File(savePath).writeAsBytes(bytes, flush: true);
        return savePath;
      } catch (error) {
        lastError = error;
        if (kDebugMode) {
          debugPrint('Response letter download failed for $savePath: $error');
        }
      }
    }

    throw lastError ?? Exception('Unable to save file');
  }

  Future<bool> _openLocalFile(String filePath) async {
    return LocalFileService.openFile(filePath);
  }

  Future<void> _downloadResponseLetter({
    required String applicationId,
    required String fileName,
    String? directFileUrl,
  }) async {
    final endpointPath = '/api/applications/$applicationId/response-letter';

    if (kIsWeb) {
      try {
        await _openAuthenticatedPdfInBrowser(
          endpointPath,
          fileName: _sanitizeFileName(fileName),
          failureMessage: 'Unable to open response letter.',
        );
      } catch (error) {
        if (_canUseDirectFileFallback(directFileUrl)) {
          await _openFileUrl(
            directFileUrl,
            invalidMessage: 'Response letter link is invalid.',
            failureMessage: 'Failed to download response letter',
          );
          return;
        }

        final message = ApiService.normalizeErrorMessage(
          error,
          fallback: 'Failed to download response letter',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text('Failed to download response letter: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    setState(() => _downloadingResponseLetters.add(applicationId));

    try {
      final safeFileName = _sanitizeFileName(fileName);
      final savePath = await _downloadToAvailableDirectory(
        endpointPath,
        fileName: safeFileName,
        requiresAuth: true,
      );
      final finalPath = Platform.isAndroid
          ? await LocalFileService.copyFileToDownloads(
              savePath,
              fileName: safeFileName,
            )
          : savePath;

      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Response letter downloaded to: $finalPath'),
          backgroundColor: Colors.green,
        ),
      );
    } on DioException catch (error) {
      if (_canUseDirectFileFallback(directFileUrl)) {
        final safeFileName = _sanitizeFileName(fileName);
        final savePath = await _downloadToAvailableDirectory(
          directFileUrl!,
          fileName: safeFileName,
        );
        final finalPath = Platform.isAndroid
            ? await LocalFileService.copyFileToDownloads(
                savePath,
                fileName: safeFileName,
              )
            : savePath;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text('Response letter downloaded to: $finalPath'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final responseData = error.response?.data;
      final message = ApiService.normalizeErrorMessage(
        responseData is Map<String, dynamic>
            ? (responseData['message'] ??
                  responseData['error'] ??
                  error.message)
            : error,
        fallback: 'Failed to download response letter',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to download response letter: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (error) {
      if (_canUseDirectFileFallback(directFileUrl)) {
        final safeFileName = _sanitizeFileName(fileName);
        final savePath = await _downloadToAvailableDirectory(
          directFileUrl!,
          fileName: safeFileName,
        );
        final finalPath = Platform.isAndroid
            ? await LocalFileService.copyFileToDownloads(
                savePath,
                fileName: safeFileName,
              )
            : savePath;

        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text('Response letter downloaded to: $finalPath'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final message = ApiService.normalizeErrorMessage(
        error,
        fallback: 'Failed to download response letter',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to download response letter: $message'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _downloadingResponseLetters.remove(applicationId));
      }
    }
  }

  Future<void> _openSupportiveDocument({
    required String applicationId,
    required String fileName,
    String? directFileUrl,
  }) async {
    final endpointPath = '/api/applications/$applicationId/supportive-document';

    if (kIsWeb) {
      try {
        await _openAuthenticatedPdfInBrowser(
          endpointPath,
          fileName: _sanitizeFileName(fileName),
          failureMessage: 'Unable to open supportive document.',
        );
      } catch (error) {
        if (_canUseDirectFileFallback(directFileUrl)) {
          await _openFileUrl(
            directFileUrl,
            invalidMessage: 'Supportive document link is invalid.',
            failureMessage: 'Unable to open supportive document.',
          );
          return;
        }

        final message = ApiService.normalizeErrorMessage(
          error,
          fallback: 'Failed to open supportive document',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text('Failed to open supportive document: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final savePath = await _downloadToAvailableDirectory(
        endpointPath,
        fileName: _sanitizeFileName(fileName),
        requiresAuth: true,
      );

      final opened = await _openLocalFile(savePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Supportive document opened from: $savePath'
                : 'Supportive document downloaded to: $savePath',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (_canUseDirectFileFallback(directFileUrl)) {
        await _openFileUrl(
          directFileUrl,
          invalidMessage: 'Supportive document link is invalid.',
          failureMessage: 'Unable to open supportive document.',
        );
        return;
      }

      final message = ApiService.normalizeErrorMessage(
        error,
        fallback: 'Failed to open supportive document',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to open supportive document: $message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _openCoverLetter({
    required String applicationId,
    String? directFileUrl,
  }) async {
    final endpointPath = '/api/applications/$applicationId/cover-letter';

    if (kIsWeb) {
      try {
        await _openAuthenticatedPdfInBrowser(
          endpointPath,
          fileName: 'cover_letter.pdf',
          failureMessage: 'Unable to open cover letter.',
        );
      } catch (error) {
        if (_canUseDirectFileFallback(directFileUrl)) {
          await _openFileUrl(
            directFileUrl,
            invalidMessage: 'Cover letter link is invalid.',
            failureMessage: 'Unable to open cover letter.',
          );
          return;
        }

        final message = ApiService.normalizeErrorMessage(
          error,
          fallback: 'Failed to open cover letter',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text('Failed to open cover letter: $message'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      final savePath = await _downloadToAvailableDirectory(
        endpointPath,
        fileName: 'cover_letter.pdf',
        requiresAuth: true,
      );

      final opened = await _openLocalFile(savePath);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Cover letter opened from: $savePath'
                : 'Cover letter downloaded to: $savePath',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (_canUseDirectFileFallback(directFileUrl)) {
        await _openFileUrl(
          directFileUrl,
          invalidMessage: 'Cover letter link is invalid.',
          failureMessage: 'Unable to open cover letter.',
        );
        return;
      }

      final message = ApiService.normalizeErrorMessage(
        error,
        fallback: 'Failed to open cover letter',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to open cover letter: $message'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadApplications();
  }

  @override
  void didUpdateWidget(covariant OrganizationApplicationsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trainingId != widget.trainingId ||
        oldWidget.trainingTitle != widget.trainingTitle) {
      _applicationFilter = 'all';
      _loadApplications();
    }
  }

  bool get _showAllApplications => widget.trainingId == null;

  int _countByStatus(String status) {
    if (status == 'accepted') {
      return _acceptedApplications.length;
    }

    return _applications
        .where((app) => '${app['status'] ?? 'pending'}' == status)
        .length;
  }

  bool _isStudentConfirmedForApplication(dynamic app) {
    final backendConfirmationStatus =
        '${app['student_confirmation_status'] ?? ''}'.trim().toLowerCase();
    if (backendConfirmationStatus == 'confirmed') {
      return true;
    }

    final email = '${app['email'] ?? ''}'.trim().toLowerCase();
    final selection = _studentSelectionsByEmail[email];
    final selectedApplicationId =
        '${selection?['selected_application_id'] ?? ''}'.trim();
    final applicationId = '${app['application_id'] ?? ''}'.trim();

    return selectedApplicationId.isNotEmpty &&
        applicationId.isNotEmpty &&
        selectedApplicationId == applicationId;
  }

  List<dynamic> get _acceptedApplications {
    return _applications
        .where(
          (app) =>
              '${app['status'] ?? 'pending'}' == 'accepted' &&
              !_isOfferConfirmationExpired('${app['application_id'] ?? ''}') &&
              _isStudentConfirmedForApplication(app),
        )
        .toList(growable: false);
  }

  List<dynamic> get _shortlistedApplications {
    return _applications
        .where((app) => '${app['status'] ?? 'pending'}' == 'shortlisted')
        .toList(growable: false);
  }

  bool _isOfferConfirmationExpired(String applicationId) {
    final approval = _approvalByApplicationId[applicationId.trim()];
    if (approval == null) return false;

    final choiceStatus = '${approval['student_choice_status'] ?? ''}'
        .trim()
        .toLowerCase();
    final organizationStatus =
        '${approval['organization_selection_status'] ?? ''}'
            .trim()
            .toLowerCase();

    return choiceStatus == 'expired' || organizationStatus == 'expired';
  }

  Future<void> _loadApplications() async {
    final language = context.read<LanguageProvider>();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = _showAllApplications
          ? await _apiService.getOrganizationApplications()
          : await _apiService.getJobApplications(widget.trainingId!);
      final selections = await _workspaceService.getStudentSelections();
      final approvals = await _workspaceService.getApprovalRecords();
      final selectionsByEmail = <String, Map<String, dynamic>>{};
      for (final selection in selections) {
        final email = '${selection['student_email'] ?? ''}'
            .trim()
            .toLowerCase();
        if (email.isEmpty) continue;
        selectionsByEmail[email] = selection;
      }
      final approvalsByApplicationId = <String, Map<String, dynamic>>{};
      for (final approval in approvals) {
        final applicationId = '${approval['application_id'] ?? ''}'.trim();
        if (applicationId.isEmpty ||
            approvalsByApplicationId.containsKey(applicationId)) {
          continue;
        }
        approvalsByApplicationId[applicationId] = approval;
      }

      if (response['success'] == true) {
        setState(() {
          _applications = response['data'] ?? [];
          _studentSelectionsByEmail = selectionsByEmail;
          _approvalByApplicationId = approvalsByApplicationId;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              response['message']?.toString() ??
              language.tr('failed_to_load_applications');
          _studentSelectionsByEmail = selectionsByEmail;
          _approvalByApplicationId = approvalsByApplicationId;
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

  String _formatDateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
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
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        keyboardType: keyboardType,
        maxLines: maxLines,
        scrollPadding: const EdgeInsets.only(bottom: 140),
        validator:
            validator ??
            (value) {
              if (value == null || value.trim().isEmpty) {
                return '$label is required';
              }
              return null;
            },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: readOnly
              ? const Icon(Icons.check_circle_outline_rounded, size: 18)
              : null,
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
    final trainingTitle =
        application['training_title']?.toString() ?? 'this position';
    final organizationAssets =
        context.read<AuthProvider>().user?['organization_data']
            as Map<String, dynamic>?;
    final organizationName =
        application['organization_name']?.toString() ??
        organizationAssets?['organization_name']?.toString() ??
        '';
    final registrationNumber =
        application['student_registration_number']?.toString() ??
        application['registration_number']?.toString() ??
        '';
    final collegeName =
        application['college_name']?.toString() ??
        application['university_name']?.toString() ??
        '';
    final organizationLocation =
        organizationAssets?['location']?.toString() ??
        application['organization_location']?.toString() ??
        '';
    final inferredLocation = _inferLocationDefaults(organizationLocation);
    final hasDigitalStamp =
        '${application['stamp_url'] ?? organizationAssets?['stamp_url'] ?? ''}'
            .trim()
            .isNotEmpty;
    final hasDigitalSignature =
        '${application['signature_url'] ?? organizationAssets?['signature_url'] ?? ''}'
            .trim()
            .isNotEmpty;
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AcceptanceLetterDialog(
        initialOrganizationName: organizationName,
        initialRegistrationNumber: registrationNumber,
        initialCollegeName: collegeName,
        initialOfficerRegion: inferredLocation['region'] ?? '',
        initialOfficerDistrict: inferredLocation['district'] ?? '',
        initialOfficerArea: inferredLocation['area'] ?? '',
        initialLetterDate: _formatDateOnly(DateTime.now()),
        studentName: studentName,
        trainingTitle: trainingTitle,
        hasDigitalStamp: hasDigitalStamp,
        hasDigitalSignature: hasDigitalSignature,
        buildInput: _buildAcceptanceLetterInput,
      ),
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

    final updated = await _updateStatus(
      applicationId,
      'accepted',
      reportingStartDate: reportingDates['reporting_start_date'],
      reportingEndDate: reportingDates['reporting_end_date'],
      acceptanceLetterData: acceptanceLetterData,
    );

    if (!updated) return;

    await _workspaceService.queueApprovalFromOrganization(
      applicationId: applicationId,
      studentName:
          application['full_name']?.toString() ??
          application['student_name']?.toString() ??
          'Student',
      studentEmail: application['email']?.toString() ?? '',
      universityName: application['university_name']?.toString() ?? '',
      organizationName:
          application['organization_name']?.toString() ?? 'Organization',
      jobTitle: application['training_title']?.toString() ?? 'Placement',
      reportingStartDate: reportingDates['reporting_start_date'],
      reportingEndDate: reportingDates['reporting_end_date'],
    );
    if (!mounted) return;
    await _loadApplications();
  }

  Future<void> _showReportStudentDialog(
    Map<String, dynamic> application,
  ) async {
    final descriptionController = TextEditingController();
    var issueType = 'absent';

    try {
      final payload = await showDialog<Map<String, String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('Report Student to University'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report this issue to ${application['university_name'] ?? 'the university'} coordinator for follow-up.',
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: issueType,
                    decoration: InputDecoration(
                      labelText: 'Issue type',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'absent',
                        child: Text('Student is not attending'),
                      ),
                      DropdownMenuItem(
                        value: 'left_without_permission',
                        child: Text('Left workplace without permission'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setDialogState(() => issueType = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    minLines: 4,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText:
                          'Explain what happened so the university can act quickly.',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final description = descriptionController.text.trim();
                  if (description.isEmpty) {
                    return;
                  }

                  Navigator.pop(context, {
                    'issue_type': issueType,
                    'description': description,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB42318),
                ),
                child: const Text('Send report'),
              ),
            ],
          ),
        ),
      );

      if (!mounted || payload == null) return;

      final currentUser = context.read<AuthProvider>().user;
      final organizationData =
          currentUser?['organization_data'] as Map<String, dynamic>?;
      final organizationName =
          application['organization_name']?.toString() ??
          organizationData?['organization_name']?.toString() ??
          'Organization';

      await _workspaceService.submitOrganizationReport(
        applicationId: '${application['application_id'] ?? ''}',
        studentName:
            application['full_name']?.toString() ??
            application['student_name']?.toString() ??
            'Student',
        studentEmail: application['email']?.toString() ?? '',
        universityName: application['university_name']?.toString() ?? '',
        organizationName: organizationName,
        jobTitle: application['training_title']?.toString() ?? 'Placement',
        issueType: payload['issue_type'] ?? 'absent',
        description: payload['description'] ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Report sent to the university successfully.'),
          backgroundColor: Colors.green,
        ),
      );
    } finally {
      descriptionController.dispose();
    }
  }

  Future<void> _rejectApplicant(String applicationId) async {
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
      await _updateStatus(applicationId, 'rejected', feedback: feedback.trim());
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
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ?? 'Document reviewed',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadApplications();
      } else {
        ScaffoldMessenger.of(context).showAppSnackBar(
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

  Future<bool> _updateStatus(
    String applicationId,
    String status, {
    String? feedback,
    String? scheduledDate,
    String? scheduledVenue,
    String? reportingStartDate,
    String? reportingEndDate,
    Map<String, dynamic>? acceptanceLetterData,
  }) async {
    final language = context.read<LanguageProvider>();
    try {
      final response = await _apiService.updateApplicationStatusWithLetter(
        applicationId: applicationId,
        status: status,
        feedback: feedback,
        scheduledDate: scheduledDate,
        scheduledVenue: scheduledVenue,
        reportingStartDate: reportingStartDate,
        reportingEndDate: reportingEndDate,
        acceptanceLetterData: acceptanceLetterData,
      );

      if (response['success'] == true) {
        if (!mounted) return false;
        ScaffoldMessenger.of(context).showAppSnackBar(
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
        return true;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ??
                  language.tr('failed_to_update_status'),
            ),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(_formatErrorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }

    return false;
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'shortlisted':
        return const Color(0xFF5C7FA3);
      case '':
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
      case '':
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
    const order = ['pending', 'shortlisted', '', 'accepted'];
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
        minimumSize: const Size(0, 42),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12.8,
          fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
    );
  }

  void _showAllApplicationsFromTop() {
    final dashboard = context
        .findAncestorStateOfType<_OrganizationDashboardState>();
    dashboard?.navigateToTab(2);
  }

  String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  List<dynamic> _applicationsForCurrentExport() {
    return switch (_applicationFilter) {
      'accepted' => _acceptedApplications,
      'shortlisted' => _shortlistedApplications,
      _ => _applications,
    };
  }

  String _currentExportLabel() {
    return switch (_applicationFilter) {
      'accepted' => 'accepted students',
      'shortlisted' => 'shortlisted students',
      _ => 'total students',
    };
  }

  String _buildApplicationsCsv(List<dynamic> applications) {
    final headers = [
      'Applicant Name',
      'Email',
      'University',
      'Phone number',
      'Serial no',
      'Training Title',
      'Status',
      'Organization Confirmed',
      'Reporting Start',
      'Reporting End',
    ];

    final rows = applications
        .map((app) {
          final email = '${app['email'] ?? ''}'.trim().toLowerCase();
          final selection = _studentSelectionsByEmail[email];
          final selectedApplicationId =
              '${selection?['selected_application_id'] ?? ''}'.trim();
          final isConfirmed =
              selectedApplicationId == '${app['application_id']}';
          return [
            '${app['full_name'] ?? ''}',
            '${app['email'] ?? ''}',
            '${app['university_name'] ?? ''}',
            '${app['phone'] ?? ''}',
            '${app['student_registration_number'] ?? app['registration_number'] ?? ''}',
            '${app['training_title'] ?? ''}',
            '${app['status'] ?? ''}',
            isConfirmed ? 'Yes' : 'No',
            '${app['reporting_start_date'] ?? ''}',
            '${app['reporting_end_date'] ?? ''}',
          ];
        })
        .toList(growable: false);

    final buffer = StringBuffer()
      ..writeln(headers.map(_escapeCsvCell).join(','));

    for (final row in rows) {
      buffer.writeln(row.map((cell) => _escapeCsvCell(cell)).join(','));
    }

    return buffer.toString();
  }

  Future<void> _exportVisibleApplications() async {
    final applications = _applicationsForCurrentExport();
    final exportLabel = _currentExportLabel();

    if (applications.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('No $exportLabel available yet.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isExportingAcceptedApplicants = true);

    try {
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final csv = _buildApplicationsCsv(applications);
      final savedPath = await saveExportFile(
        fileName: '${exportLabel.replaceAll(' ', '_')}_$timestamp.csv',
        bytes: Uint8List.fromList(utf8.encode(csv)),
        mimeType: 'text/csv',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('${_currentExportLabel()} exported to $savedPath'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to export ${_currentExportLabel()}: $error'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isExportingAcceptedApplicants = false);
      }
    }
  }

  void _showAcceptedApplicants() {
    setState(() => _applicationFilter = 'accepted');
  }

  void _showShortlistedApplications() {
    setState(() => _applicationFilter = 'shortlisted');
  }

  void _showAllApplicationsList() {
    setState(() => _applicationFilter = 'all');
  }

  Widget _buildApplicationsExportButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton.icon(
          onPressed: _isExportingAcceptedApplicants
              ? null
              : _exportVisibleApplications,
          style: ElevatedButton.styleFrom(
            backgroundColor: _organizationStudentPrimary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isExportingAcceptedApplicants
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.download_rounded, size: 18),
          label: Text(
            _isExportingAcceptedApplicants
                ? 'Exporting...'
                : 'Download ${_currentExportLabel()}',
          ),
        ),
      ],
    );
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
        color: _organizationStudentSurface,
        border: Border.all(
          color: _organizationStudentBorder.withValues(alpha: 0.9),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: language.tr('all_applications'),
            icon: Icons.grid_view_rounded,
            selected: true,
            onTap: () {
              if (!_showAllApplications) {
                _showAllApplicationsFromTop();
              }
            },
            color: _organizationStudentPrimary,
          ),
          const SizedBox(width: 6),
          navItem(
            label: widget.secondaryNavigationLabel,
            icon: Icons.work_outline_rounded,
            selected: false,
            onTap: () => widget.onGoTotraining?.call(),
            color: _organizationStudentPrimary,
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedApplicantsList() {
    final acceptedApplicants = _acceptedApplications;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _organizationStudentBorder),
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
                    const Text(
                      'Accepted students',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: _organizationStudentPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${acceptedApplicants.length} student(s) accepted.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _showAllApplicationsList,
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('All applications'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildApplicationsExportButton(),
          const SizedBox(height: 14),
          if (acceptedApplicants.isEmpty)
            Text(
              'No accepted students yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAcceptedApplicantsTableHeader(),
                  const SizedBox(height: 8),
                  ...acceptedApplicants.map(_buildAcceptedApplicantTableRow),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAcceptedApplicantsTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _organizationStudentSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _organizationStudentBorder),
      ),
      child: Row(
        children: const [
          _AcceptedApplicantsCell(label: 'Name', width: 180, isHeader: true),
          _AcceptedApplicantsCell(label: 'Email', width: 220, isHeader: true),
          _AcceptedApplicantsCell(
            label: 'University',
            width: 220,
            isHeader: true,
          ),
          _AcceptedApplicantsCell(
            label: 'Phone number',
            width: 150,
            isHeader: true,
          ),
          _AcceptedApplicantsCell(
            label: 'Serial no',
            width: 140,
            isHeader: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptedApplicantTableRow(dynamic app) {
    final fullName = '${app['full_name'] ?? 'Applicant'}'.trim();
    final email = '${app['email'] ?? 'N/A'}'.trim();
    final universityName = '${app['university_name'] ?? 'N/A'}'.trim();
    final phoneNumber = '${app['phone'] ?? 'N/A'}'.trim();
    final serialNumber =
        '${app['student_registration_number'] ?? app['registration_number'] ?? 'N/A'}'
            .trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: _organizationStudentSurfaceSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _organizationStudentBorder),
      ),
      child: Row(
        children: [
          _AcceptedApplicantsCell(label: fullName, width: 180),
          _AcceptedApplicantsCell(label: email, width: 220),
          _AcceptedApplicantsCell(label: universityName, width: 220),
          _AcceptedApplicantsCell(label: phoneNumber, width: 150),
          _AcceptedApplicantsCell(label: serialNumber, width: 140),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    bool isSelected = false,
    VoidCallback? onTap,
  }) {
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isSelected ? color.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? color.withValues(alpha: 0.5)
              : color.withValues(alpha: 0.2),
          width: isSelected ? 1.4 : 1,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: _organizationStudentPrimaryDark,
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

    if (onTap == null) {
      return card;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _buildApplicationCard(dynamic app) {
    final language = context.read<LanguageProvider>();
    final fullName = '${app['full_name'] ?? language.tr('unknown_applicant')}';
    final email = '${app['email'] ?? language.tr('no_email')}';
    final status = '${app['status'] ?? 'pending'}';
    final selection = _studentSelectionsByEmail[email.trim().toLowerCase()];
    final statusColor = _statusColor(status);
    final applicationId = '${app['application_id']}';
    final trainingTitle =
        '${app['training_title'] ?? widget.trainingTitle ?? language.tr('selected_training')}';
    final coverLetterUrl = app['cover_letter']?.toString() ?? '';
    final hasCoverLetter =
        coverLetterUrl.trim().startsWith('http://') ||
        coverLetterUrl.trim().startsWith('https://') ||
        coverLetterUrl.trim().startsWith('/');
    final supportiveDocumentUrl = app['supportive_document_url']?.toString();
    final supportiveDocumentName =
        app['supportive_document_name']?.toString() ??
        'supportive_document.pdf';
    final responseLetterUrl = app['response_letter_url']?.toString();
    final responseLetterName =
        app['response_letter_name']?.toString() ?? 'response_letter.pdf';
    final isDownloadingResponseLetter = _downloadingResponseLetters.contains(
      applicationId,
    );
    final verificationNotes = app['supportive_document_verification_notes']
        ?.toString();
    final hasSupportiveDocument =
        supportiveDocumentUrl != null && supportiveDocumentUrl.isNotEmpty;
    final documentReviewed = app['supportive_document_verified'] != null;
    final isDocumentAuthentic = app['supportive_document_verified'] == true;
    final canShortlist =
        status == 'pending' && (!hasSupportiveDocument || isDocumentAuthentic);
    final canAccept =
        (status == 'shortlisted' || status == '') &&
        (!hasSupportiveDocument || isDocumentAuthentic);
    final canReject =
        (status == 'pending' || status == 'shortlisted' || status == '') &&
        (!hasSupportiveDocument || documentReviewed);
    final isOfferExpired = _isOfferConfirmationExpired(applicationId);
    final selectedApplicationId =
        '${selection?['selected_application_id'] ?? ''}'.trim();
    final selectedOrganizationName =
        '${selection?['selected_organization_name'] ?? ''}'.trim();
    final hasConfirmedOrganization = selectedApplicationId.isNotEmpty;
    final hasConfirmedThisOrganization =
        hasConfirmedOrganization && selectedApplicationId == applicationId;
    final hasConfirmedAnotherOrganization =
        hasConfirmedOrganization && !hasConfirmedThisOrganization;
    final reviewLabel = !hasSupportiveDocument
        ? 'Cover letter only'
        : !documentReviewed
        ? 'Pending document review'
        : isDocumentAuthentic
        ? 'Document verified'
        : 'Document not authentic';
    final reviewColor = !hasSupportiveDocument
        ? Colors.blueGrey
        : !documentReviewed
        ? const Color(0xFFB38A45)
        : isDocumentAuthentic
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC62828);

    Widget buildDocumentActionButton({
      required IconData icon,
      required String label,
      required VoidCallback? onPressed,
    }) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 16),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: _organizationStudentPrimary,
          side: BorderSide(
            color: _organizationStudentPrimary.withValues(alpha: 0.35),
          ),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _organizationStudentBorder.withValues(alpha: 0.95),
        ),
        boxShadow: [
          BoxShadow(
            color: _organizationStudentPrimary.withValues(alpha: 0.05),
            blurRadius: 16,
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
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFD9ECFF),
                  borderRadius: BorderRadius.circular(999),
                ),
                alignment: Alignment.center,
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: _organizationStudentPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: _organizationStudentPrimaryDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      email,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusBackground(status),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  formatApplicationStatus(status, language),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
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
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            language.tr('training_value', {'value': trainingTitle}),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
          ),
          if (hasCoverLetter ||
              hasSupportiveDocument ||
              (responseLetterUrl != null && responseLetterUrl.isNotEmpty)) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  if (hasCoverLetter)
                    buildDocumentActionButton(
                      icon: Icons.description_outlined,
                      label: 'Open Cover Letter',
                      onPressed: () => _openCoverLetter(
                        applicationId: applicationId,
                        directFileUrl: coverLetterUrl,
                      ),
                    ),
                  if (hasCoverLetter &&
                      (hasSupportiveDocument ||
                          (responseLetterUrl != null &&
                              responseLetterUrl.isNotEmpty)))
                    const SizedBox(width: 8),
                  if (hasSupportiveDocument)
                    buildDocumentActionButton(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'Open Supportive Document',
                      onPressed: () => _openSupportiveDocument(
                        applicationId: applicationId,
                        fileName: supportiveDocumentName,
                        directFileUrl: supportiveDocumentUrl,
                      ),
                    ),
                  if (hasSupportiveDocument &&
                      responseLetterUrl != null &&
                      responseLetterUrl.isNotEmpty)
                    const SizedBox(width: 8),
                  if (responseLetterUrl != null && responseLetterUrl.isNotEmpty)
                    buildDocumentActionButton(
                      icon: Icons.download_rounded,
                      label: isDownloadingResponseLetter
                          ? 'Downloading...'
                          : 'Download',
                      onPressed: isDownloadingResponseLetter
                          ? null
                          : () => _downloadResponseLetter(
                              applicationId: applicationId,
                              fileName: responseLetterName,
                              directFileUrl: responseLetterUrl,
                            ),
                    ),
                ],
              ),
            ),
          ],
          if (hasSupportiveDocument) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 18, color: reviewColor),
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
            if (verificationNotes != null && verificationNotes.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Review notes: $verificationNotes',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ],
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  buildDocumentActionButton(
                    icon: Icons.check_circle_outline,
                    label: 'Authentic',
                    onPressed: () => _reviewSupportiveDocument(
                      applicationId,
                      isAuthentic: true,
                    ),
                  ),
                  const SizedBox(width: 8),
                  buildDocumentActionButton(
                    icon: Icons.gpp_bad_outlined,
                    label: 'Not Authentic',
                    onPressed: () => _reviewSupportiveDocument(
                      applicationId,
                      isAuthentic: false,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (status == 'accepted' && isOfferExpired) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD97706)),
              ),
              child: const Text(
                'The student did not confirm this offer within 48 hours while holding multiple offers. This slot is now open again.',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else if (status == 'accepted' && hasConfirmedOrganization) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: hasConfirmedThisOrganization
                    ? const Color(0xFFEAF7F2)
                    : const Color(0xFFFFF4EC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasConfirmedThisOrganization
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFD97706),
                ),
              ),
              child: Text(
                hasConfirmedThisOrganization
                    ? '$fullName has confirmed your organization and is waiting for university review.'
                    : '$fullName already confirmed placement with $selectedOrganizationName.',
                style: TextStyle(
                  color: hasConfirmedThisOrganization
                      ? const Color(0xFF0F766E)
                      : const Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
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
              if (status == 'accepted')
                OutlinedButton.icon(
                  onPressed: hasConfirmedAnotherOrganization
                      ? null
                      : () => _showReportStudentDialog(
                          Map<String, dynamic>.from(app as Map),
                        ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFB42318),
                    side: const BorderSide(color: Color(0xFFB42318)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.report_problem_outlined, size: 18),
                  label: const Text('Report to University'),
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
    final visibleApplications = switch (_applicationFilter) {
      'accepted' => _acceptedApplications,
      'shortlisted' => _shortlistedApplications,
      _ => _applications,
    };
    final showAcceptedSummaryOnly = _applicationFilter == 'accepted';
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
          _buildTopNavigationBar(),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 560;
              final cards = [
                _buildSummaryCard(
                  label: language.tr('total'),
                  value: '${_applications.length}',
                  icon: Icons.groups_2_outlined,
                  color: _organizationStudentPrimary,
                  isSelected: _applicationFilter == 'all',
                  onTap: _showAllApplicationsList,
                ),
                _buildSummaryCard(
                  label: language.tr('shortlisted'),
                  value: '${_countByStatus('shortlisted')}',
                  icon: Icons.playlist_add_check_circle_outlined,
                  color: Colors.blue,
                  isSelected: _applicationFilter == 'shortlisted',
                  onTap: _showShortlistedApplications,
                ),
                _buildSummaryCard(
                  label: language.tr('accepted'),
                  value: '${_countByStatus('accepted')}',
                  icon: Icons.check_circle_outline,
                  color: Colors.green,
                  isSelected: _applicationFilter == 'accepted',
                  onTap: _showAcceptedApplicants,
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
          if (_applicationFilter != 'accepted') ...[
            _buildApplicationsExportButton(),
            const SizedBox(height: 14),
          ],
          if (_applicationFilter == 'accepted') ...[
            _buildAcceptedApplicantsList(),
            const SizedBox(height: 14),
          ],
          if (!showAcceptedSummaryOnly && visibleApplications.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _organizationStudentBorder),
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
                    _applicationFilter == 'shortlisted'
                        ? 'No shortlisted students yet.'
                        : _applicationFilter == 'accepted'
                        ? 'No accepted students yet.'
                        : _showAllApplications
                        ? language.tr('no_applications_for_training_yet')
                        : language.tr('no_applications_for_this_training_yet'),
                  ),
                  if (_applicationFilter == 'all' && _showAllApplications) ...[
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: widget.onGoTotraining,
                      child: Text(widget.emptyActionLabel),
                    ),
                  ],
                ],
              ),
            ),
          if (!showAcceptedSummaryOnly)
            ...visibleApplications.map(_buildApplicationCard),
        ],
      ),
    );
  }

  Map<String, String> _inferLocationDefaults(String rawLocation) {
    final location = rawLocation.trim();
    if (location.isEmpty) {
      return const {'area': '', 'district': '', 'region': ''};
    }

    final parts = location
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList(growable: false);

    String region = '';
    String district = '';

    String? matchingRegion;
    for (final part in parts.reversed) {
      if (tanzaniaRegionDistricts.containsKey(part)) {
        matchingRegion = part;
        break;
      }
    }

    if (matchingRegion != null) {
      region = matchingRegion;
      final districts = tanzaniaRegionDistricts[region] ?? const <String>[];
      for (final part in parts) {
        if (districts.contains(part)) {
          district = part;
          break;
        }
      }
    } else if (parts.length == 1) {
      region = parts.first;
    } else if (parts.length >= 2) {
      district = parts.first;
      region = parts.last;
    }

    return {'area': location, 'district': district, 'region': region};
  }
}

class _AcceptanceLetterDialog extends StatefulWidget {
  final String initialOrganizationName;
  final String initialRegistrationNumber;
  final String initialCollegeName;
  final String initialOfficerRegion;
  final String initialOfficerDistrict;
  final String initialOfficerArea;
  final String initialLetterDate;
  final String studentName;
  final String trainingTitle;
  final bool hasDigitalStamp;
  final bool hasDigitalSignature;
  final _AcceptanceInputBuilder buildInput;

  const _AcceptanceLetterDialog({
    required this.initialOrganizationName,
    required this.initialRegistrationNumber,
    required this.initialCollegeName,
    required this.initialOfficerRegion,
    required this.initialOfficerDistrict,
    required this.initialOfficerArea,
    required this.initialLetterDate,
    required this.studentName,
    required this.trainingTitle,
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
  String? _selectedOfficerRegion;
  String? _selectedOfficerDistrict;

  DateTime _formatSeedDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  String _formatDateOnly(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  DateTime? _parseDate(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return null;
    return DateTime.tryParse(normalized);
  }

  String? _validateRequired(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    final requiredError = _validateRequired(value, 'Officer Phone Number');
    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    final phonePattern = RegExp(r'^\+?\d{9,15}$');
    if (!phonePattern.hasMatch(normalized)) {
      return 'Enter a valid phone number';
    }

    return null;
  }

  String? _validateEmailAddress(String? value) {
    final requiredError = _validateRequired(value, 'Officer Email Address');
    if (requiredError != null) {
      return requiredError;
    }

    final normalized = value!.trim();
    final emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailPattern.hasMatch(normalized)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  @override
  void initState() {
    super.initState();
    _organizationNameController = TextEditingController(
      text: widget.initialOrganizationName,
    );
    _registrationNumberController = TextEditingController(
      text: widget.initialRegistrationNumber,
    );
    _collegeNameController = TextEditingController(
      text: widget.initialCollegeName,
    );
    _sectionDepartmentController = TextEditingController();
    _officerNameController = TextEditingController();
    _officerDesignationController = TextEditingController();
    _officerPhoneController = TextEditingController();
    _officerEmailController = TextEditingController();
    _officerRegionController = TextEditingController(
      text: widget.initialOfficerRegion,
    );
    _officerDistrictController = TextEditingController(
      text: widget.initialOfficerDistrict,
    );
    _officerAreaController = TextEditingController(
      text: widget.initialOfficerArea,
    );
    _letterDateController = TextEditingController(
      text: widget.initialLetterDate,
    );
    if (tanzaniaRegionDistricts.containsKey(_officerRegionController.text)) {
      _selectedOfficerRegion = _officerRegionController.text;
    }
    final currentDistricts = _selectedOfficerRegion == null
        ? const <String>[]
        : (tanzaniaRegionDistricts[_selectedOfficerRegion] ?? const <String>[]);
    if (currentDistricts.contains(_officerDistrictController.text)) {
      _selectedOfficerDistrict = _officerDistrictController.text;
    }
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

  Future<void> _pickLetterDate() async {
    final now = DateTime.now();
    final initialDate =
        _parseDate(_letterDateController.text) ?? _formatSeedDate(now);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: 'Select letter date',
    );

    if (pickedDate == null || !mounted) return;

    setState(() {
      _letterDateController.text = _formatDateOnly(pickedDate);
    });
  }

  Widget _buildDateInput({
    required TextEditingController controller,
    required String label,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        onTap: _pickLetterDate,
        scrollPadding: const EdgeInsets.only(bottom: 140),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: const Icon(Icons.calendar_month_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveRow({
    required bool compact,
    required Widget first,
    Widget? second,
  }) {
    if (second == null) {
      return first;
    }

    if (compact) {
      return Column(children: [first, second]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 12),
        Expanded(child: second),
      ],
    );
  }

  Widget _buildRegionDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedOfficerRegion,
        decoration: InputDecoration(
          labelText: 'Region',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        items: tanzaniaRegionDistricts.keys
            .map((region) {
              return DropdownMenuItem<String>(
                value: region,
                child: Text(region),
              );
            })
            .toList(growable: false),
        onChanged: (value) {
          setState(() {
            _selectedOfficerRegion = value;
            _officerRegionController.text = value ?? '';
            _selectedOfficerDistrict = null;
            _officerDistrictController.clear();
          });
        },
        validator: (value) => _validateRequired(value, 'Region'),
      ),
    );
  }

  Widget _buildDistrictDropdown() {
    final districts = _selectedOfficerRegion == null
        ? const <String>[]
        : (tanzaniaRegionDistricts[_selectedOfficerRegion] ?? const <String>[]);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        initialValue: _selectedOfficerDistrict,
        decoration: InputDecoration(
          labelText: 'District',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        items: districts
            .map((district) {
              return DropdownMenuItem<String>(
                value: district,
                child: Text(district),
              );
            })
            .toList(growable: false),
        onChanged: _selectedOfficerRegion == null
            ? null
            : (value) {
                setState(() {
                  _selectedOfficerDistrict = value;
                  _officerDistrictController.text = value ?? '';
                });
              },
        validator: (value) => _validateRequired(value, 'District'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final viewInsets = MediaQuery.of(context).viewInsets;
    final buildInput = widget.buildInput;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: FractionallySizedBox(
        heightFactor: 0.94,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: screenSize.height * 0.82,
            ),
            child: Material(
              color: Colors.white,
              elevation: 16,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 560;

                    return Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              width: 44,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Acceptance Letter Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: SingleChildScrollView(
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              padding: EdgeInsets.only(
                                bottom: viewInsets.bottom > 0 ? 24 : 4,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Fill in the letter details for ${widget.studentName}.',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.hasDigitalStamp ||
                                            widget.hasDigitalSignature
                                        ? 'Saved stamp/signature will be inserted automatically.'
                                        : 'No digital stamp or signature uploaded yet.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                      height: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildResponsiveRow(
                                    compact: compact,
                                    first: buildInput(
                                      controller: _organizationNameController,
                                      label: 'Organization / Institution',
                                      hint: 'Example: ABC Organization Limited',
                                    ),
                                    second: buildInput(
                                      controller: _registrationNumberController,
                                      label: 'Student Registration Number',
                                      hint: 'Example: UDOM/2023/12345',
                                      readOnly: true,
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Student registration number was not found on this application';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  _buildResponsiveRow(
                                    compact: compact,
                                    first: buildInput(
                                      controller: _collegeNameController,
                                      label: 'College Name',
                                      hint: 'Example: College of Informatics',
                                    ),
                                    second: buildInput(
                                      controller: _sectionDepartmentController,
                                      label: 'Section / Department',
                                      hint: 'Example: ICT Department',
                                    ),
                                  ),
                                  _buildResponsiveRow(
                                    compact: compact,
                                    first: buildInput(
                                      controller: _officerNameController,
                                      label: 'Authorizing Officer Name',
                                    ),
                                    second: buildInput(
                                      controller: _officerDesignationController,
                                      label: 'Officer Designation',
                                    ),
                                  ),
                                  _buildResponsiveRow(
                                    compact: compact,
                                    first: buildInput(
                                      controller: _officerPhoneController,
                                      label: 'Officer Phone Number',
                                      keyboardType: TextInputType.phone,
                                      validator: _validatePhoneNumber,
                                    ),
                                    second: buildInput(
                                      controller: _officerEmailController,
                                      label: 'Officer Email Address',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: _validateEmailAddress,
                                    ),
                                  ),
                                  _buildResponsiveRow(
                                    compact: compact,
                                    first: _buildRegionDropdown(),
                                    second: _buildDistrictDropdown(),
                                  ),
                                  buildInput(
                                    controller: _officerAreaController,
                                    label: 'Area / Physical Address',
                                    hint: 'Example: Mtumba, Dodoma',
                                  ),
                                  _buildDateInput(
                                    controller: _letterDateController,
                                    label: 'Letter Date',
                                    hint: 'Tap to choose date',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: _submit,
                                child: const Text('Generate Letter'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OrganizationProfileScreen extends StatelessWidget {
  const OrganizationProfileScreen({super.key});

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
          Icon(icon, size: 20, color: _organizationStudentPrimary),
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
    final organization = user?['organization_data'] ?? {};
    final organizationName =
        '${organization['organization_name'] ?? language.tr('organization')}';
    final rawLogoUrl = organization['logo_url']?.toString();
    final logoUrls = rawLogoUrl == null || rawLogoUrl.isEmpty
        ? const <String>[]
        : ApiService().resolveAssetUrlCandidates(rawLogoUrl);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                  backgroundColor: _organizationStudentSurface,
                  child: logoUrls.isEmpty
                      ? Text(
                          organizationName.isNotEmpty
                              ? organizationName[0].toUpperCase()
                              : 'C',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: _organizationStudentPrimary,
                          ),
                        )
                      : ClipOval(
                          child: _DashboardImageWithFallbacks(
                            imageUrls: logoUrls,
                            fit: BoxFit.cover,
                            emptyChild: Container(
                              color: _organizationStudentSurface,
                              alignment: Alignment.center,
                              child: Text(
                                organizationName.isNotEmpty
                                    ? organizationName[0].toUpperCase()
                                    : 'C',
                                style: const TextStyle(
                                  color: _organizationStudentPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
                const SizedBox(height: 12),
                Text(
                  organizationName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${organization['industry'] ?? language.tr('industry_not_set')}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final buttonTextStyle = const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    );

                    return Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const EditOrganizationProfileScreen(),
                                ),
                              );
                              if (!context.mounted) return;
                              final dashboard = context
                                  .findAncestorStateOfType<
                                    _OrganizationDashboardState
                                  >();
                              dashboard?._handleRouteNavigationResult(result);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _organizationStudentPrimary,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            icon: const Icon(Icons.edit, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                language.tr('edit_profile'),
                                style: buttonTextStyle,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoTile(
            context: context,
            icon: Icons.location_on_outlined,
            label: language.tr('location'),
            value: '${organization['location'] ?? ''}',
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.language_outlined,
            label: language.tr('website'),
            value: '${organization['website_url'] ?? ''}',
          ),
          _buildInfoTile(
            context: context,
            icon: Icons.groups_outlined,
            label: language.tr('organization_size'),
            value: '${organization['organization_size'] ?? ''}',
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
              '${organization['description'] ?? language.tr('no_organization_description_added_yet')}',
              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
