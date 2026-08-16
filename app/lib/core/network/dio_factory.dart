import 'package:dio/dio.dart';

import '../config/app_config.dart';

/// O Dio fala apenas com o nosso backend. Chamada a API de terceiro
/// (Gemini, Pluggy, Google) não sai do app — sai do servidor.
Dio createDio(AppConfig config, {String Function()? accessToken}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Content-Type': 'application/json'},
    ),
  );

  if (accessToken != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = accessToken();
          if (token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );
  }

  return dio;
}
