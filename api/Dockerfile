FROM php:8.4-fpm-alpine
RUN docker-php-ext-install pdo_mysql
WORKDIR /app
COPY index.php /app/index.php
