import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

/// Erro devolvido pela API (ou falha de ligação). O [code] é estável e vem do servidor.
class ApiException implements Exception {
  ApiException({
    required this.status,
    required this.code,
    required this.message,
    this.fieldErrors = const <String, List<String>>{},
  });

  final int status;
  final String code;
  final String message;
  final Map<String, List<String>> fieldErrors;

  bool get isNetwork => code == 'network_error';

  /// Mensagem para mostrar ao utilizador: se houver erros por campo, junta-os.
  String get fullMessage {
    if (fieldErrors.isEmpty) {
      return message;
    }
    return fieldErrors.values.expand((list) => list).join('\n');
  }

  factory ApiException.network() => ApiException(
        status: 0,
        code: 'network_error',
        message:
            'Não foi possível ligar ao servidor. Verifica a tua ligação e tenta novamente.',
      );

  factory ApiException.fromResponse(int status, dynamic body) {
    var code = 'unknown_error';
    var message = 'Ocorreu um erro inesperado. Tenta novamente.';
    final fields = <String, List<String>>{};

    if (body is Map) {
      final bodyCode = body['code'];
      if (bodyCode is String && bodyCode.isNotEmpty) {
        code = bodyCode;
      }
      final title = body['title'];
      // Erros do servidor (5xx) trazem mensagens técnicas em inglês: não as mostramos.
      if (title is String && title.isNotEmpty && status < 500) {
        message = title;
      }
      final errors = body['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is List) {
            fields[key.toString()] = value.map((e) => e.toString()).toList();
          }
        });
      }
    }

    if (status == 429 && code == 'unknown_error') {
      code = 'rate_limited';
      message = 'Demasiados pedidos. Tenta novamente daqui a pouco.';
    }

    return ApiException(
      status: status,
      code: code,
      message: message,
      fieldErrors: fields,
    );
  }

  @override
  String toString() => 'ApiException($status, $code): $message';
}

class ApiResponse {
  ApiResponse(this.status, this.data);

  final int status;
  final dynamic data;

  bool get ok => status >= 200 && status < 300;

  Map<String, dynamic> get json {
    final value = data;
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return <String, dynamic>{};
  }

  /// Devolve esta resposta se for de sucesso; caso contrário lança [ApiException].
  ApiResponse ensureOk() {
    if (!ok) {
      throw ApiException.fromResponse(status, data);
    }
    return this;
  }
}

typedef RefreshCallback = Future<bool> Function();

/// Cliente HTTP da API. Junta o access token e, se a API responder 401 por token
/// expirado, pede uma renovação de sessão (uma só de cada vez) e repete o pedido.
class ApiClient {
  ApiClient({String? baseUrl})
      : _dio = Dio(
          BaseOptions(
            baseUrl: baseUrl ?? AppConfig.apiBaseUrl,
            connectTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 20),
            receiveTimeout: const Duration(seconds: 20),
            responseType: ResponseType.json,
            // Tratamos nós os códigos de erro (4xx/5xx) em vez de o Dio lançar exceções.
            validateStatus: (status) => true,
            headers: <String, dynamic>{'Accept': 'application/json'},
          ),
        );

  final Dio _dio;

  /// Access token em memória.
  String? accessToken;

  /// Definido pelo AuthController: renova a sessão (single-flight).
  RefreshCallback? onRefresh;

  Future<ApiResponse> get(String path, {bool auth = false}) =>
      _request('GET', path, null, auth);

  Future<ApiResponse> post(String path, {Object? body, bool auth = false}) =>
      _request('POST', path, body, auth);

  Future<ApiResponse> patch(String path, {Object? body, bool auth = false}) =>
      _request('PATCH', path, body, auth);

  Future<ApiResponse> _request(
    String method,
    String path,
    Object? body,
    bool auth,
  ) async {
    var response = await _send(method, path, body, auth);

    // 401 sem "code" no corpo = token de acesso inválido/expirado (vem do middleware JWT).
    // 401 com "code" (ex.: invalid_credentials) é um erro de negócio: não se repete.
    final expired = auth &&
        response.status == 401 &&
        !response.json.containsKey('code') &&
        onRefresh != null;
    if (expired) {
      final refreshed = await onRefresh!();
      if (refreshed) {
        response = await _send(method, path, body, auth);
      }
    }
    return response;
  }

  Future<ApiResponse> _send(
    String method,
    String path,
    Object? body,
    bool auth,
  ) async {
    final token = accessToken;
    try {
      final res = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          contentType: body != null ? Headers.jsonContentType : null,
          headers: <String, dynamic>{
            if (auth && token != null) 'Authorization': 'Bearer $token',
          },
        ),
      );
      return ApiResponse(res.statusCode ?? 0, res.data);
    } on DioException catch (e) {
      debugPrint('[GameHall] $method $path falhou: ${e.type} ${e.message}');
      throw ApiException.network();
    } catch (e) {
      debugPrint('[GameHall] $method $path erro inesperado: $e');
      throw ApiException(
        status: 0,
        code: 'client_error',
        message: 'Ocorreu um erro inesperado. Tenta novamente.',
      );
    }
  }
}
