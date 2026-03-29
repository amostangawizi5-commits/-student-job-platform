// lib/widgets/job_card.dart
import 'package:flutter/material.dart';
import '../models/job.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;

  const JobCard({super.key, required this.job, required this.onTap});

  String _getTypeIcon(String type) {
    switch (type) {
      case 'internship':
        return '🎓';
      case 'full-time':
        return '💼';
      case 'part-time':
        return '⏰';
      case 'graduate_program':
        return '🚀';
      default:
        return '📋';
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
    final now = DateTime.now();
    final difference = job.applicationDeadline.difference(now);
    final daysLeft = difference.inDays;
    final isExpired = difference.isNegative;
    final isClosed = job.status != 'open' || isExpired;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  // Logo placeholder
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        job.companyName[0].toUpperCase(),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          job.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          job.companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _getTypeIcon(job.type),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getTypeLabel(job.type),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? Colors.grey.shade200
                              : Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isClosed ? 'History' : 'Open',
                          style: TextStyle(
                            fontSize: 11,
                            color: isClosed
                                ? Colors.grey.shade700
                                : Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Location and Salary
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      job.location,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.attach_money,
                    size: 16,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    job.salaryRange,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green.shade600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.groups, size: 16, color: Colors.blueGrey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    'Needed: ${job.requiredApplicants}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Skills
              if (job.requiredSkills.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: job.requiredSkills.take(3).map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        skill['name'],
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (job.requiredSkills.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '+${job.requiredSkills.length - 3} more',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
              // Deadline
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: Colors.orange.shade600,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isClosed
                            ? 'Closed'
                            : daysLeft > 0
                            ? '$daysLeft days remaining'
                            : 'Closes today',
                        style: TextStyle(
                          fontSize: 12,
                          color: isClosed
                              ? Colors.grey.shade600
                              : daysLeft > 0
                              ? Colors.orange.shade600
                              : Colors.red.shade400,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Text(
                      _formatDeadline(job.applicationDeadline),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Colors.grey,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
