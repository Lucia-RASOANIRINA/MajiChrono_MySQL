<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class KycMessage extends Model
{
    protected $table = 'kyc_messages';

    public $incrementing = false;

    public $timestamps = false;

    protected $fillable = ['id', 'account_id', 'from_admin', 'body', 'created_at'];

    protected function casts(): array
    {
        return ['from_admin' => 'boolean', 'created_at' => 'datetime'];
    }
}
