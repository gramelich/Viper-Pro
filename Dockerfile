FROM php:8.2-fpm-alpine

# Instalar dependências do sistema
RUN apk add --no-cache \
    nginx \
    supervisor \
    postgresql-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    zip \
    unzip \
    libzip-dev \
    git \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install pdo pdo_pgsql pdo_mysql gd zip

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Diretório de trabalho
WORKDIR /var/www/html

# Copiar código da aplicação
COPY . .

# Instalar dependências do Composer
RUN composer install --optimize-autoloader --no-interaction --no-progress \
    --ignore-platform-reqs || \
    composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    --ignore-platform-reqs

# Criar .env se não existir
RUN if [ ! -f .env ]; then \
        cp .env.example .env 2>/dev/null || \
        touch .env; \
    fi

# Criar diretórios e ajustar permissões
RUN mkdir -p \
        storage/framework/sessions \
        storage/framework/views \
        storage/framework/cache \
        storage/logs \
        bootstrap/cache \
    && chown -R www-data:www-data \
        storage \
        bootstrap/cache \
    && chmod -R 775 \
        storage \
        bootstrap/cache

# Configurar PHP-FPM para usar socket
RUN mkdir -p /run/php && \
    sed -i 's|listen = 9000|listen = /run/php/php8.2-fpm.sock|g' \
        /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|;listen.owner = www-data|listen.owner = www-data|g' \
        /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|;listen.group = www-data|listen.group = www-data|g' \
        /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|;listen.mode = 0660|listen.mode = 0660|g' \
        /usr/local/etc/php-fpm.d/www.conf

# Configurar Nginx
RUN echo '\
server { \
    listen 80; \
    server_name localhost; \
    root /var/www/html/public; \
    index index.php; \
    client_max_body_size 100M; \
    \
    location / { \
        try_files \$uri \$uri/ /index.php?\$query_string; \
    } \
    \
    location ~ \.php$ { \
        fastcgi_pass unix:/run/php/php8.2-fpm.sock; \
        fastcgi_index index.php; \
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name; \
        include fastcgi_params; \
    } \
    \
    location ~ /\.ht { \
        deny all; \
    } \
}' > /etc/nginx/http.d/default.conf

# Supervisor (sem erro Invalid seek)
RUN cat > /etc/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/dev/null
logfile_maxbytes=0
loglevel=error

[program:php-fpm]
command=/usr/local/sbin/php-fpm --nodaemonize
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
priority=100

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
priority=200
EOF

# Expor porta
EXPOSE 80

# Iniciar Supervisor em foreground
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
