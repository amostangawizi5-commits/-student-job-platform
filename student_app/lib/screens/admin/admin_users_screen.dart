import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import '../../services/api_service.dart';
import 'admin_export_utils.dart';
import 'admin_user_filter.dart';

class AdminUsersScreen extends StatefulWidget {
  final AdminUserFilter selectedFilter;
  final VoidCallback? onUserDataChanged;

  const AdminUsersScreen({
    super.key,
    this.selectedFilter = AdminUserFilter.all,
    this.onUserDataChanged,
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

  String _normalizedRole(dynamic user) {
    return '${user['role'] ?? ''}'.trim().toLowerCase();
  }

  bool _isUserBlocked(dynamic user) {
    final raw = user['is_active'];
    if (raw is bool) return raw == false;
    final normalized = '$raw'.trim().toLowerCase();
    return normalized == 'false' ||
        normalized == '0' ||
        normalized == 'blocked';
  }

  bool _matchesFilter(dynamic user) {
    final role = _normalizedRole(user);
    final isBlocked = _isUserBlocked(user);
    final isActive = !isBlocked;

    switch (_activeFilter) {
      case AdminUserFilter.active:
        return isActive;
      case AdminUserFilter.blocked:
        return isBlocked;
      case AdminUserFilter.registeredUsers:
        return role == 'student' || role == '';
      case AdminUserFilter.companies:
        return role == 'company';
      case AdminUserFilter.universities:
        return role == 'university';
      case AdminUserFilter.admins:
        return role == 'admin';
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
      case '':
        return 'User';
      case 'student':
        return 'User';
      case 'company':
        return 'Company';
      case 'university':
        return 'University';
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
      case 'university':
        return const Color(0xFF0E3A5D);
      case 'admin':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF059669);
    }
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
  }

  Future<void> _changeRole(dynamic user) async {
    const roleOptions = <String>['student', 'company', 'university', 'admin'];

    String selectedRole = '${user['role'] ?? 'student'}'.trim().toLowerCase();
    if (selectedRole.isEmpty || !roleOptions.contains(selectedRole)) {
      selectedRole = 'student';
    }

    final studentUniversityController = TextEditingController(
      text: '${user['university_id'] ?? ''}',
    );
    final studentProgramController = TextEditingController(
      text: '${user['program'] ?? ''}',
    );
    final studentRegistrationController = TextEditingController(
      text: '${user['registration_number'] ?? ''}',
    );
    final companyNameController = TextEditingController(
      text: '${user['company_name'] ?? user['full_name'] ?? ''}',
    );
    final companyIndustryController = TextEditingController(
      text: '${user['industry'] ?? ''}',
    );
    final companyLocationController = TextEditingController(
      text: '${user['location'] ?? ''}',
    );
    final universityNameController = TextEditingController(
      text: '${user['college_name'] ?? user['university_name'] ?? ''}',
    );
    final coordinatorNameController = TextEditingController(
      text: '${user['coordinator_name'] ?? user['full_name'] ?? ''}',
    );
    final coordinatorPhoneController = TextEditingController(
      text: '${user['coordinator_phone'] ?? user['phone'] ?? ''}',
    );
    final coordinatorEmailController = TextEditingController(
      text: '${user['coordinator_email'] ?? user['email'] ?? ''}',
    );

    Map<String, dynamic>? rolePayload;

    Map<String, dynamic> compactPayload(Map<String, dynamic> values) {
      return Map<String, dynamic>.fromEntries(
        values.entries.where((entry) => '${entry.value}'.trim().isNotEmpty),
      );
    }

    Widget buildField(
      TextEditingController controller,
      String label, {
      TextInputType keyboardType = TextInputType.text,
    }) {
      return Padding(
        padding: const EdgeInsets.only(top: 10),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
    }

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Role management'),
            content: SingleChildScrollView(
              child: Column(
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
                      DropdownMenuItem(
                        value: 'company',
                        child: Text('Company'),
                      ),
                      DropdownMenuItem(
                        value: 'university',
                        child: Text('University / Coordinator'),
                      ),
                      DropdownMenuItem(value: 'admin', child: Text('Admin')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => selectedRole = value);
                      }
                    },
                  ),
                  if (selectedRole == 'student') ...[
                    buildField(studentUniversityController, 'University ID'),
                    buildField(studentProgramController, 'Program'),
                    buildField(
                      studentRegistrationController,
                      'Registration number',
                    ),
                  ] else if (selectedRole == 'company') ...[
                    buildField(companyNameController, 'Company name'),
                    buildField(companyIndustryController, 'Industry'),
                    buildField(companyLocationController, 'Location'),
                  ] else if (selectedRole == 'university') ...[
                    buildField(
                      universityNameController,
                      'University / college name',
                    ),
                    buildField(coordinatorNameController, 'Coordinator name'),
                    buildField(
                      coordinatorPhoneController,
                      'Coordinator phone',
                      keyboardType: TextInputType.phone,
                    ),
                    buildField(
                      coordinatorEmailController,
                      'Coordinator email',
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ],
                ],
              ),
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

      rolePayload = switch (selectedRole) {
        'student' => compactPayload({
          'university_id': studentUniversityController.text,
          'program': studentProgramController.text,
          'registration_number': studentRegistrationController.text,
        }),
        'company' => compactPayload({
          'company_name': companyNameController.text,
          'industry': companyIndustryController.text,
          'location': companyLocationController.text,
        }),
        'university' => compactPayload({
          'college_name': universityNameController.text,
          'coordinator_name': coordinatorNameController.text,
          'coordinator_phone': coordinatorPhoneController.text,
          'coordinator_email': coordinatorEmailController.text,
          'college_email': coordinatorEmailController.text,
          'college_phone': coordinatorPhoneController.text,
        }),
        _ => null,
      };
    } finally {
      studentUniversityController.dispose();
      studentProgramController.dispose();
      studentRegistrationController.dispose();
      companyNameController.dispose();
      companyIndustryController.dispose();
      companyLocationController.dispose();
      universityNameController.dispose();
      coordinatorNameController.dispose();
      coordinatorPhoneController.dispose();
      coordinatorEmailController.dispose();
    }

    final response = await _apiService.updateUserRole(
      '${user['user_id']}',
      selectedRole,
      studentData: selectedRole == 'student' ? rolePayload : null,
      companyData: selectedRole == 'company' ? rolePayload : null,
      universityData: selectedRole == 'university' ? rolePayload : null,
    );
    if (!mounted) return;

    if (response['success'] == true) {
      await _fetchUsers();
      widget.onUserDataChanged?.call();
      _showMessage(
        response['message']?.toString() ?? 'Role updated successfully',
        backgroundColor: Colors.green,
      );
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
      widget.onUserDataChanged?.call();
      _showMessage(
        currentStatus
            ? 'User blocked successfully'
            : 'User unblocked successfully',
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
      widget.onUserDataChanged?.call();
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
        'Password reset link sent successfully.',
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
          _isUserBlocked(user) ? 'Blocked' : 'Active',
          '${user['phone'] ?? ''}',
        ];
      }).toList(),
    );
  }

  Future<void> _showUserDetails(dynamic user) async {
    final role = '${user['role'] ?? ''}';
    final isActive = !_isUserBlocked(user);

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

  Widget _buildSummaryFilterCard({
    required String title,
    required String value,
    required Color color,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: selected
                  ? color.withValues(alpha: 0.16)
                  : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.7)
                    : color.withValues(alpha: 0.18),
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final role = _normalizedRole(user).isEmpty
        ? 'student'
        : _normalizedRole(user);
    final isActive = !_isUserBlocked(user);
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
    final activeCount = _users.where((user) => !_isUserBlocked(user)).length;
    final blockedCount = _users.where(_isUserBlocked).length;

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
              _buildSummaryFilterCard(
                title: 'All users',
                value: '${_users.length}',
                color: const Color(0xFF2563EB),
                selected: _activeFilter == AdminUserFilter.all,
                onTap: () =>
                    setState(() => _activeFilter = AdminUserFilter.all),
              ),
              const SizedBox(width: 12),
              _buildSummaryFilterCard(
                title: 'Active',
                value: '$activeCount',
                color: const Color(0xFF059669),
                selected: _activeFilter == AdminUserFilter.active,
                onTap: () =>
                    setState(() => _activeFilter = AdminUserFilter.active),
              ),
              const SizedBox(width: 12),
              _buildSummaryFilterCard(
                title: 'Blocked',
                value: '$blockedCount',
                color: Colors.red,
                selected: _activeFilter == AdminUserFilter.blocked,
                onTap: () =>
                    setState(() => _activeFilter = AdminUserFilter.blocked),
              ),
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
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        AdminUserFilter.registeredUsers,
                        'Students',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(AdminUserFilter.companies, 'Companies'),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        AdminUserFilter.universities,
                        'Universities',
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(AdminUserFilter.admins, 'Admins'),
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
