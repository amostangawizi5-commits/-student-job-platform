import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/coordinator_workspace_service.dart';
import '../../utils/theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
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
    final studentEmail = currentUser?['email']?.toString();
    final studentData = currentUser?['student_data'] as Map<String, dynamic>?;
    final universityId = studentData?['university_id']?.toString();
    final universityName = studentData?['university_name']?.toString();
    final institutionIds = _studentInstitutionIds(studentData);
    final institutionNames = _studentInstitutionNames(studentData);

    try {
      final response = await _apiService.getNotifications();
      final localNotifications = await _workspaceService
          .getNotificationsForRole(
            role: 'student',
            studentEmail: studentEmail,
            universityId: universityId,
            universityName: universityName,
            institutionIds: institutionIds,
            institutionNames: institutionNames,
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
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      final localNotifications = await _workspaceService
          .getNotificationsForRole(
            role: 'student',
            studentEmail: studentEmail,
            universityId: universityId,
            universityName: universityName,
            institutionIds: institutionIds,
            institutionNames: institutionNames,
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
      _loadNotifications();
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final currentUser = context.read<AuthProvider>().user;
    final studentEmail = currentUser?['email']?.toString();
    final studentData = currentUser?['student_data'] as Map<String, dynamic>?;
    final universityId = studentData?['university_id']?.toString();
    final universityName = studentData?['university_name']?.toString();
    final institutionIds = _studentInstitutionIds(studentData);
    final institutionNames = _studentInstitutionNames(studentData);
    try {
      await _apiService.markAllNotificationsRead();
      await _workspaceService.markAllNotificationsReadForRole(
        role: 'student',
        studentEmail: studentEmail,
        universityId: universityId,
        universityName: universityName,
        institutionIds: institutionIds,
        institutionNames: institutionNames,
      );
      _loadNotifications();
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    final notificationId = '${notification['notification_id'] ?? ''}';
    if (notificationId.isEmpty) return;

    try {
      if (notification['is_local'] == true) {
        await _workspaceService.deleteNotification(notificationId);
        if (!mounted) return;
        setState(() {
          _notifications.removeWhere(
            (item) => '${item['notification_id']}' == notificationId,
          );
        });
        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      final response = await _apiService.deleteNotification(notificationId);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _notifications.removeWhere(
            (item) => '${item['notification_id']}' == notificationId,
          );
        });

        ScaffoldMessenger.of(context).showAppSnackBar(
          const SnackBar(
            content: Text('Notification deleted'),
            backgroundColor: Colors.green,
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            response['message']?.toString() ?? 'Failed to delete notification',
          ),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Error deleting notification: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'coordinator_announcement':
        return Icons.campaign_rounded;
      case 'student_company_confirmed':
        return Icons.approval_rounded;
      case 'coordinator_manual_assignment':
        return Icons.assignment_turned_in_rounded;
      case 'university_approval_approved':
        return Icons.verified_rounded;
      case 'university_approval_rejected':
        return Icons.report_gmailerrorred_rounded;
      case 'shortlisted':
        return Icons.star;
      case '':
        return Icons.calendar_today;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'coordinator_announcement':
        return AppTheme.primaryBlue;
      case 'student_company_confirmed':
        return Colors.teal;
      case 'coordinator_manual_assignment':
        return Colors.indigo;
      case 'university_approval_approved':
        return AppTheme.primaryGreen;
      case 'university_approval_rejected':
        return Colors.red;
      case 'shortlisted':
        return Colors.blue;
      case '':
        return Colors.purple;
      case 'accepted':
        return AppTheme.primaryGreen;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }

  String? _extractDate(String? message) {
    if (message == null || message.isEmpty) return null;
    final match = RegExp(
      r' Date:\s*(.+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(message);
    if (match == null) return null;
    return match.group(1)?.trim();
  }

  String? _extractVenue(String? message) {
    if (message == null || message.isEmpty) return null;
    final match = RegExp(
      r' Venue:\s*(.+)',
      caseSensitive: false,
      multiLine: true,
    ).firstMatch(message);
    if (match == null) return null;
    return match.group(1)?.trim();
  }

  String _cleanNotificationMessage(String? message) {
    if (message == null) return '';
    return message
        .replaceAll('**', '')
        .replaceAll(RegExp(r' Date:\s*.+', multiLine: true), '')
        .replaceAll(RegExp(r' Venue:\s*.+', multiLine: true), '')
        .trim();
  }

  List<String> _studentInstitutionNames(Map<String, dynamic>? studentData) {
    final values = [
      studentData?['college_name'],
      studentData?['institution_name'],
      studentData?['university_name'],
    ];

    final seen = <String>{};
    final names = <String>[];
    for (final value in values) {
      final name = '${value ?? ''}'.trim();
      if (name.isEmpty) continue;
      final normalized = name.toLowerCase();
      if (!seen.add(normalized)) continue;
      names.add(name);
    }
    return names;
  }

  List<String> _studentInstitutionIds(Map<String, dynamic>? studentData) {
    final values = [studentData?['university_id']];

    final seen = <String>{};
    final ids = <String>[];
    for (final value in values) {
      final id = '${value ?? ''}'.trim();
      if (id.isEmpty) continue;
      final normalized = id.toLowerCase();
      if (!seen.add(normalized)) continue;
      ids.add(id);
    }
    return ids;
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
              child: Text(
                'Mark all read',
                style: TextStyle(color: AppTheme.primaryBlue),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No notifications yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'You will see updates here when companies review your applications',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _notifications.length,
              itemBuilder: (context, index) {
                final notification = _notifications[index];
                final isRead = notification['is_read'] ?? false;
                final type = notification['type'];
                final iconColor = _getColorForType(type);
                final rawMessage = '${notification['message'] ?? ''}';
                final scheduledDate = _extractDate(rawMessage);
                final scheduledVenue = _extractVenue(rawMessage);
                final message = scheduledDate == null
                    ? rawMessage
                    : _cleanNotificationMessage(rawMessage);

                return Dismissible(
                  key: ValueKey('${notification['notification_id']}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerRight,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  confirmDismiss: (_) async {
                    await _deleteNotification(notification);
                    return false;
                  },
                  child: GestureDetector(
                    onTap: () => _markAsRead(
                      Map<String, dynamic>.from(notification as Map),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: isRead
                            ? Colors.white
                            : AppTheme.primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isRead
                              ? Colors.grey.shade200
                              : AppTheme.primaryBlue.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _getIconForType(type),
                                color: iconColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    notification['title'],
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: isRead
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if (type == '' && scheduledDate != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.event,
                                            size: 14,
                                            color: Colors.black87,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              ' Date: $scheduledDate',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (type == '' && scheduledVenue != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.place,
                                            size: 14,
                                            color: Colors.black87,
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              ' Venue: $scheduledVenue',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.black87,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatDate(notification['created_at']),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              children: [
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert, size: 20),
                                  onSelected: (value) {
                                    if (value == 'delete') {
                                      _deleteNotification(notification);
                                    }
                                  },
                                  itemBuilder: (context) => const [
                                    PopupMenuItem<String>(
                                      value: 'delete',
                                      child: Text('Delete'),
                                    ),
                                  ],
                                ),
                                if (!isRead)
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryBlue,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
