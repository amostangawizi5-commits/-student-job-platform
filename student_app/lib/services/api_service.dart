import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiService {
  // Default mobile backend points to the hosted production API.
  static const String _defaultApiBaseUrl =
      'https://student-job-platform-api.onrender.com';
  static const String _webBaseUrl = 'http://localhost:5000';
  static const String _tokenStorageKey = 'token';
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static List<dynamic>? _universitiesCache;
  static DateTime? _universitiesCacheTime;
  static Map<String, dynamic>? _unreadNotificationsCache;
  static DateTime? _unreadNotificationsCacheTime;
  static Map<String, dynamic>? _profileCache;
  static DateTime? _profileCacheTime;
  static final Map<String, Map<String, dynamic>> _jobsCache = {};
  static final Map<String, DateTime> _jobsCacheTime = {};
  static Map<String, dynamic>? _companyJobsCache;
  static DateTime? _companyJobsCacheTime;
  static final Dio _sharedDio = Dio();
  static const FlutterSecureStorage _sharedStorage = FlutterSecureStorage();
  static bool _isDioConfigured = false;

  static String _normalizeBaseUrl(String url) {
    return url.trim().replaceFirst(RegExp(r'/*$'), '');
  }

  static String _resolveBaseUrl() {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _normalizeBaseUrl(_apiBaseUrlOverride);
    }

    if (kIsWeb) {
      return _webBaseUrl;
    }

    return _defaultApiBaseUrl;
  }

  // Native apps use the hosted API unless overridden with --dart-define.
  final String baseUrl = _resolveBaseUrl();

  final Dio _dio = _sharedDio;
  final FlutterSecureStorage _storage = _sharedStorage;

  ApiService() {
    if (_isDioConfigured) return;

    _log('🌐 ApiService baseUrl: $baseUrl');

    _dio.options.connectTimeout = const Duration(seconds: 10);
    _dio.options.receiveTimeout = const Duration(seconds: 20);
    _dio.options.headers = {'Content-Type': 'application/json'};

    // Add logging interceptor for debugging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _log('🚀 ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _log(
            '✅ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          _log('❌ ${e.type} ${e.requestOptions.path}: ${e.message}');
          return handler.next(e);
        },
      ),
    );

    _isDioConfigured = true;
  }

  static void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  static bool _isFresh(DateTime? timestamp, Duration ttl) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < ttl;
  }

  static void _invalidateProfileCache() {
    _profileCache = null;
    _profileCacheTime = null;
  }

  static void _invalidateJobsCache() {
    _jobsCache.clear();
    _jobsCacheTime.clear();
    _companyJobsCache = null;
    _companyJobsCacheTime = null;
  }

  static void _invalidateCachesForPath(String path) {
    if (path.startsWith('/api/auth/profile') ||
        path.startsWith('/api/company/profile') ||
        path.startsWith('/api/resume')) {
      _invalidateProfileCache();
    }

    if (path.startsWith('/api/jobs') || path.startsWith('/api/applications')) {
      _invalidateJobsCache();
    }

    if (path.startsWith('/api/notifications')) {
      _unreadNotificationsCache = null;
      _unreadNotificationsCacheTime = null;
    }
  }

  static String _jobsCacheKey({
    String? type,
    String? location,
    String? limit,
    String? search,
    String? view,
  }) {
    return [
      type ?? '',
      location ?? '',
      limit ?? '',
      search ?? '',
      view ?? '',
    ].join('|');
  }

  static String _normalizeLoginErrorMessage(Object? error) {
    final message = (error?.toString() ?? '').replaceFirst('Exception: ', '');
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('device is locked') ||
        lowerMessage.contains('app locked') ||
        lowerMessage.contains('app lock') ||
        lowerMessage.contains('locked to another account') ||
        lowerMessage.contains('clear app cache') ||
        lowerMessage.contains('clear cache')) {
      return 'Login failed';
    }

    if (lowerMessage.contains('invalid email or password') ||
        lowerMessage.contains('invalid credentials') ||
        lowerMessage.contains('wrong password') ||
        lowerMessage.contains('user not found') ||
        lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('401')) {
      return 'Invalid email or password';
    }

    if (lowerMessage.contains('network') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('cannot connect') ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection error') ||
        lowerMessage.contains('server not responding')) {
      return 'Network error';
    }

    return 'Login failed';
  }

  static String _sanitizeAuthResponseMessage(String? message) {
    final normalized = (message ?? '').replaceFirst('Exception: ', '').trim();
    final lowerMessage = normalized.toLowerCase();
    if (lowerMessage.contains('device is locked') ||
        lowerMessage.contains('app locked') ||
        lowerMessage.contains('app lock') ||
        lowerMessage.contains('locked to another account') ||
        lowerMessage.contains('clear app cache') ||
        lowerMessage.contains('clear cache')) {
      return 'Authentication failed. Please try again.';
    }
    return normalized;
  }

  Future<String?> getToken() async {
    return await _storage.read(key: _tokenStorageKey);
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: _tokenStorageKey, value: token);
  }

  String? _extractAuthToken(Map<String, dynamic> response) {
    if (response['token'] != null) {
      return '${response['token']}';
    }

    final data = response['data'];
    if (data is Map<String, dynamic> && data['token'] != null) {
      return '${data['token']}';
    }

    return null;
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    dynamic data,
    bool requiresAuth = false,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final options = Options(
        method: method,
        headers: requiresAuth
            ? {'Authorization': 'Bearer ${await getToken()}'}
            : {},
      );

      final response = await _dio.request(
        '$baseUrl$path',
        data: data,
        options: options,
        queryParameters: queryParams,
      );
      return response.data;
    } on DioException catch (e) {
      _log('❌ DioException ${e.type}: ${e.message}');

      if (e.type == DioExceptionType.connectionTimeout) {
        throw Exception(
          'Connection timeout. Please check your internet connection.',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Server not responding. Please try again.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception(
          'Cannot connect to server at $baseUrl. If you are testing on a phone, rebuild with --dart-define=API_BASE_URL=http://YOUR-LAPTOP-IP:5000',
        );
      }

      if (e.response != null) {
        final errorData = e.response?.data;
        String errorMessage = 'Request failed';

        if (errorData is Map) {
          errorMessage =
              errorData['message'] ?? errorData['error'] ?? 'Request failed';
        } else if (errorData is String) {
          errorMessage = errorData;
        }

        throw Exception(errorMessage);
      }
      throw Exception('Network error: ${e.message}');
    } catch (e) {
      _log('❌ Unexpected error: $e');
      throw Exception('Unexpected error: $e');
    }
  }

  // ==================== AUTH METHODS ====================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _request(
        'POST',
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      // Check different response structures
      if (response['success'] == true || response['token'] != null) {
        final token = _extractAuthToken(response);

        if (token != null) {
          await setToken(token);
        }

        return {'success': true, 'data': response};
      }

      return {
        ...response,
        'message': _sanitizeAuthResponseMessage(
          response['message']?.toString(),
        ),
      };
    } catch (e) {
      _log('❌ Login error: $e');
      return {'success': false, 'message': _normalizeLoginErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> verifyAccountPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _request(
        'POST',
        '/api/auth/login',
        data: {'email': email.trim(), 'password': password},
      );

      if (response['success'] == true || response['token'] != null) {
        return {'success': true};
      }

      return {
        'success': false,
        'message': _sanitizeAuthResponseMessage(
          response['message']?.toString(),
        ),
      };
    } catch (e) {
      _log('❌ Verify account password error: $e');
      return {'success': false, 'message': _normalizeLoginErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> forgotPassword(String email) async {
    try {
      return await _request(
        'POST',
        '/api/auth/forgot-password',
        data: {'email': email.trim()},
      );
    } catch (e) {
      _log('❌ Forgot password error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> completePasswordReset({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/auth/reset-password',
        data: {
          'token': token.trim(),
          'password': password,
          'confirmPassword': confirmPassword,
        },
      );
    } catch (e) {
      _log('❌ Complete password reset error: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> register(Map<String, dynamic> userData) async {
    try {
      final response = await _request(
        'POST',
        '/api/auth/register',
        data: userData,
      );
      final token = _extractAuthToken(response);

      if (token != null) {
        await setToken(token);
      }

      return {'success': true, 'data': response};
    } catch (e) {
      _log('❌ Registration error: $e');
      return {
        'success': false,
        'message': _sanitizeAuthResponseMessage(e.toString()),
      };
    }
  }

  Future<Map<String, dynamic>> getProfile({bool forceRefresh = false}) async {
    try {
      if (!forceRefresh &&
          _isFresh(_profileCacheTime, const Duration(seconds: 30))) {
        final cached = _profileCache;
        if (cached != null) {
          return cached;
        }
      }

      final response = await _request(
        'GET',
        '/api/auth/profile',
        requiresAuth: true,
      );
      if (response['success'] == true) {
        _profileCache = response;
        _profileCacheTime = DateTime.now();
      }
      return response;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _request(
        'PUT',
        '/api/auth/profile',
        data: data,
        requiresAuth: true,
      );
      _invalidateProfileCache();
      return response;
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> changePassword(Map<String, dynamic> data) async {
    try {
      return await _request(
        'PUT',
        '/api/auth/change-password',
        data: data,
        requiresAuth: true,
      );
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenStorageKey);
    _unreadNotificationsCache = null;
    _unreadNotificationsCacheTime = null;
  }

  // ==================== JOB METHODS ====================
  Future<Map<String, dynamic>> getJobs({
    String? type,
    String? location,
    String? limit,
    String? search,
    String? view,
    bool forceRefresh = false,
  }) async {
    Map<String, dynamic> query = {};
    if (type != null && type != 'all') query['type'] = type;
    if (location != null && location != 'all') query['location'] = location;
    if (limit != null) query['limit'] = limit;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (view != null && view.isNotEmpty) query['view'] = view;
    final cacheKey = _jobsCacheKey(
      type: query['type']?.toString(),
      location: query['location']?.toString(),
      limit: query['limit']?.toString(),
      search: query['search']?.toString(),
      view: query['view']?.toString(),
    );

    if (!forceRefresh &&
        _isFresh(_jobsCacheTime[cacheKey], const Duration(seconds: 30))) {
      final cached = _jobsCache[cacheKey];
      if (cached != null) {
        return cached;
      }
    }

    final response = await _request(
      'GET',
      '/api/jobs',
      queryParams: query,
      requiresAuth: true,
    );
    if (response['success'] == true) {
      _jobsCache[cacheKey] = response;
      _jobsCacheTime[cacheKey] = DateTime.now();
    }
    return response;
  }

  Future<Map<String, dynamic>> getJobsWithLimit(String limit) async {
    return await getJobs(limit: limit);
  }

  Future<Map<String, dynamic>> getJobById(String jobId) async {
    return await _request('GET', '/api/jobs/$jobId', requiresAuth: true);
  }

  Future<Map<String, dynamic>> getCompanyJobs({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _isFresh(_companyJobsCacheTime, const Duration(seconds: 20))) {
      final cached = _companyJobsCache;
      if (cached != null) {
        return cached;
      }
    }

    final response = await _request(
      'GET',
      '/api/jobs/company/my-jobs',
      requiresAuth: true,
    );
    if (response['success'] == true) {
      _companyJobsCache = response;
      _companyJobsCacheTime = DateTime.now();
    }
    return response;
  }

  Future<Map<String, dynamic>> postJob(Map<String, dynamic> jobData) async {
    final response = await _request(
      'POST',
      '/api/jobs',
      data: jobData,
      requiresAuth: true,
    );
    _invalidateJobsCache();
    return response;
  }

  Future<Map<String, dynamic>> updateJob(
    String jobId,
    Map<String, dynamic> data,
  ) async {
    final response = await _request(
      'PUT',
      '/api/jobs/$jobId',
      data: data,
      requiresAuth: true,
    );
    _invalidateJobsCache();
    return response;
  }

  Future<Map<String, dynamic>> deleteJob(String jobId) async {
    final response = await _request(
      'DELETE',
      '/api/jobs/$jobId',
      requiresAuth: true,
    );
    _invalidateJobsCache();
    return response;
  }

  // ==================== APPLICATION METHODS ====================
  Future<Map<String, dynamic>> applyForJob(String jobId) async {
    final response = await _request(
      'POST',
      '/api/applications',
      data: {'job_id': jobId},
      requiresAuth: true,
    );
    _invalidateJobsCache();
    return response;
  }

  Future<Map<String, dynamic>> getMyApplications() async {
    return await _request(
      'GET',
      '/api/applications/my-applications',
      requiresAuth: true,
    );
  }

  Future<Map<String, dynamic>> getJobApplications(String jobId) async {
    return await _request(
      'GET',
      '/api/applications/job/$jobId',
      requiresAuth: true,
    );
  }

  Future<Map<String, dynamic>> getCompanyApplications() async {
    return await _request(
      'GET',
      '/api/applications/company',
      requiresAuth: true,
    );
  }

  Future<Map<String, dynamic>> updateApplication(
    String applicationId,
    String status,
  ) async {
    return await _request(
      'PUT',
      '/api/applications/$applicationId',
      data: {'status': status},
      requiresAuth: true,
    );
  }

  // ==================== SKILLS METHODS ====================
  Future<Map<String, dynamic>> getAllSkills() async {
    return await _request('GET', '/api/skills', requiresAuth: true);
  }

  Future<Map<String, dynamic>> getSkills() async {
    return await _request('GET', '/api/skills', requiresAuth: true);
  }

  Future<Map<String, dynamic>> getStudentSkills() async {
    return await _request('GET', '/api/student/skills', requiresAuth: true);
  }

  Future<Map<String, dynamic>> addStudentSkill(String skillId) async {
    return await _request(
      'POST',
      '/api/student/skills',
      data: {'skill_id': skillId},
      requiresAuth: true,
    );
  }

  Future<Map<String, dynamic>> removeStudentSkill(String skillId) async {
    return await _request(
      'DELETE',
      '/api/student/skills/$skillId',
      requiresAuth: true,
    );
  }

  // ==================== NOTIFICATION METHODS ====================
  Future<Map<String, dynamic>> getNotifications() async {
    return await _request('GET', '/api/notifications', requiresAuth: true);
  }

  Future<Map<String, dynamic>> markNotificationRead(
    String notificationId,
  ) async {
    final response = await _request(
      'PUT',
      '/api/notifications/$notificationId/read',
      data: {},
      requiresAuth: true,
    );
    _unreadNotificationsCache = null;
    _unreadNotificationsCacheTime = null;
    return response;
  }

  Future<Map<String, dynamic>> markAllNotificationsRead() async {
    final response = await _request(
      'PUT',
      '/api/notifications/read-all',
      data: {},
      requiresAuth: true,
    );
    _unreadNotificationsCache = {
      'success': true,
      'data': {'count': 0},
    };
    _unreadNotificationsCacheTime = DateTime.now();
    return response;
  }

  Future<Map<String, dynamic>> getUnreadNotificationCount({
    bool forceRefresh = false,
  }) async {
    final hasFreshCache =
        _unreadNotificationsCache != null &&
        _unreadNotificationsCacheTime != null &&
        DateTime.now().difference(_unreadNotificationsCacheTime!) <
            const Duration(seconds: 20);

    if (!forceRefresh && hasFreshCache) {
      return _unreadNotificationsCache!;
    }

    final response = await _request(
      'GET',
      '/api/notifications/unread-count',
      requiresAuth: true,
    );
    if (response['success'] == true) {
      _unreadNotificationsCache = response;
      _unreadNotificationsCacheTime = DateTime.now();
    }
    return response;
  }

  // ==================== UNIVERSITY METHODS ====================
  Future<Map<String, dynamic>> getUniversities({
    bool forceRefresh = false,
  }) async {
    final hasFreshCache =
        _universitiesCache != null &&
        _universitiesCacheTime != null &&
        DateTime.now().difference(_universitiesCacheTime!) <
            const Duration(hours: 6);

    if (!forceRefresh && hasFreshCache) {
      return {'success': true, 'data': _universitiesCache};
    }

    try {
      // Registration screen needs this endpoint before login.
      final response = await _request(
        'GET',
        '/api/auth/universities',
        requiresAuth: false,
      );

      final data = response['data'];
      if (response['success'] == true && data is List) {
        _universitiesCache = List<dynamic>.from(data);
        _universitiesCacheTime = DateTime.now();
      }

      return response;
    } catch (e) {
      _log('❌ Error getting universities: $e');
      if (_universitiesCache != null) {
        return {'success': true, 'data': _universitiesCache};
      }
      return {'success': false, 'message': e.toString(), 'data': []};
    }
  }

  // ==================== PROJECT METHODS ====================
  Future<Map<String, dynamic>> getStudentProjects() async {
    try {
      return await _request('GET', '/api/projects/student', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting projects: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> addStudentProject(
    Map<String, dynamic> projectData,
  ) async {
    try {
      return await _request(
        'POST',
        '/api/projects/student',
        data: projectData,
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error adding project: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> removeStudentProject(String projectId) async {
    try {
      return await _request(
        'DELETE',
        '/api/projects/student/$projectId',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error removing project: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== RESUME METHODS ====================
  Future<Map<String, dynamic>> uploadResume(String filePath) async {
    try {
      final token = await getToken();
      DioException? lastError;

      // Some backends expect different form keys for CV upload.
      for (final fieldName in const ['resume', 'cv', 'file', 'resume_file']) {
        try {
          FormData formData = FormData.fromMap({
            fieldName: await MultipartFile.fromFile(
              filePath,
              filename: filePath.split('/').last,
            ),
          });

          final response = await _dio.post(
            '$baseUrl/api/resume/upload',
            data: formData,
            options: Options(
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'multipart/form-data',
              },
            ),
          );
          _invalidateProfileCache();
          return response.data;
        } on DioException catch (e) {
          lastError = e;
          final statusCode = e.response?.statusCode ?? 0;
          // Retry only for likely payload-shape errors.
          if (statusCode == 400 ||
              statusCode == 404 ||
              statusCode == 415 ||
              statusCode == 422) {
            continue;
          }
          rethrow;
        }
      }

      throw lastError ??
          DioException(
            requestOptions: RequestOptions(path: '/api/resume/upload'),
            message: 'Resume upload failed',
          );
    } on DioException catch (e) {
      _log('❌ Error uploading resume: $e');
      final errorData = e.response?.data;
      if (errorData is Map &&
          (errorData['message'] != null || errorData['error'] != null)) {
        throw Exception(errorData['message'] ?? errorData['error']);
      }
      throw Exception('Failed to upload resume: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> deleteResume() async {
    try {
      final response = await _request(
        'DELETE',
        '/api/resume',
        requiresAuth: true,
      );
      _invalidateProfileCache();
      return response;
    } catch (e) {
      _log('❌ Error deleting resume: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> uploadStudentProfileImage(
    String filePath,
  ) async {
    try {
      final token = await getToken();
      final fileName = filePath.split('/').last;
      final formData = FormData.fromMap({
        'profile_image': await MultipartFile.fromFile(
          filePath,
          filename: fileName,
        ),
      });

      final response = await _dio.post(
        '$baseUrl/api/auth/profile-image',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      _invalidateProfileCache();
      return response.data;
    } on DioException catch (e) {
      _log('❌ Error uploading student profile image: $e');
      final errorData = e.response?.data;
      if (errorData is Map &&
          (errorData['message'] != null || errorData['error'] != null)) {
        throw Exception(errorData['message'] ?? errorData['error']);
      }
      throw Exception('Failed to upload profile image: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> deleteStudentProfileImage() async {
    try {
      final response = await _request(
        'DELETE',
        '/api/auth/profile-image',
        requiresAuth: true,
      );
      _invalidateProfileCache();
      return response;
    } catch (e) {
      _log('❌ Error deleting student profile image: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== COMPANY METHODS ====================
  Future<Map<String, dynamic>> getCompanyProfile() async {
    try {
      return await _request('GET', '/api/company/profile', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting company profile: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateCompanyProfile(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _request(
        'PUT',
        '/api/company/profile',
        data: data,
        requiresAuth: true,
      );
      _invalidateProfileCache();
      return response;
    } catch (e) {
      _log('❌ Error updating company profile: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  // ==================== COMPANY LOGO METHODS ====================
  Future<Map<String, dynamic>> uploadCompanyLogo(String filePath) async {
    try {
      final token = await getToken();
      DioException? lastError;
      final fileName = filePath.split('/').last;

      const endpoints = ['/api/company/logo', '/api/company/upload-logo'];
      const fieldNames = ['logo', 'file', 'image', 'logo_file'];

      for (final endpoint in endpoints) {
        for (final fieldName in fieldNames) {
          try {
            final formData = FormData.fromMap({
              fieldName: await MultipartFile.fromFile(
                filePath,
                filename: fileName,
              ),
            });

            final response = await _dio.post(
              '$baseUrl$endpoint',
              data: formData,
              options: Options(headers: {'Authorization': 'Bearer $token'}),
            );
            _invalidateProfileCache();
            return response.data;
          } on DioException catch (e) {
            lastError = e;
            final statusCode = e.response?.statusCode ?? 0;

            // Retry with next field/endpoint for common payload/route issues.
            if (statusCode == 400 ||
                statusCode == 404 ||
                statusCode == 415 ||
                statusCode == 422) {
              continue;
            }
            rethrow;
          }
        }
      }

      throw lastError ??
          DioException(
            requestOptions: RequestOptions(path: '/api/company/logo'),
            message: 'Logo upload failed',
          );
    } on DioException catch (e) {
      _log('❌ Error uploading logo: $e');
      final errorData = e.response?.data;
      if (errorData is Map &&
          (errorData['message'] != null || errorData['error'] != null)) {
        throw Exception(errorData['message'] ?? errorData['error']);
      }
      throw Exception('Failed to upload logo: ${e.message}');
    }
  }

  // ==================== ADMIN METHODS ====================
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      return await _request('GET', '/api/admin/stats', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting admin stats: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getUsers() async {
    try {
      return await _request('GET', '/api/admin/users', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting users: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminJobs() async {
    try {
      return await _request('GET', '/api/admin/jobs', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting admin jobs: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getApplications({String? status}) async {
    try {
      String path = '/api/admin/applications';
      if (status != null) {
        path += '?status=$status';
      }
      return await _request('GET', path, requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting applications: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateUserRole(
    String userId,
    String role,
  ) async {
    try {
      return await _request(
        'PUT',
        '/api/admin/users/$userId/role',
        data: {'role': role},
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error updating user role: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> toggleUserStatus(
    String userId,
    bool isActive,
  ) async {
    try {
      final path = isActive
          ? '/api/admin/users/$userId/activate'
          : '/api/admin/users/$userId/suspend';
      return await _request('PUT', path, data: {}, requiresAuth: true);
    } catch (e) {
      _log('❌ Error toggling user status: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> sendUserPasswordResetLink(String userId) async {
    try {
      return await _request(
        'PUT',
        '/api/admin/users/$userId/reset-password',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error sending reset link: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> verifyUser(String userId) async {
    try {
      return await _request(
        'PUT',
        '/api/admin/users/$userId/verify',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error verifying user: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> deleteUser(String userId) async {
    try {
      return await _request(
        'DELETE',
        '/api/admin/users/$userId',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error deleting user: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> updateApplicationStatus(
    String applicationId,
    String status, {
    bool notifyUser = false,
  }) async {
    try {
      return await _request(
        'PUT',
        '/api/admin/applications/$applicationId/status',
        data: {'status': status, 'notify_user': notifyUser},
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error updating application status: $e');
      return {'success': false, 'message': e.toString()};
    }
  }

  Future<Map<String, dynamic>> getAdminLogs() async {
    try {
      return await _request('GET', '/api/admin/logs', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting admin logs: $e');
      return {'success': false, 'message': e.toString(), 'data': []};
    }
  }

  // ==================== GENERIC METHODS ====================
  Future<Map<String, dynamic>> get(
    String path, {
    bool requiresAuth = false,
  }) async {
    return await _request('GET', path, requiresAuth: requiresAuth);
  }

  Future<Map<String, dynamic>> post(
    String path,
    dynamic data, {
    bool requiresAuth = false,
  }) async {
    final response = await _request(
      'POST',
      path,
      data: data,
      requiresAuth: requiresAuth,
    );
    _invalidateCachesForPath(path);
    return response;
  }

  Future<Map<String, dynamic>> put(
    String path,
    dynamic data, {
    bool requiresAuth = false,
  }) async {
    final response = await _request(
      'PUT',
      path,
      data: data,
      requiresAuth: requiresAuth,
    );
    _invalidateCachesForPath(path);
    return response;
  }

  Future<Map<String, dynamic>> delete(
    String path, {
    bool requiresAuth = false,
  }) async {
    final response = await _request('DELETE', path, requiresAuth: requiresAuth);
    _invalidateCachesForPath(path);
    return response;
  }
}
