#!/bin/bash

set -e

#will expose the env vars through the docker-compose file
DB_NAME=$MYSQL_DATABASE
DB_USER=$MYSQL_USER
DB_PASSWORD=$(cat /run/secrets/db_password)
DB_ROOT_PASSWORD=$(cat /run/secrets/db_root_password)

mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld
chown -R mysql:mysql /var/lib/mysql

if [ ! -d "/var/lib/mysql/mysql" ]; then
	echo "Initializing MariaDB..."
	mariadb-install-db --user=mysql --datadir=/var/lib/mysql
	mariadbd --user=mysql --bootstrap <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOT_PASSWORD}';

CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;

CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';

GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';

EOF
	echo "Database initialized."
fi

echo "Starting MariaDB..."
exec mariadbd --user=mysql

# PID = Process ID, every running process gets a number in linux.
# ps -ef
# In a Docker container, the main service should become PID 1.
# Docker sends signals (SIGTERM) to PID 1 when stopping the container.
# Using exec replaces the shell with mariadbd so MariaDB becomes PID 1.
# Works since its not a VM, so the PID isn't to launch but to do whatever we docker run

# We want the volume to be accesible even later so if we change the image
# or if MariaDB crashes its gonna restart but
# we still keep the collected data and don't lose it.