<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\Delivery;
use App\Models\Dispute;
use App\Models\DisputeMessage;
use App\Models\IdempotencyRecord;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class DisputeController extends Controller
{
    private const MIN_REASON_LENGTH = 10;

    public function store(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($replay = $this->replay($request, $account, 'POST /disputes')) {
            return $replay;
        }
        $delivery = Delivery::find($request->input('deliveryId'));
        if ($delivery === null || ! $this->isParty($delivery, $account)) {
            throw ApiException::notFound('Course inconnue');
        }

        $reason = trim((string) $request->input('reason', ''));
        if ($reason === '') {
            throw ApiException::unprocessable('reason_required', 'Motif obligatoire');
        }

        $dispute = Dispute::create([
            'delivery_id' => $delivery->id,
            'reason' => $reason,
            'opened_by' => $account->role,
        ]);

        $payload = $dispute->load('messages')->payload();
        $this->remember($request, $account, 'POST /disputes', 201, $payload);

        return response()->json($payload, 201);
    }

    public function index(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $query = Dispute::with('messages')->orderByDesc('opened_at');
        if ($request->query('status') !== null) {
            $query->where('status', $request->query('status'));
        }
        if (! $this->isAdmin($account)) {
            $deliveryIds = Delivery::where('client_id', $account->id)
                ->orWhere('driver_id', $account->id)->pluck('id');
            $query->whereIn('delivery_id', $deliveryIds);
        }

        return response()->json(['items' => $query->get()->map->payload()->values()->all()]);
    }

    public function show(Request $request, string $disputeId)
    {
        $dispute = $this->visible($request, $disputeId);

        return response()->json($dispute->load('messages')->payload());
    }

    public function message(Request $request, string $disputeId)
    {
        $account = CurrentAccount::resolve($request);
        $dispute = $this->visibleAccount($disputeId, $account);
        if ($dispute->isClosed()) {
            throw ApiException::conflict('dispute_closed', 'Litige clos', ['currentState' => $dispute->status]);
        }

        $body = trim((string) $request->input('body', ''));
        if ($body === '') {
            throw ApiException::unprocessable('empty_message', 'Message vide');
        }
        $isAdmin = $this->isAdmin($account);
        DisputeMessage::create([
            'dispute_id' => $dispute->id,
            'author_label' => $isAdmin ? 'Exploitation' : ($account->role === 'driver' ? 'Livreur' : 'Client'),
            'body' => $body,
            'from_operations' => $isAdmin,
        ]);
        if ($dispute->status === 'open') {
            $dispute->status = 'investigating';
            $dispute->save();
        }

        return response()->json($dispute->fresh()->load('messages')->payload());
    }

    public function decision(Request $request, string $disputeId)
    {
        $account = CurrentAccount::resolve($request);
        if (! $this->isAdmin($account)) {
            throw ApiException::forbidden('role_forbidden', "Seule l'exploitation tranche");
        }
        if ($replay = $this->replay($request, $account, 'POST /disputes/decision')) {
            return $replay;
        }
        $dispute = Dispute::find($disputeId);
        if ($dispute === null) {
            throw ApiException::notFound('Litige inconnu');
        }
        if ($dispute->isClosed()) {
            throw ApiException::conflict('already_decided', 'Litige deja tranche', ['currentState' => $dispute->status]);
        }

        if (! $request->has('resolve') || ! is_bool($request->input('resolve')) && ! in_array($request->input('resolve'), ['0', '1', 0, 1, 'true', 'false'], true)) {
            throw ApiException::unprocessable('invalid_request', 'Requete invalide');
        }
        $reason = trim((string) $request->input('reason', ''));
        if (mb_strlen($reason) < self::MIN_REASON_LENGTH) {
            throw ApiException::unprocessable('reason_required', 'Motif obligatoire');
        }
        $resolve = filter_var($request->input('resolve'), FILTER_VALIDATE_BOOLEAN);
        $dispute->fill([
            'status' => $resolve ? 'resolved' : 'rejected',
            'decision_action' => $resolve ? 'resolve_dispute' : 'reject_dispute',
            'decision_reason' => $reason,
            'decided_at' => Carbon::now(),
            'decided_by' => $account->id,
        ])->save();

        $payload = $dispute->fresh()->load('messages')->payload();
        $this->remember($request, $account, 'POST /disputes/decision', 200, $payload);

        return response()->json($payload);
    }

    private function visible(Request $request, string $id): Dispute
    {
        return $this->visibleAccount($id, CurrentAccount::resolve($request));
    }

    private function visibleAccount(string $id, Account $account): Dispute
    {
        $dispute = Dispute::with('messages')->find($id);
        $delivery = $dispute === null ? null : Delivery::find($dispute->delivery_id);
        if ($dispute === null || $delivery === null || (! $this->isAdmin($account) && ! $this->isParty($delivery, $account))) {
            throw ApiException::notFound('Litige inconnu');
        }

        return $dispute;
    }

    private function isParty(Delivery $delivery, Account $account): bool
    {
        return (string) $delivery->client_id === (string) $account->id
            || (string) $delivery->driver_id === (string) $account->id;
    }

    private function isAdmin(Account $account): bool
    {
        return in_array($account->role, ['admin', 'superadmin'], true);
    }

    private function replay(Request $request, Account $account, string $endpoint)
    {
        $key = $request->header('Idempotency-Key');
        if (! $key) {
            return null;
        }
        $record = IdempotencyRecord::find($key);
        if ($record === null) {
            return null;
        }
        if ($record->endpoint !== $endpoint) {
            throw ApiException::unprocessable('idempotency_key_reused', 'Cle deja utilisee ailleurs');
        }

        return response()->json(json_decode($record->response_json, true), (int) $record->status_code);
    }

    private function remember(Request $request, Account $account, string $endpoint, int $status, array $payload): void
    {
        $key = $request->header('Idempotency-Key');
        if ($key) {
            IdempotencyRecord::create([
                'key' => $key,
                'account_id' => (string) $account->id,
                'endpoint' => $endpoint,
                'status_code' => $status,
                'response_json' => json_encode($payload, JSON_THROW_ON_ERROR),
                'created_at' => Carbon::now(),
            ]);
        }
    }
}
