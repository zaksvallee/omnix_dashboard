class AuthorityToken {
  final String authorizedBy;
  final DateTime timestamp;

  const AuthorityToken({
    required this.authorizedBy,
    required this.timestamp,
  });
}
