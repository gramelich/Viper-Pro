<?php

namespace App\Http\Middleware;

use Closure;
use Throwable; // <-- ALTERAÇÃO AQUI: Captura todos os erros e exceções
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class SetDefaultLanguage
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     */
    public function handle($request, Closure $next)
    {
        try {
            // Tenta verificar a autenticação.
            if (auth('api')->check()) {
                app()->setLocale(auth('api')->user()->language);
            }
        } catch (Throwable $e) { // <-- CAPTURA AGORA A CLASSE PAI DE ERROS E EXCEÇÕES
            // Em caso de qualquer falha na inicialização (DB, JWT, etc.),
            // o erro será registrado no log, e a requisição segue.
            \Log::error('Falha na inicialização do Auth no Middleware: ' . $e->getMessage());
        }

        return $next($request);
    }
}
