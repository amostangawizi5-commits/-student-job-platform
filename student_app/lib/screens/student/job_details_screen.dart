import 'dart:typed_data';

// lib/screens/student/job_details_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  const JobDetailsScreen({super.key, required this.jobId});

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  final ApiService _apiService = ApiService();
  Job? _job;
  bool _isLoading = true;
  bool _isApplying = false;
  String? _loadErrorMessage;
  List<String> _studentSkillNames = [];

  @override
  void initState() {
    super.initState();
    _loadJobDetails();
  }

  Future<void> _loadJobDetails() async {
    setState(() {
      _isLoading = true;
      _loadErrorMessage = null;
    });

    try {
      final responses = await Future.wait([
        _apiService.getJobById(widget.jobId),
        _apiService.getStudentSkills(),
      ]);
      final response = responses[0];
      final skillsResponse = responses[1];
      if (response['success'] != true) {
        throw Exception(
          ApiService.responseMessage(
            response,
            fallback: 'Unable to load this job right now.',
          ),
        );
      }

      final rawData = response['data'];
      if (rawData is! Map) {
        throw const FormatException('Job details response is invalid.');
      }

      final parsedJob = Job.fromJson(Map<String, dynamic>.from(rawData));
      final studentSkillNames = skillsResponse['success'] == true
          ? (skillsResponse['data'] as List<dynamic>? ?? const [])
                .map((skill) => '${skill['name'] ?? ''}'.trim().toLowerCase())
                .where((name) => name.isNotEmpty)
                .toList(growable: false)
          : const <String>[];

      if (!mounted) return;

      setState(() {
        _job = parsedJob;
        _studentSkillNames = studentSkillNames;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading job details: $e');
      final message = ApiService.normalizeErrorMessage(
        e,
        fallback: 'Unable to load this job right now.',
      );

      if (!mounted) return;

      setState(() {
        _job = null;
        _isLoading = false;
        _loadErrorMessage = message;
      });
    }
  }

  Future<void> _applyForJob() async {
    if (_job == null) {
      _showMessage('Job details are not available yet. Please refresh.');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final studentData =
        authProvider.user?['student_data'] as Map<String, dynamic>?;
    final eligibilityReasons = _eligibilityReasons(studentData);
    if (eligibilityReasons.isNotEmpty) {
      _showMessage(eligibilityReasons.first, backgroundColor: Colors.red);
      return;
    }

    final applicationDraft = await _showApplicationDialog();
    if (applicationDraft == null) {
      return;
    }

    setState(() => _isApplying = true);

    try {
      final response = await _apiService.applyForJob(
        jobId: _job!.jobId,
        coverLetter: applicationDraft.coverLetter,
        supportiveDocumentPath: applicationDraft.filePath,
        supportiveDocumentBytes: applicationDraft.fileBytes,
        supportiveDocumentName: applicationDraft.fileName,
      );
      debugPrint('Apply response: $response');

      if (response['success']) {
        if (mounted) {
          _showMessage(
            'Application submitted successfully!',
            backgroundColor: Colors.green,
          );
          // Go back to browse jobs after successful application
          Navigator.pop(context);
        }
      } else {
        if (mounted) {
          _showMessage(
            ApiService.responseMessage(
              response,
              fallback: 'Failed to submit application.',
            ),
            backgroundColor: Colors.red,
          );
        }
      }
    } catch (e) {
      debugPrint('Apply error: $e');
      if (mounted) {
        _showMessage(
          ApiService.normalizeErrorMessage(
            e,
            fallback: 'Failed to submit application.',
          ),
          backgroundColor: Colors.red,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  Future<_ApplicationDraft?> _showApplicationDialog() async {
    final coverLetterController = TextEditingController();
    String? selectedFilePath;
    Uint8List? selectedFileBytes;
    String? selectedFileName;
    int? selectedFileSize;
    return await showModalBottomSheet<_ApplicationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickPdf() async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: const ['pdf'],
              withData: true,
            );

            if (!context.mounted || result == null) return;

            final file = result.files.single;
            final filePath = file.path;
            final fileBytes = file.bytes;
            final fileName = file.name.trim();

            if ((filePath == null || filePath.isEmpty) && fileBytes == null) {
              _showMessage(
                'Unable to read the selected PDF.',
                backgroundColor: Colors.red,
              );
              return;
            }

            if (!_isPdfFileName(fileName)) {
              _showMessage(
                'Please choose a PDF document only.',
                backgroundColor: Colors.red,
              );
              return;
            }

            if (file.size > 5 * 1024 * 1024) {
              _showMessage(
                'Supportive document must be 5MB or less.',
                backgroundColor: Colors.red,
              );
              return;
            }

            setModalState(() {
              selectedFilePath = filePath;
              selectedFileBytes = fileBytes;
              selectedFileName = fileName;
              selectedFileSize = file.size;
            });
          }

          void clearSelectedPdf() {
            setModalState(() {
              selectedFilePath = null;
              selectedFileBytes = null;
              selectedFileName = null;
              selectedFileSize = null;
            });
          }

          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, keyboardInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Submit Application',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Write your cover letter for ${_job!.title}. Your profile CV will be attached automatically if it exists, and you can also add one supportive document PDF.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: coverLetterController,
                    minLines: 4,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Cover Letter',
                      hintText: 'Write a short message to the company',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFD9E2EC)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          color: Colors.blue.shade700,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedFileName == null
                                ? 'Profile CV is automatic. Supportive document PDF is optional, max 5MB.'
                                : '$selectedFileName${selectedFileSize != null ? ' (${_formatFileSize(selectedFileSize!)})' : ''}',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: pickPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: Text(
                      selectedFileName == null
                          ? 'Add Supportive PDF'
                          : 'Change Supportive PDF',
                    ),
                  ),
                  if (selectedFileName != null) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: clearSelectedPdf,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Remove Supportive PDF'),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          _ApplicationDraft(
                            coverLetter: coverLetterController.text.trim(),
                            filePath: selectedFilePath,
                            fileBytes: selectedFileBytes,
                            fileName: selectedFileName,
                          ),
                        );
                      },
                      child: const Text('Submit Application'),
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  int? _deriveAcademicYear(Map<String, dynamic>? studentData) {
    final studentType = '${studentData?['student_type'] ?? ''}'
        .trim()
        .toLowerCase();
    if (studentType == 'graduate') {
      return 4;
    }

    final expectedYear = int.tryParse(
      '${studentData?['expected_graduation_year'] ?? ''}',
    );
    if (expectedYear == null) return null;

    final currentYear = DateTime.now().year;
    final remainingYears = expectedYear - currentYear;
    if (remainingYears <= 0) return 3;
    if (remainingYears == 1) return 2;
    return 1;
  }

  String _normalizeTargetCandidate(String target) {
    switch (target.trim().toLowerCase()) {
      case 'first_year':
        return 'first_year';
      case 'second_year':
        return 'second_year';
      case 'third_year':
      case 'third_year_plus':
      case 'current_students':
        return 'third_year_plus';
      default:
        return '';
    }
  }

  String _targetCandidateLabel(String target) {
    switch (target) {
      case 'first_year':
        return 'First Year';
      case 'second_year':
        return 'Second Year';
      case 'third_year_plus':
        return '3 Year+';
      default:
        return target;
    }
  }

  bool _isUnrestrictedTargetCandidates(List<String> targetCandidates) {
    if (targetCandidates.isEmpty) {
      return true;
    }

    final normalized = targetCandidates
        .map(_normalizeTargetCandidate)
        .where((item) => item.isNotEmpty)
        .toSet();

    return normalized.contains('first_year') &&
        normalized.contains('second_year') &&
        normalized.contains('third_year_plus');
  }

  List<_EligibilityCriterion> _buildEligibilityCriteria(
    Map<String, dynamic>? studentData,
  ) {
    if (_job == null) return const <_EligibilityCriterion>[];

    final studentProgram = '${studentData?['program'] ?? ''}'
        .trim()
        .toLowerCase();
    final studentGpa = double.tryParse('${studentData?['gpa'] ?? ''}');
    final academicYear = _deriveAcademicYear(studentData);
    final criteria = <_EligibilityCriterion>[];

    if (!_isUnrestrictedTargetCandidates(_job!.targetCandidates)) {
      final matchesYear = _job!.targetCandidates.any((target) {
        switch (_normalizeTargetCandidate(target)) {
          case 'first_year':
            return academicYear == 1;
          case 'second_year':
            return academicYear == 2;
          case 'third_year_plus':
            return academicYear != null && academicYear >= 3;
          default:
            return false;
        }
      });
      criteria.add(
        _EligibilityCriterion(
          passed: matchesYear,
          reason:
              'This opportunity is not open for your current academic year.',
          option: 'your academic year matches the company target',
        ),
      );
    }

    if (_job!.minimumAcademicYear != null && _job!.minimumAcademicYear! > 0) {
      criteria.add(
        _EligibilityCriterion(
          passed:
              academicYear != null &&
              academicYear >= _job!.minimumAcademicYear!,
          reason:
              'This opportunity requires students from year ${_job!.minimumAcademicYear} and above.',
          option: 'you are in year ${_job!.minimumAcademicYear} or above',
        ),
      );
    }

    if (_job!.eligiblePrograms.isNotEmpty) {
      final matchesProgram = _job!.eligiblePrograms.any((program) {
        final normalized = program.trim().toLowerCase();
        return normalized.isNotEmpty &&
            studentProgram.isNotEmpty &&
            (studentProgram.contains(normalized) ||
                normalized.contains(studentProgram));
      });
      criteria.add(
        _EligibilityCriterion(
          passed: matchesProgram,
          reason: 'Allowed programs: ${_job!.eligiblePrograms.join(', ')}.',
          option:
              'your program matches one of: ${_job!.eligiblePrograms.join(', ')}',
        ),
      );
    }

    if (_job!.minimumGpa != null) {
      criteria.add(
        _EligibilityCriterion(
          passed: studentGpa != null && studentGpa >= _job!.minimumGpa!,
          reason: studentGpa == null
              ? 'A minimum GPA of ${_job!.minimumGpa!.toStringAsFixed(2)} is required. Update your profile first.'
              : 'Your GPA is below the minimum requirement of ${_job!.minimumGpa!.toStringAsFixed(2)}.',
          option:
              'your GPA is at least ${_job!.minimumGpa!.toStringAsFixed(2)}',
        ),
      );
    }

    if (_job!.requiredSkills.isNotEmpty) {
      for (final skill in _job!.requiredSkills) {
        final skillName = '${skill['name'] ?? ''}'.trim();
        if (skillName.isEmpty) continue;
        criteria.add(
          _EligibilityCriterion(
            passed: _studentSkillNames.contains(skillName.toLowerCase()),
            reason: 'Missing required skill: $skillName.',
            option: 'you have the $skillName skill',
          ),
        );
      }
    }

    return criteria;
  }

  List<String> _eligibilityReasons(Map<String, dynamic>? studentData) {
    if (_job == null) return const ['Job details are not available.'];

    final criteria = _buildEligibilityCriteria(studentData);
    if (criteria.isEmpty) {
      return const [];
    }

    if (_job!.eligibilityMatchMode == 'any') {
      final passedAny = criteria.any((criterion) => criterion.passed);
      if (passedAny) {
        return const [];
      }

      return [
        'You must match at least one of the company requirements below.',
        ...criteria.map(
          (criterion) => 'Requirement option: ${criterion.option}',
        ),
      ];
    }

    return criteria
        .where((criterion) => !criterion.passed)
        .map((criterion) => criterion.reason)
        .toList(growable: false);
  }

  String _academicYearLabel(int? academicYear) {
    if (academicYear == null) {
      return 'Not set';
    }

    switch (academicYear) {
      case 1:
        return 'Year 1';
      case 2:
        return 'Year 2';
      case 3:
        return 'Year 3+';
      case 4:
        return 'Graduate';
      default:
        return 'Year $academicYear';
    }
  }

  List<String> _studentProfileLabels(Map<String, dynamic>? studentData) {
    final labels = <String>[];
    final program = '${studentData?['program'] ?? ''}'.trim();
    final gpa = '${studentData?['gpa'] ?? ''}'.trim();
    final academicYear = _deriveAcademicYear(studentData);

    labels.add(program.isEmpty ? 'Program: not set' : 'Program: $program');
    labels.add(gpa.isEmpty || gpa == 'null' ? 'GPA: not set' : 'GPA: $gpa');
    labels.add('Academic year: ${_academicYearLabel(academicYear)}');

    if (_studentSkillNames.isEmpty) {
      labels.add('Skills: none saved');
    } else {
      labels.add('Skills: ${_studentSkillNames.join(', ')}');
    }

    return labels;
  }

  String _eligibilityModeLabel() {
    if (_job?.eligibilityMatchMode == 'any') {
      return 'Apply if you match at least one listed condition.';
    }

    return 'Apply only if you match all listed conditions.';
  }

  List<String> _companyConditionLabels() {
    if (_job == null) return const [];

    final labels = <String>[];
    final targets = _job!.targetCandidates
        .map(_normalizeTargetCandidate)
        .where((item) => item.isNotEmpty)
        .toSet();
    final isAllYears =
        targets.contains('first_year') &&
        targets.contains('second_year') &&
        targets.contains('third_year_plus');

    if (targets.isNotEmpty && !isAllYears) {
      labels.add(
        'Target years: ${targets.map(_targetCandidateLabel).join(', ')}',
      );
    }

    if (_job!.minimumAcademicYear != null) {
      labels.add('Minimum year: ${_job!.minimumAcademicYear}+');
    }

    if (_job!.eligiblePrograms.isNotEmpty) {
      labels.add('Programs: ${_job!.eligiblePrograms.join(', ')}');
    }

    if (_job!.minimumGpa != null) {
      labels.add('Minimum GPA: ${_job!.minimumGpa!.toStringAsFixed(2)}');
    }

    if (_job!.requiredSkills.isNotEmpty) {
      labels.add(
        'Skills: ${_job!.requiredSkills.map((skill) => '${skill['name'] ?? ''}').where((name) => name.trim().isNotEmpty).join(', ')}',
      );
    }

    if (_job!.eligibilityNotes != null && _job!.eligibilityNotes!.isNotEmpty) {
      labels.add('Notes: ${_job!.eligibilityNotes!}');
    }

    return labels;
  }

  String _getTypeLabel(String type) => 'Industrial Practical Training';

  String _formatDeadline(DateTime deadline) {
    final day = deadline.day.toString().padLeft(2, '0');
    final month = deadline.month.toString().padLeft(2, '0');
    final hour = deadline.hour.toString().padLeft(2, '0');
    final minute = deadline.minute.toString().padLeft(2, '0');
    return '$day/$month/${deadline.year} $hour:$minute';
  }

  bool _isPdfFileName(String fileName) {
    return fileName.trim().toLowerCase().endsWith('.pdf');
  }

  void _showMessage(String message, {Color? backgroundColor}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: backgroundColor),
      );
  }

  Widget _buildLoadErrorState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Unable to load job details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                _loadErrorMessage ?? 'Please try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadJobDetails,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingJobState() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.work_off_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 16),
              const Text(
                'Job not found',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'This job may have been removed or is no longer available.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadJobDetails,
                child: const Text('Refresh'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loadErrorMessage != null) {
      return _buildLoadErrorState();
    }

    if (_job == null) {
      return _buildMissingJobState();
    }

    final difference = _job!.applicationDeadline.difference(DateTime.now());
    final daysLeft = difference.inDays;
    final isClosed = _job!.status != 'open' || difference.isNegative;
    final studentData =
        context.watch<AuthProvider>().user?['student_data']
            as Map<String, dynamic>?;
    final criteria = _buildEligibilityCriteria(studentData);
    final eligibilityReasons = _eligibilityReasons(studentData);
    final isEligible = eligibilityReasons.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Company Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        _job!.companyName.isNotEmpty
                            ? _job!.companyName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _job!.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _job!.companyName,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Job Info Cards
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.location_on,
                    label: 'Location',
                    value: _job!.location,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.groups,
                    label: 'Needed',
                    value: '${_job!.requiredApplicants} applicants',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _infoCard(
                    icon: Icons.work,
                    label: 'Type',
                    value: _getTypeLabel(_job!.type),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    icon: Icons.access_time,
                    label: 'Deadline',
                    value: _formatDeadline(_job!.applicationDeadline),
                    valueColor: isClosed
                        ? Colors.grey
                        : daysLeft <= 3
                        ? Colors.red
                        : Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isEligible
                    ? const Color(0xFFECFDF5)
                    : const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isEligible
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFED7AA),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isEligible
                            ? Icons.verified_outlined
                            : Icons.gpp_bad_outlined,
                        color: isEligible
                            ? const Color(0xFF047857)
                            : const Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isEligible ? 'You are eligible' : 'Not eligible yet',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isEligible
                              ? const Color(0xFF047857)
                              : const Color(0xFFC2410C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'System checks this using your saved student profile.',
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'It uses your program, GPA, academic year and saved skills. You do not need to tick manually.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Profile Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _studentProfileLabels(studentData).map((item) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD9E2EC)),
                        ),
                        child: Text(
                          item,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Company Conditions',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._companyConditionLabels().map(
                    (condition) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.checklist_rounded,
                            size: 16,
                            color: Colors.grey.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              condition,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Eligibility Checklist',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (criteria.isEmpty)
                    Text(
                      'No extra conditions were added for this job.',
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  else
                    ...criteria.map(
                      (criterion) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              criterion.passed
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 20,
                              color: criterion.passed
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFC2410C),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    criterion.option,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade900,
                                    ),
                                  ),
                                  if (!criterion.passed)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        criterion.reason,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Text(
                    _eligibilityModeLabel(),
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                  if (_job!.minimumAcademicYear != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Minimum year: ${_job!.minimumAcademicYear}+',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  if (_job!.minimumGpa != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Minimum GPA: ${_job!.minimumGpa!.toStringAsFixed(2)}',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  if (_job!.eligibilityNotes != null &&
                      _job!.eligibilityNotes!.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      _job!.eligibilityNotes!,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                  if (!isEligible) ...[
                    const SizedBox(height: 12),
                    ...eligibilityReasons.map(
                      (reason) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('\u2022 '),
                            Expanded(child: Text(reason)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Description
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _job!.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Required Skills
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.shade200,
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Required Skills',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _job!.requiredSkills.isEmpty
                        ? [
                            Text(
                              'No specific skills were listed for this job.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ]
                        : _job!.requiredSkills.map((skill) {
                            return Chip(
                              label: Text('${skill['name']}'),
                              backgroundColor: Colors.blue.shade50,
                              labelStyle: TextStyle(
                                color: Colors.blue.shade700,
                                fontSize: 13,
                              ),
                            );
                          }).toList(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // Apply Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isApplying || isClosed || !isEligible
                    ? null
                    : _applyForJob,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: isClosed
                      ? Colors.grey.shade400
                      : Colors.blue.shade700,
                ),
                child: _isApplying
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isClosed
                            ? 'APPLICATIONS CLOSED'
                            : !isEligible
                            ? 'NOT ELIGIBLE'
                            : 'APPLY NOW',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blue.shade600),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: valueColor ?? Colors.black87,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _ApplicationDraft {
  final String coverLetter;
  final String? filePath;
  final Uint8List? fileBytes;
  final String? fileName;

  const _ApplicationDraft({
    required this.coverLetter,
    this.filePath,
    this.fileBytes,
    this.fileName,
  });
}

class _EligibilityCriterion {
  final bool passed;
  final String reason;
  final String option;

  const _EligibilityCriterion({
    required this.passed,
    required this.reason,
    required this.option,
  });
}
