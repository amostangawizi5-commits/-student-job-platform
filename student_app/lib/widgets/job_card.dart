// lib/widgets/job_card.dart
import 'package:flutter/material.dart';

import '../models/job.dart';
import '../utils/theme.dart';

class JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onViewDetails;
  final VoidCallback? onApplyNow;

  const JobCard({
    super.key,
    required this.job,
    required this.onViewDetails,
    this.onApplyNow,
  });

  String _getTypeLabel(String type) => 'Industrial Practical Training';

  String _formatDeadline(DateTime deadline) {
    final day = deadline.day.toString().padLeft(2, '0');
    final month = deadline.month.toString().padLeft(2, '0');
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$day/$month/${deadline.year} $hour:$minute';
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final difference = job.applicationDeadline.difference(now);
    final daysLeft = difference.inDays;
    final isExpired = difference.isNegative;
    final isClosed = job.status != 'open' || isExpired;
    final descriptionPreview = job.description.trim().isEmpty
        ? 'No description provided.'
        : job.description.trim().replaceAll(RegExp(r'\s+'), ' ');
    final deadlineLabel = isClosed
        ? 'Closed'
        : daysLeft > 0
        ? '$daysLeft days left'
        : 'Closes today';
    final primaryActionLabel = isClosed ? 'View Details' : 'Apply Now';
    final primaryAction = isClosed
        ? onViewDetails
        : (onApplyNow ?? onViewDetails);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderGrey.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      job.companyName.isEmpty
                          ? '?'
                          : job.companyName[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.primaryBlue,
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.companyName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isClosed
                        ? Colors.grey.shade100
                        : const Color(0xFFE9F7EF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    isClosed ? 'History' : 'Open',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isClosed
                          ? Colors.grey.shade700
                          : const Color(0xFF15803D),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F7FC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getTypeLabel(job.type),
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              descriptionPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _buildMetaChip(
                  icon: Icons.location_on_outlined,
                  label: job.location,
                  color: const Color(0xFF2563EB),
                ),
                _buildMetaChip(
                  icon: Icons.groups_rounded,
                  label: 'Needed: ${job.requiredApplicants}',
                  color: const Color(0xFF0F766E),
                ),
                _buildMetaChip(
                  icon: Icons.schedule_rounded,
                  label: deadlineLabel,
                  color: isClosed
                      ? const Color(0xFF6B7280)
                      : daysLeft > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFFDC2626),
                ),
              ],
            ),
            if (job.requiredSkills.isNotEmpty) ...[
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: job.requiredSkills.take(3).map((skill) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${skill['name']}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              'Deadline: ${_formatDeadline(job.applicationDeadline)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: onViewDetails,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Details',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: primaryAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isClosed
                        ? const Color(0xFF475569)
                        : AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    primaryActionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
