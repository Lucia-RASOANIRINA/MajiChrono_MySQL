<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class Conversation extends Model
{
    protected $table = 'conversations';

    public $timestamps = false;

    protected $fillable = ['delivery_id', 'created_at'];
}
