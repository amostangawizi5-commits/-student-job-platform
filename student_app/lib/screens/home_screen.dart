import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/job.dart';
import '../services/api_service.dart';
import '../utils/assets.dart';
import '../utils/theme.dart';
import '../widgets/job_card.dart';
import 'auth/login_screen.dart';
import 'auth/register_screen.dart';

class _TrainingCategory {
  const _TrainingCategory({
    required this.title,
    required this.description,
    required this.students,
  });

  final String title;
  final String description;
  final String students;
}

const List<_TrainingCategory> _trainingCategories = [
  _TrainingCategory(
    title: 'Industrial Practical Training (IPT)',
    description:
        'Hands-on training in industries, companies, government institutions, '
        'or NGOs to apply theoretical knowledge.',
    students: 'Engineering, ICT, Business, Agriculture, Health Sciences.',
  ),
  _TrainingCategory(
    title: 'Field Practical Training (FPT)',
    description:
        'Field-based experience involving data collection, surveys, community '
        'work, and field observations.',
    students: 'Geography, Environmental Science, Sociology, Agriculture.',
  ),
  _TrainingCategory(
    title: 'Teaching Practice (TP)',
    description:
        'Supervised teaching experience in schools where students practice '
        'classroom instruction.',
    students: 'Education.',
  ),
  _TrainingCategory(
    title: 'Clinical Practice/Clinical Rotation',
    description:
        'Practical training in hospitals and health facilities under '
        'supervision.',
    students: 'Medicine, Nursing, Pharmacy, Allied Health.',
  ),
  _TrainingCategory(
    title: 'Internship Programmes',
    description:
        'Structured workplace learning aimed at improving employability skills, '
        'usually after coursework completion.',
    students: 'Final-year students and recent graduates.',
  ),
  _TrainingCategory(
    title: 'Laboratory/Research Training',
    description:
        'Research-oriented practical work conducted in laboratories or research '
        'institutions.',
    students: 'Science and research-based programmes.',
  ),
  _TrainingCategory(
    title: 'Community-Based Training (CBT)',
    description:
        'Training involving direct engagement with communities to address '
        'social or health challenges.',
    students: 'Public Health, Social Work, Development Studies.',
  ),
  _TrainingCategory(
    title: 'Legal Practice/Chambers Attachment',
    description:
        'Practical legal training in courts, law firms, and legal institutions.',
    students: 'Law.',
  ),
  _TrainingCategory(
    title: 'Teaching Assistantship/Academic Attachment',
    description:
        'Training involving assisting lecturers in academic activities and '
        'tutorials.',
    students: 'Postgraduate students and selected undergraduate programmes.',
  ),
  _TrainingCategory(
    title: 'Professional Field Attachment',
    description:
        'Programme-specific practical training in professional settings.',
    students: 'Accounting, Procurement, Human Resource, Tourism.',
  ),
];

const String _callCenterPhones = '07 417 426 27\n+255 627 992 2627';
const String _callCenterWorkingHours = 'Monday - Friday\n07:30 - 17:30';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  int _expandedFaqIndex = 0;

  bool get _isMobileDevice =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _openRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void _openHomePage() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _openTrainingPage() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const TrainingPortalScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isMobileDevice) {
      return const LoginScreen();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            return SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  if (!isCompact)
                    _PortalHeader(
                      isCompact: isCompact,
                      onHomePressed: _openHomePage,
                      onTrainingPressed: _openTrainingPage,
                      onLoginPressed: _openLogin,
                    ),
                  _HeroSection(
                    isCompact: isCompact,
                    onBrowsePressed: _openTrainingPage,
                    onCreateAccountPressed: _openRegister,
                    onLoginPressed: _openLogin,
                  ),
                  if (!isCompact)
                    _VacancyCategories(
                      isCompact: isCompact,
                      onCategorySelected: _openTrainingPage,
                    ),
                  if (!isCompact) _ApplicationTips(isCompact: isCompact),
                  if (!isCompact)
                    _FaqSection(
                      expandedIndex: _expandedFaqIndex,
                      onChanged: (index) {
                        setState(() => _expandedFaqIndex = index);
                      },
                    ),
                  _PortalFooter(showDownloadBadges: !isCompact),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class TrainingPortalScreen extends StatelessWidget {
  const TrainingPortalScreen({super.key});

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            return CustomScrollView(
              slivers: [
                if (!isCompact)
                  SliverToBoxAdapter(
                    child: _PortalHeader(
                      isCompact: isCompact,
                      isTrainingSelected: true,
                      onHomePressed: () => _goHome(context),
                      onTrainingPressed: () {},
                      onLoginPressed: () => _openLogin(context),
                    ),
                  ),
                SliverToBoxAdapter(
                  child: _TrainingListSection(
                    isCompact: isCompact,
                    onLoginPressed: () => _openLogin(context),
                  ),
                ),
                if (!isCompact)
                  const SliverToBoxAdapter(child: _PortalFooter()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PublicInfoPage extends StatelessWidget {
  const _PublicInfoPage({
    required this.title,
    required this.subtitle,
    required this.sections,
    this.showSupportContacts = false,
  });

  factory _PublicInfoPage.privacyPolicy() {
    return const _PublicInfoPage(
      title: 'Privacy Policy',
      subtitle:
          'How IPTkiganjani handles student, institution, and organization data.',
      sections: [
        (
          'Information we collect',
          'We collect account details, profile information, practical training '
              'applications, test activity, notifications, and support messages '
              'needed to operate the IPTkiganjani platform.',
        ),
        (
          'How information is used',
          'Your information is used to match students with training '
              'opportunities, support institutional coordination, communicate '
              'application updates, and improve platform reliability.',
        ),
        (
          'Data protection',
          'Access to information is limited by user role. Students, '
              'universities, organizations, and administrators only see the '
              'records required for their approved platform workflows.',
        ),
        (
          'Your choices',
          'You may update your profile information from your account and contact '
              'support when you need help with access, corrections, or account '
              'questions.',
        ),
      ],
    );
  }

  factory _PublicInfoPage.termsOfService() {
    return const _PublicInfoPage(
      title: 'Terms of Service',
      subtitle:
          'The basic rules for using IPTkiganjani practical training services.',
      sections: [
        (
          'Platform use',
          'Users must provide accurate information, keep account credentials '
              'secure, and use the platform only for legitimate practical '
              'training, recruitment, assessment, and coordination activities.',
        ),
        (
          'Applications and tests',
          'Students are responsible for submitting truthful applications and '
              'completing tests honestly. Organizations and institutions should '
              'review applications and results fairly.',
        ),
        (
          'System availability',
          'IPTkiganjani may update, maintain, or improve services from time to '
              'time. We aim to keep services available and reliable for all '
              'approved users.',
        ),
        (
          'Account responsibility',
          'Users are responsible for actions performed through their accounts. '
              'Suspicious access, wrong information, or misuse should be '
              'reported to support promptly.',
        ),
      ],
    );
  }

  factory _PublicInfoPage.contactSupport() {
    return const _PublicInfoPage(
      title: 'Contact Support',
      subtitle:
          'Reach the IPTkiganjani support team for account, application, or test help.',
      showSupportContacts: true,
      sections: [
        (
          'Before contacting support',
          'Please include your full name, account email, role, and a short '
              'description of the issue so the team can assist you quickly.',
        ),
        (
          'Support coverage',
          'The support team can help with login access, profile updates, '
              'application issues, test invitations, and institution or '
              'organization coordination questions.',
        ),
      ],
    );
  }

  final String title;
  final String subtitle;
  final List<(String, String)> sections;
  final bool showSupportContacts;

  void _openLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void _goHome(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
      (route) => false,
    );
  }

  void _goTraining(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const TrainingPortalScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 760;
            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _PortalHeader(
                    isCompact: isCompact,
                    onHomePressed: () => _goHome(context),
                    onTrainingPressed: () => _goTraining(context),
                    onLoginPressed: () => _openLogin(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _PublicInfoContent(
                    title: title,
                    subtitle: subtitle,
                    sections: sections,
                    showSupportContacts: showSupportContacts,
                    isCompact: isCompact,
                  ),
                ),
                const SliverToBoxAdapter(child: _PortalFooter()),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PublicInfoContent extends StatelessWidget {
  const _PublicInfoContent({
    required this.title,
    required this.subtitle,
    required this.sections,
    required this.showSupportContacts,
    required this.isCompact,
  });

  final String title;
  final String subtitle;
  final List<(String, String)> sections;
  final bool showSupportContacts;
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F9FC),
      padding: EdgeInsets.fromLTRB(
        isCompact ? 20 : 56,
        isCompact ? 42 : 68,
        isCompact ? 20 : 56,
        isCompact ? 48 : 72,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.primaryDark,
                  fontSize: isCompact ? 30 : 42,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: isCompact ? 15 : 17,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              for (final section in sections) ...[
                _PublicInfoSection(title: section.$1, body: section.$2),
                const SizedBox(height: 14),
              ],
              if (showSupportContacts) ...[
                const SizedBox(height: 8),
                const _SupportContactPanel(),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PublicInfoSection extends StatelessWidget {
  const _PublicInfoSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD6E5F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14.5,
              height: 1.55,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportContactPanel extends StatelessWidget {
  const _SupportContactPanel();

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.phone_in_talk_outlined, 'Call Us', _callCenterPhones),
      (
        Icons.mark_email_read_outlined,
        'Email Us',
        'support@iptkiganjani.go.tz\ninfo@iptkiganjani.go.tz',
      ),
      (
        Icons.apartment_rounded,
        'Our Location',
        'Industrial Practical Training\nP.O. BOX 2320, Dodoma',
      ),
      (Icons.schedule_rounded, 'Working Hours', _callCenterWorkingHours),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isCompact ? 1 : 2,
            childAspectRatio: isCompact ? 3.8 : 3.1,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return _SupportContactTile(
              icon: item.$1,
              title: item.$2,
              body: item.$3,
            );
          },
        );
      },
    );
  }
}

class _SupportContactTile extends StatelessWidget {
  const _SupportContactTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF12366D),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF22A7A8)),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.accentGold,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PublicPortalHeader extends StatelessWidget {
  const PublicPortalHeader({
    super.key,
    required this.isCompact,
    required this.onHomePressed,
    required this.onVacanciesPressed,
    required this.onLoginPressed,
    this.isTrainingSelected = false,
  });

  final bool isCompact;
  final VoidCallback onHomePressed;
  final VoidCallback onVacanciesPressed;
  final VoidCallback onLoginPressed;
  final bool isTrainingSelected;

  @override
  Widget build(BuildContext context) {
    return _PortalHeader(
      isCompact: isCompact,
      isTrainingSelected: isTrainingSelected,
      onHomePressed: onHomePressed,
      onTrainingPressed: onVacanciesPressed,
      onLoginPressed: onLoginPressed,
    );
  }
}

class _PortalHeader extends StatelessWidget {
  const _PortalHeader({
    required this.isCompact,
    required this.onHomePressed,
    required this.onTrainingPressed,
    required this.onLoginPressed,
    this.isTrainingSelected = false,
  });

  final bool isCompact;
  final VoidCallback onHomePressed;
  final VoidCallback onTrainingPressed;
  final VoidCallback onLoginPressed;
  final bool isTrainingSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 58,
          vertical: isCompact ? 10 : 14,
        ),
        child: isCompact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: _HeaderBrand(),
                  ),
                  const SizedBox(height: 8),
                  const _HeaderCenterTitle(),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _HeaderActions(
                      isTrainingSelected: isTrainingSelected,
                      onHomePressed: onHomePressed,
                      onTrainingPressed: onTrainingPressed,
                      onLoginPressed: onLoginPressed,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  const _HeaderBrand(),
                  const Expanded(child: _HeaderCenterTitle()),
                  _HeaderActions(
                    isTrainingSelected: isTrainingSelected,
                    onHomePressed: onHomePressed,
                    onTrainingPressed: onTrainingPressed,
                    onLoginPressed: onLoginPressed,
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderCenterTitle extends StatelessWidget {
  const _HeaderCenterTitle();

  static const Color _brandNavy = Color(0xFF1A3471);

  @override
  Widget build(BuildContext context) {
    return const Text(
      'THE UNITED REPUBLIC OF TANZANIA\nPRACTICAL TRAINING SYSTEM',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: _brandNavy,
        fontSize: 15,
        height: 1.25,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _HeaderBrand extends StatelessWidget {
  const _HeaderBrand();

  static const Color _brandNavy = Color(0xFF1A3471);
  static const Color _brandOrange = Color(0xFFE97612);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 46, width: 78, child: _IptKiganjaniLogo()),
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

class _HeaderActions extends StatelessWidget {
  const _HeaderActions({
    required this.isTrainingSelected,
    required this.onHomePressed,
    required this.onTrainingPressed,
    required this.onLoginPressed,
  });

  final bool isTrainingSelected;
  final VoidCallback onHomePressed;
  final VoidCallback onTrainingPressed;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _HeaderNavButton(
          label: 'Home',
          isSelected: !isTrainingSelected,
          onPressed: onHomePressed,
        ),
        _HeaderNavButton(
          label: 'Training',
          isSelected: isTrainingSelected,
          onPressed: onTrainingPressed,
        ),
        const SizedBox(width: 18),
        _HeaderLoginButton(onPressed: onLoginPressed),
      ],
    );
  }
}

class _HeaderNavButton extends StatelessWidget {
  const _HeaderNavButton({
    required this.label,
    required this.onPressed,
    this.isSelected = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isSelected;

  static const Color _brandTeal = Color(0xFF0084A3);
  static const Color _brandNavy = Color(0xFF1A3471);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          if (isSelected)
            Container(
              height: 3,
              width: 54,
              decoration: BoxDecoration(
                color: _brandTeal,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          TextButton(
            onPressed: onPressed,
            style: TextButton.styleFrom(
              foregroundColor: isSelected ? _brandTeal : _brandNavy,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0,
              ),
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}

class _HeaderLoginButton extends StatelessWidget {
  const _HeaderLoginButton({required this.onPressed});

  final VoidCallback onPressed;

  static const Color _brandTeal = Color(0xFF007892);
  static const Color _brandGold = Color(0xFFFFC21A);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: _brandGold,
          backgroundColor: _brandTeal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 0,
          ),
        ),
        child: const Text('Log In'),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.isCompact,
    required this.onBrowsePressed,
    required this.onCreateAccountPressed,
    required this.onLoginPressed,
  });

  final bool isCompact;
  final VoidCallback onBrowsePressed;
  final VoidCallback onCreateAccountPressed;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: isCompact ? 690 : 650),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081A33), Color(0xFF12366D), Color(0xFF007892)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _IptLinePattern())),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: isCompact ? 8 : 72,
              color: const Color(0xFF0B3D6E),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: isCompact ? 8 : 96,
              color: const Color(0xFF07315E),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 20 : 92,
                isCompact ? 34 : 58,
                isCompact ? 20 : 92,
                isCompact ? 36 : 58,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1260),
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 20 : 34),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFC21A).withValues(alpha: 0.42),
                    ),
                  ),
                  child: Flex(
                    direction: isCompact ? Axis.vertical : Axis.horizontal,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Flexible(
                        flex: isCompact ? 0 : 6,
                        child: _HeroBrandImage(isCompact: isCompact),
                      ),
                      SizedBox(
                        width: isCompact ? 0 : 48,
                        height: isCompact ? 28 : 0,
                      ),
                      Flexible(
                        flex: isCompact ? 0 : 5,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: isCompact
                              ? CrossAxisAlignment.center
                              : CrossAxisAlignment.start,
                          children: [
                            _HeroBrandLockup(isCompact: isCompact),
                            const SizedBox(height: 18),
                            RichText(
                              textAlign: isCompact
                                  ? TextAlign.center
                                  : TextAlign.left,
                              text: TextSpan(
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isCompact ? 36 : 56,
                                  fontWeight: FontWeight.w900,
                                  height: 1.05,
                                  letterSpacing: 0,
                                ),
                                children: const [
                                  TextSpan(
                                    text: 'INDUSTRIAL PRACTICAL Training\n',
                                  ),
                                  TextSpan(
                                    text: 'Management System',
                                    style: TextStyle(color: Color(0xFFFFC21A)),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'IPTkiganjani enables students to apply for practical '
                              'training opportunities and helps institutions manage '
                              'placements, tests, and progress in one place.',
                              textAlign: isCompact
                                  ? TextAlign.center
                                  : TextAlign.left,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: isCompact ? 16 : 18,
                                height: 1.48,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Wrap(
                              alignment: isCompact
                                  ? WrapAlignment.center
                                  : WrapAlignment.start,
                              spacing: 14,
                              runSpacing: 12,
                              children: [
                                SizedBox(
                                  height: 52,
                                  width: isCompact ? 168 : 202,
                                  child: ElevatedButton.icon(
                                    onPressed: onBrowsePressed,
                                    icon: const Icon(
                                      Icons.badge_outlined,
                                      size: 20,
                                    ),
                                    label: const Text('Browse Training'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFFFC21A),
                                      foregroundColor: const Color(0xFF0D2E59),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 52,
                                  width: isCompact ? 168 : 202,
                                  child: OutlinedButton.icon(
                                    onPressed: onCreateAccountPressed,
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 21,
                                    ),
                                    label: const Text('Create Account'),
                                    style: OutlinedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFF0D2E59),
                                      side: const BorderSide(
                                        color: Color(0xFFFFC21A),
                                        width: 1.6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                        letterSpacing: 0,
                                      ),
                                    ),
                                  ),
                                ),
                                if (isCompact)
                                  SizedBox(
                                    height: 52,
                                    width: 168,
                                    child: TextButton.icon(
                                      onPressed: onLoginPressed,
                                      icon: const Icon(
                                        Icons.login_rounded,
                                        size: 19,
                                      ),
                                      label: const Text('Log In'),
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: const Color(
                                          0xFF007892,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        textStyle: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 26),
                            const Wrap(
                              spacing: 14,
                              runSpacing: 10,
                              children: [
                                _HeroMetric(
                                  icon: Icons.school_outlined,
                                  label: 'Learn',
                                ),
                                _HeroMetric(
                                  icon: Icons.task_alt_rounded,
                                  label: 'Practice',
                                ),
                                _HeroMetric(
                                  icon: Icons.trending_up_rounded,
                                  label: 'Grow',
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
        ],
      ),
    );
  }
}

class _HeroBrandImage extends StatelessWidget {
  const _HeroBrandImage({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: isCompact ? 420 : 560,
          maxWidth: isCompact ? 280 : 430,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.asset(
            AppAssets.homeReceptionHero,
            fit: BoxFit.contain,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

class _HeroBrandLockup extends StatelessWidget {
  const _HeroBrandLockup({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        final shouldStack = isCompact || availableWidth < 330;
        final logoWidth = shouldStack ? 112.0 : 145.0;
        final logoHeight = shouldStack ? 54.0 : 70.0;
        final title = Text(
          'IPTkiganjani',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: shouldStack ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            color: Colors.white,
            fontSize: shouldStack ? 24 : 26,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        );

        final logo = SizedBox(
          height: logoHeight,
          width: logoWidth,
          child: const _IptKiganjaniLogo(),
        );

        if (shouldStack) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: logo),
              const SizedBox(height: 8),
              title,
            ],
          );
        }

        return Row(
          mainAxisSize: MainAxisSize.max,
          children: [
            logo,
            const SizedBox(width: 12),
            Expanded(child: title),
          ],
        );
      },
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 32,
          width: 32,
          decoration: BoxDecoration(
            color: const Color(0xFFFFC21A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF0D2E59), size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}

class _ApplicationTips extends StatelessWidget {
  const _ApplicationTips({required this.isCompact});

  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final tips = const [
      'Complete your Profile',
      'Apply for training online',
      'Attach required documents',
      'Track your application status',
    ];

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF081A33), Color(0xFF12366D), Color(0xFF007892)],
          stops: [0, 0.62, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: CustomPaint(painter: _IptLinePattern())),
          Padding(
            padding: EdgeInsets.fromLTRB(
              isCompact ? 20 : 58,
              isCompact ? 46 : 70,
              isCompact ? 20 : 58,
              isCompact ? 52 : 76,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: Container(
                  padding: EdgeInsets.all(isCompact ? 20 : 36),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFFFFC21A).withValues(alpha: 0.42),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Apply with confidence',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 21,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'APPLICATION TIPS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFC21A),
                          fontSize: isCompact ? 31 : 48,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Four simple steps to keep your practical training application ready and easy to track.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 30),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: tips.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isCompact ? 1 : 2,
                          childAspectRatio: isCompact ? 4.8 : 5.8,
                          mainAxisSpacing: 14,
                          crossAxisSpacing: 16,
                        ),
                        itemBuilder: (context, index) {
                          return _NumberedStrip(
                            number: index + 1,
                            label: tips[index],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingListSection extends StatefulWidget {
  const _TrainingListSection({
    required this.isCompact,
    required this.onLoginPressed,
  });

  final bool isCompact;
  final VoidCallback onLoginPressed;

  @override
  State<_TrainingListSection> createState() => _TrainingListSectionState();
}

class _TrainingListSectionState extends State<_TrainingListSection> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<Job> _training = const [];
  bool _isLoading = true;
  String? _errorMessage;
  int _entriesLimit = 10;

  @override
  void initState() {
    super.initState();
    _loadTraining();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTraining() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.gettraining(
        view: 'open',
        limit: '100',
        forceRefresh: false,
        requiresAuth: false,
      );
      final data = response['data'];
      if (response['success'] != true || data is! List) {
        throw Exception(
          ApiService.responseMessage(
            response,
            fallback: 'Unable to load posted training.',
          ),
        );
      }

      final now = DateTime.now();
      final parsed = data
          .whereType<Map<String, dynamic>>()
          .map(Job.fromJson)
          .where(
            (job) =>
                job.status.toLowerCase() == 'open' &&
                job.applicationDeadline.isAfter(now) &&
                job.requiredApplicants > 0,
          )
          .toList(growable: false);

      if (!mounted) return;
      setState(() {
        _training = parsed;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _training = const [];
        _isLoading = false;
        _errorMessage = ApiService.normalizeErrorMessage(
          error,
          fallback: 'Unable to load posted training.',
        );
      });
    }
  }

  String _normalize(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  }

  List<Job> get _filteredTraining {
    final query = _normalize(_searchController.text);
    var items = _training;

    if (query.isNotEmpty) {
      items = items.where((job) {
        final searchable = _normalize(
          '${job.title} ${job.companyName} ${job.location} ${job.type}',
        );
        return searchable.contains(query);
      }).toList();
    }

    return items;
  }

  String _formatCloseDate(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  Widget _buildToolbar(List<Job> visibleTraining) {
    final entriesControl = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Show:',
          style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
        ),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _entriesLimit,
          items: const [
            DropdownMenuItem(value: 10, child: Text('10')),
            DropdownMenuItem(value: 25, child: Text('25')),
            DropdownMenuItem(value: 50, child: Text('50')),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _entriesLimit = value);
          },
        ),
        const SizedBox(width: 8),
        const Text(
          'entries',
          style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
        ),
      ],
    );

    final searchControl = SizedBox(
      width: widget.isCompact ? double.infinity : 330,
      child: Row(
        children: [
          const Text(
            'Search:',
            style: TextStyle(fontSize: 13, color: AppTheme.primaryDark),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 38,
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search training...',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        ),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 18, 0, 18),
      child: widget.isCompact
          ? searchControl
          : Row(children: [entriesControl, const Spacer(), searchControl]),
    );
  }

  Widget _buildTrainingCards(List<Job> visibleTraining) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 14,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.work_outline_rounded,
                    color: Color(0xFF2563EB),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Browse training',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${visibleTraining.length} opportunities found',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final job in visibleTraining)
          JobCard(
            job: job,
            onViewDetails: widget.onLoginPressed,
            onApplyNow: widget.onLoginPressed,
          ),
      ],
    );
  }

  Widget _buildTrainingTable(List<Job> visibleTraining) {
    final limitedTraining = visibleTraining.take(_entriesLimit).toList();

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 42),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 38),
        child: Column(
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _loadTraining,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (visibleTraining.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 42),
        child: const Text(
          'No posted training available right now.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
      );
    }

    if (widget.isCompact) {
      return _buildTrainingCards(visibleTraining);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: widget.isCompact ? 900 : 1760,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              border: TableBorder.all(color: const Color(0xFFD4DEE8)),
              columnSpacing: widget.isCompact ? 24 : 56,
              columns: const [
                DataColumn(label: Text('S/N')),
                DataColumn(label: Text('ADVERT NAME')),
                DataColumn(label: Text('COMPANY NAME')),
                DataColumn(label: Text('CLOSE DATE')),
                DataColumn(label: Text('ACTION')),
              ],
              rows: [
                for (var index = 0; index < limitedTraining.length; index++)
                  DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(
                        SizedBox(
                          width: widget.isCompact ? 260 : 470,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                limitedTraining[index].title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Number of Posts: ${limitedTraining[index].requiredApplicants}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: widget.isCompact ? 220 : 320,
                          child: Text(
                            limitedTraining[index].companyName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          _formatCloseDate(
                            limitedTraining[index].applicationDeadline,
                          ),
                        ),
                      ),
                      DataCell(
                        ElevatedButton(
                          onPressed: widget.onLoginPressed,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF155A99),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(2),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                          ),
                          child: const Text(
                            'Login to Apply',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: Color(0xFFD4DEE8)),
              right: BorderSide(color: Color(0xFFD4DEE8)),
              bottom: BorderSide(color: Color(0xFFD4DEE8)),
            ),
          ),
          child: Text(
            'Showing 1 to ${limitedTraining.length} of ${visibleTraining.length} entries',
            style: const TextStyle(fontSize: 13, color: AppTheme.primaryDark),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTraining = _filteredTraining;

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(18, 28, 18, 48),
            color: Colors.white,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: Text(
                        'All Posted Training',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(color: AppTheme.borderGrey.withValues(alpha: 0.9)),
                    _buildToolbar(visibleTraining),
                    _buildTrainingTable(visibleTraining),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VacancyCategories extends StatefulWidget {
  const _VacancyCategories({
    required this.isCompact,
    required this.onCategorySelected,
  });

  final bool isCompact;
  final VoidCallback onCategorySelected;

  @override
  State<_VacancyCategories> createState() => _VacancyCategoriesState();
}

class _VacancyCategoriesState extends State<_VacancyCategories> {
  final Set<int> _expandedCategories = <int>{};
  int? _hoveredCategory;

  void _toggleCategory(int index) {
    setState(() {
      if (_expandedCategories.contains(index)) {
        _expandedCategories.remove(index);
      } else {
        _expandedCategories.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF7FBFF), Color(0xFFEAF7FF)],
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        widget.isCompact ? 20 : 58,
        widget.isCompact ? 42 : 62,
        widget.isCompact ? 20 : 58,
        widget.isCompact ? 48 : 68,
      ),
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Container(
              clipBehavior: Clip.antiAlias,
              padding: EdgeInsets.all(widget.isCompact ? 20 : 34),
              decoration: BoxDecoration(
                color: const Color(0xFF0D2E59),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF22A7A8)),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryDark.withValues(alpha: 0.18),
                    blurRadius: 28,
                    offset: const Offset(0, 16),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  const Positioned.fill(
                    child: CustomPaint(painter: _IptLinePattern(subtle: true)),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Text(
                        'Explore every pathway',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'TRAINING CATEGORIES',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFFFFC21A),
                          fontSize: widget.isCompact ? 30 : 46,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Choose the practical training type that matches your programme, then view posted opportunities.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          height: 1.45,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 30),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = widget.isCompact ? 1 : 2;
                          final spacing = widget.isCompact ? 10.0 : 14.0;
                          final cardWidth =
                              (constraints.maxWidth -
                                  (spacing * (columns - 1))) /
                              columns;

                          return Wrap(
                            spacing: spacing,
                            runSpacing: spacing,
                            children: [
                              for (
                                var index = 0;
                                index < _trainingCategories.length;
                                index++
                              )
                                SizedBox(
                                  width: cardWidth,
                                  child: MouseRegion(
                                    onEnter: (_) {
                                      if (_hoveredCategory == index) return;
                                      setState(() => _hoveredCategory = index);
                                    },
                                    onExit: (_) {
                                      if (_hoveredCategory == null) return;
                                      setState(() => _hoveredCategory = null);
                                    },
                                    child: _TrainingCategoryCard(
                                      category: _trainingCategories[index],
                                      isExpanded: _expandedCategories.contains(
                                        index,
                                      ),
                                      isHovered: _hoveredCategory == index,
                                      onToggle: () => _toggleCategory(index),
                                      onViewTraining: widget.onCategorySelected,
                                    ),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqSection extends StatelessWidget {
  const _FaqSection({required this.expandedIndex, required this.onChanged});

  final int expandedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final faqs = const [
      (
        'How Can I Register',
        'Registration is done by creating an account with your email, phone '
            'number and password. Complete your profile after activation, then '
            'log in to apply for opportunities.',
      ),
      (
        'How Can I Change my Password',
        'Log in to your account and open your profile or settings page, then '
            'choose the password option and submit the updated credentials.',
      ),
      (
        'How Do I Reset my Password',
        'Open the login page, choose forgot password, enter your email address '
            'and follow the reset instructions sent to your inbox.',
      ),
      (
        'How Do I Apply For Jobs',
        'Log in, complete your profile, browse available training, open the '
            'opportunity details and submit your application online.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;
        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFEAF7FF), Color(0xFFF7FBFF)],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            isCompact ? 20 : 58,
            isCompact ? 44 : 66,
            isCompact ? 20 : 58,
            isCompact ? 50 : 70,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1180),
              child: Container(
                clipBehavior: Clip.antiAlias,
                padding: EdgeInsets.all(isCompact ? 20 : 34),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D2E59),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF22A7A8)),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryDark.withValues(alpha: 0.16),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Positioned.fill(
                      child: CustomPaint(
                        painter: _IptLinePattern(subtle: true),
                      ),
                    ),
                    Column(
                      children: [
                        const Text(
                          'Need help?',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'FREQUENTLY ASKED QUESTIONS',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFFFFC21A),
                            fontSize: isCompact ? 28 : 42,
                            fontWeight: FontWeight.w900,
                            height: 1.05,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Quick answers for account access, applications, and practical training workflows.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < faqs.length; i++)
                                _FaqTile(
                                  title: faqs[i].$1,
                                  body: faqs[i].$2,
                                  isExpanded: expandedIndex == i,
                                  onTap: () => onChanged(i),
                                  darkMode: true,
                                ),
                            ],
                          ),
                        ),
                      ],
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
}

class _PortalFooter extends StatelessWidget {
  const _PortalFooter({this.showDownloadBadges = true});

  final bool showDownloadBadges;

  static const Color _footerBase = Color(0xFF12366D);
  static const Color _footerDeep = Color(0xFF0B2854);
  static const Color _footerLine = Color(0xFF22A7A8);
  static const Color _footerGold = Color(0xFFF58A14);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 760;

        return Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: _footerBase,
            border: Border(top: BorderSide(color: _footerLine, width: 1)),
          ),
          child: Column(
            children: [
              _FooterBand(
                backgroundColor: _footerDeep,
                child: Wrap(
                  alignment: isCompact
                      ? WrapAlignment.center
                      : WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 28,
                  runSpacing: 18,
                  children: [
                    const _FooterBrand(),
                    const _FooterSocialLinks(),
                    if (showDownloadBadges) const _PortalDownloadBadges(),
                  ],
                ),
              ),
              const _FooterBand(
                child: _FooterLogoGrid(
                  title: 'IPTKIGANJANI PARTNERS',
                  items: [
                    ('TCU', Icons.account_balance_rounded),
                    ('HESLB', Icons.payments_outlined),
                  ],
                ),
              ),
              const _FooterDivider(),
              const _FooterBand(
                compactVerticalPadding: 22,
                child: _FooterLogoGrid(
                  title: 'USEFUL STUDY LINKS',
                  compact: true,
                  items: [
                    ('TCU Programmes', Icons.menu_book_outlined),
                    ('NACTVET Courses', Icons.badge_outlined),
                    ('Student Loans', Icons.account_balance_wallet_outlined),
                    ('Ajira Portal', Icons.work_outline_rounded),
                  ],
                ),
              ),
              const _FooterDivider(),
              _FooterBand(
                backgroundColor: _footerDeep,
                child: Wrap(
                  alignment: isCompact
                      ? WrapAlignment.center
                      : WrapAlignment.spaceBetween,
                  runAlignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 24,
                  runSpacing: 14,
                  children: const [
                    _FooterLegalLinks(),
                    Text(
                      'Copyright © 2025-2026 IPTkiganjani. All rights reserved.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FooterDivider extends StatelessWidget {
  const _FooterDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      width: double.infinity,
      color: _PortalFooter._footerLine,
    );
  }
}

class _FooterBand extends StatelessWidget {
  const _FooterBand({
    required this.child,
    this.backgroundColor,
    this.compactVerticalPadding = 18,
  });

  final Widget child;
  final Color? backgroundColor;
  final double compactVerticalPadding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      padding: EdgeInsets.symmetric(
        horizontal: 28,
        vertical: compactVerticalPadding,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: child,
        ),
      ),
    );
  }
}

class _FooterBrand extends StatelessWidget {
  const _FooterBrand();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      width: 190,
      child: const _IptKiganjaniLogo(alignment: Alignment.centerLeft),
    );
  }
}

class _IptKiganjaniLogo extends StatelessWidget {
  const _IptKiganjaniLogo({this.alignment = Alignment.center});

  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.homeLogo,
      fit: BoxFit.contain,
      alignment: alignment,
      gaplessPlayback: true,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          AppAssets.splashLogo,
          fit: BoxFit.contain,
          alignment: alignment,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        );
      },
    );
  }
}

class _FooterSocialLinks extends StatelessWidget {
  const _FooterSocialLinks();

  @override
  Widget build(BuildContext context) {
    return const Wrap(
      spacing: 14,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _FooterSocialIcon(icon: Icons.alternate_email_rounded, label: 'X'),
        _FooterSocialIcon(icon: Icons.facebook_rounded, label: 'Facebook'),
        _FooterSocialIcon(icon: Icons.camera_alt_outlined, label: 'Instagram'),
        _FooterSocialIcon(icon: Icons.play_arrow_rounded, label: 'YouTube'),
        _FooterSocialIcon(icon: Icons.music_note_rounded, label: 'TikTok'),
      ],
    );
  }
}

class _FooterSocialIcon extends StatelessWidget {
  const _FooterSocialIcon({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Icon(icon, color: Colors.white, size: 19),
      ),
    );
  }
}

class _FooterLogoGrid extends StatelessWidget {
  const _FooterLogoGrid({
    required this.title,
    required this.items,
    this.compact = false,
  });

  final String title;
  final List<(String, IconData)> items;
  final bool compact;

  static const Map<String, String> _studyLinks = {
    'TCU': 'https://www.tcu.go.tz',
    'TCU Programmes': 'https://www.tcu.go.tz',
    'NACTVET': 'https://www.nactvet.go.tz',
    'NACTVET Courses': 'https://www.nactvet.go.tz',
    'HESLB': 'https://www.heslb.go.tz',
    'Student Loans': 'https://www.heslb.go.tz',
    'Ajira Portal': 'https://portal.ajira.go.tz',
  };

  Future<void> _openLink(String label) async {
    final url = _studyLinks[label];
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: compact ? _PortalFooter._footerGold : Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          alignment: WrapAlignment.spaceEvenly,
          runAlignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: compact ? 36 : 58,
          runSpacing: compact ? 18 : 28,
          children: [
            for (final item in items)
              _FooterPartnerMark(
                label: item.$1,
                icon: item.$2,
                compact: compact,
                onTap: _studyLinks.containsKey(item.$1)
                    ? () => _openLink(item.$1)
                    : null,
              ),
          ],
        ),
      ],
    );
  }
}

class _FooterPartnerMark extends StatelessWidget {
  const _FooterPartnerMark({
    required this.label,
    required this.icon,
    required this.compact,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool compact;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textSize = compact
        ? 13.0
        : label.length > 8
        ? 21.0
        : 27.0;

    return SizedBox(
      width: compact ? 142 : 178,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: compact ? 18 : 24),
              const SizedBox(height: 5),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: textSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1,
                ),
              ),
              if (compact) ...[
                const SizedBox(height: 4),
                Container(
                  width: 30,
                  height: 2,
                  color: _PortalFooter._footerGold,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLegalLinks extends StatelessWidget {
  const _FooterLegalLinks();

  static const List<String> _links = [
    'PRIVACY POLICY',
    'TERMS OF SERVICE',
    'CONTACT SUPPORT',
  ];

  void _openLink(BuildContext context, String label) {
    final Widget page = switch (label) {
      'PRIVACY POLICY' => _PublicInfoPage.privacyPolicy(),
      'TERMS OF SERVICE' => _PublicInfoPage.termsOfService(),
      'CONTACT SUPPORT' => _PublicInfoPage.contactSupport(),
      _ => _PublicInfoPage.privacyPolicy(),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 24,
      runSpacing: 10,
      alignment: WrapAlignment.center,
      children: [
        for (final label in _links)
          _FooterLink(label: label, onTap: () => _openLink(context, label)),
      ],
    );
  }
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

class _PortalDownloadBadges extends StatelessWidget {
  const _PortalDownloadBadges();

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: const [
          Text(
            'Download the IPTkiganjani app today',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          _PortalStoreBadge(
            icon: Icons.play_arrow_rounded,
            label: 'Google Play',
          ),
          _PortalStoreBadge(icon: Icons.apple, label: 'App Store'),
        ],
      ),
    );
  }
}

class _PortalStoreBadge extends StatelessWidget {
  const _PortalStoreBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _IptLinePattern extends CustomPainter {
  const _IptLinePattern({this.subtle = false});

  final bool subtle;

  @override
  void paint(Canvas canvas, Size size) {
    final goldPaint = Paint()
      ..color = const Color(0xFFFFC21A).withValues(alpha: subtle ? 0.18 : 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final whitePaint = Paint()
      ..color = Colors.white.withValues(alpha: subtle ? 0.12 : 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final tealPaint = Paint()
      ..color = const Color(0xFF22A7A8).withValues(alpha: subtle ? 0.14 : 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    canvas.drawLine(
      Offset(0, size.height * 0.82),
      Offset(size.width, size.height * 0.82),
      goldPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(
        -size.width * 0.28,
        size.height * 0.08,
        size.width * 0.64,
        size.height * 1.18,
      ),
      -1.1,
      2.35,
      false,
      whitePaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.34,
        -size.height * 0.46,
        size.width * 0.62,
        size.height * 1.1,
      ),
      1.15,
      2.2,
      false,
      goldPaint,
    );

    canvas.drawArc(
      Rect.fromLTWH(
        size.width * 0.78,
        size.height * 0.2,
        size.width * 0.46,
        size.height * 0.82,
      ),
      3.25,
      2.25,
      false,
      tealPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.72, size.height * 0.28),
      Offset(size.width, size.height * 0.28),
      tealPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _IptLinePattern oldDelegate) {
    return oldDelegate.subtle != subtle;
  }
}

class _NumberedStrip extends StatelessWidget {
  const _NumberedStrip({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFFFC21A),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Color(0xFF0D2E59),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingCategoryCard extends StatelessWidget {
  const _TrainingCategoryCard({
    required this.category,
    required this.isExpanded,
    required this.isHovered,
    required this.onToggle,
    required this.onViewTraining,
  });

  final _TrainingCategory category;
  final bool isExpanded;
  final bool isHovered;
  final VoidCallback onToggle;
  final VoidCallback onViewTraining;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isExpanded
            ? Colors.white
            : Colors.white.withValues(alpha: isHovered ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isExpanded
              ? const Color(0xFFFFC21A)
              : isHovered
              ? const Color(0xFF22A7A8)
              : Colors.white.withValues(alpha: 0.16),
        ),
        boxShadow: [
          if (isHovered)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        category.title,
                        style: TextStyle(
                          color: isExpanded
                              ? AppTheme.primaryDark
                              : Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                          height: 1.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isExpanded ? 0.25 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: isExpanded
                            ? const Color(0xFF007892)
                            : const Color(0xFFFFC21A),
                        size: 16,
                      ),
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox(width: double.infinity),
                  secondChild: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TrainingCategoryDetail(
                          label: 'Description',
                          value: category.description,
                        ),
                        const SizedBox(height: 10),
                        _TrainingCategoryDetail(
                          label: 'Students Involved',
                          value: category.students,
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: onViewTraining,
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                            ),
                            label: const Text('View posted training'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF155A99),
                              padding: EdgeInsets.zero,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  crossFadeState: isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 180),
                  sizeCurve: Curves.easeOut,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TrainingCategoryDetail extends StatelessWidget {
  const _TrainingCategoryDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          height: 1.4,
          letterSpacing: 0,
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              color: AppTheme.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.title,
    required this.body,
    required this.isExpanded,
    required this.onTap,
    this.darkMode = false,
  });

  final String title;
  final String body;
  final bool isExpanded;
  final VoidCallback onTap;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    final expandedColor = darkMode
        ? Colors.white.withValues(alpha: 0.12)
        : const Color(0xFFEAF0FF);
    final titleColor = darkMode
        ? Colors.white
        : isExpanded
        ? const Color(0xFF155A99)
        : Colors.black;
    final iconColor = darkMode
        ? const Color(0xFFFFC21A)
        : isExpanded
        ? const Color(0xFF155A99)
        : Colors.black;
    final bodyColor = darkMode
        ? Colors.white.withValues(alpha: 0.82)
        : AppTheme.textSecondary;
    final dividerColor = darkMode
        ? Colors.white.withValues(alpha: 0.12)
        : AppTheme.borderGrey.withValues(alpha: 0.9);

    return Column(
      children: [
        Material(
          color: isExpanded ? expandedColor : Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.remove_circle_outline
                        : Icons.add_circle_outline,
                    size: 18,
                    color: iconColor,
                  ),
                ],
              ),
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(10, 2, 10, 14),
            child: Text(
              body,
              style: TextStyle(
                color: bodyColor,
                fontSize: 14,
                height: 1.45,
                letterSpacing: 0,
              ),
            ),
          ),
          crossFadeState: isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 180),
        ),
        Divider(color: dividerColor, height: 1),
      ],
    );
  }
}
