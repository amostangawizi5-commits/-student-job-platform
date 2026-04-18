String normalizeUserRole(Object? role) {
  final normalized = '$role'
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');

  switch (normalized) {
    case 'student':
    case 'graduate':
    case 'company':
    case 'admin':
    case 'university':
      return normalized;
    case 'university coordinator':
    case 'college coordinator':
    case 'institution coordinator':
    case 'coordinator':
    case 'university admin':
    case 'university administrator':
      return 'university';
    default:
      if (normalized.startsWith('university ') &&
          (normalized.contains('coordinator') ||
              normalized.contains('admin') ||
              normalized.contains('administrator'))) {
        return 'university';
      }

      return normalized;
  }
}

bool isStudentRole(Object? role) {
  final normalized = normalizeUserRole(role);
  return normalized == 'student' || normalized == 'graduate';
}

bool isCompanyRole(Object? role) => normalizeUserRole(role) == 'company';

bool isUniversityRole(Object? role) => normalizeUserRole(role) == 'university';

bool isAdminRole(Object? role) => normalizeUserRole(role) == 'admin';
