import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/tanzania_locations.dart';
import '../../services/api_service.dart';
import '../../utils/role_theme.dart';

const Color _companyJobPrimary = CompanyRoleTheme.primary;
const Color _companyJobPrimaryDark = CompanyRoleTheme.primaryDark;
const Color _companyJobSurface = CompanyRoleTheme.surface;
const Color _companyJobSurfaceSoft = CompanyRoleTheme.surfaceSoft;
const Color _companyJobBorder = CompanyRoleTheme.border;

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
  final _requiredApplicantsController = TextEditingController();
  final _deadlineController = TextEditingController();
  final _courseRequirementsController = TextEditingController();
  final _minimumGpaController = TextEditingController();
  final _eligibilityNotesController = TextEditingController();

  // Dropdown values
  String _selectedType = 'graduate_program';
  List<String> _selectedTargetCandidates = [];
  List<dynamic> _availableSkills = [];
  List<String> _selectedSkillIds = [];
  bool _allowAllStudents = true;
  String _eligibilityMatchMode = 'all';
  String? _selectedRegion;
  int? _minimumAcademicYear;
  bool _isSubmitting = false;
  DateTime? _selectedDeadline;

  final List<String> _jobTypes = ['graduate_program'];

  bool get _isEditing => widget.jobId != null;

  @override
  void initState() {
    super.initState();
    _requiredApplicantsController.text = '1';
    _selectedTargetCandidates = List<String>.from(_targetOptions);
    _prefillForm();
    _loadSkills();
  }

  void _prefillForm() {
    final job = widget.initialJobData;
    if (job == null) return;

    _titleController.text = '${job['title'] ?? ''}';
    _descriptionController.text = '${job['description'] ?? ''}';
    _locationController.text = '${job['location'] ?? ''}';
    final normalizedLocation = _locationController.text.trim();
    if (tanzaniaRegionDistricts.containsKey(normalizedLocation)) {
      _selectedRegion = normalizedLocation;
    }
    final deadlineValue = '${job['application_deadline'] ?? ''}';
    _selectedDeadline = DateTime.tryParse(deadlineValue);
    _deadlineController.text = _selectedDeadline == null
        ? ''
        : _formatDeadline(_selectedDeadline!);
    _requiredApplicantsController.text = '${job['required_applicants'] ?? 1}';

    final type = '${job['type'] ?? 'graduate_program'}';
    if (_jobTypes.contains(type)) {
      _selectedType = type;
    }

    final targets = job['target_candidates'];
    if (targets is List) {
      _selectedTargetCandidates = _sanitizeTargetCandidates(targets);
    }

    final eligiblePrograms = job['eligible_programs'];
    if (eligiblePrograms is List && eligiblePrograms.isNotEmpty) {
      _courseRequirementsController.text = eligiblePrograms.join(', ');
    }

    final minimumGpa = '${job['minimum_gpa'] ?? ''}'.trim();
    if (minimumGpa.isNotEmpty && minimumGpa != 'null') {
      _minimumGpaController.text = minimumGpa;
    }

    final minimumAcademicYearValue = int.tryParse(
      '${job['minimum_academic_year'] ?? ''}',
    );
    _minimumAcademicYear = minimumAcademicYearValue;

    final eligibilityNotes = '${job['eligibility_notes'] ?? ''}'.trim();
    if (eligibilityNotes.isNotEmpty && eligibilityNotes != 'null') {
      _eligibilityNotesController.text = eligibilityNotes;
    }

    final matchMode = '${job['eligibility_match_mode'] ?? 'all'}'
        .trim()
        .toLowerCase();
    _eligibilityMatchMode = matchMode == 'any' ? 'any' : 'all';

    final requiredSkills = job['required_skills'];
    if (requiredSkills is List) {
      _selectedSkillIds = requiredSkills
          .map((skill) => '${skill['skill_id'] ?? ''}'.trim())
          .where((skillId) => skillId.isNotEmpty)
          .toList();
    }

    final hasRestrictions =
        _selectedTargetCandidates.length != _targetOptions.length ||
        _courseRequirementsController.text.trim().isNotEmpty ||
        _minimumGpaController.text.trim().isNotEmpty ||
        _minimumAcademicYear != null ||
        _selectedSkillIds.isNotEmpty ||
        _eligibilityNotesController.text.trim().isNotEmpty;
    _allowAllStudents = !hasRestrictions;
  }

  final List<String> _targetOptions = [
    'first_year',
    'second_year',
    'third_year_plus',
  ];

  List<String> _sanitizeTargetCandidates(Iterable<dynamic> values) {
    final allowedTargets = _targetOptions.toSet();

    return values
        .map((value) => '$value'.trim().toLowerCase())
        .where((value) => allowedTargets.contains(value))
        .toSet()
        .toList(growable: false);
  }

  Future<void> _loadSkills() async {
    try {
      final response = await _apiService.getSkills();
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _availableSkills = response['data'] as List<dynamic>? ?? const [];
        });
      }
    } catch (_) {}
  }

  String _getTypeLabel(String type) => 'Industrial Practical Training';

  String _getTargetLabel(String target) {
    switch (target) {
      case 'current_students':
      case 'first_year':
        return 'First Year';
      case 'second_year':
        return 'Second Year';
      case 'third_year':
      case 'third_year_plus':
        return '3 Year+';
      default:
        return target;
    }
  }

  String _getAcademicYearLabel(int year) {
    switch (year) {
      case 1:
        return 'First Year and above';
      case 2:
        return 'Second Year and above';
      case 3:
        return 'Third Year and above';
      case 4:
        return 'Fourth Year and above';
      default:
        return 'Year $year and above';
    }
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
    final today = DateTime(now.year, now.month, now.day);
    final initialDate = _selectedDeadline ?? today;
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _companyJobPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _companyJobPrimaryDark,
            ),
          ),
          child: child!,
        );
      },
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        _selectedDeadline ?? now.add(const Duration(hours: 1)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _companyJobPrimary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _companyJobPrimaryDark,
            ),
          ),
          child: child!,
        );
      },
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

  List<String> _eligiblePrograms() {
    return _courseRequirementsController.text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  String _matchModeLabel() {
    return _eligibilityMatchMode == 'any'
        ? 'Student can apply after matching at least one condition below.'
        : 'Student must match all conditions below before applying.';
  }

  List<String> _conditionPreviewItems() {
    final items = <String>[];

    if (_selectedTargetCandidates.isNotEmpty &&
        _selectedTargetCandidates.length != _targetOptions.length) {
      items.add(
        'Target year: ${_selectedTargetCandidates.map(_getTargetLabel).join(', ')}',
      );
    }

    if (_minimumAcademicYear != null) {
      items.add(
        'Minimum year: ${_getAcademicYearLabel(_minimumAcademicYear!)}',
      );
    }

    final programs = _eligiblePrograms();
    if (programs.isNotEmpty) {
      items.add('Programs: ${programs.join(', ')}');
    }

    final minimumGpa = _minimumGpaController.text.trim();
    if (minimumGpa.isNotEmpty) {
      items.add('Minimum GPA: $minimumGpa');
    }

    if (_selectedSkillIds.isNotEmpty) {
      final selectedSkills = _availableSkills
          .where(
            (skill) =>
                _selectedSkillIds.contains('${skill['skill_id'] ?? ''}'.trim()),
          )
          .map((skill) => '${skill['name'] ?? 'Skill'}')
          .where((name) => name.trim().isNotEmpty)
          .toList(growable: false);
      if (selectedSkills.isNotEmpty) {
        items.add('Skills: ${selectedSkills.join(', ')}');
      }
    }

    final notes = _eligibilityNotesController.text.trim();
    if (notes.isNotEmpty) {
      items.add('Notes: $notes');
    }

    return items;
  }

  Future<void> _submitJob() async {
    if (_formKey.currentState!.validate()) {
      if (!_allowAllStudents && _selectedTargetCandidates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Select at least one target candidate year'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

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
        final selectedPrograms = _allowAllStudents
            ? <String>[]
            : _eligiblePrograms();
        final jobData = {
          'title': _titleController.text.trim(),
          'type': _selectedType,
          'target_candidates': _allowAllStudents
              ? _targetOptions
              : _sanitizeTargetCandidates(_selectedTargetCandidates),
          'description': _descriptionController.text.trim(),
          'location': _locationController.text.trim(),
          'salary_range': null,
          'required_applicants': int.parse(
            _requiredApplicantsController.text.trim(),
          ),
          'application_deadline': _selectedDeadline!.toIso8601String(),
          'eligible_programs': selectedPrograms,
          'minimum_gpa': _allowAllStudents
              ? null
              : double.tryParse(_minimumGpaController.text.trim()),
          'minimum_academic_year': _allowAllStudents
              ? null
              : _minimumAcademicYear,
          'eligibility_notes': _allowAllStudents
              ? null
              : _eligibilityNotesController.text.trim(),
          'eligibility_match_mode': _allowAllStudents
              ? 'all'
              : _eligibilityMatchMode,
          'skills': _allowAllStudents ? <String>[] : _selectedSkillIds,
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
    _requiredApplicantsController.dispose();
    _deadlineController.dispose();
    _courseRequirementsController.dispose();
    _minimumGpaController.dispose();
    _eligibilityNotesController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration({
    String? hintText,
    String? labelText,
    String? helperText,
  }) {
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      helperText: helperText,
      labelStyle: const TextStyle(
        color: _companyJobPrimaryDark,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(color: Colors.blueGrey.shade400),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _companyJobBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: _companyJobPrimary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 14,
        color: _companyJobPrimaryDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conditionPreviewItems = _conditionPreviewItems();

    return Scaffold(
      backgroundColor: _companyJobSurfaceSoft,
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Job' : 'Post New Job'),
        backgroundColor: _companyJobSurfaceSoft,
        foregroundColor: _companyJobPrimaryDark,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Form(
              key: _formKey,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: _companyJobBorder.withValues(alpha: 0.8),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _companyJobPrimary.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _companyJobSurfaceSoft,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: _companyJobBorder),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: _companyJobSurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.work_outline_rounded,
                              color: _companyJobPrimary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _isEditing
                                      ? 'Update job information'
                                      : 'Create a new company job post',
                                  style: const TextStyle(
                                    color: _companyJobPrimaryDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _isEditing
                                      ? 'Edit the opportunity details below and save your changes.'
                                      : 'Fill in the role details below to publish a new opportunity.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildSectionLabel('Job Title *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _titleController,
                      decoration: _inputDecoration(
                        hintText:
                            'e.g., Industrial Practical Training Opportunity',
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('Target Type *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedType,
                      decoration: _inputDecoration(),
                      dropdownColor: Colors.white,
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
                    const SizedBox(height: 16),
                    _buildSectionLabel('Applicant Conditions'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(color: _companyJobBorder),
                        borderRadius: BorderRadius.circular(18),
                        color: _companyJobSurfaceSoft,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            value: _allowAllStudents,
                            activeThumbColor: _companyJobPrimary,
                            activeTrackColor: _companyJobSurface,
                            contentPadding: EdgeInsets.zero,
                            title: const Text(
                              'Allow all students to apply',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: _companyJobPrimaryDark,
                              ),
                            ),
                            subtitle: Text(
                              'Turn off this option to limit by year, course, GPA, or skills.',
                              style: TextStyle(color: Colors.blueGrey.shade700),
                            ),
                            onChanged: (value) {
                              setState(() {
                                _allowAllStudents = value;
                                if (value) {
                                  _selectedTargetCandidates = List<String>.from(
                                    _targetOptions,
                                  );
                                  _minimumAcademicYear = null;
                                }
                              });
                            },
                          ),
                          if (!_allowAllStudents) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _companyJobSurface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: _companyJobBorder),
                              ),
                              child: Text(
                                _matchModeLabel(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _companyJobPrimaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _eligibilityMatchMode,
                              decoration: _inputDecoration(
                                labelText: 'Eligibility Match Rule',
                                helperText:
                                    'Choose whether students must meet all conditions or at least one.',
                              ),
                              dropdownColor: Colors.white,
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Match all conditions'),
                                ),
                                DropdownMenuItem(
                                  value: 'any',
                                  child: Text('Match any condition'),
                                ),
                              ],
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _eligibilityMatchMode = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildSectionLabel('Target Candidates *'),
                            const SizedBox(height: 8),
                            ..._targetOptions.map((option) {
                              return CheckboxListTile(
                                title: Text(
                                  _getTargetLabel(option),
                                  style: const TextStyle(
                                    color: _companyJobPrimaryDark,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                value: _selectedTargetCandidates.contains(
                                  option,
                                ),
                                activeColor: _companyJobPrimary,
                                checkColor: Colors.white,
                                onChanged: (checked) {
                                  setState(() {
                                    if (checked == true) {
                                      _selectedTargetCandidates = [
                                        ..._selectedTargetCandidates,
                                        option,
                                      ];
                                    } else {
                                      _selectedTargetCandidates =
                                          _selectedTargetCandidates
                                              .where(
                                                (candidate) =>
                                                    candidate != option,
                                              )
                                              .toList();
                                    }
                                  });
                                },
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            }),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<int>(
                              initialValue: _minimumAcademicYear,
                              decoration: _inputDecoration(
                                labelText: 'Minimum Academic Year',
                              ),
                              dropdownColor: Colors.white,
                              items: List<int>.generate(4, (index) => index + 1)
                                  .map(
                                    (year) => DropdownMenuItem<int>(
                                      value: year,
                                      child: Text(_getAcademicYearLabel(year)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                setState(() => _minimumAcademicYear = value);
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _courseRequirementsController,
                              decoration: _inputDecoration(
                                labelText: 'Allowed Courses / Programs',
                                hintText:
                                    'e.g. Computer Science, IT, Software Engineering',
                                helperText:
                                    'Separate multiple programs with commas.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _minimumGpaController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.]'),
                                ),
                              ],
                              decoration: _inputDecoration(
                                labelText: 'Minimum GPA',
                                hintText: 'e.g. 3.5',
                                helperText: 'Optional. Use 0.0 to 5.0 scale.',
                              ),
                              validator: (value) {
                                final trimmed = value?.trim() ?? '';
                                if (trimmed.isEmpty) return null;
                                final parsed = double.tryParse(trimmed);
                                if (parsed == null ||
                                    parsed < 0 ||
                                    parsed > 5) {
                                  return 'Enter GPA between 0.0 and 5.0';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            _buildSectionLabel('Required Skills'),
                            const SizedBox(height: 8),
                            if (_availableSkills.isEmpty)
                              Text(
                                'No skills loaded yet.',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableSkills.map((skill) {
                                  final skillId = '${skill['skill_id'] ?? ''}';
                                  final selected = _selectedSkillIds.contains(
                                    skillId,
                                  );
                                  return FilterChip(
                                    label: Text('${skill['name'] ?? 'Skill'}'),
                                    selected: selected,
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? _companyJobPrimaryDark
                                          : Colors.blueGrey.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    backgroundColor: Colors.white,
                                    selectedColor: _companyJobSurface,
                                    checkmarkColor: _companyJobPrimary,
                                    side: BorderSide(
                                      color: selected
                                          ? _companyJobPrimary
                                          : _companyJobBorder,
                                    ),
                                    onSelected: (checked) {
                                      setState(() {
                                        if (checked) {
                                          _selectedSkillIds = [
                                            ..._selectedSkillIds,
                                            skillId,
                                          ];
                                        } else {
                                          _selectedSkillIds = _selectedSkillIds
                                              .where((id) => id != skillId)
                                              .toList();
                                        }
                                      });
                                    },
                                  );
                                }).toList(),
                              ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _eligibilityNotesController,
                              maxLines: 3,
                              decoration: _inputDecoration(
                                labelText: 'Extra Eligibility Notes',
                                hintText:
                                    'e.g. Mobile app development portfolio is an advantage.',
                              ),
                            ),
                            const SizedBox(height: 14),
                            _buildSectionLabel('Condition Preview'),
                            const SizedBox(height: 8),
                            if (conditionPreviewItems.isEmpty)
                              Text(
                                'Add at least one condition above to restrict applicants.',
                                style: TextStyle(
                                  color: Colors.blueGrey.shade600,
                                ),
                              )
                            else
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: conditionPreviewItems
                                    .map(
                                      (item) => Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: _companyJobBorder,
                                          ),
                                        ),
                                        child: Text(
                                          item,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: _companyJobPrimaryDark,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('Location *'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRegion,
                      decoration: _inputDecoration(hintText: 'Select region'),
                      dropdownColor: Colors.white,
                      items: tanzaniaRegionDistricts.keys
                          .map((region) {
                            return DropdownMenuItem<String>(
                              value: region,
                              child: Text(region),
                            );
                          })
                          .toList(growable: false),
                      onChanged: (value) {
                        setState(() {
                          _selectedRegion = value;
                          _locationController.text = value ?? '';
                        });
                      },
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Select job location';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('Required Applicants *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _requiredApplicantsController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: _inputDecoration(hintText: 'e.g., 3'),
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
                    _buildSectionLabel('Application Deadline *'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _selectDeadline,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: _companyJobBorder),
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white,
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today_rounded,
                              size: 20,
                              color: _companyJobPrimary,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _deadlineController.text.isEmpty
                                    ? 'Select deadline date and time'
                                    : _deadlineController.text,
                                style: TextStyle(
                                  color: _deadlineController.text.isEmpty
                                      ? Colors.blueGrey.shade400
                                      : _companyJobPrimaryDark,
                                  fontWeight: _deadlineController.text.isEmpty
                                      ? FontWeight.w500
                                      : FontWeight.w600,
                                ),
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
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                          ),
                        ),
                      ),
                    const SizedBox(height: 16),
                    _buildSectionLabel('Job Description *'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      decoration: _inputDecoration(
                        hintText:
                            'Describe the role, responsibilities, requirements...',
                      ),
                      validator: (v) => v?.isEmpty ?? true ? 'Required' : null,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitJob,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _companyJobPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
