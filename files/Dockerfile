ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm

# System dependencies
RUN apt-get update \
    && apt-get install -y \
        git \
        curl \
        unzip \
        zip \
        libzip-dev \
        libpng-dev \
        libonig-dev \
        libxml2-dev \
        libicu-dev \
    && docker-php-ext-install \
        pdo_mysql \
        zip \
        gd \
        intl \
    && pecl install xdebug \
    && pecl install redis \
    && docker-php-ext-enable xdebug \
    && docker-php-ext-enable redis \
    && rm -rf /var/lib/apt/lists/*

# Node.js (for Vite)
ARG NODE_VERSION=20
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY ./xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini

WORKDIR /var/www/html
