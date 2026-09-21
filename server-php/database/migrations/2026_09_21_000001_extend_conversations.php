<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('conversations')) {
            Schema::create('conversations', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('delivery_id')->nullable();
                $table->unsignedBigInteger('client_id')->nullable();
                $table->unsignedBigInteger('admin_id')->nullable();
                $table->string('kind')->default('delivery');
                $table->string('status')->default('active');
                $table->timestamp('archived_at')->nullable();
                $table->timestamp('blocked_at')->nullable();
                $table->unsignedBigInteger('blocked_by')->nullable();
                $table->timestamp('deleted_at')->nullable();
                $table->timestamps();
                $table->index(['client_id', 'kind', 'status']);
                $table->index(['admin_id', 'kind', 'status']);
            });
        } else {
            Schema::table('conversations', function (Blueprint $table): void {
                if (! Schema::hasColumn('conversations', 'client_id')) $table->unsignedBigInteger('client_id')->nullable();
                if (! Schema::hasColumn('conversations', 'admin_id')) $table->unsignedBigInteger('admin_id')->nullable();
                if (! Schema::hasColumn('conversations', 'kind')) $table->string('kind')->default('delivery');
                if (! Schema::hasColumn('conversations', 'status')) $table->string('status')->default('active');
                if (! Schema::hasColumn('conversations', 'archived_at')) $table->timestamp('archived_at')->nullable();
                if (! Schema::hasColumn('conversations', 'blocked_at')) $table->timestamp('blocked_at')->nullable();
                if (! Schema::hasColumn('conversations', 'blocked_by')) $table->unsignedBigInteger('blocked_by')->nullable();
                if (! Schema::hasColumn('conversations', 'deleted_at')) $table->timestamp('deleted_at')->nullable();
            });
        }

        if (! Schema::hasTable('conversation_messages')) {
            Schema::create('conversation_messages', function (Blueprint $table): void {
                $table->id();
                $table->unsignedBigInteger('conversation_id');
                $table->unsignedBigInteger('sender_id');
                $table->text('body')->nullable();
                $table->string('attachment_media_id')->nullable();
                $table->string('attachment_name')->nullable();
                $table->string('attachment_content_type')->nullable();
                $table->timestamp('created_at')->useCurrent();
                $table->timestamp('read_at')->nullable();
                $table->index(['conversation_id', 'created_at']);
            });
        } elseif (! Schema::hasColumn('conversation_messages', 'attachment_media_id')) {
            Schema::table('conversation_messages', function (Blueprint $table): void {
                $table->string('attachment_media_id')->nullable();
                $table->string('attachment_name')->nullable();
                $table->string('attachment_content_type')->nullable();
            });
        }
    }

    public function down(): void
    {
        // Shared production tables may predate Laravel migrations; never drop them.
    }
};
