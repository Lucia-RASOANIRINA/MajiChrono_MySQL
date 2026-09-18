<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\ContactMessage;
use App\Models\Dispute;
use App\Models\Notification;
use App\Models\ReclamationFile;
use App\Models\Setting;
use App\Support\CurrentAccount;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

class SupportController extends Controller
{
    public function notifications(Request $request)
    {
        $account = CurrentAccount::resolve($request);

        return response()->json([
            'items' => Notification::where('user_id', $account->id)
                ->orderByDesc('created_at')
                ->limit(100)
                ->get()
                ->map(fn (Notification $notification): array => $notification->payload())
                ->all(),
        ]);
    }

    public function markNotificationRead(Request $request, string $notificationId)
    {
        $account = CurrentAccount::resolve($request);
        $notification = Notification::where('id', $notificationId)
            ->where('user_id', $account->id)
            ->first();
        if ($notification === null) {
            throw ApiException::notFound('Notification inconnue');
        }
        $notification->forceFill(['is_read' => true])->save();

        return response()->json($notification->payload());
    }

    public function contact(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $subject = trim((string) $request->input('subject'));
        $message = trim((string) $request->input('message'));
        if ($subject === '' || mb_strlen($subject) > 160) {
            throw ApiException::unprocessable('invalid_subject', 'Sujet invalide');
        }
        if ($message === '' || mb_strlen($message) > 10000) {
            throw ApiException::unprocessable('invalid_message', 'Message invalide');
        }

        $now = Carbon::now();
        $row = ContactMessage::create([
            'client_id' => $account->id,
            'subject' => $subject,
            'message' => $message,
            'status' => 'open',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return response()->json(['id' => $row->id, 'status' => $row->status], 201);
    }

    public function adminContacts(Request $request)
    {
        $this->requireAdmin($request);

        return response()->json([
            'items' => ContactMessage::orderByDesc('created_at')->limit(100)->get()->map(
                fn (ContactMessage $row): array => [
                    'id' => $row->id,
                    'clientId' => (string) $row->client_id,
                    'subject' => $row->subject,
                    'message' => $row->message,
                    'status' => $row->status,
                    'adminReply' => $row->admin_reply,
                    'createdAt' => optional($row->created_at)->toIso8601String(),
                ]
            )->all(),
        ]);
    }

    public function replyContact(Request $request, string $messageId)
    {
        $admin = $this->requireAdmin($request);
        $reply = trim((string) $request->input('reply'));
        if ($reply === '' || mb_strlen($reply) > 10000) {
            throw ApiException::unprocessable('invalid_reply', 'Réponse invalide');
        }
        $row = ContactMessage::find($messageId);
        if ($row === null) {
            throw ApiException::notFound('Message inconnue');
        }

        $now = Carbon::now();
        DB::transaction(function () use ($admin, $row, $reply, $now): void {
            $row->forceFill([
                'admin_reply' => $reply,
                'replied_by' => $admin->id,
                'replied_at' => $now,
                'updated_at' => $now,
                'status' => 'answered',
            ])->save();
            Notification::create([
                'user_id' => $row->client_id,
                'type' => 'support',
                'title' => 'Réponse du support',
                'message' => $reply,
                'related_id' => $row->id,
                'is_read' => false,
                'created_at' => $now,
            ]);
        });

        return response()->json(['id' => $row->id, 'status' => $row->status]);
    }

    public function files(Request $request, string $disputeId)
    {
        $account = CurrentAccount::resolve($request);
        $dispute = Dispute::find($disputeId);
        if ($dispute === null || ((string) $dispute->opened_by !== (string) $account->id && $account->role !== 'admin')) {
            throw ApiException::notFound('Litige inconnu');
        }

        return response()->json([
            'items' => ReclamationFile::where('reclamation_id', $disputeId)->orderBy('created_at')->get()->map(
                fn (ReclamationFile $file): array => [
                    'id' => $file->id,
                    'filePath' => $file->file_path,
                    'originalName' => $file->original_name,
                    'mimeType' => $file->mime_type,
                    'sizeBytes' => $file->size_bytes,
                    'createdAt' => optional($file->created_at)->toIso8601String(),
                ]
            )->all(),
        ]);
    }

    public function addFile(Request $request, string $disputeId)
    {
        $account = CurrentAccount::resolve($request);
        $dispute = Dispute::find($disputeId);
        if ($dispute === null || ((string) $dispute->opened_by !== (string) $account->id && $account->role !== 'admin')) {
            throw ApiException::notFound('Litige inconnu');
        }
        $values = [
            'filePath' => trim((string) $request->input('filePath')),
            'originalName' => trim((string) $request->input('originalName')),
            'mimeType' => trim((string) $request->input('mimeType')),
            'sizeBytes' => (int) $request->input('sizeBytes'),
        ];
        if ($values['filePath'] === '' || $values['originalName'] === '' || $values['mimeType'] === '' || $values['sizeBytes'] < 0) {
            throw ApiException::unprocessable('invalid_file', 'Fichier invalide');
        }
        $file = ReclamationFile::create([
            'reclamation_id' => $disputeId,
            'file_path' => $values['filePath'],
            'original_name' => $values['originalName'],
            'mime_type' => $values['mimeType'],
            'size_bytes' => $values['sizeBytes'],
            'created_at' => Carbon::now(),
        ]);

        return response()->json(['id' => $file->id, 'reclamationId' => (int) $disputeId], 201);
    }

    public function audit(Request $request)
    {
        $this->requireAdmin($request);
        $tables = [
            'apiTokens' => 'api_tokens',
            'loginAttempts' => 'login_attempts',
            'passwordResets' => 'password_resets',
            'settings' => 'settings',
            'notifications' => 'notifications',
            'contactMessages' => 'contact_messages',
            'reclamationFiles' => 'reclamation_files',
        ];
        $counts = [];
        foreach ($tables as $key => $table) {
            $counts[$key] = DB::table($table)->count();
        }

        return response()->json($counts);
    }

    public function settings(Request $request)
    {
        $this->requireAdmin($request);

        return response()->json([
            'items' => Setting::orderBy('key_name')->get()->map(fn (Setting $setting): array => [
                'key' => $setting->key_name,
                'value' => $setting->value,
                'updatedAt' => optional($setting->updated_at)->toIso8601String(),
            ])->all(),
        ]);
    }

    public function updateSetting(Request $request, string $key)
    {
        $this->requireAdmin($request);
        $value = $request->input('value');
        if ($value !== null && mb_strlen((string) $value) > 10000) {
            throw ApiException::unprocessable('invalid_value', 'Valeur trop longue');
        }
        $setting = Setting::find($key);
        if ($setting === null) {
            $setting = Setting::create(['key_name' => $key, 'value' => $value, 'updated_at' => Carbon::now()]);
        } else {
            $setting->forceFill(['value' => $value, 'updated_at' => Carbon::now()])->save();
        }

        return response()->json(['key' => $setting->key_name, 'value' => $setting->value]);
    }

    private function requireAdmin(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        if ($account->role !== 'admin') {
            throw ApiException::forbidden('admin_required', "Accès réservé à l'administration");
        }

        return $account;
    }
}
