<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\ChatMessage;
use App\Models\Conversation;
use App\Models\Delivery;
use App\Models\Media;
use App\Support\CurrentAccount;
use Carbon\Exceptions\InvalidFormatException;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ChatController extends Controller
{
    public function conversations(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $deliveries = Delivery::query()
            ->whereNotNull('driver_id')
            ->where(function ($query) use ($account): void {
                $query->where('client_id', $account->id)->orWhere('driver_id', $account->id);
            })
            ->get();

        $items = [];
        foreach ($deliveries as $delivery) {
            $conversation = Conversation::where('delivery_id', $delivery->id)->first();
            if ($conversation === null) {
                continue;
            }
            $messages = ChatMessage::where('conversation_id', $conversation->id)->orderBy('created_at')->get();
            if ($messages->isEmpty()) {
                continue;
            }
            $last = $messages->last();
            $otherId = (string) $delivery->client_id === (string) $account->id
                ? $delivery->driver_id
                : $delivery->client_id;
            $other = Account::find($otherId);
            $items[] = [
                'conversationId' => (string) $conversation->id,
                'deliveryId' => (string) $delivery->id,
                'kind' => 'delivery',
                'counterpartyName' => $other?->resolvedDisplayName() ?: 'Contact',
                'lastMessage' => $last->body,
                'lastSenderId' => (string) $last->sender_id,
                'lastAt' => optional($last->created_at)->toIso8601String(),
                'unread' => $messages->filter(fn (ChatMessage $message): bool => (string) $message->sender_id !== (string) $account->id && $message->read_at === null)->count(),
            ];
        }
        $adminConversations = Conversation::where('kind', 'admin')
            ->where(function ($query) use ($account): void {
                $query->where('client_id', $account->id)->orWhere('admin_id', $account->id);
            })
            ->whereNull('deleted_at')
            ->with(['messages' => fn ($query) => $query->latest('created_at')])
            ->get();
        foreach ($adminConversations as $conversation) {
            $last = $conversation->messages->first();
            if ($last === null) {
                continue;
            }
            $otherId = (string) $conversation->client_id === (string) $account->id
                ? $conversation->admin_id
                : $conversation->client_id;
            $other = Account::find($otherId);
            $items[] = [
                'conversationId' => (string) $conversation->id,
                'deliveryId' => null,
                'kind' => 'admin',
                'counterpartyName' => $other?->resolvedDisplayName() ?: 'Administration',
                'lastMessage' => $last->body ?: 'Pièce jointe',
                'lastSenderId' => (string) $last->sender_id,
                'lastAt' => optional($last->created_at)->toIso8601String(),
                'unread' => $conversation->messages
                    ->filter(fn (ChatMessage $message): bool => (string) $message->sender_id !== (string) $account->id && $message->read_at === null)->count(),
                'archived' => $conversation->archived_at !== null,
                'blocked' => $conversation->blocked_at !== null,
            ];
        }
        usort($items, fn (array $a, array $b): int => strcmp($b['lastAt'], $a['lastAt']));

        return response()->json(['items' => $items]);
    }

    public function startAdminConversation(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $admin = Account::where('role', 'admin')->orderBy('id')->first();
        if ($admin === null) {
            throw ApiException::badGateway('admin_unavailable', 'Administration indisponible');
        }
        $conversation = Conversation::where('kind', 'admin')
            ->where('client_id', $account->id)
            ->where('admin_id', $admin->id)
            ->whereNull('deleted_at')
            ->first();
        if ($conversation === null) {
            $conversation = Conversation::create([
                'client_id' => $account->id,
                'admin_id' => $admin->id,
                'kind' => 'admin',
                'status' => 'active',
                'created_at' => Carbon::now(),
            ]);
        }

        return response()->json(['conversationId' => (string) $conversation->id], 201);
    }

    public function search(Request $request)
    {
        $account = CurrentAccount::resolve($request);
        $term = trim((string) $request->query('q'));
        if ($term === '' || mb_strlen($term) < 2) {
            throw ApiException::unprocessable('invalid_search', 'La recherche doit contenir au moins 2 caractères');
        }
        $conversationIds = Conversation::query()
            ->whereNull('deleted_at')
            ->where(function ($query) use ($account): void {
                $query->where('client_id', $account->id)->orWhere('admin_id', $account->id);
            })
            ->pluck('id')->all();
        $deliveryIds = Delivery::query()
            ->where(function ($query) use ($account): void {
                $query->where('client_id', $account->id)->orWhere('driver_id', $account->id);
            })
            ->pluck('id');
        $conversationIds = array_merge(
            $conversationIds,
            Conversation::whereIn('delivery_id', $deliveryIds)->pluck('id')->all(),
        );
        $items = ChatMessage::query()
            ->where('body', 'like', '%'.$term.'%')
            ->whereIn('conversation_id', $conversationIds)
            ->latest('created_at')->limit(100)->get()
            ->map(fn (ChatMessage $message): array => $this->payload($message))
            ->all();

        return response()->json(['items' => $items]);
    }

    public function conversationMessages(Request $request, string $conversationId)
    {
        [$account, $conversation] = $this->conversationForId($request, $conversationId);
        $query = ChatMessage::where('conversation_id', $conversation->id);
        $term = trim((string) $request->query('q'));
        if ($term !== '') {
            $query->where('body', 'like', '%'.$term.'%');
        }
        return response()->json([
            'items' => $query->orderBy('created_at')->get()->map(fn (ChatMessage $message): array => $this->payload($message))->all(),
        ]);
    }

    public function sendConversationMessage(Request $request, string $conversationId)
    {
        [$account, $conversation] = $this->conversationForId($request, $conversationId);
        if ($conversation->blocked_at !== null) {
            throw ApiException::forbidden('conversation_blocked', 'Conversation bloquée');
        }
        $body = trim((string) $request->input('body'));
        $mediaId = $request->input('attachmentMediaId');
        if ($body === '' && ! is_string($mediaId)) {
            throw ApiException::unprocessable('empty_message', 'Message vide');
        }
        if (mb_strlen($body) > 2000) {
            throw ApiException::unprocessable('message_too_long', 'Message trop long');
        }
        $media = null;
        if (is_string($mediaId) && $mediaId !== '') {
            $media = Media::where('id', $mediaId)->where('account_id', $account->id)->first();
            if ($media === null) {
                throw ApiException::notFound('Pièce jointe inconnue');
            }
        }
        $message = ChatMessage::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $account->id,
            'body' => $body,
            'attachment_media_id' => $media?->id,
            'attachment_name' => $request->input('attachmentName'),
            'attachment_content_type' => $media?->content_type,
            'created_at' => Carbon::now(),
        ]);
        return response()->json($this->payload($message), 201);
    }

    public function archive(Request $request, string $conversationId) { return $this->conversationState($request, $conversationId, ['archived_at' => Carbon::now()]); }
    public function restore(Request $request, string $conversationId) { return $this->conversationState($request, $conversationId, ['archived_at' => null]); }
    public function block(Request $request, string $conversationId) { [$account, $conversation] = $this->conversationForId($request, $conversationId); $conversation->update(['blocked_at' => Carbon::now(), 'blocked_by' => $account->id]); return response()->json(['ok' => true]); }
    public function unblock(Request $request, string $conversationId) { return $this->conversationState($request, $conversationId, ['blocked_at' => null, 'blocked_by' => null]); }
    public function deleteConversation(Request $request, string $conversationId) { return $this->conversationState($request, $conversationId, ['deleted_at' => Carbon::now(), 'status' => 'deleted']); }

    public function messages(Request $request, string $deliveryId)
    {
        [$account, $conversation] = $this->conversationFor($request, $deliveryId);
        $query = ChatMessage::where('conversation_id', $conversation->id);
        $after = $request->query('after');
        if ($after !== null) {
            try {
                $query->where('created_at', '>', Carbon::parse($after));
            } catch (InvalidFormatException) {
                throw ApiException::unprocessable('invalid_cursor', 'Curseur de date invalide');
            }
        }

        return response()->json([
            'items' => $query->orderBy('created_at')->get()->map(fn (ChatMessage $message): array => $this->payload($message))->all(),
        ]);
    }

    public function send(Request $request, string $deliveryId)
    {
        [$account, $conversation] = $this->conversationFor($request, $deliveryId);
        $body = trim((string) $request->input('body'));
        if ($body === '') {
            throw ApiException::unprocessable('empty_message', 'Message vide');
        }
        if (mb_strlen($body) > 2000) {
            throw ApiException::unprocessable('message_too_long', 'Message trop long');
        }

        $message = ChatMessage::create([
            'conversation_id' => $conversation->id,
            'sender_id' => $account->id,
            'body' => $body,
            'created_at' => Carbon::now(),
        ]);

        return response()->json($this->payload($message), 201);
    }

    public function markRead(Request $request, string $deliveryId)
    {
        [$account, $conversation] = $this->conversationFor($request, $deliveryId);
        $marked = ChatMessage::where('conversation_id', $conversation->id)
            ->where('sender_id', '!=', $account->id)
            ->whereNull('read_at')
            ->update(['read_at' => Carbon::now()]);

        return response()->json(['marked' => $marked]);
    }

    private function conversationFor(Request $request, string $deliveryId): array
    {
        $account = CurrentAccount::resolve($request);
        $delivery = Delivery::find($deliveryId);
        if ($delivery === null || $delivery->driver_id === null
            || ((string) $delivery->client_id !== (string) $account->id
                && (string) $delivery->driver_id !== (string) $account->id)) {
            throw ApiException::notFound('Course inconnue');
        }

        $conversation = Conversation::where('delivery_id', $delivery->id)->first();
        if ($conversation === null) {
            throw ApiException::notFound('La discussion s ouvre a l acceptation de la course');
        }

        return [$account, $conversation];
    }

    private function conversationForId(Request $request, string $conversationId): array
    {
        $account = CurrentAccount::resolve($request);
        $conversation = Conversation::whereKey($conversationId)->whereNull('deleted_at')->first();
        if ($conversation === null || (
            $conversation->kind === 'admin'
            && (string) $conversation->client_id !== (string) $account->id
            && (string) $conversation->admin_id !== (string) $account->id
        )) {
            throw ApiException::notFound('Conversation inconnue');
        }
        return [$account, $conversation];
    }

    private function conversationState(Request $request, string $conversationId, array $changes)
    {
        [, $conversation] = $this->conversationForId($request, $conversationId);
        $conversation->update($changes);
        return response()->json(['ok' => true]);
    }

    private function payload(ChatMessage $message): array
    {
        return [
            'id' => (string) $message->id,
            'deliveryId' => (string) Conversation::findOrFail($message->conversation_id)->delivery_id,
            'senderId' => (string) $message->sender_id,
            'body' => $message->body,
            'createdAt' => optional($message->created_at)->toIso8601String(),
            'readAt' => optional($message->read_at)->toIso8601String(),
            'attachmentMediaId' => $message->attachment_media_id,
            'attachmentName' => $message->attachment_name,
            'attachmentContentType' => $message->attachment_content_type,
        ];
    }
}
