// lib/screens/student/job_details_screen.dart
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/job.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  const JobDetailsScreen({super.key, required this.jobId});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final ApiService _apiService = ApiService();
  Job? _job;
  bool _isLoading = true;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  Future<void> _loadJobDetails() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getJobById(widget.jobId);
      if (response['success']) {
        setState(() {
          _job = Job.fromJson(response['data']);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading job details: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading job details: $e')),
        );
      }
    }
  }

  Future<void> _applyForJob() async {
    if (_job == null) {
      debugPrint('Error: Job is null');
      return;
    }

    debugPrint('Applying for job: ${_job!.jobId}');
    debugPrint('Job title: ${_job!.title}');

    setState(() => _isApplying = true);

    try {
      final response = await _apiService.applyForJob(_job!.jobId);
      debugPrint('Apply response: $response');

      if (response['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Application submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Go back to browse jobs after successful application
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Application failed'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Apply error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'internship':
        return 'Internship';
      case 'full-time':
        return 'Full Time';
      case 'part-time':
        return 'Part Time';
      case 'graduate_program':
        return 'Graduate Program';
      default:
        return type;
    }
  }

  String _formatDeadline(DateTime deadline) {
    final day = deadline.day.toString().padLeft(2, '0');
    final month = deadline.month.toString().padLeft(2, '0');
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$day/$month/${deadline.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_job == null) {
      return const Scaffold(body: Center(child: Text('Job not found')));
    }

    final difference = _job!.applicationDeadline.difference(DateTime.now());
    final daysLeft = difference.inDays;
    final isClosed = _job!.status != 'open' || difference.isNegative;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Header
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _job!.companyName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _job!.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _job!.companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Job Info Cards
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.location_on,
                    label: 'Location',
                    value: _job!.location,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    icon: Icons.attach_money,
                    label: 'Salary',
                    value: _job!.salaryRange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.groups,
                    label: 'Needed',
                    value: '${_job!.requiredApplicants} applicants',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.work,
                    label: 'Type',
                    value: _getTypeLabel(_job!.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    icon: Icons.access_time,
                    label: 'Deadline',
                    value: _formatDeadline(_job!.applicationDeadline),
                    valueColor: isClosed
                        ? Colors.grey
                        : daysLeft <= 3
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Description
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _job!.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Required Skills
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Required Skills',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _job!.requiredSkills.map((skill) {
                      return Chip(
                        label: Text(skill['name']),
                        backgroundColor: Colors.blue.shade50,
                        labelStyle: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 13,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isApplying || isClosed ? null : _applyForJob,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: isClosed
                      ? Colors.grey.shade400
                      : Colors.blue.shade700,
                ),
                child: _isApplying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isClosed ? 'APPLICATIONS CLOSED' : 'APPLY NOW',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
