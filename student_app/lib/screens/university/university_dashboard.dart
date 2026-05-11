import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:student_app/utils/app_feedback.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/api_service.dart';
import '../../services/coordinator_workspace_service.dart';
import '../../services/export_file_saver.dart';
import '../../utils/assets.dart';
import '../../utils/role_theme.dart';
import '../../widgets/language_picker_dialog.dart';
import '../auth/login_screen.dart';
import 'company_reports_board.dart';
import 'coordinator_announcement_center.dart';
import 'university_notifications_screen.dart';

const Color _universityNavy = Color(0xFF103B63);
const Color _universityTeal = Color(0xFF0F766E);
const Color _universityMist = Color(0xFFEAF4FB);
const Color _universityBorder = Color(0xFFD9E6F2);
const Color _universityInk = Color(0xFF17324D);
const Color _universityMuted = Color(0xFF5F7288);
const Color _universityHeaderNavy = AdminRoleTheme.primary;
const Color _coordinatorPrimary = Color(0xFF1E3A5F);
const Color _coordinatorSecondary = Color(0xFFF4A261);
const Color _coordinatorSuccess = Color(0xFF2E9C6E);
const Color _coordinatorWarning = Color(0xFFE9C46A);
const Color _coordinatorDanger = Color(0xFFE76F51);
const Color _coordinatorBackground = Color(0xFFF8F9FA);

enum _UniversityMoreAction { settings, language, logout }

enum _UniversityStudentView { all, awarded, placed, noField }

enum _CoordinatorDashboardTab { placed, notPlaced, all }

class UniversityDashboard extends StatefulWidget {
  const UniversityDashboard({super.key});

  @override
  State<UniversityDashboard> createState() => _UniversityDashboardState();
}

class _UniversityDashboardState extends State<UniversityDashboard> {
  final ApiService _apiService = ApiService();
  final CoordinatorWorkspaceService _workspaceService =
      CoordinatorWorkspaceService();
  final TextEditingController _dashboardSearchController =
      TextEditingController();

  int _selectedIndex = 0;
  _UniversityStudentView _selectedStudentView = _UniversityStudentView.all;
  _CoordinatorDashboardTab _selectedDashboardTab =
      _CoordinatorDashboardTab.placed;
  bool _isLoading = true;
  bool _isLoggingOut = false;
  bool _hasError = false;
  String _errorMessage = '';
  String _dashboardSearchQuery = '';

  List<Map<String, dynamic>> _universityStudentsData = const [];
  List<Map<String, dynamic>> _wallOfFame = const [];
  List<Map<String, dynamic>> _recentAnnouncements = const [];
  List<Map<String, dynamic>> _leaderboard = const [];
  List<Map<String, dynamic>> _approvalRecords = const [];
  List<Map<String, dynamic>> _manualPlacementRecords = const [];
  List<Map<String, dynamic>> _companyContacts = const [];
  List<Map<String, dynamic>> _companyReports = const [];
  List<Map<String, dynamic>> get _awardedStudents {
    final awarded = <Map<String, dynamic>>[];
    awarded.addAll(_recentAnnouncements);
    awarded.addAll(_leaderboard);
    final trackedEmails = _trackedStudentEmails;
    final trackedNames = _trackedStudentNames;

    final uniqueAwarded = <String, Map<String, dynamic>>{};
    for (final item in awarded) {
      final studentName = _stringValue(item['student_name'], fallback: '');
      final studentEmail = _normalizedText(item['email']);
      final belongsToUniversity =
          _matchesUniversity(item['university_name']) ||
          (studentEmail.isNotEmpty && trackedEmails.contains(studentEmail)) ||
          trackedNames.contains(_normalizedText(studentName));
      if (!belongsToUniversity || studentName.isEmpty) continue;

      final trackedStudent = _findTrackedStudent(
        email: item['email'],
        studentName: studentName,
      );
      final uniqueKey = studentEmail.isNotEmpty
          ? studentEmail
          : _normalizedText(studentName);
      if (uniqueKey.isEmpty || uniqueAwarded.containsKey(uniqueKey)) continue;

      uniqueAwarded[uniqueKey] = {
        'student_name': studentName,
        'email': _stringValue(
          trackedStudent?['email'] ?? item['email'],
          fallback: '',
        ),
        'phone': _stringValue(trackedStudent?['phone'], fallback: ''),
        'company_name': _stringValue(item['company_name']),
        'title': _stringValue(
          item['title'],
          fallback: _stringValue(item['award_title'], fallback: 'Award'),
        ),
        'award_date': item['award_date'],
        'created_at': item['created_at'],
        'university_name': _stringValue(
          trackedStudent?['university_name'] ?? item['university_name'],
        ),
      };
    }

    return uniqueAwarded.values.toList(growable: false)..sort((a, b) {
      final aDate = _parseDate(a['award_date'] ?? a['created_at']);
      final bDate = _parseDate(b['award_date'] ?? b['created_at']);
      return (bDate?.compareTo(aDate ?? DateTime(2000)) ?? 0) -
          (aDate?.compareTo(bDate ?? DateTime(2000)) ?? 0);
    });
  }

  List<Map<String, dynamic>> get _fieldPlacedStudents {
    final placedStudents = <String, Map<String, dynamic>>{};

    void upsertPlacedStudent(Map<String, dynamic> candidate) {
      final studentName = _stringValue(candidate['student_name'], fallback: '');
      final uniqueKey = _studentIdentityKey(
        email: candidate['email'],
        studentName: studentName,
      );
      if (uniqueKey.isEmpty) return;

      final current = placedStudents[uniqueKey];
      final candidateDate = _parseDate(
        candidate['confirmed_at'] ??
            candidate['assigned_at'] ??
            candidate['updated_at'] ??
            candidate['created_at'],
      );
      final currentDate = _parseDate(
        current?['confirmed_at'] ??
            current?['assigned_at'] ??
            current?['updated_at'] ??
            current?['created_at'],
      );
      if (current != null &&
          currentDate != null &&
          candidateDate != null &&
          currentDate.isAfter(candidateDate)) {
        return;
      }

      placedStudents[uniqueKey] = candidate;
    }

    for (final record in _approvalRecords) {
      final choiceStatus = _normalizedText(record['student_choice_status']);
      if (choiceStatus != 'confirmed') continue;

      final trackedStudent = _findTrackedStudent(
        email: record['student_email'],
        studentName: record['student_name'],
      );

      if (trackedStudent == null &&
          !_matchesUniversity(record['university_name'])) {
        continue;
      }

      final studentName = _stringValue(
        trackedStudent?['student_name'] ?? record['student_name'],
        fallback: '',
      );
      upsertPlacedStudent({
        'student_name': studentName,
        'email': _stringValue(
          trackedStudent?['email'] ?? record['student_email'],
          fallback: '',
        ),
        'phone': _stringValue(trackedStudent?['phone'], fallback: ''),
        'registration_number': _stringValue(
          trackedStudent?['registration_number'],
          fallback: '',
        ),
        'program': _stringValue(trackedStudent?['program'], fallback: ''),
        'student_id': trackedStudent?['student_id'],
        'company_name': _stringValue(
          record['company_name'],
          fallback: _stringValue(record['selected_company_name']),
        ),
        'title': _stringValue(
          record['job_title'],
          fallback: _stringValue(record['selected_job_title']),
        ),
        'coordinator_status': _stringValue(
          record['coordinator_status'],
          fallback: 'pending',
        ),
        'confirmed_at': record['confirmed_at'] ?? record['updated_at'],
        'created_at': record['created_at'],
        'university_name': _stringValue(
          trackedStudent?['university_name'] ?? record['university_name'],
        ),
        'placement_location': _stringValue(
          record['placement_location'],
          fallback: '',
        ),
        'coordinator_notes': _stringValue(
          record['coordinator_notes'],
          fallback: '',
        ),
        'placement_source': 'student_confirmation',
      });
    }

    for (final record in _manualPlacementRecords) {
      final trackedStudent = _findTrackedStudent(
        email: record['student_email'],
        studentName: record['student_name'],
      );

      if (trackedStudent == null &&
          !_matchesUniversity(record['university_name'])) {
        continue;
      }

      upsertPlacedStudent({
        'student_name': _stringValue(
          trackedStudent?['student_name'] ?? record['student_name'],
          fallback: '',
        ),
        'email': _stringValue(
          trackedStudent?['email'] ?? record['student_email'],
          fallback: '',
        ),
        'phone': _stringValue(
          trackedStudent?['phone'] ?? record['student_phone'],
          fallback: '',
        ),
        'registration_number': _stringValue(
          trackedStudent?['registration_number'] ??
              record['registration_number'],
          fallback: '',
        ),
        'program': _stringValue(
          trackedStudent?['program'] ?? record['department'],
          fallback: '',
        ),
        'student_id': trackedStudent?['student_id'] ?? record['student_id'],
        'company_name': _stringValue(record['company_name']),
        'title': _stringValue(record['job_title']),
        'coordinator_status': 'assigned',
        'confirmed_at': record['assigned_at'] ?? record['updated_at'],
        'assigned_at': record['assigned_at'],
        'created_at': record['created_at'],
        'updated_at': record['updated_at'],
        'university_name': _stringValue(
          trackedStudent?['university_name'] ?? record['university_name'],
        ),
        'placement_location': _stringValue(
          record['placement_location'],
          fallback: '',
        ),
        'coordinator_notes': _stringValue(
          record['coordinator_notes'],
          fallback: '',
        ),
        'start_date': record['start_date'],
        'end_date': record['end_date'],
        'coordinator_name': _stringValue(
          record['coordinator_name'],
          fallback: '',
        ),
        'placement_source': 'coordinator_assignment',
      });
    }

    final students = placedStudents.values.toList(growable: false);
    students.sort((left, right) {
      final leftDate = _parseDate(left['confirmed_at'] ?? left['created_at']);
      final rightDate = _parseDate(
        right['confirmed_at'] ?? right['created_at'],
      );
      if (leftDate == null && rightDate == null) return 0;
      if (leftDate == null) return 1;
      if (rightDate == null) return -1;
      return rightDate.compareTo(leftDate);
    });
    return students;
  }

  List<Map<String, dynamic>> get _studentsWithoutField {
    final placedKeys = _fieldPlacedStudents
        .map(
          (student) => _studentIdentityKey(
            email: student['email'],
            studentName: student['student_name'],
          ),
        )
        .where((key) => key.isNotEmpty)
        .toSet();

    return _trackedStudents
        .where((student) {
          final studentKey = _studentIdentityKey(
            email: student['email'],
            studentName: student['student_name'],
          );
          return studentKey.isNotEmpty && !placedKeys.contains(studentKey);
        })
        .toList(growable: false);
  }

  int get _dashboardTotalStudentsCount => _dashboardStudentRecords.length;
  int get _dashboardPlacedCount =>
      _dashboardStudentRecords.where((record) => record.isPlaced).length;
  int get _dashboardNotPlacedCount =>
      _dashboardStudentRecords.where((record) => !record.isPlaced).length;
  double get _dashboardPlacementRatio {
    if (_dashboardTotalStudentsCount == 0) return 0;
    return _dashboardPlacedCount / _dashboardTotalStudentsCount;
  }

  List<_CoordinatorStudentRecord> get _dashboardStudentRecords {
    final records = <_CoordinatorStudentRecord>[];
    final addedKeys = <String>{};
    final placedByKey = <String, Map<String, dynamic>>{
      for (final placed in _fieldPlacedStudents)
        _studentIdentityKey(
          email: placed['email'],
          studentName: placed['student_name'],
        ): placed,
    }..remove('');

    Map<String, dynamic>? latestReportFor({
      dynamic email,
      dynamic studentName,
      dynamic companyName,
    }) {
      Map<String, dynamic>? latest;
      DateTime? latestDate;
      for (final report in _companyReports) {
        final matchesStudent =
            _studentIdentityKey(
              email: report['student_email'],
              studentName: report['student_name'],
            ) ==
            _studentIdentityKey(email: email, studentName: studentName);
        final matchesCompany =
            _normalizedText(companyName).isNotEmpty &&
            _normalizedText(report['company_name']) ==
                _normalizedText(companyName);
        if (!matchesStudent && !matchesCompany) continue;
        final reportDate = _parseDate(
          report['updated_at'] ?? report['created_at'],
        );
        if (latest == null ||
            (reportDate != null &&
                reportDate.isAfter(latestDate ?? DateTime(1900)))) {
          latest = report;
          latestDate = reportDate;
        }
      }
      return latest;
    }

    _CoordinatorPlacementStatus resolvePlacedStatus(
      Map<String, dynamic>? latestReport,
      DateTime? lastFeedbackDate,
    ) {
      final issueType = _normalizedText(latestReport?['issue_type']);
      if (issueType == 'absent' ||
          issueType == 'left_without_permission' ||
          issueType == 'other') {
        return _CoordinatorPlacementStatus.needsAttention;
      }
      if (lastFeedbackDate == null) return _CoordinatorPlacementStatus.average;
      if (DateTime.now().difference(lastFeedbackDate).inDays > 14) {
        return _CoordinatorPlacementStatus.average;
      }
      return _CoordinatorPlacementStatus.good;
    }

    void addRecordFromStudent(Map<String, dynamic> student) {
      final key = _studentIdentityKey(
        email: student['email'],
        studentName: student['student_name'],
      );
      if (key.isEmpty || addedKeys.contains(key)) return;
      addedKeys.add(key);

      final placed = placedByKey[key];
      final latestReport = latestReportFor(
        email: student['email'],
        studentName: student['student_name'],
        companyName: placed?['company_name'],
      );
      final lastFeedbackDate = _parseDate(
        latestReport?['updated_at'] ??
            latestReport?['created_at'] ??
            placed?['confirmed_at'] ??
            placed?['created_at'],
      );
      final department = _stringValue(
        student['program'] ?? student['department'],
        fallback: 'Not set',
      );
      final registrationNumber = _stringValue(
        student['registration_number'],
        fallback: _stringValue(student['student_id'], fallback: '-'),
      );

      records.add(
        _CoordinatorStudentRecord(
          studentName: _stringValue(student['student_name']),
          email: _stringValue(student['email'], fallback: ''),
          department: department,
          registrationNumber: registrationNumber,
          companyName: placed == null
              ? null
              : _stringValue(placed['company_name'], fallback: ''),
          status: placed == null
              ? _CoordinatorPlacementStatus.notPlaced
              : resolvePlacedStatus(latestReport, lastFeedbackDate),
          startDate: placed == null
              ? null
              : _formatDashboardDate(
                  placed['confirmed_at'] ?? placed['created_at'],
                ),
          lastFeedback: lastFeedbackDate == null
              ? null
              : _formatDashboardDate(lastFeedbackDate.toIso8601String()),
        ),
      );
    }

    for (final student in _trackedStudents) {
      addRecordFromStudent(student);
    }

    for (final placed in _fieldPlacedStudents) {
      final key = _studentIdentityKey(
        email: placed['email'],
        studentName: placed['student_name'],
      );
      if (key.isEmpty || addedKeys.contains(key)) continue;
      addRecordFromStudent({
        'student_name': placed['student_name'],
        'email': placed['email'],
        'phone': placed['phone'],
        'registration_number': placed['registration_number'],
        'program': placed['program'],
        'student_id': placed['student_id'],
      });
    }

    records.sort(
      (left, right) => left.studentName.toLowerCase().compareTo(
        right.studentName.toLowerCase(),
      ),
    );
    return records;
  }

  List<_CoordinatorCompanyFeedback> get _dashboardCompanyFeedback {
    final companyDueDates = <String, DateTime>{};
    for (final record in _approvalRecords) {
      final companyName = _stringValue(record['company_name'], fallback: '');
      final dueDate = _parseDate(record['reporting_end_date']);
      if (companyName.isEmpty || dueDate == null) continue;
      final existing = companyDueDates[companyName];
      if (existing == null || dueDate.isAfter(existing)) {
        companyDueDates[companyName] = dueDate;
      }
    }

    final latestReportByCompany = <String, DateTime>{};
    for (final report in _companyReports) {
      final companyName = _stringValue(report['company_name'], fallback: '');
      final reportDate = _parseDate(
        report['updated_at'] ?? report['created_at'],
      );
      if (companyName.isEmpty || reportDate == null) continue;
      final existing = latestReportByCompany[companyName];
      if (existing == null || reportDate.isAfter(existing)) {
        latestReportByCompany[companyName] = reportDate;
      }
    }

    final companies = <String>{
      ...companyDueDates.keys,
      ...latestReportByCompany.keys,
    }.toList(growable: false)..sort();

    return companies
        .map((companyName) {
          final dueDate = companyDueDates[companyName];
          final latestReport = latestReportByCompany[companyName];
          final isOverdue =
              dueDate != null &&
              dueDate.isBefore(DateTime.now()) &&
              (latestReport == null || latestReport.isBefore(dueDate));
          return _CoordinatorCompanyFeedback(
            companyName: companyName,
            status: isOverdue
                ? _CoordinatorFeedbackStatus.overdue
                : _CoordinatorFeedbackStatus.received,
            detail: isOverdue
                ? 'Due ${_formatDashboardDate(dueDate.toIso8601String())}'
                : latestReport == null
                ? 'No feedback date available'
                : 'Report received ${_formatDashboardDate(latestReport.toIso8601String())}',
          );
        })
        .toList(growable: false);
  }

  Map<String, dynamic>? _findCompanyContact(String? companyName) {
    final normalizedCompany = _normalizedText(companyName);
    if (normalizedCompany.isEmpty) return null;

    for (final company in _companyContacts) {
      if (_normalizedText(company['company_name']) == normalizedCompany) {
        return company;
      }
    }

    return null;
  }

  List<_CoordinatorDeadlineItem> get _dashboardDeadlines {
    final items = <_CoordinatorDeadlineItem>[];
    final seen = <String>{};
    for (final record in _approvalRecords) {
      final deadline = _parseDate(record['reporting_end_date']);
      final companyName = _stringValue(record['company_name'], fallback: '');
      if (deadline == null ||
          companyName.isEmpty ||
          deadline.isBefore(DateTime.now())) {
        continue;
      }
      final key = '$companyName|${deadline.toIso8601String()}';
      if (!seen.add(key)) continue;
      items.add(
        _CoordinatorDeadlineItem(
          dateLabel: _formatShortMonthDay(deadline.toIso8601String()),
          description: 'Report due from $companyName',
        ),
      );
    }
    items.sort((left, right) => left.dateLabel.compareTo(right.dateLabel));
    return items.take(4).toList(growable: false);
  }

  List<Map<String, dynamic>> get _activeCompanies {
    final uniqueCompanies = <String, Map<String, dynamic>>{};

    for (final company in _companyContacts) {
      final companyName = _stringValue(company['company_name'], fallback: '');
      final normalizedName = _normalizedText(companyName);
      if (normalizedName.isEmpty ||
          uniqueCompanies.containsKey(normalizedName)) {
        continue;
      }
      uniqueCompanies[normalizedName] = company;
    }

    final companies = uniqueCompanies.values.toList(growable: false);
    companies.sort((left, right) {
      final leftName = _stringValue(
        left['company_name'],
        fallback: '',
      ).toLowerCase();
      final rightName = _stringValue(
        right['company_name'],
        fallback: '',
      ).toLowerCase();
      return leftName.compareTo(rightName);
    });
    return companies;
  }

  List<_CoordinatorStudentRecord> get _filteredDashboardStudents {
    Iterable<_CoordinatorStudentRecord> base = _dashboardStudentRecords;
    switch (_selectedDashboardTab) {
      case _CoordinatorDashboardTab.placed:
        base = base.where((record) => record.isPlaced);
        break;
      case _CoordinatorDashboardTab.notPlaced:
        base = base.where((record) => !record.isPlaced);
        break;
      case _CoordinatorDashboardTab.all:
        break;
    }

    final normalizedQuery = _normalizedText(_dashboardSearchQuery);
    return base
        .where((record) {
          final searchTarget = _normalizedText(
            '${record.studentName} ${record.department} ${record.registrationNumber} ${record.companyName ?? ''}',
          );
          final matchesQuery =
              normalizedQuery.isEmpty || searchTarget.contains(normalizedQuery);
          return matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadUniversityPortal();
  }

  @override
  void dispose() {
    _dashboardSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadUniversityPortal() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      final responses = await Future.wait<dynamic>([
        _apiService.getAwardsHomeData(),
        _apiService.getWallOfFame(limit: 24),
        _apiService.getUniversityStudentsOverview(),
        _apiService.getUniversityCompanyContacts(),
        _workspaceService.getApprovalRecords(universityName: _universityName),
        _workspaceService.getManualPlacements(universityName: _universityName),
        _workspaceService.getReportsForUniversity(
          universityName: _universityName,
        ),
      ]);

      final awardsHomeResponse = responses[0] as Map<String, dynamic>;
      final wallResponse = responses[1] as Map<String, dynamic>;
      final studentsResponse = responses[2] as Map<String, dynamic>;
      final companyContactsResponse = responses[3] as Map<String, dynamic>;
      final approvalRecordsResponse =
          responses[4] as List<Map<String, dynamic>>;
      final manualPlacementRecordsResponse =
          responses[5] as List<Map<String, dynamic>>;
      final companyReportsResponse = responses[6] as List<Map<String, dynamic>>;

      final awardsHomeData = awardsHomeResponse['data'] is Map<String, dynamic>
          ? awardsHomeResponse['data'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final studentsData = studentsResponse['data'] is Map<String, dynamic>
          ? studentsResponse['data'] as Map<String, dynamic>
          : const <String, dynamic>{};
      final companyContacts = _mapList(companyContactsResponse['data']);

      setState(() {
        _universityStudentsData = _mapList(studentsData['students']);
        _recentAnnouncements = _mapList(awardsHomeData['recent_announcements']);
        _leaderboard = _mapList(awardsHomeData['leaderboard']);
        _wallOfFame = _mapList(wallResponse['data']);
        _companyContacts = companyContacts;
        _approvalRecords = approvalRecordsResponse;
        _manualPlacementRecords = manualPlacementRecordsResponse;
        _companyReports = companyReportsResponse;
        _isLoading = false;
        _hasError =
            awardsHomeResponse['success'] != true &&
            wallResponse['success'] != true &&
            studentsResponse['success'] != true;
        _errorMessage = _hasError
            ? ApiService.normalizeErrorMessage(
                awardsHomeResponse['message'] ??
                    wallResponse['message'] ??
                    studentsResponse['message'],
                fallback:
                    'University portal loaded with limited information only.',
              )
            : '';
      });
    } catch (error) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = ApiService.normalizeErrorMessage(
          error,
          fallback: 'Failed to load university portal data.',
        );
      });
    }
  }

  List<Map<String, dynamic>> _mapList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) {
          final mapped = <String, dynamic>{};
          for (final entry in item.entries) {
            mapped['${entry.key}'] = entry.value;
          }
          return mapped;
        })
        .toList(growable: false);
  }

  String _stringValue(dynamic value, {String fallback = '-'}) {
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return null;

    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _formatDashboardDate(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day} ${date.year}';
  }

  String _formatShortMonthDay(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '-';
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }

  String _normalizedText(dynamic value) {
    return '${value ?? ''}'
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
  }

  bool _matchesUniversity(dynamic value) {
    final currentUniversity = _normalizedText(_universityName);
    final candidate = _normalizedText(value);
    return currentUniversity.isNotEmpty &&
        candidate.isNotEmpty &&
        currentUniversity == candidate;
  }

  String _studentIdentityKey({dynamic email, dynamic studentName}) {
    final normalizedEmail = _normalizedText(email);
    if (normalizedEmail.isNotEmpty) return 'email:$normalizedEmail';

    final normalizedName = _normalizedText(studentName);
    if (normalizedName.isNotEmpty) return 'name:$normalizedName';

    return '';
  }

  Set<String> get _trackedStudentEmails {
    return _trackedStudents
        .map((student) => _normalizedText(student['email']))
        .where((email) => email.isNotEmpty)
        .toSet();
  }

  Set<String> get _trackedStudentNames {
    return _trackedStudents
        .map((student) => _normalizedText(student['student_name']))
        .where((name) => name.isNotEmpty)
        .toSet();
  }

  Map<String, dynamic>? _findTrackedStudent({
    dynamic email,
    dynamic studentName,
  }) {
    final key = _studentIdentityKey(email: email, studentName: studentName);
    if (key.isEmpty) return null;

    for (final student in _trackedStudents) {
      final studentKey = _studentIdentityKey(
        email: student['email'],
        studentName: student['student_name'],
      );
      if (studentKey == key) return student;
    }

    return null;
  }

  List<Map<String, dynamic>> get _trackedStudents {
    if (_universityStudentsData.isNotEmpty) {
      return _universityStudentsData
          .map((student) {
            return {
              'student_id': student['user_id'] ?? student['student_id'],
              'student_name': _stringValue(
                student['full_name'],
                fallback: _stringValue(student['student_name']),
              ),
              'email': _stringValue(student['email'], fallback: ''),
              'phone': _stringValue(student['phone'], fallback: ''),
              'registration_number': _stringValue(
                student['registration_number'],
                fallback: '',
              ),
              'program': _stringValue(student['program'], fallback: ''),
              'university_name': _stringValue(
                student['university_name'],
                fallback: _universityName,
              ),
              'created_at': student['created_at'],
            };
          })
          .where(
            (student) => _normalizedText(student['student_name']).isNotEmpty,
          )
          .toList(growable: false);
    }

    final all = [..._wallOfFame, ..._recentAnnouncements, ..._leaderboard];
    final byStudent = <String, Map<String, dynamic>>{};

    for (final entry in all) {
      if (!_matchesUniversity(entry['university_name'])) continue;

      final studentName = _stringValue(entry['student_name'], fallback: '');
      final uniqueKey = _studentIdentityKey(
        email: entry['email'],
        studentName: studentName,
      );
      if (studentName.isEmpty || uniqueKey.isEmpty) continue;

      byStudent.putIfAbsent(uniqueKey, () {
        return {
          'student_name': studentName,
          'email': _stringValue(entry['email'], fallback: ''),
          'phone': _stringValue(entry['phone'], fallback: ''),
          'registration_number': _stringValue(
            entry['registration_number'],
            fallback: '',
          ),
          'company_name': _stringValue(entry['company_name']),
          'title': _stringValue(
            entry['title'],
            fallback: _stringValue(entry['award_title'], fallback: 'Placement'),
          ),
          'university_name': _stringValue(
            entry['university_name'],
            fallback: _universityName,
          ),
          'rating': _intValue(entry['rating']),
          'created_at': entry['created_at'],
          'award_date': entry['award_date'],
        };
      });
    }

    final students = byStudent.values.toList(growable: false);
    students.sort((left, right) {
      final leftDate = _parseDate(left['award_date'] ?? left['created_at']);
      final rightDate = _parseDate(right['award_date'] ?? right['created_at']);
      if (leftDate == null && rightDate == null) {
        return _stringValue(
          left['student_name'],
        ).compareTo(_stringValue(right['student_name']));
      }
      if (leftDate == null) return 1;
      if (rightDate == null) return -1;
      return rightDate.compareTo(leftDate);
    });
    return students;
  }

  String get _universityName {
    final user = context.read<AuthProvider>().user;
    final universityData = user?['university_data'] as Map<String, dynamic>?;
    return _stringValue(
      universityData?['university_name'] ??
          universityData?['college_name'] ??
          user?['full_name'],
      fallback: 'University Portal',
    );
  }

  String get _universityId {
    final user = context.read<AuthProvider>().user;
    final universityData = user?['university_data'] as Map<String, dynamic>?;
    return _stringValue(universityData?['university_id'], fallback: '');
  }

  String get _coordinatorName {
    final user = context.read<AuthProvider>().user;
    final universityData = user?['university_data'] as Map<String, dynamic>?;
    return _stringValue(
      universityData?['coordinator_name'] ?? user?['full_name'],
      fallback: 'Coordinator',
    );
  }

  List<String> _getUniversityLogoUrls() {
    final user = context.read<AuthProvider>().user;
    final universityData = user?['university_data'] as Map<String, dynamic>?;
    final logoUrl =
        universityData?['logo_url'] as String? ??
        universityData?['college_logo_url'] as String? ??
        universityData?['university_logo_url'] as String? ??
        user?['profile_image_url'] as String?;
    final normalized = (logoUrl ?? '').trim();
    if (normalized.isEmpty) {
      return const [];
    }

    return _apiService.resolveAssetUrlCandidates(normalized);
  }

  Future<void> _logout() async {
    final language = context.read<LanguageProvider>();
    final authProvider = context.read<AuthProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(language.tr('logout_title')),
        content: Text(language.tr('logout_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(language.tr('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              language.tr('logout'),
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    await authProvider.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(language.tr('logout_success')),
        backgroundColor: Colors.green,
      ),
    );
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UniversityNotificationsScreen()),
    );
  }

  Future<void> _showLanguageDialog() async {
    final language = context.read<LanguageProvider>();
    final currentLanguageCode = language.localeCode;
    final selectedLanguage = await showDialog<String>(
      context: context,
      builder: (_) => LanguagePickerDialog(
        titleText: language.tr('change_language_title'),
        cancelText: language.tr('cancel'),
        applyText: language.tr('apply'),
        currentLanguageCode: currentLanguageCode,
        options: [
          LanguageOption(code: 'en', label: language.nativeLanguageName('en')),
          LanguageOption(code: 'sw', label: language.nativeLanguageName('sw')),
        ],
      ),
    );

    if (selectedLanguage == null ||
        selectedLanguage == currentLanguageCode ||
        !mounted) {
      return;
    }

    await context.read<LanguageProvider>().setLocaleCode(selectedLanguage);
  }

  Future<void> _showChangePasswordDialog() async {
    final messenger = ScaffoldMessenger.of(context);

    await showDialog<void>(
      context: context,
      builder: (_) => _UniversityChangePasswordDialog(
        apiService: _apiService,
        messenger: messenger,
      ),
    );
  }

  Future<void> _handleMoreAction(_UniversityMoreAction action) async {
    switch (action) {
      case _UniversityMoreAction.settings:
        _openNavigationItem(4);
        break;
      case _UniversityMoreAction.language:
        await _showLanguageDialog();
        break;
      case _UniversityMoreAction.logout:
        await _logout();
        break;
    }
  }

  void _openNavigationItem(int index) {
    setState(() => _selectedIndex = index);
  }

  void _openStudentsView(_UniversityStudentView view) {
    setState(() {
      _selectedIndex = 1;
      _selectedStudentView = view;
      switch (view) {
        case _UniversityStudentView.placed:
          _selectedDashboardTab = _CoordinatorDashboardTab.placed;
          break;
        case _UniversityStudentView.noField:
          _selectedDashboardTab = _CoordinatorDashboardTab.notPlaced;
          break;
        case _UniversityStudentView.all:
        case _UniversityStudentView.awarded:
          _selectedDashboardTab = _CoordinatorDashboardTab.all;
          break;
      }
    });
  }

  Map<String, dynamic>? _currentPlacementForStudent({
    dynamic email,
    dynamic studentName,
  }) {
    final key = _studentIdentityKey(email: email, studentName: studentName);
    if (key.isEmpty) return null;

    Map<String, dynamic>? latest;
    DateTime? latestDate;
    for (final placement in _fieldPlacedStudents) {
      final placementKey = _studentIdentityKey(
        email: placement['email'],
        studentName: placement['student_name'],
      );
      if (placementKey != key) continue;

      final placementDate = _parseDate(
        placement['confirmed_at'] ??
            placement['assigned_at'] ??
            placement['updated_at'] ??
            placement['created_at'],
      );
      if (latest == null ||
          (placementDate != null &&
              placementDate.isAfter(latestDate ?? DateTime(1900)))) {
        latest = placement;
        latestDate = placementDate;
      }
    }
    return latest;
  }

  Future<void> _showStudentDetailsSheet(
    _CoordinatorStudentRecord record,
  ) async {
    final trackedStudent = _findTrackedStudent(
      email: record.email,
      studentName: record.studentName,
    );
    final placement = _currentPlacementForStudent(
      email: record.email,
      studentName: record.studentName,
    );

    Widget infoTile(String label, String value) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 132,
              child: Text(
                label,
                style: const TextStyle(
                  color: _universityMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value.isEmpty ? '-' : value,
                style: const TextStyle(
                  color: _universityInk,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _universityInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    record.isPlaced
                        ? 'Student currently has an active placement record.'
                        : 'Student is still waiting for placement.',
                    style: const TextStyle(color: _universityMuted),
                  ),
                  const SizedBox(height: 20),
                  infoTile('Email', record.email),
                  infoTile(
                    'Phone',
                    _stringValue(trackedStudent?['phone'], fallback: ''),
                  ),
                  infoTile('Program', record.department),
                  infoTile('Registration No.', record.registrationNumber),
                  infoTile(
                    'Student ID',
                    _stringValue(trackedStudent?['student_id'], fallback: ''),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Placement Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _universityInk,
                    ),
                  ),
                  const SizedBox(height: 12),
                  infoTile(
                    'Company',
                    _stringValue(placement?['company_name'], fallback: ''),
                  ),
                  infoTile(
                    'Role',
                    _stringValue(placement?['title'], fallback: ''),
                  ),
                  infoTile(
                    'Location',
                    _stringValue(
                      placement?['placement_location'],
                      fallback: '',
                    ),
                  ),
                  infoTile(
                    'Start Date',
                    _formatDashboardDate(placement?['start_date']),
                  ),
                  infoTile(
                    'End Date',
                    _formatDashboardDate(placement?['end_date']),
                  ),
                  infoTile(
                    'Assigned By',
                    _stringValue(
                      placement?['coordinator_name'],
                      fallback: placement == null
                          ? ''
                          : placement['placement_source'] ==
                                'student_confirmation'
                          ? 'Student confirmed placement'
                          : _coordinatorName,
                    ),
                  ),
                  infoTile(
                    'Notes',
                    _stringValue(placement?['coordinator_notes'], fallback: ''),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 10,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Close'),
                        ),
                        if (!record.isPlaced)
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _openPlacementAssignmentDialog(record);
                            },
                            icon: const Icon(Icons.add_link_rounded),
                            label: const Text('Assign'),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDateTime(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return '-';
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$day/$month/${date.year} $hour:$minute';
  }

  Color _reportIssueColor(String issueType) {
    switch (issueType) {
      case 'absent':
        return _coordinatorWarning;
      case 'left_without_permission':
        return _coordinatorDanger;
      default:
        return _coordinatorPrimary;
    }
  }

  String _reportIssueLabel(String issueType) {
    switch (issueType) {
      case 'absent':
        return 'Not attending';
      case 'left_without_permission':
        return 'Left workplace without permission';
      default:
        return 'Conduct issue';
    }
  }

  Future<void> _showCompanyReportSheet(String companyName) async {
    final reports =
        _companyReports
            .where(
              (report) =>
                  _normalizedText(report['company_name']) ==
                  _normalizedText(companyName),
            )
            .toList(growable: false)
          ..sort((left, right) {
            final leftDate =
                _parseDate(left['updated_at'] ?? left['created_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            final rightDate =
                _parseDate(right['updated_at'] ?? right['created_at']) ??
                DateTime.fromMillisecondsSinceEpoch(0);
            return rightDate.compareTo(leftDate);
          });

    if (reports.isEmpty) {
      _showCoordinatorMessage(
        'No report details found for $companyName.',
        backgroundColor: _coordinatorDanger,
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.58,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$companyName Reports',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _universityInk,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${reports.length} report${reports.length == 1 ? '' : 's'} received from this company.',
                        style: const TextStyle(color: _universityMuted),
                      ),
                      const SizedBox(height: 18),
                      Expanded(
                        child: ListView.separated(
                          itemCount: reports.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final report = reports[index];
                            final issueType = _normalizedText(
                              report['issue_type'],
                            );
                            final issueColor = _reportIssueColor(issueType);

                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _universityBorder),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: issueColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.report_problem_rounded,
                                          color: issueColor,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _stringValue(
                                                report['student_name'],
                                                fallback: 'Student',
                                              ),
                                              style: const TextStyle(
                                                color: _universityInk,
                                                fontWeight: FontWeight.w800,
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              _stringValue(
                                                report['job_title'],
                                                fallback: 'Placement',
                                              ),
                                              style: const TextStyle(
                                                color: _universityMuted,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: issueColor.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          _reportIssueLabel(issueType),
                                          style: TextStyle(
                                            color: issueColor,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    _stringValue(
                                      report['description'],
                                      fallback: '-',
                                    ),
                                    style: const TextStyle(
                                      color: _universityInk,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 16,
                                    runSpacing: 10,
                                    children: [
                                      Text(
                                        'Student email: ${_stringValue(report['student_email'], fallback: '-')}',
                                        style: const TextStyle(
                                          color: _universityMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        'Received: ${_formatDateTime(report['created_at'])}',
                                        style: const TextStyle(
                                          color: _universityMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
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
    );
  }

  Future<void> _showCompanyContactSheet(String? companyName) async {
    final normalizedName = _stringValue(companyName, fallback: '').trim();
    if (normalizedName.isEmpty) {
      _showCoordinatorMessage(
        'Company name is not available for this contact.',
        backgroundColor: _coordinatorDanger,
      );
      return;
    }

    final company = _findCompanyContact(normalizedName);
    final phone = _stringValue(company?['phone'], fallback: '');
    final email = _stringValue(company?['email'], fallback: '');
    final location = _stringValue(company?['location'], fallback: '');
    final website = _stringValue(company?['website_url'], fallback: '');
    final industry = _stringValue(company?['industry'], fallback: '');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        Widget infoRow(IconData icon, String label, String value) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _coordinatorSuccess.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: _coordinatorSuccess),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: _universityMuted,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value.isEmpty ? 'Not available' : value,
                        style: const TextStyle(
                          color: _universityInk,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      normalizedName,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _universityInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Company contact details for coordinator follow-up.',
                      style: TextStyle(color: _universityMuted),
                    ),
                    const SizedBox(height: 18),
                    infoRow(Icons.phone_outlined, 'Phone', phone),
                    infoRow(Icons.email_outlined, 'Email', email),
                    infoRow(Icons.location_on_outlined, 'Location', location),
                    infoRow(Icons.language_outlined, 'Website', website),
                    if (industry.isNotEmpty)
                      infoRow(Icons.apartment_outlined, 'Industry', industry),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _universityMist,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Use the phone number above to contact the company directly.',
                        style: TextStyle(
                          color: _coordinatorPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showActiveCompaniesSheet() async {
    final searchController = TextEditingController();
    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          String query = '';

          return StatefulBuilder(
            builder: (context, setModalState) {
              final filteredCompanies = _activeCompanies
                  .where((company) {
                    if (query.trim().isEmpty) return true;
                    final target = _normalizedText(
                      '${company['company_name'] ?? ''} ${company['industry'] ?? ''} ${company['location'] ?? ''}',
                    );
                    return target.contains(_normalizedText(query));
                  })
                  .toList(growable: false);

              return SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.72,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Active Organizations',
                              style: TextStyle(
                                color: _universityInk,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${filteredCompanies.length} organizations available for coordinator follow-up.',
                              style: const TextStyle(color: _universityMuted),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: searchController,
                              onChanged: (value) {
                                setModalState(() => query = value);
                              },
                              decoration: InputDecoration(
                                hintText:
                                    'Filter by organization, industry, or location',
                                prefixIcon: const Icon(Icons.search_rounded),
                                suffixIcon: query.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          searchController.clear();
                                          setModalState(() => query = '');
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: _universityBorder,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: _universityBorder,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Expanded(
                              child: filteredCompanies.isEmpty
                                  ? const Center(
                                      child: _EmptyStateCard(
                                        title:
                                            'No organizations match your filter',
                                        message:
                                            'Try a different organization keyword.',
                                        icon: Icons.business_center_outlined,
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: filteredCompanies.length,
                                      separatorBuilder: (_, _) =>
                                          const SizedBox(height: 12),
                                      itemBuilder: (context, index) {
                                        final company =
                                            filteredCompanies[index];
                                        final companyName = _stringValue(
                                          company['company_name'],
                                          fallback: 'Unknown company',
                                        );
                                        final industry = _stringValue(
                                          company['industry'],
                                          fallback: '',
                                        );
                                        final location = _stringValue(
                                          company['location'],
                                          fallback: '',
                                        );
                                        final phone = _stringValue(
                                          company['phone'],
                                          fallback: 'No phone',
                                        );

                                        return InkWell(
                                          onTap: () async {
                                            Navigator.of(context).pop();
                                            await _showCompanyContactSheet(
                                              companyName,
                                            );
                                          },
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                              border: Border.all(
                                                color: _universityBorder,
                                              ),
                                            ),
                                            child: Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Container(
                                                  width: 44,
                                                  height: 44,
                                                  decoration: BoxDecoration(
                                                    color: _universityMist,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.apartment_rounded,
                                                    color: _coordinatorPrimary,
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        companyName,
                                                        style: const TextStyle(
                                                          color: _universityInk,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                        ),
                                                      ),
                                                      if (industry
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          industry,
                                                          style: const TextStyle(
                                                            color:
                                                                _universityMuted,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                      if (location
                                                          .isNotEmpty) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          location,
                                                          style: const TextStyle(
                                                            color:
                                                                _universityMuted,
                                                          ),
                                                        ),
                                                      ],
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        phone,
                                                        style: const TextStyle(
                                                          color:
                                                              _coordinatorPrimary,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                const Icon(
                                                  Icons.chevron_right_rounded,
                                                  color: _universityMuted,
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
          );
        },
      );
    } finally {
      searchController.dispose();
    }
  }

  Future<void> _openPlacementAssignmentDialog(
    _CoordinatorStudentRecord record,
  ) async {
    if (record.email.trim().isEmpty) {
      _showCoordinatorMessage(
        'This student has no email address, so assignment notification cannot be sent.',
        backgroundColor: _coordinatorDanger,
      );
      return;
    }

    final companyController = TextEditingController();
    final roleController = TextEditingController();
    final locationController = TextEditingController();
    final notesController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> pickDate(bool isStart) async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: isStart
                      ? (startDate ?? DateTime.now())
                      : (endDate ?? startDate ?? DateTime.now()),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (picked == null) return;
                setModalState(() {
                  if (isStart) {
                    startDate = picked;
                    if (endDate != null && endDate!.isBefore(picked)) {
                      endDate = picked;
                    }
                  } else {
                    endDate = picked;
                  }
                });
              }

              String formatPickedDate(DateTime? value) {
                if (value == null) return 'Select date';
                return _formatDashboardDate(value.toIso8601String());
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                title: Text('Assign Placement to ${record.studentName}'),
                content: SizedBox(
                  width: 460,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: companyController,
                          decoration: const InputDecoration(
                            labelText: 'Company / Organization',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: roleController,
                          decoration: const InputDecoration(
                            labelText: 'Role / Position',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: locationController,
                          decoration: const InputDecoration(
                            labelText: 'Placement Location / Department',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => pickDate(true),
                                icon: const Icon(Icons.calendar_today_rounded),
                                label: Text(formatPickedDate(startDate)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => pickDate(false),
                                icon: const Icon(Icons.event_available_rounded),
                                label: Text(formatPickedDate(endDate)),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: notesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Coordinator Notes',
                            hintText: 'Optional instructions for the student.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final companyName = companyController.text.trim();
                      final role = roleController.text.trim();
                      final location = locationController.text.trim();
                      if (companyName.isEmpty ||
                          role.isEmpty ||
                          location.isEmpty) {
                        _showCoordinatorMessage(
                          'Company, role, and placement location are required.',
                          backgroundColor: _coordinatorDanger,
                        );
                        return;
                      }

                      await _workspaceService.assignManualPlacement(
                        studentName: record.studentName,
                        studentEmail: record.email,
                        studentPhone: _stringValue(
                          _findTrackedStudent(
                            email: record.email,
                            studentName: record.studentName,
                          )?['phone'],
                          fallback: '',
                        ),
                        registrationNumber: record.registrationNumber,
                        department: record.department,
                        studentId: _stringValue(
                          _findTrackedStudent(
                            email: record.email,
                            studentName: record.studentName,
                          )?['student_id'],
                          fallback: '',
                        ),
                        universityName: _universityName,
                        coordinatorName: _coordinatorName,
                        companyName: companyName,
                        trainingTitle: role,
                        placementLocation: location,
                        startDate: startDate?.toIso8601String(),
                        endDate: endDate?.toIso8601String(),
                        coordinatorNotes: notesController.text.trim(),
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('Save Assignment'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (saved == true) {
        await _loadUniversityPortal();
        if (!mounted) return;
        _showCoordinatorMessage(
          'Placement assigned successfully and student notification sent.',
          backgroundColor: _coordinatorSuccess,
        );
      }
    } finally {
      companyController.dispose();
      roleController.dispose();
      locationController.dispose();
      notesController.dispose();
    }
  }

  void _showCoordinatorMessage(String message, {Color? backgroundColor}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showAppSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor ?? _coordinatorPrimary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _exportStudents() async {
    final buffer = StringBuffer();
    String filename = '';
    switch (_selectedStudentView) {
      case _UniversityStudentView.all:
        buffer.writeln('Name,Email,Phone');
        filename = 'all_students.csv';
        for (final student in _trackedStudents) {
          buffer.writeln(
            [
              _csvCell(_stringValue(student['student_name'])),
              _csvCell(_stringValue(student['email'])),
              _csvCell(_stringValue(student['phone'])),
            ].join(','),
          );
        }
        break;
      case _UniversityStudentView.awarded:
        buffer.writeln('Name,Email,Company,Award');
        filename = 'awarded_students.csv';
        for (final record in _awardedStudents) {
          buffer.writeln(
            [
              _csvCell(_stringValue(record['student_name'])),
              _csvCell(_stringValue(record['email'])),
              _csvCell(_stringValue(record['company_name'])),
              _csvCell(_stringValue(record['title'])),
            ].join(','),
          );
        }
        break;
      case _UniversityStudentView.placed:
        buffer.writeln('Name,Email,Company,Position');
        filename = 'placed_students.csv';
        for (final record in _fieldPlacedStudents) {
          buffer.writeln(
            [
              _csvCell(_stringValue(record['student_name'])),
              _csvCell(_stringValue(record['email'])),
              _csvCell(_stringValue(record['company_name'])),
              _csvCell(_stringValue(record['title'])),
            ].join(','),
          );
        }
        break;
      case _UniversityStudentView.noField:
        buffer.writeln('Name,Email,Phone');
        filename = 'not_placed_students.csv';
        for (final student in _studentsWithoutField) {
          buffer.writeln(
            [
              _csvCell(_stringValue(student['student_name'])),
              _csvCell(_stringValue(student['email'])),
              _csvCell(_stringValue(student['phone'])),
            ].join(','),
          );
        }
        break;
    }

    try {
      await saveExportFile(
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(buffer.toString())),
        mimeType: 'text/csv',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text(
            'Export successful',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          backgroundColor: const Color(0xFF15803D),
          behavior: SnackBarBehavior.floating,
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showAppSnackBar(
        SnackBar(
          content: Text('Failed to export students: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _csvCell(String value) => '"${value.replaceAll('"', '""')}"';

  List<_UniversityNavigationItem> _navigationItems() {
    return const [
      _UniversityNavigationItem(
        label: 'Dashboard',
        icon: Icons.dashboard_rounded,
        subtitle: '',
      ),
      _UniversityNavigationItem(
        label: 'Students',
        icon: Icons.school_rounded,
        subtitle: '',
      ),
      _UniversityNavigationItem(
        label: 'Reports',
        icon: Icons.report_problem_rounded,
        subtitle: '',
      ),
      _UniversityNavigationItem(
        label: 'Announcements',
        icon: Icons.campaign_rounded,
        subtitle: '',
      ),
    ];
  }

  IconData _inactiveNavigationIcon(IconData icon) {
    if (icon == Icons.dashboard_rounded) {
      return Icons.dashboard_outlined;
    }
    if (icon == Icons.school_rounded) {
      return Icons.school_outlined;
    }
    if (icon == Icons.report_problem_rounded) {
      return Icons.report_problem_outlined;
    }
    if (icon == Icons.campaign_rounded) {
      return Icons.campaign_outlined;
    }
    return icon;
  }

  Widget _buildBody(bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Loading university portal...'),
          ],
        ),
      );
    }

    final pages = [
      _buildDashboardPage(isDesktop),
      _buildStudentsPage(),
      _buildReportsPage(),
      _buildAnnouncementsPage(),
      _buildSettingsPage(),
    ];

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: KeyedSubtree(
        key: ValueKey(_selectedIndex),
        child: pages[_selectedIndex],
      ),
    );
  }

  Widget _buildDashboardPage(bool isDesktop) {
    final stats = [
      _MetricCardData(
        title: 'Total Students',
        value: '$_dashboardTotalStudentsCount',
        caption: 'Students under coordination',
        icon: Icons.groups_rounded,
        color: _coordinatorPrimary,
        navigationIndex: 1,
        studentView: _UniversityStudentView.all,
      ),
      _MetricCardData(
        title: 'Placed',
        value: '$_dashboardPlacedCount',
        caption:
            '${(_dashboardPlacementRatio * 100).round()}% in field placement',
        icon: Icons.work_history_rounded,
        color: _coordinatorSuccess,
        navigationIndex: 1,
        studentView: _UniversityStudentView.placed,
      ),
      _MetricCardData(
        title: 'Not Placed',
        value: '$_dashboardNotPlacedCount',
        caption:
            '${(100 - (_dashboardPlacementRatio * 100).round())}% still waiting',
        icon: Icons.person_off_rounded,
        color: _coordinatorDanger,
        navigationIndex: 1,
        studentView: _UniversityStudentView.noField,
      ),
      _MetricCardData(
        title: 'Active Organizations',
        value: '${_activeCompanies.length}',
        caption: 'Tap to filter organization contacts',
        icon: Icons.apartment_rounded,
        color: _coordinatorSecondary,
        onTap: _showActiveCompaniesSheet,
      ),
    ];

    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 680;
    final isWideLayout = screenWidth >= 1200;
    final listPadding = isCompact
        ? const EdgeInsets.all(12)
        : const EdgeInsets.all(16);

    final mainColumn = Column(
      children: [
        _buildPlacementProgressSection(),
        const SizedBox(height: 12),
        _buildCompanyFeedbackTracker(),
      ],
    );

    final sideColumn = Column(children: [_buildUpcomingDeadlinesSection()]);

    return RefreshIndicator(
      onRefresh: _loadUniversityPortal,
      child: ListView(
        padding: listPadding,
        children: [
          if (_hasError)
            _InlineBanner(
              color: Colors.red.shade700,
              background: Colors.red.shade50,
              icon: Icons.warning_amber_rounded,
              title: 'Some sections are showing fallback data',
              message: _errorMessage,
            ),
          if (_hasError) const SizedBox(height: 16),
          _PageHeader(title: 'Dashboard', subtitle: ''),
          const SizedBox(height: 16),
          _buildDashboardSpotlight(),
          const SizedBox(height: 16),
          const Text(
            'Overview',
            style: TextStyle(
              color: _universityInk,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricGrid(stats, isDesktop: isDesktop),
          const SizedBox(height: 12),
          if (isWideLayout)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: mainColumn),
                const SizedBox(width: 12),
                SizedBox(width: 320, child: sideColumn),
              ],
            )
          else ...[
            mainColumn,
            const SizedBox(height: 12),
            sideColumn,
          ],
        ],
      ),
    );
  }

  Widget _buildDashboardSpotlight() {
    final placementPercentage = (_dashboardPlacementRatio * 100).round();

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_universityNavy, _coordinatorPrimary, _universityTeal],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _universityNavy.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.18),
                  ),
                ),
                child: const Icon(
                  Icons.space_dashboard_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _universityName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'University Dashboard',
                      style: TextStyle(
                        color: Color(0xFFD8E8F7),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 430;
                if (isNarrow) {
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 16,
                    runSpacing: 14,
                    children: [
                      _buildHeroStat(
                        label: 'Students',
                        value: '$_dashboardTotalStudentsCount',
                      ),
                      _buildHeroStat(
                        label: 'Placed',
                        value: '$placementPercentage%',
                      ),
                      _buildHeroStat(
                        label: 'Waiting',
                        value: '$_dashboardNotPlacedCount',
                      ),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: _buildHeroStat(
                        label: 'Students',
                        value: '$_dashboardTotalStudentsCount',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    Expanded(
                      child: _buildHeroStat(
                        label: 'Placed',
                        value: '$placementPercentage%',
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 42,
                      color: Colors.white.withValues(alpha: 0.16),
                    ),
                    Expanded(
                      child: _buildHeroStat(
                        label: 'Waiting',
                        value: '$_dashboardNotPlacedCount',
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({required String label, required String value}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFD8E8F7),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricGrid(
    List<_MetricCardData> stats, {
    required bool isDesktop,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = isDesktop
        ? 5
        : screenWidth >= 760
        ? 3
        : 2;
    final spacing = screenWidth < 400 ? 8.0 : 12.0;
    final childAspectRatio = isDesktop
        ? 2.8
        : screenWidth < 400
        ? 1.8
        : 2.15;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: spacing,
        mainAxisSpacing: spacing,
        childAspectRatio: childAspectRatio,
      ),
      itemBuilder: (context, index) => _MetricCard(
        data: stats[index],
        onTap: () {
          final metricAction = stats[index].onTap;
          if (metricAction != null) {
            metricAction();
            return;
          }

          final studentView = stats[index].studentView;
          if (studentView != null) {
            _openStudentsView(studentView);
            return;
          }

          final navigationIndex = stats[index].navigationIndex;
          if (navigationIndex != null) {
            _openNavigationItem(navigationIndex);
          }
        },
      ),
    );
  }

  Widget _buildPlacementProgressSection() {
    final percentage = (_dashboardPlacementRatio * 100).round();

    return _buildSectionCard(
      title: 'Placement Progress',
      subtitle: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$percentage%',
                style: const TextStyle(
                  color: _coordinatorPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'of students are currently placed',
                style: TextStyle(
                  color: _universityMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 14,
              value: _dashboardPlacementRatio,
              backgroundColor: const Color(0xFFD9DDE3),
              valueColor: const AlwaysStoppedAnimation<Color>(
                _coordinatorSuccess,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _LegendPill(
                color: _coordinatorSuccess,
                label:
                    'Placed $_dashboardPlacedCount (${(_dashboardPlacementRatio * 100).round()}%)',
              ),
              _LegendPill(
                color: const Color(0xFFB8C0CC),
                label:
                    'Not placed $_dashboardNotPlacedCount (${(100 - (_dashboardPlacementRatio * 100).round())}%)',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompanyFeedbackTracker() {
    final overdueItems = _dashboardCompanyFeedback
        .where((item) => item.status == _CoordinatorFeedbackStatus.overdue)
        .toList(growable: false);
    final receivedItems = _dashboardCompanyFeedback
        .where((item) => item.status == _CoordinatorFeedbackStatus.received)
        .toList(growable: false);

    return _buildSectionCard(
      title: 'Company Feedback Tracker',
      subtitle: '',
      child: Column(
        children: [
          if (overdueItems.isNotEmpty) ...[
            _buildFeedbackGroup(
              title: 'Overdue Companies',
              tone: _coordinatorDanger,
              items: overdueItems,
            ),
            if (receivedItems.isNotEmpty) const SizedBox(height: 12),
          ],
          if (receivedItems.isNotEmpty)
            _buildFeedbackGroup(
              title: 'Received Companies',
              tone: _coordinatorSuccess,
              items: receivedItems,
            )
          else if (overdueItems.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'No company records available yet.',
                style: TextStyle(color: _universityMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeedbackGroup({
    required String title,
    required Color tone,
    required List<_CoordinatorCompanyFeedback> items,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(color: tone, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'No company records available yet.',
              style: const TextStyle(color: _universityMuted),
            )
          else
            ...items.map((item) {
              final isOverdue =
                  item.status == _CoordinatorFeedbackStatus.overdue;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tone.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isOverdue
                              ? Icons.notifications_active_rounded
                              : Icons.fact_check_rounded,
                          color: tone,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.companyName,
                              style: const TextStyle(
                                color: _universityInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.detail,
                              style: const TextStyle(color: _universityMuted),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: isOverdue
                            ? [
                                _ActionPillButton(
                                  label: 'Remind',
                                  icon: Icons.notifications_outlined,
                                  color: _coordinatorWarning,
                                  onTap: () => _showCoordinatorMessage(
                                    'Reminder sent to ${item.companyName}',
                                    backgroundColor: _coordinatorWarning,
                                  ),
                                ),
                                _ActionPillButton(
                                  label: 'Call',
                                  icon: Icons.call_outlined,
                                  color: _coordinatorPrimary,
                                  onTap: () => _showCompanyContactSheet(
                                    item.companyName,
                                  ),
                                ),
                              ]
                            : [
                                _ActionPillButton(
                                  label: 'View Report',
                                  icon: Icons.visibility_outlined,
                                  color: _coordinatorSuccess,
                                  onTap: () =>
                                      _showCompanyReportSheet(item.companyName),
                                ),
                              ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildDashboardStudentsSection() {
    final filteredStudents = _filteredDashboardStudents;

    return _buildSectionCard(
      title: 'Students Management',
      subtitle: '',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _DashboardTabButton(
                label: 'All ($_dashboardTotalStudentsCount)',
                isSelected:
                    _selectedDashboardTab == _CoordinatorDashboardTab.all,
                onTap: () => setState(
                  () => _selectedDashboardTab = _CoordinatorDashboardTab.all,
                ),
              ),
              _DashboardTabButton(
                label: 'Placed ($_dashboardPlacedCount)',
                isSelected:
                    _selectedDashboardTab == _CoordinatorDashboardTab.placed,
                onTap: () => setState(
                  () => _selectedDashboardTab = _CoordinatorDashboardTab.placed,
                ),
              ),
              _DashboardTabButton(
                label: 'Not Placed ($_dashboardNotPlacedCount)',
                isSelected:
                    _selectedDashboardTab == _CoordinatorDashboardTab.notPlaced,
                onTap: () => setState(
                  () => _selectedDashboardTab =
                      _CoordinatorDashboardTab.notPlaced,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildDashboardStudentFilters(),
          const SizedBox(height: 14),
          if (filteredStudents.isEmpty)
            const _EmptyStateCard(
              title: 'No students match your filters',
              message: 'Try another search keyword.',
              icon: Icons.search_off_rounded,
            )
          else
            _buildDashboardStudentTable(filteredStudents),
        ],
      ),
    );
  }

  Widget _buildDashboardStudentFilters() {
    return TextField(
      controller: _dashboardSearchController,
      onChanged: (value) {
        setState(() => _dashboardSearchQuery = value);
      },
      decoration: InputDecoration(
        hintText: 'Search student by name, company, or reg number',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _dashboardSearchQuery.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _dashboardSearchController.clear();
                  setState(() => _dashboardSearchQuery = '');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _universityBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _universityBorder),
        ),
      ),
    );
  }

  Widget _buildDashboardStudentTable(List<_CoordinatorStudentRecord> records) {
    switch (_selectedDashboardTab) {
      case _CoordinatorDashboardTab.placed:
        return _buildPlacedStudentsTable(records);
      case _CoordinatorDashboardTab.notPlaced:
        return _buildNotPlacedStudentsTable(records);
      case _CoordinatorDashboardTab.all:
        return _buildAllStudentsTable(records);
    }
  }

  Widget _buildPlacedStudentsTable(List<_CoordinatorStudentRecord> records) {
    return _buildDashboardDataTable(
      minWidth: 1080,
      columns: const [
        DataColumn(label: Text('Student')),
        DataColumn(label: Text('Program')),
        DataColumn(label: Text('Company')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Start Date')),
        DataColumn(label: Text('Last Feedback')),
        DataColumn(label: Text('Action')),
      ],
      rows: records
          .map(
            (record) => _buildInteractiveDataRow(
              cells: [
                DataCell(Text(record.studentName)),
                DataCell(Text(record.department)),
                DataCell(Text(record.companyName ?? '-')),
                DataCell(_PlacementStatusChip(status: record.status)),
                DataCell(Text(record.startDate ?? '-')),
                DataCell(Text(record.lastFeedback ?? '-')),
                DataCell(
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ActionPillButton(
                        label: 'View',
                        icon: Icons.visibility_outlined,
                        color: _coordinatorPrimary,
                        onTap: () => _showStudentDetailsSheet(record),
                      ),
                      _ActionPillButton(
                        label: 'Call',
                        icon: Icons.call_outlined,
                        color: _coordinatorSuccess,
                        onTap: () =>
                            _showCompanyContactSheet(record.companyName),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildNotPlacedStudentsTable(List<_CoordinatorStudentRecord> records) {
    return _buildDashboardDataTable(
      minWidth: 860,
      columns: const [
        DataColumn(label: Text('Student')),
        DataColumn(label: Text('Program')),
        DataColumn(label: Text('Registration Number')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Action')),
      ],
      rows: records
          .map(
            (record) => _buildInteractiveDataRow(
              cells: [
                DataCell(Text(record.studentName)),
                DataCell(Text(record.department)),
                DataCell(Text(record.registrationNumber)),
                const DataCell(
                  _PlacementStatusChip(
                    status: _CoordinatorPlacementStatus.notPlaced,
                  ),
                ),
                DataCell(
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _ActionPillButton(
                        label: 'Assign',
                        icon: Icons.add_link_rounded,
                        color: _coordinatorSuccess,
                        onTap: () => _openPlacementAssignmentDialog(record),
                      ),
                      _ActionPillButton(
                        label: 'View',
                        icon: Icons.visibility_outlined,
                        color: _coordinatorPrimary,
                        onTap: () => _showStudentDetailsSheet(record),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildAllStudentsTable(List<_CoordinatorStudentRecord> records) {
    return _buildDashboardDataTable(
      minWidth: 1180,
      columns: const [
        DataColumn(label: Text('Student')),
        DataColumn(label: Text('Email')),
        DataColumn(label: Text('Program')),
        DataColumn(label: Text('Registration Number')),
        DataColumn(label: Text('Placement')),
        DataColumn(label: Text('Status')),
        DataColumn(label: Text('Action')),
      ],
      rows: records
          .map(
            (record) => _buildInteractiveDataRow(
              cells: [
                DataCell(Text(record.studentName)),
                DataCell(
                  Text(
                    record.email.isEmpty ? '-' : record.email,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DataCell(Text(record.department)),
                DataCell(Text(record.registrationNumber)),
                DataCell(Text(record.isPlaced ? 'Placed' : 'Not Placed')),
                DataCell(_PlacementStatusChip(status: record.status)),
                DataCell(
                  record.isPlaced
                      ? Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ActionPillButton(
                              label: 'View',
                              icon: Icons.visibility_outlined,
                              color: _coordinatorPrimary,
                              onTap: () => _showStudentDetailsSheet(record),
                            ),
                            _ActionPillButton(
                              label: 'Call',
                              icon: Icons.call_outlined,
                              color: _coordinatorSuccess,
                              onTap: () =>
                                  _showCompanyContactSheet(record.companyName),
                            ),
                          ],
                        )
                      : Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _ActionPillButton(
                              label: 'Assign',
                              icon: Icons.add_link_rounded,
                              color: _coordinatorSuccess,
                              onTap: () =>
                                  _openPlacementAssignmentDialog(record),
                            ),
                            _ActionPillButton(
                              label: 'View',
                              icon: Icons.visibility_outlined,
                              color: _coordinatorPrimary,
                              onTap: () => _showStudentDetailsSheet(record),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildDashboardDataTable({
    required List<DataColumn> columns,
    required List<DataRow> rows,
    required double minWidth,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final tableWidth = math.max(minWidth, constraints.maxWidth);
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFD6E2EE)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: tableWidth),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFDCEAF7),
                ),
                headingTextStyle: const TextStyle(
                  color: _coordinatorPrimary,
                  fontWeight: FontWeight.w800,
                ),
                dataTextStyle: const TextStyle(color: _universityInk),
                dataRowMinHeight: 72,
                dataRowMaxHeight: 88,
                headingRowHeight: 66,
                columnSpacing: 28,
                horizontalMargin: 16,
                dividerThickness: 0.6,
                showBottomBorder: true,
                columns: columns,
                rows: rows,
              ),
            ),
          ),
        );
      },
    );
  }

  DataRow _buildInteractiveDataRow({required List<DataCell> cells}) {
    return DataRow(
      color: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.hovered)) {
          return _universityMist.withValues(alpha: 0.55);
        }
        return null;
      }),
      cells: cells,
    );
  }

  Widget _buildUpcomingDeadlinesSection() {
    final deadlines = _dashboardDeadlines;
    return _buildSectionCard(
      title: 'Upcoming Deadlines',
      subtitle: '',
      child: deadlines.isEmpty
          ? const Text(
              'No upcoming reporting deadlines available.',
              style: TextStyle(color: _universityMuted),
            )
          : Column(
              children: deadlines
                  .map(
                    (item) => _TimelineTile(
                      dateLabel: item.dateLabel,
                      description: item.description,
                      accent: _coordinatorSecondary,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildStudentsPage() {
    final screenWidth = MediaQuery.of(context).size.width;
    final pagePadding = screenWidth < 400
        ? const EdgeInsets.all(12)
        : const EdgeInsets.all(20);

    return ListView(
      padding: pagePadding,
      children: [
        _PageHeader(
          title: 'Students',
          subtitle: '',
          trailing: ElevatedButton.icon(
            onPressed: _exportStudents,
            icon: const Icon(Icons.download),
            label: const Text('Export'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _universityNavy,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDashboardStudentsSection(),
      ],
    );
  }

  Widget _buildReportsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PageHeader(title: 'Reports / Complaints', subtitle: ''),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Company Reports',
          subtitle: '',
          child: CompanyReportsBoard(universityName: _universityName),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PageHeader(title: 'Announcements', subtitle: ''),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Coordinator Announcement Center',
          subtitle: '',
          child: CoordinatorAnnouncementCenter(
            universityId: _universityId,
            universityName: _universityName,
            coordinatorName: _coordinatorName,
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Recent Announcements',
          subtitle: '',
          child: _AnnouncementList(announcements: _recentAnnouncements),
        ),
      ],
    );
  }

  Widget _buildSettingsPage() {
    final user = context.watch<AuthProvider>().user;
    final universityData = user?['university_data'] as Map<String, dynamic>?;
    final universityLogoUrls = _getUniversityLogoUrls();
    final institutionName = _stringValue(
      universityData?['college_name'],
      fallback: 'University',
    );
    final coordinatorName = _stringValue(
      universityData?['coordinator_name'],
      fallback: 'Coordinator',
    );
    final email = _stringValue(user?['email'], fallback: 'Not available');

    final settings = [
      {
        'label': 'University name',
        'value': institutionName,
        'icon': Icons.account_balance_rounded,
      },
      {
        'label': 'Registration number',
        'value': _stringValue(universityData?['registration_number']),
        'icon': Icons.badge_outlined,
      },
      {
        'label': 'Coordinator',
        'value': coordinatorName,
        'icon': Icons.person_outline_rounded,
      },
      {
        'label': 'Coordinator phone',
        'value': _stringValue(universityData?['coordinator_phone']),
        'icon': Icons.phone_outlined,
      },
      {'label': 'Email', 'value': email, 'icon': Icons.mail_outline_rounded},
      {
        'label': 'Location',
        'value':
            '${_stringValue(universityData?['district'])}, ${_stringValue(universityData?['region'])}',
        'icon': Icons.location_on_outlined,
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const _PageHeader(title: 'Settings', subtitle: ''),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'University Profile',
          subtitle: '',
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: _universityMist,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: _universityBorder),
                ),
                child: Row(
                  children: [
                    _UniversityHeroAvatar(imageUrls: universityLogoUrls),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            institutionName,
                            style: const TextStyle(
                              color: _universityInk,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            coordinatorName,
                            style: const TextStyle(
                              color: _universityMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _universityInk,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxWidth < 720;
                  final spacing = 12.0;
                  final itemWidth = compact
                      ? constraints.maxWidth
                      : (constraints.maxWidth - spacing) / 2;

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: settings
                        .map((item) {
                          return SizedBox(
                            width: itemWidth,
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _universityBorder),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: _universityMist,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: Icon(
                                      item['icon'] as IconData,
                                      color: _universityNavy,
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (item['label'] ?? '').toString(),
                                          style: const TextStyle(
                                            color: _universityMuted,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          (item['value'] ?? '').toString(),
                                          style: const TextStyle(
                                            color: _universityInk,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        })
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Security',
          subtitle: '',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _showChangePasswordDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _universityNavy,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.lock_reset_rounded),
                label: const Text('Change Password'),
              ),
              ElevatedButton.icon(
                onPressed: _logout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _coordinatorDanger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    Widget? trailing,
  }) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 400;
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.all(isCompact ? 8 : 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isCompact ? 14 : 16),
        boxShadow: [
          BoxShadow(
            color: _universityNavy.withValues(alpha: 0.05),
            blurRadius: isCompact ? 12 : 16,
            offset: Offset(0, isCompact ? 4 : 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _universityInk,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (hasSubtitle) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: _universityMuted,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing],
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    final items = _navigationItems();

    return Container(
      width: 280,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
      decoration: BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSidebarBrand(),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              children: [
                for (var index = 0; index < items.length; index++) ...[
                  _SidebarTile(
                    item: items[index],
                    isSelected: index == _selectedIndex,
                    onTap: () => _openNavigationItem(index),
                  ),
                  if (index != items.length - 1) const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarBrand() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _universityBorder),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'UNIVERSITY',
                  style: TextStyle(
                    color: _universityMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _stringValue(_universityName, fallback: 'PORTAL'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _universityInk,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardAppBarIcon({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Container(
        height: 46,
        width: 46,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final language = context.watch<LanguageProvider>();
    if (_isLoggingOut ||
        !authProvider.isAuthenticated ||
        authProvider.user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 1100;
    final universityLogoUrls = _getUniversityLogoUrls();
    final today = MaterialLocalizations.of(
      context,
    ).formatFullDate(DateTime.now());

    return Scaffold(
      backgroundColor: _coordinatorBackground,
      appBar: AppBar(
        backgroundColor: _universityHeaderNavy,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        foregroundColor: Colors.white,
        centerTitle: true,
        toolbarHeight: 96,
        flexibleSpace: const DecoratedBox(
          decoration: BoxDecoration(color: _universityHeaderNavy),
        ),
        leadingWidth: isDesktop ? 90 : 72,
        leading: Padding(
          padding: EdgeInsets.only(left: isDesktop ? 12 : 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.98),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.16),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Image.asset(
                    AppAssets.splashLogo,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.account_balance_rounded,
                        color: _universityHeaderNavy,
                        size: 24,
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'INDUSTRIAL PRACTICAL TRAING SYSTEM',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              today,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white70,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: _UniversityLogoImage(
                      imageUrls: universityLogoUrls,
                      fit: BoxFit.contain,
                      emptyChild: const Icon(
                        Icons.account_balance_rounded,
                        color: _universityHeaderNavy,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _buildDashboardAppBarIcon(
            tooltip: language.tr('notifications'),
            onPressed: _openNotifications,
            icon: Icons.notifications_outlined,
          ),
          PopupMenuButton<_UniversityMoreAction>(
            tooltip: language.tr('more_actions'),
            onSelected: _handleMoreAction,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _UniversityMoreAction.settings,
                child: Row(
                  children: [
                    const Icon(Icons.settings_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(language.tr('settings')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: _UniversityMoreAction.language,
                child: Row(
                  children: [
                    const Icon(Icons.language_outlined, size: 18),
                    const SizedBox(width: 10),
                    Text(language.tr('change_language')),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: _UniversityMoreAction.logout,
                child: Row(
                  children: [
                    const Icon(Icons.logout_rounded, size: 18),
                    const SizedBox(width: 10),
                    Text(language.tr('logout')),
                  ],
                ),
              ),
            ],
            icon: Container(
              height: 46,
              width: 46,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
              child: const Icon(Icons.more_vert_rounded, color: Colors.white),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            if (isDesktop) _buildDesktopSidebar(),
            Expanded(child: _buildBody(isDesktop)),
          ],
        ),
      ),
      floatingActionButton: !_isLoading
          ? (_selectedIndex == 0
                ? FloatingActionButton(
                    onPressed: _loadUniversityPortal,
                    backgroundColor: _universityNavy,
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.refresh_rounded),
                  )
                : null)
          : null,
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              type: BottomNavigationBarType.fixed,
              currentIndex: _selectedIndex < _navigationItems().length
                  ? _selectedIndex
                  : 0,
              onTap: _openNavigationItem,
              selectedItemColor: _universityNavy,
              unselectedItemColor: _universityMuted,
              items: _navigationItems()
                  .map(
                    (item) => BottomNavigationBarItem(
                      icon: Icon(_inactiveNavigationIcon(item.icon)),
                      activeIcon: Icon(item.icon),
                      label: item.label,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }
}

class _UniversityNavigationItem {
  const _UniversityNavigationItem({
    required this.label,
    required this.icon,
    required this.subtitle,
  });

  final String label;
  final IconData icon;
  final String subtitle;
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _UniversityNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? _universityMist : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected
                    ? _universityNavy.withValues(alpha: 0.12)
                    : const Color(0xFFF6F8FB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                color: isSelected ? _universityNavy : _universityMuted,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: TextStyle(
                      color: isSelected ? _universityInk : _universityMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (item.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _universityMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UniversityHeroAvatar extends StatelessWidget {
  const _UniversityHeroAvatar({required this.imageUrls});

  final List<String> imageUrls;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      width: 64,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _universityBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: _UniversityLogoImage(
          imageUrls: imageUrls,
          fit: BoxFit.cover,
          emptyChild: Image.asset(
            'assets/images/splash_logo.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.account_balance_rounded,
                color: _universityNavy,
                size: 30,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UniversityLogoImage extends StatefulWidget {
  final List<String> imageUrls;
  final BoxFit fit;
  final Widget emptyChild;

  const _UniversityLogoImage({
    required this.imageUrls,
    required this.fit,
    required this.emptyChild,
  });

  @override
  State<_UniversityLogoImage> createState() => _UniversityLogoImageState();
}

class _UniversityLogoImageState extends State<_UniversityLogoImage> {
  int _imageIndex = 0;

  @override
  void didUpdateWidget(covariant _UniversityLogoImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrls.join('|') != widget.imageUrls.join('|')) {
      _imageIndex = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty || _imageIndex >= widget.imageUrls.length) {
      return widget.emptyChild;
    }

    final currentUrl = widget.imageUrls[_imageIndex];
    return Image.network(
      currentUrl,
      key: ValueKey('$currentUrl-$_imageIndex'),
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        if (_imageIndex < widget.imageUrls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _imageIndex += 1);
          });
          return const SizedBox.expand();
        }
        return widget.emptyChild;
      },
    );
  }
}

enum _CoordinatorPlacementStatus { good, average, needsAttention, notPlaced }

enum _CoordinatorFeedbackStatus { overdue, received }

class _CoordinatorStudentRecord {
  const _CoordinatorStudentRecord({
    required this.studentName,
    required this.email,
    required this.department,
    required this.registrationNumber,
    this.companyName,
    required this.status,
    this.startDate,
    this.lastFeedback,
  });

  final String studentName;
  final String email;
  final String department;
  final String registrationNumber;
  final String? companyName;
  final _CoordinatorPlacementStatus status;
  final String? startDate;
  final String? lastFeedback;

  bool get isPlaced => companyName != null && companyName!.trim().isNotEmpty;
}

class _CoordinatorCompanyFeedback {
  const _CoordinatorCompanyFeedback({
    required this.companyName,
    required this.status,
    required this.detail,
  });

  final String companyName;
  final _CoordinatorFeedbackStatus status;
  final String detail;
}

class _CoordinatorDeadlineItem {
  const _CoordinatorDeadlineItem({
    required this.dateLabel,
    required this.description,
  });

  final String dateLabel;
  final String description;
}

class _LegendPill extends StatelessWidget {
  const _LegendPill({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: _universityInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPillButton extends StatelessWidget {
  const _ActionPillButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withValues(alpha: 0.12),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

class _DashboardTabButton extends StatelessWidget {
  const _DashboardTabButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? _coordinatorPrimary : Colors.transparent,
              width: 2.4,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? _coordinatorPrimary : _universityMuted,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _PlacementStatusChip extends StatelessWidget {
  const _PlacementStatusChip({required this.status});

  final _CoordinatorPlacementStatus status;

  Color get _color {
    switch (status) {
      case _CoordinatorPlacementStatus.good:
        return _coordinatorSuccess;
      case _CoordinatorPlacementStatus.average:
        return _coordinatorWarning;
      case _CoordinatorPlacementStatus.needsAttention:
      case _CoordinatorPlacementStatus.notPlaced:
        return _coordinatorDanger;
    }
  }

  String get _label {
    switch (status) {
      case _CoordinatorPlacementStatus.good:
        return 'Good';
      case _CoordinatorPlacementStatus.average:
        return 'Average';
      case _CoordinatorPlacementStatus.needsAttention:
        return 'Needs Attention';
      case _CoordinatorPlacementStatus.notPlaced:
        return 'Not Placed';
    }
  }

  IconData get _icon {
    switch (status) {
      case _CoordinatorPlacementStatus.good:
        return Icons.circle;
      case _CoordinatorPlacementStatus.average:
        return Icons.circle;
      case _CoordinatorPlacementStatus.needsAttention:
      case _CoordinatorPlacementStatus.notPlaced:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: 10, color: _color),
          const SizedBox(width: 7),
          Text(
            _label,
            style: TextStyle(color: _color, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.dateLabel,
    required this.description,
    required this.accent,
  });

  final String dateLabel;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              dateLabel,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                description,
                style: const TextStyle(
                  color: _universityInk,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final hasSubtitle = subtitle.trim().isNotEmpty;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: _universityInk,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (hasSubtitle) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: _universityMuted, height: 1.45),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...<Widget>[trailing!],
      ],
    );
  }
}

class _MetricCardData {
  const _MetricCardData({
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    required this.color,
    this.navigationIndex,
    this.studentView,
    this.onTap,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final Color color;
  final int? navigationIndex;
  final _UniversityStudentView? studentView;
  final VoidCallback? onTap;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data, this.onTap});

  final _MetricCardData data;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _universityBorder.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: data.color.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: isMobile ? 34 : 40,
                height: isMobile ? 34 : 40,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  data.icon,
                  color: data.color,
                  size: isMobile ? 18 : 20,
                ),
              ),
              SizedBox(width: isMobile ? 10 : 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: TextStyle(
                        color: _universityMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: isMobile ? 11 : 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      data.value,
                      style: TextStyle(
                        color: data.color,
                        fontSize: isMobile ? 22 : 24,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineBanner extends StatelessWidget {
  const _InlineBanner({
    required this.color,
    required this.background,
    required this.icon,
    required this.title,
    required this.message,
  });

  final Color color;
  final Color background;
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(color: _universityMuted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AnnouncementList extends StatelessWidget {
  const _AnnouncementList({required this.announcements});

  final List<Map<String, dynamic>> announcements;

  String _stringValue(dynamic value, {String fallback = '-'}) {
    final text = '$value'.trim();
    if (text.isEmpty || text == 'null') return fallback;
    return text;
  }

  DateTime? _parseDate(dynamic value) {
    final raw = '$value'.trim();
    if (raw.isEmpty || raw == 'null') return null;
    try {
      return DateTime.parse(raw).toLocal();
    } catch (_) {
      return null;
    }
  }

  String _relativeTime(dynamic value) {
    final date = _parseDate(value);
    if (date == null) return 'Recently';
    final difference = DateTime.now().difference(date);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} mins ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return const _EmptyStateCard(
        title: 'No announcements published yet',
        message: '',
        icon: Icons.campaign_rounded,
      );
    }

    return Column(
      children: announcements
          .map((announcement) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _universityMist,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _stringValue(
                              announcement['title'],
                              fallback: 'Award',
                            ),
                            style: const TextStyle(
                              color: _universityInk,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_stringValue(announcement['student_name'])} • ${_stringValue(announcement['company_name'])}',
                            style: const TextStyle(color: _universityMuted),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _relativeTime(
                              announcement['award_date'] ??
                                  announcement['created_at'],
                            ),
                            style: const TextStyle(
                              color: _universityMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _UniversityChangePasswordDialog extends StatefulWidget {
  const _UniversityChangePasswordDialog({
    required this.apiService,
    required this.messenger,
  });

  final ApiService apiService;
  final ScaffoldMessengerState messenger;

  @override
  State<_UniversityChangePasswordDialog> createState() =>
      _UniversityChangePasswordDialogState();
}

class _UniversityChangePasswordDialogState
    extends State<_UniversityChangePasswordDialog> {
  final TextEditingController _currentPasswordController =
      TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isSubmitting = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _buildDecoration({
    required String label,
    required IconData icon,
    required bool isVisible,
    required VoidCallback onToggleVisibility,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: _universityNavy),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(
          isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        ),
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _universityNavy),
      ),
    );
  }

  void _showError(String message) {
    widget.messenger
      ..hideCurrentSnackBar()
      ..showAppSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
  }

  Future<void> _submit() async {
    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (currentPassword.isEmpty) {
      _showError('Please enter your current password');
      return;
    }

    if (newPassword.length < 6) {
      _showError('New password must be at least 6 characters');
      return;
    }

    if (newPassword != confirmPassword) {
      _showError('New passwords do not match');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await widget.apiService.changePassword({
        'current_password': currentPassword,
        'new_password': newPassword,
      });
      if (!mounted) return;

      if (response['success'] == true) {
        Navigator.of(context).pop();
        widget.messenger
          ..hideCurrentSnackBar()
          ..showAppSnackBar(
            const SnackBar(
              content: Text('Password changed successfully'),
              backgroundColor: _coordinatorSuccess,
            ),
          );
        return;
      }

      _showError(
        response['message']?.toString() ?? 'Failed to change password',
      );
    } catch (error) {
      if (!mounted) return;
      _showError(
        ApiService.normalizeErrorMessage(
          error,
          fallback: 'Failed to change password. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Password'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: _buildDecoration(
                label: 'Current Password',
                icon: Icons.lock_outline,
                isVisible: _showCurrentPassword,
                onToggleVisibility: () {
                  setState(() => _showCurrentPassword = !_showCurrentPassword);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: _buildDecoration(
                label: 'New Password',
                icon: Icons.lock_reset_outlined,
                isVisible: _showNewPassword,
                onToggleVisibility: () {
                  setState(() => _showNewPassword = !_showNewPassword);
                },
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: _buildDecoration(
                label: 'Confirm New Password',
                icon: Icons.verified_user_outlined,
                isVisible: _showConfirmPassword,
                onToggleVisibility: () {
                  setState(() => _showConfirmPassword = !_showConfirmPassword);
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _universityNavy,
            foregroundColor: Colors.white,
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update Password'),
        ),
      ],
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.title,
    required this.message,
    required this.icon,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _universityBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _universityNavy),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: _universityInk,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(color: _universityMuted, height: 1.4),
          ),
        ],
      ),
    );
  }
}
