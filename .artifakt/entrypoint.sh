#!/bin/bash

set -e

echo ">>>>>>>>>>>>>> START CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "

# set runtime env. vars on the fly
export APP_ENV=prod
export APP_DATABASE_NAME=${ARTIFAKT_MYSQL_DATABASE_NAME:-changeme}
export APP_DATABASE_USER=${ARTIFAKT_MYSQL_USER:-changeme}
export APP_DATABASE_PASSWORD=${ARTIFAKT_MYSQL_PASSWORD:-changeme}
export APP_DATABASE_HOST=${ARTIFAKT_MYSQL_HOST:-mysql}
export APP_DATABASE_PORT=${ARTIFAKT_MYSQL_PORT:-3306}

echo "APP_DATABASE_NAME=${APP_DATABASE_NAME}"         >  /var/www/html/pim-community-standard/.env.local
echo "APP_DATABASE_USER=${APP_DATABASE_USER}"         >> /var/www/html/pim-community-standard/.env.local
echo "APP_DATABASE_PASSWORD=${APP_DATABASE_PASSWORD}" >> /var/www/html/pim-community-standard/.env.local

chown www-data:www-data /var/www/html/pim-community-standard/.env.local
chown -R www-data:www-data /var/www/html/pim-community-standard/config

ES_PROTOCOL=""
if [[ "$ARTIFAKT_ES_PORT" == "443" ]]; then
  ES_PROTOCOL="https://"
fi
export APP_INDEX_HOSTS=${ES_PROTOCOL:-http://}${ARTIFAKT_ES_HOST:-elasticsearch}:${ARTIFAKT_ES_PORT:-9200}

wait-for ${ARTIFAKT_ES_HOST:-elasticsearch}:${ARTIFAKT_ES_PORT:-9200} --timeout=30

wait-for $APP_DATABASE_HOST:3306 --timeout=90 -- su --preserve-environment www-data -s /bin/bash -c '
  cd /var/www/html/pim-community-standard
  ./bin/console pim:system:information 2>/dev/null;

  if [ $? -ne 0 ]; then
  	echo FIRST DEPLOYMENT, will run default installer
    APP_ENV=dev php bin/console pim:installer:db --doNotDropDatabase --catalog vendor/akeneo/pim-community-dev/src/Akeneo/Platform/Bundle/InstallerBundle/Resources/fixtures/minimal    
    php ./bin/console pim:user:create admin password123 user@example.com Admin User en_US --admin -n
  else
  	echo FOUND INSTALLED SYSTEM, will not run installer
  fi
'

echo ">>>>>>>>>>>>>> END CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "
