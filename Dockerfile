FROM php:8.1-fpm-alpine as base
WORKDIR /app
RUN set -x \
    && apk add --no-cache icu-libs bash \
    && apk add --no-cache --virtual .build-deps icu-dev autoconf openssl make g++ \
    && docker-php-ext-install -j$(nproc) sockets opcache pcntl intl 1>/dev/null \
    && docker-php-source delete \
        && apk del .build-deps \
        && php -r "readfile('http://getcomposer.org/installer');" | php -- --install-dir=/usr/bin/ --filename=composer

COPY ./composer.* /app/
RUN composer install -n --no-dev --no-cache --no-ansi --no-autoloader --no-scripts --prefer-dist


FROM base as backend
COPY --chown=www-data:www-data . /app/
RUN composer dump-autoload -n --optimize
COPY .environment/backend/zzz-php-fpm-config.conf /usr/local/etc/php-fpm.d/zzz-php-fpm-config.conf
EXPOSE 9000

FROM base as frontend
RUN apk add --no-cache nodejs npm
COPY package.json ./
RUN npm install
COPY . .
RUN npm run build

FROM nginx:stable-alpine as webserver
WORKDIR /www
COPY --from=frontend /app/public /www
COPY .environment/webserver/nginx.conf /etc/nginx/nginx.conf

EXPOSE 8080 443


