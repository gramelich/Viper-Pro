FROM php:8.2-fpm-alpine

# Pacotes e extensões
RUN apk add --no-cache \
    nginx \
    supervisor \
    git \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    libzip-dev \
    postgresql-dev \
    zip \
    unzip \
  && docker-php-ext-configure gd --with-freetype --with-jpeg \
  && docker-php-ext-install pdo pdo_mysql pdo_pgsql gd zip \
  && rm -rf /var/cache/apk/*

# Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html
COPY . .

# Instala dependências Laravel
RUN composer install --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs \
 || composer install --no-dev --optimize-autoloader --no-interaction --no-progress --ignore-platform-reqs

# Permissões
RUN mkdir -p storage bootstrap/cache /run/php \
 && chown -R www-data:www-data storage bootstrap/cache /run/php \
 && chmod -R 775 storage bootstrap/cache

# Configura socket PHP-FPM
RUN sed -i 's|listen =.*|listen = /run/php/php8.2-fpm.sock|' /usr/local/etc/php-fpm.d/www.conf \
 && echo -e "listen.owner = www-data\nlisten.group = www-data\nlisten.mode = 0660" >> /usr/local/etc/php-fpm.d/www.conf

# Nginx
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

# Supervisor
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
startsecs=5
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr

[program:nginx]
command=/usr/sbin/nginx -g "daemon off;"
autostart=true
autorestart=true
startsecs=5
stdout_logfile=/dev/stdout
stderr_logfile=/dev/stderr
EOF

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

EXPOSE 80
