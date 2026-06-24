import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/browser_pdf_opener.dart';
import '../../services/coordinator_workspace_service.dart';
import '../../services/export_file_saver.dart';
import '../../services/local_file_service.dart';
import '../../utils/assets.dart';
import '../../utils/role_theme.dart';
import '../../utils/theme.dart';
import '../../widgets/language_picker_dialog.dart';
import '../auth/login_screen.dart';
import 'company_test_management_screen.dart';
import 'post_job_screen.dart';
import 'edit_organization_profile_screen.dart';
import 'organization_notifications_screen.dart';

enum _OrganizationMoreAction { settings, language, logout }

const Color _organizationStudentPrimary = OrganizationRoleTheme.primary;
const Color _organizationStudentPrimaryDark = OrganizationRoleTheme.primaryDark;
const Color _organizationLoginBlue = AppTheme.primaryBlue;
const Color _organizationLoginBlueSoft = Color(0xFFF6FAFF);
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

class _OrganizationDashboardState extends State<OrganizationDashboard> {
  final ApiService _apiService = ApiService();
  int _currentIndex = 0;
  int _unreadNotifications = 0;
  final List<int> _tabHistory = [];

  String? _selectedTrainingId;
  String? _selectedTrainingTitle;

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

  bool _isDesktopWidth(double width) => width >= 1200;

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
          final sidebarWidth = constraints.maxWidth >= 1200
              ? 288.0
              : constraints.maxWidth >= 900
              ? 240.0
              : 220.0;

          if (!isDesktop) {
            return Scaffold(
              backgroundColor: _organizationLoginBlueSoft,
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(108),
                child: _OrganizationPortalHeader(
                  isCompact: true,
                  unreadNotifications: _unreadNotifications,
                  language: language,
                  onNotificationsPressed: _openNotifications,
                  onMoreSelected: _handleMoreAction,
                ),
              ),
              body: IndexedStack(index: _currentIndex, children: screens),
              bottomNavigationBar: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                currentIndex: _currentIndex,
                onTap: (index) {
                  navigateToTab(index);
                  _loadUnreadNotificationCount();
                },
                selectedItemColor: _organizationLoginBlue,
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
            backgroundColor: _organizationLoginBlueSoft,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(74),
              child: _OrganizationPortalHeader(
                isCompact: false,
                unreadNotifications: _unreadNotifications,
                language: language,
                onNotificationsPressed: _openNotifications,
                onMoreSelected: _handleMoreAction,
              ),
            ),
            body: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: sidebarWidth,
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

class _OrganizationPortalHeader extends StatelessWidget {
  const _OrganizationPortalHeader({
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
  final PopupMenuItemSelected<_OrganizationMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _organizationLoginBlueSoft,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: _organizationLoginBlueSoft,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
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
                        const _OrganizationHeaderBrand(),
                        const Spacer(),
                        _OrganizationHeaderActions(
                          unreadNotifications: unreadNotifications,
                          language: language,
                          onNotificationsPressed: onNotificationsPressed,
                          onMoreSelected: onMoreSelected,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const _OrganizationHeaderCenterTitle(isCompact: true),
                  ],
                )
              : Row(
                  children: [
                    const _OrganizationHeaderBrand(),
                    const Expanded(child: _OrganizationHeaderCenterTitle()),
                    _OrganizationHeaderActions(
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

class _OrganizationHeaderBrand extends StatelessWidget {
  const _OrganizationHeaderBrand();

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
                    Icons.business_rounded,
                    color: _organizationLoginBlue,
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
                style: TextStyle(color: _organizationLoginBlue),
              ),
              TextSpan(
                text: 'Kiganjani',
                style: TextStyle(color: _organizationLoginBlue),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrganizationHeaderCenterTitle extends StatelessWidget {
  const _OrganizationHeaderCenterTitle({this.isCompact = false});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'THE UNITED REPUBLIC OF TANZANIA\nPRACTICAL TRAINING SYSTEM',
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _organizationLoginBlue,
        fontSize: isCompact ? 12 : 15,
        height: 1.25,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _OrganizationHeaderActions extends StatelessWidget {
  const _OrganizationHeaderActions({
    required this.unreadNotifications,
    required this.language,
    required this.onNotificationsPressed,
    required this.onMoreSelected,
  });

  final int unreadNotifications;
  final LanguageProvider language;
  final VoidCallback onNotificationsPressed;
  final PopupMenuItemSelected<_OrganizationMoreAction> onMoreSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _OrganizationNotificationButton(
          unreadNotifications: unreadNotifications,
          tooltip: language.tr('notifications'),
          onPressed: onNotificationsPressed,
        ),
        const SizedBox(width: 8),
        _OrganizationHeaderMenuButton(
          language: language,
          onSelected: onMoreSelected,
        ),
      ],
    );
  }
}

class _OrganizationNotificationButton extends StatelessWidget {
  const _OrganizationNotificationButton({
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
              foregroundColor: Colors.white,
              backgroundColor: _organizationLoginBlue,
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

class _OrganizationHeaderMenuButton extends StatelessWidget {
  const _OrganizationHeaderMenuButton({
    required this.language,
    required this.onSelected,
  });

  final LanguageProvider language;
  final PopupMenuItemSelected<_OrganizationMoreAction> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_OrganizationMoreAction>(
      tooltip: language.tr('more_actions'),
      onSelected: onSelected,
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
      icon: const Icon(Icons.more_vert_rounded),
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      iconColor: _organizationLoginBlue,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }
}

String formatOrganizationStatus(String status, LanguageProvider language) {
  return status == 'open'
      ? language.tr('status_active')
      : language.tr('status_closed');
}

String organizationTrainingId(Map<String, dynamic> training) {
  final candidates = [training['job_id'], training['training_id']];

  for (final candidate in candidates) {
    final value = '$candidate'.trim();
    if (value.isNotEmpty && value.toLowerCase() != 'null') {
      return value;
    }
  }

  return '';
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
    case 'assigned':
      return language.tr('status_assigned');
    case 'shortlisted':
      return language.tr('status_shortlisted');
    case '':
      return language.tr('status_');
    case 'accepted':
      return language.tr('status_accepted');
    case 'expired':
      return language.tr('expired');
    case 'rejected':
      return language.tr('status_rejected');
    case 'pending':
    default:
      return language.tr('status_pending');
  }
}

class OrganizationUniversityChatsPage extends StatefulWidget {
  final List<Map<String, dynamic>> initialConversations;

  const OrganizationUniversityChatsPage({
    super.key,
    this.initialConversations = const [],
  });

  @override
  State<OrganizationUniversityChatsPage> createState() =>
      _OrganizationUniversityChatsPageState();
}

class _OrganizationUniversityChatsPageState
    extends State<OrganizationUniversityChatsPage> {
  final ApiService _apiService = ApiService();
  final TextEditingController _composerController = TextEditingController();

  List<Map<String, dynamic>> _conversations = const [];
  List<Map<String, dynamic>> _messages = const [];
  Map<String, dynamic>? _selectedConversation;
  bool _isLoadingConversations = true;
  bool _isLoadingMessages = false;
  bool _isSending = false;
  String? _deletingMessageId;
  String? _editingMessageId;
  String? _composerError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _conversations = _mergeConversations(widget.initialConversations, const []);
    _loadConversations();
  }

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, entry) => MapEntry('$key', entry)))
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _mergeConversations(
    List<Map<String, dynamic>> first,
    List<Map<String, dynamic>> second,
  ) {
    final merged = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(Map<String, dynamic> item) {
      final universityUserId = '${item['university_user_id'] ?? ''}'.trim();
      final universityName = '${item['university_name'] ?? ''}'.trim();
      final key = universityUserId.isNotEmpty
          ? universityUserId
          : universityName.toLowerCase();
      if (key.isEmpty || !seen.add(key)) return;
      merged.add(item);
    }

    for (final item in second) {
      add(item);
    }
    for (final item in first) {
      add(item);
    }
    return merged;
  }

  String _universityName(Map<String, dynamic>? conversation) {
    return '${conversation?['university_name'] ?? 'University'}'.trim();
  }

  String _universityUserId(Map<String, dynamic>? conversation) {
    return '${conversation?['university_user_id'] ?? ''}'.trim();
  }

  String _preview(Map<String, dynamic> conversation) {
    final latest = '${conversation['latest_message'] ?? ''}'.trim();
    return latest.isEmpty ? 'Tap to start the conversation.' : latest;
  }

  int _unreadCount(Map<String, dynamic> conversation) {
    final value = conversation['unread_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  String _formatTime(Object? value) {
    final date = DateTime.tryParse('${value ?? ''}')?.toLocal();
    if (date == null) return '';
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Future<void> _loadConversations() async {
    setState(() {
      _isLoadingConversations = true;
      _error = null;
    });

    try {
      final response = await _apiService.getOrganizationUniversityChats();
      final remoteConversations = _mapList(response['data']);
      final conversations = _mergeConversations(
        widget.initialConversations,
        remoteConversations,
      );
      if (!mounted) return;
      setState(() {
        _conversations = conversations;
        _selectedConversation ??= conversations.isNotEmpty
            ? conversations.first
            : null;
        _isLoadingConversations = false;
      });
      if (_selectedConversation != null && _messages.isEmpty) {
        await _selectConversation(_selectedConversation!, openDetail: false);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = ApiService.normalizeErrorMessage(
          error,
          fallback: 'Failed to load university chats.',
        );
        _isLoadingConversations = false;
      });
    }
  }

  Future<void> _selectConversation(
    Map<String, dynamic> conversation, {
    bool openDetail = true,
  }) async {
    final universityUserId = _universityUserId(conversation);
    if (universityUserId.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('University chat target is missing.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _selectedConversation = conversation;
      _messages = const [];
      _isLoadingMessages = true;
      _editingMessageId = null;
      _composerError = null;
    });
    _composerController.clear();

    try {
      final response = await _apiService.getOrganizationUniversityChatMessages(
        universityUserId,
      );
      if (!mounted) return;
      setState(() {
        _messages = _mapList(response['data']);
        _isLoadingMessages = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingMessages = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            ApiService.normalizeErrorMessage(
              error,
              fallback: 'Failed to load messages.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _sendMessage() async {
    final selected = _selectedConversation;
    final universityUserId = _universityUserId(selected);
    final text = _composerController.text.trim();
    final editingMessageId = _editingMessageId;
    if (_isSending) return;
    if (selected == null || universityUserId.isEmpty) return;
    if (text.isEmpty) {
      setState(() => _composerError = 'Write a message first.');
      return;
    }

    setState(() {
      _isSending = true;
      _composerError = null;
    });

    try {
      final response = editingMessageId == null
          ? await _apiService.sendOrganizationUniversityChatMessage(
              universityUserId: universityUserId,
              message: text,
            )
          : await _apiService.updateOrganizationUniversityChatMessage(
              universityUserId: universityUserId,
              messageId: editingMessageId,
              message: text,
            );
      if (!mounted) return;
      if (response['success'] == true && response['data'] is Map) {
        _composerController.clear();
        setState(() {
          if (editingMessageId == null) {
            _messages = [
              ..._messages,
              Map<String, dynamic>.from(response['data'] as Map),
            ];
          } else {
            final updatedMessage = Map<String, dynamic>.from(
              response['data'] as Map,
            );
            _messages = _messages
                .map(
                  (message) =>
                      '${message['id'] ?? ''}'.trim() == editingMessageId
                      ? updatedMessage
                      : message,
                )
                .toList(growable: false);
          }
          _editingMessageId = null;
          _isSending = false;
        });
        await _loadConversations();
      } else {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              '${response['message'] ?? 'Failed to send message.'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            ApiService.normalizeErrorMessage(
              error,
              fallback: 'Failed to send message.',
            ),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteMessage(Map<String, dynamic> message) async {
    final selected = _selectedConversation;
    final universityUserId = _universityUserId(selected);
    final messageId = '${message['id'] ?? ''}'.trim();
    if (universityUserId.isEmpty || messageId.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
          'This will remove the message from your chat only.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deletingMessageId = messageId);
    final response = await _apiService.deleteOrganizationUniversityChatMessage(
      universityUserId: universityUserId,
      messageId: messageId,
    );
    if (!mounted) return;

    if (response['success'] == true) {
      setState(() {
        _messages = _messages
            .where((item) => '${item['id'] ?? ''}'.trim() != messageId)
            .toList(growable: false);
        if (_editingMessageId == messageId) {
          _editingMessageId = null;
          _composerController.clear();
        }
        _deletingMessageId = null;
      });
    } else {
      setState(() => _deletingMessageId = null);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            '${response['message'] ?? 'Failed to delete message.'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isOwnMessage(Map<String, dynamic> message) {
    final senderRole = '${message['sender_role'] ?? ''}'.trim().toLowerCase();
    return senderRole == 'organization' || senderRole == 'company';
  }

  void _startEditingMessage(Map<String, dynamic> message) {
    final messageId = '${message['id'] ?? ''}'.trim();
    if (messageId.isEmpty ||
        !_isOwnMessage(message) ||
        _deletingMessageId != null) {
      return;
    }

    _composerController.text = '${message['message'] ?? ''}'.trim();
    _composerController.selection = TextSelection.fromPosition(
      TextPosition(offset: _composerController.text.length),
    );
    setState(() {
      _editingMessageId = messageId;
      _composerError = null;
    });
  }

  void _cancelEditingMessage() {
    _composerController.clear();
    setState(() {
      _editingMessageId = null;
      _composerError = null;
    });
  }

  Future<void> _showMessageActions(Map<String, dynamic> message) async {
    final messageId = '${message['id'] ?? ''}'.trim();
    if (messageId.isEmpty || _deletingMessageId != null) return;
    final isOwnMessage = _isOwnMessage(message);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwnMessage)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit message'),
                onTap: () => Navigator.of(context).pop('edit'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
              ),
              title: const Text('Delete message'),
              textColor: Colors.red,
              iconColor: Colors.red,
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );

    if (action == 'edit') {
      _startEditingMessage(message);
    } else if (action == 'delete') {
      await _deleteMessage(message);
    }
  }

  Widget _buildConversationList({required bool compact}) {
    if (_isLoadingConversations && _conversations.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _loadConversations,
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      );
    }

    if (_conversations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 58,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 12),
              const Text(
                'No university chats yet',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Universities connected to your placements will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, indent: 76),
      itemBuilder: (context, index) {
        final conversation = _conversations[index];
        final selected =
            _universityUserId(conversation) ==
            _universityUserId(_selectedConversation);
        final unreadCount = _unreadCount(conversation);

        return Material(
          color: selected
              ? _organizationStudentSurfaceSoft
              : Colors.transparent,
          child: InkWell(
            onTap: () => _selectConversation(conversation),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFFDDF6EC),
                    child: Text(
                      _universityName(conversation).isEmpty
                          ? 'U'
                          : _universityName(conversation)[0].toUpperCase(),
                      style: const TextStyle(
                        color: _organizationStudentPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _universityName(conversation),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            color: _organizationStudentPrimaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _preview(conversation),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (unreadCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _organizationStudentPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = _isOwnMessage(message);
    final isDeleting = _deletingMessageId == '${message['id'] ?? ''}'.trim();
    final isEdited = '${message['edited_at'] ?? ''}'.trim().isNotEmpty;
    final bubbleColor = isMine ? const Color(0xFFDCF8C6) : Colors.white;
    final alignment = isMine ? Alignment.centerRight : Alignment.centerLeft;

    return Align(
      alignment: alignment,
      child: GestureDetector(
        onTap: () => _showMessageActions(message),
        onLongPress: () => _deleteMessage(message),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 7),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(isMine ? 14 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 14),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${message['message'] ?? ''}',
                style: const TextStyle(
                  color: Color(0xFF1F2937),
                  height: 1.35,
                  fontSize: 14.5,
                ),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatTime(message['created_at']),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                  ),
                  if (isEdited) ...[
                    const SizedBox(width: 8),
                    Text(
                      'edited',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (isDeleting) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 11,
                      height: 11,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatPane({required bool compact}) {
    final selected = _selectedConversation;
    if (selected == null) {
      return const Center(
        child: Text(
          'Select a university chat',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }

    return Column(
      children: [
        Container(
          color: _organizationStudentPrimary,
          padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 10, 16, 10),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                if (compact)
                  IconButton(
                    onPressed: () => setState(() {
                      _selectedConversation = null;
                      _messages = const [];
                    }),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: Colors.white,
                  ),
                CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  child: const Icon(
                    Icons.account_balance_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _universityName(selected),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'University chat',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _selectConversation(selected),
                  icon: const Icon(Icons.refresh_rounded),
                  color: Colors.white,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFFECE5DD),
            child: _isLoadingMessages
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'No messages yet. Start the conversation.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) =>
                        _buildMessageBubble(_messages[index]),
                  ),
          ),
        ),
        Container(
          color: const Color(0xFFF0F2F5),
          padding: EdgeInsets.fromLTRB(
            12,
            10,
            12,
            MediaQuery.of(context).padding.bottom + 10,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_editingMessageId != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _organizationStudentBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.edit_outlined,
                        size: 18,
                        color: _organizationStudentPrimary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Editing message',
                          style: TextStyle(
                            color: _organizationStudentPrimaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _isSending ? null : _cancelEditingMessage,
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Cancel edit',
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _composerController,
                      minLines: 1,
                      maxLines: 5,
                      onChanged: (_) {
                        if (_composerError != null) {
                          setState(() => _composerError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: _editingMessageId == null
                            ? 'Message'
                            : 'Edit message',
                        errorText: _composerError,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    width: 48,
                    child: FilledButton(
                      onPressed: _isSending ? null : _sendMessage,
                      style: FilledButton.styleFrom(
                        shape: const CircleBorder(),
                        padding: EdgeInsets.zero,
                        backgroundColor: _organizationStudentPrimary,
                      ),
                      child: _isSending
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              _editingMessageId == null
                                  ? Icons.send_rounded
                                  : Icons.check_rounded,
                              color: Colors.white,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text('University Chats'),
        backgroundColor: _organizationStudentPrimary,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          if (compact && _selectedConversation != null) {
            return _buildChatPane(compact: true);
          }

          if (compact) {
            return _buildConversationList(compact: true);
          }

          return Row(
            children: [
              SizedBox(
                width: 360,
                child: Material(
                  color: Colors.white,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
                        child: Text(
                          'Chats',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      Expanded(child: _buildConversationList(compact: false)),
                    ],
                  ),
                ),
              ),
              const VerticalDivider(width: 1),
              Expanded(child: _buildChatPane(compact: false)),
            ],
          );
        },
      ),
    );
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
  List<Map<String, dynamic>> _chatUniversities = const [];
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
        _workspaceService.getAnnouncements(audience: 'company'),
        _apiService.getOrganizationUniversityChats(),
      ]);
      final trainingResponse = responses[0] as Map<String, dynamic>;
      final announcements = responses[1] as List<Map<String, dynamic>>;
      final chatResponse = responses[2] as Map<String, dynamic>;
      final chatUniversities = _mapConversationList(chatResponse['data']);
      if (trainingResponse['success']) {
        setState(() {
          _training = trainingResponse['data'];
          _announcements = announcements;
          _chatUniversities = chatUniversities;
          _isLoading = false;
        });
      } else {
        setState(() {
          _announcements = announcements;
          _chatUniversities = chatUniversities;
          _isLoading = false;
        });
      }
    } catch (e) {
      final announcements = await _workspaceService.getAnnouncements(
        audience: 'company',
      );
      final chatResponse = await _apiService.getOrganizationUniversityChats();
      final chatUniversities = _mapConversationList(chatResponse['data']);
      if (!mounted) return;
      setState(() {
        _announcements = announcements;
        _chatUniversities = chatUniversities;
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _mapConversationList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => item.map((key, entry) => MapEntry('$key', entry)))
        .toList(growable: false);
  }

  int _conversationUnreadCount(Map<String, dynamic> conversation) {
    final value = conversation['unread_count'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('${value ?? 0}') ?? 0;
  }

  int get _totalUniversityUnreadCount {
    var total = 0;
    for (final conversation in _chatUniversities) {
      total += _conversationUnreadCount(conversation);
    }
    return total;
  }

  bool _isEligibleUniversityChatApplication(Map<String, dynamic> application) {
    final status = '${application['status'] ?? ''}'.trim().toLowerCase();
    if (status != 'accepted') return false;

    final confirmationStatus =
        '${application['student_confirmation_status'] ?? ''}'
            .trim()
            .toLowerCase();
    return confirmationStatus != 'expired' &&
        confirmationStatus != 'confirmed_elsewhere';
  }

  Future<List<Map<String, dynamic>>> _loadUniversityChatCandidates() async {
    if (_chatUniversities.isNotEmpty) {
      return List<Map<String, dynamic>>.from(_chatUniversities);
    }

    final applicationsResponse = await _apiService
        .getOrganizationApplications();
    final applications = applicationsResponse['data'] is List
        ? List<Map<String, dynamic>>.from(
            (applicationsResponse['data'] as List).whereType<Map>().map(
              (item) => item.map((key, value) => MapEntry('$key', value)),
            ),
          )
        : const <Map<String, dynamic>>[];

    final candidatesByKey = <String, Map<String, dynamic>>{};
    for (final application in applications) {
      if (!_isEligibleUniversityChatApplication(application)) {
        continue;
      }
      final universityUserId = '${application['university_user_id'] ?? ''}'
          .trim();
      final universityName =
          '${application['university_name'] ?? application['college_name'] ?? ''}'
              .trim();
      final key = universityUserId.isNotEmpty
          ? universityUserId
          : universityName.toLowerCase();
      if (key.isEmpty || candidatesByKey.containsKey(key)) continue;

      candidatesByKey[key] = {
        'university_user_id': universityUserId,
        'university_name': universityName.isEmpty
            ? 'University'
            : universityName,
        'coordinator_name': '${application['coordinator_name'] ?? ''}'.trim(),
        'coordinator_phone': '${application['coordinator_phone'] ?? ''}'.trim(),
        'latest_message': '',
      };
    }

    return candidatesByKey.values.toList(growable: false);
  }

  Future<void> _openUniversityChatsPage() async {
    var chatCandidates = List<Map<String, dynamic>>.from(_chatUniversities);

    try {
      chatCandidates = await _loadUniversityChatCandidates();
    } catch (error) {
      chatCandidates = List<Map<String, dynamic>>.from(_chatUniversities);
    }

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrganizationUniversityChatsPage(
          initialConversations: chatCandidates,
        ),
      ),
    );

    if (mounted) {
      _loadData(forceRefresh: true);
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
          jobId: training == null
              ? null
              : organizationTrainingId(Map<String, dynamic>.from(training)),
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
                          badgeCount: 0,
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
                          badgeCount: 0,
                          onTap: () {
                            final dashboard = context
                                .findAncestorStateOfType<
                                  _OrganizationDashboardState
                                >();
                            dashboard?.navigateToTab(1);
                          },
                        ),
                        (
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'University Chats',
                          color: Colors.teal,
                          badgeCount: _totalUniversityUnreadCount,
                          onTap: _openUniversityChatsPage,
                        ),
                        (
                          icon: Icons.analytics,
                          title: language.tr('statistics'),
                          color: Colors.purple,
                          badgeCount: 0,
                          onTap: () {
                            _showStatsDialog(context);
                          },
                        ),
                      ];
                      final columns = constraints.maxWidth >= 900
                          ? 4
                          : constraints.maxWidth >= 520
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
                                  badgeCount: action.badgeCount,
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
    int badgeCount = 0,
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
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 24),
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _organizationStudentPrimary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
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
    final trainingId = organizationTrainingId(
      Map<String, dynamic>.from(training),
    );
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
          jobId: training == null
              ? null
              : organizationTrainingId(Map<String, dynamic>.from(training)),
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
          final trainingId = organizationTrainingId(
            Map<String, dynamic>.from(training),
          );
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

class _TestSelectionSummary {
  const _TestSelectionSummary({
    required this.testedStudentIds,
    required this.testedApplicationIds,
    required this.testedEmails,
    required this.testedCount,
    required this.selectedCount,
    required this.notSelectedCount,
    required this.pendingCount,
  });

  const _TestSelectionSummary.empty()
    : testedStudentIds = const <String>{},
      testedApplicationIds = const <String>{},
      testedEmails = const <String>{},
      testedCount = 0,
      selectedCount = 0,
      notSelectedCount = 0,
      pendingCount = 0;

  final Set<String> testedStudentIds;
  final Set<String> testedApplicationIds;
  final Set<String> testedEmails;
  final int testedCount;
  final int selectedCount;
  final int notSelectedCount;
  final int pendingCount;
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
  _TestSelectionSummary _testSelectionSummary =
      const _TestSelectionSummary.empty();
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

  String get _normalizedTrainingId {
    final value = widget.trainingId?.trim() ?? '';
    if (value.isEmpty || value.toLowerCase() == 'null') {
      return '';
    }
    return value;
  }

  bool get _showAllApplications => _normalizedTrainingId.isEmpty;

  bool get _hasSelectedTraining => _normalizedTrainingId.isNotEmpty;

  List<dynamic> get _testSelectionApplicants {
    if (_applicationFilter == 'assigned') {
      return _assignedApplications;
    }
    if (_applicationFilter == 'shortlisted') {
      return _shortlistedApplications;
    }
    final eligibleApplicants = [
      ..._assignedApplications,
      ..._shortlistedApplications,
    ];
    return eligibleApplicants.isNotEmpty ? eligibleApplicants : _applications;
  }

  String get _testSelectionJobId {
    return _resolveTestJobId(_testSelectionApplicants);
  }

  String _resolveTestJobId(List<dynamic> applicants) {
    if (_hasSelectedTraining) return _normalizedTrainingId;
    if (applicants.isEmpty) return '';

    final firstJobId = '${applicants.first['job_id'] ?? ''}'.trim();
    if (firstJobId.isEmpty) return '';

    final allSameJob = applicants.every(
      (app) => '${app['job_id'] ?? ''}'.trim() == firstJobId,
    );
    return allSameJob ? firstJobId : '';
  }

  String get _testSelectionJobTitle {
    return _resolveTestJobTitle(_testSelectionApplicants);
  }

  String _resolveTestJobTitle(List<dynamic> applicants) {
    final widgetTitle = widget.trainingTitle?.trim() ?? '';
    if (widgetTitle.isNotEmpty) return widgetTitle;

    if (applicants.isEmpty) return 'Applications';
    return '${applicants.first['training_title'] ?? applicants.first['job_title'] ?? 'Applications'}';
  }

  String _normalizedLookupValue(Object? value) {
    return '${value ?? ''}'.trim().toLowerCase();
  }

  bool _sameLookupValue(Object? left, Object? right) {
    final normalizedLeft = _normalizedLookupValue(left);
    final normalizedRight = _normalizedLookupValue(right);
    return normalizedLeft.isNotEmpty && normalizedLeft == normalizedRight;
  }

  Map<String, dynamic> _mapManualPlacementToOrganizationApplication(
    Map<String, dynamic> placement,
  ) {
    final placementId = '${placement['id'] ?? ''}'.trim();
    final applicationId = '${placement['application_id'] ?? ''}'.trim();
    final fallbackApplicationId = placementId.isEmpty
        ? 'manual-placement'
        : 'manual-placement:$placementId';

    return {
      'application_id': applicationId.isEmpty
          ? fallbackApplicationId
          : applicationId,
      'job_id': '${placement['job_id'] ?? ''}',
      'status': '${placement['status'] ?? 'assigned'}'.trim().isEmpty
          ? 'assigned'
          : '${placement['status']}',
      'full_name': '${placement['student_name'] ?? 'Student'}',
      'student_name': '${placement['student_name'] ?? 'Student'}',
      'email': '${placement['student_email'] ?? ''}',
      'phone': '${placement['student_phone'] ?? ''}',
      'student_registration_number':
          '${placement['registration_number'] ?? ''}',
      'registration_number': '${placement['registration_number'] ?? ''}',
      'university_name': '${placement['university_name'] ?? ''}',
      'training_title': '${placement['training_title'] ?? 'Placement'}',
      'job_title': '${placement['training_title'] ?? 'Placement'}',
      'company_name': '${placement['company_name'] ?? 'Organization'}',
      'organization_name': '${placement['company_name'] ?? 'Organization'}',
      'company_feedback':
          '${placement['company_response_notes'] ?? placement['coordinator_notes'] ?? ''}',
      'reporting_start_date':
          '${placement['reporting_start_date'] ?? placement['start_date'] ?? ''}',
      'reporting_end_date':
          '${placement['reporting_end_date'] ?? placement['end_date'] ?? ''}',
      'placement_location': '${placement['placement_location'] ?? ''}',
      'placement_department': '${placement['placement_department'] ?? ''}',
      'company_phone': '${placement['company_phone'] ?? ''}',
      'applied_date':
          '${placement['assigned_at'] ?? placement['updated_at'] ?? placement['created_at'] ?? ''}',
      'is_manual_assignment': true,
    };
  }

  List<dynamic> _mergeOrganizationApplications({
    required List<dynamic> apiApplications,
    required List<Map<String, dynamic>> manualPlacements,
  }) {
    final merged = <Map<String, dynamic>>[];
    final seenApplicationIds = <String>{};
    final seenAssignmentKeys = <String>{};

    void addApplication(Map<String, dynamic> app) {
      final applicationId = '${app['application_id'] ?? ''}'.trim();
      if (applicationId.isNotEmpty &&
          !applicationId.startsWith('manual-placement') &&
          !seenApplicationIds.add(applicationId)) {
        return;
      }

      final assignmentKey = [
        _normalizedLookupValue(app['email'] ?? app['student_email']),
        _normalizedLookupValue(app['company_name'] ?? app['organization_name']),
        _normalizedLookupValue(app['job_id']),
        _normalizedLookupValue(app['training_title'] ?? app['job_title']),
      ].join('|');

      if (assignmentKey.trim().replaceAll('|', '').isNotEmpty &&
          !seenAssignmentKeys.add(assignmentKey)) {
        return;
      }

      merged.add(app);
    }

    for (final app in apiApplications.whereType<Map>()) {
      addApplication(app.map((key, value) => MapEntry('$key', value)));
    }

    for (final placement in manualPlacements) {
      addApplication(_mapManualPlacementToOrganizationApplication(placement));
    }

    DateTime parseSortDate(Map<String, dynamic> item) {
      final candidates = [
        item['updated_date'],
        item['updated_at'],
        item['accepted_at'],
        item['applied_date'],
        item['assigned_at'],
        item['created_at'],
      ];
      for (final candidate in candidates) {
        final parsed = DateTime.tryParse('${candidate ?? ''}');
        if (parsed != null) return parsed;
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    merged.sort(
      (left, right) => parseSortDate(right).compareTo(parseSortDate(left)),
    );
    return merged;
  }

  int _countByStatus(String status) {
    if (status == 'pending') {
      return _pendingApplications.length;
    }

    if (status == 'accepted') {
      return _acceptedApplications.length;
    }

    if (status == 'shortlisted') {
      return _shortlistedApplications.length;
    }

    if (status == 'assigned') {
      return _assignedApplications.length;
    }

    return _applications
        .where((app) => '${app['status'] ?? 'pending'}' == status)
        .length;
  }

  bool _isTestedApplication(dynamic app) {
    final applicationId = '${app['application_id'] ?? ''}'.trim();
    final studentId = '${app['student_id'] ?? app['user_id'] ?? ''}'.trim();
    final email = '${app['email'] ?? app['student_email'] ?? ''}'
        .trim()
        .toLowerCase();

    return (applicationId.isNotEmpty &&
            _testSelectionSummary.testedApplicationIds.contains(
              applicationId,
            )) ||
        (studentId.isNotEmpty &&
            _testSelectionSummary.testedStudentIds.contains(studentId)) ||
        (email.isNotEmpty &&
            _testSelectionSummary.testedEmails.contains(email));
  }

  bool _isStudentConfirmedForApplication(dynamic app) {
    if (app['is_manual_assignment'] == true &&
        '${app['status'] ?? ''}'.trim().toLowerCase() == 'accepted') {
      return true;
    }

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

  bool _isAwaitingStudentConfirmation(dynamic app) {
    final status = '${app['status'] ?? 'pending'}'.trim().toLowerCase();
    if (status != 'accepted' ||
        _isOfferConfirmationExpired('${app['application_id'] ?? ''}') ||
        _isStudentConfirmedForApplication(app)) {
      return false;
    }

    final email = '${app['email'] ?? ''}'.trim().toLowerCase();
    final selection = _studentSelectionsByEmail[email];
    final selectedApplicationId =
        '${selection?['selected_application_id'] ?? ''}'.trim();
    return selectedApplicationId.isEmpty;
  }

  List<dynamic> get _pendingApplications {
    return _applications
        .where((app) {
          if (_acceptedApplications.contains(app) ||
              _assignedApplications.contains(app) ||
              _shortlistedApplications.contains(app) ||
              _isTestedApplication(app)) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
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
        .where(
          (app) =>
              '${app['status'] ?? 'pending'}' == 'shortlisted' &&
              !_isTestedApplication(app) &&
              !_acceptedApplications.contains(app),
        )
        .toList(growable: false);
  }

  List<dynamic> get _assignedApplications {
    return _applications
        .where(
          (app) =>
              '${app['status'] ?? 'pending'}' == 'assigned' &&
              !_isTestedApplication(app) &&
              !_acceptedApplications.contains(app),
        )
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
    final companyStatus = '${approval['company_selection_status'] ?? ''}'
        .trim()
        .toLowerCase();

    return choiceStatus == 'expired' ||
        organizationStatus == 'expired' ||
        companyStatus == 'expired';
  }

  String _effectiveOrganizationStatus(dynamic app) {
    if (_isOfferConfirmationExpired('${app['application_id'] ?? ''}')) {
      return 'expired';
    }
    return '${app['status'] ?? 'pending'}'.trim().toLowerCase();
  }

  Future<_TestSelectionSummary> _fetchTestSelectionSummary() async {
    final response = await _apiService.getOrganizationTests(
      jobId: _showAllApplications ? null : _normalizedTrainingId,
    );
    final tests = response['success'] == true && response['data'] is List
        ? List<dynamic>.from(response['data'])
        : <dynamic>[];
    final seenKeys = <String>{};
    final studentIds = <String>{};
    final applicationIds = <String>{};
    final emails = <String>{};
    var selectedCount = 0;
    var notSelectedCount = 0;
    var pendingCount = 0;

    for (final test in tests) {
      final testId = '${test['id'] ?? ''}'.trim();
      if (testId.isEmpty) continue;
      final resultsResponse = await _apiService.getOrganizationTestResults(
        testId,
      );
      final results =
          resultsResponse['success'] == true && resultsResponse['data'] is List
          ? List<dynamic>.from(resultsResponse['data'])
          : <dynamic>[];

      for (final result in results) {
        if ('${result['attempt_status'] ?? ''}'.trim().toLowerCase() !=
            'completed') {
          continue;
        }
        final studentId = '${result['student_id'] ?? ''}'.trim();
        final applicationId = '${result['application_id'] ?? ''}'.trim();
        final email = '${result['email'] ?? ''}'.trim().toLowerCase();
        final key = applicationId.isNotEmpty
            ? 'application:$applicationId'
            : studentId.isNotEmpty
            ? 'student:$studentId'
            : email.isNotEmpty
            ? 'email:$email'
            : 'attempt:${result['attempt_id'] ?? seenKeys.length}';
        if (!seenKeys.add(key)) continue;

        final selectionStatus = '${result['selection_status'] ?? 'pending'}'
            .trim()
            .toLowerCase();
        if (selectionStatus == 'accepted') continue;

        if (studentId.isNotEmpty) {
          studentIds.add(studentId);
        }
        if (applicationId.isNotEmpty) {
          applicationIds.add(applicationId);
        }
        if (email.isNotEmpty) {
          emails.add(email);
        }

        if (selectionStatus == 'selected' || selectionStatus == 'shortlisted') {
          selectedCount += 1;
        } else if (selectionStatus == 'not_selected' ||
            selectionStatus == 'rejected') {
          notSelectedCount += 1;
        } else {
          pendingCount += 1;
        }
      }
    }

    return _TestSelectionSummary(
      testedStudentIds: studentIds,
      testedApplicationIds: applicationIds,
      testedEmails: emails,
      testedCount: selectedCount + notSelectedCount + pendingCount,
      selectedCount: selectedCount,
      notSelectedCount: notSelectedCount,
      pendingCount: pendingCount,
    );
  }

  Future<void> _loadApplications() async {
    final language = context.read<LanguageProvider>();
    final organizationName = _organizationDisplayName(
      context.read<AuthProvider>().user,
      language,
    );
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = _showAllApplications
          ? await _apiService.getOrganizationApplications()
          : await _apiService.getJobApplications(_normalizedTrainingId);
      final manualPlacements = (await _workspaceService.getManualPlacements())
          .where((placement) {
            final matchesOrganization = _sameLookupValue(
              placement['company_name'],
              organizationName,
            );
            if (!matchesOrganization) return false;

            if (_showAllApplications) return true;
            final placementJobId = '${placement['job_id'] ?? ''}'.trim();
            return placementJobId.isNotEmpty &&
                placementJobId == _normalizedTrainingId;
          })
          .toList(growable: false);
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
      final testSelectionSummary = await _fetchTestSelectionSummary();

      if (response['success'] == true) {
        final apiApplications = response['data'] is List
            ? response['data'] as List<dynamic>
            : const <dynamic>[];
        setState(() {
          _applications = _mergeOrganizationApplications(
            apiApplications: apiApplications,
            manualPlacements: manualPlacements,
          );
          _studentSelectionsByEmail = selectionsByEmail;
          _approvalByApplicationId = approvalsByApplicationId;
          _testSelectionSummary = testSelectionSummary;
          _isLoading = false;
        });
      } else {
        setState(() {
          _applications = _mergeOrganizationApplications(
            apiApplications: const <dynamic>[],
            manualPlacements: manualPlacements,
          );
          _error = _applications.isEmpty
              ? response['message']?.toString() ??
                    language.tr('failed_to_load_applications')
              : null;
          _studentSelectionsByEmail = selectionsByEmail;
          _approvalByApplicationId = approvalsByApplicationId;
          _testSelectionSummary = testSelectionSummary;
          _isLoading = false;
        });
      }
    } catch (e) {
      final manualPlacements = (await _workspaceService.getManualPlacements())
          .where(
            (placement) =>
                _sameLookupValue(placement['company_name'], organizationName) &&
                (_showAllApplications ||
                    _sameLookupValue(
                      placement['job_id'],
                      _normalizedTrainingId,
                    )),
          )
          .toList(growable: false);
      final fallbackApplications = _mergeOrganizationApplications(
        apiApplications: const <dynamic>[],
        manualPlacements: manualPlacements,
      );
      setState(() {
        _applications = fallbackApplications;
        _testSelectionSummary = const _TestSelectionSummary.empty();
        _error = fallbackApplications.isEmpty ? _formatErrorMessage(e) : null;
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

  Future<void> _acceptApplicant(Map<String, dynamic> application) async {
    final applicationId = '${application['application_id'] ?? ''}';
    if (applicationId.isEmpty) return;
    final isManualAssignment = application['is_manual_assignment'] == true;

    final reportingDates = await _collectReportingDates();
    if (reportingDates == null) return;

    final updated = await _updateStatus(
      applicationId,
      'accepted',
      reportingStartDate: reportingDates['reporting_start_date'],
      reportingEndDate: reportingDates['reporting_end_date'],
    );

    if (!updated) return;

    if (!isManualAssignment) {
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
    }
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
              OutlinedButton.icon(
                onPressed: () {
                  final description = descriptionController.text.trim();
                  if (description.isEmpty) {
                    ScaffoldMessenger.of(context).showAppSnackBar(
                      const SnackBar(
                        content: Text('Please enter a description.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }

                  Navigator.pop(context, {
                    'issue_type': issueType,
                    'description': description,
                  });
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _organizationStudentPrimary,
                  side: BorderSide(
                    color: _organizationStudentPrimary.withValues(alpha: 0.35),
                  ),
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const Text('Send report'),
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

      final response = await _workspaceService.submitOrganizationReport(
        applicationId: '${application['application_id'] ?? ''}',
        studentName:
            application['full_name']?.toString() ??
            application['student_name']?.toString() ??
            'Student',
        studentEmail: application['email']?.toString() ?? '',
        studentPhone: application['phone']?.toString() ?? '',
        registrationNumber:
            application['student_registration_number']?.toString() ??
            application['registration_number']?.toString() ??
            '',
        universityName: application['university_name']?.toString() ?? '',
        organizationName: organizationName,
        jobTitle: application['training_title']?.toString() ?? 'Placement',
        issueType: payload['issue_type'] ?? 'absent',
        description: payload['description'] ?? '',
      );

      if (!mounted) return;
      final success = response['success'] == true;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            '${response['message'] ?? (success ? 'Report sent successfully.' : 'Failed to send report.')}',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    } finally {
      descriptionController.dispose();
    }
  }

  Future<void> _showUniversityChatSheet(
    Map<String, dynamic> application,
  ) async {
    final universityName =
        application['university_name']?.toString() ??
        application['college_name']?.toString() ??
        '';
    if (universityName.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('University information is not available for chat.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    final conversationResponse = await _apiService
        .getOrganizationUniversityChats();
    final conversations = conversationResponse['data'] is List
        ? List<Map<String, dynamic>>.from(
            (conversationResponse['data'] as List).whereType<Map>().map(
              (item) => item.map((key, value) => MapEntry('$key', value)),
            ),
          )
        : const <Map<String, dynamic>>[];
    final normalizedUniversityName = universityName.trim().toLowerCase();
    Map<String, dynamic>? conversation;
    for (final item in conversations) {
      if ('${item['university_name'] ?? ''}'.trim().toLowerCase() ==
          normalizedUniversityName) {
        conversation = item;
        break;
      }
    }
    if (conversation == null) {
      final fallbackUniversityUserId =
          '${application['university_user_id'] ?? ''}'.trim();
      if (fallbackUniversityUserId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('This university is not available for chat yet.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      conversation = {
        'university_user_id': fallbackUniversityUserId,
        'university_name': universityName,
      };
    }

    final composerController = TextEditingController();
    final universityUserId = '${conversation['university_user_id'] ?? ''}'
        .trim();
    final initialResponse = await _apiService
        .getOrganizationUniversityChatMessages(universityUserId);
    final initialMessages = initialResponse['data'] is List
        ? List<Map<String, dynamic>>.from(
            (initialResponse['data'] as List).whereType<Map>().map(
              (item) => item.map((key, value) => MapEntry('$key', value)),
            ),
          )
        : <Map<String, dynamic>>[];
    if (!mounted) return;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) {
          var messages = List<Map<String, dynamic>>.from(initialMessages);
          var isSending = false;
          String? deletingMessageId;
          String? editingMessageId;
          String? composerError;

          String formatChatTime(String value) {
            final date = DateTime.tryParse(value)?.toLocal();
            if (date == null) return '';
            final hour = date.hour.toString().padLeft(2, '0');
            final minute = date.minute.toString().padLeft(2, '0');
            return '$hour:$minute';
          }

          String messageIdOf(Map<String, dynamic> item) =>
              '${item['id'] ?? ''}'.trim();

          bool isOwnMessage(Map<String, dynamic> item) {
            final senderRole = '${item['sender_role'] ?? ''}'
                .trim()
                .toLowerCase();
            return senderRole == 'organization' || senderRole == 'company';
          }

          void startEditingMessage(
            StateSetter setModalState,
            Map<String, dynamic> item,
          ) {
            final messageId = messageIdOf(item);
            if (messageId.isEmpty ||
                !isOwnMessage(item) ||
                deletingMessageId != null) {
              return;
            }

            composerController.text = '${item['message'] ?? ''}'.trim();
            composerController.selection = TextSelection.fromPosition(
              TextPosition(offset: composerController.text.length),
            );
            setModalState(() {
              editingMessageId = messageId;
              composerError = null;
            });
          }

          void cancelEditing(StateSetter setModalState) {
            composerController.clear();
            setModalState(() {
              editingMessageId = null;
              composerError = null;
            });
          }

          Future<void> sendMessage(StateSetter setModalState) async {
            final text = composerController.text.trim();
            final currentEditingMessageId = editingMessageId;
            if (isSending) return;
            if (text.isEmpty) {
              setModalState(() => composerError = 'Write a message first.');
              return;
            }

            setModalState(() {
              composerError = null;
              isSending = true;
            });
            final response = currentEditingMessageId == null
                ? await _apiService.sendOrganizationUniversityChatMessage(
                    universityUserId: universityUserId,
                    message: text,
                  )
                : await _apiService.updateOrganizationUniversityChatMessage(
                    universityUserId: universityUserId,
                    messageId: currentEditingMessageId,
                    message: text,
                  );

            if (!sheetContext.mounted) return;

            if (response['success'] == true &&
                response['data'] is Map<String, dynamic>) {
              composerController.clear();
              setModalState(() {
                if (currentEditingMessageId == null) {
                  messages = [
                    ...messages,
                    Map<String, dynamic>.from(response['data']),
                  ];
                } else {
                  final updatedMessage = Map<String, dynamic>.from(
                    response['data'],
                  );
                  messages = messages
                      .map(
                        (message) =>
                            messageIdOf(message) == currentEditingMessageId
                            ? updatedMessage
                            : message,
                      )
                      .toList(growable: false);
                }
                editingMessageId = null;
                isSending = false;
              });
            } else {
              setModalState(() => isSending = false);
              ScaffoldMessenger.of(sheetContext).showAppSnackBar(
                SnackBar(
                  content: Text(
                    '${response['message'] ?? 'Failed to send message.'}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          Future<void> deleteMessage(
            StateSetter setModalState,
            Map<String, dynamic> item,
          ) async {
            final messageId = '${item['id'] ?? ''}'.trim();
            if (messageId.isEmpty || deletingMessageId != null) return;

            final confirmed = await showDialog<bool>(
              context: sheetContext,
              builder: (context) => AlertDialog(
                title: const Text('Delete message?'),
                content: const Text(
                  'This will remove the message from your chat only.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            );

            if (confirmed != true) return;

            setModalState(() => deletingMessageId = messageId);
            final response = await _apiService
                .deleteOrganizationUniversityChatMessage(
                  universityUserId: universityUserId,
                  messageId: messageId,
                );

            if (!sheetContext.mounted) return;

            if (response['success'] == true) {
              setModalState(() {
                messages = messages
                    .where((message) => messageIdOf(message) != messageId)
                    .toList(growable: false);
                if (editingMessageId == messageId) {
                  editingMessageId = null;
                  composerController.clear();
                }
                deletingMessageId = null;
              });
              ScaffoldMessenger.of(sheetContext).showAppSnackBar(
                SnackBar(
                  content: Text(
                    '${response['message'] ?? 'Message deleted successfully.'}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            } else {
              setModalState(() => deletingMessageId = null);
              ScaffoldMessenger.of(sheetContext).showAppSnackBar(
                SnackBar(
                  content: Text(
                    '${response['message'] ?? 'Failed to delete message.'}',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }

          Future<void> showMessageActions(
            StateSetter setModalState,
            Map<String, dynamic> item,
          ) async {
            if (messageIdOf(item).isEmpty || deletingMessageId != null) return;

            final action = await showModalBottomSheet<String>(
              context: sheetContext,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwnMessage(item))
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Edit message'),
                        onTap: () => Navigator.of(context).pop('edit'),
                      ),
                    ListTile(
                      leading: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red,
                      ),
                      title: const Text('Delete message'),
                      textColor: Colors.red,
                      iconColor: Colors.red,
                      onTap: () => Navigator.of(context).pop('delete'),
                    ),
                  ],
                ),
              ),
            );

            if (action == 'edit') {
              startEditingMessage(setModalState, item);
            } else if (action == 'delete') {
              await deleteMessage(setModalState, item);
            }
          }

          return StatefulBuilder(
            builder: (context, setModalState) => SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  clipBehavior: Clip.antiAlias,
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height * 0.72,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Chat with $universityName',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _organizationStudentPrimaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Use this chat for placement coordination and follow-up.',
                                style: TextStyle(color: Colors.black54),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap any message for actions. You can edit your own messages.',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: messages.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No messages yet. Start the conversation.',
                                    style: TextStyle(color: Colors.black54),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(16),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final item = messages[index];
                                    final isMine = isOwnMessage(item);
                                    final bubbleColor = isMine
                                        ? _organizationStudentPrimary
                                        : const Color(0xFFEFF3F8);
                                    final textColor = isMine
                                        ? Colors.white
                                        : _organizationStudentPrimaryDark;
                                    final isDeleting =
                                        deletingMessageId == messageIdOf(item);
                                    final isEdited =
                                        '${item['edited_at'] ?? ''}'
                                            .trim()
                                            .isNotEmpty;

                                    return Align(
                                      alignment: isMine
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: GestureDetector(
                                        onTap: () => showMessageActions(
                                          setModalState,
                                          item,
                                        ),
                                        onLongPress: () =>
                                            deleteMessage(setModalState, item),
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          constraints: const BoxConstraints(
                                            maxWidth: 360,
                                          ),
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: bubbleColor,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${item['message'] ?? ''}',
                                                style: TextStyle(
                                                  color: textColor,
                                                  height: 1.4,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Text(
                                                    formatChatTime(
                                                      '${item['created_at'] ?? ''}',
                                                    ),
                                                    style: TextStyle(
                                                      color: textColor
                                                          .withValues(
                                                            alpha: 0.82,
                                                          ),
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  if (isDeleting) ...[
                                                    const SizedBox(width: 8),
                                                    SizedBox(
                                                      width: 12,
                                                      height: 12,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color: textColor,
                                                          ),
                                                    ),
                                                  ],
                                                  if (isEdited) ...[
                                                    const SizedBox(width: 8),
                                                    Text(
                                                      'edited',
                                                      style: TextStyle(
                                                        color: textColor
                                                            .withValues(
                                                              alpha: 0.82,
                                                            ),
                                                        fontSize: 11,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (editingMessageId != null) ...[
                                Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _organizationStudentSurface,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: _organizationStudentBorder,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: _organizationStudentPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Editing message',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color:
                                                _organizationStudentPrimaryDark,
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: isSending
                                            ? null
                                            : () =>
                                                  cancelEditing(setModalState),
                                        icon: const Icon(Icons.close_rounded),
                                        tooltip: 'Cancel edit',
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              Text(
                                editingMessageId == null
                                    ? 'Send message to university'
                                    : 'Update message',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _organizationStudentPrimaryDark,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: composerController,
                                      minLines: 1,
                                      maxLines: 4,
                                      onChanged: (_) {
                                        if (composerError != null) {
                                          setModalState(
                                            () => composerError = null,
                                          );
                                        }
                                      },
                                      decoration: InputDecoration(
                                        hintText: editingMessageId == null
                                            ? 'Write a message'
                                            : 'Edit message',
                                        errorText: composerError,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  FilledButton.icon(
                                    onPressed: isSending
                                        ? null
                                        : () => sendMessage(setModalState),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          _organizationStudentPrimary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    icon: isSending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Icon(
                                            editingMessageId == null
                                                ? Icons.send_rounded
                                                : Icons.check_rounded,
                                          ),
                                    label: Text(
                                      isSending
                                          ? 'Saving...'
                                          : editingMessageId == null
                                          ? 'Send'
                                          : 'Save',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } finally {
      composerController.dispose();
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
    try {
      final isManualPlacement = applicationId.startsWith('manual-placement');
      final organizationName = isManualPlacement
          ? _organizationDisplayName(
              context.read<AuthProvider>().user,
              context.read<LanguageProvider>(),
            )
          : '';

      final response = isManualPlacement
          ? await _workspaceService.updateManualPlacementStatus(
              placementId: applicationId,
              status: status,
              companyName: organizationName,
              companyFeedback: feedback,
              reportingStartDate: reportingStartDate,
              reportingEndDate: reportingEndDate,
            )
          : await _apiService.updateApplicationStatusWithLetter(
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
        final successMessage = switch (status) {
          'shortlisted' => 'Student shortlisted successfully.',
          'accepted' => 'Student accepted successfully.',
          'rejected' => 'Student rejected successfully.',
          _ => 'Application updated successfully.',
        };
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
        _loadApplications();
        return true;
      } else if (mounted) {
        ScaffoldMessenger.of(context).showAppSnackBar(
          SnackBar(
            content: Text(
              response['message']?.toString() ?? 'Failed to update status',
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
      case 'assigned':
        return const Color(0xFF2563EB);
      case 'shortlisted':
        return const Color(0xFF5C7FA3);
      case '':
        return const Color(0xFF7D6AA8);
      case 'accepted':
        return const Color(0xFF5D8D73);
      case 'expired':
        return const Color(0xFFD97706);
      case 'rejected':
        return const Color(0xFFB26B6B);
      default:
        return const Color(0xFFB38A45);
    }
  }

  Color _statusBackground(String status) {
    switch (status) {
      case 'assigned':
        return const Color(0xFFEFF6FF);
      case 'shortlisted':
        return const Color(0xFFEAF1F7);
      case '':
        return const Color(0xFFF1ECF8);
      case 'accepted':
        return const Color(0xFFEAF4EE);
      case 'expired':
        return const Color(0xFFFFF4EC);
      case 'rejected':
        return const Color(0xFFF8ECEC);
      default:
        return const Color(0xFFF8F1E3);
    }
  }

  bool _hasReachedStatus(String currentStatus, String targetStatus) {
    const order = ['pending', 'assigned', 'shortlisted', '', 'accepted'];
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

  Future<void> _openTestSelection({List<dynamic>? applicantsOverride}) async {
    final testApplicants = applicantsOverride ?? _testSelectionApplicants;
    final testJobId = applicantsOverride == null
        ? _testSelectionJobId
        : _resolveTestJobId(testApplicants);
    final testJobTitle = applicantsOverride == null
        ? _testSelectionJobTitle
        : _resolveTestJobTitle(testApplicants);

    if (testJobId.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text(
            'Select one training or filter shortlisted students from one training before assigning a test.',
          ),
        ),
      );
      return;
    }

    if (testApplicants.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('No students available for test assignment.'),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyTestManagementScreen(
          jobId: testJobId,
          jobTitle: testJobTitle,
          applicants: testApplicants,
        ),
      ),
    );

    if (!mounted) return;
    await _loadApplications();
  }

  String _escapeCsvCell(String value) {
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  List<dynamic> _applicationsForCurrentExport() {
    return switch (_applicationFilter) {
      'pending' => _pendingApplications,
      'accepted' => _acceptedApplications,
      'assigned' => _assignedApplications,
      'shortlisted' => _shortlistedApplications,
      _ => _applications,
    };
  }

  String _currentExportLabel() {
    return switch (_applicationFilter) {
      'pending' => 'pending students',
      'accepted' => 'accepted students',
      'assigned' => 'assigned students',
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

  void _showPendingApplications() {
    setState(() => _applicationFilter = 'pending');
  }

  void _showShortlistedApplications() {
    setState(() => _applicationFilter = 'shortlisted');
  }

  void _showAssignedApplications() {
    setState(() => _applicationFilter = 'assigned');
  }

  void _showAllApplicationsList() {
    setState(() => _applicationFilter = 'all');
  }

  Future<void> _openCompletedTestTakers() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompanyTestManagementScreen(
          jobId: _hasSelectedTraining ? _testSelectionJobId : null,
          jobTitle: _hasSelectedTraining ? _testSelectionJobTitle : null,
          applicants: _applications,
          resultsOnly: true,
        ),
      ),
    );

    if (!mounted) return;
    await _loadApplications();
  }

  Widget _buildApplicationsExportButton() {
    return Row(
      mainAxisSize: MainAxisSize.min,
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

  Widget _buildApplicationsActionBar() {
    final canAssignTest =
        _hasSelectedTraining ||
        _assignedApplications.isNotEmpty ||
        _shortlistedApplications.isNotEmpty;

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      alignment: WrapAlignment.end,
      children: [
        if (canAssignTest)
          ElevatedButton.icon(
            onPressed: _openTestSelection,
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
            icon: const Icon(Icons.quiz_outlined, size: 18),
            label: const Text('Assign test'),
          ),
        ElevatedButton.icon(
          onPressed: _openCompletedTestTakers,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F766E),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            minimumSize: const Size(0, 40),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.fact_check_outlined, size: 18),
          label: const Text('Tested'),
        ),
        _buildApplicationsExportButton(),
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
          _buildApplicationsActionBar(),
          const SizedBox(height: 14),
          if (acceptedApplicants.isEmpty)
            Text(
              'No accepted students yet.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            )
          else
            _buildAcceptedApplicantsTable(acceptedApplicants),
        ],
      ),
    );
  }

  Widget _buildAcceptedApplicantsTable(List<dynamic> acceptedApplicants) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(980.0, constraints.maxWidth);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: _organizationStudentBorder),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  _organizationStudentSurface,
                ),
                headingTextStyle: const TextStyle(
                  color: _organizationStudentPrimaryDark,
                  fontWeight: FontWeight.w800,
                ),
                dataTextStyle: TextStyle(
                  color: Colors.grey.shade800,
                  fontWeight: FontWeight.w500,
                ),
                dataRowMinHeight: 72,
                dataRowMaxHeight: 88,
                headingRowHeight: 66,
                columnSpacing: 28,
                horizontalMargin: 16,
                dividerThickness: 0.6,
                showBottomBorder: true,
                columns: const [
                  DataColumn(label: Text('Serial no')),
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Registration number')),
                  DataColumn(label: Text('University')),
                  DataColumn(label: Text('Phone number')),
                ],
                rows: acceptedApplicants
                    .asMap()
                    .entries
                    .map((entry) {
                      final index = entry.key + 1;
                      final app = entry.value;
                      final fullName = '${app['full_name'] ?? 'Applicant'}'
                          .trim();
                      final registrationNumber =
                          '${app['student_registration_number'] ?? app['registration_number'] ?? 'N/A'}'
                              .trim();
                      final universityName =
                          '${app['university_name'] ?? 'N/A'}'.trim();
                      final phoneNumber = '${app['phone'] ?? 'N/A'}'.trim();

                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color?>((
                          states,
                        ) {
                          if (states.contains(WidgetState.hovered)) {
                            return _organizationStudentSurfaceSoft.withValues(
                              alpha: 0.65,
                            );
                          }
                          return null;
                        }),
                        cells: [
                          DataCell(Text('$index')),
                          DataCell(
                            _buildAcceptedApplicantText(fullName, width: 180),
                          ),
                          DataCell(
                            _buildAcceptedApplicantText(
                              registrationNumber,
                              width: 180,
                            ),
                          ),
                          DataCell(
                            _buildAcceptedApplicantText(
                              universityName,
                              width: 240,
                            ),
                          ),
                          DataCell(
                            _buildAcceptedApplicantText(
                              phoneNumber,
                              width: 150,
                            ),
                          ),
                        ],
                      );
                    })
                    .toList(growable: false),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAcceptedApplicantText(String value, {required double width}) {
    final text = value.trim().isEmpty ? 'N/A' : value.trim();
    return SizedBox(
      width: width,
      child: Text(text, maxLines: 2, overflow: TextOverflow.ellipsis),
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
    final rawStatus = '${app['status'] ?? 'pending'}'.trim().toLowerCase();
    final status = _effectiveOrganizationStatus(app);
    final selection = _studentSelectionsByEmail[email.trim().toLowerCase()];
    final statusColor = _statusColor(status);
    final applicationId = '${app['application_id']}';
    final hasBackendApplication = !applicationId.startsWith('manual-placement');
    final isManualAssignment = app['is_manual_assignment'] == true;
    final trainingTitle =
        '${app['training_title'] ?? app['job_title'] ?? widget.trainingTitle ?? language.tr('selected_training')}';
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
        hasBackendApplication &&
        (status == 'pending' || status == 'assigned') &&
        (!hasSupportiveDocument || isDocumentAuthentic);
    final canAccept =
        (hasBackendApplication || isManualAssignment) &&
        (status == 'assigned' || status == 'shortlisted' || status == '') &&
        (!hasSupportiveDocument || isDocumentAuthentic);
    final canReject =
        (hasBackendApplication || isManualAssignment) &&
        (status == 'pending' ||
            status == 'assigned' ||
            status == 'shortlisted' ||
            status == '') &&
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
          if (rawStatus == 'accepted' && isOfferExpired) ...[
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
                'The student did not confirm this offer within 48 hours, so the offer expired and this slot is open again.',
                style: TextStyle(
                  color: Color(0xFF9A3412),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ] else if (status == 'accepted' &&
              _isAwaitingStudentConfirmation(app)) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFB38A45)),
              ),
              child: Text(
                '$fullName has been accepted and is waiting to confirm your organization.',
                style: const TextStyle(
                  color: Color(0xFF8A5D13),
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
              if (status == 'accepted')
                OutlinedButton.icon(
                  onPressed: () =>
                      _showUniversityChatSheet(Map<String, dynamic>.from(app)),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _organizationStudentPrimary,
                    side: BorderSide(
                      color: _organizationStudentPrimary.withValues(
                        alpha: 0.45,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 11,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                  label: const Text('Chat with University'),
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
      'pending' => _pendingApplications,
      'accepted' => _acceptedApplications,
      'assigned' => _assignedApplications,
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
                  label: language.tr('status_pending'),
                  value: '${_countByStatus('pending')}',
                  icon: Icons.hourglass_top_rounded,
                  color: const Color(0xFFB38A45),
                  isSelected: _applicationFilter == 'pending',
                  onTap: _showPendingApplications,
                ),
                _buildSummaryCard(
                  label: 'Assigned',
                  value: '${_countByStatus('assigned')}',
                  icon: Icons.assignment_turned_in_outlined,
                  color: const Color(0xFF2563EB),
                  isSelected: _applicationFilter == 'assigned',
                  onTap: _showAssignedApplications,
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
                  label: 'Tested',
                  value: '${_testSelectionSummary.testedCount}',
                  icon: Icons.fact_check_outlined,
                  color: const Color(0xFF0F766E),
                  isSelected: false,
                  onTap: _openCompletedTestTakers,
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
            _buildApplicationsActionBar(),
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
                        : _applicationFilter == 'pending'
                        ? 'No pending students yet.'
                        : _applicationFilter == 'assigned'
                        ? 'No assigned students yet.'
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
    final organization = _organizationProfileData(user) ?? {};
    final organizationName =
        '${organization['company_name'] ?? organization['organization_name'] ?? language.tr('organization')}';
    final rawLogoUrl = organization['logo_url']?.toString();
    final logoUrls = rawLogoUrl == null || rawLogoUrl.isEmpty
        ? const <String>[]
        : ApiService().resolveAssetUrlCandidates(rawLogoUrl);
    final hasLogo = logoUrls.isNotEmpty;

    Future<void> openEditProfile() async {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const EditOrganizationProfileScreen(),
        ),
      );
      if (!context.mounted) return;
      final dashboard = context
          .findAncestorStateOfType<_OrganizationDashboardState>();
      dashboard?._handleRouteNavigationResult(result);
    }

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
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: openEditProfile,
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
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: openEditProfile,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _organizationStudentPrimary,
                              side: BorderSide(
                                color: _organizationStudentPrimary.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.image_outlined, size: 18),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                hasLogo ? 'Change Logo' : 'Upload Logo',
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
