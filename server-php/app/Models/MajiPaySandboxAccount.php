<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class MajiPaySandboxAccount extends Model
{
    protected $table = 'majipay_sandbox_accounts';

    protected $primaryKey = 'account_id';

    public $incrementing = false;

    public $timestamps = false;

    protected $fillable = ['account_id', 'balance_ariary', 'account_ref'];
}
