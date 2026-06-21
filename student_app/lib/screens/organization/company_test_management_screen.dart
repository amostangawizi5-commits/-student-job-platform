import 'package:flutter/material.dart';

import '../admin/admin_test_management_screen.dart';

class CompanyTestManagementScreen extends StatelessWidget {
  const CompanyTestManagementScreen({
    super.key,
    this.jobId,
    this.jobTitle,
    this.applicants,
    this.resultsOnly = false,
  });

  final String? jobId;
  final String? jobTitle;
  final List<dynamic>? applicants;
  final bool resultsOnly;

  @override
  Widget build(BuildContext context) {
    return AdminTestManagementScreen(
      organizationMode: true,
      jobId: jobId,
      jobTitle: jobTitle,
      applicants: applicants,
      resultsOnly: resultsOnly,
    );
  }
}
