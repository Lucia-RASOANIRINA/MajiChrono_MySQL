<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MajiPaySandboxTxn extends Model
{
    protected $table = 'majipay_sandbox_txns';

    protected $primaryKey = 'idem_key';

    protected $keyType = 'string';

    public $incrementing = false;

    public $timestamps = false;

    protected $fillable = ['idem_key', 'receipt_ref', 'created_at'];
}
