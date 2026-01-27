FROM php:8.5.2-apache

# Установка системных зависимостей и расширений PHP
RUN apt-get update && apt-get install -y \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libzip-dev \
    libicu-dev \
    libxml2-dev \
    libonig-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) \
    mysqli \
    pdo \
    pdo_mysql \
    gd \
    zip \
    intl \
    mbstring \
    xml \
    curl \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Копирование Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Включение mod_rewrite для Apache
RUN a2enmod rewrite

# Установка рабочей директории
WORKDIR /var/www/html

RUN usermod -u 1000 www-data && groupmod -g 1000 www-data \
    && chown -R www-data:www-data /var/www/html \
    && chown -R www-data:www-data /var/run/apache2 \
    && chown -R www-data:www-data /var/log/apache2 \
    && chown -R www-data:www-data /var/lock/apache2

# Открытие порта 80
EXPOSE 80

CMD ["apache2-foreground"]
