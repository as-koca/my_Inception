FROM debian:bookworm

RUN apt update && apt install --assume-yes mariadb-server

COPY conf/my.cnf /etc/mysql/

COPY --chmod=755 tools/init.sh /usr/local/bin/

ENTRYPOINT ["/usr/local/bin/init.sh"]
