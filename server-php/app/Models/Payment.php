<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Payment extends Model
{
    protected $table = 'payments';

    public $timestamps = false;

    protected $fillable = [
        'delivery_id', 'payer_id', 'payee_id', 'amount_ariary', 'direction', 'status',
        'token_hash', 'failure', 'receipt_ref', 'created_at', 'expires_at', 'captured_at',
    ];

    protected function casts(): array
    {
        return [
            'amount_ariary' => 'integer',
            'created_at' => 'datetime',
            'expires_at' => 'datetime',
            'captured_at' => 'datetime',
        ];
    }

    public function isFinal(): bool
    {
        return in_array($this->status, ['captured', 'failed', 'cash'], true);
    }

    public function expired(): bool
    {
        return now()->greaterThan($this->expires_at);
    }

    public function payload(): array
    {
        return [
            'id' => $this->id,
            'deliveryId' => (string) $this->delivery_id,
            'amount' => $this->amount_ariary,
            'direction' => $this->direction,
            'status' => $this->status,
            'payerLabel' => 'Client',
            'payeeLabel' => 'Livreur',
            'failure' => $this->failure,
            'receiptRef' => $this->receipt_ref,
            'createdAt' => optional($this->created_at)->toIso8601String(),
            'expiresAt' => optional($this->expires_at)->toIso8601String(),
            'capturedAt' => optional($this->captured_at)->toIso8601String(),
        ];
    }
}
