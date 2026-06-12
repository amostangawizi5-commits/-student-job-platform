import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';

import '../../services/api_service.dart';
import '../../utils/role_theme.dart';

const Color _brandBlue = AdminRoleTheme.primary;
const Color _acceptedGreen = Color(0xFF16A34A);
const Color _shortlistedBlue = Color(0xFF2563EB);
const Color _rejectedRed = Color(0xFFDC2626);

class AdminTestManagementScreen extends StatefulWidget {
  const AdminTestManagementScreen({
    super.key,
    this.organizationMode = false,
    this.jobId,
    this.jobTitle,
    this.applicants,
  });

  final bool organizationMode;
  final String? jobId;
  final String? jobTitle;
  final List<dynamic>? applicants;

  @override
  State<AdminTestManagementScreen> createState() =>
      _AdminTestManagementScreenState();
}

class _AdminTestManagementScreenState extends State<AdminTestManagementScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _titleController = TextEditingController(
    text: 'Software Development Entrance Test',
  );
  final TextEditingController _durationController = TextEditingController(
    text: '60',
  );
  final TextEditingController _passMarkController = TextEditingController(
    text: '70',
  );
  final TextEditingController _deadlineController = TextEditingController();
  final TextEditingController _minimumScoreController = TextEditingController(
    text: '70',
  );
  final TextEditingController _topNController = TextEditingController(
    text: '5',
  );

  final List<_QuestionDraft> _questions = [_QuestionDraft.exampleShort()];
  final Set<String> _selectedStudentIds = {};
  List<dynamic> _students = [];
  List<dynamic> _tests = [];
  List<dynamic> _results = [];
  String? _selectedTestId;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isApplyingSelection = false;

  @override
  void initState() {
    super.initState();
    final defaultDeadline = DateTime.now().add(const Duration(days: 14));
    _deadlineController.text = _formatDate(defaultDeadline);
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _durationController.dispose();
    _passMarkController.dispose();
    _deadlineController.dispose();
    _minimumScoreController.dispose();
    _topNController.dispose();
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _studentId(dynamic student) {
    return '${student['student_id'] ?? student['user_id'] ?? student['id'] ?? ''}'
        .trim();
  }

  String _studentName(dynamic student) {
    return '${student['full_name'] ?? student['student_name'] ?? student['name'] ?? 'No name'}';
  }

  String _studentTraining(dynamic student) {
    return '${student['program'] ?? student['training_title'] ?? student['job_title'] ?? widget.jobTitle ?? 'No training'}';
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final responses = widget.organizationMode
        ? await Future.wait([
            _apiService.getOrganizationTests(jobId: widget.jobId),
            Future.value({
              'success': true,
              'data': widget.applicants ?? const <dynamic>[],
            }),
          ])
        : await Future.wait([
            _apiService.getAdminTests(),
            _apiService.getAllAdminStudents(),
          ]);
    if (!mounted) return;
    setState(() {
      _tests = responses[0]['success'] == true && responses[0]['data'] is List
          ? List<dynamic>.from(responses[0]['data'])
          : [];
      _students =
          responses[1]['success'] == true && responses[1]['data'] is List
          ? List<dynamic>.from(responses[1]['data'])
          : [];
      if (widget.organizationMode && _selectedStudentIds.isEmpty) {
        _selectedStudentIds.addAll(
          _students.map(_studentId).where((id) => id.isNotEmpty),
        );
      }
      _selectedTestId ??= _tests.isNotEmpty ? '${_tests.first['id']}' : null;
      _isLoading = false;
    });
    if (_selectedTestId != null) {
      await _loadResults(_selectedTestId!);
    }
  }

  Future<void> _loadResults(String testId) async {
    final response = widget.organizationMode
        ? await _apiService.getOrganizationTestResults(testId)
        : await _apiService.getTestResults(testId);
    if (!mounted) return;
    setState(() {
      _results = response['success'] == true && response['data'] is List
          ? List<dynamic>.from(response['data'])
          : [];
    });
  }

  Future<void> _pickDeadline() async {
    final initial =
        DateTime.tryParse(_deadlineController.text) ??
        DateTime.now().add(const Duration(days: 7));
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
      initialDate: initial,
    );
    if (picked != null) {
      setState(() => _deadlineController.text = _formatDate(picked));
    }
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'title': _titleController.text.trim(),
      'duration': int.tryParse(_durationController.text.trim()) ?? 0,
      'pass_mark': double.tryParse(_passMarkController.text.trim()) ?? 0,
      'deadline': _deadlineController.text.trim(),
      if (widget.organizationMode) 'job_id': widget.jobId,
      'questions': _questions.map((question) => question.toJson()).toList(),
    };
  }

  Future<String?> _saveTest() async {
    final invalidQuestion = _questions.indexWhere(
      (question) => !question.isValid,
    );
    if (invalidQuestion >= 0) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Complete question ${invalidQuestion + 1}.')),
      );
      return null;
    }

    setState(() => _isSaving = true);
    final response = widget.organizationMode
        ? await _apiService.createOrganizationTest(_buildPayload())
        : await _apiService.createAdminTest(_buildPayload());
    if (!mounted) return null;
    setState(() => _isSaving = false);

    if (response['success'] != true) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(ApiService.responseMessage(response))),
      );
      return null;
    }

    final testId = '${response['data']?['id'] ?? ''}';
    ScaffoldMessenger.of(context).showAppSnackBar(
      const SnackBar(content: Text('Test saved successfully.')),
    );
    await _loadData();
    if (testId.isNotEmpty) {
      setState(() => _selectedTestId = testId);
      await _loadResults(testId);
    }
    return testId.isEmpty ? null : testId;
  }

  Future<void> _publishAndInvite() async {
    final testId = await _saveTest();
    if (testId == null) return;
    if (_selectedStudentIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Select students before publishing.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final response = widget.organizationMode
        ? await _apiService.inviteStudentsToOrganizationTest(
            testId: testId,
            studentIds: _selectedStudentIds.toList(),
          )
        : await _apiService.inviteStudentsToTest(
            testId: testId,
            studentIds: _selectedStudentIds.toList(),
          );
    if (!mounted) return;
    setState(() => _isSaving = false);

    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(ApiService.responseMessage(response))),
    );
    await _loadResults(testId);
  }

  Future<void> _applyAutoSelection() async {
    final testId = _selectedTestId;
    if (testId == null) return;

    setState(() => _isApplyingSelection = true);
    final minimumScore =
        double.tryParse(_minimumScoreController.text.trim()) ?? 70;
    final topN = int.tryParse(_topNController.text.trim()) ?? 5;
    final response = widget.organizationMode
        ? await _apiService.applyOrganizationAutoSelection(
            testId: testId,
            minimumScore: minimumScore,
            topN: topN,
          )
        : await _apiService.applyAutoSelection(
            testId: testId,
            minimumScore: minimumScore,
            topN: topN,
          );
    if (!mounted) return;
    setState(() => _isApplyingSelection = false);

    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(ApiService.responseMessage(response))),
    );
    await _loadResults(testId);
  }

  Future<void> _openAttemptAnswers(dynamic result) async {
    final attemptId = '${result['attempt_id'] ?? ''}';
    if (attemptId.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (_) => _AttemptAnswersDialog(
        apiService: _apiService,
        organizationMode: widget.organizationMode,
        attemptId: attemptId,
        studentName: '${result['student_name'] ?? 'Student'}',
      ),
    );
    if (_selectedTestId != null) {
      await _loadResults(_selectedTestId!);
    }
  }

  void _addQuestion() {
    setState(() => _questions.add(_QuestionDraft()));
  }

  void _removeQuestion(int index) {
    if (_questions.length == 1) return;
    final removed = _questions.removeAt(index);
    removed.dispose();
    setState(() {});
  }

  Color _selectionColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'selected':
        return _acceptedGreen;
      case 'shortlisted':
        return _shortlistedBlue;
      case 'rejected':
      case 'not_selected':
        return _rejectedRed;
      default:
        return Colors.grey.shade700;
    }
  }

  String _selectionLabel(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
      case 'shortlisted':
      case 'selected':
        return 'Selected';
      case 'rejected':
      case 'not_selected':
        return 'Not selected';
      default:
        return 'Pending';
    }
  }

  Future<Map<String, String>?> _collectReportingDates() async {
    final now = DateTime.now();
    final startDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 3),
      helpText: 'Select reporting start date',
    );
    if (startDate == null || !mounted) return null;

    final endDate = await showDatePicker(
      context: context,
      initialDate: startDate.add(const Duration(days: 1)),
      firstDate: startDate,
      lastDate: DateTime(now.year + 3),
      helpText: 'Select reporting end date',
    );
    if (endDate == null) return null;

    return {
      'reporting_start_date': _formatDate(startDate),
      'reporting_end_date': _formatDate(endDate),
    };
  }

  String _applicationIdForResult(dynamic result) {
    final fromResult = '${result['application_id'] ?? ''}'.trim();
    if (fromResult.isNotEmpty) return fromResult;

    final studentId = '${result['student_id'] ?? ''}'.trim();
    if (studentId.isEmpty) return '';
    for (final student in _students) {
      if (_studentId(student) == studentId) {
        return '${student['application_id'] ?? ''}'.trim();
      }
    }
    return '';
  }

  Future<void> _acceptSelectedApplicant(dynamic result) async {
    final applicationId = _applicationIdForResult(result);
    if (applicationId.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('Application record was not found.')),
      );
      return;
    }

    final reportingDates = await _collectReportingDates();
    if (reportingDates == null) return;

    final response = await _apiService.put('/api/applications/$applicationId', {
      'status': 'accepted',
      'reporting_start_date': reportingDates['reporting_start_date'],
      'reporting_end_date': reportingDates['reporting_end_date'],
    }, requiresAuth: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(ApiService.responseMessage(response))),
    );
    if (_selectedTestId != null) {
      await _loadResults(_selectedTestId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.organizationMode
              ? 'Test Selection - ${widget.jobTitle ?? 'Applications'}'
              : 'Test Management System',
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadData,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1000;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: isWide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 6, child: _buildCreateTestPanel()),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: _buildResultsPanel()),
                        ],
                      )
                    : Column(
                        children: [
                          _buildCreateTestPanel(),
                          const SizedBox(height: 20),
                          _buildResultsPanel(),
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCreateTestPanel() {
    return _SectionShell(
      title: 'Create New Test',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SizedField(
                width: 360,
                child: TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Test title'),
                ),
              ),
              _SizedField(
                width: 150,
                child: TextField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration'),
                ),
              ),
              _SizedField(
                width: 150,
                child: TextField(
                  controller: _passMarkController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Pass mark %'),
                ),
              ),
              _SizedField(
                width: 190,
                child: TextField(
                  controller: _deadlineController,
                  readOnly: true,
                  onTap: _pickDeadline,
                  decoration: const InputDecoration(
                    labelText: 'Deadline',
                    suffixIcon: Icon(Icons.calendar_month_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Text(
            'Questions',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          ..._questions.asMap().entries.map(
            (entry) => _QuestionEditor(
              index: entry.key,
              question: entry.value,
              canRemove: _questions.length > 1,
              onChanged: () => setState(() {}),
              onRemove: () => _removeQuestion(entry.key),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addQuestion,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add Question'),
          ),
          const SizedBox(height: 22),
          _buildStudentSelector(),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveTest,
                icon: const Icon(Icons.save_rounded),
                label: Text(_isSaving ? 'Saving...' : 'Save Test'),
              ),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _publishAndInvite,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Publish & Send to Selected Students'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStudentSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Select Students for Test',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  if (_selectedStudentIds.length == _students.length) {
                    _selectedStudentIds.clear();
                  } else {
                    _selectedStudentIds
                      ..clear()
                      ..addAll(
                        _students.map(_studentId).where((id) => id.isNotEmpty),
                      );
                  }
                });
              },
              child: Text(
                _selectedStudentIds.length == _students.length
                    ? 'Clear all'
                    : 'Select all',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: _students.length,
            separatorBuilder: (context, separatorIndex) =>
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
            itemBuilder: (context, index) {
              final student = _students[index];
              final studentId = _studentId(student);
              final selected = _selectedStudentIds.contains(studentId);
              return CheckboxListTile(
                value: selected,
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                activeColor: _brandBlue,
                title: Text(_studentName(student)),
                subtitle: Text(
                  '${student['email'] ?? ''}  •  ${_studentTraining(student)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedStudentIds.add(studentId);
                    } else {
                      _selectedStudentIds.remove(studentId);
                    }
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildResultsPanel() {
    return _SectionShell(
      title: 'Results & Auto-Selection',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedTestId,
            decoration: const InputDecoration(labelText: 'Select test'),
            items: _tests
                .map(
                  (test) => DropdownMenuItem<String>(
                    value: '${test['id']}',
                    child: Text('${test['title']}'),
                  ),
                )
                .toList(),
            onChanged: (value) async {
              if (value == null) return;
              setState(() => _selectedTestId = value);
              await _loadResults(value);
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              _SizedField(
                width: 220,
                child: TextField(
                  controller: _minimumScoreController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Minimum shortlist score %',
                  ),
                ),
              ),
              _SizedField(
                width: 160,
                child: TextField(
                  controller: _topNController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Auto accept top N',
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _selectedTestId == null || _isApplyingSelection
                    ? null
                    : _applyAutoSelection,
                icon: const Icon(Icons.auto_awesome_rounded),
                label: Text(
                  _isApplyingSelection ? 'Applying...' : 'Apply Auto-Selection',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('No test attempts yet.')),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStatePropertyAll(Colors.blue.shade50),
                columns: const [
                  DataColumn(label: Text('Student')),
                  DataColumn(label: Text('Score')),
                  DataColumn(label: Text('Attempt')),
                  DataColumn(label: Text('Selection')),
                  DataColumn(label: Text('Acceptance')),
                  DataColumn(label: Text('Answers')),
                ],
                rows: _results.map((result) {
                  final selection =
                      '${result['selection_status'] ?? 'pending'}';
                  final score =
                      double.tryParse('${result['score_percent']}') ?? 0;
                  final selectionLabel = _selectionLabel(selection);
                  final canSendAcceptance =
                      widget.organizationMode &&
                      selectionLabel == 'Selected' &&
                      selection != 'accepted' &&
                      _applicationIdForResult(result).isNotEmpty;
                  return DataRow(
                    cells: [
                      DataCell(
                        SizedBox(
                          width: 210,
                          child: Text(
                            '${result['student_name'] ?? 'Student'}\n${result['email'] ?? ''}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(Text('${score.toStringAsFixed(1)}%')),
                      DataCell(
                        Text('${result['attempt_status'] ?? 'pending'}'),
                      ),
                      DataCell(
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(selectionLabel.toUpperCase()),
                          labelStyle: TextStyle(
                            color: _selectionColor(selection),
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          backgroundColor: _selectionColor(
                            selection,
                          ).withValues(alpha: 0.10),
                          side: BorderSide(
                            color: _selectionColor(
                              selection,
                            ).withValues(alpha: 0.22),
                          ),
                        ),
                      ),
                      DataCell(
                        TextButton.icon(
                          onPressed: canSendAcceptance
                              ? () => _acceptSelectedApplicant(result)
                              : null,
                          icon: const Icon(Icons.mark_email_read_outlined),
                          label: Text(
                            selection == 'accepted'
                                ? 'Letter sent'
                                : 'Send letter',
                          ),
                        ),
                      ),
                      DataCell(
                        TextButton.icon(
                          onPressed: () => _openAttemptAnswers(result),
                          icon: const Icon(Icons.rate_review_rounded),
                          label: const Text('Grade'),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _AttemptAnswersDialog extends StatefulWidget {
  const _AttemptAnswersDialog({
    required this.apiService,
    required this.organizationMode,
    required this.attemptId,
    required this.studentName,
  });

  final ApiService apiService;
  final bool organizationMode;
  final String attemptId;
  final String studentName;

  @override
  State<_AttemptAnswersDialog> createState() => _AttemptAnswersDialogState();
}

class _AttemptAnswersDialogState extends State<_AttemptAnswersDialog> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _answers = [];
  final Map<String, TextEditingController> _scoreControllers = {};

  @override
  void initState() {
    super.initState();
    _loadAnswers();
  }

  @override
  void dispose() {
    for (final controller in _scoreControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAnswers() async {
    final response = widget.organizationMode
        ? await widget.apiService.getOrganizationTestAttemptAnswers(
            widget.attemptId,
          )
        : await widget.apiService.getTestAttemptAnswers(widget.attemptId);
    if (!mounted) return;
    final data = response['data'] as Map<String, dynamic>? ?? {};
    final answers = data['answers'] is List
        ? List<dynamic>.from(data['answers'])
        : <dynamic>[];
    for (final answer in answers) {
      final answerId = '${answer['answer_id'] ?? ''}';
      if (answerId.isEmpty) continue;
      _scoreControllers[answerId] = TextEditingController(
        text: '${answer['score_awarded'] ?? ''}',
      );
    }
    setState(() {
      _answers = answers;
      _isLoading = false;
    });
  }

  Future<void> _saveScore(dynamic answer) async {
    final answerId = '${answer['answer_id'] ?? ''}';
    if (answerId.isEmpty) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        const SnackBar(content: Text('This question has no submitted answer.')),
      );
      return;
    }

    final score =
        double.tryParse(_scoreControllers[answerId]?.text.trim() ?? '') ?? -1;
    final maxMarks = double.tryParse('${answer['marks']}') ?? 0;
    if (score < 0 || score > maxMarks) {
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text('Score must be between 0 and $maxMarks.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final response = widget.organizationMode
        ? await widget.apiService.updateOrganizationTestAnswerScore(
            answerId: answerId,
            scoreAwarded: score,
          )
        : await widget.apiService.updateTestAnswerScore(
            answerId: answerId,
            scoreAwarded: score,
          );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(ApiService.responseMessage(response))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Grade Answers - ${widget.studentName}'),
      content: SizedBox(
        width: 760,
        child: _isLoading
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: _answers.map((answer) {
                    final answerId = '${answer['answer_id'] ?? ''}';
                    final manual = const {
                      'paragraph',
                      'code',
                    }.contains('${answer['question_type']}');
                    return Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${answer['question_text'] ?? ''}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            '${answer['answer_text'] ?? 'No answer submitted'}',
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: answerId.isEmpty
                                      ? null
                                      : _scoreControllers[answerId],
                                  enabled: answerId.isNotEmpty,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Score / ${answer['marks'] ?? 0}',
                                    helperText: manual
                                        ? 'Manual grading required'
                                        : 'Auto-graded; adjust if needed',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: _isSaving || answerId.isEmpty
                                    ? null
                                    : () => _saveScore(answer),
                                child: const Text('Save'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _QuestionDraft {
  _QuestionDraft({
    String questionText = '',
    String marks = '10',
    String correctAnswer = '',
    List<String> options = const ['', ''],
  }) : questionController = TextEditingController(text: questionText),
       marksController = TextEditingController(text: marks),
       correctAnswerController = TextEditingController(text: correctAnswer),
       optionControllers = options
           .map((option) => TextEditingController(text: option))
           .toList();

  factory _QuestionDraft.exampleShort() {
    return _QuestionDraft(
      questionText: 'What is a variable in programming?',
      marks: '20',
      correctAnswer: 'A container that stores data',
    );
  }

  final TextEditingController questionController;
  final TextEditingController marksController;
  final TextEditingController correctAnswerController;
  final List<TextEditingController> optionControllers;
  String questionType = 'short_answer';

  bool get isMultipleChoice => questionType == 'multiple_choice';

  bool get isValid {
    if (questionController.text.trim().isEmpty) return false;
    if ((double.tryParse(marksController.text.trim()) ?? 0) <= 0) return false;
    if (isMultipleChoice) {
      final options = optionControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      return options.length >= 2 &&
          correctAnswerController.text.trim().isNotEmpty;
    }
    return true;
  }

  Map<String, dynamic> toJson() {
    return {
      'question_text': questionController.text.trim(),
      'question_type': questionType,
      'marks': double.tryParse(marksController.text.trim()) ?? 0,
      'correct_answer': correctAnswerController.text.trim(),
      'question_options': optionControllers
          .map((controller) => controller.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(),
    };
  }

  void addOption() {
    optionControllers.add(TextEditingController());
  }

  void removeOption(int index) {
    if (optionControllers.length <= 2) return;
    final removed = optionControllers.removeAt(index);
    removed.dispose();
  }

  void dispose() {
    questionController.dispose();
    marksController.dispose();
    correctAnswerController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }
}

class _QuestionEditor extends StatelessWidget {
  const _QuestionEditor({
    required this.index,
    required this.question,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _QuestionDraft question;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Q${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              IconButton(
                tooltip: 'Remove question',
                onPressed: canRemove ? onRemove : null,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          TextField(
            controller: question.questionController,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Question text'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SizedField(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: question.questionType,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'short_answer',
                      child: Text('Short answer'),
                    ),
                    DropdownMenuItem(
                      value: 'multiple_choice',
                      child: Text('Multiple choice'),
                    ),
                    DropdownMenuItem(
                      value: 'paragraph',
                      child: Text('Paragraph'),
                    ),
                    DropdownMenuItem(value: 'code', child: Text('Code')),
                  ],
                  onChanged: (value) {
                    question.questionType = value ?? 'short_answer';
                    onChanged();
                  },
                ),
              ),
              _SizedField(
                width: 140,
                child: TextField(
                  controller: question.marksController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Marks'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (question.isMultipleChoice) ...[
            ...question.optionControllers.asMap().entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: entry.value,
                        decoration: InputDecoration(
                          labelText: 'Option ${entry.key + 1}',
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Remove option',
                      onPressed: question.optionControllers.length > 2
                          ? () {
                              question.removeOption(entry.key);
                              onChanged();
                            }
                          : null,
                      icon: const Icon(Icons.remove_circle_outline_rounded),
                    ),
                  ],
                ),
              );
            }),
            TextButton.icon(
              onPressed: () {
                question.addOption();
                onChanged();
              },
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add option'),
            ),
          ],
          TextField(
            controller: question.correctAnswerController,
            maxLines: question.questionType == 'code' ? 4 : 1,
            decoration: InputDecoration(
              labelText: question.isMultipleChoice
                  ? 'Correct option'
                  : question.questionType == 'short_answer'
                  ? 'Suggested correct answer'
                  : 'Manual grading notes',
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SizedField extends StatelessWidget {
  const _SizedField({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}
