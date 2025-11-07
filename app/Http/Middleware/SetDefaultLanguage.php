<?php

namespace App\Http\Middleware;

use Closure;
use Exception; // Importar a classe Exception
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
            // Tenta verificar a autenticação. Se a conexão DB falhar, a exceção é capturada.
            if (auth('api')->check()) {
                app()->setLocale(auth('api')->user()->language);
            }
        } catch (Exception $e) {
            // Em caso de falha de conexão com o banco de dados ou outro erro, 
            // não faz nada e deixa o processo seguir.
            // O erro será registrado no log (laravel.log), mas o site não retornará 500.
            // Opcional: registrar o erro, mas não é estritamente necessário se for apenas erro DB inicial.
            // \Log::error('Erro no middleware de linguagem: ' . $e->getMessage());
        }

        return $next($request);
    }
}
