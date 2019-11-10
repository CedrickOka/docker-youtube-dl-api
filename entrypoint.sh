#!/bin/bash

envsubst < /etc/youtube-dl.conf > /etc/youtube-dl.conf

# Start supervisor
supervisord -c /etc/supervisor/supervisord.conf

cron && /usr/sbin/php-fpm7.3 --nodaemonize
