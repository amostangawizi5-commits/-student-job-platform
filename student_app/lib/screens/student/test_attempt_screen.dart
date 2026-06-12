import 'dart:async';

import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';

import '../../services/api_service.dart';

class TestAttemptScreen extends StatefulWidget {
  const TestAttemptScreen({super.key, required this.token});

  final String token;

  @override
  State<TestAttemptScreen> createState() => _TestAttemptScreenState();
}

class _TestAttemptScreenState extends State<TestAttemptScreen> {
  final ApiService _apiService = ApiService();
  final Map<String, TextEditingController> _answerControllers = {};
  final Map<String, String> _selectedChoices = {};
  Timer? _timer;

  Map<String, dynamic>? _attempt;
  List<dynamic> _questions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSubmitted = false;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadAttempt();
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final controller in _answerControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadAttempt() async {
    final response = await _apiService.getTestAttemptByToken(widget.token);
    if (!mounted) return;

    if (response['success'] != true) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(content: Text(ApiService.responseMessage(response))),
      );
      return;
    }

    final data = response['data'] as Map<String, dynamic>? ?? {};
    final answers = data['answers'] is List
        ? List<dynamic>.from(data['answers'])
        : <dynamic>[];

    setState(() {
      _attempt = data['attempt'] as Map<String, dynamic>?;
      _questions = data['questions'] is List
          ? List<dynamic>.from(data['questions'])
          : [];
      _isSubmitted = '${_attempt?['attempt_status']}' == 'completed';
      _isLoading = false;
    });

    for (final question in _questions) {
      final questionId = '${question['id']}';
      final saved = answers.firstWhere(
        (answer) => '${answer['question_id']}' == questionId,
        orElse: () => null,
      );
      final answerText = '${saved?['answer_text'] ?? ''}';
      if ('${question['question_type']}' == 'multiple_choice') {
        _selectedChoices[questionId] = answerText;
      } else {
        _answerControllers[questionId] = TextEditingController(
          text: answerText,
        );
      }
    }

    _startTimer();
  }

  void _startTimer() {
    final attempt = _attempt;
    if (attempt == null) return;

    final durationMinutes = int.tryParse('${attempt['duration']}') ?? 0;
    final startedAt =
        DateTime.tryParse('${attempt['started_at']}') ?? DateTime.now();
    final endsAt = startedAt.add(Duration(minutes: durationMinutes));

    void tick() {
      if (!mounted) return;
      final remaining = endsAt.difference(DateTime.now());
      setState(
        () => _remaining = remaining.isNegative ? Duration.zero : remaining,
      );
      if (_remaining == Duration.zero) {
        _timer?.cancel();
      }
    }

    tick();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  Map<String, String> _collectAnswers() {
    final answers = <String, String>{};
    for (final question in _questions) {
      final questionId = '${question['id']}';
      if ('${question['question_type']}' == 'multiple_choice') {
        answers[questionId] = _selectedChoices[questionId] ?? '';
      } else {
        answers[questionId] = _answerControllers[questionId]?.text ?? '';
      }
    }
    return answers;
  }

  Future<void> _saveProgress() async {
    setState(() => _isSaving = true);
    final response = await _apiService.saveTestAttempt(
      token: widget.token,
      answers: _collectAnswers(),
    );
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(content: Text(ApiService.responseMessage(response))),
    );
  }

  Future<void> _submit() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit test?'),
        content: const Text('You cannot edit answers after submitting.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSaving = true);
    final response = await _apiService.submitTestAttempt(
      token: widget.token,
      answers: _collectAnswers(),
    );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isSubmitted = response['success'] == true;
    });
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(
          response['success'] == true
              ? 'Test submitted successfully'
              : ApiService.responseMessage(response),
        ),
      ),
    );
  }

  String _formatDuration(Duration value) {
    final hours = value.inHours;
    final minutes = value.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = value.inSeconds.remainder(60).toString().padLeft(2, '0');
    return hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final attempt = _attempt;
    if (attempt == null) {
      return const Scaffold(
        body: Center(child: Text('This test link is invalid or expired.')),
      );
    }

    if (_isSubmitted) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 72,
                    color: Colors.green.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Test submitted successfully',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Thank you, ${attempt['student_name'] ?? 'Student'}.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${attempt['title'] ?? 'Online Test'}'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _remaining.inMinutes <= 5
                      ? Colors.red.shade50
                      : Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatDuration(_remaining),
                  style: TextStyle(
                    color: _remaining.inMinutes <= 5
                        ? Colors.red.shade700
                        : Colors.blue.shade700,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(attempt: attempt),
                    const SizedBox(height: 18),
                    ..._questions.asMap().entries.map(
                      (entry) => _QuestionAnswerCard(
                        index: entry.key,
                        question: entry.value,
                        controller: _answerControllers['${entry.value['id']}'],
                        selectedChoice:
                            _selectedChoices['${entry.value['id']}'],
                        onChoiceChanged: (value) {
                          setState(() {
                            _selectedChoices['${entry.value['id']}'] =
                                value ?? '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _saveProgress,
                          icon: const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving ? 'Saving...' : 'Save progress',
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isSaving || _remaining == Duration.zero
                              ? null
                              : _submit,
                          icon: const Icon(Icons.send_rounded),
                          label: const Text('Submit'),
                        ),
                      ],
                    ),
                    if (_remaining == Duration.zero)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          'Time is over. Contact admin if you need assistance.',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.attempt});

  final Map<String, dynamic> attempt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        children: [
          _InfoItem(
            label: 'Student',
            value: '${attempt['student_name'] ?? '-'}',
          ),
          _InfoItem(label: 'Duration', value: '${attempt['duration']} minutes'),
          _InfoItem(label: 'Pass mark', value: '${attempt['pass_mark']}%'),
          _InfoItem(label: 'Deadline', value: '${attempt['deadline']}'),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _QuestionAnswerCard extends StatelessWidget {
  const _QuestionAnswerCard({
    required this.index,
    required this.question,
    required this.controller,
    required this.selectedChoice,
    required this.onChoiceChanged,
  });

  final int index;
  final dynamic question;
  final TextEditingController? controller;
  final String? selectedChoice;
  final ValueChanged<String?> onChoiceChanged;

  @override
  Widget build(BuildContext context) {
    final questionType = '${question['question_type']}';
    final options = question['question_options'] is List
        ? List<dynamic>.from(question['question_options'])
        : <dynamic>[];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Q${index + 1}. ${question['question_text'] ?? ''}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            '${question['marks']} marks',
            style: TextStyle(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          if (questionType == 'multiple_choice')
            ...options.map((option) {
              final value = '$option';
              final selected = value == selectedChoice;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onChoiceChanged(value),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.blue.shade50 : Colors.white,
                      border: Border.all(
                        color: selected
                            ? Colors.blue.shade700
                            : const Color(0xFFE5E7EB),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: selected
                              ? Colors.blue.shade700
                              : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(value)),
                      ],
                    ),
                  ),
                ),
              );
            })
          else
            TextField(
              controller: controller,
              maxLines: questionType == 'short_answer'
                  ? 2
                  : questionType == 'code'
                  ? 10
                  : 6,
              style: questionType == 'code'
                  ? const TextStyle(fontFamily: 'monospace')
                  : null,
              decoration: InputDecoration(
                hintText: questionType == 'code'
                    ? 'Write your code here'
                    : 'Write your answer here',
              ),
            ),
        ],
      ),
    );
  }
}
