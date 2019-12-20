FROM phpdockerio/php73-fpm:latest
LABEL vendor="cedrickoka/youtube-dl-api" maintainer="okacedrick@gmail.com" version="1.0.0"

WORKDIR "/app"

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive

# Install selected extensions and other stuff
RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    	php-amqp \
    	php-apcu \
    	php7.3-bcmath \
    	php7.3-intl \
    	php-xdebug && \
    apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN apt-get update && \
	apt-get -y --no-install-recommends install cron && \
	apt-get -y --no-install-recommends install \
    	git \
    	ffmpeg \
    	gettext-base \
    	python \
    	software-properties-common \
    	supervisor \
    	wget && \
    apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl && \
	chmod a+rx /usr/local/bin/youtube-dl && \
	hash -r

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" && \
	php composer-setup.php && \
	php -r "unlink('composer-setup.php');" && \
	mv composer.phar /usr/local/bin/composer && \
	chmod +x /usr/local/bin/composer

RUN git clone -b 2.3.0 https://github.com/CedrickOka/youtube-dl-api.git ./ && \
    composer install --no-dev --no-interaction --optimize-autoloader --classmap-authoritative && \
    composer clear-cache

ENV APP_ENV=prod
ENV APP_LOCALE=en
ENV APP_SECRET=598d01f22edceea6bf7c5ace30929f41
ENV MESSENGER_TRANSPORT_DSN=semaphore://localhost%kernel.project_dir%/.env
ENV ASSETS_DIR=/opt/youtube-dl/downloads
ENV SHELL_VERBOSITY=-1
ENV LC_ALL=C.UTF-8

COPY php-ini-overrides.ini /etc/php/7.3/fpm/conf.d/99-overrides.ini
COPY supervisor.conf /etc/supervisor/conf.d/supervisor.conf
COPY youtube-dl.conf /etc/youtube-dl.conf

RUN mkdir -p /opt/youtube-dl/downloads && \
	chown -R www-data:www-data /opt/youtube-dl/downloads && \
	chmod -R 0755 /opt/youtube-dl/downloads && \
	chmod 0755 /etc/youtube-dl.conf

RUN php bin/console cache:clear -e prod --no-debug && \
	chmod -R 0777 var/

# Create cron log
RUN touch /var/log/cron.log && \
	ln -sf /dev/stdout /var/log/cron.log

# Add crontab file
ADD cron /etc/cron.d/cron
RUN chmod 0644 /etc/cron.d/cron && \
	/usr/bin/crontab /etc/cron.d/cron

ADD entrypoint.sh /entrypoint.sh
RUN chmod 0777 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
