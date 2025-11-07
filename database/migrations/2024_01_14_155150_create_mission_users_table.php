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
        Schema::create('mission_users', function (Blueprint $table) {
            $table->id();
            
            // CORREÇÃO: Usa foreignId() para garantir compatibilidade com users.id
            $table->foreignId('user_id')->constrained('users')->onDelete('cascade');
            
            // CORREÇÃO: Usa foreignId() para garantir compatibilidade com missions.id
            // Assumimos que a tabela 'missions' também usa $table->id()
            $table->foreignId('mission_id')->constrained('missions')->onDelete('cascade');
            
            $table->bigInteger('rounds')->default(0);
            $table->decimal('rewards', 10, 2)->default(0);
            $table->tinyInteger('status')->default(0);
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('mission_users');
    }
};
