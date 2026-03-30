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
    required this.requiredSkills,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();

    return Job(
      jobId: _stringValue(json['job_id']),
      companyId: _stringValue(json['company_id']),
      companyName: _stringValue(json['company_name'], fallback: 'Company'),
      title: _stringValue(json['title'], fallback: 'Untitled Job'),
      type: _stringValue(json['type'], fallback: 'internship'),
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
      requiredSkills: _skillList(json['required_skills']),
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final normalized = '$value'.trim();
    return normalized.isEmpty ? fallback : normalized;
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
