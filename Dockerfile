FROM php:8.2-fpm-alpine

# Instalar dependências
RUN apk add --no-cache \
    nginx git libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev \
    postgresql-dev mysql-client zip unzip netcat-openbsd patch \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo pdo_mysql pdo_pgsql gd zip bcmath \
  && rm -rf /var/cache/apk/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

# ===== CORREÇÃO DIRETA NO ARQUIVO =====
# Criar script Python para corrigir as migrations
RUN apk add --no-cache python3 && \
    python3 << 'PYTHON'
import os
import re

migrations_dir = 'database/migrations'
fixed_count = 0

for filename in os.listdir(migrations_dir):
    if filename.endswith('.php'):
        filepath = os.path.join(migrations_dir, filename)
        
        with open(filepath, 'r') as f:
            content = f.read()
        
        # Padrões para corrigir foreign keys
        patterns = [
            (r"->unsignedInteger\('provider_id'\)", "->unsignedBigInteger('provider_id')"),
            (r"->unsignedInteger\('category_id'\)", "->unsignedBigInteger('category_id')"),
            (r"->unsignedInteger\('game_id'\)", "->unsignedBigInteger('game_id')"),
            (r"->unsignedInteger\('user_id'\)", "->unsignedBigInteger('user_id')"),
        ]
        
        original = content
        for pattern, replacement in patterns:
            content = re.sub(pattern, replacement, content)
        
        if content != original:
            with open(filepath, 'w') as f:
                f.write(content)
            fixed_count += 1
            print(f"✓ Corrigido: {filename}")

print(f"\n✅ Total de arquivos corrigidos: {fixed_count}")
PYTHON

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

# Script de inicialização
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
        echo "❌ Timeout aguardando banco."
        exit 1
    fi
    
    # Verificar tabelas
    TABLE_COUNT=$(mysql -h"$DB_HOST" -P"${DB_PORT:-3306}" -u"$DB_USERNAME" -p"$DB_PASSWORD" "$DB_DATABASE" -sN -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '$DB_DATABASE' AND table_name != 'migrations';" 2>/dev/null || echo "0")
    
    echo "📊 Tabelas no banco: $TABLE_COUNT"
    
    if [ "$TABLE_COUNT" = "0" ] || [ "$FORCE_FRESH" = "true" ]; then
        echo "🔄 Criando banco do zero..."
        
        php artisan migrate:fresh --seed --force 2>&1 | tail -100 && {
            echo "✅ Banco criado com sucesso!"
        } || {
            echo "⚠ Erro. Tentando sem seed..."
            php artisan migrate:fresh --force 2>&1 | tail -50
            
            if [ "$RUN_SEEDERS" = "true" ]; then
                php artisan db:seed --force 2>&1 | tail -30
            fi
        }
    else
        echo "📈 Rodando migrate incremental..."
        php artisan migrate --force 2>&1 | tail -30 || echo "⚠ Nenhuma migration nova"
    fi
fi

php artisan config:cache 2>/dev/null || true
chown -R www-data:www-data storage bootstrap/cache 2>/dev/null || true

echo ""
echo "✅ Setup concluído!"
echo "🚀 Iniciando serviços..."
echo ""

php-fpm -D
exec nginx -g "daemon off;"
EOF

RUN chmod +x /start.sh

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=90s \
  CMD nc -z 127.0.0.1 80 || exit 1

CMD ["/start.sh"]
