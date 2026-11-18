// Common API exception types.
import 'package:dio/dio.dart';

/// Base exception for API errors.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;

  factory ApiException.fromDio(DioException error) {
    final status = error.response?.statusCode;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => ApiException(
          'сервер не отвечает. проверьте интернет и попробуйте ещё раз.',
          statusCode: status,
        ),
      DioExceptionType.connectionError => ApiException(
          'нет соединения. проверьте интернет.',
          statusCode: status,
        ),
      _ => switch (status) {
          404 => const ApiException('не найдено.', statusCode: 404),
          429 => const ApiException(
              'слишком много запросов. подождите немного.',
              statusCode: 429,
            ),
          403 => const ApiException(
              'доступ ограничен сервером.',
              statusCode: 403,
            ),
          _ => ApiException(
              'не удалось загрузить данные. попробуйте ещё раз.',
              statusCode: status,
            ),
        },
    };
  }
}