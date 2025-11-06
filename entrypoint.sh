#!/bin/sh

# Garante que diretórios essenciais existam
mkdir -p /run/php
chown www-data:www-data /run/php

# Garante permissões corretas
chown -R www-data:www-data storage bootstrap/cache
chmod -R 775 storage bootstrap/cache

# Copia .env se não existir
[ ! -f .env ] && cp .env.example .env

# Gera chave do Laravel se não existir
if ! grep -q "^APP_KEY=base64:" .env; then
  php artisan key:generate
fi

# Roda migrations (opcional)
# php artisan migrate --force

# Inicia o Supervisor
exec /usr/bin/supervisord -c /etc/supervisord.conf
