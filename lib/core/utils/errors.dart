import '../api/exceptions.dart';

String userMessage(Object error) {
  if (error is ApiException) return error.message;
  return 'что-то пошло не так. попробуйте ещё раз.';
}
