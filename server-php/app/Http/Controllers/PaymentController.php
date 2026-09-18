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
        $amount = (int) $request->input('amount');
        if ($amount <= 0) {
            throw ApiException::unprocessable('invalid_amount', 'Montant invalide');
        }
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
        if ($wallet->balance_ariary < $amount) {
            throw ApiException::unprocessable('insufficient_funds', 'Solde MajiPay insuffisant', ['failure' => 'insufficient_funds']);
        }
        $wallet->decrement('balance_ariary', $amount);

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

    private function settle(Payment $payment)
    {
        $payer = $this->wallet(Account::find($payment->payer_id));
        $payee = $this->wallet(Account::find($payment->payee_id));
        if ($payer->balance_ariary < $payment->amount_ariary) {
            $payment->forceFill(['status' => 'failed', 'failure' => 'insufficient_funds'])->save();
            throw ApiException::unprocessable('insufficient_funds', 'Solde MajiPay insuffisant', ['failure' => 'insufficient_funds']);
        }
        DB::transaction(function () use ($payment, $payer, $payee): void {
            $payer->decrement('balance_ariary', $payment->amount_ariary);
            $payee->increment('balance_ariary', $payment->amount_ariary);
            $payment->forceFill([
                'status' => 'captured',
                'captured_at' => Carbon::now(),
                'receipt_ref' => 'MP-'.$payment->id,
            ])->save();
            MajiPaySandboxTxn::firstOrCreate(
                ['idem_key' => 'settle_'.$payment->id],
                ['receipt_ref' => 'MP-'.$payment->id, 'created_at' => Carbon::now()],
            );
        });

        return response()->json($payment->fresh()->payload());
    }

    private function wallet(Account $account): MajiPaySandboxAccount
    {
        $seed = $account->role === 'driver' ? 18500 : 42000;

        return MajiPaySandboxAccount::firstOrCreate(
            ['account_id' => $account->id],
            ['balance_ariary' => $seed, 'account_ref' => 'MP ** ** '.substr((string) $account->phone, -4)]
        );
    }
}
