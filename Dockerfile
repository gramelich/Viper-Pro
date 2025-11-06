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

RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

RUN mkdir -p /run/php \
    && sed -i 's|listen =.*|listen = /run/php/php8.2-fpm.sock|' /usr/local/etc/php-fpm.d/www.conf \
    && echo -e "listen.owner = www-data\nlisten.group = www-data\nlisten.mode = 0660" >> /usr/local/etc/php-fpm.d/www.conf

RUN echo '\
server { \
    listen 80; \
    server_name _; \
    root /var/www/html/public; \
    index index.php; \
    client_max_body_size 100M; \
    location / { try_files $uri $uri/ /index.php?$query_string; } \
    location ~ \.php$ { \
        fastcgi_pass unix:/run/php/php8.2-fpm.sock; \
        fastcgi_index index.php; \
        include fastcgi_params; \
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name; \
    } \
    location ~ /\.ht { deny all; } \
}' > /etc/nginx/http.d/default.conf

# Supervisor com LINHAS EM BRANCO
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
stderr_logfile=/dev/stderr
priority=100

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
priority=200
EOF

EXPOSE 80
CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
