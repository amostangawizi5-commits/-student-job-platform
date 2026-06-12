import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

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
                  if (!isCompact) const _ContactSection(),
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
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    children: [
                      const Spacer(),
                      if (!isCompact) const _PortalFooter(),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
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
        SizedBox(
          height: 46,
          width: 46,
          child: Image.asset(AppAssets.splashLogo, fit: BoxFit.contain),
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
      constraints: BoxConstraints(minHeight: isCompact ? 520 : 610),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [Color(0xFFE7F2FC), Colors.white, Color(0xFFF2FFF7)],
          stops: [0, 0.55, 1],
        ),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -80,
            bottom: 22,
            child: _SoftCircle(size: 230, color: Color(0xFFFFF7D7)),
          ),
          const Positioned(
            right: 82,
            top: 92,
            child: _SoftCircle(size: 260, color: Color(0xFFD6F8DB)),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                isCompact ? 20 : 28,
                isCompact ? 72 : 118,
                isCompact ? 20 : 28,
                72,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _LogoColorBars(),
                    const SizedBox(height: 24),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          color: AppTheme.primaryDark,
                          fontSize: isCompact ? 38 : 58,
                          fontWeight: FontWeight.w700,
                          height: 1.08,
                          letterSpacing: 0,
                        ),
                        children: const [
                          TextSpan(text: 'Welcome to '),
                          TextSpan(
                            text: 'IPTkiganjani',
                            style: TextStyle(color: Color(0xFF155A99)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'IPTkiganjani is an online platform designed to enable '
                      'students ~ to apply for available '
                      'practical training opportunities.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: isCompact ? 16 : 19,
                        height: 1.48,
                        letterSpacing: 0,
                      ),
                    ),
                    const SizedBox(height: 42),
                    if (isCompact)
                      Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: ElevatedButton.icon(
                                    onPressed: onBrowsePressed,
                                    icon: const Icon(
                                      Icons.badge_outlined,
                                      size: 18,
                                    ),
                                    label: const Text('Browse Training'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF155A99),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 48,
                                  child: OutlinedButton.icon(
                                    onPressed: onCreateAccountPressed,
                                    icon: const Icon(
                                      Icons.edit_note_rounded,
                                      size: 18,
                                    ),
                                    label: const Text('Create Account'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF155A99),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      side: const BorderSide(
                                        color: Color(0xFF155A99),
                                        width: 1.6,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      textStyle: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: TextButton.icon(
                              onPressed: onLoginPressed,
                              icon: const Icon(Icons.login_rounded, size: 18),
                              label: const Text('Log In'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF007892),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
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
                      )
                    else
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 22,
                        runSpacing: 14,
                        children: [
                          ElevatedButton.icon(
                            onPressed: onBrowsePressed,
                            icon: const Icon(Icons.badge_outlined, size: 20),
                            label: const Text('Browse Training'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF155A99),
                              fixedSize: const Size(224, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: onCreateAccountPressed,
                            icon: const Icon(Icons.edit_note_rounded, size: 22),
                            label: const Text('Create Account'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF155A99),
                              side: const BorderSide(
                                color: Color(0xFF155A99),
                                width: 1.6,
                              ),
                              fixedSize: const Size(224, 54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
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
        ],
      ),
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
      padding: const EdgeInsets.fromLTRB(18, 30, 18, 34),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.borderGrey.withValues(alpha: 0.8)),
        ),
      ),
      child: Column(
        children: [
          const _SectionTitle(title: 'APPLICATION TIPS'),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tips.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isCompact ? 1 : 2,
                childAspectRatio: isCompact ? 6.6 : 8.8,
                mainAxisSpacing: 12,
                crossAxisSpacing: 16,
              ),
              itemBuilder: (context, index) {
                return _NumberedStrip(number: index + 1, label: tips[index]);
              },
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
      color: const Color(0xFFF7FBFF),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 34),
      child: Column(
        children: [
          const _SectionTitle(title: 'TRAINING CATEGORIES'),
          const SizedBox(height: 18),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F2FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFD1E4F7)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = widget.isCompact ? 1 : 2;
                      final spacing = widget.isCompact ? 10.0 : 14.0;
                      final cardWidth =
                          (constraints.maxWidth - (spacing * (columns - 1))) /
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 28, 18, 48),
      color: Colors.white,
      child: Column(
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: 0,
              ),
              children: [
                TextSpan(text: 'Frequently asked '),
                TextSpan(
                  text: 'questions',
                  style: TextStyle(color: Color(0xFF155A99)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1360),
            child: Container(
              color: const Color(0xFFEAF7FF),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  for (var i = 0; i < faqs.length; i++)
                    _FaqTile(
                      title: faqs[i].$1,
                      body: faqs[i].$2,
                      isExpanded: expandedIndex == i,
                      onTap: () => onChanged(i),
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

class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    final contacts = const [
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

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 56),
      child: Column(
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LogoColorBars(height: 32),
              SizedBox(width: 12),
              Text(
                'Contact Us',
                style: TextStyle(
                  color: AppTheme.primaryDark,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 28),
              decoration: BoxDecoration(
                color: const Color(0xFF155A99),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.shadow.withValues(alpha: 0.16),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 760;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: contacts.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: isCompact ? 1 : 4,
                      childAspectRatio: isCompact ? 4.1 : 1.45,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 22,
                    ),
                    itemBuilder: (context, index) {
                      final item = contacts[index];
                      return _ContactItem(
                        icon: item.$1,
                        title: item.$2,
                        body: item.$3,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalFooter extends StatelessWidget {
  const _PortalFooter({this.showDownloadBadges = true});

  final bool showDownloadBadges;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF155A99),
        border: Border(top: BorderSide(color: Color(0xFF10B981), width: 3)),
      ),
      padding: showDownloadBadges
          ? const EdgeInsets.symmetric(horizontal: 28, vertical: 12)
          : const EdgeInsets.fromLTRB(28, 22, 28, 18),
      child: showDownloadBadges
          ? const Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 10,
              children: [
                Text(
                  'Copyright © 2025-2026 IPTkiganjani | All Rights Reserved (version 1.0)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                _PortalDownloadBadges(),
              ],
            )
          : const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Copyright © 2026 IPTkiganjani',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    letterSpacing: 0,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'v 1.0',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
    );
  }
}

class _PortalDownloadBadges extends StatelessWidget {
  const _PortalDownloadBadges();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: const [
        Text(
          'Download IPtkiganjani app',
          style: TextStyle(color: Colors.white, fontSize: 12, letterSpacing: 0),
        ),
        _PortalStoreBadge(icon: Icons.apple, label: 'App Store'),
        _PortalStoreBadge(icon: Icons.play_arrow_rounded, label: 'Google Play'),
      ],
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppTheme.primaryDark,
        fontSize: 23,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _NumberedStrip extends StatelessWidget {
  const _NumberedStrip({required this.number, required this.label});

  final int number;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE6F2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            height: 26,
            width: 26,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFF155A99),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.primaryDark,
                fontSize: 15,
                fontWeight: FontWeight.w600,
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
        color: isHovered ? const Color(0xFFF8FCFF) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHovered ? const Color(0xFF155A99) : const Color(0xFFD1E4F7),
        ),
        boxShadow: [
          if (isHovered)
            BoxShadow(
              color: AppTheme.shadow.withValues(alpha: 0.14),
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
                        style: const TextStyle(
                          color: AppTheme.primaryDark,
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
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: Color(0xFF155A99),
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
  });

  final String title;
  final String body;
  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: isExpanded ? const Color(0xFFEAF0FF) : Colors.transparent,
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
                        color: isExpanded
                            ? const Color(0xFF155A99)
                            : Colors.black,
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
                    color: isExpanded ? const Color(0xFF155A99) : Colors.black,
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
              style: const TextStyle(
                color: AppTheme.textSecondary,
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
        Divider(color: AppTheme.borderGrey.withValues(alpha: 0.9), height: 1),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 210,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.accentGold,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
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
      ),
    );
  }
}

class _LogoColorBars extends StatelessWidget {
  const _LogoColorBars({this.height = 40});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: 28,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          _ColorBar(color: Color(0xFF20B95A)),
          SizedBox(width: 3),
          _ColorBar(color: Color(0xFFF3C21A)),
          SizedBox(width: 3),
          _ColorBar(color: Color(0xFF0099D6)),
          SizedBox(width: 3),
          _ColorBar(color: Color(0xFF1A4F8B)),
        ],
      ),
    );
  }
}

class _ColorBar extends StatelessWidget {
  const _ColorBar({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
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
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    );
  }
}
