import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import '../../services/api_service.dart';
import 'admin_application_filter.dart';
import 'admin_export_utils.dart';

class AdminApplicationsScreen extends StatefulWidget {
  final AdminApplicationFilter selectedFilter;

  const AdminApplicationsScreen({
    super.key,
    this.selectedFilter = AdminApplicationFilter.all,
  });

  @override
  State<AdminApplicationsScreen> createState() =>
      _AdminApplicationsScreenState();
}

class _AdminApplicationsScreenState extends State<AdminApplicationsScreen> {
  bool _isLoading = true;
  List<dynamic> _applications = [];
  late AdminApplicationFilter _activeFilter;
  final ApiService _apiService = ApiService();

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.selectedFilter;
    _fetchApplications();
  }

  @override
  void didUpdateWidget(covariant AdminApplicationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFilter != widget.selectedFilter) {
      _activeFilter = widget.selectedFilter;
      _fetchApplications();
    }
  }

  String? _statusForFilter(AdminApplicationFilter filter) {
    switch (filter) {
      case AdminApplicationFilter.pending:
        return 'pending';
      case AdminApplicationFilter.approved:
        return 'approved';
      case AdminApplicationFilter.rejected:
        return 'rejected';
      case AdminApplicationFilter.all:
        return null;
    }
  }

  Future<void> _fetchApplications() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getApplications(
        status: _statusForFilter(_activeFilter),
      );
      if (!mounted) return;

      setState(() {
        _applications = response['success'] == true && response['data'] is List
            ? List<dynamic>.from(response['data'])
            : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to load applications: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return const Color(0xFF059669);
      case 'rejected':
        return Colors.red;
      default:
        return const Color(0xFFD97706);
    }
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'No date';
    try {
      final parsed = DateTime.parse(value).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year;
      return '$day/$month/$year';
    } catch (_) {
      return value;
    }
  }

  Future<void> _updateStatus(
    String id,
    String status, {
    bool notifyUser = false,
  }) async {
    final response = await _apiService.updateApplicationStatus(
      id,
      status,
      notifyUser: notifyUser,
    );
    if (!mounted) return;

    if (response['success'] == true) {
      await _fetchApplications();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            notifyUser
                ? 'Application $status and user notified'
                : 'Application $status successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Failed to update application',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportApplications(List<dynamic> applications) async {
    await AdminExportUtils.showExportDialog(
      context,
      title: 'applications',
      filePrefix: 'applications_export',
      headers: const [
        'Applicant',
        'Company',
        'Job',
        'Applied date',
        'Status',
        'Document',
      ],
      rows: applications.map((app) {
        return [
          '${app['user_name'] ?? ''}',
          '${app['company_name'] ?? ''}',
          '${app['job_title'] ?? ''}',
          _formatDate('${app['applied_date'] ?? ''}'),
          '${app['status'] ?? ''}',
          '${app['resume_url'] ?? ''}',
        ];
      }).toList(),
    );
  }

  Future<void> _showApplicationDetails(dynamic app) async {
    bool notifyUser = true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final status = '${app['status'] ?? 'pending'}';
          final resume = '${app['resume_url'] ?? ''}'.trim();

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${app['user_name'] ?? 'Applicant'}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('${app['email'] ?? ''}'),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        Chip(label: Text('Status: $status')),
                        Chip(
                          label: Text(
                            'Applied: ${_formatDate('${app['applied_date'] ?? ''}')}',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    _ApplicationLine(
                      label: 'Company info',
                      value: '${app['company_name'] ?? '-'}',
                    ),
                    _ApplicationLine(
                      label: 'Position',
                      value: '${app['job_title'] ?? '-'}',
                    ),
                    _ApplicationLine(
                      label: 'CV/Document',
                      value: resume.isEmpty ? 'No uploaded document' : resume,
                    ),
                    _ApplicationLine(
                      label: 'Cover letter',
                      value: '${app['cover_letter'] ?? '-'}',
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notify user after approve'),
                      subtitle: const Text(
                        'Send an in-app notification when this application is approved.',
                      ),
                      value: notifyUser,
                      onChanged: (value) {
                        setModalState(() => notifyUser = value);
                      },
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        if (status == 'pending')
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _updateStatus(
                                '${app['application_id']}',
                                'approved',
                                notifyUser: notifyUser,
                              );
                            },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Approve'),
                          ),
                        if (status == 'pending')
                          OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(sheetContext).pop();
                              _updateStatus(
                                '${app['application_id']}',
                                'rejected',
                              );
                            },
                            icon: const Icon(Icons.cancel_rounded),
                            label: const Text('Reject'),
                          ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();
                            _exportApplications([app]);
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Export application'),
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
    );
  }

  Widget _buildFilterChip(AdminApplicationFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _activeFilter == filter,
      onSelected: (_) {
        setState(() => _activeFilter = filter);
        _fetchApplications();
      },
    );
  }

  Widget _buildApplicationCard(dynamic app) {
    final status = '${app['status'] ?? 'pending'}';
    final statusColor = _statusColor(status);

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
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  foregroundColor: statusColor,
                  child: const Icon(Icons.assignment_ind_rounded),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${app['user_name'] ?? 'Unknown applicant'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${app['company_name'] ?? 'Unknown company'}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Applied on ${_formatDate('${app['applied_date'] ?? ''}')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'export') {
                      _exportApplications([app]);
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'export',
                      child: Text('Export application'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${app['job_title'] ?? 'Unknown job'}',
              style: TextStyle(
                color: Colors.grey.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => _showApplicationDetails(app),
                  child: const Text('View details'),
                ),
                if (status == 'pending')
                  ElevatedButton(
                    onPressed: () => _updateStatus(
                      '${app['application_id']}',
                      'approved',
                      notifyUser: true,
                    ),
                    child: const Text('Approve'),
                  ),
                if (status == 'pending')
                  OutlinedButton(
                    onPressed: () =>
                        _updateStatus('${app['application_id']}', 'rejected'),
                    child: const Text('Reject'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchApplications,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip(AdminApplicationFilter.all, 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        AdminApplicationFilter.pending,
                        'Pending',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        AdminApplicationFilter.approved,
                        'Approved',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        AdminApplicationFilter.rejected,
                        'Rejected',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _exportApplications(_applications),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_applications.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text('No applications found for this filter.'),
            )
          else
            ..._applications.map(_buildApplicationCard),
        ],
      ),
    );
  }
}

class _ApplicationLine extends StatelessWidget {
  final String label;
  final String value;

  const _ApplicationLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
