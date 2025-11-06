FROM php:8.2-fpm-alpine

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

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

# Instalar dependências PHP
RUN composer install --ignore-platform-reqs --no-interaction || composer install --no-dev --ignore-platform-reqs --no-interaction

# Criar .env se não existir
RUN if [ ! -f .env ]; then cp .env.example .env || touch .env; fi

# Criar diretórios e configurar permissões
RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Configurar Nginx
RUN echo 'server { listen 80; root /var/www/html/public; index index.php; location / { try_files $uri $uri/ /index.php?$query_string; } location ~ \.php$ { fastcgi_pass 127.0.0.1:9000; fastcgi_index index.php; fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; include fastcgi_params; } }' > /etc/nginx/http.d/default.conf

# Configurar Supervisor
RUN mkdir -p /etc/supervisor/conf.d && \
    cat > /etc/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
user=root
logfile=/dev/stdout
logfile_maxbytes=0
pidfile=/var/run/supervisord.pid

[program:php-fpm]
command=php-fpm
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0

[program:nginx]
command=nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stdout_logfile_maxbytes=0
stderr_logfile=/dev/stderr
stderr_logfile_maxbytes=0
EOF

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
