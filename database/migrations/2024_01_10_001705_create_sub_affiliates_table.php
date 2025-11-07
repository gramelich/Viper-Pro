<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('sub_affiliates', function (Blueprint $table) {
            $table->id();
            
            // CORREÇÃO 1: Garante compatibilidade de tipo de dado com users.id
            $table->foreignId('affiliate_id')->constrained('users')->cascadeOnDelete();
            
            // CORREÇÃO 2: Garante compatibilidade de tipo de dado com users.id
            $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
            
            $table->tinyInteger('status')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('sub_affiliates');
    }
};
