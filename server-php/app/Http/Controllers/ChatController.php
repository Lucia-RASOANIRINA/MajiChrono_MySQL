<?php

namespace App\Http\Controllers;

use App\Exceptions\ApiException;
use App\Models\Account;
use App\Models\ChatMessage;
use App\Models\Conversation;
use App\Models\Delivery;
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
                'deliveryId' => (string) $delivery->id,
                'counterpartyName' => $other?->resolvedDisplayName() ?: 'Contact',
                'lastMessage' => $last->body,
                'lastSenderId' => (string) $last->sender_id,
                'lastAt' => optional($last->created_at)->toIso8601String(),
                'unread' => $messages->filter(fn (ChatMessage $message): bool => (string) $message->sender_id !== (string) $account->id && $message->read_at === null)->count(),
            ];
        }
        usort($items, fn (array $a, array $b): int => strcmp($b['lastAt'], $a['lastAt']));

        return response()->json(['items' => $items]);
    }

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

    private function payload(ChatMessage $message): array
    {
        return [
            'id' => (string) $message->id,
            'deliveryId' => (string) Conversation::findOrFail($message->conversation_id)->delivery_id,
            'senderId' => (string) $message->sender_id,
            'body' => $message->body,
            'createdAt' => optional($message->created_at)->toIso8601String(),
            'readAt' => optional($message->read_at)->toIso8601String(),
        ];
    }
}
