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

COPY . .

RUN composer install --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs \
    || composer install --no-dev --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs

RUN cp .env.example .env

RUN php artisan key:generate --force

RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

RUN php artisan storage:link || true

RUN php artisan route:cache || true
RUN php artisan view:cache || true

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

RUN cat > /start.sh <<'EOF'
#!/bin/sh
set -e

echo "=== Viper Pro - Iniciando ==="

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
    
    # Fresh migration - apaga tudo e recria
    echo "Executando migrations fresh..."
    php artisan migrate:fresh --force 2>&1 | tail -50 || {
        echo "⚠ Erro nas migrations. Tentando migrate normal..."
        php artisan migrate --force 2>&1 | tail -50
    }
    
    # Seeders
    if [ "$RUN_SEEDERS" = "true" ]; then
        echo "Executando seeders..."
        php artisan db:seed --force 2>&1 | tail -30 || echo "⚠ Seeders falharam"
    fi
fi

php artisan config:cache 2>/dev/null || true

chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

echo "✓ Setup concluído!"
echo "Iniciando serviços..."

php-fpm -D

exec nginx -g "daemon off;"
EOF

RUN chmod +x /start.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
  CMD nc -z 127.0.0.1 80 || exit 1

CMD ["/start.sh"]
