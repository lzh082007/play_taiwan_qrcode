import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../config/auth_session.dart';

/// 後端 API 例外的共同基底，UI 層可以用 `is` / `switch` 分辨原因。
sealed class ApiException implements Exception {
  const ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 連不到主機：DNS 失敗、connection refused、逾時...等。
/// 通常代表 Base URL 設錯、網路不通、或防火牆擋住 port。
class ApiConnectionException extends ApiException {
  const ApiConnectionException(super.message);
}

/// 主機有回應，但回應內容不是預期的格式（不是合法 JSON、缺少欄位...等）。
class ApiResponseFormatException extends ApiException {
  const ApiResponseFormatException(super.message);
}

/// 後端回應失敗時的錯誤，[statusCode] 是 HTTP 狀態碼（400/401/403/404/409/500...）。
/// [message] 是可以直接顯示給使用者看的錯誤說明。
class ApiFailure extends ApiException {
  const ApiFailure(this.statusCode, super.message);

  final int statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;
  bool get isNotFound => statusCode == 404;
  bool get isConflict => statusCode == 409;
}

/// 呼叫後端 API 的共用邏輯：送出 request、帶上登入 Token、解開統一回應格式
/// `{ isSuccess, message, Result }`、把錯誤狀態碼轉成對應的例外。
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _client;
  final String _baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  /// [withAuth] 為 true 且目前有登入時，會帶上 `Authorization: Bearer {token}`。
  Future<Map<String, dynamic>?> get(String path, {bool withAuth = true}) => _send('GET', path, withAuth: withAuth);

  /// [withAuth] 為 true 且目前有登入時，會帶上 `Authorization: Bearer {token}`。
  Future<Map<String, dynamic>?> post(String path, {Object? body, bool withAuth = true}) =>
      _send('POST', path, body: body, withAuth: withAuth);

  Future<Map<String, dynamic>?> _send(String method, String path, {Object? body, required bool withAuth}) async {
    final uri = Uri.parse('$_baseUrl$path');
    final token = withAuth ? AuthSession.token : null;

    final http.Response response;
    try {
      final request = http.Request(method, uri)..headers['Content-Type'] = 'application/json; charset=utf-8';
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      if (body != null) {
        request.body = jsonEncode(body);
      }
      final streamed = await _client.send(request).timeout(_timeout);
      response = await http.Response.fromStream(streamed);
    } on TimeoutException {
      throw ApiConnectionException('連線逾時，無法連到伺服器（$_baseUrl）。\n請確認手機網路是否正常，或稍後再試一次。');
    } on SocketException catch (e) {
      throw ApiConnectionException('無法連線到伺服器（$_baseUrl）：${e.message}\n請確認手機網路是否正常、Base URL 是否正確。');
    } on http.ClientException catch (e) {
      throw ApiConnectionException('連線發生錯誤：${e.message}');
    }

    // JWT 驗證沒過（沒登入、Token 過期）或帳號身分不符時，後端直接回 401/403，沒有 body。
    if (response.bodyBytes.isEmpty) {
      if (response.statusCode == 401) {
        if (token != null) AuthSession.signOut();
        throw const ApiFailure(401, '尚未登入或登入已過期，請回首頁重新登入。');
      }
      if (response.statusCode == 403) {
        throw const ApiFailure(403, '目前登入的帳號沒有權限使用這個功能，請改用正確身分的帳號登入。');
      }
    }

    final Object? decoded;
    try {
      decoded = response.bodyBytes.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    } on FormatException catch (e) {
      throw ApiResponseFormatException('伺服器有回應（HTTP ${response.statusCode}），但內容不是合法的 JSON：${e.message}');
    }

    if (decoded is! Map<String, dynamic>) {
      throw ApiResponseFormatException('伺服器有回應（HTTP ${response.statusCode}），但格式不是預期的物件（JSON object）。');
    }

    final isSuccess = decoded['isSuccess'] as bool?;
    final message = decoded['message'] as String? ?? '';

    if (isSuccess == null) {
      throw const ApiResponseFormatException('伺服器有回應，但缺少 isSuccess 欄位。');
    }

    if (!isSuccess) {
      throw ApiFailure(response.statusCode, message);
    }

    return decoded['Result'] as Map<String, dynamic>?;
  }
}
