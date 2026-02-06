ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm

# System dependencies
ARG NODE_VERSION=20
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        unzip \
        zip \
        sqlite3 \
        libzip-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
        libonig-dev \
        libxml2-dev \
        libicu-dev \
        libsqlite3-dev \
        libcurl4-openssl-dev \
        libmagickwand-dev \
        imagemagick \
        ghostscript \
        ffmpeg \
        python3 \
        python3-pip \
        python3-venv \
        watchman \
        libpcre3 \
        openjdk-17-jdk \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        bcmath \
        exif \
        gd \
        intl \
        mbstring \
        opcache \
        mysqli \
        pdo_mysql \
        pdo_sqlite \
        zip \
        curl \
        dom \
        xml \
    && pecl install xdebug \
    && pecl install redis \
    && pecl install imagick \
    && docker-php-ext-enable xdebug redis imagick opcache \
    && python3 -m pip install --no-cache-dir pywatchman \
    && rm -rf /var/lib/apt/lists/*

# Node.js (for Vite)
RUN curl -fsSL https://deb.nodesource.com/setup_${NODE_VERSION}.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g npm@latest \
    && rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY ./xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY ./opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

WORKDIR /var/www/html
