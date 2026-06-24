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

DB_PASSWORD=$(cat /run/secrets/db_password)
WP_USER_PASSWORD=$(cat /run/secrets/wp_user_password)
WP_ADMIN_PASSWORD=$(cat /run/secrets/wp_admin_password)

WP_PATH="/var/www/html"
#This is the default path that the more popular web servers use as the default.
#Gonna be php and wp related files along the wp volume. (wp-config.php, themes, plugin, uploads, core files)

# --- WAIT FOR MARIADB --- #
echo "Waiting for MariaDB..."

while ! nc -z mariadb 3306; do
    sleep 1
done

echo "MariaDB is ready!"
#Basically waits until mariadb is reachable through 3306 but don't send anything (-z)
#  -z Specifies that nc should just scan for listening daemons, without sending
#     any data to them.

# --- DOWNLOAD WP IF NEEDED --- #
if [ ! -f "$WP_PATH/wp-load.php" ]; then
    echo "Downloading WordPress..."
    # wp core installs, downloads, updates , manages wordpress installations
    # download wordpress
    wp core download --path=$WP_PATH --allow-root
fi

# --- CREATE CONFIG (checking if exists too) --- #
if [ ! -f "$WP_PATH/wp-config.php" ]; then
    echo "Creating config..."	
    # wp config generates and reads the wp-config.php file.
     wp config create \
        --path=$WP_PATH \
        --dbname=$DB_NAME \
        --dbuser=$DB_USER \
        --dbpass=$DB_PASSWORD \
        --dbhost=mariadb \
        --allow-root
fi

# --- INSTALL + USERS --- # (multiple checks if install failed halfway and retried)
if ! wp core is-installed --path=$WP_PATH --allow-root; then
    echo "Installing Wordpress..."
    # set up wordpress
    wp core install \
        --path=$WP_PATH \
        --url="https://$DOMAIN_NAME" \
        --title="Inception" \
        --admin_user=$WP_ADMIN \
        --admin_password=$WP_ADMIN_PASSWORD \
        --admin_email=$WP_ADMIN_EMAIL \
        --skip-email \
        --allow-root

    # wp user manages users, along with their roles, capabilities, and meta.
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

# --- GIVE OWNERSHIP OF FILES TO WP --- #
chown -R www-data:www-data $WP_PATH

exec php-fpm8.2 -F
# Have to use '-F' (for Foreground) as php-fpm is
# forked into the background (deamonized?) and the container dies immediately.
# No fck idea why tho ngl
