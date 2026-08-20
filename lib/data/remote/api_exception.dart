class ApiException implements Exception {
  const ApiException({
    required this.statusCode,
    required this.message,
    this.code,
    this.details,
    this.requestId,
    this.retryAfterSeconds,
  });

  final int statusCode;
  final String message;
  final String? code;
  final Object? details;
  final String? requestId;
  final int? retryAfterSeconds;

  @override
  String toString() {
    final suffix = code == null ? '' : ' ($code)';
    return 'ApiException $statusCode$suffix: $message';
  }
}

class UnauthenticatedException implements Exception {
  const UnauthenticatedException([this.message = '缺少访问令牌，请登录后重试']);

  final String message;

  @override
  String toString() => message;
}

class ApiContractException implements Exception {
  const ApiContractException(this.message);

  final String message;

  @override
  String toString() => message;
}
