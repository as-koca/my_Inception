#!/bin/bash

set -e

echo "Starting WordPress setup..."

# --- ENV VARS --- #
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_PASSWORD=$(cat /run/secrets/db_password)
DP_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)
WP_PATH="/var/www/html"

# --- CHECK WP DIR EXISTS --- #
mkdir -p $WP_PATH
chown -R www-data:www-data $WP_PATH

# --- WAIT FOR MARIADB --- #
echo "Waiting for MariaDB..."

while ! nc -z mariadb 3306: do
    sleep 1
done

echo "MariaDB is ready!"

# --- DOWNLOAD WP IF NEEDED --- #
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Downloading WordPress..."

    wp core download --path=$WP_PATH --allow-root

    wp config create \
        --path=$WP_PATH \
        --dbname=$DB_NAME \
        --dbuser=$DB_USER \
        --dbpass=$DB_PASSWORD \
        --dbhost=mariadb \
        --allow-root

    wp core install \
        --path=$WP_PATH \
        --url="https://$DOMAIN_NAME" \
        --title="Inception" \
        --admin_user=$WP_ADMIN \
        --admin_password=$WP_ADMIN_PASSWORD \
        --admin_email=$WP_ADMIN_EMAIL \
        --skip-email \
        --allow-root

    # Create second (non-admin) user
    wp user create $WP_USER $WP_USER_EMAIL \
        --role=author \
        --user_pass=$WP_USER_PASSWORD \
        --path=$WP_PATH \
        --allow-root

    echo "WordPress installed."
fi

# --- START PHP-FPM --- #
echo "Starting PHP-FPM..."

exec php-fpm8.2 -F
