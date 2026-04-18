import 'package:flutter/material.dart';

import '../../services/coordinator_workspace_service.dart';

class CompanyReportsBoard extends StatefulWidget {
  const CompanyReportsBoard({super.key, required this.universityName});

  final String universityName;

  @override
  State<CompanyReportsBoard> createState() => _CompanyReportsBoardState();
}

class _CompanyReportsBoardState extends State<CompanyReportsBoard> {
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();

  bool _isLoading = true;
  List<Map<String, dynamic>> _reports = const [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);
    final reports = await _workspaceService.getReportsForUniversity(
      universityName: widget.universityName,
    );
    if (!mounted) return;
    setState(() {
      _reports = reports;
      _isLoading = false;
    });
  }

  String _formatDate(String value) {
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return value;
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  Color _issueColor(String issueType) {
    switch (issueType) {
      case 'absent':
        return const Color(0xFFB7791F);
      case 'left_without_permission':
        return const Color(0xFFB42318);
      default:
        return const Color(0xFF103B63);
    }
  }

  String _issueLabel(String issueType) {
    switch (issueType) {
      case 'absent':
        return 'Not attending';
      case 'left_without_permission':
        return 'Left workplace without permission';
      default:
        return 'Conduct issue';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_reports.isEmpty) {
      return Container(
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
              Icons.report_problem_outlined,
              size: 42,
              color: Color(0xFF5F7288),
            ),
            SizedBox(height: 10),
            Text(
              'No company reports have been submitted yet',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF17324D),
              ),
            ),
            SizedBox(height: 6),
            Text(
              '',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF5F7288)),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _reports
          .map((report) {
            final issueType = '${report['issue_type'] ?? 'other'}';
            final issueColor = _issueColor(issueType);
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
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: issueColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          Icons.report_problem_rounded,
                          color: issueColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${report['student_name'] ?? 'Student'}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF17324D),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${report['company_name'] ?? 'Company'} • ${report['job_title'] ?? 'Placement'}',
                              style: const TextStyle(color: Color(0xFF5F7288)),
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
                          color: issueColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _issueLabel(issueType),
                          style: TextStyle(
                            color: issueColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    '${report['description'] ?? ''}',
                    style: const TextStyle(
                      color: Color(0xFF36495E),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 16,
                    runSpacing: 10,
                    children: [
                      Text('Student email: ${report['student_email'] ?? '-'}'),
                      Text(
                        'Received: ${_formatDate('${report['created_at'] ?? ''}')}',
                      ),
                    ],
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}
