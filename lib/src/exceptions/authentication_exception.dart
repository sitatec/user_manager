import 'package:meta/meta.dart';

class AuthenticationException implements Exception {
  final AuthenticationExceptionType exceptionType;
  final String message;
  const AuthenticationException(
      {@required this.exceptionType, @required this.message});

  const AuthenticationException.unknown()
      : this(
          exceptionType: AuthenticationExceptionType.unknown,
          message:
              "Une Erreur critique est survenue. Si l'erreur persiste veuillez redémarrer l'application.",
        );

  const AuthenticationException.invalidVerificationCode()
      : this(
          exceptionType: AuthenticationExceptionType.invalidVerificationCode,
          message:
              'Le code que vous avez saisie ne correspond pas à celui que nous vous avons envoyé.',
        );

  const AuthenticationException.emailAlreadyUsed()
      : this(
          exceptionType: AuthenticationExceptionType.emailAlreadyUsed,
          message:
              "L'adresse email que vous avez saisie est déjà liée à un compte",
        );

  const AuthenticationException.weakPassword()
      : this(
          exceptionType: AuthenticationExceptionType.weakPassword,
          message: 'Le mot de passe que vous avez saisie est trop faible.',
        );

  const AuthenticationException.invalidEmail()
      : this(
          exceptionType: AuthenticationExceptionType.invalidEmail,
          message: 'Adresse email invalid.',
        );

  const AuthenticationException.userDisabled()
      : this(
          exceptionType: AuthenticationExceptionType.userDisabled,
          message:
              'Votre compte a été temporairement désactivé, si vous ne connaissez pas les raisons pour lesquelles votre compte a été désactivé veuillez nous contacter (taluxi.gn@gmail.com) pour plus d\'informations.',
        );

  const AuthenticationException.userNotFound()
      : this(
          exceptionType: AuthenticationExceptionType.userNotFound,
          message:
              "L'adresse email que vous avez saisie ne correspond à aucun compte existant. S'il vous plaît veuillez saisir la bonne adresse email ou créez un nouveaux compte si vous n'êtes pas déjà inscrit.",
        );

  const AuthenticationException.wrongPassword()
      : this(
          exceptionType: AuthenticationExceptionType.wrongPassword,
          message: 'Mot de passe incorrect.',
        );

  const AuthenticationException.invalidCredential()
      : this(
          exceptionType: AuthenticationExceptionType.invalidCredential,
          message:
              "Nous n'arrivons pas à obtenir l'autorisation de vous connecter à l'aide de votre compte facebook. s'il vous plaît veuillez vous assurez que vous n'avez pas désactivé l'autorisation de Taluxi sur les paramètres de votre compte facebook.",
        );

  const AuthenticationException.accountExistsWithDifferentCredential()
      : this(
          exceptionType:
              AuthenticationExceptionType.accountExistsWithDifferentCredential,
          message:
              "Un conflit d'adresse email est survenu, il se peut que vous vous êtes connecté au part avant avec une méthode de connexion différente de celle que tentez d'utiliser actuellement mais que vous avez utilisez la même adresse pour les deux méthodes. Ce type d'erreur peut arriver si vous avez créer un compte avec votre email et que vous tentez par la suite de vous connecter avec un compte facebook qui est lié à cet email , dans ce cas vous devez vous connecter en saisissant votre email et mot de passe au lieu de tenter de vous connecter avec votre compte facebook.",
        );
}

enum AuthenticationExceptionType {
  unknown,
  invalidVerificationCode,
  emailAlreadyUsed,
  weakPassword,
  invalidEmail,
  userDisabled,
  userNotFound,
  wrongPassword,
  invalidCredential,
  accountExistsWithDifferentCredential
}
