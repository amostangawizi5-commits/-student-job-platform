import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class AdminJobsScreen extends StatefulWidget {
  const AdminJobsScreen({super.key});

  @override
  State<AdminJobsScreen> createState() => _AdminJobsScreenState();
}

class _AdminJobsScreenState extends State<AdminJobsScreen> {
  bool _isLoading = true;
  List<dynamic> _jobs = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _fetchJobs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchJobs() async {
    try {
      final response = await _apiService.getJobs();
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _jobs = response['data'];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  bool _matchesSearch(dynamic job) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();
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

  String _formatDeadline(String? deadline) {
    if (deadline == null || deadline.trim().isEmpty) return 'No deadline';

    try {
      final parsed = DateTime.parse(deadline).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year;
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return deadline;
    }
  }

  Widget _buildMetaChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade700),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: value),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showJobDetails(dynamic job) {
    final title = '${job['title'] ?? 'No title'}';
    final companyName = '${job['company_name'] ?? 'Unknown company'}';
    final location = '${job['location'] ?? 'Not specified'}';
    final type =
        '${job['type'] ?? job['employment_type'] ?? job['job_type'] ?? 'Not specified'}';
    final category = '${job['category'] ?? 'Not specified'}';
    final salary = '${job['salary_range'] ?? 'Not specified'}';
    final requiredApplicants =
        '${job['required_applicants'] ?? 'Not specified'}';
    final status = '${job['status'] ?? 'open'}';
    final deadline = _formatDeadline('${job['application_deadline'] ?? ''}');
    final description = '${job['description'] ?? 'No description provided'}';

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          scrollable: true,
          title: Text(title),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  companyName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  Icons.location_on_outlined,
                  'Location',
                  location,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.badge_outlined, 'Type', type),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.category_outlined, 'Category', category),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.payments_outlined, 'Salary', salary),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.people_outline_rounded,
                  'Required applicants',
                  requiredApplicants,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(
                  Icons.calendar_today_outlined,
                  'Deadline',
                  deadline,
                ),
                const SizedBox(height: 10),
                _buildDetailRow(Icons.info_outline_rounded, 'Status', status),
                const SizedBox(height: 18),
                const Text(
                  'Description',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(description),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredJobs = _jobs.where(_matchesSearch).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Moderation'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchJobs),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() => _searchQuery = value);
              },
              decoration: InputDecoration(
                hintText: 'Search by job title, company, location...',
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
            child: filteredJobs.isEmpty
                ? Center(
                    child: Text(
                      _searchQuery.trim().isNotEmpty
                          ? 'No jobs match your search'
                          : 'No jobs found',
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredJobs.length,
                    itemBuilder: (context, index) {
                      final job = filteredJobs[index];
                      final title = '${job['title'] ?? 'No title'}';
                      final companyName =
                          '${job['company_name'] ?? 'Unknown company'}';
                      final location = '${job['location'] ?? ''}'.trim();
                      final type =
                          '${job['type'] ?? job['employment_type'] ?? job['job_type'] ?? ''}'
                              .trim();
                      final salary = '${job['salary_range'] ?? ''}'.trim();
                      final status = '${job['status'] ?? 'open'}'.trim();
                      final deadline = _formatDeadline(
                        '${job['application_deadline'] ?? ''}',
                      );
                      final description = '${job['description'] ?? ''}'.trim();
                      final previewDescription = description.isEmpty
                          ? 'No description provided'
                          : (description.length > 110
                                ? '${description.substring(0, 110)}...'
                                : description);

                      return Card(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => _showJobDetails(job),
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
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            title,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            companyName,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Icon(
                                      Icons.visibility_outlined,
                                      color: Colors.grey.shade600,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    if (location.isNotEmpty)
                                      _buildMetaChip(
                                        Icons.location_on_outlined,
                                        location,
                                        Colors.blue,
                                      ),
                                    if (type.isNotEmpty)
                                      _buildMetaChip(
                                        Icons.badge_outlined,
                                        type,
                                        Colors.deepPurple,
                                      ),
                                    if (salary.isNotEmpty)
                                      _buildMetaChip(
                                        Icons.payments_outlined,
                                        salary,
                                        Colors.green,
                                      ),
                                    _buildMetaChip(
                                      status == 'open'
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.cancel_outlined,
                                      status,
                                      status == 'open'
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  previewDescription,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 16,
                                      color: Colors.grey.shade600,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Deadline: $deadline',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
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
        ],
      ),
    );
  }
}
