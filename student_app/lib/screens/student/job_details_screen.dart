// lib/screens/student/job_details_screen.dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../models/job.dart';

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
      final response = await _apiService.getJobById(widget.jobId);
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

      if (!mounted) return;

      setState(() {
        _job = parsedJob;
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
              withData: kIsWeb,
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'internship':
        return 'Internship';
      case 'full-time':
        return 'Full Time';
      case 'part-time':
        return 'Part Time';
      case 'graduate_program':
        return 'Graduate Program';
      default:
        return type;
    }
  }

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
                const SizedBox(width: 12),
                Expanded(
                  child: _infoCard(
                    icon: Icons.attach_money,
                    label: 'Salary',
                    value: _job!.salaryRange,
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
