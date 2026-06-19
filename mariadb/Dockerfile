FROM debian:bookworm

RUN  apt update &&  apt install --assume-yes mariadb-server

#On Debian, MariaDB reads configs from locations under: /etc/mysql/
COPY conf/my.cnf /etc/mysql/

#A common place for scripts is: /usr/local/bin/
COPY --chmod=755 tools/init.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/init.sh"]