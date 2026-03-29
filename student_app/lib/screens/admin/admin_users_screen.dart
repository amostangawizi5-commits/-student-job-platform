import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'admin_export_utils.dart';
import 'admin_user_filter.dart';

class AdminUsersScreen extends StatefulWidget {
  final AdminUserFilter selectedFilter;

  const AdminUsersScreen({
    super.key,
    this.selectedFilter = AdminUserFilter.all,
  });

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  late AdminUserFilter _activeFilter;
  final TextEditingController _searchController = TextEditingController();
  final ApiService _apiService = ApiService();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _activeFilter = widget.selectedFilter;
    _fetchUsers();
  }

  @override
  void didUpdateWidget(covariant AdminUsersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFilter != widget.selectedFilter) {
      setState(() => _activeFilter = widget.selectedFilter);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await _apiService.getUsers();
      if (!mounted) return;

      setState(() {
        _users = response['success'] == true && response['data'] is List
            ? List<dynamic>.from(response['data'])
            : [];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Failed to load users: $e', backgroundColor: Colors.red);
    }
  }

  bool _matchesFilter(dynamic user) {
    final isActive = user['is_active'] == true;

    switch (_activeFilter) {
      case AdminUserFilter.active:
        return isActive;
      case AdminUserFilter.blocked:
        return !isActive;
      case AdminUserFilter.registeredUsers:
        final role = '${user['role'] ?? ''}';
        return role == 'student' || role == 'graduate';
      case AdminUserFilter.companies:
        return '${user['role'] ?? ''}' == 'company';
      case AdminUserFilter.all:
        return true;
    }
  }

  bool _matchesSearch(dynamic user) {
    if (_searchQuery.trim().isEmpty) return true;

    final query = _searchQuery.trim().toLowerCase();
    final searchableParts = [
      '${user['full_name'] ?? ''}',
      '${user['email'] ?? ''}',
      '${user['role'] ?? ''}',
      '${user['company_name'] ?? ''}',
      '${user['industry'] ?? ''}',
      '${user['location'] ?? ''}',
      '${user['program'] ?? ''}',
      '${user['university_name'] ?? ''}',
      '${user['phone'] ?? ''}',
    ];

    return searchableParts.any((value) => value.toLowerCase().contains(query));
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'graduate':
        return 'User';
      case 'student':
        return 'User';
      case 'company':
        return 'Company';
      case 'admin':
        return 'Admin';
      default:
        return role.isEmpty ? 'User' : role;
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'company':
        return const Color(0xFF2563EB);
      case 'admin':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF059669);
    }
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Future<void> _changeRole(dynamic user) async {
    String selectedRole = '${user['role'] ?? 'student'}';
    if (selectedRole == 'graduate') {
      selectedRole = 'student';
    }

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Role management'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${user['full_name'] ?? 'User'}'),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(labelText: 'Select role'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('User')),
                  DropdownMenuItem(value: 'company', child: Text('Company')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setDialogState(() => selectedRole = value);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final response = await _apiService.updateUserRole(
      '${user['user_id']}',
      selectedRole,
    );
    if (!mounted) return;

    if (response['success'] == true) {
      await _fetchUsers();
      _showMessage('Role updated successfully', backgroundColor: Colors.green);
    } else {
      _showMessage(
        response['message']?.toString() ?? 'Failed to update role',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _toggleUserStatus(dynamic user, bool currentStatus) async {
    final response = await _apiService.toggleUserStatus(
      '${user['user_id']}',
      !currentStatus,
    );
    if (!mounted) return;

    if (response['success'] == true) {
      await _fetchUsers();
      _showMessage(
        currentStatus ? 'User blocked successfully' : 'User unblocked successfully',
        backgroundColor: Colors.green,
      );
    } else {
      _showMessage(
        response['message']?.toString() ?? 'Failed to update status',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _deleteUser(dynamic user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete user'),
        content: Text(
          'Delete ${user['full_name'] ?? 'this user'}? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final response = await _apiService.deleteUser('${user['user_id']}');
    if (!mounted) return;

    if (response['success'] == true) {
      await _fetchUsers();
      _showMessage('User deleted successfully', backgroundColor: Colors.green);
    } else {
      _showMessage(
        response['message']?.toString() ?? 'Failed to delete user',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _showResetPasswordDialog(dynamic user) async {
    final response = await _apiService.sendUserPasswordResetLink(
      '${user['user_id']}',
    );
    if (!mounted) return;

    if (response['success'] == true) {
      _showMessage(
        response['message']?.toString() ?? 'Reset link sent successfully',
        backgroundColor: Colors.green,
      );
    } else {
      _showMessage(
        response['message']?.toString() ?? 'Failed to send reset link',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _exportUsers(List<dynamic> users) async {
    await AdminExportUtils.showExportDialog(
      context,
      title: 'users',
      filePrefix: 'users_export',
      headers: const ['Name', 'Email', 'Role', 'Status', 'Phone'],
      rows: users.map((user) {
        return [
          '${user['full_name'] ?? ''}',
          '${user['email'] ?? ''}',
          _roleLabel('${user['role'] ?? ''}'),
          user['is_active'] == true ? 'Active' : 'Blocked',
          '${user['phone'] ?? ''}',
        ];
      }).toList(),
    );
  }

  Future<void> _showUserDetails(dynamic user) async {
    final role = '${user['role'] ?? ''}';
    final isActive = user['is_active'] == true;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${user['full_name'] ?? 'User details'}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('${user['email'] ?? ''}'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text('Role: ${_roleLabel(role)}')),
                    Chip(label: Text(isActive ? 'Active' : 'Blocked')),
                  ],
                ),
                const SizedBox(height: 16),
                _DetailLine(label: 'Phone', value: '${user['phone'] ?? '-'}'),
                _DetailLine(
                  label: 'Company',
                  value: '${user['company_name'] ?? '-'}',
                ),
                _DetailLine(
                  label: 'Industry',
                  value: '${user['industry'] ?? '-'}',
                ),
                _DetailLine(
                  label: 'Location',
                  value: '${user['location'] ?? '-'}',
                ),
                _DetailLine(
                  label: 'Program',
                  value: '${user['program'] ?? '-'}',
                ),
                _DetailLine(
                  label: 'University',
                  value: '${user['university_name'] ?? '-'}',
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _changeRole(user);
                      },
                      icon: const Icon(Icons.swap_horiz_rounded),
                      label: const Text('Change role'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _toggleUserStatus(user, isActive);
                      },
                      icon: Icon(
                        isActive
                            ? Icons.block_rounded
                            : Icons.check_circle_rounded,
                      ),
                      label: Text(isActive ? 'Block' : 'Unblock'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _showResetPasswordDialog(user);
                      },
                      icon: const Icon(Icons.lock_reset_rounded),
                      label: const Text('Reset password'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _exportUsers([user]);
                      },
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Export'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        _deleteUser(user);
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(AdminUserFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _activeFilter == filter,
      onSelected: (_) => setState(() => _activeFilter = filter),
    );
  }

  Widget _buildSummaryCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(title, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final role = '${user['role'] ?? 'student'}';
    final isActive = user['is_active'] == true;
    final roleColor = _roleColor(role);
    final statusColor = isActive ? const Color(0xFF059669) : Colors.red;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showUserDetails(user),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: roleColor.withValues(alpha: 0.12),
                    foregroundColor: roleColor,
                    child: Text(_avatarLabel(user)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${user['full_name'] ?? 'No name'}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${user['email'] ?? ''}',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: roleColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                _roleLabel(role),
                                style: TextStyle(
                                  color: roleColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isActive ? 'Active' : 'Blocked',
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'export':
                          _exportUsers([user]);
                          break;
                        case 'reset':
                          _showResetPasswordDialog(user);
                          break;
                        case 'delete':
                          _deleteUser(user);
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(value: 'export', child: Text('Export')),
                      PopupMenuItem(
                        value: 'reset',
                        child: Text('Send reset link'),
                      ),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: () => _showUserDetails(user),
                    child: const Text('View details'),
                  ),
                  OutlinedButton(
                    onPressed: () => _changeRole(user),
                    child: const Text('Change role'),
                  ),
                  FilledButton.tonal(
                    onPressed: () => _toggleUserStatus(user, isActive),
                    child: Text(isActive ? 'Block' : 'Unblock'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _avatarLabel(dynamic user) {
    final name = '${user['full_name'] ?? ''}'.trim();
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _users
        .where(_matchesFilter)
        .where(_matchesSearch)
        .toList();
    final activeCount = _users.where((user) => user['is_active'] == true).length;
    final blockedCount =
        _users.where((user) => user['is_active'] != true).length;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchUsers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Row(
            children: [
              _buildSummaryCard('All users', '${_users.length}', const Color(0xFF2563EB)),
              const SizedBox(width: 12),
              _buildSummaryCard('Active', '$activeCount', const Color(0xFF059669)),
              const SizedBox(width: 12),
              _buildSummaryCard('Blocked', '$blockedCount', Colors.red),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search by name, email, role, company...',
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
                      _buildFilterChip(AdminUserFilter.all, 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip(AdminUserFilter.active, 'Active'),
                      const SizedBox(width: 8),
                      _buildFilterChip(AdminUserFilter.blocked, 'Blocked'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _exportUsers(filteredUsers),
                icon: const Icon(Icons.download_rounded, size: 18),
                label: const Text('Export'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (filteredUsers.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Text('No users match the current filters.'),
            )
          else
            ...filteredUsers.map(_buildUserCard),
        ],
      ),
    );
  }
}

class _DetailLine extends StatelessWidget {
  final String label;
  final String value;

  const _DetailLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(child: Text(value.isEmpty ? '-' : value)),
        ],
      ),
    );
  }
}
