// lib/screens/student/browse_training_screen.dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/job.dart';
import '../../utils/role_theme.dart';
import '../../widgets/job_card.dart';
import 'job_details_screen.dart';

class BrowsetrainingScreen extends StatefulWidget {
  const BrowsetrainingScreen({super.key});

  @override
  State<BrowsetrainingScreen> createState() => _BrowsetrainingScreenState();
}

class _BrowsetrainingScreenState extends State<BrowsetrainingScreen> {
  final ApiService _apiService = ApiService();
  List<Job> _training = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedView = 'open';
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  int _loadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadtraining(forceRefresh: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadtraining({bool forceRefresh = false}) async {
    final requestId = ++_loadRequestId;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _apiService.gettraining(
        view: _selectedView,
        search: _searchController.text.isEmpty ? null : _searchController.text,
        forceRefresh: forceRefresh,
      );

      if (response['success'] != true) {
        throw Exception(
          ApiService.responseMessage(
            response,
            fallback: 'Unable to load training right now.',
          ),
        );
      }

      final trainingData = response['data'];
      if (trainingData is! List) {
        throw const FormatException('training response is invalid.');
      }

      final parsedtraining = <Job>[];
      for (final job in trainingData) {
        if (job is! Map) {
          if (kDebugMode) {
            debugPrint('Skipping malformed job entry: $job');
          }
          continue;
        }

        try {
          parsedtraining.add(Job.fromJson(Map<String, dynamic>.from(job)));
        } catch (error) {
          if (kDebugMode) {
            debugPrint('Skipping job due to parse error: $error');
          }
        }
      }

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _training = parsedtraining;
        _isLoading = false;
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading training: $e');
      }

      final message = ApiService.normalizeErrorMessage(
        e,
        fallback: 'Unable to load training right now.',
      );

      if (!mounted || requestId != _loadRequestId) return;

      setState(() {
        _training = [];
        _isLoading = false;
        _errorMessage = message;
      });
    }
  }

  void _scheduleSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _loadtraining();
    });
  }

  Future<void> _openJobDetails(Job job, {bool openApplySheet = false}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JobDetailsScreen(
          jobId: job.jobId,
          openApplySheetOnLoad: openApplySheet,
        ),
      ),
    );
    if (!mounted) return;
    _loadtraining(forceRefresh: true);
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
            _loadtraining();
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
              label: 'Open training',
              icon: Icons.bolt_rounded,
              activeColor: StudentRoleTheme.primary,
            ),
            const SizedBox(width: 6),
            item(
              value: 'history',
              label: 'History',
              icon: Icons.history_rounded,
              activeColor: StudentRoleTheme.primary,
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
        hintText: 'Search training, companies,region..',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {});
                  _loadtraining(forceRefresh: true);
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
      onChanged: (_) {
        setState(() {});
        _scheduleSearch();
      },
      onSubmitted: (_) {
        _searchDebounce?.cancel();
        _loadtraining();
      },
    );
  }

  Widget _buildResultsCount() {
    final title = _selectedView == 'history'
        ? 'Training History'
        : 'Browse training';
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
                color: StudentRoleTheme.surface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                _selectedView == 'history'
                    ? Icons.history_rounded
                    : Icons.work_outline_rounded,
                color: StudentRoleTheme.primary,
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
                              ? '${_training.length} posted training in history'
                              : '${_training.length} opportunities found',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: StudentRoleTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (!_isLoading && _training.isEmpty && _selectedView != 'history')
              TextButton(
                onPressed: () => _loadtraining(forceRefresh: true),
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
                ? 'Expired and closed training will appear here'
                : 'Try a different search term',
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
              'Unable to load training',
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
              onPressed: () => _loadtraining(forceRefresh: true),
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
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(child: _buildResultsCount()),
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null && _training.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildErrorState())
          else if (_training.isEmpty)
            SliverFillRemaining(hasScrollBody: false, child: _buildEmptyState())
          else
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 24),
              sliver: SliverList.builder(
                itemCount: _training.length,
                itemBuilder: (context, index) {
                  final job = _training[index];
                  return JobCard(
                    job: job,
                    onViewDetails: () => _openJobDetails(job),
                    onApplyNow: () =>
                        _openJobDetails(job, openApplySheet: true),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
