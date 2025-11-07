<?php
use App\Http\Controllers\Api\Providers\VGamesController;
use Illuminate\Support\Facades\Route;

Route::prefix('vgames')
    ->as('vgames.')
    ->group(function ()
    {
        Route::get('/exclusive/', [VGamesController::class, 'index'])->name('index');

        // Rota renomeada para 'show.aposta' para evitar conflito com a linha 9.
        Route::get('/exclusive/{game}/{aposta}', [VGamesController::class, 'show'])->name('show.aposta'); 

        // Esta é a rota que agora será chamada de 'web.vgames.show'
        Route::get('/exclusive/{game}', [VGamesController::class, 'show'])->name('show'); 
        
        Route::post('/game/sub', [VGamesController::class, 'subprocess'])->name('subprocess');
    });
