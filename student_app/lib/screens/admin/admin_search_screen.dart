import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import 'admin_application_filter.dart';
import 'admin_user_filter.dart';

class AdminSearchScreen extends StatefulWidget {
  final void Function(
    int index, {
    AdminUserFilter? userFilter,
    AdminApplicationFilter? applicationFilter,
  })?
  onNavigateToTab;

  const AdminSearchScreen({super.key, this.onNavigateToTab});

  @override
  State<AdminSearchScreen> createState() => _AdminSearchScreenState();
}

class _AdminSearchScreenState extends State<AdminSearchScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  List<dynamic> _users = [];
  List<dynamic> _training = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSearchData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSearchData() async {
    setState(() => _isLoading = true);

    try {
      final responses = await Future.wait([
        _apiService.getUsers(),
        _apiService.gettraining(),
      ]);

      if (!mounted) return;

      final usersResponse = responses[0];
      final trainingResponse = responses[1];

      setState(() {
        _users =
            usersResponse['success'] == true && usersResponse['data'] is List
            ? List<dynamic>.from(usersResponse['data'])
            : [];
        _training =
            trainingResponse['success'] == true &&
                trainingResponse['data'] is List
            ? List<dynamic>.from(trainingResponse['data'])
            : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _matchesCompany(dynamic user) {
    if ('${user['role'] ?? ''}' != 'company') {
      return false;
    }

    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableParts = [
      '${user['full_name'] ?? ''}',
      '${user['company_name'] ?? ''}',
      '${user['email'] ?? ''}',
      '${user['industry'] ?? ''}',
      '${user['location'] ?? ''}',
      '${user['phone'] ?? ''}',
    ];

    return searchableParts.any((value) => value.toLowerCase().contains(query));
  }

  bool _matchesJob(dynamic job) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableParts = [
      '${job['title'] ?? ''}',
      '${job['company_name'] ?? ''}',
      '${job['location'] ?? ''}',
      '${job['description'] ?? ''}',
      '${job['category'] ?? ''}',
      '${job['employment_type'] ?? ''}',
      '${job['job_type'] ?? ''}',
    ];

    return searchableParts.any((value) => value.toLowerCase().contains(query));
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String count,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 12),
              Text(
                count,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompanyCard(dynamic company, LanguageProvider language) {
    final companyName =
        '${company['company_name'] ?? company['full_name'] ?? ''}'.trim();
    final email = '${company['email'] ?? ''}'.trim();
    final industry = '${company['industry'] ?? ''}'.trim();
    final location = '${company['location'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(
                    0xFF2563EB,
                  ).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFF2563EB),
                  child: const Icon(Icons.apartment_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        companyName.isEmpty
                            ? language.tr('company')
                            : companyName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(language.tr('email_label', {'value': email})),
                      ],
                      if (industry.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          language.tr('industry_label', {'value': industry}),
                        ),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          language.tr('location_label', {'value': location}),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => widget.onNavigateToTab?.call(
                  1,
                  userFilter: AdminUserFilter.companies,
                ),
                icon: const Icon(Icons.people_outline_rounded, size: 18),
                label: Text(language.tr('open_users_tab')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildJobCard(dynamic job, LanguageProvider language) {
    final title = '${job['title'] ?? ''}'.trim();
    final companyName = '${job['company_name'] ?? ''}'.trim();
    final location = '${job['location'] ?? ''}'.trim();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: const Color(
                    0xFFF59E0B,
                  ).withValues(alpha: 0.12),
                  foregroundColor: const Color(0xFFF59E0B),
                  child: const Icon(Icons.work_outline_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? language.tr('training') : title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (companyName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          language.tr('company_label', {'value': companyName}),
                        ),
                      ],
                      if (location.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          language.tr('location_label', {'value': location}),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () => widget.onNavigateToTab?.call(2),
                icon: const Icon(Icons.work_history_rounded, size: 18),
                label: Text(language.tr('open_training_tab')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final language = context.watch<LanguageProvider>();
    final companies = _users.where(_matchesCompany).toList();
    final training = _training.where(_matchesJob).toList();
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final totalResults = companies.length + training.length;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(language.tr('search')),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadSearchData,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: language.tr('search_companies_training_hint'),
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadSearchData,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                children: [
                  Text(
                    language.tr('search_admin_subtitle'),
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildSummaryCard(
                        icon: Icons.apartment_rounded,
                        title: language.tr('search_companies'),
                        count: companies.length.toString(),
                        onTap: () => widget.onNavigateToTab?.call(
                          1,
                          userFilter: AdminUserFilter.companies,
                        ),
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        icon: Icons.work_history_rounded,
                        title: language.tr('search_training'),
                        count: training.length.toString(),
                        onTap: () => widget.onNavigateToTab?.call(2),
                        color: const Color(0xFFF59E0B),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  if (!hasQuery)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.manage_search_rounded,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(language.tr('start_search_message')),
                          ),
                        ],
                      ),
                    )
                  else if (totalResults == 0)
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(language.tr('no_search_results')),
                    )
                  else ...[
                    Text(
                      language.tr('search_results_count', {
                        'count': totalResults.toString(),
                      }),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (companies.isNotEmpty) ...[
                      Text(
                        language.tr('search_companies'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...companies.map((company) {
                        return _buildCompanyCard(company, language);
                      }),
                    ],
                    if (training.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        language.tr('search_training'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...training.map((job) {
                        return _buildJobCard(job, language);
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
