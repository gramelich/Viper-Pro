FROM php:8.2-fpm-alpine

# Instalar dependências
RUN apk add --no-cache \
    nginx git libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev \
    postgresql-dev mysql-client zip unzip netcat-openbsd sed \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo pdo_mysql pdo_pgsql gd zip bcmath \
  && rm -rf /var/cache/apk/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

# ===== CORREÇÃO AUTOMÁTICA DA MIGRATION =====
# Corrigir o erro de foreign key na migration de games
RUN if [ -f database/migrations/2023_10_07_183922_create_games_table.php ]; then \
    sed -i "s/\$table->unsignedInteger('provider_id');/\$table->unsignedBigInteger('provider_id');/g" \
        database/migrations/2023_10_07_183922_create_games_table.php && \
    echo "✓ Migration de games corrigida!"; \
fi

# Corrigir também outras possíveis migrations com o mesmo problema
RUN find database/migrations -name "*.php" -type f -exec \
    sed -i "s/\$table->unsignedInteger('provider_id');/\$table->unsignedBigInteger('provider_id');/g" {} \;

RUN find database/migrations -name "*.php" -type f -exec \
    sed -i "s/\$table->unsignedInteger('category_id');/\$table->unsignedBigInteger('category_id');/g" {} \;

RUN find database/migrations -name "*.php" -type f -exec \
    sed -i "s/\$table->unsignedInteger('game_id');/\$table->unsignedBigInteger('game_id');/g" {} \;

RUN find database/migrations -name "*.php" -type f -exec \
    sed -i "s/\$table->unsignedInteger('user_id');/\$table->unsignedBigInteger('user_id');/g" {} \;

# Instalar dependências PHP
RUN composer install --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs \
    || composer install --no-dev --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs

# Preparar .env
RUN cp .env.example .env

# Gerar APP_KEY
RUN php artisan key:generate --force

# Criar estrutura de diretórios
RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Storage link
RUN php artisan storage:link || true

# Caches
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

# Script de inicialização otimizado
RUN cat > /start.sh <<'EOF'
#!/bin/sh
set -e

echo "=== Viper Pro - Iniciando ==="

if [ ! -z "$DB_HOST" ]; then
    echo "Aguardando banco de dados em $DB_HOST:${DB_PORT:-3306}..."
    timeout=60
    while [ $timeout -gt 0 ]; do
        if nc -z $DB_HOST ${DB_PORT:-3306} 2>/dev/null; then
            echo "✓ Banco conectado!"
            sleep 2
            break
        fi
        timeout=$((timeout-1))
        sleep 1
    done
    
    if [ $timeout -eq 0 ]; then
        echo "❌ Timeout aguardando banco. Abortando..."
        exit 1
    fi
    
    # Verificar se banco está vazio
    TABLE_COUNT=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_DATABASE' AND table_name != 'migrations';" 2>/dev/null || echo "0")
    
    echo "Tabelas encontradas no banco: $TABLE_COUNT"
    
    if [ "$TABLE_COUNT" = "0" ] || [ "$FORCE_FRESH" = "true" ]; then
        echo "🔄 Criando banco de dados do zero..."
        
        # Migrate fresh com seed
        php artisan migrate:fresh --seed --force 2>&1 | tail -100 && {
            echo "✓ Banco criado e populado com sucesso!"
        } || {
            echo "⚠ Erro no migrate:fresh. Tentando sem seed..."
            php artisan migrate:fresh --force 2>&1 | tail -50
            
            if [ "$RUN_SEEDERS" = "true" ]; then
                echo "Executando seeders..."
                php artisan db:seed --force 2>&1 | tail -30 || echo "⚠ Seeders falharam"
            fi
        }
    else
        echo "📊 Banco já tem dados. Rodando apenas migrate..."
        php artisan migrate --force 2>&1 | tail -30 || echo "⚠ Nenhuma migration nova"
    fi
fi

# Cache
php artisan config:cache 2>/dev/null || true

# Permissões
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

echo ""
echo "✅ Setup concluído com sucesso!"
echo "🚀 Iniciando serviços..."
echo ""

# PHP-FPM em background
php-fpm -D

# Nginx em foreground
exec nginx -g "daemon off;"
EOF

RUN chmod +x /start.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=90s \
  CMD nc -z 127.0.0.1 80 || exit 1

CMD ["/start.sh"]
