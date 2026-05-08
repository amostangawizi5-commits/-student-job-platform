import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';

import '../../services/coordinator_workspace_service.dart';

class CoordinatorApprovalQueue extends StatefulWidget {
  const CoordinatorApprovalQueue({
    super.key,
    required this.universityName,
    required this.coordinatorName,
  });

  final String universityName;
  final String coordinatorName;

  @override
  State<CoordinatorApprovalQueue> createState() =>
      _CoordinatorApprovalQueueState();
}

class _CoordinatorApprovalQueueState extends State<CoordinatorApprovalQueue> {
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();

  bool _isLoading = true;
  String _filter = 'all';
  List<Map<String, dynamic>> _records = const [];

  @override
  void initState() {
    super.initState();
    _loadApprovals();
  }

  Future<void> _loadApprovals() async {
    setState(() => _isLoading = true);
    final records = await _workspaceService.getApprovalRecords(
      universityName: widget.universityName,
    );
    if (!mounted) return;
    setState(() {
      _records = records;
      _isLoading = false;
    });
  }

  Future<void> _updateStatus(Map<String, dynamic> record, String status) async {
    final notesController = TextEditingController(
      text: '${record['coordinator_notes'] ?? ''}',
    );

    try {
      final notes = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            status == 'approved' ? 'Approve selection' : 'Reject selection',
          ),
          content: TextField(
            controller: notesController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Coordinator notes',
              hintText: status == 'approved'
                  ? 'Optional guidance for the student and company'
                  : 'Explain why this selection is not approved',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, notesController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: status == 'approved'
                    ? const Color(0xFF0F766E)
                    : const Color(0xFFB42318),
              ),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        ),
      );

      if (notes == null) return;
      await _workspaceService.updateApprovalStatus(
        approvalId: '${record['id'] ?? ''}',
        status: status,
        coordinatorName: widget.coordinatorName,
        coordinatorNotes: notes,
      );
      await _loadApprovals();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Student selection approved successfully.'
                : 'Student selection rejected successfully.',
          ),
          backgroundColor: status == 'approved'
              ? const Color(0xFF0F766E)
              : const Color(0xFFB42318),
        ),
      );
    } finally {
      notesController.dispose();
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_filter == 'all') return _records;
    return _records
        .where(
          (record) => '${record['coordinator_status'] ?? 'pending'}' == _filter,
        )
        .toList(growable: false);
  }

  int _countByStatus(String status) {
    return _records
        .where(
          (record) => '${record['coordinator_status'] ?? 'pending'}' == status,
        )
        .length;
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Color _statusColor(String value) {
    switch (value) {
      case 'approved':
        return const Color(0xFF0F766E);
      case 'rejected':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFFB7791F);
    }
  }

  String _statusLabel(String value) {
    switch (value) {
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Pending';
    }
  }

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(title, style: const TextStyle(color: Color(0xFF5F7288))),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 860;
            final cards = [
              _buildStatCard(
                'Pending',
                '${_countByStatus('pending')}',
                const Color(0xFFB7791F),
                Icons.schedule_rounded,
              ),
              _buildStatCard(
                'Approved',
                '${_countByStatus('approved')}',
                const Color(0xFF0F766E),
                Icons.verified_rounded,
              ),
              _buildStatCard(
                'Rejected',
                '${_countByStatus('rejected')}',
                const Color(0xFFB42318),
                Icons.cancel_outlined,
              ),
            ];

            if (!isWide) {
              return Column(
                children: cards
                    .map(
                      (card) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: card,
                      ),
                    )
                    .toList(growable: false),
              );
            }

            return Row(
              children: cards
                  .map(
                    (card) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: card,
                      ),
                    ),
                  )
                  .toList(growable: false),
            );
          },
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: _filter == 'all',
                onSelected: (_) => setState(() => _filter = 'all'),
              ),
              ChoiceChip(
                label: const Text('Pending'),
                selected: _filter == 'pending',
                onSelected: (_) => setState(() => _filter = 'pending'),
              ),
              ChoiceChip(
                label: const Text('Approved'),
                selected: _filter == 'approved',
                onSelected: (_) => setState(() => _filter = 'approved'),
              ),
              ChoiceChip(
                label: const Text('Rejected'),
                selected: _filter == 'rejected',
                onSelected: (_) => setState(() => _filter = 'rejected'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_filteredRecords.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD9E6F2)),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 42,
                  color: Color(0xFF5F7288),
                ),
                SizedBox(height: 10),
                Text(
                  'No company selections in this queue yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17324D),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Accepted students from the company workflow will appear here for coordinator review.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF5F7288)),
                ),
              ],
            ),
          )
        else
          Column(
            children: _filteredRecords
                .map((record) {
                  final status = '${record['coordinator_status'] ?? 'pending'}';
                  final statusColor = _statusColor(status);
                  final notes = '${record['coordinator_notes'] ?? ''}'.trim();
                  final isPending = status == 'pending';
                  final studentName = '${record['student_name'] ?? 'Student'}'
                      .trim();
                  final avatarLabel = studentName.isEmpty
                      ? 'S'
                      : studentName.substring(0, 1).toUpperCase();

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD9E6F2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              backgroundColor: statusColor.withValues(
                                alpha: 0.12,
                              ),
                              foregroundColor: statusColor,
                              child: Text(avatarLabel),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    studentName.isEmpty
                                        ? 'Student'
                                        : studentName,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF17324D),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${record['student_email'] ?? ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF5F7288),
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
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _statusLabel(status),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 16,
                          runSpacing: 10,
                          children: [
                            Text('Company: ${record['company_name'] ?? '-'}'),
                            Text('Position: ${record['job_title'] ?? '-'}'),
                            Text(
                              'Queued: ${_formatDate('${record['created_at'] ?? ''}')}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if ('${record['reporting_start_date'] ?? ''}'
                                .trim()
                                .isNotEmpty ||
                            '${record['reporting_end_date'] ?? ''}'
                                .trim()
                                .isNotEmpty)
                          Text(
                            'Reporting window: ${record['reporting_start_date'] ?? '-'} to ${record['reporting_end_date'] ?? '-'}',
                            style: const TextStyle(color: Color(0xFF36495E)),
                          ),
                        if (notes.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7FBFE),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD9E6F2),
                              ),
                            ),
                            child: Text(
                              'Coordinator notes: $notes',
                              style: const TextStyle(color: Color(0xFF36495E)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            ElevatedButton.icon(
                              onPressed: isPending
                                  ? () => _updateStatus(record, 'approved')
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F766E),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.check_circle_outline),
                              label: const Text('Approve'),
                            ),
                            OutlinedButton.icon(
                              onPressed: isPending
                                  ? () => _updateStatus(record, 'rejected')
                                  : null,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB42318),
                                side: const BorderSide(
                                  color: Color(0xFFB42318),
                                ),
                              ),
                              icon: const Icon(Icons.highlight_off_rounded),
                              label: const Text('Reject'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                })
                .toList(growable: false),
          ),
      ],
    );
  }
}
