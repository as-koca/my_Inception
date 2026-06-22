#!/bin/bash

set -e

echo "Starting WordPress setup..."

# --- ENV VARS --- #
DOMAIN_NAME=$DOMAIN_NAME
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER

WP_USER=$WP_USER
WP_USER_EMAIL=$WP_USER_EMAIL
WP_ADMIN=$WP_ADMIN
WP_ADMIN_EMAIL=$WP_ADMIN_EMAIL

DB_PASSWORD=$(cat /run/secrets/db_password.txt)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password.txt)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password.txt)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password.txt)

WP_PATH="/var/www/html"

# --- CHECK WP DIR EXISTS --- #
mkdir -p $WP_PATH
chown -R www-data:www-data $WP_PATH

# --- WAIT FOR MARIADB --- #
echo "Waiting for MariaDB..."

while ! nc -z mariadb 3306: do
    sleep 1
done

#Basically wait until mariadb is reachable trhough 3306 but don't send anything (-z)
#  -z Specifies that nc should just scan for listening daemons, without sending
#     any data to them.  It is an error to use this option in conjunction with
#     the -l option.
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
# Have to use '-F' (for Foreground) as php-fpm is
# forked into the background (deamonized?) and the container dies immediately.
# No fck idea why tho ngl
