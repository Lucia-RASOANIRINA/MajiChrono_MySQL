<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\KycDocument;
use App\Models\KycMessage;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class KycController extends Controller
{
    private const KINDS = ['cin_front', 'cin_back', 'licence', 'selfie', 'registration', 'vehicle', 'plate'];

    private const ALLOWED_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

    private function driver(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($account->role !== 'driver') {
            throw ApiException::forbidden('driver_required', 'Acces reserve aux livreurs');
        }

        return $account;
    }

    private function admin(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($account->role !== 'admin') {
            throw ApiException::forbidden('admin_required', 'Acces reserve a l administration');
        }

        return $account;
    }

    private function findDriver(string $driverId)
    {
        $driver = Account::find($driverId);
        if ($driver === null || $driver->role !== 'driver') {
            throw ApiException::notFound('Livreur inconnu');
        }

        return $driver;
    }

    public function status(Request $request)
    {
        $account = $this->driver($request);
        $uploaded = KycDocument::query()
            ->where('account_id', $account->id)
            ->pluck('kind')
            ->all();

        return response()->json([
            'status' => $account->kyc_status ?: 'draft',
            'documents' => self::KINDS,
            'uploaded' => array_values(array_intersect(self::KINDS, $uploaded)),
            'missing' => array_values(array_diff(self::KINDS, $uploaded)),
            'rejectionReason' => null,
        ]);
    }

    public function messages(Request $request)
    {
        $account = $this->driver($request);

        return response()->json([
            'items' => KycMessage::query()
                ->where('account_id', $account->id)
                ->orderBy('created_at')
                ->get()
                ->map(fn (KycMessage $message): array => $this->messagePayload($message))
                ->all(),
        ]);
    }

    public function sendMessage(Request $request)
    {
        $account = $this->driver($request);
        $body = trim((string) $request->input('body'));
        if ($body === '') {
            throw ApiException::unprocessable('empty_message', 'Message vide');
        }
        if (mb_strlen($body) > 2000) {
            throw ApiException::unprocessable('message_too_long', 'Message trop long');
        }

        $message = KycMessage::create([
            'id' => (string) Str::uuid(),
            'account_id' => $account->id,
            'from_admin' => false,
            'body' => $body,
            'created_at' => Carbon::now(),
        ]);

        return response()->json($this->messagePayload($message), 201);
    }

    public function upload(Request $request, string $kind)
    {
        $account = $this->driver($request);
        $this->validateKind($kind);
        $contentType = mb_strtolower(trim((string) $request->input('contentType')));
        if (! in_array($contentType, self::ALLOWED_TYPES, true)) {
            throw ApiException::unprocessable('unsupported_type', "Format d'image non accepte");
        }

        $raw = (string) $request->input('imageBase64');
        if (str_starts_with(trim($raw), 'data:') && str_contains($raw, ',')) {
            $raw = explode(',', $raw, 2)[1];
        }
        $data = base64_decode($raw, true);
        if ($data === false || $data === '') {
            throw ApiException::unprocessable('invalid_image', 'Image illisible');
        }
        if (strlen($data) > 1024 * 1024) {
            throw ApiException::unprocessable('image_too_large', 'Image trop lourde', ['maxBytes' => 1024 * 1024]);
        }

        DB::table('kyc_documents')->updateOrInsert(
            ['account_id' => $account->id, 'kind' => $kind],
            ['data' => $data, 'content_type' => $contentType, 'updated_at' => Carbon::now()],
        );

        return response()->json($this->uploadedPayload($account->id));
    }

    public function delete(Request $request, string $kind)
    {
        $account = $this->driver($request);
        $this->validateKind($kind);
        DB::table('kyc_documents')
            ->where('account_id', $account->id)
            ->where('kind', $kind)
            ->delete();

        return response()->json($this->uploadedPayload($account->id));
    }

    public function read(Request $request, string $accountId, string $kind)
    {
        $viewer = CurrentAccount::resolve($request);
        $this->validateKind($kind);
        if ((string) $viewer->id !== $accountId && $viewer->role !== 'admin') {
            throw ApiException::forbidden('not_allowed', 'Acces reserve');
        }

        $document = DB::table('kyc_documents')
            ->where('account_id', $accountId)
            ->where('kind', $kind)
            ->first();
        if ($document === null) {
            throw ApiException::notFound('Piece inconnue');
        }

        return response($document->data, 200, ['Content-Type' => $document->content_type]);
    }

    public function submit(Request $request)
    {
        $account = $this->driver($request);
        if (in_array($account->kyc_status, ['approved', 'submitted'], true)) {
            return response()->json(['status' => $account->kyc_status]);
        }

        $uploaded = KycDocument::query()->where('account_id', $account->id)->pluck('kind')->all();
        $missing = array_values(array_diff(self::KINDS, $uploaded));
        if ($missing !== []) {
            throw ApiException::unprocessable('kyc_incomplete', 'Dossier incomplet', ['missing' => $missing]);
        }

        $account->forceFill(['kyc_status' => 'submitted'])->save();

        return response()->json(['status' => 'submitted']);
    }

    public function queue(Request $request)
    {
        $this->admin($request);
        $drivers = Account::query()
            ->where('role', 'driver')
            ->where(function ($query): void {
                $query->whereIn('kyc_status', ['submitted', 'under_review'])
                    ->orWhereExists(function ($messages): void {
                        $messages->selectRaw('1')
                            ->from('kyc_messages')
                            ->whereColumn('kyc_messages.account_id', 'users.id')
                            ->where('from_admin', false);
                    });
            })
            ->orderBy('created_at')
            ->get();

        return response()->json([
            'items' => $drivers->map(function ($driver): array {
                $uploaded = KycDocument::query()
                    ->where('account_id', $driver->id)
                    ->pluck('kind')
                    ->all();

                return [
                    'driverId' => (string) $driver->id,
                    'displayName' => $driver->resolvedDisplayName(),
                    'phone' => $driver->phone,
                    'status' => $driver->kyc_status ?: 'draft',
                    'submittedAt' => optional($driver->created_at)->toIso8601String(),
                    'documents' => array_map(fn (string $kind): array => [
                        'code' => $kind,
                        'provided' => in_array($kind, $uploaded, true),
                        'url' => "/accounts/{$driver->id}/kyc/{$kind}",
                    ], self::KINDS),
                ];
            })->all(),
        ]);
    }

    public function adminDocuments(Request $request, string $driverId)
    {
        $this->admin($request);
        $driver = $this->findDriver($driverId);
        $documents = KycDocument::query()
            ->where('account_id', $driver->id)
            ->orderBy('kind')
            ->get(['kind'])
            ->map(fn (KycDocument $document): array => [
                'kind' => $document->kind,
                'url' => "/accounts/{$driver->id}/kyc/{$document->kind}",
            ])->all();

        return response()->json(['driverId' => (string) $driver->id, 'documents' => $documents]);
    }

    public function adminMessages(Request $request, string $driverId)
    {
        $this->admin($request);
        $driver = $this->findDriver($driverId);

        return response()->json([
            'items' => KycMessage::query()
                ->where('account_id', $driver->id)
                ->orderBy('created_at')
                ->get()
                ->map(fn (KycMessage $message): array => $this->messagePayload($message))
                ->all(),
        ]);
    }

    public function adminSendMessage(Request $request, string $driverId)
    {
        $admin = $this->admin($request);
        $driver = $this->findDriver($driverId);
        $body = trim((string) $request->input('body'));
        if ($body === '') {
            throw ApiException::unprocessable('empty_message', 'Message vide');
        }
        if (mb_strlen($body) > 2000) {
            throw ApiException::unprocessable('message_too_long', 'Message trop long');
        }

        $message = KycMessage::create([
            'id' => (string) Str::uuid(),
            'account_id' => $driver->id,
            'from_admin' => true,
            'body' => $body,
            'created_at' => Carbon::now(),
        ]);

        return response()->json($this->messagePayload($message), 201);
    }

    public function review(Request $request, string $driverId)
    {
        $admin = $this->admin($request);
        $driver = $this->findDriver($driverId);
        $reason = trim((string) $request->input('reason'));
        if (mb_strlen($reason) < 3) {
            throw ApiException::unprocessable('invalid_reason', 'Motif obligatoire');
        }

        $approved = filter_var($request->input('approve'), FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
        if ($approved === null) {
            throw ApiException::unprocessable('invalid_approval', 'Decision invalide');
        }

        $status = $approved ? 'approved' : 'rejected';
        DB::transaction(function () use ($admin, $driver, $status, $reason): void {
            $driver->forceFill(['kyc_status' => $status])->save();
            DB::table('moderation_logs')->insert([
                'id' => (string) Str::uuid(),
                'actor_id' => $admin->id,
                'subject_id' => $driver->id,
                'action' => $status === 'approved' ? 'kyc_approved' : 'kyc_rejected',
                'reason' => $reason,
                'decided_at' => Carbon::now(),
            ]);
        });

        return response()->json(['driverId' => (string) $driver->id, 'kycStatus' => $status]);
    }

    private function validateKind(string $kind): void
    {
        if (! in_array($kind, self::KINDS, true)) {
            throw ApiException::unprocessable('unknown_kind', 'Piece inconnue');
        }
    }

    private function uploadedPayload($accountId): array
    {
        $uploaded = KycDocument::query()->where('account_id', $accountId)->pluck('kind')->all();

        return ['uploaded' => array_values(array_intersect(self::KINDS, $uploaded))];
    }

    private function messagePayload(KycMessage $message): array
    {
        return [
            'id' => (string) $message->id,
            'fromAdmin' => (bool) $message->from_admin,
            'body' => $message->body,
            'createdAt' => optional($message->created_at)->toIso8601String(),
        ];
    }
}
