FROM php:7.4-fpm-alpine
LABEL vendor="cedrickoka/youtube-dl-api" maintainer="okacedrick@gmail.com" version="3.0.0"

WORKDIR /app

## Install system dependencies
RUN apk update && \
    apk add --no-cache --virtual dev-deps \
	    autoconf \
	    gcc \
	    git \
	    g++ \
	    make && \
    apk add --no-cache \
    	ffmpeg \
    	icu-dev \
	    gettext \
    	git \
    	libxml2-dev \
    	libzip-dev \
    	python3 \
    	py3-setuptools \
    	supervisor \
    	zlib-dev

## Install php extensions
RUN pecl install apcu && \
    docker-php-ext-enable apcu && \
    docker-php-ext-install intl opcache sysvmsg

## Copy php default configuration
RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY php-ini-overrides.ini $PHP_INI_DIR/conf.d/99-overrides.ini
COPY php-fpm-overrides.conf /usr/local/etc/php-fpm.d/z-overrides.conf

## Install youtube-dl
RUN curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && \
	chmod a+rx /usr/local/bin/youtube-dl

## Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
	composer global require hirak/prestissimo

RUN git clone -b 3.1.1 https://github.com/CedrickOka/youtube-dl-api.git ./ && \
    composer install --no-dev --no-interaction --optimize-autoloader --classmap-authoritative && \
    composer clear-cache

## Add dependencies files
COPY youtube-dl.conf /etc/youtube-dl.conf
COPY supervisor.ini /etc/supervisor.d/messenger.ini

## Change files owner to php-fpm default user
RUN mkdir -p /opt/youtube-dl/downloads && \
	chown -R www-data:www-data ./ /opt/youtube-dl/downloads && \
	chmod -R 0755 /etc/youtube-dl.conf /opt/youtube-dl/downloads

ENV APP_ENV=prod
ENV APP_LOCALE=en
ENV APP_SECRET=3e71c228f60ccb937b7784cc072e0b61
ENV MESSENGER_TRANSPORT_DSN=semaphore://localhost%kernel.project_dir%/.env
ENV ASSETS_DIR=/opt/youtube-dl/downloads
ENV FILE_UNIX_OWNER=www-data
ENV SHELL_VERBOSITY=-1
ENV PROCESS_NUMBER=2
ENV LC_ALL=C.UTF-8

# Configure crontab
ADD crontab /crontab
RUN /usr/bin/crontab /crontab

## Cleanup
RUN apk del dev-deps && \
    composer global remove hirak/prestissimo && \
    rm /usr/local/bin/composer

COPY entrypoint /usr/local/bin/entrypoint
RUN	chmod +x /usr/local/bin/entrypoint
## Change files owner to php-fpm default user
RUN mkdir -p /opt/youtube-dl/downloads && \
	chown -R www-data:www-data ./ /opt/youtube-dl/downloads && \
	chmod -R 0755 /etc/youtube-dl.conf /opt/youtube-dl/downloads

CMD ["entrypoint"]
