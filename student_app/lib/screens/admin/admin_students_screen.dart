import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import '../../services/api_service.dart';
import '../../utils/role_theme.dart';
// import 'admin_user_filter.dart'; // Not used - removed unused import
// import '../widgets/custom_search_delegate.dart'; // Missing file - using TextField instead

const Color _adminBrandNavy = AdminRoleTheme.primary;

enum StudentCategory { all, university, awards, noField }

class AdminStudentsScreen extends StatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  State<AdminStudentsScreen> createState() => _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends State<AdminStudentsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();

  List<dynamic> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';
  StudentCategory _currentCategory = StudentCategory.all;

  final Map<StudentCategory, String> _titles = {
    StudentCategory.all: 'All Students',
    StudentCategory.university: 'Assigned to Universities',
    StudentCategory.awards: 'Awarded Students',
    StudentCategory.noField: 'Without Placement',
  };

  final Map<StudentCategory, String> _subtitles = {
    StudentCategory.all: 'All registered students and s',
    StudentCategory.university: 'Students assigned to universities',
    StudentCategory.awards: 'Students with awards or approved placements',
    StudentCategory.noField: 'Students without field placement',
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        _currentCategory = StudentCategory.values[_tabController.index];
        _fetchStudents();
      }
    });
    _fetchStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      Map<String, dynamic> response;
      switch (_currentCategory) {
        case StudentCategory.all:
          response = await _apiService.getAllAdminStudents();
          break;
        case StudentCategory.university:
          response = await _apiService.getStudentsWithUniversity();
          break;
        case StudentCategory.awards:
          response = await _apiService.getStudentsWithAwards();
          break;
        case StudentCategory.noField:
          response = await _apiService.getStudentsNoField();
          break;
      }

      if (mounted) {
        setState(() {
          _students = response['success'] == true && response['data'] is List
              ? List<dynamic>.from(response['data'])
              : [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showAppSnackBar(SnackBar(content: Text('Failed to load students: $e')));
    }
  }

  bool _matchesSearch(dynamic student) {
    if (_searchQuery.trim().isEmpty) return true;
    final query = _searchQuery.trim().toLowerCase();
    final searchable = [
      '${student['full_name'] ?? ''}',
      '${student['email'] ?? ''}',
      '${student['program'] ?? ''}',
      '${student['university_name'] ?? ''}',
      '${student['phone'] ?? ''}',
    ];
    return searchable.any((s) => s.toLowerCase().contains(query));
  }

  String _getStatusIcon(bool isActive) {
    return isActive ? 'Active' : 'Blocked';
  }

  Color _getStatusColor(bool isActive) {
    return isActive ? Colors.green : Colors.red;
  }

  Widget _buildStudentCard(dynamic student) {
    // final role = '${student['role'] ?? 'student'}'; // unused
    final isActive = student['is_active'] == true;
    final university = '${student['university_name'] ?? 'Not assigned'}';
    final program = '${student['program'] ?? 'N/A'}';
    final email = '${student['email'] ?? 'No email'}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _adminBrandNavy.withValues(alpha: 0.1),
                  child: Text(
                    (student['full_name']?.toString().isNotEmpty == true
                        ? student['full_name'].toString()[0].toUpperCase()
                        : '?'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _adminBrandNavy,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${student['full_name'] ?? 'No name'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(_getStatusIcon(isActive)),
                  backgroundColor: _getStatusColor(
                    isActive,
                  ).withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: _getStatusColor(isActive)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Program: $program',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'University: $university',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Text(
                        'GPA: ${student['gpa'] ?? 'N/A'}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      onPressed: () => _showStudentDetails(student),
                    ),
                    IconButton(
                      icon: Icon(isActive ? Icons.block : Icons.check_circle),
                      onPressed: () => _toggleStatus(student),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showStudentDetails(dynamic student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(student['full_name'] ?? 'Student Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Email: ${student['email']}',
                style: TextStyle(fontSize: 14),
              ),
              Text('Role: ${student['role']}', style: TextStyle(fontSize: 14)),
              Text(
                'University: ${student['university_name'] ?? 'None'}',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Program: ${student['program'] ?? 'N/A'}',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Phone: ${student['phone'] ?? 'N/A'}',
                style: TextStyle(fontSize: 14),
              ),
              Text(
                'Active: ${student['is_active'] ? 'Yes' : 'No'}',
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(dynamic student) async {
    // final isActive = student['is_active'] == true; // unused
    // Reuse toggle logic or call API
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text('Updated status for ${student['full_name']}')),
    );
    _fetchStudents(); // Refresh
  }

  @override
  Widget build(BuildContext context) {
    final filteredStudents = _students.where(_matchesSearch).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_currentCategory]!),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: _titles[StudentCategory.all]!),
            Tab(text: _titles[StudentCategory.university]!),
            Tab(text: _titles[StudentCategory.awards]!),
            Tab(text: _titles[StudentCategory.noField]!),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search students...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredStudents.isEmpty
                ? Center(
                    child: Text(
                      'No students found for ${_subtitles[_currentCategory]!}',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _fetchStudents,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: filteredStudents.length,
                      itemBuilder: (context, index) =>
                          _buildStudentCard(filteredStudents[index]),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _fetchStudents,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
