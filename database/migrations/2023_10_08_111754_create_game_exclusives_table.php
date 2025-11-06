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
        Schema::create('game_exclusives', function (Blueprint $table) {
            // Chave primária padrão
            $table->id(); 

            // Se for uma tabela exclusiva de um jogo, provavelmente tem uma chave estrangeira para 'games'.
            // Assumo uma FK para a tabela 'games'
            $table->foreignId('game_id')->unique()->constrained('games')->onDelete('cascade');
            
            // Colunas adicionais mínimas (caso haja alguma na implementação original que não são as que estão sendo adicionadas na próxima migração)
            // Se você souber de mais colunas que DEVEM estar aqui, adicione-as.
            
            // Colunas de timestamp
            $table->timestamps();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('game_exclusives');
    }
};
