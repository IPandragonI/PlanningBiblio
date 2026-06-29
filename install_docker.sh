#!/bin/bash
set -e

# Vérification du paramètre obligatoire
if [ -z "$1" ]; then
  echo "❌ Erreur : Vous devez spécifier le nom du client."
  echo "   Usage   : $0 <nom_du_client>"
  echo "   Exemple : $0 client1"
  exit 1
fi

CLIENT_ENV=$1
echo "🚀 Installation de Planno pour le client [$CLIENT_ENV] en mode Multi-Tenant..."

# Construction des noms spécifiques au client
CLIENT_DB_NAME="${DB_NAME}_${CLIENT_ENV}"
CLIENT_DB_USER="${DB_USER}_${CLIENT_ENV}"
CLIENT_DB_PASSWORD="${DB_PASSWORD}_${CLIENT_ENV}"
CLIENT_URL="http://sigbxx.${CLIENT_ENV}.planno"

# 1. Vérification de la connectivité avec la base de données
echo "⏳ En attente de MariaDB sur $DB_HOST:$DB_PORT ..."
MAX_WAIT=60
WAITED=0
until mysql -h"$DB_HOST" -P"$DB_PORT" -uroot -p"$DB_ROOT_PASSWORD" --ssl=0 -e "SELECT 1;" &> /dev/null; do
  sleep 2
  WAITED=$((WAITED + 2))
  if [ "$WAITED" -ge "$MAX_WAIT" ]; then
    echo "❌ Erreur : MariaDB n'a pas répondu après ${MAX_WAIT}s. Abandon."
    exit 1
  fi
done
echo "✅ MariaDB est prête et accessible."

# 2. Création de la base de données et de l'utilisateur dédié au client
echo "🛠️  Création de la base de données [$CLIENT_DB_NAME] et de l'utilisateur [$CLIENT_DB_USER]..."
mysql -h "$DB_HOST" -P "$DB_PORT" -uroot -p"$DB_ROOT_PASSWORD" --ssl=0 <<-EOSQL
  DROP DATABASE IF EXISTS $CLIENT_DB_NAME;
  CREATE DATABASE $CLIENT_DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
  CREATE USER IF NOT EXISTS '$CLIENT_DB_USER'@'%' IDENTIFIED BY '$CLIENT_DB_PASSWORD';
  GRANT ALL PRIVILEGES ON $CLIENT_DB_NAME.* TO '$CLIENT_DB_USER'@'%';
  FLUSH PRIVILEGES;
EOSQL

# 3. Importation du jeu de données initial
if [ -f data/planno_25.05.xx.sql.gz ]; then
  echo "📥 Importation des données initiales dans la base [$CLIENT_DB_NAME]..."
  zcat data/planno_25.05.xx.sql.gz | mysql -h "$DB_HOST" -P "$DB_PORT" -u "$CLIENT_DB_USER" -p"$CLIENT_DB_PASSWORD" --ssl=0 "$CLIENT_DB_NAME"
else
  echo "❌ Erreur : Aucun fichier de données initiales trouvé dans data/planno_25.05.xx.sql.gz."
  exit 1
fi

# 4. Configuration du compte administrateur par défaut
echo "👤 Configuration du compte administrateur pour le client [$CLIENT_ENV]..."
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$CLIENT_DB_USER" -p"$CLIENT_DB_PASSWORD" --ssl=0 <<-EOSQL
  UPDATE $CLIENT_DB_NAME.personnel
  SET nom='$ADMIN_LASTNAME',
      prenom='$ADMIN_FIRSTNAME',
      mail='$ADMIN_EMAIL',
      password=MD5('$ADMIN_PASSWORD')
  WHERE id = 1;
EOSQL

# 5. Génération du fichier d'environnement Symfony local
ENV_FILE=".env.${CLIENT_ENV}.local"
echo "📝 Génération du fichier de configuration Symfony [$ENV_FILE]..."
cp .env "$ENV_FILE"

sed -i "s|APP_ENV=.*|APP_ENV=${CLIENT_ENV}|g" "$ENV_FILE"
sed -i "s|APP_SECRET=.*|APP_SECRET=${APP_SECRET}_${CLIENT_ENV}|g" "$ENV_FILE"
sed -i "s|DATABASE_URL=.*|DATABASE_URL=mysql://$CLIENT_DB_USER:$CLIENT_DB_PASSWORD@$DB_HOST:$DB_PORT/$CLIENT_DB_NAME|g" "$ENV_FILE"
sed -i "s|DEFAULT_URI=.*|DEFAULT_URI=$CLIENT_URL|g" "$ENV_FILE"
sed -i "s|DATABASE_PREFIX=.*|DATABASE_PREFIX=$DATABASE_PREFIX|g" "$ENV_FILE"
# Alignement des variables DB_* avec la base/utilisateur réellement créés pour ce client.
# (DATABASE_URL est la seule lue par Doctrine, mais on garde DB_NAME/DB_USER/DB_PASSWORD
#  cohérents pour éviter toute confusion si un script ou un outil tiers les lit directement.)
sed -i "s|DB_NAME=.*|DB_NAME=${CLIENT_DB_NAME}|g" "$ENV_FILE"
sed -i "s|DB_USER=.*|DB_USER=${CLIENT_DB_USER}|g" "$ENV_FILE"
sed -i "s|DB_PASSWORD=.*|DB_PASSWORD=${CLIENT_DB_PASSWORD}|g" "$ENV_FILE"

# 6. Configuration du VirtualHost Apache pour le client
VHOST_DIR="/etc/apache2/clients-vhosts.d"
VHOST_FILE="${VHOST_DIR}/${CLIENT_ENV}.conf"

# Sécurité indispensable : recréer le dossier s'il a été masqué ou supprimé par le montage de volume
if [ ! -d "$VHOST_DIR" ]; then
  echo "📂 Le dossier des VirtualHosts n'existe pas. Création de $VHOST_DIR..."
  mkdir -p "$VHOST_DIR"
fi

echo "🌐 Génération de la configuration Apache du VirtualHost dans [$VHOST_FILE]..."
cat <<EOF > "$VHOST_FILE"
<VirtualHost *:80>
    ServerName sigbxx.${CLIENT_ENV}.planno
    DocumentRoot /var/www/html/public

    SetEnv APP_ENV ${CLIENT_ENV}

    <Directory /var/www/html/public>
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog \${APACHE_LOG_DIR}/${CLIENT_ENV}_error.log
    CustomLog \${APACHE_LOG_DIR}/${CLIENT_ENV}_access.log combined
</VirtualHost>
EOF

echo "🔄 Rechargement de la configuration du serveur Apache..."
apache2ctl -k graceful || true

# 7. Finalisation des dépendances et du cache Symfony
echo "📦 Installation et vérification des dépendances PHP avec Composer..."
composer install --no-interaction --optimize-autoloader --no-scripts

echo "🧹 Nettoyage et préparation du cache pour l'environnement [$CLIENT_ENV]..."
php -d error_reporting=22527 bin/console cache:clear --env="$CLIENT_ENV" --no-warmup
php -d error_reporting=22527 bin/console cache:warmup --env="$CLIENT_ENV"

echo "⚙️  Application des mises à jour des schémas de base de données pour [$CLIENT_ENV]..."
php -d error_reporting=22527 bin/console app:update-db --env="$CLIENT_ENV" || true

# Attribution des droits sur le dossier var (Caches et Logs)
# www-data est l'utilisateur sous lequel Apache/PHP tourne dans l'image officielle php:apache.
chown -R www-data:www-data var
chmod -R 775 var

echo ""
echo "✅ Installation terminée avec succès pour le client [$CLIENT_ENV] !"
echo "   🔗 URL d'accès  : $CLIENT_URL"
echo "   🔑 Identifiants : admin / $ADMIN_PASSWORD"