class WebPortalRoutes {
  const WebPortalRoutes._();

  static const home = '/';
  static const training = '/training';
  static const trainingCompany = '/training-company';
  static const university = '/university';
  static const admin = '/admin';
  static const splash = '/splash';

  static const portalRoutes = <String>{
    training,
    trainingCompany,
    university,
    admin,
  };

  static String normalizePath(String? rawPath) {
    final path = (rawPath ?? '').trim();
    if (path.isEmpty || path == '/index.html') return home;
    if (path.length > 1 && path.endsWith('/')) {
      return path.substring(0, path.length - 1);
    }
    return path;
  }

  static String initialPath(String rawPath) {
    final path = normalizePath(rawPath);
    return portalRoutes.contains(path) ? path : home;
  }

  static String forRole(Object? role) {
    switch ('$role'.trim().toLowerCase()) {
      case 'company':
      case 'organization':
        return trainingCompany;
      case 'university':
      case 'institution':
        return university;
      case 'admin':
        return admin;
      case 'student':
      case '':
      default:
        return training;
    }
  }
}
