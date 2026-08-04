#!/bin/bash
set -e

echo "Installing Planno in DEV mode..."

echo "Waiting for MariaDB at $DB_HOST:$DB_PORT ..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -uroot -p"$DB_ROOT_PASSWORD" --ssl=0 -e "SELECT 1;" &> /dev/null; do
  sleep 2
done
echo "MariaDB is up"

echo "Creating database $DB_NAME ..."
mysql -h "$DB_HOST" -P "$DB_PORT" -uroot -p"$DB_ROOT_PASSWORD" --ssl=0 <<-EOSQL
  DROP DATABASE IF EXISTS $DB_NAME;
  CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASSWORD';
  GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'%';
  FLUSH PRIVILEGES;
EOSQL

if [ -f data/planno_25.05.xx.sql.gz ]; then
  echo "Importing initial data..."
  zcat data/planno_25.05.xx.sql.gz | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" --ssl=0 "$DB_NAME"
else
  echo "No initial data to import, please check the data/planno_25.05.xx.sql.gz file."
  exit 1
fi

mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASSWORD" --ssl=0 <<-EOSQL
  UPDATE $DB_NAME.personnel
  SET nom='$ADMIN_LASTNAME',
      prenom='$ADMIN_FIRSTNAME',
      mail='$ADMIN_EMAIL',
      password=MD5('$ADMIN_PASSWORD')
  WHERE id = 1;
EOSQL

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

echo ""
echo "✅ DEV Installation finished!"
echo "   URL: http://localhost:8081"
echo "   Admin login: admin / $ADMIN_PASSWORD"
