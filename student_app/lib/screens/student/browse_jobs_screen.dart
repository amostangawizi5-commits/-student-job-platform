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
  String _selectedView = 'open';
  String _selectedType = 'all';
  String _selectedLocation = 'all';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _jobTypes = [
    'all',
    'internship',
    'full-time',
    'part-time',
    'graduate_program',
  ];
  final List<String> _locations = [
    'all',
    'Dar es Salaam',
    'Dodoma',
    'Arusha',
    'Mwanza',
    'Remote',
  ];

  @override
  void initState() {
    super.initState();
    _loadJobs();
  }

  Future<void> _loadJobs({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getJobs(
        view: _selectedView,
        type: _selectedType == 'all' ? null : _selectedType,
        location: _selectedLocation == 'all' ? null : _selectedLocation,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        forceRefresh: forceRefresh,
      );

      if (response['success']) {
        final List<dynamic> jobsData = response['data'];
        setState(() {
          _jobs = jobsData.map((job) => Job.fromJson(job)).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading jobs: $e');
      }
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading jobs: $e')));
      }
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search jobs, companies...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
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
              onSubmitted: (_) => _loadJobs(),
            ),
          ),
          // Type Filter
          _buildViewToggle(),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _jobTypes.map((type) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        type == 'all'
                            ? 'All'
                            : type == 'internship'
                            ? 'Internship'
                            : type == 'full-time'
                            ? 'Full Time'
                            : type == 'part-time'
                            ? 'Part Time'
                            : 'Graduate Program',
                        style: const TextStyle(fontSize: 13),
                      ),
                      selected: _selectedType == type,
                      onSelected: (selected) {
                        setState(() {
                          _selectedType = type;
                        });
                        _loadJobs();
                      },
                      backgroundColor: Colors.grey.shade100,
                      selectedColor: Colors.blue.shade100,
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // Location Filter
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _locations.map((location) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        location,
                        style: const TextStyle(fontSize: 13),
                      ),
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
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Results Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedView == 'history'
                      ? '${_jobs.length} posted jobs in history'
                      : '${_jobs.length} opportunities found',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (!_isLoading && _jobs.isEmpty)
                  TextButton(
                    onPressed: () => _loadJobs(forceRefresh: true),
                    child: const Text('Refresh'),
                  ),
              ],
            ),
          ),
          // Job List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.work_off,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _selectedView == 'history'
                              ? 'No job history found'
                              : 'No opportunities found',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _selectedView == 'history'
                              ? 'Expired and closed jobs will appear here'
                              : 'Try adjusting your filters',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _jobs.length,
                    itemBuilder: (context, index) {
                      final job = _jobs[index];
                      return JobCard(
                        job: job,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  JobDetailsScreen(jobId: job.jobId),
                            ),
                          );
                          _loadJobs(
                            forceRefresh: true,
                          ); // Refresh when coming back
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
