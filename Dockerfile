FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    nginx supervisor git libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev postgresql-dev zip unzip \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo pdo_mysql pdo_pgsql gd zip \
  && rm -rf /var/cache/apk/*

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

COPY . .

RUN composer install --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs \
    || composer install --no-dev --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs

RUN cp .env.example .env 2>/dev/null || touch .env && \
    echo "APP_KEY=base64:$(openssl rand -base64 32)" >> .env

RUN mkdir -p storage/framework/{sessions,views,cache} storage/logs bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# Configurar PHP-FPM para usar TCP em vez de socket Unix
RUN mkdir -p /run/php && \
    sed -i 's|listen = 127.0.0.1:9000|listen = 127.0.0.1:9000|' /usr/local/etc/php-fpm.d/www.conf && \
    sed -i 's|;clear_env = no|clear_env = no|' /usr/local/etc/php-fpm.d/www.conf

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
    location ~ /\.ht { deny all; } \
}' > /etc/nginx/http.d/default.conf

# Configurar Supervisor - SEM logfile que causa o erro
RUN cat > /etc/supervisord.conf <<'EOF'
[supervisord]
nodaemon=true
user=root
loglevel=info

[program:php-fpm]
command=/usr/local/sbin/php-fpm --nodaemonize --force-stderr
autostart=true
autorestart=true
priority=5
stdout_events_enabled=true
stderr_events_enabled=true

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
priority=10
stdout_events_enabled=true
stderr_events_enabled=true
EOF

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf"]
