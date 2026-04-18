import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../services/coordinator_workspace_service.dart';

class CompanyNotificationsScreen extends StatefulWidget {
  const CompanyNotificationsScreen({super.key});

  @override
  State<CompanyNotificationsScreen> createState() =>
      _CompanyNotificationsScreenState();
}

class _CompanyNotificationsScreenState
    extends State<CompanyNotificationsScreen> {
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
    final companyData = currentUser?['company_data'] as Map<String, dynamic>?;
    final companyName = companyData?['company_name']?.toString();

    try {
      final response = await _apiService.getNotifications();
      final localNotifications = await _workspaceService
          .getNotificationsForRole(role: 'company', companyName: companyName);

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
          .getNotificationsForRole(role: 'company', companyName: companyName);
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
    } catch (_) {}
  }

  Future<void> _markAllAsRead() async {
    final currentUser = context.read<AuthProvider>().user;
    final companyData = currentUser?['company_data'] as Map<String, dynamic>?;
    final companyName = companyData?['company_name']?.toString();
    try {
      await _apiService.markAllNotificationsRead();
      await _workspaceService.markAllNotificationsReadForRole(
        role: 'company',
        companyName: companyName,
      );
      _loadNotifications();
    } catch (_) {}
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'coordinator_announcement':
        return Icons.campaign_rounded;
      case 'student_company_confirmed':
        return Icons.approval_rounded;
      case 'student_confirmed_other_company':
        return Icons.person_off_outlined;
      case 'university_approval_approved':
        return Icons.verified_rounded;
      case 'university_approval_rejected':
        return Icons.report_gmailerrorred_rounded;
      case 'application':
        return Icons.person_add_alt_1;
      case 'shortlisted':
        return Icons.star;
      case 'interview':
        return Icons.calendar_today;
      case 'accepted':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      default:
        return Icons.notifications;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'coordinator_announcement':
        return const Color(0xFF103B63);
      case 'student_company_confirmed':
        return Colors.teal;
      case 'student_confirmed_other_company':
        return const Color(0xFFB42318);
      case 'university_approval_approved':
        return Colors.green;
      case 'university_approval_rejected':
        return Colors.red;
      case 'application':
        return Colors.blue;
      case 'shortlisted':
        return Colors.indigo;
      case 'interview':
        return Colors.purple;
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _cleanNotificationMessage(String? message) {
    if (message == null || message.isEmpty) return '';
    return message.replaceAll('**', '').trim();
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
                final n = _notifications[index];
                final type = '${n['type'] ?? ''}';
                final isRead = n['is_read'] == true;
                final color = _typeColor(type);
                final message = _cleanNotificationMessage(
                  n['message']?.toString(),
                );

                return GestureDetector(
                  onTap: () => _markAsRead(Map<String, dynamic>.from(n as Map)),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isRead
                          ? Colors.white
                          : color.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isRead
                            ? Colors.grey.shade200
                            : color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(_typeIcon(type), color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${n['title'] ?? 'Notification'}',
                                style: TextStyle(
                                  fontWeight: isRead
                                      ? FontWeight.w500
                                      : FontWeight.w700,
                                  fontSize: 14,
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
                                _formatDate(n['created_at']?.toString()),
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
                            decoration: const BoxDecoration(
                              color: Colors.blue,
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
