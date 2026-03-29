import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_export_utils.dart';

class AdminLogsScreen extends StatefulWidget {
  const AdminLogsScreen({super.key});

  @override
  State<AdminLogsScreen> createState() => _AdminLogsScreenState();
}

class _AdminLogsScreenState extends State<AdminLogsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _logs = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final response = await _apiService.getAdminLogs();
    if (!mounted) return;

    setState(() {
      _logs = response['success'] == true && response['data'] is List
          ? List<dynamic>.from(response['data'])
          : [];
      _isLoading = false;
    });
  }

  List<dynamic> _filteredLogs() {
    return _logs.where((log) {
      final category = '${log['category'] ?? 'all'}'.toLowerCase();
      final query = _searchQuery.trim().toLowerCase();
      final matchesCategory =
          _selectedCategory == 'all' || category == _selectedCategory;
      if (!matchesCategory) return false;
      if (query.isEmpty) return true;

      final searchable = [
        '${log['event_type'] ?? ''}',
        '${log['message'] ?? ''}',
        '${log['user_involved_name'] ?? ''}',
        '${log['actor_name'] ?? ''}',
      ];
      return searchable.any((value) => value.toLowerCase().contains(query));
    }).toList();
  }

  String _formatDate(String? value) {
    if (value == null || value.trim().isEmpty) return 'Unknown time';
    try {
      final parsed = DateTime.parse(value).toLocal();
      final day = parsed.day.toString().padLeft(2, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final year = parsed.year;
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return value;
    }
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'login':
        return Icons.login_rounded;
      case 'error':
        return Icons.error_outline_rounded;
      default:
        return Icons.admin_panel_settings_rounded;
    }
  }

  Color _colorForCategory(String category) {
    switch (category) {
      case 'login':
        return const Color(0xFF2563EB);
      case 'error':
        return Colors.red;
      default:
        return const Color(0xFF059669);
    }
  }

  Future<void> _exportLogs(List<dynamic> logs) async {
    await AdminExportUtils.showExportDialog(
      context,
      title: 'report',
      filePrefix: 'system_report',
      headers: const ['Category', 'Event', 'Message', 'Time', 'User involved'],
      rows: logs.map((log) {
        return [
          '${log['category'] ?? ''}',
          '${log['event_type'] ?? ''}',
          '${log['message'] ?? ''}',
          _formatDate('${log['created_at'] ?? ''}'),
          '${log['user_involved_name'] ?? log['actor_name'] ?? ''}',
        ];
      }).toList(),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _selectedCategory == value,
      onSelected: (_) => setState(() => _selectedCategory = value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final logs = _filteredLogs();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _loadLogs,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Report',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Track login events, admin actions, and system issues from one report feed.',
                  style: TextStyle(color: Colors.grey.shade600, height: 1.35),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search report activity',
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
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('login', 'Login'),
                      const SizedBox(width: 8),
                      _buildFilterChip('error', 'Error'),
                      const SizedBox(width: 8),
                      _buildFilterChip('admin_action', 'Admin action'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _exportLogs(logs),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (logs.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text(
                'No report entries found for the current filter.',
              ),
            )
          else
            ...logs.map((log) {
              final category = '${log['category'] ?? 'admin_action'}';
              final color = _colorForCategory(category);
              final icon = _iconForCategory(category);

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color),
                        ),
                        Container(
                          width: 2,
                          height: 70,
                          color: Colors.grey.shade200,
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Card(
                        margin: EdgeInsets.zero,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${log['event_type'] ?? 'System event'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatDate('${log['created_at'] ?? ''}'),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('${log['message'] ?? ''}'),
                              const SizedBox(height: 10),
                              Text(
                                'User involved: ${log['user_involved_name'] ?? log['actor_name'] ?? 'System'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
