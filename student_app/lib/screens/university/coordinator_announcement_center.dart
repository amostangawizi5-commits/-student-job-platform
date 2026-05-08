import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';

import '../../services/coordinator_workspace_service.dart';

class CoordinatorAnnouncementCenter extends StatefulWidget {
  const CoordinatorAnnouncementCenter({
    super.key,
    required this.universityId,
    required this.universityName,
    required this.coordinatorName,
  });

  final String universityId;
  final String universityName;
  final String coordinatorName;

  @override
  State<CoordinatorAnnouncementCenter> createState() =>
      _CoordinatorAnnouncementCenterState();
}

class _CoordinatorAnnouncementCenterState
    extends State<CoordinatorAnnouncementCenter> {
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  String _audience = 'students';
  List<Map<String, dynamic>> _announcements = const [];

  @override
  void initState() {
    super.initState();
    _loadAnnouncements();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadAnnouncements() async {
    setState(() => _isLoading = true);
    final announcements = await _workspaceService.getAnnouncements(
      universityId: widget.universityId,
      universityName: widget.universityName,
    );
    if (!mounted) return;
    setState(() {
      _announcements = announcements;
      _isLoading = false;
    });
  }

  Future<void> _submitAnnouncement() async {
    final title = _titleController.text.trim();
    final message = _messageController.text.trim();
    if (title.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(
          content: Text('Write both title and message before posting.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    await _workspaceService.createAnnouncement(
      title: title,
      message: message,
      audience: _audience,
      universityId: widget.universityId,
      universityName: widget.universityName,
      coordinatorName: widget.coordinatorName,
    );
    await _loadAnnouncements();

    if (!mounted) return;
    _titleController.clear();
    _messageController.clear();
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(
        content: Text('Announcement posted successfully.'),
        backgroundColor: Color(0xFF0F766E),
      ),
    );
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

  Color _audienceColor(String value) {
    switch (value) {
      case 'students':
        return const Color(0xFF103B63);
      case 'companies':
        return const Color(0xFF0F766E);
      default:
        return const Color(0xFFD4A017);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FBFE),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFD9E6F2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Post a coordinator announcement',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17324D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '',
                style: TextStyle(color: Color(0xFF5F7288), height: 1.4),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Announcement title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _messageController,
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment<String>(
                    value: 'students',
                    label: Text('Students'),
                    icon: Icon(Icons.school_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'companies',
                    label: Text('Companies'),
                    icon: Icon(Icons.apartment_rounded),
                  ),
                  ButtonSegment<String>(
                    value: 'all',
                    label: Text('Both'),
                    icon: Icon(Icons.campaign_rounded),
                  ),
                ],
                selected: {_audience},
                onSelectionChanged: (selection) {
                  setState(() => _audience = selection.first);
                },
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitAnnouncement,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF103B63),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                  ),
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _isSubmitting ? 'Posting...' : 'Post announcement',
                  ),
                ),
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
        else if (_announcements.isEmpty)
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
                  Icons.campaign_outlined,
                  size: 42,
                  color: Color(0xFF5F7288),
                ),
                SizedBox(height: 10),
                Text(
                  'No coordinator announcements yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF17324D),
                  ),
                ),
                SizedBox(height: 6),
               
              ],
            ),
          )
        else
          Column(
            children: _announcements
                .map((announcement) {
                  final audience = '${announcement['audience'] ?? 'all'}';
                  final audienceColor = _audienceColor(audience);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFD9E6F2)),
                      boxShadow: [
                        BoxShadow(
                          color: audienceColor.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDate('${announcement['created_at'] ?? ''}'),
                          style: const TextStyle(color: Color(0xFF5F7288)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${announcement['title'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17324D),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${announcement['message'] ?? ''}',
                          style: const TextStyle(
                            color: Color(0xFF36495E),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Posted by ${announcement['coordinator_name'] ?? widget.coordinatorName}',
                          style: const TextStyle(
                            color: Color(0xFF5F7288),
                            fontSize: 12,
                          ),
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
