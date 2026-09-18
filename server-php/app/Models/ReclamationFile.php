<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class ReclamationFile extends Model
{
    protected $table = 'reclamation_files';

    public $timestamps = false;

    protected $fillable = [
        'reclamation_id', 'file_path', 'original_name', 'mime_type', 'size_bytes', 'created_at',
    ];

    protected function casts(): array
    {
        return ['created_at' => 'datetime'];
    }
}
