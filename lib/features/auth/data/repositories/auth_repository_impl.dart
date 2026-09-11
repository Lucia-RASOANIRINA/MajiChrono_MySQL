import 'dart:async';
import 'dart:convert';

import 'package:majichrono/core/error/failure.dart';
import 'package:majichrono/core/session/user_role.dart';
import 'package:majichrono/features/auth/data/datasources/auth_local_data_source.dart';
import 'package:majichrono/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:majichrono/features/auth/domain/entities/auth_entities.dart';
import 'package:majichrono/features/auth/domain/entities/google_entities.dart';
import 'package:majichrono/features/auth/domain/repositories/auth_repository.dart';
import 'package:majichrono/features/auth/domain/value_objects/malagasy_phone.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this._remote,
    required this._local,
    required this._onAccessTokenChanged,
  });

  final AuthRemoteDataSource _remote;
  final AuthLocalDataSource _local;

  /// Pousse le jeton courant vers le client HTTP, qui le pose en en-tete.
  final void Function(String? token) _onAccessTokenChanged;

  /// Rafraichissement en vol, partage.
  ///
  /// Sans ce verrou, deux requetes qui expirent en meme temps declencheraient
  /// deux rotations concurrentes : la seconde presenterait un jeton que la
  /// premiere vient d'invalider, et l'utilisateur serait deconnecte sans raison.
  /// Le cas est frequent sur reseau lent (§4.1), ou plusieurs requetes restent
  /// en vol longtemps.
  Future<AuthSession>? _refreshInFlight;

  @override
  Future<OtpChallenge> requestOtp(MalagasyPhone phone) async {
    final json = await _remote.requestOtp(phone.e164);
    return OtpChallenge(
      challengeId: json['challengeId'] as String,
      phone: phone,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
      debugCode: json['debugCode'] as String?,
    );
  }

  @override
  Future<PhoneLoginResult> loginWithPhone({
    required MalagasyPhone phone,
    String? password,
  }) async {
    final json = await _remote.phoneLogin(
      phone: phone.e164,
      password: password,
    );
    if (json['challengeId'] != null) {
      return PhoneOtpRequired(
        OtpChallenge(
          challengeId: json['challengeId'] as String,
          phone: phone,
          expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
          attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
          debugCode: json['debugCode'] as String?,
        ),
      );
    }
    final session = _sessionFrom(json['session'] as Map<String, dynamic>);
    await _persist(session);
    final accountJson = json['account'] as Map<String, dynamic>;
    await _local.saveAccount(accountJson);
    return PhonePasswordVerified(
      OtpVerification(session: session, account: _accountFrom(accountJson)),
    );
  }

  @override
  Future<OtpVerification> verifyOtp({
    required String challengeId,
    required String code,
  }) async {
    final json = await _remote.verifyOtp(challengeId: challengeId, code: code);

    final session = _sessionFrom(json['session'] as Map<String, dynamic>);
    await _persist(session);

    final accountJson = json['account'] as Map<String, dynamic>;
    await _local.saveAccount(accountJson);

    return OtpVerification(
      session: session,
      account: _accountFrom(accountJson),
    );
  }

  @override
  Future<EmailChallenge> requestEmailCode(String email) async {
    final normalized = email.trim().toLowerCase();
    final json = await _remote.requestEmailCode(normalized);
    return EmailChallenge(
      challengeId: json['challengeId'] as String,
      email: json['email'] as String? ?? normalized,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
      debugCode: json['debugCode'] as String?,
    );
  }

  @override
  Future<EmailVerification> verifyEmailCode({
    required String challengeId,
    required String code,
  }) async {
    final json = await _remote.verifyEmailCode(
      challengeId: challengeId,
      code: code,
    );

    return _emailOutcome(json);
  }

  @override
  Future<EmailVerification> signInWithPassword({
    required String email,
    required String password,
  }) async => _emailOutcome(
    await _remote.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    ),
  );

  @override
  Future<EmailVerification> signUpWithPassword({
    required String email,
    required String password,
  }) async => _emailOutcome(
    await _remote.signUpWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    ),
  );

  /// Traduit une reponse d'entree par adresse : session ouverte et persistee, ou
  /// adresse sans compte. Trois points d'entree partagent ce format ; les
  /// traduire au meme endroit evite qu'un seul d'entre eux oublie de persister
  /// la session.
  Future<EmailVerification> _emailOutcome(Map<String, dynamic> json) async {
    if (json['linked'] != true) {
      return EmailUnlinked(json['email'] as String? ?? '');
    }

    final session = _sessionFrom(json['session'] as Map<String, dynamic>);
    await _persist(session);

    final accountJson = json['account'] as Map<String, dynamic>;
    await _local.saveAccount(accountJson);

    return EmailLinked(
      OtpVerification(session: session, account: _accountFrom(accountJson)),
    );
  }

  @override
  Future<void> linkEmail(String email) =>
      _remote.linkEmail(email.trim().toLowerCase());

  @override
  Future<void> changePassword({
    String? currentPassword,
    required String newPassword,
  }) => _remote.changePassword(
    currentPassword: currentPassword,
    newPassword: newPassword,
  );

  @override
  Future<void> resetPassword({
    required String challengeId,
    required String code,
    required String newPassword,
  }) => _remote.resetPassword(
    challengeId: challengeId,
    code: code,
    newPassword: newPassword,
  );

  @override
  Future<EmailChallenge> requestEmailChange(String email) async {
    final normalized = email.trim().toLowerCase();
    final json = await _remote.requestEmailChange(normalized);
    return EmailChallenge(
      challengeId: json['challengeId'] as String,
      email: json['email'] as String? ?? normalized,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
      debugCode: json['debugCode'] as String?,
    );
  }

  @override
  Future<UserAccount> confirmEmailChange({
    required String challengeId,
    required String code,
  }) async => _adoptAccount(
    await _remote.verifyEmailChange(challengeId: challengeId, code: code),
  );

  @override
  Future<OtpChallenge> requestPhoneChange(MalagasyPhone phone) async {
    final json = await _remote.requestPhoneChange(phone.e164);
    return OtpChallenge(
      challengeId: json['challengeId'] as String,
      phone: phone,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      attemptsLeft: (json['attemptsLeft'] as num?)?.toInt() ?? 3,
      debugCode: json['debugCode'] as String?,
    );
  }

  @override
  Future<UserAccount> confirmPhoneChange({
    required String challengeId,
    required String code,
  }) async => _adoptAccount(
    await _remote.verifyPhoneChange(challengeId: challengeId, code: code),
  );

  @override
  Future<UserAccount> updateName({String? firstName, String? lastName}) async =>
      _adoptAccount(
        await _remote.patchMe(firstName: firstName, lastName: lastName),
      );

  @override
  Future<List<SessionInfo>> listSessions() async {
    final rows = await _remote.getSessions();
    return [
      for (final row in rows.cast<Map<String, dynamic>>())
        SessionInfo(
          id: row['id'] as String,
          deviceLabel: row['deviceLabel'] as String?,
          createdAt:
              DateTime.tryParse('${row['createdAt']}')?.toLocal() ??
              DateTime.now(),
          isCurrent: row['current'] == true,
        ),
    ];
  }

  @override
  Future<void> revokeSession(String id) => _remote.revokeSession(id);

  @override
  Future<UserAccount> uploadAvatar({
    required List<int> bytes,
    required String contentType,
  }) async => _adoptAccount(
    await _remote.uploadAvatar(
      imageBase64: base64Encode(bytes),
      contentType: contentType,
    ),
  );

  @override
  Future<UserAccount> deleteAvatar() async =>
      _adoptAccount(await _remote.deleteAvatar());

  /// Enregistre le compte renvoye par le serveur (cache hors ligne) et le rend.
  /// Un compte que l'on edite garde son role : l'absence de role signalerait un
  /// contrat casse, qu'on refuse plutot que de propager.
  Future<UserAccount> _adoptAccount(Map<String, dynamic> json) async {
    await _local.saveAccount(json);
    final result = _accountFrom(json);
    if (result is! AccountReady) {
      throw const ServerFailure(statusCode: 500, code: 'account_not_ready');
    }
    return result.account;
  }

  @override
  Future<UserAccount> chooseProfile({
    required UserRole role,
    required String firstName,
    required String lastName,
  }) async {
    final json = await _remote.patchMe(
      role: role.wireName,
      firstName: firstName,
      lastName: lastName,
    );

    // Le serveur reemet la session quand une information d'identite portee par
    // le jeton change (ici le profil). Adopter immediatement le nouveau couple
    // evite de continuer a presenter un jeton devenu incoherent.
    final reissued = json['session'] as Map<String, dynamic>?;
    if (reissued != null) {
      await _persist(_sessionFrom(reissued));
    }

    await _local.saveAccount(json);

    final result = _accountFrom(json);
    if (result is! AccountReady) {
      // Le serveur a accepte la requete sans poser le role : incoherence de
      // contrat, on la signale plutot que de laisser l'interface tourner en rond.
      throw const ServerFailure(statusCode: 500, code: 'role_not_applied');
    }
    return result.account;
  }

  @override
  Future<AuthSession?> currentSession() async {
    // Les trois lectures partent ensemble. Elles sont independantes, et chacune
    // traverse le Keystore Android : enchainees, elles coutaient trois fois le
    // meme aller-retour au demarrage, sur le chemin critique du premier ecran
    // (EXI-P01).
    final (access, refreshToken, expiries) = await (
      _local.readAccessToken(),
      _local.readRefreshToken(),
      _local.readExpiries(),
    ).wait;

    if (access == null || refreshToken == null || expiries == null) return null;

    final session = AuthSession(
      accessToken: access,
      refreshToken: refreshToken,
      accessExpiresAt: expiries.access,
      refreshExpiresAt: expiries.refresh,
    );
    _onAccessTokenChanged(access);
    return session;
  }

  @override
  Future<UserAccount?> cachedAccount() async {
    final json = await _local.readAccount();
    if (json == null) return null;
    final result = _accountFrom(json);
    return result is AccountReady ? result.account : null;
  }

  @override
  Future<AccountResult> fetchAccount() async {
    final json = await _remote.me();
    await _local.saveAccount(json);
    return _accountFrom(json);
  }

  @override
  Future<AuthSession> refresh() {
    // Un seul rafraichissement a la fois ; les appelants suivants attendent le
    // meme resultat.
    return _refreshInFlight ??= _doRefresh().whenComplete(() {
      _refreshInFlight = null;
    });
  }

  Future<AuthSession> _doRefresh() async {
    final refreshToken = await _local.readRefreshToken();
    if (refreshToken == null) {
      throw const UnauthorizedFailure(details: {'reason': 'no_refresh_token'});
    }
    final json = await _remote.refresh(refreshToken);
    final session = _sessionFrom(json['session'] as Map<String, dynamic>);
    await _persist(session);
    return session;
  }

  @override
  Future<void> signOut() async {
    // La revocation serveur est souhaitable, pas bloquante : hors ligne, on
    // efface quand meme l'appareil (EXI-SEC10). L'inverse laisserait des jetons
    // sur un telephone que l'utilisateur croit deconnecte.
    try {
      await _remote.logout();
    } on Failure {
      // Ignoree volontairement.
    }
    await _local.wipe();
    _onAccessTokenChanged(null);
  }

  @override
  Future<bool> hasPin() => _local.hasPin();

  @override
  Future<void> setPin(String pin) => _local.setPin(pin);

  @override
  Future<bool> verifyPin(String pin) async =>
      await _local.verifyPin(pin) == null;

  @override
  Future<void> clearPin() => _local.clearPin();

  // --- Mapping ----------------------------------------------------------

  Future<void> _persist(AuthSession session) async {
    await _local.saveSession(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
      accessExpiresAt: session.accessExpiresAt,
      refreshExpiresAt: session.refreshExpiresAt,
    );
    _onAccessTokenChanged(session.accessToken);
  }

  AuthSession _sessionFrom(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    refreshToken: json['refreshToken'] as String,
    accessExpiresAt: DateTime.parse(
      json['accessExpiresAt'] as String,
    ).toLocal(),
    refreshExpiresAt: DateTime.parse(
      json['refreshExpiresAt'] as String,
    ).toLocal(),
  );

  AccountResult _accountFrom(Map<String, dynamic> json) {
    final phone = MalagasyPhone.tryParse(json['phone'] as String? ?? '');
    if (phone == null) {
      throw const ServerFailure(
        statusCode: 500,
        code: 'invalid_phone_in_account',
      );
    }

    final role = UserRole.fromWire(json['role'] as String?);
    if (role == null) return AccountProfilePending(phone);

    return AccountReady(
      UserAccount(
        id: json['id'] as String,
        phone: phone,
        role: role,
        displayName: json['displayName'] as String? ?? '',
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        email: json['email'] as String?,
        createdAt:
            DateTime.tryParse('${json['createdAt']}')?.toLocal() ??
            DateTime.now(),
        avatarUrl: json['avatarUrl'] as String?,
        rating: (json['rating'] as num?)?.toDouble(),
        kycStatus: KycStatus.fromWire(json['kycStatus'] as String?),
      ),
    );
  }
}
