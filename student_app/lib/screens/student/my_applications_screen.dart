import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class MyApplicationsScreen extends StatefulWidget {
  final String initialFilter;
  final int refreshToken;

  const MyApplicationsScreen({
    super.key,
    this.initialFilter = 'all',
    this.refreshToken = 0,
  });

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  final ApiService _apiService = ApiService();
  List<dynamic> _applications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _selectedFilter = _normalizeFilter(widget.initialFilter);
    _loadApplications();
  }

  @override
  void didUpdateWidget(covariant MyApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      setState(() {
        _selectedFilter = _normalizeFilter(widget.initialFilter);
      });
    }

    if (oldWidget.refreshToken != widget.refreshToken) {
      _loadApplications();
    }
  }

  String _normalizeFilter(String filter) {
    switch (filter.toLowerCase()) {
      case 'interview':
      case 'pending':
      case 'review':
      case 'accepted':
      case 'rejected':
        return filter.toLowerCase();
      default:
        return 'all';
    }
  }

  bool _matchesSelectedFilter(Map<String, dynamic> app) {
    if (_selectedFilter == 'all') return true;

    final status = '${app['status'] ?? ''}'.toLowerCase();
    if (_selectedFilter == 'review') {
      return status == 'shortlisted' ||
          status == 'review' ||
          status == 'under_review';
    }
    return status == _selectedFilter;
  }

  List<dynamic> _getFilteredApplications() {
    return _applications.where((app) {
      if (app is! Map<String, dynamic>) return false;
      return _matchesSelectedFilter(app);
    }).toList();
  }

  String _filterTitle() {
    switch (_selectedFilter) {
      case 'interview':
        return 'Interview';
      case 'pending':
        return 'Pending';
      case 'review':
        return 'Review';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return 'All';
    }
  }

  Future<void> _loadApplications() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getMyApplications();
      debugPrint('Applications: ${response['data']?.length ?? 0}');
      if (response['success']) {
        setState(() {
          _applications = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error: $e');
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'shortlisted':
        return Colors.blue;
      case 'interview':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending':
        return 'Pending Review';
      case 'shortlisted':
        return 'Shortlisted';
      case 'interview':
        return 'Interview Scheduled';
      case 'accepted':
        return 'Accepted';
      case 'rejected':
        return 'Rejected';
      default:
        return status;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty;
      case 'shortlisted':
        return Icons.star;
      case 'interview':
        return Icons.calendar_today;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApplications = _getFilteredApplications();
    final title = _selectedFilter == 'all'
        ? 'My Applications'
        : 'My Applications (${_filterTitle()})';

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (filteredApplications.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_turned_in,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              Text(
                _selectedFilter == 'all'
                    ? 'No applications yet'
                    : 'No ${_filterTitle().toLowerCase()} applications yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFilter == 'all'
                    ? 'Start applying for jobs to see them here'
                    : 'Try another filter or apply to more jobs',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Use pop until first to avoid navigation stack issues
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Filter',
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() {
                _selectedFilter = value;
              });
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'all', child: Text('All')),
              PopupMenuItem(value: 'interview', child: Text('Interview')),
              PopupMenuItem(value: 'pending', child: Text('Pending')),
              PopupMenuItem(value: 'review', child: Text('Review')),
              PopupMenuItem(value: 'accepted', child: Text('Accepted')),
              PopupMenuItem(value: 'rejected', child: Text('Rejected')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadApplications,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredApplications.length,
        itemBuilder: (context, index) {
          final app = filteredApplications[index];
          final status = app['status'] ?? 'pending';
          final statusColor = _getStatusColor(status);
          final statusText = _getStatusText(status);
          final statusIcon = _getStatusIcon(status);

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade200,
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              app['title'] ?? 'No Title',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              app['company_name'] ?? 'Unknown Company',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 14, color: statusColor),
                            const SizedBox(width: 4),
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 12,
                                color: statusColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          app['location'] ?? 'Location not specified',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.work, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Text(
                        app['type'] ?? 'Job',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Applied: ${_formatDate(app['applied_date'])}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
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
