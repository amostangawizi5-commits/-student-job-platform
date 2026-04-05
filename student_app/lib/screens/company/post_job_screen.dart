import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/api_service.dart';

class PostJobScreen extends StatefulWidget {
  final String? jobId;
  final Map<String, dynamic>? initialJobData;

  const PostJobScreen({super.key, this.jobId, this.initialJobData});

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final ApiService _apiService = ApiService();
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requiredApplicantsController = TextEditingController();
  final _deadlineController = TextEditingController();

  // Dropdown values
  String _selectedType = 'internship';
  List<String> _selectedTargetCandidates = [];
  bool _isSubmitting = false;
  DateTime? _selectedDeadline;

  final List<String> _jobTypes = [
    'internship',
    'full-time',
    'part-time',
    'contract',
    'graduate_program',
  ];

  bool get _isEditing => widget.jobId != null;

  @override
  void initState() {
    super.initState();
    _requiredApplicantsController.text = '1';
    _prefillForm();
  }

  void _prefillForm() {
    final job = widget.initialJobData;
    if (job == null) return;

    _titleController.text = '${job['title'] ?? ''}';
    _descriptionController.text = '${job['description'] ?? ''}';
    _locationController.text = '${job['location'] ?? ''}';
    _salaryController.text = _extractEditableSalary(
      '${job['salary_range'] ?? ''}',
    );
    final deadlineValue = '${job['application_deadline'] ?? ''}';
    _selectedDeadline = DateTime.tryParse(deadlineValue);
    _deadlineController.text = _selectedDeadline == null
        ? ''
        : _formatDeadline(_selectedDeadline!);
    _requiredApplicantsController.text = '${job['required_applicants'] ?? 1}';

    final type = '${job['type'] ?? 'internship'}';
    if (_jobTypes.contains(type)) {
      _selectedType = type;
    }

    final targets = job['target_candidates'];
    if (targets is List) {
      _selectedTargetCandidates = targets.map((e) => '$e').toList();
    }
  }

  final List<String> _targetOptions = [
    'current_students',
    'fresh_graduates',
    '1-2_years',
    '2-3_years',
    '3+_years',
  ];

  String _getTypeLabel(String type) {
    switch (type) {
      case 'internship':
        return 'Internship';
      case 'full-time':
        return 'Full Time';
      case 'part-time':
        return 'Part Time';
      case 'contract':
        return 'Contract';
      case 'graduate_program':
        return 'Graduate Program';
      default:
        return type;
    }
  }

  String _getTargetLabel(String target) {
    switch (target) {
      case 'current_students':
        return 'Current Students';
      case 'fresh_graduates':
        return 'Fresh Graduates (0-1 year)';
      case '1-2_years':
        return '1-2 years experience';
      case '2-3_years':
        return '2-3 years experience';
      case '3+_years':
        return '3+ years experience';
      default:
        return target;
    }
  }

  String _extractEditableSalary(String rawValue) {
    return rawValue
        .replaceAll(RegExp('tzs', caseSensitive: false), '')
        .replaceAll(RegExp(r'[^0-9,\s-]'), '')
        .trim();
  }

  String _formatWithCommas(int value) {
    final digits = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final indexFromEnd = digits.length - i;
      buffer.write(digits[i]);
      if (indexFromEnd > 1 && indexFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }
    return buffer.toString();
  }

  String _normalizeSalaryRange(String rawValue) {
    final cleaned = rawValue.trim();
    if (cleaned.isEmpty) return '';

    final parts = cleaned
        .split('-')
        .map((part) => part.replaceAll(',', '').trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty || parts.length > 2) {
      throw const FormatException('Enter salary in TZS numbers only');
    }

    final numbers = parts.map(int.parse).toList();
    if (numbers.any((value) => value <= 0)) {
      throw const FormatException('Salary must be greater than zero');
    }

    if (numbers.length == 2 && numbers[1] < numbers[0]) {
      throw const FormatException(
        'Maximum salary must be greater than minimum salary',
      );
    }

    if (numbers.length == 1) {
      return 'TZS ${_formatWithCommas(numbers.first)}';
    }

    return 'TZS ${_formatWithCommas(numbers.first)} - ${_formatWithCommas(numbers.last)}';
  }

  String _formatDeadline(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '${value.year}-$month-$day $hour:$minute';
  }

  Future<void> _selectDeadline() async {
    final now = DateTime.now();
    final initialDate = _selectedDeadline ?? now.add(const Duration(days: 30));
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDeadline ?? now.add(const Duration(hours: 1)),
      ),
    );
    if (pickedTime == null) return;

    final deadline = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _selectedDeadline = deadline;
      _deadlineController.text = _formatDeadline(deadline);
    });
  }

  Future<void> _submitJob() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDeadline == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select application deadline date and time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isSubmitting = true);

      try {
        final normalizedSalary = _normalizeSalaryRange(_salaryController.text);
        final jobData = {
          'title': _titleController.text.trim(),
          'type': _selectedType,
          'target_candidates': _selectedTargetCandidates,
          'description': _descriptionController.text.trim(),
          'location': _locationController.text.trim(),
          'salary_range': normalizedSalary.isEmpty ? null : normalizedSalary,
          'required_applicants': int.parse(
            _requiredApplicantsController.text.trim(),
          ),
          'application_deadline': _selectedDeadline!.toIso8601String(),
        };

        final response = _isEditing
            ? await _apiService.updateJob(widget.jobId!, jobData)
            : await _apiService.postJob(jobData);
        if (!mounted) return;

        if (response['success']) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _isEditing
                    ? 'Job updated successfully!'
                    : 'Job posted successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to post job'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ApiService.normalizeErrorMessage(
                e,
                fallback: 'Failed to save job. Please try again.',
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _requiredApplicantsController.dispose();
    _deadlineController.dispose();
    super.dispose();
  }

  void _goToSection(int index) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, {'targetIndex': index});
    }
  }

  Widget _buildTopNavigationBar() {
    Widget navItem({
      required String label,
      required IconData icon,
      required bool selected,
      required VoidCallback onTap,
      required Color color,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
            decoration: BoxDecoration(
              color: selected ? color : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? Colors.white : Colors.grey.shade700,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.grey.shade800,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          navItem(
            label: 'Home',
            icon: Icons.dashboard_rounded,
            selected: false,
            onTap: () => _goToSection(0),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: 'My Jobs',
            icon: Icons.work_rounded,
            selected: true,
            onTap: () => _goToSection(1),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: 'Applications',
            icon: Icons.groups_rounded,
            selected: false,
            onTap: () => _goToSection(2),
            color: const Color(0xFF2C3E50),
          ),
          const SizedBox(width: 6),
          navItem(
            label: 'Profile',
            icon: Icons.business_rounded,
            selected: false,
            onTap: () => _goToSection(3),
            color: const Color(0xFF2C3E50),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Job' : 'Post New Job'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopNavigationBar(),
              const SizedBox(height: 16),
              // Job Title
              const Text(
                'Job Title *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: 'e.g., Flutter Developer Intern',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Job Type
              const Text(
                'Job Type *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedType,
                    isExpanded: true,
                    items: _jobTypes.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(_getTypeLabel(type)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Target Candidates
              const Text(
                'Target Candidates *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: _targetOptions.map((option) {
                    return CheckboxListTile(
                      title: Text(_getTargetLabel(option)),
                      value: _selectedTargetCandidates.contains(option),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedTargetCandidates.add(option);
                          } else {
                            _selectedTargetCandidates.remove(option);
                          }
                        });
                      },
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),

              // Location
              const Text(
                'Location *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  hintText: 'e.g., Dar es Salaam, Remote',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Salary Range
              const Text(
                'Salary Range',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _salaryController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9,\s-]')),
                ],
                decoration: InputDecoration(
                  hintText: 'e.g., 300000 - 400000',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  final trimmed = value?.trim() ?? '';
                  if (trimmed.isEmpty) return null;
                  try {
                    _normalizeSalaryRange(trimmed);
                    return null;
                  } catch (e) {
                    return e.toString().replaceFirst('FormatException: ', '');
                  }
                },
              ),
              const SizedBox(height: 16),

              const Text(
                'Required Applicants *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _requiredApplicantsController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  hintText: 'e.g., 3',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (value) {
                  final parsed = int.tryParse(value?.trim() ?? '');
                  if (parsed == null) {
                    return 'Enter number of applicants needed';
                  }
                  if (parsed <= 0) {
                    return 'Required applicants must be at least 1';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Application Deadline
              const Text(
                'Application Deadline *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _selectDeadline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey.shade50,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 20,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _deadlineController.text.isEmpty
                            ? 'Select deadline date and time'
                            : _deadlineController.text,
                        style: TextStyle(
                          color: _deadlineController.text.isEmpty
                              ? Colors.grey.shade500
                              : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_deadlineController.text.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Deadline date and time are required',
                    style: TextStyle(fontSize: 12, color: Colors.red.shade700),
                  ),
                ),
              const SizedBox(height: 16),

              // Description
              const Text(
                'Job Description *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText:
                      'Describe the role, responsibilities, requirements...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _isEditing ? 'UPDATE JOB' : 'POST JOB',
                          style: const TextStyle(fontSize: 16),
                        ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
