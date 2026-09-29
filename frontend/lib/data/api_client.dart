import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Structured exceptions to replace generic string errors.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class UnauthorizedException extends ApiException {
  UnauthorizedException([String message = 'Session expired. Please log in again.']) : super(message, 401);
}

class NetworkException extends ApiException {
  NetworkException([super.message = 'No internet connection. Check your network.']);
}

class TimeoutException extends ApiException {
  TimeoutException([super.message = 'Request timed out. Please try again.']);
}

/// A centralized HTTP client that manages tokens, timeouts, parsing, and global error handling.
class ApiClient {
  static const String baseUrl = 'https://coachsaab-api.onrender.com/api/v1';
  static const Duration timeoutDuration = Duration(seconds: 10);
  final _storage = const FlutterSecureStorage();
  
  /// Optional callback to trigger global logout logic (e.g., routing to AuthScreen).
  final Function()? onUnauthorized;

  ApiClient({this.onUnauthorized});

  /// Attaches the JWT to the request headers securely.
  Future<Map<String, String>> _getHeaders({bool requireAuth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (requireAuth) {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// Centralized request dispatcher that handles timeouts, parsing, and structured error throwing.
  Future<dynamic> _request(
    Future<http.Response> Function(Map<String, String> headers) requestCall, 
    {bool requireAuth = true}
  ) async {
    try {
      final headers = await _getHeaders(requireAuth: requireAuth);
      
      // 1. Enforce strict timeout
      final response = await requestCall(headers).timeout(timeoutDuration);

      // 2. Handle Success
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.body.isNotEmpty ? jsonDecode(response.body) : null;
      } 
      // 3. Handle Auth Expiration Globally
      else if (response.statusCode == 401 || response.statusCode == 403) {
        if (onUnauthorized != null) {
          onUnauthorized!();
        }
        throw UnauthorizedException();
      } 
      // 4. Handle Server/Validation Errors
      else {
        String errorMsg = 'Server error occurred.';
        try {
          final errorBody = jsonDecode(response.body);
          if (errorBody['detail'] != null) {
            errorMsg = errorBody['detail'].toString();
          }
        } catch (_) {} 
        throw ApiException(errorMsg, response.statusCode);
      }
    } on SocketException {
      throw NetworkException();
    } on TimeoutException {
      throw TimeoutException();
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('An unexpected error occurred: $e');
    }
  }

  Future<dynamic> get(String endpoint, {bool requireAuth = true}) async {
    return _request(
      (headers) => http.get(Uri.parse('$baseUrl$endpoint'), headers: headers),
      requireAuth: requireAuth,
    );
  }

  Future<dynamic> post(String endpoint, {dynamic body, bool requireAuth = true}) async {
    return _request(
      (headers) => http.post(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body != null ? jsonEncode(body) : null),
      requireAuth: requireAuth,
    );
  }

  Future<dynamic> put(String endpoint, {dynamic body, bool requireAuth = true}) async {
    return _request(
      (headers) => http.put(Uri.parse('$baseUrl$endpoint'), headers: headers, body: body != null ? jsonEncode(body) : null),
      requireAuth: requireAuth,
    );
  }
}