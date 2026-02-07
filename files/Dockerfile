ARG PHP_VERSION=8.3
FROM php:${PHP_VERSION}-fpm-bookworm

# System dependencies
ARG APT_MIRROR=deb.debian.org
ARG APT_SECURITY_MIRROR=security.debian.org
ARG INSTALL_MEDIA_TOOLS=true
RUN mirror="$APT_MIRROR"; \
    security="$APT_SECURITY_MIRROR"; \
    case "$mirror" in \
        http://*|https://*) ;; \
        "") mirror="https://deb.debian.org" ;; \
        *) mirror="https://$mirror" ;; \
    esac; \
    case "$security" in \
        http://*|https://*) ;; \
        "") security="https://security.debian.org" ;; \
        *) security="https://$security" ;; \
    esac; \
    mirror="${mirror%/}"; \
    security="${security%/}"; \
    if [ -f /etc/apt/sources.list ]; then \
        sed -i "s|http://deb.debian.org|$mirror|g; s|https://deb.debian.org|$mirror|g; s|http://security.debian.org|$security|g; s|https://security.debian.org|$security|g" /etc/apt/sources.list; \
    fi; \
    if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
        sed -i "s|http://deb.debian.org|$mirror|g; s|https://deb.debian.org|$mirror|g; s|http://security.debian.org|$security|g; s|https://security.debian.org|$security|g" /etc/apt/sources.list.d/debian.sources; \
    fi
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    rm -f /var/lib/apt/lists/lock /var/cache/apt/archives/lock /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock; \
    apt-get update \
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
        libpcre2-8-0 \
        libpcre2-dev \
        libmagickwand-dev \
        imagemagick \
        ghostscript \
        ffmpeg \
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
    && docker-php-ext-enable redis opcache \
    && rm -f /usr/local/etc/php/conf.d/*xdebug*.ini \
    && rm -rf /var/lib/apt/lists/*

# Host-only tools (watchman, java) are intentionally not installed here.

COPY ./xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
COPY ./opcache.ini /usr/local/etc/php/conf.d/10-opcache.ini

WORKDIR /var/www/html
