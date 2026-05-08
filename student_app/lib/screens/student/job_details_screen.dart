import 'dart:typed_data';

// lib/screens/student/job_details_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/job.dart';
import '../../providers/auth_provider.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  final bool openApplySheetOnLoad;

  const JobDetailsScreen({
    super.key,
    required this.jobId,
    this.openApplySheetOnLoad = false,
  });

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
  Map<String, bool> _acknowledgedSkills = {};
  bool _hasHandledAutoApply = false;

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
        _acknowledgedSkills = {
          for (final skill in parsedJob.requiredSkills)
            if ('${skill['name'] ?? ''}'.trim().isNotEmpty)
              '${skill['name']}'.trim().toLowerCase(): false,
        };
        _isLoading = false;
      });

      if (widget.openApplySheetOnLoad && !_hasHandledAutoApply) {
        _hasHandledAutoApply = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _applyForJob();
        });
      }
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

    if (!_areRequiredSkillsAcknowledged()) {
      _showMessage(
        'Tick all required skills under Organization Condition first.',
        backgroundColor: Colors.red,
      );
      return;
    }

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
        coverLetterPath: applicationDraft.coverLetterPath,
        coverLetterBytes: applicationDraft.coverLetterBytes,
        coverLetterFileName: applicationDraft.coverLetterFileName,
        supportiveDocumentPath: applicationDraft.supportiveDocumentPath,
        supportiveDocumentBytes: applicationDraft.supportiveDocumentBytes,
        supportiveDocumentName: applicationDraft.supportiveDocumentName,
      );
      debugPrint('Apply response: $response');

      if (response['success']) {
        if (mounted) {
          _showMessage(
            'Application submitted successfully!',
            backgroundColor: Colors.green,
          );
          // Go back to browse training after successful application
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
    String? coverLetterPath;
    Uint8List? coverLetterBytes;
    String? coverLetterFileName;
    int? coverLetterFileSize;
    String? supportiveDocumentPath;
    Uint8List? supportiveDocumentBytes;
    String? supportiveDocumentName;
    int? supportiveDocumentSize;
    return await showModalBottomSheet<_ApplicationDraft>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          Future<void> pickPdf({required bool isCoverLetter}) async {
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
                'PDF must be 5MB or less.',
                backgroundColor: Colors.red,
              );
              return;
            }

            setModalState(() {
              if (isCoverLetter) {
                coverLetterPath = filePath;
                coverLetterBytes = fileBytes;
                coverLetterFileName = fileName;
                coverLetterFileSize = file.size;
              } else {
                supportiveDocumentPath = filePath;
                supportiveDocumentBytes = fileBytes;
                supportiveDocumentName = fileName;
                supportiveDocumentSize = file.size;
              }
            });
          }

          void clearSelectedPdf({required bool isCoverLetter}) {
            setModalState(() {
              if (isCoverLetter) {
                coverLetterPath = null;
                coverLetterBytes = null;
                coverLetterFileName = null;
                coverLetterFileSize = null;
              } else {
                supportiveDocumentPath = null;
                supportiveDocumentBytes = null;
                supportiveDocumentName = null;
                supportiveDocumentSize = null;
              }
            });
          }

          final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
          final screenHeight = MediaQuery.of(context).size.height;

          return AnimatedPadding(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 720,
                  maxHeight: screenHeight * 0.88,
                ),
                child: Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFD6E4F0)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A0F172A),
                        blurRadius: 30,
                        offset: Offset(0, 18),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 5,
                            decoration: BoxDecoration(
                              color: const Color(0xFFD9E2EC),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFF7FBFF), Color(0xFFEEF6FF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: const Color(0xFFD7E8FB)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                height: 52,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x140F172A),
                                      blurRadius: 12,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.cloud_upload_rounded,
                                  color: Color(0xFF166534),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Submit Application',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    SizedBox(height: 6),
                                    Text(
                                      'Upload your cover letter and any supportive PDF documents here. Keep each file under 5MB.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.45,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildUploadTile(
                          icon: Icons.picture_as_pdf_outlined,
                          title: 'Cover Letter PDF',
                          value: coverLetterFileName == null
                              ? 'Required, max 5MB'
                              : '$coverLetterFileName${coverLetterFileSize != null ? ' (${_formatFileSize(coverLetterFileSize!)})' : ''}',
                          actionLabel: coverLetterFileName == null
                              ? 'Upload'
                              : 'Change',
                          onUpload: () => pickPdf(isCoverLetter: true),
                          onClear: coverLetterFileName == null
                              ? null
                              : () => clearSelectedPdf(isCoverLetter: true),
                        ),
                        const SizedBox(height: 10),
                        _buildUploadTile(
                          icon: Icons.attach_file_rounded,
                          title: 'Supportive Document PDF',
                          value: supportiveDocumentName == null
                              ? 'Optional, max 5MB'
                              : '$supportiveDocumentName${supportiveDocumentSize != null ? ' (${_formatFileSize(supportiveDocumentSize!)})' : ''}',
                          actionLabel: supportiveDocumentName == null
                              ? 'Upload'
                              : 'Change',
                          onUpload: () => pickPdf(isCoverLetter: false),
                          onClear: supportiveDocumentName == null
                              ? null
                              : () => clearSelectedPdf(isCoverLetter: false),
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (coverLetterFileName == null ||
                                  ((coverLetterPath == null ||
                                          coverLetterPath!.isEmpty) &&
                                      coverLetterBytes == null)) {
                                _showMessage(
                                  'Upload cover letter PDF first.',
                                  backgroundColor: Colors.red,
                                );
                                return;
                              }

                              Navigator.pop(
                                context,
                                _ApplicationDraft(
                                  coverLetter: '',
                                  coverLetterPath: coverLetterPath,
                                  coverLetterBytes: coverLetterBytes,
                                  coverLetterFileName: coverLetterFileName,
                                  supportiveDocumentPath:
                                      supportiveDocumentPath,
                                  supportiveDocumentBytes:
                                      supportiveDocumentBytes,
                                  supportiveDocumentName:
                                      supportiveDocumentName,
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 0,
                            ),
                            child: const Text(
                              'Submit Application',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
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

  Widget _buildUploadTile({
    required IconData icon,
    required String title,
    required String value,
    required String actionLabel,
    required VoidCallback onUpload,
    VoidCallback? onClear,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E4F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x120F172A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.blue.shade700, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: onUpload,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: const Color(0xFF0F766E),
                  side: const BorderSide(color: Color(0xFF9FD5CA)),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(actionLabel),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: Colors.red,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                  tooltip: 'Remove file',
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey.shade700,
              height: 1.4,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  int? _deriveAcademicYear(Map<String, dynamic>? studentData) {
    final studentType = '${studentData?['student_type'] ?? ''}'
        .trim()
        .toLowerCase();
    if (studentType == '') {
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
          case 'continuing':
            return academicYear != null && academicYear >= 1;
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

    if (_job!.eligibilityNotes != null && _job!.eligibilityNotes!.isNotEmpty) {
      labels.add('Notes: ${_job!.eligibilityNotes!}');
    }

    return labels;
  }

  List<String> _requiredSkillNames() {
    if (_job == null) return const [];

    return _job!.requiredSkills
        .map((skill) => '${skill['name'] ?? ''}'.trim())
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  bool _areRequiredSkillsAcknowledged() {
    final skillNames = _requiredSkillNames();
    if (skillNames.isEmpty) {
      return true;
    }

    for (final skillName in skillNames) {
      if (_acknowledgedSkills[skillName.toLowerCase()] != true) {
        return false;
      }
    }

    return true;
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
      ..showAppSnackBar(
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

  Widget _buildMissingtrainingtate() {
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
      return _buildMissingtrainingtate();
    }

    final difference = _job!.applicationDeadline.difference(DateTime.now());
    final daysLeft = difference.inDays;
    final isClosed = _job!.status != 'open' || difference.isNegative;
    final studentData =
        context.watch<AuthProvider>().user?['student_data']
            as Map<String, dynamic>?;
    final eligibilityReasons = _eligibilityReasons(studentData);
    final isEligible = eligibilityReasons.isEmpty;
    final requiredSkillNames = _requiredSkillNames();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            constraints.maxWidth > 900 ? 28 : 16,
            16,
            constraints.maxWidth > 900 ? 28 : 16,
            16,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
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
                  // Organization Condition
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
                          'Organization Condition',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ..._companyConditionLabels().map(
                          (condition) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.checklist_rounded,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    condition,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_job!.minimumGpa != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFD9E2EC),
                              ),
                            ),
                            child: Text(
                              'GPA is checked automatically by the system. Minimum GPA: ${_job!.minimumGpa!.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                        if (requiredSkillNames.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Skills',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...requiredSkillNames.map((skillName) {
                            final skillKey = skillName.toLowerCase();
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: CheckboxListTile(
                                value: _acknowledgedSkills[skillKey] ?? false,
                                onChanged: (value) {
                                  setState(() {
                                    _acknowledgedSkills[skillKey] =
                                        value ?? false;
                                  });
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                dense: true,
                                title: Text(
                                  skillName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  _studentSkillNames.contains(skillKey)
                                      ? 'Saved in your profile'
                                      : 'Tick if you understand this skill',
                                ),
                              ),
                            );
                          }),
                        ] else
                          Text(
                            'No specific skills were listed for this placement.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                    child: Row(
                      children: [
                        Icon(
                          isEligible
                              ? Icons.verified_rounded
                              : Icons.info_outline_rounded,
                          color: isEligible
                              ? const Color(0xFF047857)
                              : const Color(0xFFC2410C),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isEligible ? 'Your eligible' : 'Not eligible yet',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isEligible
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFC2410C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isApplying || isClosed ? null : _applyForJob,
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
                              isClosed ? 'APPLICATIONS CLOSED' : 'APPLY NOW',
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
          ),
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
  final String? coverLetterPath;
  final Uint8List? coverLetterBytes;
  final String? coverLetterFileName;
  final String? supportiveDocumentPath;
  final Uint8List? supportiveDocumentBytes;
  final String? supportiveDocumentName;

  const _ApplicationDraft({
    required this.coverLetter,
    this.coverLetterPath,
    this.coverLetterBytes,
    this.coverLetterFileName,
    this.supportiveDocumentPath,
    this.supportiveDocumentBytes,
    this.supportiveDocumentName,
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
