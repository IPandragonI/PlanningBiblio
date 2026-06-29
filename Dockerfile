FROM php:8.4-apache

RUN apt-get update && apt-get install -y \
    git unzip zlib1g-dev libzip-dev libicu-dev g++ libldap2-dev libxml2-dev libonig-dev mariadb-client \
    && docker-php-ext-install pdo pdo_mysql mysqli intl zip calendar \
    && docker-php-ext-configure ldap \
    && docker-php-ext-install ldap \
    && a2enmod rewrite headers

RUN pecl install xdebug \
    && docker-php-ext-enable xdebug

RUN echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name xdebug.so)" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.mode=debug" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.start_with_request=yes" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_host=host.docker.internal" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.client_port=9003" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini \
    && echo "xdebug.log_level=0" >> /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

RUN sed -i 's|/var/www/html|/var/www/html/public|g' /etc/apache2/sites-available/000-default.conf
RUN a2enmod rewrite headers

RUN apt-get update && apt-get install -y bash

RUN echo "display_errors=0\nerror_reporting=E_ALL & ~E_DEPRECATED & ~E_NOTICE" \
    > /usr/local/etc/php/conf.d/ignore-phpcas-warnings.ini

WORKDIR /var/www/html
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer