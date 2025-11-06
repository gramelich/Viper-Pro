FROM php:8.2-fpm-alpine

# Pacotes + extensões
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

# Composer
RUN composer install --optimize-autoloader --no-interaction --no-progress \
    --ignore-platform-reqs \
    || composer install --no-dev --optimize-autoloader --no-interaction --no-progress \
    --ignore-platform-reqs

# .env
RUN cp .env.example .env 2>/dev/null || touch .env

# Permissões
RUN mkdir -p storage bootstrap/cache \
    && chown -R www-data:www-data storage bootstrap/cache \
    && chmod -R 775 storage bootstrap/cache

# PHP-FPM socket
RUN mkdir -p /run/php \
    && sed -i 's|listen =.*|listen = /run/php/php8.2-fpm.sock|' \
       /usr/local/etc/php-fpm.d/www.conf \
    && echo -e "listen.owner = www-data\nlisten.group = www-data\nlisten.mode = 0660" \
       >> /usr/local/etc/php-fpm.d/www.conf

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

# Supervisor: configuração em uma linha só (sem quebras)
RUN echo '[supervisord]\n\
nodaemon=true\n\
user=root\n\
logfile=/dev/null\n\
logfile_maxbytes=0\n\
loglevel=error\n\
\n\
[program:php-fpm]\n\
command=/usr/local/sbin/php-fpm --nodaemonize\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
\n\
[program:nginx]\n\
command=/usr/sbin/nginx -g "daemon off;"\n\
autostart=true\n\
autorestart=true\n\
stdout_logfile=/dev/stdout\n\
stdout_logfile_maxbytes=0\n\
stderr_logfile=/dev/stderr\n\
stderr_logfile_maxbytes=0\n\
' > /etc/supervisord.conf

EXPOSE 80

CMD ["/usr/bin/supervisord", "-n", "-c", "/etc/supervisord.conf"]
