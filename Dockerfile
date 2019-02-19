FROM phpdockerio/php73-fpm:latest
LABEL vendor="cedrickoka/youtube-dl-api" maintainer="okacedrick@gmail.com" version="1.0.0"

WORKDIR "/app"

# Fix debconf warnings upon build
ARG DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get -y install git \
    && apt-get -y install cron gettext-base nano \
    && apt-get -y --no-install-recommends install ffmpeg python software-properties-common wget \
    && apt-get clean; rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /usr/share/doc/*

RUN wget https://yt-dl.org/downloads/latest/youtube-dl -O /usr/local/bin/youtube-dl \
	&& chmod a+rx /usr/local/bin/youtube-dl \
	&& hash -r

RUN php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');" \
	&& php composer-setup.php \
	&& php -r "unlink('composer-setup.php');" \
	&& mv composer.phar /usr/local/bin/composer \
	&& chmod +x /usr/local/bin/composer

RUN git clone -b 1.0.0 https://github.com/CedrickOka/youtube-dl-api.git ./ \
    && composer install --no-dev --no-interaction --optimize-autoloader --classmap-authoritative \
    && composer clear-cache

ARG APP_SECRET=598d01f22edceea6bf7c5ace30929f41
ARG ASSETS_DIR=/opt/youtube-dl/downloads

ENV APP_ENV=prod
ENV APP_SECRET=$APP_SECRET
ENV ASSETS_DIR=$ASSETS_DIR
ENV LC_ALL=C

COPY php-ini-overrides.ini /etc/php/7.3/fpm/conf.d/99-overrides.ini
COPY youtube-dl.conf /etc/youtube-dl.conf

RUN envsubst < /etc/youtube-dl.conf > /etc/youtube-dl.conf \
	&& chmod 0755 /etc/youtube-dl.conf \
	&& mkdir -p $ASSETS_DIR \
	&& chown -R www-data:www-data $ASSETS_DIR \
	&& chmod -R 0755 $ASSETS_DIR
VOLUME ["$ASSETS_DIR"]

RUN php bin/console cache:clear -e prod --no-debug \
	&& chmod -R 0777 var/

# create cron log
RUN touch /var/log/cron.log \
	&& ln -sf /dev/stdout /var/log/cron.log

# add crontab file
ADD cron /etc/cron.d/cron
RUN chmod 0644 /etc/cron.d/cron \
	&& /usr/bin/crontab /etc/cron.d/cron

ADD entrypoint.sh /entrypoint.sh
RUN chmod 0777 /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
