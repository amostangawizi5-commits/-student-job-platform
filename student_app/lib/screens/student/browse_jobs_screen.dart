// lib/screens/student/browse_jobs_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/job.dart';
import '../../widgets/job_card.dart';
import 'job_details_screen.dart';

class BrowseJobsScreen extends StatefulWidget {
  const BrowseJobsScreen({super.key});

  @override
  State<BrowseJobsScreen> createState() => _BrowseJobsScreenState();
}

class _BrowseJobsScreenState extends State<BrowseJobsScreen> {
  final ApiService _apiService = ApiService();
  List<Job> _jobs = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedView = 'open';
  String _selectedLocation = 'all';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _locations = [
    'all',
    'Dar es Salaam',
    'Dodoma',
    'Arusha',
    'Mwanza',
  ];
  final List<String> _moreLocations = [
    'Geita',
    'Iringa',
    'Kagera',
    'Katavi',
    'Kigoma',
    'Kilimanjaro',
    'Lindi',
    'Manyara',
    'Mara',
    'Mbeya',
    'Morogoro',
    'Mtwara',
    'Njombe',
    'Pwani',
    'Rukwa',
    'Ruvuma',
    'Shinyanga',
    'Simiyu',
    'Singida',
    'Songwe',
    'Tabora',
    'Tanga',
    'Zanzibar',
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadJobs({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.getJobs(
        view: _selectedView,
        location: _selectedLocation == 'all' ? null : _selectedLocation,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        forceRefresh: forceRefresh,
      );

      if (response['success'] != true) {
        throw Exception(
          ApiService.responseMessage(
            response,
            fallback: 'Unable to load jobs right now.',
          ),
        );
      }

      final jobsData = response['data'];
      if (jobsData is! List) {
        throw const FormatException('Jobs response is invalid.');
      }

      final parsedJobs = <Job>[];
      for (final job in jobsData) {
        if (job is! Map) {
          if (kDebugMode) {
            debugPrint('Skipping malformed job entry: $job');
          }
          continue;
        }

        try {
          parsedJobs.add(Job.fromJson(Map<String, dynamic>.from(job)));
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Skipping job due to parse error: $error');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _jobs = parsedJobs;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading jobs: $e');
      }

      final message = ApiService.normalizeErrorMessage(
        e,
        fallback: 'Unable to load jobs right now.',
      );

      if (!mounted) return;

      setState(() {
        _jobs = [];
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  Future<void> _openJobDetails(Job job) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(jobId: job.jobId),
      ),
    );
    if (!mounted) return;
    _loadJobs(forceRefresh: true);
  }

  Widget _buildViewToggle() {
    Widget item({
      required String value,
      required String label,
      required IconData icon,
      required Color activeColor,
    }) {
      final isSelected = _selectedView == value;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            if (_selectedView == value) return;
            setState(() => _selectedView = value);
            _loadJobs();
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? activeColor : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.28),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey.shade800,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F4F7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            item(
              value: 'open',
              label: 'Open Jobs',
              icon: Icons.bolt_rounded,
              activeColor: const Color(0xFF2E8B57),
            ),
            const SizedBox(width: 6),
            item(
              value: 'history',
              label: 'History',
              icon: Icons.history_rounded,
              activeColor: const Color(0xFF5B6C8F),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Search jobs, companies...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _loadJobs(forceRefresh: true);
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
      ),
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) => _loadJobs(),
    );
  }

  Widget _buildLocationFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ..._locations.map((location) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(location, style: const TextStyle(fontSize: 13)),
                  selected: _selectedLocation == location,
                  onSelected: (selected) {
                    setState(() {
                      _selectedLocation = location;
                    });
                    _loadJobs();
                  },
                  backgroundColor: Colors.grey.shade100,
                  selectedColor: Colors.blue.shade100,
                ),
              );
            }),
            ActionChip(
              label: Text(
                _moreLocations.contains(_selectedLocation)
                    ? _selectedLocation
                    : 'Other Regions',
                style: const TextStyle(fontSize: 13),
              ),
              backgroundColor: _moreLocations.contains(_selectedLocation)
                  ? Colors.blue.shade100
                  : Colors.grey.shade100,
              onPressed: _openMoreRegionsSheet,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openMoreRegionsSheet() async {
    final selectedRegion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Other Regions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ..._moreLocations.map((region) {
                final isSelected = _selectedLocation == region;
                return ListTile(
                  title: Text(region),
                  trailing: isSelected
                      ? const Icon(Icons.check, color: Colors.blue)
                      : null,
                  onTap: () => Navigator.pop(context, region),
                );
              }),
            ],
          ),
        );
      },
    );

    if (!mounted || selectedRegion == null) return;

    setState(() {
      _selectedLocation = selectedRegion;
    });
    _loadJobs();
  }

  Widget _buildResultsCount() {
    final title = _selectedView == 'history' ? 'Job History' : 'Browse Jobs';
    final subtitle = _selectedView == 'history'
        ? 'Review previous openings and closed opportunities.'
        : 'Explore available industrial practical training opportunities.';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _selectedView == 'history'
                    ? Icons.history_rounded
                    : Icons.work_outline_rounded,
                color: const Color(0xFF2563EB),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7FC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _selectedView == 'history'
                              ? '${_jobs.length} posted jobs in history'
                              : '${_jobs.length} opportunities found',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1D4ED8),
                          ),
                        ),
                      ),
                      if (_selectedLocation != 'all')
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _selectedLocation,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF047857),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_isLoading && _jobs.isEmpty)
              TextButton(
                onPressed: () => _loadJobs(forceRefresh: true),
                child: const Text('Refresh'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.work_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            _selectedView == 'history'
                ? 'No job history found'
                : 'No opportunities found',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedView == 'history'
                ? 'Expired and closed jobs will appear here'
                : 'Try adjusting your filters',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Unable to load jobs',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadJobs(forceRefresh: true),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            toolbarHeight: 88,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: _buildSearchField(),
            ),
          ),
          SliverToBoxAdapter(child: _buildViewToggle()),
          SliverToBoxAdapter(child: _buildLocationFilter()),
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildResultsCount()),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null && _jobs.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildErrorState())
          else if (_jobs.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                itemCount: _jobs.length,
                itemBuilder: (context, index) {
                  final job = _jobs[index];
                  return JobCard(
                    job: job,
                    onViewDetails: () => _openJobDetails(job),
                    onApplyNow: () => _openJobDetails(job),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
