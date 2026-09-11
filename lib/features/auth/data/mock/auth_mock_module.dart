import 'dart:convert';
import 'dart:math';

import 'package:majichrono/core/network/api_endpoints.dart';
import 'package:majichrono/core/network/mock/mock_backend.dart';

/// Routes simulees de l'authentification (§12.2).
///
/// Deux partis pris rendent ce simulateur utilisable en recette :
///
///  - **Il est sans etat persistant.** Le jeton porte lui-meme l'identite du
///    compte, encodee en base64. Une session survit donc au redemarrage de
///    l'application sans qu'aucune base ne soit tenue cote simulateur — ce qui
///    permet de recetter la reconnexion par PIN (EXI-T04) juste apres un
///    « kill » de l'application. Ce n'est evidemment pas un JWT : rien n'est
///    signe, et cela n'a pas a l'etre, puisque ce code n'existe qu'en mode
///    `mock` et ne sera jamais compile face a un vrai serveur.
///
///  - **Le code OTP est renvoye en clair** dans la reponse, sous `debugCode`.
///    Sans passerelle SMS, c'est le seul moyen de derouler le parcours. Le
///    champ est ignore en mode `live`, et l'interface ne l'affiche que si le
///    panneau developpeur est actif.
class AuthMockModule extends MockModule {
  AuthMockModule({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// Defis en cours, par identifiant. Volontairement en memoire : un defi OTP
  /// vit cinq minutes, il n'a pas a survivre au processus.
  final Map<String, _Challenge> _challenges = {};

  /// Defis envoyes par e-mail, memes regles de duree et de tentatives.
  final Map<String, _EmailChallenge> _emailChallenges = {};

  /// Sessions actives, par famille — un appareil connecte. En memoire (le vrai
  /// serveur les range en base) : suffisant pour recetter liste et revocation.
  final Map<String, _Session> _sessions = {};

  /// Rattachements adresse -> numero.
  ///
  /// Le numero reste la cle du compte : l'adresse n'est qu'une seconde porte
  /// vers la meme identite. Une adresse absente de cette table designe donc un
  /// visiteur, pas un compte a creer.
  final Map<String, String> _emailLinks = {...seededEmails};

  /// Mots de passe, par adresse. Les comptes pre-inscrits en ont un pour que la
  /// connexion par mot de passe soit recettable sans inscription prealable.
  final Map<String, String> _passwords = {
    for (final email in seededEmails.keys) email: seededPassword,
  };

  static const Duration otpValidity = Duration(minutes: 5);
  static const int maxAttempts = 3;
  static const Duration accessTtl = Duration(minutes: 15);
  static const Duration refreshTtl = Duration(days: 30);

  /// Numeros reserves a la recette, pre-inscrits avec un profil.
  ///
  /// Ils evitent de rejouer le choix de profil a chaque test et donnent un
  /// compte administrateur, que l'inscription mobile ne peut pas produire
  /// (EXI-T02).
  static const Map<String, ({String role, String name})> seededAccounts = {
    '+261340000001': (role: 'client', name: 'Hery Rakoto'),
    '+261330000002': (role: 'driver', name: 'Naina Andria'),
    '+261320000003': (role: 'admin', name: 'Miora Rasoa'),
  };

  /// Adresses deja rattachees a un compte pre-inscrit.
  ///
  /// La troisieme adresse proposee par la detection simulee est volontairement
  /// absente : c'est elle qui deroule le cas « adresse verifiee, compte
  /// inconnu », ou le parcours bascule sur le numero de telephone.
  static const Map<String, String> seededEmails = {
    'hery.rakoto@gmail.com': '+261340000001',
    'naina.andria@gmail.com': '+261330000002',
  };

  /// Mots de passe des comptes de recette, en clair — c'est un simulateur, et il
  /// n'est jamais compile face a un vrai serveur. Le vrai backend ne stockera
  /// qu'une empreinte Argon2 (§8.4).
  static const String seededPassword = 'majichrono';

  @override
  void register(MockBackend backend) {
    backend.post(ApiEndpoints.passwordSignIn, _signInWithPassword);
    backend.post(ApiEndpoints.passwordSignUp, _signUpWithPassword);
    backend.post(ApiEndpoints.emailRequest, _requestEmailCode);
    backend.post(ApiEndpoints.emailVerify, _verifyEmailCode);
    backend.post(ApiEndpoints.emailLink, _linkEmail);
    backend.post(ApiEndpoints.otpRequest, _requestOtp);
    backend.post(ApiEndpoints.otpVerify, _verifyOtp);
    backend.post(ApiEndpoints.refresh, _refresh);
    backend.post(ApiEndpoints.logout, _logout);
    backend.get(ApiEndpoints.me, _me);
    backend.patch(ApiEndpoints.me, _patchMe);
    backend.post(ApiEndpoints.passwordChange, _changePassword);
    backend.post(ApiEndpoints.passwordReset, _resetPassword);
    backend.post(ApiEndpoints.emailChangeRequest, _requestEmailChange);
    backend.post(ApiEndpoints.emailChangeVerify, _verifyEmailChange);
    backend.post(ApiEndpoints.phoneChangeRequest, _requestPhoneChange);
    backend.post(ApiEndpoints.phoneChangeVerify, _verifyPhoneChange);
    backend.post(ApiEndpoints.meAvatar, _uploadAvatar);
    backend.delete(ApiEndpoints.meAvatar, _deleteAvatar);
    backend.get(ApiEndpoints.sessions, _listSessions);
    backend.delete('/auth/sessions/{family}', _revokeSession);
  }

  @override
  Future<void> reset() async {
    _challenges.clear();
    _emailChallenges.clear();
    _sessions.clear();
    _emailLinks
      ..clear()
      ..addAll(seededEmails);
    _passwords
      ..clear()
      ..addAll({for (final email in seededEmails.keys) email: seededPassword});
  }

  // --- POST /auth/password/signin ---------------------------------------

  Future<MockResponse> _signInWithPassword(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final email = (req.json['email'] as String?)?.trim().toLowerCase();
    final password = req.json['password'] as String?;

    // Une seule reponse d'echec pour « adresse inconnue » et « mot de passe
    // faux ». Les distinguer dirait a un attaquant quelles adresses ont un
    // compte, ce que le point d'entree par code refuse deja de dire.
    if (email == null || password == null || _passwords[email] != password) {
      return MockResponse.error(
        401,
        'bad_credentials',
        'E-mail ou mot de passe incorrect',
      );
    }

    return _sessionForEmail(email, deviceLabel: _deviceOf(req));
  }

  // --- POST /auth/password/signup ---------------------------------------

  Future<MockResponse> _signUpWithPassword(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final email = (req.json['email'] as String?)?.trim().toLowerCase();
    final password = req.json['password'] as String?;

    if (email == null || !_looksLikeEmail(email)) {
      return MockResponse.error(422, 'invalid_email', 'Adresse e-mail invalide');
    }
    if (password == null || password.length < minPasswordLength) {
      return MockResponse.error(
        422,
        'weak_password',
        'Mot de passe trop court',
        details: {'minLength': minPasswordLength},
      );
    }
    if (_passwords.containsKey(email)) {
      return MockResponse.error(
        409,
        'email_taken',
        'Cette adresse a deja un compte',
      );
    }

    _passwords[email] = password;

    // Le mot de passe est enregistre, mais **aucune session n'est ouverte** :
    // le compte n'existe pas encore tant qu'aucun numero ne s'y rattache. La
    // reponse est volontairement celle d'une adresse non rattachee, pour que
    // l'application enchaine sur la confirmation du numero comme apres Google.
    return MockResponse.ok({'linked': false, 'email': email});
  }

  static const int minPasswordLength = 8;

  /// Ouvre la session du compte rattache a une adresse, ou signale qu'aucun
  /// numero ne s'y rattache encore.
  MockResponse _sessionForEmail(String email, {String? deviceLabel}) {
    final phone = _emailLinks[email];
    if (phone == null) return MockResponse.ok({'linked': false, 'email': email});

    return MockResponse.ok({
      'linked': true,
      'session': _issueSession(_accountFor(phone), deviceLabel: deviceLabel),
      'account': _accountFor(phone).toJson(),
    });
  }

  /// Compte associe a un numero, adresse rattachee comprise.
  ///
  /// L'adresse est retrouvee par balayage inverse plutot que stockee deux fois :
  /// deux tables a tenir a jour finiraient par se contredire, et c'est le genre
  /// de divergence qu'on ne remarque que le jour ou un utilisateur se plaint de
  /// ne plus voir son adresse.
  _Account _accountFor(String phone) {
    final seeded = seededAccounts[phone];
    String? email;
    for (final entry in _emailLinks.entries) {
      if (entry.value == phone) {
        email = entry.key;
        break;
      }
    }

    return _Account(
      id: 'usr_${phone.substring(4)}',
      phone: phone,
      role: seeded?.role,
      name: seeded?.name ?? '',
      createdAt: DateTime.now(),
      email: email,
    );
  }

  // --- POST /auth/email/request -----------------------------------------

  Future<MockResponse> _requestEmailCode(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final email = (req.json['email'] as String?)?.trim().toLowerCase();
    if (email == null || !_looksLikeEmail(email)) {
      return MockResponse.error(
        422,
        'invalid_email',
        'Adresse e-mail invalide',
        details: {
          'fields': {'email': 'format_invalide'},
        },
      );
    }

    final challengeId = 'eml_${_random.nextInt(1 << 32)}';
    final code = (_random.nextInt(900000) + 100000).toString();
    final expiresAt = DateTime.now().add(otpValidity);

    _emailChallenges[challengeId] = _EmailChallenge(
      email: email,
      code: code,
      expiresAt: expiresAt,
      attemptsLeft: maxAttempts,
    );

    // Le serveur ne dit pas si l'adresse est connue : repondre « compte
    // inconnu » avant meme la saisie du code transformerait ce point d'entree en
    // oracle permettant d'enumerer les comptes. La distinction n'apparait qu'a
    // la verification, une fois la possession de la boite prouvee.
    return MockResponse.ok({
      'challengeId': challengeId,
      'email': email,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'attemptsLeft': maxAttempts,
      'debugCode': code,
    });
  }

  // --- POST /auth/email/verify ------------------------------------------

  Future<MockResponse> _verifyEmailCode(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final challengeId = req.json['challengeId'] as String?;
    final code = req.json['code'] as String?;
    final challenge = _emailChallenges[challengeId];

    if (challenge == null) {
      return MockResponse.error(
        422,
        'unknown_challenge',
        'Defi inconnu ou deja utilise',
      );
    }
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      _emailChallenges.remove(challengeId);
      return MockResponse.error(422, 'otp_expired', 'Code expire');
    }
    if (code != challenge.code) {
      final left = challenge.attemptsLeft - 1;
      if (left <= 0) {
        _emailChallenges.remove(challengeId);
        return MockResponse.error(422, 'otp_locked', 'Trop de tentatives');
      }
      _emailChallenges[challengeId!] = challenge.copyWith(attemptsLeft: left);
      return MockResponse.error(
        422,
        'otp_invalid',
        'Code incorrect',
        details: {'attemptsLeft': left},
      );
    }

    _emailChallenges.remove(challengeId);

    // Adresse prouvee. Si aucun numero ne s'y rattache, aucune session n'est
    // ouverte : un compte sans numero ne pourrait ni etre appele par un livreur,
    // ni recevoir le SMS de suivi (EXI-C24).
    return _sessionForEmail(challenge.email, deviceLabel: _deviceOf(req));
  }

  // --- POST /auth/email/link --------------------------------------------

  Future<MockResponse> _linkEmail(MockRequest req, Map<String, String> _) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }

    final email = (req.json['email'] as String?)?.trim().toLowerCase();
    if (email == null || !_looksLikeEmail(email)) {
      return MockResponse.error(422, 'invalid_email', 'Adresse e-mail invalide');
    }

    // Une adresse ne vaut que pour un compte : la rattacher a un second en
    // ferait une porte vers deux identites, et le prochain code recu ne dirait
    // plus laquelle ouvrir.
    final existing = _emailLinks[email];
    if (existing != null && existing != account.phone) {
      return MockResponse.error(
        409,
        'email_already_linked',
        'Cette adresse est deja rattachee a un autre compte',
      );
    }

    _emailLinks[email] = account.phone;
    return MockResponse.noContent();
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(value);

  // --- POST /auth/otp/request ------------------------------------------

  Future<MockResponse> _requestOtp(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final phone = req.json['phone'] as String?;
    // Memes plages que le domaine : Orange (32), Airtel (33), Telma (34, 38) et
    // le fixe Telma (20). Le simulateur refuse ce que le vrai serveur refusera.
    if (phone == null || !RegExp(r'^\+261(32|33|34|38|20)\d{7}$').hasMatch(phone)) {
      return MockResponse.error(
        422,
        'invalid_phone',
        'Numero de telephone malgache invalide',
        details: {
          'fields': {'phone': 'format_invalide'},
        },
      );
    }

    final challengeId = 'chg_${_random.nextInt(1 << 32)}';
    final code = (_random.nextInt(900000) + 100000).toString();
    final expiresAt = DateTime.now().add(otpValidity);

    _challenges[challengeId] = _Challenge(
      phone: phone,
      code: code,
      expiresAt: expiresAt,
      attemptsLeft: maxAttempts,
    );

    return MockResponse.ok({
      'challengeId': challengeId,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'attemptsLeft': maxAttempts,
      'debugCode': code,
    });
  }

  // --- POST /auth/otp/verify -------------------------------------------

  Future<MockResponse> _verifyOtp(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final challengeId = req.json['challengeId'] as String?;
    final code = req.json['code'] as String?;
    final challenge = _challenges[challengeId];

    if (challenge == null) {
      return MockResponse.error(
        422,
        'unknown_challenge',
        'Defi inconnu ou deja utilise',
      );
    }
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      _challenges.remove(challengeId);
      return MockResponse.error(422, 'otp_expired', 'Code expire');
    }
    if (code != challenge.code) {
      final left = challenge.attemptsLeft - 1;
      if (left <= 0) {
        _challenges.remove(challengeId);
        return MockResponse.error(422, 'otp_locked', 'Trop de tentatives');
      }
      _challenges[challengeId!] = challenge.copyWith(attemptsLeft: left);
      return MockResponse.error(
        422,
        'otp_invalid',
        'Code incorrect',
        details: {'attemptsLeft': left},
      );
    }

    // Le defi est brule des qu'il a servi : un code ne vaut qu'une fois.
    _challenges.remove(challengeId);

    final account = _accountFor(challenge.phone);

    return MockResponse.ok({
      'session': _issueSession(account, deviceLabel: _deviceOf(req)),
      'account': account.toJson(),
    });
  }

  // --- POST /auth/refresh ----------------------------------------------

  Future<MockResponse> _refresh(MockRequest req, Map<String, String> _) async {
    final token = req.json['refreshToken'] as String?;
    final claims = _decode(token);
    if (claims == null || claims['typ'] != 'refresh') {
      return MockResponse.error(
        401,
        'invalid_refresh',
        'Jeton de rafraichissement invalide',
      );
    }
    if (_isExpired(claims)) {
      return MockResponse.error(401, 'refresh_expired', 'Session expiree');
    }
    // Rotation : le couple precedent n'est plus valable (EXI-T03). La famille
    // est conservee — c'est la meme session (le meme appareil) qui se prolonge.
    return MockResponse.ok({
      'session': _issueSession(
        _Account.fromClaims(claims),
        family: claims['fam'] as String?,
      ),
    });
  }

  // --- POST /auth/logout -----------------------------------------------

  Future<MockResponse> _logout(MockRequest req, Map<String, String> _) async =>
      MockResponse.noContent();

  // --- GET /me ----------------------------------------------------------

  Future<MockResponse> _me(MockRequest req, Map<String, String> _) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(
        401,
        'unauthorized',
        'Jeton absent ou invalide',
      );
    }
    return MockResponse.ok(account.toJson());
  }

  // --- PATCH /me : pose du profil (EXI-T02) -----------------------------

  Future<MockResponse> _patchMe(MockRequest req, Map<String, String> _) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(
        401,
        'unauthorized',
        'Jeton absent ou invalide',
      );
    }

    final role = req.json['role'] as String?;
    final displayName = req.json['displayName'] as String?;
    final first = req.json['firstName'] as String?;
    final last = req.json['lastName'] as String?;

    // EXI-T02 : le role administrateur est attribue cote serveur uniquement.
    // Une application qui le reclamerait doit etre refusee, pas ignoree.
    if (role == 'admin') {
      return MockResponse.error(
        403,
        'role_not_assignable',
        'Le role administrateur est attribue cote serveur',
      );
    }
    if (role != null && role != 'client' && role != 'driver') {
      return MockResponse.error(422, 'invalid_role', 'Role inconnu');
    }
    // Le profil ne se choisit qu'une fois : changer de role changerait la nature
    // du compte et l'historique qui y est rattache.
    if (role != null && account.role != null && account.role != role) {
      return MockResponse.error(409, 'role_already_set', 'Profil deja defini');
    }

    // Prenom / nom priment sur `displayName` seul, et recomposent le nom d'usage.
    final newFirst = first != null ? (first.trim().isEmpty ? null : first.trim()) : account.firstName;
    final newLast = last != null ? (last.trim().isEmpty ? null : last.trim()) : account.lastName;
    final String newName;
    if (first != null || last != null) {
      newName = [newFirst, newLast].whereType<String>().join(' ').trim();
    } else {
      newName = displayName ?? account.name;
    }

    final updated = account.copyWith(
      role: role ?? account.role,
      name: newName,
      firstName: newFirst,
      lastName: newLast,
      kycStatus: (role ?? account.role) == 'driver' ? 'draft' : null,
    );

    // Le profil fait partie des informations portees par le jeton. Le modifier
    // sans reemettre la session laisserait circuler un jeton qui contredit le
    // compte : le serveur croirait le profil pose, le jeton dirait le contraire,
    // et une seconde tentative de choix passerait au travers du controle
    // ci-dessus. Toute donnee d'identite qui change entraine donc une rotation.
    final reissue = role != null && role != account.role;

    return MockResponse.ok({
      ...updated.toJson(),
      if (reissue) 'session': _issueSession(updated, family: _decode(req.bearer)?['fam'] as String?),
    });
  }

  // --- POST /auth/password/change --------------------------------------

  Future<MockResponse> _changePassword(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final next = req.json['newPassword'] as String?;
    if (next == null || next.length < minPasswordLength) {
      return MockResponse.error(
        422,
        'weak_password',
        'Mot de passe trop court',
        details: {'minLength': minPasswordLength},
      );
    }
    // Le mot de passe est range par adresse, ou par numero a defaut (compte
    // entre par numero qui s'en pose un pour la premiere fois).
    final key = account.email ?? account.phone;
    final existing = _passwords[key];
    if (existing != null && existing != (req.json['currentPassword'] as String?)) {
      // 403 et non 401 : un 401 ferait tourner l'intercepteur de rafraichissement
      // (jeton « expire ») en boucle. La session est valide, c'est la preuve qui
      // est fausse.
      return MockResponse.error(
        403,
        'wrong_current_password',
        'Mot de passe actuel incorrect',
      );
    }
    _passwords[key] = next;
    return MockResponse.noContent();
  }

  // --- POST /auth/password/reset ---------------------------------------

  Future<MockResponse> _resetPassword(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final next = req.json['newPassword'] as String?;
    if (next == null || next.length < minPasswordLength) {
      return MockResponse.error(
        422,
        'weak_password',
        'Mot de passe trop court',
        details: {'minLength': minPasswordLength},
      );
    }
    final challenge = _takeEmailChallenge(req);
    if (challenge.error != null) return challenge.error!;
    _passwords[challenge.value!.email] = next;
    return MockResponse.noContent();
  }

  // --- Changement d'adresse e-mail (compte connecte) -------------------

  Future<MockResponse> _requestEmailChange(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final email = (req.json['email'] as String?)?.trim().toLowerCase();
    if (email == null || !_looksLikeEmail(email)) {
      return MockResponse.error(422, 'invalid_email', 'Adresse e-mail invalide');
    }
    final owner = _emailLinks[email];
    if (owner != null && owner != account.phone) {
      return MockResponse.error(
        409,
        'email_taken',
        'Cette adresse est deja rattachee a un autre compte',
      );
    }
    final challengeId = 'eml_${_random.nextInt(1 << 32)}';
    final code = (_random.nextInt(900000) + 100000).toString();
    final expiresAt = DateTime.now().add(otpValidity);
    _emailChallenges[challengeId] = _EmailChallenge(
      email: email,
      code: code,
      expiresAt: expiresAt,
      attemptsLeft: maxAttempts,
    );
    return MockResponse.ok({
      'challengeId': challengeId,
      'email': email,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'attemptsLeft': maxAttempts,
      'debugCode': code,
    });
  }

  Future<MockResponse> _verifyEmailChange(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final result = _takeEmailChallenge(req);
    if (result.error != null) return result.error!;
    final newEmail = result.value!.email;

    final owner = _emailLinks[newEmail];
    if (owner != null && owner != account.phone) {
      return MockResponse.error(
        409,
        'email_taken',
        'Cette adresse est deja rattachee a un autre compte',
      );
    }
    // Repointe le rattachement : l'ancienne adresse de ce compte s'efface, la
    // nouvelle prend sa place.
    _emailLinks.removeWhere((_, phone) => phone == account.phone);
    _emailLinks[newEmail] = account.phone;

    final updated = account.copyWith(email: newEmail);
    return MockResponse.ok({
      ...updated.toJson(),
      'session': _issueSession(updated, family: _decode(req.bearer)?['fam'] as String?),
    });
  }

  // --- Changement de numero (compte connecte) --------------------------

  Future<MockResponse> _requestPhoneChange(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final phone = req.json['phone'] as String?;
    if (phone == null ||
        !RegExp(r'^\+261(32|33|34|38|20)\d{7}$').hasMatch(phone)) {
      return MockResponse.error(
        422,
        'invalid_phone',
        'Numero de telephone malgache invalide',
      );
    }
    if (phone != account.phone && _emailLinks.containsValue(phone)) {
      return MockResponse.error(
        409,
        'phone_taken',
        'Ce numero est deja utilise par un autre compte',
      );
    }
    final challengeId = 'chg_${_random.nextInt(1 << 32)}';
    final code = (_random.nextInt(900000) + 100000).toString();
    final expiresAt = DateTime.now().add(otpValidity);
    _challenges[challengeId] = _Challenge(
      phone: phone,
      code: code,
      expiresAt: expiresAt,
      attemptsLeft: maxAttempts,
    );
    return MockResponse.ok({
      'challengeId': challengeId,
      'expiresAt': expiresAt.toUtc().toIso8601String(),
      'attemptsLeft': maxAttempts,
      'debugCode': code,
    });
  }

  Future<MockResponse> _verifyPhoneChange(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final challengeId = req.json['challengeId'] as String?;
    final code = req.json['code'] as String?;
    final challenge = _challenges[challengeId];
    if (challenge == null) {
      return MockResponse.error(
        422,
        'unknown_challenge',
        'Defi inconnu ou deja utilise',
      );
    }
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      _challenges.remove(challengeId);
      return MockResponse.error(422, 'otp_expired', 'Code expire');
    }
    if (code != challenge.code) {
      final left = challenge.attemptsLeft - 1;
      if (left <= 0) {
        _challenges.remove(challengeId);
        return MockResponse.error(422, 'otp_locked', 'Trop de tentatives');
      }
      _challenges[challengeId!] = challenge.copyWith(attemptsLeft: left);
      return MockResponse.error(
        422,
        'otp_invalid',
        'Code incorrect',
        details: {'attemptsLeft': left},
      );
    }
    _challenges.remove(challengeId);

    final newPhone = challenge.phone;
    // Le rattachement d'adresse suit le compte vers son nouveau numero.
    _emailLinks.updateAll((_, phone) => phone == account.phone ? newPhone : phone);
    final updated = account.copyWith(phone: newPhone);
    return MockResponse.ok({
      ...updated.toJson(),
      'session': _issueSession(updated, family: _decode(req.bearer)?['fam'] as String?),
    });
  }

  // --- Photo de profil --------------------------------------------------

  Future<MockResponse> _uploadAvatar(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final image = req.json['imageBase64'] as String?;
    final type = (req.json['contentType'] as String?)?.trim().toLowerCase();
    if (image == null || image.isEmpty) {
      return MockResponse.error(422, 'invalid_image', 'Image vide');
    }
    if (type == null ||
        !{'image/jpeg', 'image/png', 'image/webp'}.contains(type)) {
      return MockResponse.error(422, 'unsupported_type', 'Format non accepte');
    }
    // Sans serveur d'images, la photo revient telle quelle sous forme de data
    // URI : l'application sait la rendre (voir la resolution d'avatar cote
    // profil), et le parcours se recette de bout en bout en mode simule.
    final updated = account.copyWith(avatarUrl: 'data:$type;base64,$image');
    return MockResponse.ok({
      ...updated.toJson(),
      'session': _issueSession(updated, family: _decode(req.bearer)?['fam'] as String?),
    });
  }

  Future<MockResponse> _deleteAvatar(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final updated = account.copyWith(avatarUrl: null);
    return MockResponse.ok({
      ...updated.toJson(),
      'session': _issueSession(updated, family: _decode(req.bearer)?['fam'] as String?),
    });
  }

  /// Consomme un defi e-mail (partage par la reinitialisation et le changement
  /// d'adresse) : rend le defi brule, ou l'erreur a renvoyer telle quelle.
  ({_EmailChallenge? value, MockResponse? error}) _takeEmailChallenge(
    MockRequest req,
  ) {
    final challengeId = req.json['challengeId'] as String?;
    final code = req.json['code'] as String?;
    final challenge = _emailChallenges[challengeId];
    if (challenge == null) {
      return (
        value: null,
        error: MockResponse.error(
          422,
          'unknown_challenge',
          'Defi inconnu ou deja utilise',
        ),
      );
    }
    if (DateTime.now().isAfter(challenge.expiresAt)) {
      _emailChallenges.remove(challengeId);
      return (
        value: null,
        error: MockResponse.error(422, 'otp_expired', 'Code expire'),
      );
    }
    if (code != challenge.code) {
      final left = challenge.attemptsLeft - 1;
      if (left <= 0) {
        _emailChallenges.remove(challengeId);
        return (
          value: null,
          error: MockResponse.error(422, 'otp_locked', 'Trop de tentatives'),
        );
      }
      _emailChallenges[challengeId!] = challenge.copyWith(attemptsLeft: left);
      return (
        value: null,
        error: MockResponse.error(
          422,
          'otp_invalid',
          'Code incorrect',
          details: {'attemptsLeft': left},
        ),
      );
    }
    _emailChallenges.remove(challengeId);
    return (value: challenge, error: null);
  }

  // --- Jetons -----------------------------------------------------------

  Map<String, dynamic> _issueSession(
    _Account account, {
    String? family,
    String? deviceLabel,
  }) {
    final now = DateTime.now();
    final fam = family ?? 'fam_${_random.nextInt(1 << 32)}';
    // Une session par famille : a la connexion elle nait, aux rotations elle
    // garde son instant de depart et son appareil.
    final existing = _sessions[fam];
    _sessions[fam] = _Session(
      accountId: account.id,
      deviceLabel: deviceLabel ?? existing?.deviceLabel,
      createdAt: existing?.createdAt ?? now,
    );

    Map<String, dynamic> withFamily(String type, Duration ttl) =>
        account.claims(type, now.add(ttl))..['fam'] = fam;

    return {
      'accessToken': _encode(withFamily('access', accessTtl)),
      'refreshToken': _encode(withFamily('refresh', refreshTtl)),
      'accessExpiresAt': now.add(accessTtl).toUtc().toIso8601String(),
      'refreshExpiresAt': now.add(refreshTtl).toUtc().toIso8601String(),
    };
  }

  /// Libelle d'appareil transmis par l'en-tete `X-Device`, s'il existe.
  String? _deviceOf(MockRequest req) => req.headers['x-device'];

  // --- GET /auth/sessions -----------------------------------------------

  Future<MockResponse> _listSessions(
    MockRequest req,
    Map<String, String> _,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final currentFam = _decode(req.bearer)?['fam'] as String?;
    final mine = _sessions.entries.where((e) => e.value.accountId == account.id);
    return MockResponse.ok([
      for (final entry in mine)
        {
          'id': entry.key,
          'deviceLabel': entry.value.deviceLabel,
          'createdAt': entry.value.createdAt.toUtc().toIso8601String(),
          'current': entry.key == currentFam,
        },
    ]);
  }

  // --- DELETE /auth/sessions/{family} -----------------------------------

  Future<MockResponse> _revokeSession(
    MockRequest req,
    Map<String, String> params,
  ) async {
    final account = _authenticate(req);
    if (account == null) {
      return MockResponse.error(401, 'unauthorized', 'Jeton absent ou invalide');
    }
    final family = params['family'];
    final session = _sessions[family];
    if (family == null || session == null || session.accountId != account.id) {
      return MockResponse.error(404, 'not_found', 'Session inconnue');
    }
    _sessions.remove(family);
    return MockResponse.noContent();
  }

  _Account? _authenticate(MockRequest req) {
    final claims = _decode(req.bearer);
    if (claims == null || claims['typ'] != 'access' || _isExpired(claims)) {
      return null;
    }
    return _Account.fromClaims(claims);
  }

  bool _isExpired(Map<String, dynamic> claims) {
    final exp = DateTime.tryParse('${claims['exp']}');
    return exp == null || DateTime.now().isAfter(exp);
  }

  String _encode(Map<String, dynamic> claims) =>
      base64Url.encode(utf8.encode(jsonEncode(claims)));

  Map<String, dynamic>? _decode(String? token) {
    if (token == null || token.isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(base64Url.decode(token)))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}

class _Session {
  const _Session({
    required this.accountId,
    required this.deviceLabel,
    required this.createdAt,
  });

  final String accountId;
  final String? deviceLabel;
  final DateTime createdAt;
}

class _Challenge {
  const _Challenge({
    required this.phone,
    required this.code,
    required this.expiresAt,
    required this.attemptsLeft,
  });

  final String phone;
  final String code;
  final DateTime expiresAt;
  final int attemptsLeft;

  _Challenge copyWith({int? attemptsLeft}) => _Challenge(
    phone: phone,
    code: code,
    expiresAt: expiresAt,
    attemptsLeft: attemptsLeft ?? this.attemptsLeft,
  );
}

class _EmailChallenge {
  const _EmailChallenge({
    required this.email,
    required this.code,
    required this.expiresAt,
    required this.attemptsLeft,
  });

  final String email;
  final String code;
  final DateTime expiresAt;
  final int attemptsLeft;

  _EmailChallenge copyWith({int? attemptsLeft}) => _EmailChallenge(
    email: email,
    code: code,
    expiresAt: expiresAt,
    attemptsLeft: attemptsLeft ?? this.attemptsLeft,
  );
}

class _Account {
  const _Account({
    required this.id,
    required this.phone,
    required this.role,
    required this.name,
    required this.createdAt,
    this.firstName,
    this.lastName,
    this.email,
    this.kycStatus,
    this.avatarUrl,
  });

  factory _Account.fromClaims(Map<String, dynamic> claims) => _Account(
    id: '${claims['sub']}',
    phone: '${claims['phone']}',
    role: claims['role'] as String?,
    name: '${claims['name'] ?? ''}',
    createdAt: DateTime.tryParse('') ?? DateTime.now(),
    firstName: claims['first'] as String?,
    lastName: claims['last'] as String?,
    email: claims['email'] as String?,
    kycStatus: claims['kyc'] as String?,
    avatarUrl: claims['avatar'] as String?,
  );

  final String id;
  final String phone;
  final String? role;
  final String name;
  final DateTime createdAt;
  final String? firstName;
  final String? lastName;
  final String? email;
  final String? kycStatus;
  final String? avatarUrl;

  /// Sentinelle : distingue « ne touche pas ce champ » de « efface-le » (null),
  /// pour les champs facultatifs qui peuvent legitimement redevenir absents.
  static const Object _keep = Object();

  _Account copyWith({
    String? role,
    String? name,
    String? kycStatus,
    String? phone,
    Object? firstName = _keep,
    Object? lastName = _keep,
    Object? email = _keep,
    Object? avatarUrl = _keep,
  }) => _Account(
    id: id,
    phone: phone ?? this.phone,
    role: role ?? this.role,
    name: name ?? this.name,
    createdAt: createdAt,
    firstName: identical(firstName, _keep)
        ? this.firstName
        : firstName as String?,
    lastName: identical(lastName, _keep) ? this.lastName : lastName as String?,
    email: identical(email, _keep) ? this.email : email as String?,
    kycStatus: kycStatus ?? this.kycStatus,
    avatarUrl: identical(avatarUrl, _keep)
        ? this.avatarUrl
        : avatarUrl as String?,
  );

  Map<String, dynamic> claims(String type, DateTime expiresAt) => {
    'typ': type,
    'sub': id,
    'phone': phone,
    'role': role,
    'name': name,
    'first': firstName,
    'last': lastName,
    'email': email,
    'kyc': kycStatus,
    'avatar': avatarUrl,
    'iat': createdAt.toUtc().toIso8601String(),
    'exp': expiresAt.toUtc().toIso8601String(),
  };

  Map<String, dynamic> toJson() => {
    'id': id,
    'phone': phone,
    'role': role,
    'firstName': firstName,
    'lastName': lastName,
    'displayName': name,
    'email': email,
    'avatarUrl': avatarUrl,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'kycStatus': kycStatus,
    'rating': role == 'driver' ? 4.6 : null,
  };
}
