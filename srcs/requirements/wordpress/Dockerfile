FROM debian:bookworm

RUN apt update && apt install -y curl \
    php-fpm php-mysql php-curl netcat-openbsd

RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

COPY conf/www.conf /etc/php/8.2/fpm/pool.d/

COPY --chmod=755 tools/init.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/init.sh"]

# php-fpm: PHP-FPM executes the PHP code.
# php-mysql: Allows PHP to talk to MariaDB.
# php-curl: Many WordPress operations use curl internally. Not always strictly required, but commonly installed.
# curl: Transfers a URL. We use it to download WP-CLI.
# netcat-openbsd: the 'nc' command used in init isn't installed by default on bookworm

# we then install wp-cli with curl (litterally took it from 'Make WordPress')
# make it executable otherwise using "wp" would crash.
# move it to /bin so we can use it from anywhere

# To find where the config file is stored:
# docker run --rm -it debian:bookworm bash
# apt update && apt install -y php-fpm
# find /etc/php -name "php-fpm.conf"

#installed binary by default is php-fpm8.2'
