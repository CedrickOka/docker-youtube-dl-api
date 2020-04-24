FROM php:7.3-fpm
LABEL vendor="cedrickoka/youtube-dl-api" maintainer="okacedrick@gmail.com" version="2.0.0"
WORKDIR /app

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive

## Install system dependencies
RUN apt-get update && \
	apt-get -y --no-install-recommends install \
		cron \
    	ffmpeg \
    	git \
    	gettext-base \
    	libicu-dev \
    	librabbitmq-dev \
    	libzip-dev \
    	python \
    	software-properties-common \
    	supervisor && \
    apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

## Install php extensions
RUN pecl install amqp apcu xdebug && \
    docker-php-ext-enable amqp apcu xdebug && \
    docker-php-ext-install bcmath intl opcache sysvmsg

## Install composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer && \
	composer global require hirak/prestissimo

## Install youtube-dl
RUN curl -L https://yt-dl.org/downloads/latest/youtube-dl -o /usr/local/bin/youtube-dl && \
	chmod a+rx /usr/local/bin/youtube-dl

RUN git clone -b 3.0.2 https://github.com/CedrickOka/youtube-dl-api.git ./ && \
    composer install --no-dev --no-interaction --optimize-autoloader --classmap-authoritative && \
    composer clear-cache

## Copy php default configuration
RUN mv $PHP_INI_DIR/php.ini-production $PHP_INI_DIR/php.ini
COPY ./php-ini-overrides.ini $PHP_INI_DIR/conf.d/99-overrides.ini
COPY ./php-fpm-overrides.conf /usr/local/etc/php-fpm.d/z-overrides.conf
COPY supervisor.conf /etc/supervisor/conf.d/messenger.conf
COPY youtube-dl.conf /etc/youtube-dl.conf

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
ADD crontab /etc/cron.d/update-cron
RUN chmod +x /etc/cron.d/update-cron && \
	touch /var/log/cron.log && \
	ln -sf /dev/stdout /var/log/cron.log && \
	/usr/bin/crontab /etc/cron.d/update-cron

ADD entrypoint /usr/local/bin/entrypoint
RUN chmod +x /usr/local/bin/entrypoint

## Disable xdebug on production
#RUN rm $PHP_INI_DIR/conf.d/docker-php-ext-xdebug.ini

## Cleanup
RUN composer global remove hirak/prestissimo && \
    rm /usr/local/bin/composer

ENTRYPOINT ["entrypoint"]
