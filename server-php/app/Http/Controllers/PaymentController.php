<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Delivery;
use App\Models\MajiPaySandboxAccount;
use App\Models\MajiPaySandboxTxn;
use App\Models\Payment;
use App\Support\CurrentAccount;
use App\Support\Security;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class PaymentController extends Controller
{
    private const INTENT_MINUTES = 5;

    public function balance(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $wallet = $this->wallet($account);

        return response()->json([
            'available' => $wallet->balance_ariary,
            'accountRef' => $wallet->account_ref,
            'fetchedAt' => Carbon::now()->toIso8601String(),
        ]);
    }

    public function history(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $limit = max(1, min((int) $request->query('limit', 50), 100));
        $items = Payment::where(function ($query) use ($account): void {
            $query->where('payer_id', $account->id)->orWhere('payee_id', $account->id);
        })->latest('created_at')->limit($limit)->get()->map(function (Payment $payment) use ($account): array {
            $payload = $payment->payload();
            $payload['role'] = (string) $payment->payer_id === (string) $account->id ? 'payer' : 'payee';

            return $payload;
        })->all();

        return response()->json(['items' => $items]);
    }

    public function createIntent(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $direction = in_array($request->input('direction', 'collect'), ['collect', 'offer'], true)
            ? $request->input('direction', 'collect') : 'collect';
        $delivery = Delivery::find($request->input('deliveryId'));
        if ($delivery === null) {
            throw ApiException::notFound('Course inconnue');
        }
        if ($delivery->driver_id === null) {
            throw ApiException::unprocessable('no_driver', 'Aucun livreur assigne a cette course');
        }
        if (! in_array((string) $account->id, [(string) $delivery->client_id, (string) $delivery->driver_id], true)) {
            throw ApiException::forbidden('not_a_party', 'Course etrangere au compte');
        }
        $presenter = $direction === 'collect' ? $delivery->driver_id : $delivery->client_id;
        if ((string) $account->id !== (string) $presenter) {
            throw ApiException::forbidden('wrong_presenter', "Ce n'est pas a ce compte de presenter le code");
        }
        if (in_array($delivery->status, ['cancelled', 'pending'], true)) {
            throw ApiException::conflict('illegal_transition', 'Cette course ne se paie pas dans son etat actuel');
        }
        // Une course se regle une fois. Une seconde intention, apres un
        // paiement MajiPay ou en especes, serait un double encaissement.
        if (Payment::where('delivery_id', $delivery->id)->whereIn('status', ['captured', 'cash'])->exists()) {
            throw ApiException::conflict('already_paid', 'Cette course est deja reglee');
        }

        // Le montant est le prix fixe de la course, calcule par le serveur a
        // la commande : ni le livreur ni le client ne le choisissent ici. Une
        // course ancienne sans prix garde le montant saisi.
        $amount = $delivery->price_ariary !== null
            ? (int) $delivery->price_ariary
            : (int) $request->input('amount');
        if ($amount <= 0) {
            throw ApiException::unprocessable('invalid_amount', 'Montant invalide');
        }
        if ($direction === 'offer' && $this->wallet(Account::find($delivery->client_id))->balance_ariary < $amount) {
            throw ApiException::unprocessable('insufficient_funds', 'Solde MajiPay insuffisant', ['failure' => 'insufficient_funds']);
        }

        $token = Security::newOpaqueToken();
        $payment = Payment::create([
            'delivery_id' => $delivery->id,
            'payer_id' => $delivery->client_id,
            'payee_id' => $delivery->driver_id,
            'amount_ariary' => $amount,
            'direction' => $direction,
            'status' => 'pending',
            'token_hash' => Security::hashSecret($token),
            'failure' => 'none',
            'created_at' => Carbon::now(),
            'expires_at' => Carbon::now()->addMinutes(self::INTENT_MINUTES),
        ]);

        return response()->json([...$payment->payload(), 'token' => $token], 201);
    }

    public function show(Request $request, string $paymentId)
    {
        $account = CurrentAccount::resolve($request);
        $payment = $this->paymentFor($paymentId, $account);
        $this->expire($payment);

        return response()->json($payment->fresh()->payload());
    }

    public function claim(Request $request, string $paymentId)
    {
        $account = CurrentAccount::resolve($request);
        $payment = $this->paymentFor($paymentId, $account);
        if (! Security::verifySecret($payment->token_hash, (string) $request->input('token'))) {
            throw ApiException::forbidden('bad_token', 'Code invalide');
        }
        if ($this->expire($payment)) {
            throw ApiException::unprocessable('expired', 'Code expire', ['failure' => 'expired']);
        }
        if ($payment->isFinal()) {
            return response()->json($payment->payload());
        }
        $payment->forceFill(['status' => 'claimed'])->save();
        if ($payment->direction === 'offer') {
            return $this->settle($payment);
        }

        return response()->json($payment->fresh()->payload());
    }

    public function confirm(Request $request, string $paymentId)
    {
        $account = CurrentAccount::resolve($request);
        $payment = $this->paymentFor($paymentId, $account);
        if ((string) $account->id !== (string) $payment->payer_id) {
            throw ApiException::forbidden('not_payer', 'Seul le payeur peut confirmer');
        }
        if ($this->expire($payment)) {
            throw ApiException::unprocessable('expired', 'Code expire', ['failure' => 'expired']);
        }

        return $this->settle($payment);
    }

    public function cash(Request $request, string $paymentId)
    {
        $account = CurrentAccount::resolve($request);
        $payment = $this->paymentFor($paymentId, $account);
        if ($payment->status === 'captured') {
            throw ApiException::conflict('already_captured', 'Deja regle par MajiPay', ['currentState' => 'captured']);
        }
        if ($payment->status === 'cash') {
            return response()->json($payment->payload());
        }
        $payment->forceFill([
            'status' => 'cash',
            'captured_at' => Carbon::now(),
            'receipt_ref' => 'ESP-'.$payment->id,
        ])->save();

        return response()->json($payment->fresh()->payload());
    }

    public function withdraw(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($account->role !== 'driver') {
            throw ApiException::forbidden('role_forbidden', 'Seul un livreur peut retirer ses gains');
        }
        $amount = (int) $request->input('amount');
        if ($amount <= 0) {
            throw ApiException::unprocessable('invalid_amount', 'Montant de retrait invalide');
        }
        $wallet = $this->wallet($account);
        // Debit conditionnel en une seule ecriture : deux retraits simultanes
        // ne peuvent pas passer tous les deux sur le meme solde.
        $debited = MajiPaySandboxAccount::where('account_id', $account->id)
            ->where('balance_ariary', '>=', $amount)
            ->decrement('balance_ariary', $amount);
        if ($debited !== 1) {
            throw ApiException::unprocessable('insufficient_funds', 'Solde MajiPay insuffisant', ['failure' => 'insufficient_funds']);
        }

        return response()->json([
            'receiptRef' => 'WD-'.substr(sha1((string) microtime(true)), -12),
            'amount' => $amount,
            'available' => $wallet->fresh()->balance_ariary,
            'accountRef' => $wallet->account_ref,
            'withdrawnAt' => Carbon::now()->toIso8601String(),
        ]);
    }

    private function paymentFor(string $id, Account $account): Payment
    {
        $payment = Payment::find($id);
        if ($payment === null) {
            throw ApiException::notFound('Intention inconnue');
        }
        if (! in_array((string) $account->id, [(string) $payment->payer_id, (string) $payment->payee_id], true)) {
            throw ApiException::forbidden('not_a_party', 'Intention etrangere au compte');
        }

        return $payment;
    }

    private function expire(Payment $payment): bool
    {
        if ($payment->isFinal() || ! $payment->expired()) {
            return false;
        }
        $payment->forceFill(['status' => 'failed', 'failure' => 'expired'])->save();

        return true;
    }

    /**
     * Regle une intention, une fois et une seule.
     *
     * Tout se joue sous verrou : l'intention est relue verrouillee, et le
     * debit du payeur n'aboutit que si son solde suffit au moment precis de
     * l'ecriture. Rejouer « confirmer » (double appui, file hors ligne,
     * reseau qui repete) rend le recu deja emis au lieu de debiter a nouveau.
     */
    private function settle(Payment $payment)
    {
        $this->wallet(Account::find($payment->payer_id));
        $this->wallet(Account::find($payment->payee_id));

        $outcome = DB::transaction(function () use ($payment): string {
            $locked = Payment::whereKey($payment->getKey())->lockForUpdate()->first();
            if ($locked->status === 'captured' || $locked->status === 'cash') {
                return 'final';
            }
            if ($locked->isFinal()) {
                return 'closed';
            }
            $debited = MajiPaySandboxAccount::where('account_id', $locked->payer_id)
                ->where('balance_ariary', '>=', $locked->amount_ariary)
                ->decrement('balance_ariary', $locked->amount_ariary);
            if ($debited !== 1) {
                $locked->forceFill(['status' => 'failed', 'failure' => 'insufficient_funds'])->save();

                return 'insufficient';
            }
            MajiPaySandboxAccount::where('account_id', $locked->payee_id)
                ->increment('balance_ariary', $locked->amount_ariary);
            $locked->forceFill([
                'status' => 'captured',
                'captured_at' => Carbon::now(),
                'receipt_ref' => 'MP-'.$locked->id,
            ])->save();
            MajiPaySandboxTxn::firstOrCreate(
                ['idem_key' => 'settle_'.$locked->id],
                ['receipt_ref' => 'MP-'.$locked->id, 'created_at' => Carbon::now()],
            );

            return 'captured';
        });

        if ($outcome === 'insufficient') {
            throw ApiException::unprocessable('insufficient_funds', 'Solde MajiPay insuffisant', ['failure' => 'insufficient_funds']);
        }
        if ($outcome === 'closed') {
            throw ApiException::conflict('illegal_transition', 'Intention close', ['currentState' => $payment->fresh()->status]);
        }

        return response()->json($payment->fresh()->payload());
    }

    private function wallet(Account $account): MajiPaySandboxAccount
    {
        // Bac a sable MajiPay : soldes de demonstration en developpement
        // seulement. En production, personne ne recoit d'argent fictif ; un
        // reglement sans solde echoue proprement et bascule en especes.
        $seed = config('majichrono.majipay_sandbox')
            ? ($account->role === 'driver' ? 18500 : 42000)
            : 0;

        return MajiPaySandboxAccount::firstOrCreate(
            ['account_id' => $account->id],
            ['balance_ariary' => $seed, 'account_ref' => 'MP ** ** '.substr((string) $account->phone, -4)]
        );
    }
}
