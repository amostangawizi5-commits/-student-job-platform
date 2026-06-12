import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const Set<String> _singleUniversityNames = {
    'university of dodoma (udom)',
    'university of dodoma',
    'udom',
  };
  static const String _localApiBaseUrl = 'http://localhost:5000';
  static const String _defaultAndroidDeviceApiBaseUrl =
      'http://10.104.30.219:5000';
  static const String _androidDeviceApiBaseUrl = String.fromEnvironment(
    'ANDROID_LOCAL_API_BASE_URL',
    defaultValue: _defaultAndroidDeviceApiBaseUrl,
  );
  static const String _webBaseUrl = _localApiBaseUrl;
  static const String _defaultBaseUrl = _localApiBaseUrl;
  static const String _tokenStorageKey = 'token';
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  static List<dynamic>? _universitiesCache;
  static DateTime? _universitiesCacheTime;
  static List<dynamic>? _institutionsCache;
  static DateTime? _institutionsCacheTime;
  static List<dynamic>? _governmentCache;
  static DateTime? _governmentCacheTime;
  static List<dynamic>? _organizationDirectoryCache;
  static DateTime? _organizationDirectoryCacheTime;
  static Map<String, dynamic>? _unreadNotificationsCache;
  static DateTime? _unreadNotificationsCacheTime;
  static Map<String, dynamic>? _profileCache;
  static DateTime? _profileCacheTime;
  static final Map<String, Map<String, dynamic>> _trainingCache = {};
  static final Map<String, DateTime> _trainingCacheTime = {};
  static Map<String, dynamic>? _organizationtrainingCache;
  static DateTime? _organizationtrainingCacheTime;
  static final Dio _sharedDio = Dio();
  static const FlutterSecureStorage _sharedStorage = FlutterSecureStorage();
  static bool _isDioConfigured = false;

  static String _normalizeBaseUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return trimmed;

    final withScheme =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
        ? trimmed
        : 'http://$trimmed';

    return withScheme.replaceFirst(RegExp(r'/*$'), '');
  }

  static bool _isValidIpv4Host(String host) {
    final parts = host.split('.');
    if (parts.length != 4) return false;

    for (final part in parts) {
      if (part.isEmpty || !RegExp(r'^\d+$').hasMatch(part)) {
        return false;
      }

      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return false;
      }
    }

    return true;
  }

  static bool _isUsableBaseUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) {
      return false;
    }

    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      return false;
    }

    final host = uri.host.trim().toLowerCase();
    if (RegExp(r'^[\d.]+$').hasMatch(host)) {
      return _isValidIpv4Host(host);
    }

    return true;
  }

  static String _validatedBaseUrlOrFallback({
    required String candidate,
    required String fallback,
    required String sourceName,
  }) {
    final normalizedCandidate = _normalizeBaseUrl(candidate);
    if (_isUsableBaseUrl(normalizedCandidate)) {
      return normalizedCandidate;
    }

    final normalizedFallback = _normalizeBaseUrl(fallback);
    _log(
      'Ignoring invalid $sourceName="$candidate"; using $normalizedFallback',
    );
    return normalizedFallback;
  }

  static bool _isLoopbackHost(String host) {
    final normalized = host.trim().toLowerCase();
    return normalized == 'localhost' ||
        normalized == '127.0.0.1' ||
        normalized == '::1';
  }

  static String _appendCacheBust(String url, {int? cacheBust}) {
    if (cacheBust == null) return url;
    final separator = url.contains('?') ? '&' : '?';
    return '$url${separator}v=$cacheBust';
  }

  static String _resolveBaseUrl() {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _validatedBaseUrlOrFallback(
        candidate: _apiBaseUrlOverride,
        fallback: defaultTargetPlatform == TargetPlatform.android
            ? _defaultAndroidDeviceApiBaseUrl
            : _defaultBaseUrl,
        sourceName: 'API_BASE_URL',
      );
    }

    if (kIsWeb) {
      return _normalizeBaseUrl(_webBaseUrl);
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return _validatedBaseUrlOrFallback(
        candidate: _androidDeviceApiBaseUrl,
        fallback: _defaultAndroidDeviceApiBaseUrl,
        sourceName: 'ANDROID_LOCAL_API_BASE_URL',
      );
    }

    return _normalizeBaseUrl(_defaultBaseUrl);
  }

  // Any platform can still be overridden with --dart-define=API_BASE_URL=...
  final String baseUrl = _resolveBaseUrl();

  final Dio _dio = _sharedDio;
  final FlutterSecureStorage _storage = _sharedStorage;

  ApiService() {
    if (_isDioConfigured) return;

    _log('ApiService baseUrl: $baseUrl');

    _dio.options.connectTimeout = kIsWeb
        ? const Duration(seconds: 25)
        : const Duration(seconds: 20);
    _dio.options.receiveTimeout = kIsWeb
        ? const Duration(seconds: 30)
        : const Duration(seconds: 45);
    _dio.options.headers = {'Content-Type': 'application/json'};

    // Add logging interceptor for debugging
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _log('${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _log(
            ' ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (DioException e, handler) {
          _log(' ${e.type} ${e.requestOptions.path}: ${e.message}');
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

  String? resolveAssetUrl(String? assetPath, {int? cacheBust}) {
    final candidates = resolveAssetUrlCandidates(
      assetPath,
      cacheBust: cacheBust,
    );
    if (candidates.isEmpty) {
      return null;
    }
    return candidates.first;
  }

  List<String> resolveAssetUrlCandidates(String? assetPath, {int? cacheBust}) {
    final trimmed = (assetPath ?? '').trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final urls = <String>[];

    void addUrl(String? value) {
      final normalized = _normalizeBaseUrl(value ?? '');
      if (normalized.isEmpty) return;
      urls.add(_appendCacheBust(normalized, cacheBust: cacheBust));
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      final parsed = Uri.tryParse(trimmed);
      addUrl(trimmed);

      if (parsed != null && _isLoopbackHost(parsed.host)) {
        final currentBaseUri = Uri.tryParse(baseUrl);
        if (currentBaseUri != null && !_isLoopbackHost(currentBaseUri.host)) {
          addUrl(
            currentBaseUri
                .replace(path: parsed.path, query: parsed.query)
                .toString(),
          );
        }

        final alternateLoopbackHost = parsed.host == 'localhost'
            ? '127.0.0.1'
            : 'localhost';
        addUrl(parsed.replace(host: alternateLoopbackHost).toString());

        final productionUri = Uri.tryParse(_normalizeBaseUrl(_defaultBaseUrl));
        if (productionUri != null && !_isLoopbackHost(productionUri.host)) {
          addUrl(
            productionUri
                .replace(path: parsed.path, query: parsed.query)
                .toString(),
          );
        }
      }
    } else {
      final normalizedPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      addUrl('$baseUrl$normalizedPath');

      final baseUri = Uri.tryParse(baseUrl);
      if (baseUri != null && _isLoopbackHost(baseUri.host)) {
        final alternateLoopbackHost = baseUri.host == 'localhost'
            ? '127.0.0.1'
            : 'localhost';
        addUrl(
          baseUri
              .replace(host: alternateLoopbackHost, path: normalizedPath)
              .toString(),
        );

        final productionBase = _normalizeBaseUrl(_defaultBaseUrl);
        final productionUri = Uri.tryParse(productionBase);
        if (productionUri != null && !_isLoopbackHost(productionUri.host)) {
          addUrl(productionUri.replace(path: normalizedPath).toString());
        }
      }
    }

    return urls.toSet().toList(growable: false);
  }

  static bool _isFresh(DateTime? timestamp, Duration ttl) {
    if (timestamp == null) return false;
    return DateTime.now().difference(timestamp) < ttl;
  }

  static void _invalidateProfileCache() {
    _profileCache = null;
    _profileCacheTime = null;
  }

  static void _invalidatetrainingCache() {
    _trainingCache.clear();
    _trainingCacheTime.clear();
    _organizationtrainingCache = null;
    _organizationtrainingCacheTime = null;
  }

  static void _invalidateCachesForPath(String path) {
    if (path.startsWith('/api/auth/profile') ||
        path.startsWith('/api/resume')) {
      _invalidateProfileCache();
    }

    if (path.startsWith('/api/training') ||
        path.startsWith('/api/applications')) {
      _invalidatetrainingCache();
    }

    if (path.startsWith('/api/notifications')) {
      _unreadNotificationsCache = null;
      _unreadNotificationsCacheTime = null;
    }
  }

  static String _trainingCacheKey({
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

  static bool _shouldRetryOnWakeup({
    required bool isWeb,
    required String method,
    required String path,
  }) {
    if (isWeb && method == 'GET') {
      return true;
    }

    return !isWeb && method == 'POST' && path == '/api/auth/login';
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
    final normalized = sanitizeUserMessage(
      message,
      fallback: 'Authentication failed. Please try again.',
    );
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

  static String sanitizeUserMessage(
    String? message, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    final normalized = (message ?? '')
        .split('\n')
        .map((line) => line.trim())
        .firstWhere((line) => line.isNotEmpty, orElse: () => '')
        .replaceFirst('Exception: ', '')
        .replaceFirst('DioException: ', '')
        .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
        .replaceFirst(
          RegExp(
            r'^(error|typeerror|filesystemexception|formatexception):\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    if (normalized.isEmpty || normalized.toLowerCase() == 'null') {
      return fallback;
    }

    final lowerMessage = normalized.toLowerCase();

    if (lowerMessage.contains('invalid email or password') ||
        lowerMessage.contains('invalid credentials') ||
        lowerMessage.contains('wrong password') ||
        lowerMessage.contains('user not found')) {
      return 'Invalid email or password.';
    }

    if (lowerMessage.contains('email already registered') ||
        lowerMessage.contains('email already exists') ||
        lowerMessage.contains('already registered') ||
        lowerMessage.contains('already exists')) {
      return 'This email is already registered. Please log in or reset your password.';
    }

    if (lowerMessage.contains('unauthorized') ||
        lowerMessage.contains('forbidden') ||
        lowerMessage.contains('jwt') ||
        (lowerMessage.contains('token') &&
            (lowerMessage.contains('expired') ||
                lowerMessage.contains('invalid')))) {
      return 'Your session has expired. Please log in again.';
    }

    if (lowerMessage.contains('timeout') ||
        lowerMessage.contains('socket') ||
        lowerMessage.contains('xmlhttprequest') ||
        lowerMessage.contains('clientexception') ||
        lowerMessage.contains('connection error') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('network error') ||
        lowerMessage.contains('failed host lookup') ||
        lowerMessage.contains('cannot connect') ||
        lowerMessage.contains('network is unreachable')) {
      return 'Network error. Please check your internet connection and try again.';
    }

    if (lowerMessage.contains('status code 404') ||
        lowerMessage == 'not found') {
      return 'The requested information could not be found.';
    }

    if (lowerMessage.contains('status code 413') ||
        lowerMessage.contains('file too large') ||
        lowerMessage.contains('too large')) {
      return 'The selected file is too large.';
    }

    if (lowerMessage.contains('status code 415') ||
        lowerMessage.contains('unsupported media type')) {
      return 'That file type is not supported.';
    }

    if (lowerMessage.contains('identification card') &&
        (lowerMessage.contains('pdf') ||
            lowerMessage.contains('jpg') ||
            lowerMessage.contains('jpeg') ||
            lowerMessage.contains('png') ||
            lowerMessage.contains('webp'))) {
      return 'Only PDF files are allowed for identification cards.';
    }

    if (lowerMessage.contains('status code 429') ||
        lowerMessage.contains('too many requests')) {
      return 'Too many attempts. Please wait a moment and try again.';
    }

    if (lowerMessage.contains('status code 409') ||
        lowerMessage.contains('conflict')) {
      return 'This information already exists. Please review your details and try again.';
    }

    if (lowerMessage.contains('status code 500') ||
        lowerMessage.contains('status code 502') ||
        lowerMessage.contains('status code 503') ||
        lowerMessage.contains('<!doctype html') ||
        lowerMessage.contains('<html') ||
        lowerMessage.contains('</html>') ||
        lowerMessage.contains('<body') ||
        lowerMessage.contains('</body>') ||
        lowerMessage.contains('internal server error') ||
        lowerMessage.contains('unexpected error') ||
        lowerMessage.contains('null check operator') ||
        lowerMessage.contains('typeerror') ||
        lowerMessage.contains('database') ||
        lowerMessage.contains('sqlstate') ||
        lowerMessage.contains('stack trace')) {
      return fallback;
    }

    return normalized;
  }

  static String normalizeErrorMessage(
    Object? error, {
    String fallback = 'Something went wrong. Please try again.',
  }) {
    if (error is DioException) {
      final responseData = error.response?.data;
      final structuredMessage = _extractErrorMessage(responseData);
      if (structuredMessage != null && structuredMessage.isNotEmpty) {
        return sanitizeUserMessage(structuredMessage, fallback: fallback);
      }

      final rawMessage = error.message?.trim() ?? '';
      if (rawMessage.isNotEmpty &&
          !rawMessage.toLowerCase().contains('status code of')) {
        return sanitizeUserMessage(rawMessage, fallback: fallback);
      }
    }

    final message = (error?.toString() ?? '')
        .replaceFirst('Exception: ', '')
        .replaceFirst('DioException: ', '')
        .replaceFirst(RegExp(r'^DioException \[[^\]]+\]:\s*'), '')
        .trim();

    return sanitizeUserMessage(message, fallback: fallback);
  }

  static String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final message = data['message'] ?? data['error'];
      final normalized = '$message'.trim();
      if (normalized.isNotEmpty && normalized.toLowerCase() != 'null') {
        return normalized;
      }
      return null;
    }

    if (data is List<int>) {
      try {
        final decoded = utf8.decode(data).trim();
        if (decoded.isEmpty) return null;
        final parsed = jsonDecode(decoded);
        return _extractErrorMessage(parsed) ?? decoded;
      } catch (_) {
        return null;
      }
    }

    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        final parsed = jsonDecode(trimmed);
        return _extractErrorMessage(parsed) ?? trimmed;
      } catch (_) {
        return trimmed;
      }
    }

    return null;
  }

  static bool _looksLikePdfBytes(List<int> bytes) {
    if (bytes.length < 5) {
      return false;
    }

    return bytes[0] == 0x25 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x44 &&
        bytes[3] == 0x46 &&
        bytes[4] == 0x2D;
  }

  static String responseMessage(
    Map<String, dynamic>? response, {
    String fallback = 'Request failed. Please try again.',
  }) {
    final responseData = response?['data'];
    final nestedMessage = responseData is Map<String, dynamic>
        ? responseData['message']
        : null;
    final raw = response?['message'] ?? response?['error'] ?? nestedMessage;

    final message = '$raw'.trim();
    if (message.isEmpty || message.toLowerCase() == 'null') {
      return fallback;
    }

    return sanitizeUserMessage(message, fallback: fallback);
  }

  Future<String?> getToken() async {
    try {
      final token = await _storage.read(key: _tokenStorageKey);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (error) {
      _log('Secure token read failed: $error');
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final token = preferences.getString(_tokenStorageKey);
      if (token != null && token.isNotEmpty) {
        return token;
      }
    } catch (error) {
      _log(' SharedPreferences token read failed: $error');
    }

    return null;
  }

  Future<void> setToken(String token) async {
    try {
      await _storage.write(key: _tokenStorageKey, value: token);
    } catch (error) {
      _log(' Secure token write failed: $error');
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenStorageKey, token);
      return;
    } catch (error) {
      _log(' SharedPreferences token write failed: $error');
    }

    throw Exception(
      'Unable to save login session right now. Please try again.',
    );
  }

  String _resolveFileUrl(String pathOrUrl) {
    final trimmed = pathOrUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    final normalized = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return '$baseUrl$normalized';
  }

  Future<Uint8List> downloadFileBytes(
    String pathOrUrl, {
    bool requiresAuth = false,
  }) async {
    final resolvedUrl = _resolveFileUrl(pathOrUrl);
    return _downloadFileBytesInternal(resolvedUrl, requiresAuth: requiresAuth);
  }

  Future<Uint8List> _downloadFileBytesInternal(
    String resolvedUrl, {
    required bool requiresAuth,
  }) async {
    final token = requiresAuth ? await getToken() : null;
    final headers = <String, dynamic>{};
    if (requiresAuth && token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await Dio().get<List<int>>(
      resolvedUrl,
      options: Options(
        headers: headers.isEmpty ? null : headers,
        responseType: ResponseType.bytes,
        followRedirects: false,
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
        validateStatus: (_) => true,
      ),
    );

    final statusCode = response.statusCode ?? 0;

    if (statusCode >= 300 && statusCode < 400) {
      final location = response.headers.value('location');
      if (location == null || location.trim().isEmpty) {
        throw Exception('Download link is invalid.');
      }

      final redirectedUrl = Uri.parse(resolvedUrl).resolve(location).toString();
      return _downloadFileBytesInternal(redirectedUrl, requiresAuth: false);
    }

    if (statusCode >= 200 && statusCode < 300) {
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw Exception('Downloaded file is empty.');
      }

      final contentType =
          response.headers.value('content-type')?.toLowerCase().trim() ?? '';
      if (!contentType.contains('application/pdf') &&
          !_looksLikePdfBytes(bytes)) {
        throw Exception(
          _extractErrorMessage(bytes) ??
              'Downloaded file is not a valid PDF document.',
        );
      }

      return Uint8List.fromList(bytes);
    }

    throw Exception(
      _extractErrorMessage(response.data) ??
          'Request failed with status code $statusCode.',
    );
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

  void _cacheProfileFromAuthResponse(Map<String, dynamic> response) {
    final data = response['data'];
    if (data is! Map<String, dynamic>) return;

    final nestedData = data['data'];
    final user = nestedData is Map<String, dynamic>
        ? nestedData['user']
        : data['user'];

    if (user is! Map<String, dynamic>) return;

    _profileCache = {
      'success': true,
      'data': {'user': user},
    };
    _profileCacheTime = DateTime.now();
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    dynamic data,
    bool requiresAuth = false,
    Map<String, dynamic>? queryParams,
  }) async {
    final normalizedMethod = method.toUpperCase();
    final requestUrl = '$baseUrl$path';
    final shouldRetryOnWakeup = _shouldRetryOnWakeup(
      isWeb: kIsWeb,
      method: normalizedMethod,
      path: path,
    );

    Future<Response<dynamic>> sendRequest() async {
      final token = requiresAuth ? await getToken() : null;
      final options = Options(
        method: normalizedMethod,
        headers: {
          if (requiresAuth && token != null && token.isNotEmpty)
            'Authorization': 'Bearer $token',
          if (data is FormData) 'Content-Type': 'multipart/form-data',
        },
      );

      return _dio.request(
        requestUrl,
        data: data,
        options: options,
        queryParameters: queryParams,
      );
    }

    try {
      final response = await sendRequest();
      return response.data;
    } on DioException catch (e) {
      _log('DioException ${e.type}: ${e.message}');

      if (e.type == DioExceptionType.connectionTimeout) {
        if (shouldRetryOnWakeup) {
          await Future.delayed(const Duration(seconds: 4));

          try {
            final retryResponse = await sendRequest();
            return retryResponse.data;
          } on DioException catch (retryError) {
            _log(
              ' Timeout retry failed ${retryError.type}: ${retryError.message}',
            );
          }
        }

        throw Exception(
          kIsWeb
              ? 'Connection timeout. The local server may be unavailable. Please wait a few seconds and try again.'
              : 'Connection timeout from $baseUrl. The local server may be unavailable. Please wait a moment and try again.',
        );
      } else if (e.type == DioExceptionType.receiveTimeout) {
        if (shouldRetryOnWakeup) {
          await Future.delayed(const Duration(seconds: 4));

          try {
            final retryResponse = await sendRequest();
            return retryResponse.data;
          } on DioException catch (retryError) {
            _log(
              ' Receive-timeout retry failed ${retryError.type}: ${retryError.message}',
            );
          }
        }

        throw Exception(
          kIsWeb
              ? 'Server is taking too long to respond. Please try again shortly.'
              : 'Server at $baseUrl is taking too long to respond. Please try again shortly.',
        );
      } else if (e.type == DioExceptionType.connectionError) {
        if (shouldRetryOnWakeup) {
          await Future.delayed(const Duration(seconds: 3));

          try {
            final retryResponse = await sendRequest();
            return retryResponse.data;
          } on DioException catch (retryError) {
            _log(' Retry failed ${retryError.type}: ${retryError.message}');
          }
        }

        final overrideHint = kIsWeb
            ? 'If you are deploying the web app, rebuild with --dart-define=API_BASE_URL=https://YOUR-API-DOMAIN'
            : 'Android now uses $_androidDeviceApiBaseUrl by default, while Chrome/web uses $_webBaseUrl. If your PC IP changes, run with --dart-define=API_BASE_URL=http://YOUR-LAPTOP-IP:5000 or --dart-define=ANDROID_LOCAL_API_BASE_URL=http://YOUR-LAPTOP-IP:5000. For USB debugging, you can still run `adb reverse tcp:5000 tcp:5000` and use http://localhost:5000.';
        throw Exception(
          kIsWeb
              ? 'Cannot connect to server at $baseUrl. Please wait a few seconds and refresh. $overrideHint'
              : 'Cannot connect to server at $baseUrl. $overrideHint',
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

        throw Exception(
          sanitizeUserMessage(
            errorMessage,
            fallback: 'Request failed. Please try again.',
          ),
        );
      }
      throw Exception(
        normalizeErrorMessage(e, fallback: 'Network error. Please try again.'),
      );
    } catch (e) {
      _log('Unexpected error: $e');
      throw Exception(normalizeErrorMessage(e));
    }
  }

  Future<MultipartFile> _createMultipartFile({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final contentType = _guessMultipartContentType(fileName);

    if (fileBytes != null) {
      return MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
        contentType: contentType,
      );
    }

    if (filePath != null && filePath.trim().isNotEmpty) {
      return MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: contentType,
      );
    }

    throw ArgumentError('A file path or file bytes is required for upload.');
  }

  DioMediaType? _guessMultipartContentType(String fileName) {
    final normalized = fileName.trim().toLowerCase();

    if (normalized.endsWith('.pdf')) {
      return DioMediaType.parse('application/pdf');
    }
    if (normalized.endsWith('.doc')) {
      return DioMediaType.parse('application/msword');
    }
    if (normalized.endsWith('.docx')) {
      return DioMediaType.parse(
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      );
    }
    if (normalized.endsWith('.png')) {
      return DioMediaType.parse('image/png');
    }
    if (normalized.endsWith('.webp')) {
      return DioMediaType.parse('image/webp');
    }
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return DioMediaType.parse('image/jpeg');
    }

    return null;
  }

  bool _looksLikePdfUpload(String? fileName, String? filePath) {
    final normalizedFileName = (fileName ?? '').trim().toLowerCase();
    final normalizedFilePath = (filePath ?? '').trim().toLowerCase();
    return normalizedFileName.endsWith('.pdf') ||
        normalizedFilePath.endsWith('.pdf');
  }

  // ==================== AUTH METHODS ====================
  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await _request(
        'POST',
        '/api/auth/login',
        data: {'email': email, 'password': password},
      );

      _log('Login API response: $response');

      // Check different response structures
      if (response['success'] == true || response['token'] != null) {
        final token = _extractAuthToken(response);

        if (token != null) {
          await setToken(token);
        }

        _cacheProfileFromAuthResponse(response);

        return {'success': true, 'data': response};
      }

      // Ensure message is always present for error responses
      final errorMessage = response['message']?.toString() ?? 'Login failed';
      final sanitizedMessage = _sanitizeAuthResponseMessage(errorMessage);

      _log(
        'Login failed - Raw message: $errorMessage, Sanitized: $sanitizedMessage',
      );

      return {...response, 'message': sanitizedMessage, 'success': false};
    } catch (e) {
      _log('Login error caught: $e');
      final normalizedError = _normalizeLoginErrorMessage(e);
      _log('Normalized login error: $normalizedError');
      return {'success': false, 'message': normalizedError};
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
      _log('Verify account password error: $e');
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
      return {
        'success': false,
        'message': normalizeErrorMessage(
          e,
          fallback: 'Failed to send password reset link. Please try again.',
        ),
      };
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
      _log(' Complete password reset error: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(
          e,
          fallback: 'Failed to reset password. Please try again.',
        ),
      };
    }
  }

  Future<Map<String, dynamic>> register(
    Map<String, dynamic> userData, {
    String? identificationCardFilePath,
    Uint8List? identificationCardFileBytes,
    String? identificationCardFileName,
    String? collegeLogoFilePath,
    Uint8List? collegeLogoFileBytes,
    String? collegeLogoFileName,
  }) async {
    try {
      final hasIdentificationFile =
          (identificationCardFilePath != null &&
              identificationCardFilePath.trim().isNotEmpty) ||
          identificationCardFileBytes != null;
      final hasCollegeLogoFile =
          (collegeLogoFilePath != null &&
              collegeLogoFilePath.trim().isNotEmpty) ||
          collegeLogoFileBytes != null;
      if (hasIdentificationFile &&
          !_looksLikePdfUpload(
            identificationCardFileName,
            identificationCardFilePath,
          )) {
        return {
          'success': false,
          'message': 'Only PDF files are allowed for identification cards.',
        };
      }

      final payload = hasIdentificationFile || hasCollegeLogoFile
          ? FormData.fromMap({
              ...userData,
              if (hasIdentificationFile)
                'identification_card': await _createMultipartFile(
                  filePath: identificationCardFilePath,
                  fileBytes: identificationCardFileBytes,
                  fileName:
                      identificationCardFileName ?? 'identification_card.pdf',
                ),
              if (hasCollegeLogoFile)
                'college_logo': await _createMultipartFile(
                  filePath: collegeLogoFilePath,
                  fileBytes: collegeLogoFileBytes,
                  fileName: collegeLogoFileName ?? 'college_logo.png',
                ),
            })
          : userData;

      final response = await _request(
        'POST',
        '/api/auth/register',
        data: payload,
      );
      final token = _extractAuthToken(response);

      if (token != null) {
        await setToken(token);
      }

      _cacheProfileFromAuthResponse(response);

      return {'success': true, 'data': response};
    } catch (e) {
      _log('Registration error: $e');
      return {
        'success': false,
        'message': _sanitizeAuthResponseMessage(
          normalizeErrorMessage(e, fallback: 'Registration failed'),
        ),
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
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateProfile(
    Map<String, dynamic> data, {
    String? identificationCardFilePath,
    Uint8List? identificationCardFileBytes,
    String? identificationCardFileName,
  }) async {
    try {
      final hasIdentificationFile =
          (identificationCardFilePath != null &&
              identificationCardFilePath.trim().isNotEmpty) ||
          identificationCardFileBytes != null;

      if (hasIdentificationFile &&
          !_looksLikePdfUpload(
            identificationCardFileName,
            identificationCardFilePath,
          )) {
        return {
          'success': false,
          'message': 'Only PDF files are allowed for identification cards.',
        };
      }

      final payload = hasIdentificationFile
          ? FormData.fromMap({
              ...data,
              if (data['student_data'] is Map<String, dynamic>)
                'student_data': jsonEncode(data['student_data']),
              'identification_card': await _createMultipartFile(
                filePath: identificationCardFilePath,
                fileBytes: identificationCardFileBytes,
                fileName:
                    identificationCardFileName ?? 'identification_card.pdf',
              ),
            })
          : data;

      final response = await _request(
        'PUT',
        '/api/auth/profile',
        data: payload,
        requiresAuth: true,
      );
      _invalidateProfileCache();
      return response;
    } catch (e) {
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<void> logout() async {
    try {
      await _storage.delete(key: _tokenStorageKey);
    } catch (error) {
      _log('Secure token delete failed: $error');
    }
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_tokenStorageKey);
    } catch (error) {
      _log(' SharedPreferences token delete failed: $error');
    }
    _unreadNotificationsCache = null;
    _unreadNotificationsCacheTime = null;
    _invalidateProfileCache();
    _invalidatetrainingCache();
  }

  // ==================== JOB METHODS ====================
  Future<Map<String, dynamic>> gettraining({
    String? type,
    String? location,
    String? limit,
    String? search,
    String? view,
    bool forceRefresh = false,
    bool requiresAuth = true,
  }) async {
    Map<String, dynamic> query = {};
    if (type != null && type != 'all') query['type'] = type;
    if (location != null && location != 'all') query['location'] = location;
    if (limit != null) query['limit'] = limit;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (view != null && view.isNotEmpty) query['view'] = view;
    final cacheKey = _trainingCacheKey(
      type: query['type']?.toString(),
      location: query['location']?.toString(),
      limit: query['limit']?.toString(),
      search: query['search']?.toString(),
      view: query['view']?.toString(),
    );
    final selectedView = query['view']?.toString() ?? 'open';
    final shouldUseCache = selectedView == 'history';

    if (!forceRefresh &&
        shouldUseCache &&
        _isFresh(_trainingCacheTime[cacheKey], const Duration(seconds: 30))) {
      final cached = _trainingCache[cacheKey];
      if (cached != null) {
        return cached;
      }
    }

    final response = await _request(
      'GET',
      '/api/training',
      queryParams: query,
      requiresAuth: requiresAuth,
    );
    if (response['success'] == true) {
      _trainingCache[cacheKey] = response;
      _trainingCacheTime[cacheKey] = DateTime.now();
    }
    return response;
  }

  Future<Map<String, dynamic>> gettrainingWithLimit(String limit) async {
    return await gettraining(limit: limit);
  }

  Future<Map<String, dynamic>> getJobById(String jobId) async {
    return await _request('GET', '/api/training/$jobId', requiresAuth: true);
  }

  Future<Map<String, dynamic>> getorganizationtraining({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _isFresh(_organizationtrainingCacheTime, const Duration(seconds: 20))) {
      final cached = _organizationtrainingCache;
      if (cached != null) {
        return cached;
      }
    }

    final response = await _request(
      'GET',
      '/api/training/organization/my-training',
      requiresAuth: true,
    );
    if (response['success'] == true) {
      _organizationtrainingCache = response;
      _organizationtrainingCacheTime = DateTime.now();
    }
    return response;
  }

  // Alias method for backward compatibility
  Future<Map<String, dynamic>> getOrganizationtraining({
    bool forceRefresh = false,
  }) async {
    return getorganizationtraining(forceRefresh: forceRefresh);
  }

  Future<Map<String, dynamic>> postJob(Map<String, dynamic> jobData) async {
    final response = await _request(
      'POST',
      '/api/training',
      data: jobData,
      requiresAuth: true,
    );
    _invalidatetrainingCache();
    return response;
  }

  Future<Map<String, dynamic>> updateJob(
    String jobId,
    Map<String, dynamic> data,
  ) async {
    final response = await _request(
      'PUT',
      '/api/training/$jobId',
      data: data,
      requiresAuth: true,
    );
    _invalidatetrainingCache();
    return response;
  }

  Future<Map<String, dynamic>> deleteJob(String jobId) async {
    final response = await _request(
      'DELETE',
      '/api/training/$jobId',
      requiresAuth: true,
    );
    _invalidatetrainingCache();
    return response;
  }

  // ==================== APPLICATION METHODS ====================
  Future<Map<String, dynamic>> applyForJob({
    required String jobId,
    String coverLetter = '',
    String? coverLetterPath,
    Uint8List? coverLetterBytes,
    String? coverLetterFileName,
    String? supportiveDocumentPath,
    Uint8List? supportiveDocumentBytes,
    String? supportiveDocumentName,
  }) async {
    try {
      final token = await getToken();
      final data = <String, dynamic>{
        'job_id': jobId,
        'cover_letter': coverLetter,
      };

      final hasCoverLetterFile =
          (coverLetterPath != null && coverLetterPath.isNotEmpty) ||
          coverLetterBytes != null;
      if (hasCoverLetterFile &&
          coverLetterFileName != null &&
          coverLetterFileName.trim().isNotEmpty) {
        data['cover_letter_file'] = await _createMultipartFile(
          filePath: coverLetterPath,
          fileBytes: coverLetterBytes,
          fileName: coverLetterFileName,
        );
      }

      final hasSupportiveDocument =
          (supportiveDocumentPath != null &&
              supportiveDocumentPath.isNotEmpty) ||
          supportiveDocumentBytes != null;

      if (hasSupportiveDocument &&
          supportiveDocumentName != null &&
          supportiveDocumentName.trim().isNotEmpty) {
        data['supportive_document'] = await _createMultipartFile(
          filePath: supportiveDocumentPath,
          fileBytes: supportiveDocumentBytes,
          fileName: supportiveDocumentName,
        );
      }

      final formData = FormData.fromMap(data);

      final response = await _dio.post(
        '$baseUrl/api/applications',
        data: formData,
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'multipart/form-data',
          },
        ),
      );
      _invalidatetrainingCache();
      return response.data;
    } on DioException catch (e) {
      _log('Error applying for job: $e');
      final errorData = e.response?.data;
      if (errorData is Map &&
          (errorData['message'] != null || errorData['error'] != null)) {
        return {
          'success': false,
          'message': errorData['message'] ?? errorData['error'],
        };
      }
      return {
        'success': false,
        'message': 'Failed to submit application: ${e.message}',
      };
    }
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

  Future<Map<String, dynamic>> getorganizationApplications() async {
    return await _request(
      'GET',
      '/api/applications/organization',
      requiresAuth: true,
    );
  }

  // Alias method for backward compatibility
  Future<Map<String, dynamic>> getOrganizationApplications() async {
    return getorganizationApplications();
  }

  Future<Map<String, dynamic>> confirmApplicationSelection(
    String applicationId,
  ) async {
    return await _request(
      'POST',
      '/api/applications/$applicationId/confirm-selection',
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

  Future<Map<String, dynamic>> reviewApplicationDocument({
    required String applicationId,
    required bool isAuthentic,
    String? verificationNotes,
  }) async {
    return await _request(
      'PUT',
      '/api/applications/$applicationId/document-review',
      data: {
        'supportive_document_verified': isAuthentic,
        'verification_notes': verificationNotes?.trim() ?? '',
      },
      requiresAuth: true,
    );
  }

  Future<Map<String, dynamic>> updateApplicationStatusWithLetter({
    required String applicationId,
    required String status,
    String? feedback,
    String? scheduledDate,
    String? scheduledVenue,
    String? reportingStartDate,
    String? reportingEndDate,
    Map<String, dynamic>? acceptanceLetterData,
    String? responseLetterPath,
    Uint8List? responseLetterBytes,
    String? responseLetterName,
  }) async {
    try {
      final token = await getToken();
      final data = <String, dynamic>{
        'status': status,
        ...(feedback == null ? const {} : {'feedback': feedback}),
        ...(scheduledDate == null ? const {} : {'_date': scheduledDate}),
        ...(scheduledVenue == null ? const {} : {'_venue': scheduledVenue}),
        ...(reportingStartDate == null
            ? const {}
            : {'reporting_start_date': reportingStartDate}),
        ...(reportingEndDate == null
            ? const {}
            : {'reporting_end_date': reportingEndDate}),
        ...?acceptanceLetterData,
      };

      final hasResponseLetterUpload =
          responseLetterPath != null ||
          responseLetterBytes != null ||
          (responseLetterName != null && responseLetterName.trim().isNotEmpty);

      if (hasResponseLetterUpload) {
        data['response_letter'] = await _createMultipartFile(
          filePath: responseLetterPath,
          fileBytes: responseLetterBytes,
          fileName: responseLetterName ?? 'response_letter.pdf',
        );

        final response = await _dio.put(
          '$baseUrl/api/applications/$applicationId',
          data: FormData.fromMap(data),
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/form-data',
            },
          ),
        );
        return response.data;
      }

      final response = await _dio.put(
        '$baseUrl/api/applications/$applicationId',
        data: data,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data;
    } on DioException catch (e) {
      _log(' Error updating application status: $e');
      final errorData = e.response?.data;
      if (errorData is Map &&
          (errorData['message'] != null || errorData['error'] != null)) {
        return {
          'success': false,
          'message': errorData['message'] ?? errorData['error'],
        };
      }
      return {
        'success': false,
        'message': 'Failed to update application: ${e.message}',
      };
    }
  }

  // ==================== AWARDS METHODS ====================
  Future<Map<String, dynamic>> getAwardsHomeData() async {
    try {
      return await _request('GET', '/api/awards/home');
    } catch (e) {
      _log('❌ Error loading awards home: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getWallOfFame({int limit = 60}) async {
    try {
      return await _request(
        'GET',
        '/api/awards/wall-of-fame',
        queryParams: {'limit': '$limit'},
      );
    } catch (e) {
      _log('Error loading wall of fame: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getAwardsLeaderboard({int limit = 20}) async {
    try {
      return await _request(
        'GET',
        '/api/awards/leaderboard',
        queryParams: {'limit': '$limit'},
      );
    } catch (e) {
      _log('Error loading awards leaderboard: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  // ==================== SKILLS METHODS ====================
  Future<Map<String, dynamic>> getAllSkills() async {
    return await _request('GET', '/api/skills/all', requiresAuth: true);
  }

  Future<Map<String, dynamic>> getSkills() async {
    return await _request('GET', '/api/skills/all', requiresAuth: true);
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

  Future<Map<String, dynamic>> deleteNotification(String notificationId) async {
    final response = await _request(
      'DELETE',
      '/api/notifications/$notificationId',
      requiresAuth: true,
    );
    _unreadNotificationsCache = null;
    _unreadNotificationsCacheTime = null;
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
  static List<dynamic> _onlySingleUniversityOptions(dynamic data) {
    if (data is! List) return const [];

    return data
        .where((item) {
          if (item is! Map) return false;
          final name = '${item['name'] ?? ''}'.trim().toLowerCase();
          return _singleUniversityNames.contains(name);
        })
        .toList(growable: false);
  }

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
        final universities = _onlySingleUniversityOptions(data);
        response['data'] = universities;
        _universitiesCache = List<dynamic>.from(universities);
        _universitiesCacheTime = DateTime.now();
      }

      return response;
    } catch (e) {
      _log(' Error getting universities: $e');
      if (_universitiesCache != null) {
        return {'success': true, 'data': _universitiesCache};
      }
      return {
        'success': false,
        'message': normalizeErrorMessage(
          e,
          fallback: 'Failed to load universities right now.',
        ),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getInstitutions({
    bool forceRefresh = false,
  }) async {
    final hasFreshCache =
        _institutionsCache != null &&
        _institutionsCacheTime != null &&
        DateTime.now().difference(_institutionsCacheTime!) <
            const Duration(hours: 6);

    if (!forceRefresh && hasFreshCache) {
      return {'success': true, 'data': _institutionsCache};
    }

    try {
      final response = await _request('GET', '/api/auth/', requiresAuth: false);

      final data = response['data'];
      if (response['success'] == true && data is List) {
        _institutionsCache = List<dynamic>.from(data);
        _institutionsCacheTime = DateTime.now();
      }

      return response;
    } catch (e) {
      _log('Error getting institutions: $e');
      if (_institutionsCache != null) {
        return {'success': true, 'data': _institutionsCache};
      }
      return {
        'success': false,
        'message': normalizeErrorMessage(
          e,
          fallback: 'Failed to load institutions right now.',
        ),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getGovernment({
    bool forceRefresh = false,
  }) async {
    final hasFreshCache =
        _governmentCache != null &&
        _governmentCacheTime != null &&
        DateTime.now().difference(_governmentCacheTime!) <
            const Duration(hours: 6);

    if (!forceRefresh && hasFreshCache) {
      return {'success': true, 'data': _governmentCache};
    }

    try {
      final response = await _request(
        'GET',
        '/api/auth/government-',
        requiresAuth: false,
      );

      final data = response['data'];
      if (response['success'] == true && data is List) {
        _governmentCache = List<dynamic>.from(data);
        _governmentCacheTime = DateTime.now();
      }

      return response;
    } catch (e) {
      _log('Error getting government : $e');
      if (_governmentCache != null) {
        return {'success': true, 'data': _governmentCache};
      }
      return {
        'success': false,
        'message': normalizeErrorMessage(
          e,
          fallback: 'Failed to load government  right now.',
        ),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getorganizationDirectory({
    bool forceRefresh = false,
    String? region,
    String? district,
  }) async {
    final normalizedRegion = region?.trim() ?? '';
    final normalizedDistrict = district?.trim() ?? '';
    final hasLocationFilter =
        normalizedRegion.isNotEmpty || normalizedDistrict.isNotEmpty;
    final hasFreshCache =
        !hasLocationFilter &&
        _organizationDirectoryCache != null &&
        _organizationDirectoryCacheTime != null &&
        DateTime.now().difference(_organizationDirectoryCacheTime!) <
            const Duration(hours: 6);

    if (!forceRefresh && hasFreshCache) {
      return {'success': true, 'data': _organizationDirectoryCache};
    }

    try {
      final response = await _request(
        'GET',
        '/api/auth/organization-directory',
        queryParams: {
          if (normalizedRegion.isNotEmpty) 'region': normalizedRegion,
          if (normalizedDistrict.isNotEmpty) 'district': normalizedDistrict,
        },
        requiresAuth: false,
      );

      final data = response['data'];
      if (!hasLocationFilter && response['success'] == true && data is List) {
        _organizationDirectoryCache = List<dynamic>.from(data);
        _organizationDirectoryCacheTime = DateTime.now();
      }

      return response;
    } catch (e) {
      _log(' Error getting organization directory: $e');
      if (!hasLocationFilter && _organizationDirectoryCache != null) {
        return {'success': true, 'data': _organizationDirectoryCache};
      }
      return {
        'success': false,
        'message': normalizeErrorMessage(
          e,
          fallback: 'Failed to load organization directory right now.',
        ),
        'data': [],
      };
    }
  }

  // ==================== PROJECT METHODS ====================
  Future<Map<String, dynamic>> getStudentProjects() async {
    try {
      return await _request('GET', '/api/projects/student', requiresAuth: true);
    } catch (e) {
      _log(' Error getting projects: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log('Error adding project: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log(' Error removing project: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  // ==================== RESUME METHODS ====================
  Future<Map<String, dynamic>> uploadResume({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    try {
      final token = await getToken();
      DioException? lastError;

      // Some backends expect different form keys for CV upload.
      for (final fieldName in const ['resume', 'cv', 'file', 'resume_file']) {
        try {
          FormData formData = FormData.fromMap({
            fieldName: await _createMultipartFile(
              filePath: filePath,
              fileBytes: fileBytes,
              fileName: fileName,
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
      throw Exception(
        normalizeErrorMessage(
          e,
          fallback: 'Failed to upload resume. Please try again.',
        ),
      );
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
      _log(' Error deleting resume: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> uploadStudentProfileImage({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    try {
      final token = await getToken();
      final formData = FormData.fromMap({
        'profile_image': await _createMultipartFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
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
      _log(' Error uploading student profile image: $e');
      throw Exception(
        normalizeErrorMessage(
          e,
          fallback: 'Failed to upload profile image. Please try again.',
        ),
      );
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
      _log(' Error deleting student profile image: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  // ==================== ORGANIZATION METHODS ====================
  Future<Map<String, dynamic>> getorganizationProfile() async {
    try {
      return await _request('GET', '/api/auth/profile', requiresAuth: true);
    } catch (e) {
      _log(' Error getting organization profile: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateorganizationProfile(
    Map<String, dynamic> data,
  ) async {
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
      _log(' Error updating organization profile: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  // ==================== ORGANIZATION LOGO METHODS ====================
  Future<Map<String, dynamic>> _uploadorganizationImageAsset({
    required String endpoint,
    String? fallbackEndpoint,
    required String fieldName,
    required String fileName,
    String? filePath,
    Uint8List? fileBytes,
    required String errorLabel,
  }) async {
    try {
      final token = await getToken();
      final formData = FormData.fromMap({
        fieldName: await _createMultipartFile(
          filePath: filePath,
          fileBytes: fileBytes,
          fileName: fileName,
        ),
      });

      Future<Response<dynamic>> sendUpload(String targetEndpoint) {
        return _dio.post(
          '$baseUrl$targetEndpoint',
          data: formData,
          options: Options(
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'multipart/form-data',
            },
          ),
        );
      }

      Response<dynamic> response;
      try {
        response = await sendUpload(endpoint);
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode;
        if (statusCode == 404 && fallbackEndpoint != null) {
          response = await sendUpload(fallbackEndpoint);
        } else {
          rethrow;
        }
      }

      _invalidateProfileCache();
      return response.data;
    } on DioException catch (e) {
      _log(' Error uploading $errorLabel: $e');
      throw Exception(
        normalizeErrorMessage(
          e,
          fallback: 'Failed to upload $errorLabel. Please try again.',
        ),
      );
    }
  }

  Future<Map<String, dynamic>> uploadorganizationLogo({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    return _uploadorganizationImageAsset(
      endpoint: '/api/organization/logo',
      fallbackEndpoint: '/api/company/logo',
      fieldName: 'logo',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      errorLabel: 'logo',
    );
  }

  // Alias method for backward compatibility
  Future<Map<String, dynamic>> uploadCompanyLogo({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    return uploadorganizationLogo(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  Future<Map<String, dynamic>> uploadorganizationStamp({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    return _uploadorganizationImageAsset(
      endpoint: '/api/organization/stamp',
      fallbackEndpoint: '/api/company/stamp',
      fieldName: 'stamp',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      errorLabel: 'stamp',
    );
  }

  // Alias method for backward compatibility
  Future<Map<String, dynamic>> uploadCompanyStamp({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    return uploadorganizationStamp(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  Future<Map<String, dynamic>> uploadorganizationSignature({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    return _uploadorganizationImageAsset(
      endpoint: '/api/organization/signature',
      fallbackEndpoint: '/api/company/signature',
      fieldName: 'signature',
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
      errorLabel: 'signature',
    );
  }

  // Alias method for backward compatibility
  Future<Map<String, dynamic>> uploadCompanySignature({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    return uploadorganizationSignature(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: fileName,
    );
  }

  // ==================== ADMIN METHODS ====================
  Future<Map<String, dynamic>> getAdminStats() async {
    try {
      return await _request('GET', '/api/admin/stats', requiresAuth: true);
    } catch (e) {
      _log(' Error getting admin stats: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getUsers() async {
    try {
      return await _request('GET', '/api/admin/users', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting users: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getAdmintraining() async {
    try {
      return await _request('GET', '/api/admin/training', requiresAuth: true);
    } catch (e) {
      _log('❌ Error getting admin training: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateUserRole(
    String userId,
    String role, {
    Map<String, dynamic>? studentData,
    Map<String, dynamic>? companyData,
    Map<String, dynamic>? universityData,
  }) async {
    try {
      final data = <String, dynamic>{
        'role': role,
        ...?(studentData == null ? null : {'student_data': studentData}),
        ...?(companyData == null ? null : {'company_data': companyData}),
        ...?(universityData == null
            ? null
            : {'university_data': universityData}),
      };
      return await _request(
        'PUT',
        '/api/admin/users/$userId/role',
        data: data,
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error updating user role: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> createAdminUser({
    required String fullName,
    required String email,
    required String password,
    String? phone,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/admin/users/admin',
        data: {
          'full_name': fullName,
          'email': email,
          'password': password,
          'phone': phone?.trim() ?? '',
        },
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error creating admin user: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log(' Error toggling user status: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log('Error sending reset link: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log('t Error verifying user: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log(' Error deleting user: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
      _log(' Error updating application status: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getAdminLogs() async {
    try {
      return await _request('GET', '/api/admin/logs', requiresAuth: true);
    } catch (e) {
      _log(' Error getting admin logs: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  // ===== NEW ADMIN STUDENT METHODS =====
  Future<Map<String, dynamic>> getAllAdminStudents() async {
    try {
      return await _request(
        'GET',
        '/api/admin/students/all',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error getting all admin students: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getStudentsWithUniversity() async {
    try {
      return await _request(
        'GET',
        '/api/admin/students/with-university',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting students with university: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getStudentsWithAwards() async {
    try {
      return await _request(
        'GET',
        '/api/admin/students/with-awards',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error getting students with awards: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getStudentsNoField() async {
    try {
      return await _request(
        'GET',
        '/api/admin/students/no-field',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error getting students no field: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getAdminTests() async {
    try {
      return await _request('GET', '/api/admin/tests', requiresAuth: true);
    } catch (e) {
      _log(' Error getting tests: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getOrganizationTests({String? jobId}) async {
    try {
      final query = jobId == null || jobId.trim().isEmpty
          ? null
          : {'job_id': jobId.trim()};
      return await _request(
        'GET',
        '/api/organization/tests',
        queryParams: query,
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting organization tests: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> createAdminTest(
    Map<String, dynamic> testData,
  ) async {
    try {
      return await _request(
        'POST',
        '/api/admin/tests',
        data: testData,
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error creating test: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> createOrganizationTest(
    Map<String, dynamic> testData,
  ) async {
    try {
      return await _request(
        'POST',
        '/api/organization/tests',
        data: testData,
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error creating organization test: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> inviteStudentsToTest({
    required String testId,
    required List<String> studentIds,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/admin/tests/$testId/invite',
        data: {'student_ids': studentIds},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error inviting students to test: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> inviteStudentsToOrganizationTest({
    required String testId,
    required List<String> studentIds,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/organization/tests/$testId/invite',
        data: {'student_ids': studentIds},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error inviting students to organization test: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getTestResults(String testId) async {
    try {
      return await _request(
        'GET',
        '/api/admin/tests/$testId/results',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting test results: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getOrganizationTestResults(String testId) async {
    try {
      return await _request(
        'GET',
        '/api/organization/tests/$testId/results',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting organization test results: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getTestAttemptAnswers(String attemptId) async {
    try {
      return await _request(
        'GET',
        '/api/admin/tests/attempts/$attemptId/answers',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting test attempt answers: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getOrganizationTestAttemptAnswers(
    String attemptId,
  ) async {
    try {
      return await _request(
        'GET',
        '/api/organization/tests/attempts/$attemptId/answers',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting organization test attempt answers: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateTestAnswerScore({
    required String answerId,
    required double scoreAwarded,
  }) async {
    try {
      return await _request(
        'PUT',
        '/api/admin/tests/answers/$answerId/score',
        data: {'score_awarded': scoreAwarded},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error updating test answer score: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateOrganizationTestAnswerScore({
    required String answerId,
    required double scoreAwarded,
  }) async {
    try {
      return await _request(
        'PUT',
        '/api/organization/tests/answers/$answerId/score',
        data: {'score_awarded': scoreAwarded},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error updating organization test answer score: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> applyAutoSelection({
    required String testId,
    required double minimumScore,
    required int topN,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/admin/tests/$testId/auto-selection',
        data: {'minimum_score': minimumScore, 'top_n': topN},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error applying auto-selection: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> applyOrganizationAutoSelection({
    required String testId,
    required double minimumScore,
    required int topN,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/organization/tests/$testId/auto-selection',
        data: {'minimum_score': minimumScore, 'top_n': topN},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error applying organization auto-selection: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getTestAttemptByToken(String token) async {
    try {
      return await _request('GET', '/api/tests/attempt/$token');
    } catch (e) {
      _log(' Error getting test attempt: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getMyTestAttempts() async {
    try {
      return await _request(
        'GET',
        '/api/tests/my-attempts',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting my test attempts: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> saveTestAttempt({
    required String token,
    required Map<String, String> answers,
  }) async {
    try {
      return await _request(
        'PUT',
        '/api/tests/attempt/$token/save',
        data: {'answers': answers},
      );
    } catch (e) {
      _log(' Error saving test attempt: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> submitTestAttempt({
    required String token,
    required Map<String, String> answers,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/tests/attempt/$token/submit',
        data: {'answers': answers},
      );
    } catch (e) {
      _log(' Error submitting test attempt: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getUniversityStudentsOverview() async {
    try {
      return await _request(
        'GET',
        '/api/university/students/overview',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting university students overview: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': {'students': []},
      };
    }
  }

  Future<Map<String, dynamic>> getUniversityPlacedStudents() async {
    try {
      return await _request(
        'GET',
        '/api/university/students/placed',
        requiresAuth: true,
      );
    } catch (e) {
      _log('❌ Error getting university placed students: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': {'placements': []},
      };
    }
  }

  Future<Map<String, dynamic>> getUniversityorganizationContacts() async {
    try {
      return await _request(
        'GET',
        '/api/university/companies/contacts',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting university organization contacts: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  // Alias for getUniversityorganizationContacts with alternative naming
  Future<Map<String, dynamic>> getUniversityCompanyContacts() async {
    return getUniversityorganizationContacts();
  }

  Future<Map<String, dynamic>> reserveUniversityCompanyJobSlot({
    required String companyId,
    required String jobId,
  }) async {
    try {
      final response = await _request(
        'POST',
        '/api/university/companies/$companyId/jobs/$jobId/reserve-slot',
        requiresAuth: true,
      );
      _invalidatetrainingCache();
      return response;
    } catch (e) {
      _log(' Error reserving university company job slot: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> assignUniversityStudentToCompanyJob({
    required String companyId,
    required String jobId,
    required String studentId,
    required String studentEmail,
    required String placementDepartment,
    required String placementLocation,
    required String companyPhone,
    required String startDate,
    required String endDate,
    String coordinatorNotes = '',
  }) async {
    try {
      final response = await _request(
        'POST',
        '/api/university/companies/$companyId/jobs/$jobId/assign-student',
        requiresAuth: true,
        data: {
          'student_id': studentId,
          'student_email': studentEmail,
          'placement_department': placementDepartment,
          'placement_location': placementLocation,
          'company_phone': companyPhone,
          'start_date': startDate,
          'end_date': endDate,
          'coordinator_notes': coordinatorNotes,
        },
      );
      _invalidatetrainingCache();
      return response;
    } catch (e) {
      _log(' Error assigning university student to company job: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getOrganizationUniversityChats() async {
    try {
      return await _request(
        'GET',
        '/api/company/university-chats',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting organization university chats: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getOrganizationUniversityChatMessages(
    String universityUserId,
  ) async {
    try {
      return await _request(
        'GET',
        '/api/company/university-chats/$universityUserId/messages',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting organization university chat messages: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> sendOrganizationUniversityChatMessage({
    required String universityUserId,
    required String message,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/company/university-chats/$universityUserId/messages',
        data: {'message': message},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error sending organization university chat message: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> deleteOrganizationUniversityChatMessage({
    required String universityUserId,
    required String messageId,
  }) async {
    try {
      return await delete(
        '/api/company/university-chats/$universityUserId/messages/$messageId',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error deleting organization university chat message: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateOrganizationUniversityChatMessage({
    required String universityUserId,
    required String messageId,
    required String message,
  }) async {
    try {
      return await put(
        '/api/company/university-chats/$universityUserId/messages/$messageId',
        {'message': message},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error updating organization university chat message: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> getUniversityOrganizationChats() async {
    try {
      return await _request(
        'GET',
        '/api/university/organization-chats',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting university organization chats: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> getUniversityOrganizationChatMessages(
    String companyUserId,
  ) async {
    try {
      return await _request(
        'GET',
        '/api/university/organization-chats/$companyUserId/messages',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error getting university organization chat messages: $e');
      return {
        'success': false,
        'message': normalizeErrorMessage(e),
        'data': [],
      };
    }
  }

  Future<Map<String, dynamic>> sendUniversityOrganizationChatMessage({
    required String companyUserId,
    required String message,
  }) async {
    try {
      return await _request(
        'POST',
        '/api/university/organization-chats/$companyUserId/messages',
        data: {'message': message},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error sending university organization chat message: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> deleteUniversityOrganizationChatMessage({
    required String companyUserId,
    required String messageId,
  }) async {
    try {
      return await delete(
        '/api/university/organization-chats/$companyUserId/messages/$messageId',
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error deleting university organization chat message: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
    }
  }

  Future<Map<String, dynamic>> updateUniversityOrganizationChatMessage({
    required String companyUserId,
    required String messageId,
    required String message,
  }) async {
    try {
      return await put(
        '/api/university/organization-chats/$companyUserId/messages/$messageId',
        {'message': message},
        requiresAuth: true,
      );
    } catch (e) {
      _log(' Error updating university organization chat message: $e');
      return {'success': false, 'message': normalizeErrorMessage(e)};
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
