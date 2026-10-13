import 'user.dart';

/// What `POST /auth/login` expects.
///
/// The `username` field accepts either a username or an email address — the
/// backend matches on both — so the login screen's single field can be labelled
/// for whichever the crew finds easier to type.
class LoginRequest {
  final String username;
  final String password;

  const LoginRequest({required this.username, required this.password});

  Map<String, dynamic> toJson() {
    return {'username': username, 'password': password};
  }
}

/// What `POST /auth/login` returns.
///
/// The full user, roles included, arrives with the token — so the app knows
/// whether it is talking to a Sticker man without a second request.
class LoginResponse {
  final String accessToken;
  final String tokenType;
  final User user;

  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] ?? '',
      tokenType: json['token_type'] ?? 'bearer',
      user: User.fromJson(json['user']),
    );
  }
}
