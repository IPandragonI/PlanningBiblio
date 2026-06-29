#!/bin/bash
set -e

# Charger le fichier .env global pour récupérer les accès root
if [ -f .env ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    line=$(echo "$line" | tr -d '\r')
    if [[ ! "$line" =~ ^# ]] && [[ ! -z "$line" ]]; then
      if [[ "$line" == *"="* ]]; then
        key=$(echo "$line" | cut -d '=' -f1)
        value=$(echo "$line" | cut -d '=' -f2- | sed -e 's/^"//' -e 's/"$//')
        export "$key"="$value"
      fi
    fi
  done < .env
fi

if [ -z "$1" ] || [ -z "$2" ]; then
  echo "❌ Erreur : Paramètres manquants."
  echo "   Usage   : $0 <network_id> <client_name>"
  echo "   Exemple : $0 123456 vannes"
  exit 1
fi

NETWORK_ID=$1
CLIENT_NAME=$2

CLIENT_DB_NAME="${DB_NAME}_${CLIENT_NAME}"
CLIENT_DB_USER="${DB_USER}_${CLIENT_NAME}"
CLIENT_DB_PASSWORD="${DB_PASSWORD}_${CLIENT_NAME}"

echo "🚀 Préparation du Tenant [$CLIENT_NAME] (Network ID: $NETWORK_ID)..."

echo "⏳ En attente de MariaDB..."
until mysql -h"$DB_HOST" -P"$DB_PORT" -uroot -p"$DB_ROOT_PASSWORD" --ssl=0 -e "SELECT 1;" &> /dev/null; do
  sleep 2
done

echo "🛠️  Création de la base [$CLIENT_DB_NAME]..."
mysql -h "$DB_HOST" -P "$DB_PORT" -uroot -p"$DB_ROOT_PASSWORD" --ssl=0 <<-EOSQL
  DROP DATABASE IF EXISTS $CLIENT_DB_NAME;
  CREATE DATABASE $CLIENT_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '$CLIENT_DB_USER'@'%' IDENTIFIED BY '$CLIENT_DB_PASSWORD';
  GRANT ALL PRIVILEGES ON $CLIENT_DB_NAME.* TO '$CLIENT_DB_USER'@'%';
  FLUSH PRIVILEGES;
EOSQL

if [ -f data/planno_25.05.xx.sql.gz ]; then
  echo "📥 Importation du schéma initial..."
  zcat data/planno_25.05.xx.sql.gz | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$CLIENT_DB_USER" -p"$CLIENT_DB_PASSWORD" --ssl=0 "$CLIENT_DB_NAME"
else
  echo "❌ Erreur : data/planno_25.05.xx.sql.gz introuvable."
  exit 1
fi

echo "👤 Configuration du compte admin pour le tenant..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$CLIENT_DB_USER" -p"$CLIENT_DB_PASSWORD" --ssl=0 <<-EOSQL
  UPDATE $CLIENT_DB_NAME.personnel
  SET nom='$ADMIN_LASTNAME', prenom='$ADMIN_FIRSTNAME', mail='$ADMIN_EMAIL', password=MD5('$ADMIN_PASSWORD')
  WHERE id = 1;
EOSQL

# Inscription du tenant dans config/tenants.php
TENANTS_FILE="config/tenants.php"
echo "📝 Inscription du mapping dans $TENANTS_FILE..."

# Si le fichier n'existe pas ou est vide, on l'initialise
if [ ! -f "$TENANTS_FILE" ] || [ ! -s "$TENANTS_FILE" ]; then
  echo -e "<?php\nreturn [\n];" > "$TENANTS_FILE"
fi

# Supprimer la dernière ligne ]; pour insérer la nouvelle configuration
sed -i '$d' "$TENANTS_FILE"

# Ajouter l'entrée
cat <<EOF >> "$TENANTS_FILE"
    '$NETWORK_ID' => [
        'dbname' => '$CLIENT_DB_NAME',
        'user' => '$CLIENT_DB_USER',
        'password' => '$CLIENT_DB_PASSWORD',
    ],
];
EOF

echo "🧹 Nettoyage du cache unique (prod/dev)..."
rm -rf var/cache/*
php bin/console cache:clear

echo "✅ Tenant [$CLIENT_NAME] configuré avec succès !"