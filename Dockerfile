FROM php:8.2-fpm-alpine

# Instalar dependências
RUN apk add --no-cache \
    nginx git libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev \
    postgresql-dev mysql-client zip unzip netcat-openbsd \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo pdo_mysql pdo_pgsql gd zip bcmath \
  && rm -rf /var/cache/apk/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copiar tudo
COPY . .

# Instalar dependências PHP
RUN composer install --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs \
    || composer install --no-dev --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs

# Preparar .env
RUN cp .env.example .env

# Gerar APP_KEY durante o build
RUN php artisan key:generate --force

# Criar estrutura de diretórios
RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Criar link do storage
RUN php artisan storage:link || true

# Otimizar durante o build (exceto config que precisa das envs)
RUN php artisan route:cache || true
RUN php artisan view:cache || true

# Configurar Nginx
RUN echo 'server { \
    listen 80; \
    server_name _; \
    root /var/www/html/public; \
    index index.php; \
    client_max_body_size 100M; \
    location / { try_files $uri $uri/ /index.php?$query_string; } \
    location ~ \.php$ { \
        fastcgi_pass 127.0.0.1:9000; \
        fastcgi_index index.php; \
        include fastcgi_params; \
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
    } \
    location ~ /\.(?!well-known).* { deny all; } \
}' > /etc/nginx/http.d/default.conf

# Script de inicialização MINIMALISTA
RUN cat > /start.sh <<'EOF'
#!/bin/sh
set -e

echo "=== Viper Pro - Iniciando ==="

# Aguardar banco (se DB_HOST estiver definido)
if [ ! -z "$DB_HOST" ]; then
    echo "Aguardando banco de dados em $DB_HOST:${DB_PORT:-3306}..."
    timeout=30
    while [ $timeout -gt 0 ]; do
        if nc -z $DB_HOST ${DB_PORT:-3306} 2>/dev/null; then
            echo "✓ Banco conectado!"
            break
        fi
        timeout=$((timeout-1))
        sleep 1
    done
    
    if [ $timeout -eq 0 ]; then
        echo "⚠ Timeout aguardando banco. Continuando mesmo assim..."
    fi
    
    # Rodar migrations automaticamente
    echo "Executando migrations..."
    php artisan migrate --force 2>&1 | head -20 || echo "⚠ Migrations com erro (pode ser normal)"
    
    # Seeders (se necessário)
    if [ "$RUN_SEEDERS" = "true" ]; then
        echo "Executando seeders..."
        php artisan db:seed --force 2>&1 | head -20 || echo "⚠ Seeders não executados"
    fi
fi

# Cache de config (agora que temos as envs)
php artisan config:cache 2>/dev/null || true

# Ajustar permissões finais
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

echo "✓ Setup concluído!"
echo "Iniciando serviços..."

# PHP-FPM em background
php-fpm -D

# Nginx em foreground
exec nginx -g "daemon off;"
EOF

RUN chmod +x /start.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD nc -z 127.0.0.1 80 || exit 1

CMD ["/start.sh"]
