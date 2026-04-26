import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';

import '../models/api_response.dart';
import '../services/url_services.dart';
import '../services/storage_service.dart';
import '../services/downloads_service.dart';
import '../utils/logger.dart';
import '../widgets/common_widgets.dart';

/// API Service for handling all HTTP requests
class ApiService {
  static final Dio _dio = Dio(
    BaseOptions(
      headers: {"Content-Type": "application/json"},
      validateStatus: (status) => status! < 600,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 30),
    ),
  );

  // CookieJar (to store cookies in memory) - only for non-web platforms
  static final CookieJar? _cookieJar = kIsWeb ? null : CookieJar();

  /// Initialize Dio with CookieManager (only on non-web platforms)
  static void init() {
    _dio.interceptors.clear();

    // Only add CookieManager on non-web platforms
    if (!kIsWeb && _cookieJar != null) {
      _dio.interceptors.add(CookieManager(_cookieJar!));
    }

    // Add debugging interceptor
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.i('🚀 API Request: ${options.method} ${options.uri}');
        if (options.data != null) {
          logger.d('📤 Request Data: ${options.data}');
        }
        if (options.queryParameters.isNotEmpty) {
          logger.d('🔍 Query Params: ${options.queryParameters}');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        logger.i(
            '✅ API Response: ${response.statusCode} ${response.requestOptions.uri}');
        logger.d('📥 Response Data: ${response.data}');
        handler.next(response);
      },
      onError: (error, handler) {
        logger.e(
            '❌ API Error: ${error.requestOptions.method} ${error.requestOptions.uri}');
        logger.e('💥 Error Message: ${error.message}');
        if (error.response != null) {
          logger.e(
              '📥 Error Response: ${error.response?.statusCode} - ${error.response?.data}');
        }
        handler.next(error);
      },
    ));
  }

  /// Test server connectivity and available endpoints
  static Future<void> testServerConnectivity() async {
    try {
      logger.i('Testing server connectivity...');

      if (kIsWeb) {
        logger.i('Running on web platform - testing CORS compatibility...');
      }

      // Test base URL
      final baseResponse = await _dio.get(UrlServices.BASE_URL);
      logger.i('Base URL response status: ${baseResponse.statusCode}');

      // Test if server is reachable by checking base URL
      if (baseResponse.statusCode == 200 || baseResponse.statusCode == 404) {
        logger.i('Server is reachable (status: ${baseResponse.statusCode})');
        return; // Server is reachable, no need to test other endpoints
      }

      // If base URL fails, try alternative endpoints
      final endpoints = [
        UrlServices.HEALTH_CHECK,
        'api/status',
        'health',
        'status',
        'ping'
      ];

      for (final endpoint in endpoints) {
        try {
          final response = await _dio.get('${UrlServices.BASE_URL}/$endpoint');
          logger.i('$endpoint response status: ${response.statusCode}');
          if (response.statusCode == 200) {
            logger.i('Server connectivity confirmed via $endpoint');
            return;
          }
        } catch (e) {
          logger.w('$endpoint not available: $e');
        }
      }

      logger.w(
          'No working health check endpoints found, but server base URL is reachable');
    } catch (e) {
      logger.e('Server connectivity test failed: $e');
      if (kIsWeb) {
        logger.e(
            'Web platform detected - this might be a CORS issue. The server needs to allow cross-origin requests.');
      }
    }
  }

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    // On web platforms, assume internet is available
    if (kIsWeb) {
      return true;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }

  /// Create a Dio instance with shorter timeouts for books API
  static Dio _createBooksDio() {
    return Dio(
      BaseOptions(
        validateStatus: (status) => status! < 600,
        connectTimeout: const Duration(seconds: 10), // Shorter connect timeout
        receiveTimeout: const Duration(seconds: 15), // Shorter receive timeout
        sendTimeout: const Duration(seconds: 10), // Shorter send timeout
      ),
    );
  }

  /// Get exams list
  static Future<ApiResponse> getExams() async {
    // Use the correct exams endpoint
    return await get(
      endpoint: UrlServices.EXAMS,
      params: {},
      useAuth: true,
    );
  }

  /// Save exam with questions
  static Future<ApiResponse> saveExamWithQuestions(
      Map<String, dynamic> payload) async {
    return await post(
      endpoint: UrlServices.EXAMS,
      json: payload,
      useAuth: true,
    );
  }

  /// Get specific exam by id
  static Future<ApiResponse> getExamById(String examId) async {
    return await get(
      endpoint: '${UrlServices.EXAMS}/$examId',
      params: {},
      useAuth: true,
    );
  }

  /// Generate questions
  static Future<ApiResponse> generateQuestions({
    required String examName,
    required String topicOrBookName,
    required String date,
    required String duration,
    required int totalQuestions,
    required num marksPerQuestion,
    required String aiOption,
    List<String>? chapterNames,
    String? bookName,
    String? startTime,
    String? endTime,
  }) async {
    final payload = {
      'exam_name': examName,
      'topic_or_book_name': topicOrBookName,
      'book_name': bookName ?? topicOrBookName,
      'date': date,
      'duration': duration,
      'total_questions': totalQuestions,
      'marks_per_question': marksPerQuestion,
      'ai_option': aiOption,
    };
    // API expects singular key 'chapter_name' with list value per sample payload
    if (chapterNames != null && chapterNames.isNotEmpty) {
      payload['chapter_name'] = chapterNames;
    }
    if (startTime != null) payload['start_time'] = startTime;
    if (endTime != null) payload['end_time'] = endTime;

    return await post(
      endpoint: UrlServices.GENERATE_QUESTIONS,
      json: payload,
      useAuth: true, // This endpoint requires authentication
    );
  }

  /// Search books with AI search API
  static Future<ApiResponse> searchBooks({
    required String query,
    int limit = 10,
    double threshold = 0.3,
    bool useAuth = false,
  }) async {
    final booksDio = _createBooksDio();
    final url = '${UrlServices.BASE_URL}/${UrlServices.SEARCH_BOOKS}';

    final payload = {
      'query': query,
      'limit': limit,
      'threshold': threshold,
    };

    logger.w('Making POST search on URL: $url with payload:');
    logger.f(payload);

    try {
      final response = await booksDio.post(
        url,
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
          },
        ),
      );

      logger.i('Search response received: ${response.data}');

      // Check for 404 responses first
      if (response.statusCode == 404) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 404,
          status: false,
          message:
              'The search endpoint was not found. Please check the server configuration.',
          data: null,
        );
      }

      // Check for other HTTP error status codes
      if (response.statusCode != null &&
          response.statusCode! >= 400 &&
          response.statusCode! < 500) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode!,
          status: false,
          message:
              'Search request failed with status ${response.statusCode}. Please check your request.',
          data: null,
        );
      }

      if (response.data != null) {
        dynamic responseData = response.data;

        // Check if response is HTML (like 404 pages)
        if (responseData is String &&
            responseData.contains('<!DOCTYPE html>')) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 404,
            status: false,
            message:
                'The search endpoint was not found. The server returned an HTML page instead of JSON.',
            data: null,
          );
        }

        // Check if response is a simple string (like redirects or simple responses)
        if (responseData is String &&
            responseData.length < 100 &&
            !responseData.startsWith('{')) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: response.statusCode ?? 400,
            status: false,
            message:
                'The server returned an unexpected response format: "$responseData". This might indicate a redirect or incorrect endpoint.',
            data: null,
          );
        }

        if (responseData is List && responseData.isNotEmpty) {
          responseData = responseData.first;
        }

        if (responseData is Map &&
            (responseData.containsKey('code') ||
                responseData.containsKey('statusCode'))) {
          final code = responseData['code'] ?? responseData['statusCode'];
          final status = responseData['status'] ?? (code == 200);
          final message = responseData['message'] ?? 'No message provided';
          final validationErrors = responseData['validationErrors'];

          return ApiResponse(
            version: responseData['version'] ?? '0',
            validationErrors: validationErrors,
            code: code,
            status: status,
            message: message,
            data: responseData['data'],
          );
        } else if (responseData is Map && responseData.containsKey('books')) {
          // Handle search API response format
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: 200,
            status: true,
            message: 'Search completed successfully',
            data: responseData,
          );
        } else {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: response.statusCode ?? 400,
            status: false,
            message:
                'Unexpected search response format from server. Please contact support.',
            data: null,
          );
        }
      }

      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: 404,
        status: false,
        message: 'Error while searching, please try again later',
        data: null,
      );
    } on DioException catch (dioErr) {
      logger.e('Dio error: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Unexpected exception: $e\n$st');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        data: null,
      );
    }
  }

  /// GET request for books with shorter timeout
  static Future<ApiResponse> getBooks({
    required String endpoint,
    required Map<String, dynamic> params,
    bool useAuth = false,
  }) async {
    if (endpoint.isEmpty) {
      return ApiResponse(
        version: null,
        validationErrors: null,
        code: 401,
        status: false,
        message: 'Unauthorized request.',
        data: null,
      );
    }

    final booksDio = _createBooksDio();
    final url = '${UrlServices.BASE_URL}/$endpoint';
    logger.w('Making GET on URL: $url with params:');
    logger.f(params);

    try {
      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };

      if (useAuth) {
        final storageService = await StorageService.getInstance();
        final token = storageService.getUserToken();
        logger.i(
            'Auth required (booksDio) - Full token from storage: ${token ?? 'null'}');
        if (token == null || token.isEmpty) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 401,
            status: false,
            message: 'User not authenticated. Please login again.',
            data: null,
          );
        }
        // Bearer token
        headers['Authorization'] = 'Bearer $token';
        // Accept JSON explicitly
        headers['Accept'] = 'application/json';
        // Also send auth cookie for backends that rely on cookies
        headers['Cookie'] = 'user_auth_token=$token';
        // Keep CookieJar in sync for non-web where applicable
        await setAuthCookie(token);
      }

      final response = await booksDio.get(
        url,
        queryParameters: params,
        options: Options(headers: headers),
      );

      logger.i('Response received: ${response.data}');

      // Check for 404 responses first
      if (response.statusCode == 404) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 404,
          status: false,
          message:
              'The requested endpoint was not found. Please check the server configuration.',
          data: null,
        );
      }

      // Check for other HTTP error status codes
      if (response.statusCode != null &&
          response.statusCode! >= 400 &&
          response.statusCode! < 500) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode!,
          status: false,
          message:
              'Request failed with status ${response.statusCode}. Please check your request.',
          data: null,
        );
      }

      if (response.data != null) {
        dynamic responseData = response.data;

        // Check if response is HTML (like 404 pages)
        if (responseData is String &&
            responseData.contains('<!DOCTYPE html>')) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 404,
            status: false,
            message:
                'The requested endpoint was not found. The server returned an HTML page instead of JSON.',
            data: null,
          );
        }

        // Check if response is a simple string (like redirects or simple responses)
        if (responseData is String &&
            responseData.length < 100 &&
            !responseData.startsWith('{')) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: response.statusCode ?? 400,
            status: false,
            message:
                'The server returned an unexpected response format: "$responseData". This might indicate a redirect or incorrect endpoint.',
            data: null,
          );
        }

        if (responseData is List) {
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: 200,
            status: true,
            message: 'Books loaded successfully',
            data: {'books': responseData},
          );
        }

        if (responseData is Map &&
            (responseData.containsKey('code') ||
                responseData.containsKey('statusCode'))) {
          final code = responseData['code'] ?? responseData['statusCode'];
          final status = responseData['status'] ?? (code == 200);
          final message = responseData['message'] ?? 'No message provided';
          final validationErrors = responseData['validationErrors'];

          if (code == 200) {
            return ApiResponse(
              version: responseData['version'] ?? '0',
              validationErrors: validationErrors,
              code: code,
              status: status,
              message: message,
              data: responseData['data'],
            );
          } else {
            return ApiResponse(
              version: responseData['version'] ?? '0',
              validationErrors: validationErrors,
              code: code,
              status: status,
              message: message,
              data: responseData['data'],
            );
          }
        } else if (responseData is Map && responseData.containsKey('books')) {
          // Handle books API response format even when status is not provided
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: 200,
            status: true,
            message: 'Books loaded successfully',
            data: responseData,
          );
        } else if (responseData is Map &&
            responseData.containsKey('status') &&
            responseData.containsKey('books')) {
          // Handle books API response format with explicit status field
          final status = responseData['status'] == 'success';
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: status ? 200 : 400,
            status: status,
            message:
                status ? 'Books loaded successfully' : 'Failed to load books',
            data: responseData,
          );
        } else if (responseData is Map && responseData.containsKey('answer')) {
          // Handle Medibook chat API response format
          // Response: {"answer": "...", "sources": [...], "found_relevant_content": true, "session_id": "...", "total_turns": 2}
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: 200,
            status: true,
            message: 'Chat response received successfully',
            data: responseData,
          );
        } else if (responseData is Map &&
            (responseData.containsKey('chapter_wise_books') ||
                responseData.containsKey('non_chapter_wise_books'))) {
          // Handle categorized books list (ai/books-list)
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: 200,
            status: true,
            message: 'Categorized books loaded successfully',
            data: responseData,
          );
        } else {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: response.statusCode ?? 400,
            status: false,
            message:
                'Unexpected response format from server. Please contact support.',
            data: null,
          );
        }
      }

      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: 404,
        status: false,
        message: 'Error while fetching data, please try again later',
        data: null,
      );
    } on DioException catch (dioErr) {
      logger.e('Dio error: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Unexpected exception: $e\n$st');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        data: null,
      );
    }
  }

  /// Get chapter-wise books list
  static Future<ApiResponse> getChapterWiseBooks({bool useAuth = false}) async {
    // Try multiple known endpoint variants
    final endpoints = [
      UrlServices.BOOKS_CHAPTER, // ai/books/chapter
      'api/books/chapter', // api/books/chapter
      'api/v1/books/chapter', // api/v1/books/chapter
      'books/chapter', // books/chapter
    ];

    for (final endpoint in endpoints) {
      final res = await getBooks(
          endpoint: endpoint, params: const {}, useAuth: useAuth);
      if (res.status && res.data != null) {
        return res;
      }
      if (res.code == 404 ||
          (res.message.toLowerCase().contains('not found'))) {
        continue; // try next
      } else if (res.code == -1 &&
          res.message.toLowerCase().contains('timeout')) {
        continue; // try next quickly
      } else {
        return res; // other error, return immediately
      }
    }

    return ApiResponse(
      version: '0',
      validationErrors: [],
      code: 404,
      status: false,
      message: 'Chapter-wise books endpoint not found on server.',
      data: null,
    );
  }

  /// Get non-chapter books list
  static Future<ApiResponse> getNonChapterBooks({bool useAuth = false}) async {
    // Try multiple known endpoint variants
    final endpoints = [
      UrlServices.BOOKS_NON_CHAPTER, // ai/books/non-chapter
      'api/books/non-chapter', // api/books/non-chapter
      'api/v1/books/non-chapter', // api/v1/books/non-chapter
      'books/non-chapter', // books/non-chapter
    ];

    for (final endpoint in endpoints) {
      final res = await getBooks(
          endpoint: endpoint, params: const {}, useAuth: useAuth);
      if (res.status && res.data != null) {
        return res;
      }
      if (res.code == 404 ||
          (res.message.toLowerCase().contains('not found'))) {
        continue;
      } else if (res.code == -1 &&
          res.message.toLowerCase().contains('timeout')) {
        continue;
      } else {
        return res;
      }
    }

    return ApiResponse(
      version: '0',
      validationErrors: [],
      code: 404,
      status: false,
      message: 'Non-chapter books endpoint not found on server.',
      data: null,
    );
  }

  /// Get chapters of a specific book
  static Future<ApiResponse> getChaptersOfBook({
    required String bookName,
    bool useAuth = false,
  }) async {
    // final encoded = Uri.encodeComponent(bookName);
    final endpoints = [
      UrlServices.BOOKS_LIST,
    ];

    final booksDio = _createBooksDio();

    // Prepare headers
    Map<String, String> headers = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
    };
    if (useAuth) {
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();
      if (token == null || token.isEmpty) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }
      headers['Authorization'] = 'Bearer $token';
      await setAuthCookie(token);
    }

    for (final endpoint in endpoints) {
      try {
        final url = '${UrlServices.BASE_URL}/$endpoint';
        final response =
            await booksDio.get(url, options: Options(headers: headers));
        if (response.statusCode == 200 && response.data != null) {
          // Accept raw chapters payload as-is
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 200,
            status: true,
            message: 'Chapters loaded',
            data: response.data,
          );
        }
        if (response.statusCode == 404) {
          continue; // try next
        }
      } on DioException catch (dioErr) {
        // Try next on 404/timeout, otherwise return error
        final code = dioErr.response?.statusCode ?? -1;
        final msg = dioErr.message?.toLowerCase() ?? '';
        if (code == 404 || msg.contains('timeout')) {
          continue;
        }
        return _handleDioError(dioErr);
      } catch (_) {
        // Try next
        continue;
      }
    }

    return ApiResponse(
      version: '0',
      validationErrors: [],
      code: 404,
      status: false,
      message: 'Chapters endpoint not found for book "$bookName".',
      data: null,
    );
  }

  /// Toggle books mode (chapter vs non-chapter)
  static Future<ApiResponse> toggleBooksMode(
      {required bool chapterMode}) async {
    try {
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();
      if (token == null || token.isEmpty) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      await setAuthCookie(token);

      final response = await _dio.post(
        '${UrlServices.BASE_URL}/${UrlServices.TOGGLE_BOOKS_MODE}',
        data: {
          'books_mode': chapterMode, // true => chapter, false => non-chapter
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      if (response.statusCode == 200) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'Books mode toggled successfully',
          data: response.data,
        );
      }

      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: response.statusCode ?? 400,
        status: false,
        message: 'Failed to toggle books mode',
        data: null,
      );
    } on DioException catch (dioErr) {
      return _handleDioError(dioErr);
    } catch (e) {
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to toggle books mode. Please try again.',
        data: null,
      );
    }
  }

  /// Set auth cookie manually (when login/signup gives token)
  static Future<void> setAuthCookie(String token) async {
    // Only set cookies on non-web platforms
    if (!kIsWeb && _cookieJar != null) {
      final uri = Uri.parse(UrlServices.BASE_URL);
      await _cookieJar!.saveFromResponse(uri, [
        Cookie("user_auth_token", token),
      ]);

      // Ensure Dio uses updated CookieJar
      init();
    }
    // On web platforms, cookies are handled by the browser automatically
  }

  /// POST request
  static Future<ApiResponse> post({
    required String endpoint,
    required Map<String, dynamic> json,
    bool useAuth = false,
  }) async {
    if (endpoint.isEmpty) {
      return ApiResponse(
        version: null,
        validationErrors: null,
        code: 401,
        status: false,
        message: 'Unauthorized request.',
        data: null,
      );
    }

    // Inject user ID to request body
    final storageService = await StorageService.getInstance();
    final userId = storageService.getUserId();
    if (userId != null) {
      final newJson = Map<String, dynamic>.from(json);
      newJson['id'] = userId;
      json = newJson;
    }

    // If auth required but no token
    String? token;
    if (useAuth) {
      final storageService = await StorageService.getInstance();
      token = storageService.getUserToken();
      logger.i(
          'Auth required - Token from storage: ${token != null ? '${token.substring(0, 10)}...' : 'null'}');

      if (token == null || token.isEmpty) {
        logger.e('No token found in storage for authenticated request');
        return ApiResponse(
          version: null,
          validationErrors: null,
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      } else {
        logger.i('Setting auth cookie with token');
        await setAuthCookie(token);
      }
    }

    final url = '${UrlServices.BASE_URL}/$endpoint';
    logger.w('Making POST on URL: $url with json:');
    logger.f(json);

    // Log headers for debugging
    if (useAuth) {
      logger.i('Using authentication: true');
      logger.i('Token length: ${token?.length ?? 0}');
    } else {
      logger.i('Using authentication: false');
    }

    try {
      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };

      // Add Authorization header if auth is required
      if (useAuth) {
        // Token was already retrieved and validated above
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
          logger.i('Added Authorization header with Bearer token');
        }
      }

      logger.i('Request headers: $headers');

      final response = await _dio.post(
        url,
        data: json,
        options: Options(
          headers: headers,
        ),
      );

      logger.i('Response received: ${response.data}');
      logger.i('Response status code: ${response.statusCode}');
      logger.i('Response headers: ${response.headers}');

      // Check for 404 responses first
      if (response.statusCode == 404) {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 404,
          status: false,
          message:
              'The requested endpoint was not found. Please check the server configuration.',
          data: null,
        );
      }

      // Check for other HTTP error status codes
      if (response.statusCode != null && response.statusCode! >= 400) {
        String errorMessage =
            'Request failed with status ${response.statusCode}';

        // Handle specific status codes
        if (response.statusCode! >= 500) {
          errorMessage =
              'Server error (${response.statusCode}). Please try again later.';
        } else if (response.statusCode! >= 400 && response.statusCode! < 500) {
          errorMessage =
              'Request failed with status ${response.statusCode}. Please check your request.';
        }

        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode!,
          status: false,
          message: errorMessage,
          data: null,
        );
      }

      if (response.data != null) {
        dynamic responseData = response.data;

        // Check if response is HTML (like 404 pages)
        if (responseData is String &&
            responseData.contains('<!DOCTYPE html>')) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 404,
            status: false,
            message:
                'The requested endpoint was not found. The server returned an HTML page instead of JSON.',
            data: null,
          );
        }

        // Check if response is a simple string (like redirects or simple responses)
        if (responseData is String &&
            responseData.length < 100 &&
            !responseData.startsWith('{')) {
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: response.statusCode ?? 400,
            status: false,
            message:
                'The server returned an unexpected response format: "$responseData". This might indicate a redirect or incorrect endpoint.',
            data: null,
          );
        }

        if (responseData is List && responseData.isNotEmpty) {
          responseData = responseData.first;
        }

        if (responseData is Map &&
            (responseData.containsKey('code') ||
                responseData.containsKey('statusCode'))) {
          final code = responseData['code'] ?? responseData['statusCode'];
          final status = responseData['status'] ?? (code == 200);
          final message = responseData['message'] ?? 'No message provided';
          final validationErrors = responseData['validationErrors'];

          if (code == 200) {
            return ApiResponse(
              version: responseData['version'] ?? '0',
              validationErrors: validationErrors,
              code: code,
              status: status,
              message: message,
              data: responseData['data'],
            );
          } else {
            if (validationErrors != null &&
                validationErrors is Map &&
                validationErrors.containsKey('password')) {
              final passwordErrors = validationErrors['password']['_errors'];
              if (passwordErrors is List && passwordErrors.isNotEmpty) {
                showError(text: passwordErrors.join('\n'));
              }
            }

            return ApiResponse(
              version: responseData['version'] ?? '0',
              validationErrors: validationErrors,
              code: code,
              status: status,
              message: message,
              data: responseData['data'],
            );
          }
        } else if (response.statusCode == 200 &&
            responseData is Map &&
            endpoint.contains('web-search')) {
          // Accept plain JSON payloads from web-search endpoint
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 200,
            status: true,
            message: 'Web search results received successfully',
            data: responseData,
          );
        } else if (response.statusCode == 200 &&
            responseData is Map &&
            (endpoint.contains('chat') || endpoint.contains('session'))) {
          // Accept plain JSON payloads from chat/session endpoints
          // This handles Medibook API format: {"answer": "...", "sources": [...], ...}
          return ApiResponse(
            version: '0',
            validationErrors: [],
            code: 200,
            status: true,
            message: 'Chat response received successfully',
            data: responseData,
          );
        } else {
          // Handle generate questions response format (exam_id, questions array)
          if (responseData is Map &&
              responseData.containsKey('exam_id') &&
              responseData.containsKey('questions')) {
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: response.statusCode ?? 200,
              status: true,
              message: 'Questions generated successfully',
              data: responseData,
            );
          }

          // Handle exam creation response format (message, exam object)
          if (responseData is Map &&
              responseData.containsKey('message') &&
              responseData.containsKey('exam')) {
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: response.statusCode ?? 200,
              status: true,
              message: responseData['message'] ?? 'Exam created successfully',
              data: responseData,
            );
          }

          // Handle chat response format (messages array)
          if (responseData is Map && responseData.containsKey('messages')) {
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: response.statusCode ?? 200,
              status: true,
              message: 'Chat response received successfully',
              data: responseData,
            );
          }

          // Handle server errors (502, 503, 504, etc.)
          final statusCode = response.statusCode;
          if (statusCode != null && statusCode >= 500) {
            String errorMessage =
                'Server is temporarily unavailable. Please try again later.';
            if (statusCode == 502) {
              errorMessage =
                  'Server is temporarily unavailable. Please try again later.';
            } else if (statusCode == 503) {
              errorMessage =
                  'Service is temporarily unavailable. Please try again later.';
            } else if (statusCode == 504) {
              errorMessage = 'Server timeout. Please try again later.';
            }

            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: statusCode,
              status: false,
              message: errorMessage,
              data: null,
            );
          } else {
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: statusCode ?? 400,
              status: false,
              message:
                  'Unexpected response format from server. Please contact support.',
              data: null,
            );
          }
        }
      }

      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: 404,
        status: false,
        message: 'Error while creating account, please try again later',
        data: null,
      );
    } on DioException catch (dioErr) {
      logger.e('Dio error: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Unexpected exception: $e\n$st');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        data: null,
      );
    }
  }

  /// GET request
  static Future<ApiResponse> get({
    required String endpoint,
    required Map<String, dynamic> params,
    bool useAuth = false,
  }) async {
    if (endpoint.isEmpty) {
      return ApiResponse(
        version: null,
        validationErrors: null,
        code: 401,
        status: false,
        message: 'Unauthorized request.',
        data: null,
      );
    }

    if (useAuth) {
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();
      logger.i(
          'Auth required - Token from storage: ${token != null ? '${token.substring(0, 10)}...' : 'null'}');

      if (token == null || token.isEmpty) {
        logger.e('No token found in storage for authenticated request');
        return ApiResponse(
          version: null,
          validationErrors: null,
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      } else {
        logger.i('Setting auth cookie with token');
        await setAuthCookie(token);
      }
    }

    final url = '${UrlServices.BASE_URL}/$endpoint';
    logger.w('Making GET on URL: $url with params:');
    logger.f(params);

    try {
      // Build headers (add Authorization when auth is required)
      final Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };
      if (useAuth) {
        final storageService = await StorageService.getInstance();
        final token = storageService.getUserToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
          headers['Accept'] = 'application/json';
        }
      }

      final response = await _dio.get(
        url,
        queryParameters: params,
        options: Options(headers: headers),
      );

      logger.i('Response received: ${response.data}');

      if (response.data != null) {
        // If API returns a raw list (e.g., exams summaries), pass through as success
        if (response.data is List) {
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: response.statusCode ?? 200,
            status: true,
            message: 'OK',
            data: response.data,
          );
        }

        dynamic responseData = response.data;

        if (responseData is Map &&
            (responseData.containsKey('code') ||
                responseData.containsKey('statusCode'))) {
          final code = responseData['code'] ?? responseData['statusCode'];
          final status = responseData['status'] ?? (code == 200);
          final message = responseData['message'] ?? 'No message provided';
          final validationErrors = responseData['validationErrors'];

          if (code == 200) {
            return ApiResponse(
              version: responseData['version'] ?? '0',
              validationErrors: validationErrors,
              code: code,
              status: status,
              message: message,
              data: responseData['data'],
            );
          } else {
            if (validationErrors != null &&
                validationErrors is Map &&
                validationErrors.containsKey('password')) {
              final passwordErrors = validationErrors['password']['_errors'];
              if (passwordErrors is List && passwordErrors.isNotEmpty) {
                showError(text: passwordErrors.join('\n'));
              }
            }

            return ApiResponse(
              version: responseData['version'] ?? '0',
              validationErrors: validationErrors,
              code: code,
              status: status,
              message: message,
              data: responseData['data'],
            );
          }
        } else if (responseData is Map &&
            responseData.containsKey('status') &&
            responseData.containsKey('books')) {
          // Handle books API response format
          final status = responseData['status'] == 'success';
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: status ? 200 : 400,
            status: status,
            message:
                status ? 'Books loaded successfully' : 'Failed to load books',
            data: responseData,
          );
        } else if (responseData is Map && responseData.containsKey('exams')) {
          // Handle exams API response format
          return ApiResponse(
            version: '0',
            validationErrors: null,
            code: 200,
            status: true,
            message: 'Exams loaded successfully',
            data: responseData,
          );
        } else {
          // Handle common error payloads
          if (responseData is Map && responseData.containsKey('detail')) {
            final detail = responseData['detail'];
            final message = detail is String ? detail : responseData.toString();
            final code = response.statusCode ?? 401;
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: code,
              status: false,
              message: message,
              data: null,
            );
          }

          // Handle exam data response format (status, message, data)
          if (responseData is Map &&
              responseData.containsKey('status') &&
              responseData.containsKey('message') &&
              responseData.containsKey('data')) {
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: response.statusCode ?? 200,
              status: responseData['status'] == 'success',
              message: responseData['message'] ?? 'Request completed',
              data: responseData['data'],
            );
          }

          // Handle HTML error responses (like 404 pages)
          if (responseData is String &&
              responseData.contains('<!DOCTYPE html>')) {
            return ApiResponse(
              version: '0',
              validationErrors: [],
              code: 404,
              status: false,
              message:
                  'The requested endpoint was not found. Please check the server configuration.',
              data: null,
            );
          }

          throw Exception("Unexpected API response structure: $responseData");
        }
      }

      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: 404,
        status: false,
        message: 'Error while fetching data, please try again later',
        data: null,
      );
    } on DioException catch (dioErr) {
      logger.e('Dio error: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Unexpected exception: $e\n$st');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        data: null,
      );
    }
  }

  /// PUT request
  static Future<ApiResponse> put({
    required String endpoint,
    required Map<String, dynamic> json,
    bool useAuth = true,
  }) async {
    if (endpoint.isEmpty) {
      return ApiResponse(
        version: null,
        validationErrors: null,
        code: 401,
        status: false,
        message: 'Unauthorized request.',
        data: null,
      );
    }

    // Inject user ID to request body
    final storageService = await StorageService.getInstance();
    final userId = storageService.getUserId();
    if (userId != null) {
      final newJson = Map<String, dynamic>.from(json);
      newJson['id'] = userId;
      json = newJson;
    }

    String? token;
    if (useAuth) {
      final storageService = await StorageService.getInstance();
      token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        return ApiResponse(
          version: null,
          validationErrors: null,
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      } else {
        await setAuthCookie(token);
      }
    }

    final url = '${UrlServices.BASE_URL}/$endpoint';
    logger.w('Making PUT on URL: $url with json:');
    logger.f(json);

    try {
      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };

      // Add Authorization header if auth is required
      if (useAuth && token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _dio.put(
        url,
        data: json,
        options: Options(
          headers: headers,
        ),
      );

      return _handleResponse(response);
    } on DioException catch (dioErr) {
      logger.e('Dio error: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Unexpected exception: $e\n$st');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        data: null,
      );
    }
  }

  /// DELETE request
  static Future<ApiResponse> delete({
    required String endpoint,
    required Map<String, dynamic> json,
    bool useAuth = true,
  }) async {
    if (endpoint.isEmpty) {
      return ApiResponse(
        version: null,
        validationErrors: null,
        code: 401,
        status: false,
        message: 'Unauthorized request.',
        data: null,
      );
    }

    // Inject user ID to request body
    final storageService = await StorageService.getInstance();
    final userId = storageService.getUserId();
    if (userId != null) {
      final newJson = Map<String, dynamic>.from(json);
      newJson['id'] = userId;
      json = newJson;
    }

    String? token;
    if (useAuth) {
      final storageService = await StorageService.getInstance();
      token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        return ApiResponse(
          version: null,
          validationErrors: null,
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      } else {
        await setAuthCookie(token);
      }
    }

    final url = '${UrlServices.BASE_URL}/$endpoint';
    logger.w('Making DELETE on URL: $url with json:');
    logger.f(json);

    try {
      Map<String, String> headers = {
        'Content-Type': 'application/json; charset=UTF-8',
      };

      // Add Authorization header if auth is required
      if (useAuth && token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await _dio.delete(
        url,
        data: json,
        options: Options(
          headers: headers,
        ),
      );

      return _handleResponse(response);
    } on DioException catch (dioErr) {
      logger.e('Dio error: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Unexpected exception: $e\n$st');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        data: null,
      );
    }
  }

  /// Upload file
  static Future<ApiResponse> uploadFile({
    required String filePath,
    bool useAuth = false,
  }) async {
    try {
      final file = File(filePath);
      logger.i('File: $filePath');

      if (!file.existsSync()) {
        return ApiResponse(
          version: '0',
          code: 400,
          status: false,
          message: 'File does not exist at path: $filePath',
          validationErrors: [],
          data: null,
        );
      }

      final fileName = file.path.split('/').last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      logger.i('Uploading file: $fileName');

      // Add auth cookie if required
      String? userToken;
      final storageService = await StorageService.getInstance();
      if (useAuth) {
        userToken = storageService.getUserToken();
        if (userToken == null || userToken.isEmpty) {
          return ApiResponse(
            version: '0',
            code: 401,
            status: false,
            message: 'User not authenticated. Please login again.',
            validationErrors: [],
            data: null,
          );
        }
      }

      final response = await _dio.post(
        '${UrlServices.BASE_URL}/${UrlServices.UPLOAD_SINGLE_FILE}',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            if (useAuth && userToken != null)
              'Cookie': 'user_auth_token=$userToken',
          },
        ),
      );

      logger.f('File upload response: ${response.data}');

      if (response.data != null && response.data is Map) {
        final responseData = response.data as Map<String, dynamic>;

        final code = responseData['code'] ?? response.statusCode ?? 500;
        final status = responseData['status'] ?? false;
        final message = responseData['message'] ?? 'Unknown response';
        final validationErrors = responseData['validationErrors'];

        return ApiResponse(
          version: responseData['version'] ?? '0',
          code: code,
          status: status,
          message: message,
          validationErrors: validationErrors,
          data: responseData['data'] ?? responseData['imageUrl'],
        );
      }

      return ApiResponse(
        version: '0',
        code: response.statusCode ?? 500,
        status: false,
        message: 'Unexpected server response.',
        validationErrors: [],
        data: null,
      );
    } on DioException catch (dioErr) {
      logger.e(
        'DioException: ${dioErr.message} | Response: ${dioErr.response?.data} | '
        'Status Code: ${dioErr.response?.statusCode} | Error: ${dioErr.error}',
      );

      return _handleDioError(dioErr);
    } on SocketException {
      logger.e('No Internet connection');
      return ApiResponse(
        version: '0',
        code: -1,
        status: false,
        message: 'No Internet connection.',
        validationErrors: [],
        data: null,
      );
    } catch (e, st) {
      logger.e('Unexpected error: $e\n$st');
      return ApiResponse(
        version: '0',
        code: -1,
        status: false,
        message: 'Something went wrong. Please try again later.',
        validationErrors: [],
        data: null,
      );
    }
  }

  /// Handle response data
  static ApiResponse _handleResponse(Response response) {
    if (response.data != null) {
      dynamic responseData = response.data;

      if (responseData is List && responseData.isNotEmpty) {
        responseData = responseData.first;
      }

      if (responseData is Map && responseData.containsKey('code')) {
        final code = responseData['code'];
        final status = responseData['status'] ?? false;
        final message = responseData['message'] ?? 'No message provided';
        final validationErrors = responseData['validationErrors'];

        return ApiResponse(
          version: responseData['version'] ?? '0',
          validationErrors: validationErrors,
          code: code,
          status: status,
          message: message,
          data: responseData['data'],
        );
      } else {
        throw Exception("Unexpected API response structure: $responseData");
      }
    }

    return ApiResponse(
      version: '0',
      validationErrors: [],
      code: 404,
      status: false,
      message: 'No data received from server',
      data: null,
    );
  }

  /// Handle Dio errors
  static ApiResponse _handleDioError(DioException dioErr) {
    String errorMessage = 'Unexpected error';
    int errorCode = dioErr.response?.statusCode ?? -1;
    List<dynamic>? validationErrors;

    if (dioErr.response?.data is Map<String, dynamic>) {
      final data = dioErr.response?.data;
      errorMessage = data?['message'] ?? dioErr.message ?? errorMessage;
      validationErrors = data?['validationErrors'];
    } else {
      switch (dioErr.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          errorMessage = 'Connection timeout';
          break;
        case DioExceptionType.badCertificate:
          errorMessage = 'Bad certificate';
          break;
        case DioExceptionType.badResponse:
          final statusCode = dioErr.response?.statusCode;
          if (statusCode == 502) {
            errorMessage =
                'Server is temporarily unavailable. Please try again later.';
          } else if (statusCode == 503) {
            errorMessage =
                'Service is temporarily unavailable. Please try again later.';
          } else if (statusCode == 504) {
            errorMessage = 'Server timeout. Please try again later.';
          } else if (statusCode != null && statusCode >= 500) {
            errorMessage = 'Server error. Please try again later.';
          } else if (statusCode != null && statusCode >= 400) {
            errorMessage = 'Request failed. Please check your credentials.';
          } else {
            errorMessage = 'Server responded with error';
          }
          break;
        case DioExceptionType.cancel:
          errorMessage = 'Request was cancelled';
          break;
        case DioExceptionType.connectionError:
          if (kIsWeb) {
            errorMessage =
                'Connection failed. This might be due to CORS policy restrictions. Please ensure the server allows cross-origin requests from this domain.';
          } else {
            errorMessage =
                'No internet connection. Please check your network settings and try again.';
          }
          break;
        case DioExceptionType.unknown:
          errorMessage = 'Unknown error occurred from server.';
          break;
      }
    }

    return ApiResponse(
      version: '0',
      validationErrors: validationErrors,
      code: errorCode,
      status: false,
      message: errorMessage,
      data: null,
    );
  }

  /// Toggle AI mode
  static Future<ApiResponse> toggleAiMode(bool mediAiMode) async {
    try {
      logger.i('Toggling AI mode: medi_ai_mode=$mediAiMode');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for toggle AI mode request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      final response = await _dio.post(
        '${UrlServices.BASE_URL}/ai/toggle_mode',
        data: {
          'medi_ai_mode': mediAiMode,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Toggle AI mode response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'AI mode toggled successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to toggle AI mode: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('Toggle AI mode error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('Toggle AI mode error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to toggle AI mode. Please try again.',
        data: null,
      );
    }
  }

  /// Start a new chat session
  static Future<ApiResponse> startNewSession() async {
    try {
      logger.i('Starting new chat session');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for new session request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      final response = await _dio.post(
        '${UrlServices.BASE_URL}/${UrlServices.NEW_SESSION}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('New session response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'New session started successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to start new session: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('New session error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('New session error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to start new session. Please try again.',
        data: null,
      );
    }
  }

  /// Get session history
  /// GET https://drjebasingh.in/ai/api/session/{session_id}/history
  static Future<ApiResponse> getSessionHistory(String sessionId) async {
    try {
      logger.i('Getting session history for: $sessionId');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for session history request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      final response = await _dio.get(
        '${UrlServices.BASE_URL}/ai/api/session/$sessionId/history',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Session history response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'Session history retrieved successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to get session history: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('Session history error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('Session history error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to get session history. Please try again.',
        data: null,
      );
    }
  }

  /// Delete session
  /// DELETE https://drjebasingh.in/ai/api/session/{session_id}
  static Future<ApiResponse> deleteSession(String sessionId) async {
    try {
      logger.i('Deleting session: $sessionId');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for delete session request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      final response = await _dio.delete(
        '${UrlServices.BASE_URL}/ai/api/session/$sessionId',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Delete session response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'Session deleted successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to delete session: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('Delete session error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('Delete session error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to delete session. Please try again.',
        data: null,
      );
    }
  }

  /// Get chat sessions history
  static Future<ApiResponse> getChatSessions() async {
    try {
      logger.i('Getting chat sessions history');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for get sessions request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      final response = await _dio.get(
        '${UrlServices.BASE_URL}/${UrlServices.SESSIONS}',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Get sessions response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'Sessions retrieved successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to get sessions: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('Get sessions error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('Get sessions error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to get sessions. Please try again.',
        data: null,
      );
    }
  }

  /// Get messages for a specific session
  /// GET https://drjebasingh.in/ai/api/session/{session_id}/history
  /// Response: {"session_id": "...", "history": [{"role": "user", "content": "..."}], "total_messages": 4}
  static Future<ApiResponse> getSessionMessages(String sessionId) async {
    try {
      logger.i('Getting messages for session: $sessionId');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for get session messages request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      // Use the new session history endpoint
      final response = await _dio.get(
        '${UrlServices.BASE_URL}/ai/api/session/$sessionId/history',
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Get session messages response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'Session messages retrieved successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to get session messages: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('Get session messages error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('Get session messages error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to get session messages. Please try again.',
        data: null,
      );
    }
  }

  /// Select books for chat session
  static Future<ApiResponse> selectBooks({
    required List<String> selectedBooks,
  }) async {
    try {
      logger.i('Selecting books: $selectedBooks');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for select books request');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 401,
          status: false,
          message: 'User not authenticated. Please login again.',
          data: null,
        );
      }

      // Set auth cookie
      await setAuthCookie(token);

      final payload = {
        'selected_books': selectedBooks,
      };

      final response = await _dio.post(
        '${UrlServices.BASE_URL}/${UrlServices.SELECT_BOOKS}',
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Select books response: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = response.data;
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 200,
          status: true,
          message: 'Books selected successfully',
          data: data,
        );
      } else {
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: response.statusCode ?? 400,
          status: false,
          message: 'Failed to select books: ${response.statusCode}',
          data: null,
        );
      }
    } on DioException catch (dioErr) {
      logger.e('Select books error: $dioErr');
      return _handleDioError(dioErr);
    } catch (e) {
      logger.e('Select books error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to select books. Please try again.',
        data: null,
      );
    }
  }

  /// Debug all endpoints - comprehensive testing
  static Future<void> debugAllEndpoints() async {
    logger.i('🔧 Starting comprehensive endpoint debugging...');

    final endpoints = [
      {
        'name': 'Health Check',
        'url': UrlServices.HEALTH_CHECK,
        'method': 'GET',
        'auth': false
      },
      {
        'name': 'Books (no auth)',
        'url': UrlServices.BOOKS,
        'method': 'GET',
        'auth': false
      },
      {
        'name': 'Books (with auth)',
        'url': UrlServices.BOOKS,
        'method': 'GET',
        'auth': true
      },
      {
        'name': 'Exams (no auth)',
        'url': UrlServices.EXAMS,
        'method': 'GET',
        'auth': false
      },
      {
        'name': 'Exams (with auth)',
        'url': UrlServices.EXAMS,
        'method': 'GET',
        'auth': true
      },
      {
        'name': 'Login',
        'url': UrlServices.LOGIN,
        'method': 'POST',
        'auth': false
      },
      {'name': 'Chat', 'url': UrlServices.CHAT, 'method': 'POST', 'auth': true},
      {
        'name': 'Generate Questions',
        'url': UrlServices.GENERATE_QUESTIONS,
        'method': 'POST',
        'auth': true
      },
    ];

    for (final endpoint in endpoints) {
      await _testEndpoint(
        endpoint['name'] as String,
        endpoint['url'] as String,
        endpoint['method'] as String,
        endpoint['auth'] as bool,
      );
      await Future.delayed(
          const Duration(milliseconds: 500)); // Small delay between tests
    }

    logger.i('🏁 Endpoint debugging completed');
  }

  /// Test individual endpoint
  static Future<void> _testEndpoint(
      String name, String url, String method, bool useAuth) async {
    try {
      logger.i('🧪 Testing $name: $method $url (auth: $useAuth)');

      Response response;
      switch (method.toUpperCase()) {
        case 'GET':
          response = await get(
            endpoint: url,
            params: {},
            useAuth: useAuth,
          ).then((apiResponse) {
            // Convert ApiResponse to Dio Response for consistency
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: apiResponse.code,
              data: apiResponse.data,
              statusMessage: apiResponse.message,
            );
          });
          break;
        case 'POST':
          // Send minimal test data for POST requests
          final testData = _getTestDataForEndpoint(url);
          response = await post(
            endpoint: url,
            json: testData,
            useAuth: useAuth,
          ).then((apiResponse) {
            // Convert ApiResponse to Dio Response for consistency
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: apiResponse.code,
              data: apiResponse.data,
              statusMessage: apiResponse.message,
            );
          });
          break;
        default:
          logger.w('⚠️ Unsupported method: $method');
          return;
      }

      logger.i('✅ $name: ${response.statusCode} - ${response.statusMessage}');
      if (response.data != null) {
        logger.d('📥 Response: ${response.data}');
      }
    } catch (e) {
      if (e is DioException) {
        final statusCode = e.response?.statusCode ?? 'No response';
        final message = e.message ?? 'Unknown error';
        logger.w('⚠️ $name: $statusCode - $message');

        if (e.response?.data != null) {
          logger.d('📥 Error Response: ${e.response?.data}');
        }
      } else {
        logger.e('❌ $name: $e');
      }
    }
  }

  /// Generate lesson plan using AI
  static Future<Map<String, dynamic>?> generateLessonPlan({
    required String bookName,
    required List<String> chapterNames,
  }) async {
    try {
      logger.i(
          'Generating lesson plan for book: $bookName with chapters: $chapterNames');

      // Get authentication token
      final storageService = await StorageService.getInstance();
      final token = storageService.getUserToken();

      if (token == null || token.isEmpty) {
        logger.e('No token found for lesson plan generation request');
        return null;
      }

      // Set auth cookie
      await setAuthCookie(token);

      // Create a Dio instance with longer timeout for lesson plan generation
      final lessonPlanDio = Dio(
        BaseOptions(
          validateStatus: (status) => status! < 600,
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout:
              const Duration(seconds: 120), // 2 minutes for AI generation
          sendTimeout: const Duration(seconds: 60),
        ),
      );

      // Build the payload with actual book and chapter data
      final payload = {
        "book_id": bookName,
        "chapter_ids": chapterNames,
        "chapter_name": chapterNames.isNotEmpty ? chapterNames.first : "",
        "limit": 8
      };

      logger.w('Lesson plan payload: $payload');

      final response = await lessonPlanDio.post(
        '${UrlServices.BASE_URL}/${UrlServices.LESSON_PLAN_GENERATE}',
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            // 'Authorization': 'Bearer $token',
          },
        ),
      );

      logger.i('Lesson plan generation response: ${response.statusCode}');
      logger.d('Lesson plan response data: ${response.data}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data;

        // Handle the structured lesson plan response
        if (data is Map && data.containsKey('lesson_plan')) {
          return data as Map<String, dynamic>;
        } else if (data is Map) {
          return data as Map<String, dynamic>;
        }
      }

      return null;
    } on DioException catch (dioErr) {
      logger.e('Lesson plan generation error: $dioErr');
      return null;
    } catch (e) {
      logger.e('Lesson plan generation error: $e');
      return null;
    }
  }

  /// Generate and download lesson plan PDF
  /// First gets lesson plan data with pdf_url, then downloads from that URL
  /// Saves to persistent local storage and maintains downloads list
  static Future<ApiResponse> generateLessonPlanPdf({
    required String bookId,
    required String chapterId,
    required List<String> headingIds,
    required String chapterName,
    required String headingName,
    required String lessonTitle,
    int limit = 10,
    Function(int, int)? onProgress,
    Function(String)? onStatusChange,
  }) async {
    try {
      final payload = {
        "book_id": bookId,
        "chapter_ids": chapterId,
        "heading_ids": headingIds,
        "chapter_name": chapterName,
        "heading_name": headingName,
        "limit": limit,
      };

      logger.w('Lesson plan PDF payload: $payload');
      onStatusChange?.call('Generating lesson plan...');

      // Step 1: Call lesson plan endpoint to get response with pdf_url
      final lessonPlanResponse = await _dio.post(
        '${UrlServices.BASE_URL}/${UrlServices.LESSON_PLAN_GENERATE}',
        data: payload,
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status != null && status < 600,
        ),
      );

      if (lessonPlanResponse.statusCode != 200 ||
          lessonPlanResponse.data == null) {
        onStatusChange?.call('Failed to generate lesson plan');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: lessonPlanResponse.statusCode ?? 500,
          status: false,
          message: 'Failed to generate lesson plan.',
          data: null,
        );
      }

      // Step 2: Extract pdf_url from response
      final responseData = lessonPlanResponse.data;
      String? pdfUrl;

      if (responseData is Map && responseData.containsKey('pdf_url')) {
        pdfUrl = responseData['pdf_url'] as String?;
      }

      if (pdfUrl == null || pdfUrl.isEmpty) {
        logger.e(
            'No pdf_url found in lesson plan response: $responseData');
        onStatusChange?.call('PDF URL not found');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 400,
          status: false,
          message: 'PDF URL not found in server response.',
          data: null,
        );
      }

      logger.i('PDF URL from response: $pdfUrl');
      onStatusChange?.call('Downloading PDF...');

      // Step 3: Download PDF from the provided URL with progress tracking
      final downloadUrl =
          '${UrlServices.BASE_URL}$pdfUrl'; // Construct full URL if relative
      logger.i('Downloading PDF from: $downloadUrl');

      final pdfResponse = await _dio.get(
        downloadUrl,
        options: Options(
          responseType: ResponseType.bytes,
          validateStatus: (status) => status != null && status < 600,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progressPercent = ((received / total) * 100).toInt();
            logger.d('Download progress: $progressPercent%');
            onProgress?.call(received, total);
          }
        },
      );

      if (pdfResponse.statusCode != 200 || pdfResponse.data == null) {
        onStatusChange?.call('Failed to download PDF');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: pdfResponse.statusCode ?? 500,
          status: false,
          message: 'Failed to download PDF from URL.',
          data: null,
        );
      }

      if (pdfResponse.data is! List<int>) {
        onStatusChange?.call('Invalid PDF format');
        return ApiResponse(
          version: '0',
          validationErrors: [],
          code: 400,
          status: false,
          message: 'Server did not return a valid PDF file.',
          data: null,
        );
      }

      // Step 4: Save PDF to persistent local storage
      onStatusChange?.call('Saving to device...');
      final bytes = pdfResponse.data as List<int>;
      
      // Initialize downloads service
      final downloadsService = DownloadsService.getInstance();
      await downloadsService.init();
      
      // Extract filename from pdf_url or generate one
      final fileName = pdfUrl.split('/').last.isNotEmpty
          ? pdfUrl.split('/').last
          : 'lesson_plan_${DateTime.now().millisecondsSinceEpoch}.pdf';
      
      final downloadsPath = downloadsService.downloadsDirPath;
      final filePath = '$downloadsPath/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes, flush: true);

      logger.i(
          'PDF saved successfully to: $filePath (${bytes.length} bytes)');

      // Step 5: Track download in downloads list
      await downloadsService.addDownload(
        fileName: fileName,
        filePath: filePath,
        originalUrl: downloadUrl,
        fileSize: bytes.length,
        title: lessonTitle,
        bookName: bookId,
        chapterName: chapterName,
      );

      onStatusChange?.call('Download completed');

      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: 200,
        status: true,
        message: 'Lesson plan PDF downloaded successfully.',
        data: {
          'file_path': filePath,
          'file_name': fileName,
          'size': bytes.length,
          'pdf_url': pdfUrl,
          'download_id': DateTime.now().millisecondsSinceEpoch.toString(),
          'downloaded_at': DateTime.now().toIso8601String(),
        },
      );
    } on DioException catch (dioErr) {
      logger.e('Lesson plan PDF download error: $dioErr');
      onStatusChange?.call('Download failed: ${dioErr.message}');
      return _handleDioError(dioErr);
    } catch (e, st) {
      logger.e('Lesson plan PDF generation error: $e\n$st');
      onStatusChange?.call('Error: $e');
      return ApiResponse(
        version: '0',
        validationErrors: [],
        code: -1,
        status: false,
        message: 'Failed to download lesson plan PDF.',
        data: null,
      );
    }
  }

  /// Get all lesson plans
  static Future<ApiResponse> getLessonPlans() async {
    return await get(
      endpoint: UrlServices.LESSON_PLANS,
      params: {},
      useAuth: true,
    );
  }

  /// Get lesson plans by date range
  static Future<ApiResponse> getLessonPlansInRange(String from, String to) async {
    return await get(
      endpoint: UrlServices.LESSON_PLANS_RANGE,
      params: {'from': from, 'to': to},
      useAuth: true,
    );
  }

  /// Create lesson plan
  static Future<ApiResponse> createLessonPlan(Map<String, dynamic> payload) async {
    return await post(
      endpoint: UrlServices.LESSON_PLANS,
      json: payload,
      useAuth: true,
    );
  }

  /// Update lesson plan
  static Future<ApiResponse> updateLessonPlan(int id, Map<String, dynamic> payload) async {
    return await put(
      endpoint: '${UrlServices.LESSON_PLANS}/$id',
      json: payload,
      useAuth: true,
    );
  }

  /// Delete lesson plan
  static Future<ApiResponse> deleteLessonPlan(int id) async {
    return await delete(
      endpoint: '${UrlServices.LESSON_PLANS}/$id',
      json: {},
      useAuth: true,
    );
  }

  /// Get appropriate test data for different endpoints
  static Map<String, dynamic> _getTestDataForEndpoint(String url) {
    if (url.contains('login')) {
      return {
        'username': 'test@example.com',
        'password': 'testpassword',
      };
    } else if (url.contains('chat')) {
      return {
        'message': 'Hello, this is a test message',
        'session_id': 'test_session',
      };
    } else if (url.contains('generate-questions')) {
      return {
        'exam_name': 'Test Exam',
        'book_name': 'Test Book',
        'date': '2025-01-01',
        'duration': '1 hour',
        'total_questions': 5,
        'marks_per_question': 1,
        'ai_option': 'Common ai',
      };
    }
    return {};
  }

  /// ==================== Downloads Management ====================

  /// Initialize downloads service
  static Future<void> initDownloadsService() async {
    final downloadsService = DownloadsService.getInstance();
    await downloadsService.init();
  }

  /// Get all downloaded PDFs
  static List<dynamic> getAllDownloads() {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.getAllDownloads();
  }

  /// Get downloads for a specific book
  static List<dynamic> getDownloadsByBook(String bookName) {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.getDownloadsByBook(bookName);
  }

  /// Get download by ID
  static dynamic? getDownloadById(String id) {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.getDownloadById(id);
  }

  /// Delete a download
  static Future<bool> deleteDownload(String id) async {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.deleteDownload(id);
  }

  /// Get total downloads count
  static int getDownloadsCount() {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.downloadsCount;
  }

  /// Get total downloads size in MB
  static double getTotalDownloadsSizeInMB() {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.totalSizeInMB;
  }

  /// Get storage information
  static Future<Map<String, dynamic>> getDownloadsStorageInfo() async {
    final downloadsService = DownloadsService.getInstance();
    return downloadsService.getStorageInfo();
  }

  /// Clear all downloads
  static Future<void> clearAllDownloads() async {
    final downloadsService = DownloadsService.getInstance();
    await downloadsService.clearAllDownloads();
  }
}
