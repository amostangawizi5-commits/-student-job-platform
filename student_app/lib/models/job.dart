// lib/models/job.dart
class Job {
  final String jobId;
  final String companyId;
  final String companyName;
  final String title;
  final String type;
  final List<String> targetCandidates;
  final String description;
  final String location;
  final String salaryRange;
  final int requiredApplicants;
  final DateTime applicationDeadline;
  final String status;
  final DateTime createdAt;
  final String? logoUrl;
  final List<String> eligiblePrograms;
  final double? minimumGpa;
  final int? minimumAcademicYear;
  final String? eligibilityNotes;
  final String eligibilityMatchMode;
  final List<Map<String, dynamic>> requiredSkills;

  Job({
    required this.jobId,
    required this.companyId,
    required this.companyName,
    required this.title,
    required this.type,
    required this.targetCandidates,
    required this.description,
    required this.location,
    required this.salaryRange,
    required this.requiredApplicants,
    required this.applicationDeadline,
    required this.status,
    required this.createdAt,
    this.logoUrl,
    required this.eligiblePrograms,
    this.minimumGpa,
    this.minimumAcademicYear,
    this.eligibilityNotes,
    required this.eligibilityMatchMode,
    required this.requiredSkills,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    return Job(
      jobId: _stringValue(json['job_id']),
      companyId: _stringValue(json['company_id']),
      companyName: _stringValue(json['company_name'], fallback: 'Company'),
      title: _stringValue(json['title'], fallback: 'Untitled Job'),
      type: _stringValue(json['type'], fallback: '_program'),
      targetCandidates: _stringList(json['target_candidates']),
      description: _stringValue(
        json['description'],
        fallback: 'No job description was provided.',
      ),
      location: _stringValue(json['location'], fallback: 'Remote'),
      salaryRange: _stringValue(
        json['salary_range'],
        fallback: 'Not specified',
      ),
      requiredApplicants: json['required_applicants'] is int
          ? json['required_applicants']
          : int.tryParse('${json['required_applicants'] ?? 1}') ?? 1,
      applicationDeadline:
          _parseDateTime(
            json['application_deadline'],
            fallback: now.add(const Duration(days: 30)),
          ) ??
          now.add(const Duration(days: 30)),
      status: _stringValue(json['status'], fallback: 'open'),
      createdAt: _parseDateTime(json['created_at'], fallback: now) ?? now,
      logoUrl: json['logo_url'],
      eligiblePrograms: _stringList(json['eligible_programs']),
      minimumGpa: _parseDouble(json['minimum_gpa']),
      minimumAcademicYear: _parseInt(json['minimum_academic_year']),
      eligibilityNotes: _nullableStringValue(json['eligibility_notes']),
      eligibilityMatchMode:
          _stringValue(
                json['eligibility_match_mode'],
                fallback: 'all',
              ).toLowerCase() ==
              'any'
          ? 'any'
          : 'all',
      requiredSkills: _skillList(json['required_skills']),
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final normalized = '$value'.trim();
    return normalized.isEmpty ? fallback : normalized;
  }

  static String? _nullableStringValue(dynamic value) {
    final normalized = _stringValue(value);
    return normalized.isEmpty ? null : normalized;
  }

  static DateTime? _parseDateTime(dynamic value, {DateTime? fallback}) {
    if (value == null) return fallback;
    if (value is DateTime) return value;

    final normalized = '$value'.trim();
    if (normalized.isEmpty) return fallback;

    return DateTime.tryParse(normalized) ?? fallback;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];

    return value
        .map((item) => _stringValue(item))
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse('$value');
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse('$value');
  }

  static List<Map<String, dynamic>> _skillList(dynamic value) {
    if (value is! List) return const [];

    final skills = <Map<String, dynamic>>[];

    for (final item in value) {
      if (item is Map) {
        final skill = Map<String, dynamic>.from(item);
        final name = _stringValue(skill['name']);
        if (name.isEmpty) continue;
        skills.add({...skill, 'name': name});
        continue;
      }

      final name = _stringValue(item);
      if (name.isEmpty) continue;
      skills.add({'name': name});
    }

    return skills;
  }
}
