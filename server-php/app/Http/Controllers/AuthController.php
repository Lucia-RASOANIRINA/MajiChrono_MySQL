<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Challenge;
use App\Models\RefreshToken;
use App\Support\CurrentAccount;
use App\Support\MailSender;
use App\Support\Security;
use App\Support\SmsSender;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Port de server/app/routers/auth.py. Une regle gouverne tout ce fichier,
 * inchangee par rapport a FastAPI : le numero et l'e-mail sont deux portes
 * d'entree symetriques et facultatives vers le meme compte (voir
 * app/Models/Account.php et le commentaire au sommet du modele).
 */
class AuthController extends Controller
{
    private const PHONE_PATTERN = '/^\+261(32|33|34|37|38|39|20)\d{7}$/';

    private const EMAIL_PATTERN = '/^[^@\s]+@[^@\s.]+\.[^@\s]+$/';

    // --- Telephone -----------------------------------------------------

    public function requestOtp(Request $request)
    {
        $phone = (string) $request->input('phone');
        if (! preg_match(self::PHONE_PATTERN, $phone)) {
            throw ApiException::unprocessable('invalid_phone', 'Numero de telephone malgache invalide', [
                'fields' => ['phone' => 'format_invalide'],
            ]);
        }

        [$challenge, $code] = $this->openChallenge('sms', $phone);

        try {
            SmsSender::sendLoginCode($phone, $code);
        } catch (Throwable $e) {
            $challenge->consumed_at = Carbon::now();
            $challenge->save();

            throw ApiException::badGateway('sms_delivery_failed', 'Impossible d\'envoyer le SMS pour le moment');
        }

        return response()->json($this->challengeResponse($challenge, $code));
    }

    public function verifyOtp(Request $request)
    {
        $challenge = $this->consumeChallenge((string) $request->input('challengeId'), (string) $request->input('code'));

        $account = Account::where('phone', $challenge->destination)->first();
        if ($account === null) {
            // Premiere venue : le compte nait ici, sans profil detaille. Le
            // profil se pose ensuite par PATCH /me. `email` reste absent :
            // colonne NOT NULL sans defaut, MySQL la coerce en '' en mode
            // non strict (voir config/database.php) -- toMobileJson()
            // renvoie alors null au mobile, comme le ferait FastAPI.
            $account = Account::create([
                'phone' => $challenge->destination,
                'full_name' => '',
                'password_hash' => '',
                'phone_verified_at' => Carbon::now(),
            ]);
        } else {
            $account->phone_verified_at = Carbon::now();
            $account->save();
        }

        return response()->json([
            'session' => $this->issueSession($account, deviceLabel: $request->header('X-Device')),
            'account' => $account->toMobileJson(),
        ]);
    }

    public function phoneLogin(Request $request)
    {
        $phone = (string) $request->input('phone');
        if (! preg_match(self::PHONE_PATTERN, $phone)) {
            throw ApiException::unprocessable('invalid_phone', 'Numero de telephone malgache invalide');
        }

        $account = Account::where('phone', $phone)->first();
        if ($account !== null && filled($account->password_hash)) {
            $password = $request->input('password');
            if (! $password) {
                throw ApiException::conflict('password_required', 'Ce compte utilise un mot de passe');
            }
            if (! Security::verifySecret($account->password_hash, $password)) {
                throw ApiException::unauthorized('Numero de telephone ou mot de passe incorrect');
            }

            return response()->json([
                'linked' => true,
                'session' => $this->issueSession($account, deviceLabel: $request->header('X-Device')),
                'account' => $account->toMobileJson(),
            ]);
        }

        [$challenge, $code] = $this->openChallenge('sms', $phone);
        try {
            SmsSender::sendLoginCode($phone, $code);
        } catch (Throwable $e) {
            $challenge->consumed_at = Carbon::now();
            $challenge->save();

            throw ApiException::badGateway('sms_delivery_failed', 'Impossible d\'envoyer le SMS pour le moment');
        }

        return response()->json($this->challengeResponse($challenge, $code));
    }

    // --- Adresse e-mail --------------------------------------------------

    public function requestEmailCode(Request $request)
    {
        $email = mb_strtolower(trim((string) $request->input('email')));
        if (! preg_match(self::EMAIL_PATTERN, $email)) {
            throw ApiException::unprocessable('invalid_email', 'Adresse e-mail invalide', [
                'fields' => ['email' => 'format_invalide'],
            ]);
        }

        [$challenge, $code] = $this->openChallenge('email', $email);

        try {
            MailSender::sendLoginCode($email, $code);
        } catch (Throwable $e) {
            if (config('app.env') === 'local') {
                Log::warning('AUCUN ENVOI E-MAIL en dev — code disponible via debugCode.');
            } else {
                $challenge->consumed_at = Carbon::now();
                $challenge->save();

                throw ApiException::badGateway('mail_delivery_failed', 'Impossible d\'envoyer le code pour le moment');
            }
        }

        // La reponse ne dit jamais si l'adresse est connue : le savoir avant
        // la preuve de possession permettrait d'enumerer les comptes.
        return response()->json($this->challengeResponse($challenge, $code, email: $email));
    }

    public function verifyEmailCode(Request $request)
    {
        $challenge = $this->consumeChallenge((string) $request->input('challengeId'), (string) $request->input('code'));

        return response()->json($this->sessionForEmail($challenge->destination, $request->header('X-Device')));
    }

    /**
     * Cree un compte a partir d'un defi e-mail deja prouve, sans numero —
     * pendant du bord "compte inconnu" de verifyEmailCode. Reutilise le meme
     * defi (deja consomme par verifyEmailCode) : pas de nouveau code envoye.
     */
    public function registerWithEmail(Request $request)
    {
        $challengeId = (string) $request->input('challengeId');
        $challenge = Challenge::find($challengeId);

        if ($challenge === null || $challenge->channel !== 'email' || $challenge->consumed_at === null) {
            throw ApiException::unprocessable('unknown_challenge', 'Defi inconnu ou non prouve');
        }

        $ttlMinutes = (int) config('majichrono.otp_ttl_minutes');
        if ($challenge->consumed_at->diffInMinutes(Carbon::now()) > $ttlMinutes) {
            throw ApiException::unprocessable('challenge_expired', 'Preuve trop ancienne');
        }

        $email = $challenge->destination;
        if (Account::where('email', $email)->exists()) {
            throw ApiException::conflict('email_already_registered', 'Un compte existe deja pour cette adresse');
        }

        $account = Account::create([
            'email' => $email,
            'full_name' => '',
            'password_hash' => $this->pendingPasswordHash($email),
            'email_verified_at' => Carbon::now(),
        ]);

        return response()->json([
            'session' => $this->issueSession($account, deviceLabel: $request->header('X-Device')),
            'account' => $account->toMobileJson(),
        ]);
    }

    public function linkEmail(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $email = mb_strtolower(trim((string) $request->input('email')));
        if (! preg_match(self::EMAIL_PATTERN, $email)) {
            throw ApiException::unprocessable('invalid_email', 'Adresse e-mail invalide');
        }

        $taken = Account::where('email', $email)->first();
        if ($taken !== null && $taken->id !== $account->id) {
            throw ApiException::conflict('email_already_linked', 'Cette adresse est deja rattachee a un autre compte');
        }

        $account->email = $email;
        $account->email_verified_at = Carbon::now();
        $account->save();

        return response()->noContent();
    }

    public function signInWithPassword(Request $request)
    {
        $email = mb_strtolower(trim((string) $request->input('email')));
        $password = (string) $request->input('password');
        $account = Account::where('email', $email)->first();

        if ($account === null || ! Security::verifySecret($account->password_hash, $password)) {
            throw ApiException::unauthorized('E-mail ou mot de passe incorrect');
        }

        return response()->json([
            'linked' => true,
            'session' => $this->issueSession($account, deviceLabel: $request->header('X-Device')),
            'account' => $account->toMobileJson(),
        ]);
    }

    public function signUpWithPassword(Request $request)
    {
        $email = mb_strtolower(trim((string) $request->input('email')));
        $password = (string) $request->input('password');
        if (! preg_match(self::EMAIL_PATTERN, $email)) {
            throw ApiException::unprocessable('invalid_email', 'Adresse e-mail invalide');
        }
        if (mb_strlen($password) < 8) {
            throw ApiException::unprocessable('weak_password', 'Mot de passe trop court', [
                'minLength' => 8,
            ]);
        }
        if (Account::where('email', $email)->exists()) {
            throw ApiException::conflict('email_taken', 'Cette adresse a deja un compte');
        }

        $challenge = Challenge::create([
            'channel' => 'email',
            'destination' => $email,
            'code_hash' => Security::hashSecret($password),
            'attempts_left' => 0,
            'expires_at' => Carbon::now()->addHour(),
            'consumed_at' => Carbon::now(),
        ]);

        return response()->json(['linked' => false, 'email' => $email]);
    }

    public function changePassword(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $newPassword = (string) $request->input('newPassword');
        if (mb_strlen($newPassword) < 8) {
            throw ApiException::unprocessable('weak_password', 'Mot de passe trop court', [
                'minLength' => 8,
            ]);
        }
        if (filled($account->password_hash)
            && ! Security::verifySecret($account->password_hash, (string) $request->input('currentPassword'))) {
            throw ApiException::forbidden('wrong_current_password', 'Mot de passe actuel incorrect');
        }

        $account->password_hash = Security::hashSecret($newPassword);
        $account->save();

        return response()->noContent();
    }

    public function resetPassword(Request $request)
    {
        $newPassword = (string) $request->input('newPassword');
        if (mb_strlen($newPassword) < 8) {
            throw ApiException::unprocessable('weak_password', 'Mot de passe trop court', [
                'minLength' => 8,
            ]);
        }

        $challenge = $this->consumeChallenge((string) $request->input('challengeId'), (string) $request->input('code'));
        if ($challenge->channel !== 'email') {
            throw ApiException::unprocessable('wrong_channel', 'Ce code ne vaut pas pour un mot de passe');
        }

        $account = Account::where('email', $challenge->destination)->first();
        if ($account !== null) {
            $account->password_hash = Security::hashSecret($newPassword);
            $account->save();
        }

        return response()->noContent();
    }

    public function requestEmailChange(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $email = mb_strtolower(trim((string) $request->input('email')));
        if (! preg_match(self::EMAIL_PATTERN, $email)) {
            throw ApiException::unprocessable('invalid_email', 'Adresse e-mail invalide');
        }
        $taken = Account::where('email', $email)->first();
        if ($taken !== null && $taken->id !== $account->id) {
            throw ApiException::conflict('email_taken', 'Cette adresse est deja rattachee a un autre compte');
        }

        [$challenge, $code] = $this->openChallenge('email', $email);
        try {
            MailSender::sendLoginCode($email, $code);
        } catch (Throwable $e) {
            $challenge->consumed_at = Carbon::now();
            $challenge->save();
            throw ApiException::badGateway('mail_delivery_failed', 'Impossible d\'envoyer le code pour le moment');
        }

        return response()->json($this->challengeResponse($challenge, $code, email: $email));
    }

    public function verifyEmailChange(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $challenge = $this->consumeChallenge((string) $request->input('challengeId'), (string) $request->input('code'));
        if ($challenge->channel !== 'email') {
            throw ApiException::unprocessable('wrong_channel', 'Ce code ne vaut pas pour un e-mail');
        }
        $taken = Account::where('email', $challenge->destination)->first();
        if ($taken !== null && $taken->id !== $account->id) {
            throw ApiException::conflict('email_taken', 'Cette adresse est deja rattachee a un autre compte');
        }
        $account->email = $challenge->destination;
        $account->email_verified_at = Carbon::now();
        $account->save();

        return response()->json($account->toMobileJson());
    }

    public function requestPhoneChange(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $phone = (string) $request->input('phone');
        if (! preg_match(self::PHONE_PATTERN, $phone)) {
            throw ApiException::unprocessable('invalid_phone', 'Numero de telephone malgache invalide');
        }
        $taken = Account::where('phone', $phone)->first();
        if ($taken !== null && $taken->id !== $account->id) {
            throw ApiException::conflict('phone_taken', 'Ce numero est deja utilise par un autre compte');
        }

        [$challenge, $code] = $this->openChallenge('sms', $phone);
        try {
            SmsSender::sendLoginCode($phone, $code);
        } catch (Throwable $e) {
            $challenge->consumed_at = Carbon::now();
            $challenge->save();
            throw ApiException::badGateway('sms_delivery_failed', 'Impossible d\'envoyer le SMS pour le moment');
        }

        return response()->json($this->challengeResponse($challenge, $code));
    }

    public function verifyPhoneChange(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $challenge = $this->consumeChallenge((string) $request->input('challengeId'), (string) $request->input('code'));
        if ($challenge->channel !== 'sms') {
            throw ApiException::unprocessable('wrong_channel', 'Ce code ne vaut pas pour un numero');
        }
        $taken = Account::where('phone', $challenge->destination)->first();
        if ($taken !== null && $taken->id !== $account->id) {
            throw ApiException::conflict('phone_taken', 'Ce numero est deja utilise par un autre compte');
        }
        $account->phone = $challenge->destination;
        $account->phone_verified_at = Carbon::now();
        $account->save();

        return response()->json($account->toMobileJson());
    }

    public function sessions(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $claims = Security::readAccessToken(trim(substr((string) $request->header('Authorization'), 7)));
        $currentFamily = $claims['fam'] ?? null;
        $tokens = RefreshToken::where('account_id', $account->id)
            ->whereNull('revoked_at')
            ->where('expires_at', '>', Carbon::now())
            ->orderBy('created_at')
            ->get()
            ->groupBy('family');

        return response()->json($tokens->map(function ($familyTokens, $family) use ($currentFamily) {
            $token = $familyTokens->first();

            return [
                'id' => $family,
                'deviceLabel' => $token->device_label,
                'createdAt' => $token->created_at->toIso8601String(),
                'current' => $family === $currentFamily,
            ];
        })->values());
    }

    public function revokeSession(Request $request, string $family)
    {
        $account = CurrentAccount::resolve($request);
        $tokens = RefreshToken::where('account_id', $account->id)->where('family', $family)->get();
        if ($tokens->isEmpty()) {
            throw ApiException::notFound('Session inconnue');
        }
        RefreshToken::where('account_id', $account->id)->where('family', $family)->update([
            'revoked_at' => Carbon::now(),
        ]);

        return response()->noContent();
    }

    // --- Sessions ----------------------------------------------------------

    public function refresh(Request $request)
    {
        $refreshToken = (string) $request->input('refreshToken');
        $now = Carbon::now();

        $candidates = RefreshToken::where('expires_at', '>', $now)->get();
        $stored = $candidates->first(fn (RefreshToken $t) => Security::verifySecret($t->token_hash, $refreshToken));

        if ($stored === null) {
            throw ApiException::unauthorized('Jeton de rafraichissement invalide');
        }

        if ($stored->revoked_at !== null) {
            // Jeton deja tourne, presente a nouveau : rejeu d'un jeton vole.
            // Toute la famille tombe -- deconnecte l'attaquant et le porteur
            // legitime, c'est voulu.
            RefreshToken::where('family', $stored->family)->update(['revoked_at' => $now]);

            throw ApiException::unauthorized('Session revoquee');
        }

        $stored->revoked_at = $now;
        $stored->save();

        $account = Account::findOrFail($stored->account_id);

        return response()->json([
            'session' => $this->issueSession($account, family: $stored->family, deviceLabel: $stored->device_label),
        ]);
    }

    public function logout(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        RefreshToken::where('account_id', $account->id)->whereNull('revoked_at')->update([
            'revoked_at' => Carbon::now(),
        ]);

        return response()->noContent();
    }

    // --- Aides internes ------------------------------------------------

    private function openChallenge(string $channel, string $destination): array
    {
        $code = Security::newNumericCode();
        $challenge = Challenge::create([
            'channel' => $channel,
            'destination' => $destination,
            'code_hash' => Security::hashSecret($code),
            'attempts_left' => config('majichrono.otp_max_attempts'),
            'expires_at' => Carbon::now()->addMinutes((int) config('majichrono.otp_ttl_minutes')),
        ]);

        return [$challenge, $code];
    }

    private function pendingPasswordHash(string $email): string
    {
        return (string) (Challenge::query()
            ->where('channel', 'email')
            ->where('destination', $email)
            ->where('attempts_left', 0)
            ->whereNotNull('consumed_at')
            ->where('expires_at', '>', Carbon::now())
            ->latest('created_at')
            ->value('code_hash') ?? '');
    }

    private function consumeChallenge(string $challengeId, string $code): Challenge
    {
        $challenge = Challenge::find($challengeId);
        if ($challenge === null || ! $challenge->isUsable()) {
            throw ApiException::unprocessable('unknown_challenge', 'Defi inconnu ou deja utilise');
        }

        if (! Security::verifySecret($challenge->code_hash, $code)) {
            $challenge->attempts_left -= 1;
            if ($challenge->attempts_left <= 0) {
                $challenge->consumed_at = Carbon::now();
                $challenge->save();
                throw ApiException::unprocessable('otp_locked', 'Trop de tentatives');
            }
            $challenge->save();
            throw ApiException::unprocessable('otp_invalid', 'Code incorrect', ['attemptsLeft' => $challenge->attempts_left]);
        }

        $challenge->consumed_at = Carbon::now();
        $challenge->save();

        return $challenge;
    }

    private function sessionForEmail(string $email, ?string $deviceLabel): array
    {
        $account = Account::where('email', $email)->first();
        if ($account === null) {
            // Adresse prouvee, compte inconnu : le mobile choisit alors
            // registerWithEmail (nouveau compte) ou de rattacher un numero
            // existant.
            return ['linked' => false, 'email' => $email];
        }

        if ($account->email_verified_at === null) {
            $account->email_verified_at = Carbon::now();
            $account->save();
        }

        return [
            'linked' => true,
            'session' => $this->issueSession($account, deviceLabel: $deviceLabel),
            'account' => $account->toMobileJson(),
        ];
    }

    private function issueSession(Account $account, ?string $family = null, ?string $deviceLabel = null): array
    {
        $fam = $family ?? substr(Security::newOpaqueToken(), 0, 32);
        [$access, $accessExpires] = Security::issueAccessToken((string) $account->id, $account->role, $fam);

        $refresh = Security::newOpaqueToken();
        $refreshExpires = Carbon::now()->addDays((int) config('majichrono.refresh_ttl_days'));

        RefreshToken::create([
            'account_id' => (string) $account->id,
            'token_hash' => Security::hashSecret($refresh),
            'family' => $fam,
            'device_label' => $deviceLabel,
            'expires_at' => $refreshExpires,
        ]);

        return [
            'accessToken' => $access,
            'refreshToken' => $refresh,
            'accessExpiresAt' => $accessExpires->toIso8601String(),
            'refreshExpiresAt' => $refreshExpires->toIso8601String(),
        ];
    }

    private function challengeResponse(Challenge $challenge, string $code, ?string $email = null): array
    {
        $body = [
            'challengeId' => $challenge->id,
            'expiresAt' => $challenge->expires_at->toIso8601String(),
            'attemptsLeft' => $challenge->attempts_left,
        ];
        if ($email !== null) {
            $body['email'] = $email;
        }
        if (config('majichrono.otp_debug_codes')) {
            $body['debugCode'] = $code;
        }

        return $body;
    }
}
