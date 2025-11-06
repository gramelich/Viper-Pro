FROM php:8.2-fpm-alpine

RUN apk add --no-cache \
    nginx git libpng-dev libjpeg-turbo-dev freetype-dev libzip-dev postgresql-dev zip unzip \
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

# Script de inicialização
RUN cat > /start.sh <<'EOF'
#!/bin/sh
echo "Starting PHP-FPM..."
php-fpm -D

echo "Starting Nginx..."
nginx -g "daemon off;"
EOF

RUN chmod +x /start.sh

EXPOSE 80

CMD ["/start.sh"]
