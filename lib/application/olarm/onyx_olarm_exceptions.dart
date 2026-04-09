class OnyxOlarmException implements Exception {
  final String message;
  final int? statusCode;
  final Object? cause;

  const OnyxOlarmException(
    this.message, {
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    if (statusCode == null) {
      return 'OnyxOlarmException: $message';
    }
    return 'OnyxOlarmException($statusCode): $message';
  }
}

class OnyxOlarmUnauthorizedException extends OnyxOlarmException {
  const OnyxOlarmUnauthorizedException(super.message, {super.cause})
    : super(statusCode: 401);
}

class OnyxOlarmRateLimitedException extends OnyxOlarmException {
  const OnyxOlarmRateLimitedException(super.message, {super.cause})
    : super(statusCode: 429);
}

class OnyxOlarmDeviceNotFoundException extends OnyxOlarmException {
  const OnyxOlarmDeviceNotFoundException(super.message, {super.cause})
    : super(statusCode: 404);
}

class OnyxOlarmApiException extends OnyxOlarmException {
  const OnyxOlarmApiException(
    super.message, {
    super.statusCode,
    super.cause,
  });
}

class OnyxOlarmMqttException extends OnyxOlarmException {
  const OnyxOlarmMqttException(super.message, {super.cause});
}
