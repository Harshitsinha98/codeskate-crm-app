import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../constants/app_constants.dart';

/// Error thrown by [ApiClient] — carries the backend's `{error, code}` shape.
class ApiException implements Exception {
  final String message;
  final int status;
  final String? code;
  final Map<String, dynamic> data;

  ApiException(this.message, {this.status = 0, this.code, this.data = const {}});

  @override
  String toString() => message;
}

/// Authenticated JSON client for the Codeskate backend (same API the web CRM
/// uses). Every call carries `Authorization: Bearer <Firebase ID token>`.
class ApiClient {
  ApiClient._();

  static String get _base => AppConstants.backendBaseUrl.replaceAll(RegExp(r'/+$'), '');
  static const _timeout = Duration(seconds: 35);

  static Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json', 'Accept': 'application/json'};
    if (auth) {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Uri _uri(String path, [Map<String, dynamic>? query]) {
    final q = <String, String>{};
    query?.forEach((k, v) {
      if (v != null && '$v'.isNotEmpty) q[k] = '$v';
    });
    return Uri.parse('$_base$path').replace(queryParameters: q.isEmpty ? null : q);
  }

  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> data = {};
    try {
      if (res.body.isNotEmpty) {
        final d = jsonDecode(res.body);
        if (d is Map<String, dynamic>) {
          data = d;
        } else if (d is List) {
          data = {'items': d};
        }
      }
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return data;
    throw ApiException(
      data['error']?.toString() ?? _friendly(res.statusCode),
      status: res.statusCode,
      code: data['code']?.toString(),
      data: data,
    );
  }

  static String _friendly(int status) {
    if (status == 401) return 'Session expired — please sign in again.';
    if (status == 403) return 'You don\'t have permission for this action.';
    if (status == 404) return 'Not found.';
    if (status == 429) return 'Too many requests — try again in a moment.';
    if (status >= 500) return 'Server is busy — please retry.';
    return 'Request failed ($status)';
  }

  static Future<Map<String, dynamic>> _run(Future<http.Response> Function() fn) async {
    try {
      final res = await fn().timeout(_timeout);
      return _decode(res);
    } on ApiException {
      rethrow;
    } catch (_) {
      throw ApiException('Network error — check your internet connection.');
    }
  }

  static Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? query, bool auth = true}) async {
    final h = await _headers(auth: auth);
    return _run(() => http.get(_uri(path, query), headers: h));
  }

  static Future<Map<String, dynamic>> post(String path, {Map<String, dynamic>? body, bool auth = true}) async {
    final h = await _headers(auth: auth);
    return _run(() => http.post(_uri(path), headers: h, body: jsonEncode(body ?? {})));
  }

  static Future<Map<String, dynamic>> patch(String path, {Map<String, dynamic>? body}) async {
    final h = await _headers();
    return _run(() => http.patch(_uri(path), headers: h, body: jsonEncode(body ?? {})));
  }

  static Future<Map<String, dynamic>> delete(String path, {Map<String, dynamic>? query}) async {
    final h = await _headers();
    return _run(() => http.delete(_uri(path, query), headers: h));
  }
}
