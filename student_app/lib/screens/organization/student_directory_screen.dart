import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../utils/role_theme.dart';

class StudentDirectoryScreen extends StatefulWidget {
  const StudentDirectoryScreen({super.key});

  @override
  State<StudentDirectoryScreen> createState() => _StudentDirectoryScreenState();
}

class _StudentDirectoryScreenState extends State<StudentDirectoryScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _skillController = TextEditingController();
  List<Map<String, dynamic>> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _skillController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final response = await _apiService.getStudentDirectory(
      search: _searchController.text,
      skill: _skillController.text,
    );
    if (!mounted) return;
    final data = response['data'];
    setState(() {
      _isLoading = false;
      _error = response['success'] == true ? null : response['message']?.toString();
      _students = data is List
          ? data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList()
          : [];
    });
  }

  String _text(dynamic value, [String fallback = 'Not specified']) {
    final text = '${value ?? ''}'.trim();
    return text.isEmpty || text == 'null' ? fallback : text;
  }

  List<dynamic> _list(dynamic value) => value is List ? value : const [];

  void _showStudent(Map<String, dynamic> student) {
    final skills = _list(student['skills']);
    final projects = _list(student['projects']);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_text(student['full_name'])),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_text(student['headline'], _text(student['desired_role']))),
                const SizedBox(height: 8),
                Text('${_text(student['program'])} • ${_text(student['university_name'])}'),
                if (_text(student['about'], '').isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_text(student['about'], '')),
                ],
                if (skills.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Skills', style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 6,
                    children: skills.map((skill) {
                      final item = skill is Map ? skill : <String, dynamic>{};
                      return Chip(label: Text(_text(item['name'])));
                    }).toList(),
                  ),
                ],
                if (projects.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('Portfolio projects: ${projects.length}'),
                ],
                const SizedBox(height: 16),
                Text('Contact: ${_text(student['email'])}'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  Widget _studentCard(Map<String, dynamic> student) {
    final skills = _list(student['skills']);
    final name = _text(student['full_name']);
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showStudent(student),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: OrganizationRoleTheme.primary.withValues(alpha: .12),
                    child: Text(
                      name.substring(0, name.length > 1 ? 2 : 1).toUpperCase(),
                      style: const TextStyle(color: OrganizationRoleTheme.primary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(_text(student['headline'], _text(student['desired_role']))),
              const SizedBox(height: 6),
              Text(_text(student['program']), style: TextStyle(color: Colors.grey.shade700)),
              Text(_text(student['university_name']), style: TextStyle(color: Colors.grey.shade700)),
              if (skills.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: skills.take(4).map((skill) {
                    final item = skill is Map ? skill : <String, dynamic>{};
                    return Chip(
                      label: Text(_text(item['name'])),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Student Directory'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadStudents,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Discover students who have chosen to advertise their skills and projects.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _loadStudents(),
                    decoration: const InputDecoration(
                      labelText: 'Search students',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _skillController,
                    onSubmitted: (_) => _loadStudents(),
                    decoration: const InputDecoration(
                      labelText: 'Skill filter',
                      prefixIcon: Icon(Icons.auto_awesome_outlined),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loadStudents,
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_isLoading)
              const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Center(child: Text(_error!))
            else if (_students.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No public student profiles found.'),
                ),
              )
            else
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 1000
                      ? 3
                      : constraints.maxWidth >= 650
                          ? 2
                          : 1;
                  final width = (constraints.maxWidth - ((columns - 1) * 14)) / columns;
                  return Wrap(
                    spacing: 14,
                    runSpacing: 14,
                    children: _students
                        .map((student) => SizedBox(width: width, child: _studentCard(student)))
                        .toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
