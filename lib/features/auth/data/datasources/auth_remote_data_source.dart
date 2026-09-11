import 'package:majichrono/core/network/api_client.dart';
import 'package:majichrono/core/network/api_endpoints.dart';

/// Acces reseau brut de l'authentification.
///
/// Cette classe ne connait que des `Map` : la traduction en entites du domaine
/// est le travail du repository. La separation permet de tester le mapping sans
/// reseau, et de changer le format de reponse sans toucher au domaine.
class AuthRemoteDataSource {
  AuthRemoteDataSource(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> requestOtp(String phoneE164) =>
      _client.post<Map<String, dynamic>>(
        ApiEndpoints.otpRequest,
        body: {'phone': phoneE164},
      );

  Future<Map<String, dynamic>> phoneLogin({
    required String phone,
    String? password,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.phoneLogin,
    body: {'phone': phone, 'password': ?password},
  );

  Future<Map<String, dynamic>> verifyOtp({
    required String challengeId,
    required String code,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.otpVerify,
    body: {'challengeId': challengeId, 'code': code},
  );

  Future<Map<String, dynamic>> requestEmailCode(String email) =>
      _client.post<Map<String, dynamic>>(
        ApiEndpoints.emailRequest,
        body: {'email': email},
      );

  Future<Map<String, dynamic>> verifyEmailCode({
    required String challengeId,
    required String code,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.emailVerify,
    body: {'challengeId': challengeId, 'code': code},
  );

  Future<Map<String, dynamic>> signInWithPassword({
    required String email,
    required String password,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.passwordSignIn,
    body: {'email': email, 'password': password},
  );

  Future<Map<String, dynamic>> signUpWithPassword({
    required String email,
    required String password,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.passwordSignUp,
    body: {'email': email, 'password': password},
  );

  Future<void> linkEmail(String email) =>
      _client.post<void>(ApiEndpoints.emailLink, body: {'email': email});

  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) => _client.post<void>(
    ApiEndpoints.passwordChange,
    body: {'currentPassword': ?currentPassword, 'newPassword': newPassword},
  );

  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  }) => _client.post<void>(
    ApiEndpoints.passwordReset,
    body: {
      'challengeId': challengeId,
      'code': code,
      'newPassword': newPassword,
    },
  );

  Future<Map<String, dynamic>> requestEmailChange(String email) =>
      _client.post<Map<String, dynamic>>(
        ApiEndpoints.emailChangeRequest,
        body: {'email': email},
      );

  Future<Map<String, dynamic>> verifyEmailChange({
    required String challengeId,
    required String code,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.emailChangeVerify,
    body: {'challengeId': challengeId, 'code': code},
  );

  Future<Map<String, dynamic>> requestPhoneChange(String phoneE164) =>
      _client.post<Map<String, dynamic>>(
        ApiEndpoints.phoneChangeRequest,
        body: {'phone': phoneE164},
      );

  Future<Map<String, dynamic>> verifyPhoneChange({
    required String challengeId,
    required String code,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.phoneChangeVerify,
    body: {'challengeId': challengeId, 'code': code},
  );

  Future<Map<String, dynamic>> uploadAvatar({
    required String imageBase64,
    required String contentType,
  }) => _client.post<Map<String, dynamic>>(
    ApiEndpoints.meAvatar,
    body: {'imageBase64': imageBase64, 'contentType': contentType},
  );

  Future<Map<String, dynamic>> deleteAvatar() =>
      _client.delete<Map<String, dynamic>>(ApiEndpoints.meAvatar);

  Future<Map<String, dynamic>> refresh(String refreshToken) =>
      _client.post<Map<String, dynamic>>(
        ApiEndpoints.refresh,
        body: {'refreshToken': refreshToken},
      );

  Future<void> logout() => _client.post<void>(ApiEndpoints.logout);

  Future<Map<String, dynamic>> me() =>
      _client.get<Map<String, dynamic>>(ApiEndpoints.me);

  Future<Map<String, dynamic>> patchMe({
    String? role,
    String? displayName,
    String? firstName,
    String? lastName,
  }) => _client.patch<Map<String, dynamic>>(
    ApiEndpoints.me,
    body: {
      'role': ?role,
      'displayName': ?displayName,
      'firstName': ?firstName,
      'lastName': ?lastName,
    },
  );

  Future<List<dynamic>> getSessions() =>
      _client.get<List<dynamic>>(ApiEndpoints.sessions);

  Future<void> revokeSession(String id) =>
      _client.delete<void>(ApiEndpoints.session(id));
}
