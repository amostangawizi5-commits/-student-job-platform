import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/coordinator_workspace_service.dart';

class UniversityNotificationsScreen extends StatefulWidget {
  const UniversityNotificationsScreen({super.key});

  @override
  State<UniversityNotificationsScreen> createState() =>
      _UniversityNotificationsScreenState();
}

class _UniversityNotificationsScreenState
    extends State<UniversityNotificationsScreen> {
  final ApiService _apiService = ApiService();
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  List<dynamic> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final currentUser = context.read<AuthProvider>().user;
    final universityData =
        currentUser?['university_data'] as Map<String, dynamic>?;
    final universityId = universityData?['university_id']?.toString();
    final universityName = universityData?['college_name']?.toString();

    try {
      final response = await _apiService.getNotifications();
      final localNotifications = await _workspaceService
          .getNotificationsForRole(
            role: 'university',
            universityId: universityId,
            universityName: universityName,
          );
      final remoteNotifications =
          response['success'] == true && response['data'] is List
          ? List<Map<String, dynamic>>.from(
              (response['data'] as List).whereType<Map>().map(
                (item) => item.map((key, value) => MapEntry('$key', value)),
              ),
            )
          : <Map<String, dynamic>>[];
      final allNotifications = [
        ...localNotifications.map((item) => {...item, 'is_local': true}),
        ...remoteNotifications.map((item) => {...item, 'is_local': false}),
      ];
      allNotifications.sort((left, right) {
        final leftDate =
            DateTime.tryParse('${left['created_at'] ?? ''}') ?? DateTime(1970);
        final rightDate =
            DateTime.tryParse('${right['created_at'] ?? ''}') ?? DateTime(1970);
        return rightDate.compareTo(leftDate);
      });
      if (!mounted) return;
      setState(() {
        _notifications = allNotifications;
        _isLoading = false;
      });
    } catch (_) {
      final localNotifications = await _workspaceService
          .getNotificationsForRole(
            role: 'university',
            universityId: universityId,
            universityName: universityName,
          );
      if (!mounted) return;
      setState(() {
        _notifications = localNotifications
            .map((item) => {...item, 'is_local': true})
            .toList(growable: false);
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    final id = '${notification['notification_id'] ?? ''}';
    if (id.isEmpty) return;

    try {
      if (notification['is_local'] == true) {
        await _workspaceService.markNotificationRead(id);
      } else {
        await _apiService.markNotificationRead(id);
      }
      await _loadNotifications();
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final currentUser = context.read<AuthProvider>().user;
    final universityData =
        currentUser?['university_data'] as Map<String, dynamic>?;
    final universityId = universityData?['university_id']?.toString();
    final universityName = universityData?['college_name']?.toString();
    try {
      await _apiService.markAllNotificationsRead();
      await _workspaceService.markAllNotificationsReadForRole(
        role: 'university',
        universityId: universityId,
        universityName: universityName,
      );
      await _loadNotifications();
    } catch (_) {}
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'company_report':
        return Icons.report_problem_rounded;
      case 'application':
        return Icons.assignment_outlined;
      case 'accepted':
        return Icons.verified_outlined;
      case 'shortlisted':
        return Icons.star_outline_rounded;
      case 'interview':
        return Icons.event_available_outlined;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'company_report':
        return const Color(0xFFB42318);
      case 'application':
        return const Color(0xFF103B63);
      case 'accepted':
        return const Color(0xFF0F766E);
      case 'shortlisted':
        return const Color(0xFFD4A017);
      case 'interview':
        return const Color(0xFF7C3AED);
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 0) return '${diff.inDays} days ago';
      if (diff.inHours > 0) return '${diff.inHours} hours ago';
      if (diff.inMinutes > 0) return '${diff.inMinutes} minutes ago';
      return 'Just now';
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Text(
                'No notifications yet',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final type = '${notification['type'] ?? ''}';
                final isRead = notification['is_read'] == true;
                final color = _colorForType(type);
                final message = '${notification['message'] ?? ''}'
                    .replaceAll('**', '')
                    .trim();

                return GestureDetector(
                  onTap: () => _markAsRead(
                    Map<String, dynamic>.from(notification as Map),
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : color.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRead
                            ? Colors.grey.shade200
                            : color.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            _iconForType(type),
                            color: color,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${notification['title'] ?? 'Notification'}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                message,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatDate(
                                  notification['created_at']?.toString(),
                                ),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isRead)
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
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
