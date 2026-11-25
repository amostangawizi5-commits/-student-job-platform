import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/assets.dart';
import '../utils/theme.dart';
import 'auth/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String completionPreferenceKey = 'onboarding_completed';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  static const List<_OnboardingPageData> _pages = [
    _OnboardingPageData(
      title: 'Discover Practical Training Opportunities',
      description:
          'Find practical training opportunities that match your academic program and year of study.',
      illustration: _OnboardingIllustrationType.discover,
    ),
    _OnboardingPageData(
      title: 'Apply for Opportunities Easily',
      description:
          'Submit your practical training applications and required documents directly through IPTKiganjani.',
      illustration: _OnboardingIllustrationType.apply,
    ),
    _OnboardingPageData(
      title: 'Track Your Applications',
      description:
          'Stay informed about your application progress and receive responses from organizations you have applied to.',
      illustration: _OnboardingIllustrationType.track,
    ),
  ];

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finishOnboarding() async {
    if (_isCompleting) return;
    setState(() => _isCompleting = true);

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(OnboardingScreen.completionPreferenceKey, true);

    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  void _showNextPage() {
    if (_isLastPage) {
      _finishOnboarding();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 12, 14, 4),
              child: Row(
                children: [
                  Image.asset(AppAssets.splashLogo, width: 38, height: 38),
                  const SizedBox(width: 10),
                  Text(
                    'IPTKIGANJANI',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.primaryDark,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const Spacer(),
                  if (!_isLastPage)
                    TextButton(
                      onPressed: _isCompleting ? null : _finishOnboarding,
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: const Text('Skip'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) => setState(() => _currentPage = page),
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return _OnboardingPage(data: page);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
              child: Row(
                children: [
                  Row(
                    children: List.generate(
                      _pages.length,
                      (index) => AnimatedContainer(
                        duration: const Duration(milliseconds: 240),
                        curve: Curves.easeOut,
                        margin: const EdgeInsets.only(right: 7),
                        width: index == _currentPage ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: index == _currentPage
                              ? AppTheme.primaryBlue
                              : AppTheme.borderGrey,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _isCompleting ? null : _showNextPage,
                    icon: Icon(
                      _isLastPage
                          ? Icons.arrow_forward_rounded
                          : Icons.chevron_right_rounded,
                    ),
                    label: Text(_isLastPage ? 'Get Started' : 'Next'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppTheme.primaryBlue.withValues(
                        alpha: 0.55,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
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
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final illustrationHeight = (constraints.maxHeight * 0.5)
            .clamp(205.0, 350.0)
            .toDouble();

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 6),
          child: Column(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.94, end: 1),
                duration: const Duration(milliseconds: 550),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: SizedBox(
                  height: illustrationHeight,
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: SizedBox(
                      width: 330,
                      height: 350,
                      child: _OnboardingIllustration(type: data.illustration),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.primaryDark,
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 14),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 390),
                child: Text(
                  data.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _OnboardingIllustration extends StatelessWidget {
  const _OnboardingIllustration({required this.type});

  final _OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(34),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: type == _OnboardingIllustrationType.track
                ? const [Color(0xFFEAF7F4), Color(0xFFF3F7FF)]
                : const [Color(0xFFEAF2FF), Color(0xFFF7FAFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -45,
              right: -25,
              child: _SoftCircle(
                size: 155,
                color: AppTheme.primaryBlue.withValues(alpha: 0.08),
              ),
            ),
            Positioned(
              bottom: -70,
              left: -32,
              child: _SoftCircle(
                size: 175,
                color: AppTheme.accentGold.withValues(alpha: 0.15),
              ),
            ),
            Center(child: _PhoneIllustration(type: type)),
            Positioned(left: 20, bottom: 22, child: _StudentBadge(type: type)),
            Positioned(right: 20, top: 24, child: _ContextBadge(type: type)),
          ],
        ),
      ),
    );
  }
}

class _PhoneIllustration extends StatelessWidget {
  const _PhoneIllustration({required this.type});

  final _OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 142,
      height: 232,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryDark,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.2),
            blurRadius: 25,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: _PhoneScreen(type: type),
      ),
    );
  }
}

class _PhoneScreen extends StatelessWidget {
  const _PhoneScreen({required this.type});

  final _OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    if (type == _OnboardingIllustrationType.discover) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniHeader(label: 'Find training'),
          const SizedBox(height: 10),
          _MiniSearch(),
          const SizedBox(height: 10),
          const _MiniSectionLabel(label: 'Recommended for you'),
          const SizedBox(height: 7),
          const _MiniJobCard(
            icon: Icons.business_center_rounded,
            title: 'Technology internship',
            subtitle: 'Dar es Salaam',
            color: AppTheme.primaryBlue,
          ),
          const SizedBox(height: 7),
          const _MiniJobCard(
            icon: Icons.account_balance_rounded,
            title: 'Finance placement',
            subtitle: 'Arusha',
            color: AppTheme.primaryGreen,
          ),
        ],
      );
    }

    if (type == _OnboardingIllustrationType.apply) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniHeader(label: 'Your application'),
          const SizedBox(height: 14),
          const Text(
            'Technology internship',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
            ),
          ),
          const SizedBox(height: 10),
          const _MiniProgressStep(
            icon: Icons.check_rounded,
            label: 'Application details',
            complete: true,
          ),
          const _MiniProgressLine(),
          const _MiniProgressStep(
            icon: Icons.upload_file_rounded,
            label: 'Upload documents',
            complete: false,
          ),
          const _MiniProgressLine(),
          const _MiniProgressStep(
            icon: Icons.send_rounded,
            label: 'Submit application',
            complete: false,
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Apply now',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _MiniHeader(label: 'Application updates'),
        const SizedBox(height: 13),
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppTheme.successLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryGreen,
                size: 18,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Application shortlisted',
                  style: TextStyle(
                    color: Color(0xFF065F46),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const _MiniSectionLabel(label: 'Recent activity'),
        const SizedBox(height: 8),
        const _MiniActivity(
          icon: Icons.mark_email_read_rounded,
          label: 'Organization sent a response',
          time: 'Today',
        ),
        const SizedBox(height: 10),
        const _MiniActivity(
          icon: Icons.visibility_rounded,
          label: 'Application viewed',
          time: 'Yesterday',
        ),
      ],
    );
  }
}

class _StudentBadge extends StatelessWidget {
  const _StudentBadge({required this.type});

  final _OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          const CircleAvatar(
            radius: 23,
            backgroundColor: Color(0xFFDDEAFF),
            child: Icon(
              Icons.person_rounded,
              color: AppTheme.primaryBlue,
              size: 34,
            ),
          ),
          if (type == _OnboardingIllustrationType.apply)
            const Positioned(
              right: 3,
              bottom: 8,
              child: _TinyIconBadge(
                icon: Icons.upload_file_rounded,
                color: AppTheme.accentGold,
              ),
            ),
          if (type == _OnboardingIllustrationType.track)
            const Positioned(
              right: 3,
              bottom: 8,
              child: _TinyIconBadge(
                icon: Icons.notifications_active_rounded,
                color: AppTheme.primaryGreen,
              ),
            ),
        ],
      ),
    );
  }
}

class _ContextBadge extends StatelessWidget {
  const _ContextBadge({required this.type});

  final _OnboardingIllustrationType type;

  @override
  Widget build(BuildContext context) {
    final isDiscover = type == _OnboardingIllustrationType.discover;
    final isApply = type == _OnboardingIllustrationType.apply;
    final icon = isDiscover
        ? Icons.school_rounded
        : isApply
        ? Icons.description_rounded
        : Icons.notifications_rounded;
    final label = isDiscover
        ? 'For students'
        : isApply
        ? 'Secure upload'
        : 'Stay updated';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryDark.withValues(alpha: 0.1),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniHeader extends StatelessWidget {
  const _MiniHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.arrow_back_rounded,
          size: 13,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Icon(
          Icons.more_horiz_rounded,
          size: 15,
          color: AppTheme.textSecondary,
        ),
      ],
    );
  }
}

class _MiniSearch extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surfaceSoft,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderGrey.withValues(alpha: 0.6)),
      ),
      child: const Row(
        children: [
          Icon(Icons.search_rounded, size: 13, color: AppTheme.primaryBlue),
          SizedBox(width: 5),
          Expanded(
            child: Text(
              'Search opportunities',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AppTheme.textLight, fontSize: 8),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniSectionLabel extends StatelessWidget {
  const _MiniSectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 8,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MiniJobCard extends StatelessWidget {
  const _MiniJobCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderGrey.withValues(alpha: 0.65)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textLight,
                    fontSize: 7,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 14,
            color: AppTheme.textLight,
          ),
        ],
      ),
    );
  }
}

class _MiniProgressStep extends StatelessWidget {
  const _MiniProgressStep({
    required this.icon,
    required this.label,
    required this.complete,
  });

  final IconData icon;
  final String label;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 23,
          height: 23,
          decoration: BoxDecoration(
            color: complete
                ? AppTheme.primaryGreen
                : AppTheme.primaryBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 13,
            color: complete ? Colors.white : AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryDark,
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _MiniProgressLine extends StatelessWidget {
  const _MiniProgressLine();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 11),
      height: 12,
      width: 1,
      color: AppTheme.borderGrey,
    );
  }
}

class _MiniActivity extends StatelessWidget {
  const _MiniActivity({
    required this.icon,
    required this.label,
    required this.time,
  });

  final IconData icon;
  final String label;
  final String time;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.circle, size: 5, color: AppTheme.primaryGreen),
        const SizedBox(width: 7),
        Icon(icon, size: 14, color: AppTheme.primaryBlue),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 8,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          time,
          style: const TextStyle(color: AppTheme.textLight, fontSize: 7),
        ),
      ],
    );
  }
}

class _TinyIconBadge extends StatelessWidget {
  const _TinyIconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(icon, color: Colors.white, size: 12),
    );
  }
}

class _SoftCircle extends StatelessWidget {
  const _SoftCircle({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.illustration,
  });

  final String title;
  final String description;
  final _OnboardingIllustrationType illustration;
}

enum _OnboardingIllustrationType { discover, apply, track }
