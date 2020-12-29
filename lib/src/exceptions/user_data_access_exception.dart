class UserDataAccessException implements Exception {
  final UserDataAccessExceptionType exceptionType;
  final String message;
  const UserDataAccessException({
    this.exceptionType = UserDataAccessExceptionType.unknown,
    this.message =
        "Une Erreur critique est survenue. Si l'erreur persiste veuillez redémarrer l'application.",
  });
  const UserDataAccessException.unknown() : this();
}

enum UserDataAccessExceptionType { unknown }
