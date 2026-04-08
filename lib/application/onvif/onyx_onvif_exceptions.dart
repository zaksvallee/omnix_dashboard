class OnyxOnvifException implements Exception {
  final String message;
  final Object? cause;

  const OnyxOnvifException(this.message, {this.cause});

  @override
  String toString() => '$runtimeType: $message';
}

class OnyxOnvifConnectionException extends OnyxOnvifException {
  const OnyxOnvifConnectionException(super.message, {super.cause});
}

class OnyxOnvifAuthException extends OnyxOnvifException {
  const OnyxOnvifAuthException(super.message, {super.cause});
}

class OnyxOnvifCapabilityException extends OnyxOnvifException {
  const OnyxOnvifCapabilityException(super.message, {super.cause});
}

class OnyxOnvifTimeoutException extends OnyxOnvifException {
  const OnyxOnvifTimeoutException(super.message, {super.cause});
}
