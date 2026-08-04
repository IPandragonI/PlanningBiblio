#!/bin/bash
set -e

cp .env .env.local
sed -i "s|APP_SECRET=.*|APP_SECRET=$APP_SECRET|g" .env.local
sed -i "s|DATABASE_URL=.*|DATABASE_URL=mysql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME|g" .env.local
sed -i "s|APP_ENV=.*|APP_ENV=dev|g" .env.local
sed -i "s|DATABASE_PREFIX=.*|DATABASE_PREFIX=$DATABASE_PREFIX|g" .env.local

echo "Installing PHP dependencies with Composer..."
composer install --no-interaction --optimize-autoloader

php -d error_reporting=22527 bin/console cache:clear --no-warmup
php -d error_reporting=22527 bin/console cache:warmup

php -d error_reporting=22527 bin/console app:update-db || true

chmod -R 777 var
