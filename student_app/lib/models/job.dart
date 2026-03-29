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
    return Job(
      jobId: json['job_id'] ?? '',
      companyId: json['company_id'] ?? '',
      companyName: json['company_name'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      targetCandidates: List<String>.from(json['target_candidates'] ?? []),
      description: json['description'] ?? '',
      location: json['location'] ?? 'Remote',
      salaryRange: json['salary_range'] ?? 'Not specified',
      requiredApplicants: json['required_applicants'] is int
          ? json['required_applicants']
          : int.tryParse('${json['required_applicants'] ?? 1}') ?? 1,
      applicationDeadline: json['application_deadline'] != null
          ? DateTime.parse(json['application_deadline'])
          : DateTime.now().add(const Duration(days: 30)),
      status: json['status'] ?? 'open',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      logoUrl: json['logo_url'],
      requiredSkills: List<Map<String, dynamic>>.from(
        json['required_skills'] ?? [],
      ),
    );
  }
}
