FROM debian:bookworm

RUN apt update && apt install -y nginx openssl

RUN mkdir -p /etc/nginx/ssl

RUN openssl req -x509 -nodes -days 365 \
	-newkey rsa:2048 \
	-keyout /etc/nginx/ssl/nginx.key \
	-out /etc/nginx/ssl/nginx.crt \
	-subj "/CN=akoca.42.fr"

COPY conf/nginx.conf /etc/nginx/nginx.conf

CMD ["nginx", "-g", "daemon off;"]

# -g directives — set global configuration directives
# daemon off; overrides nginx's default self-backgrounding
# so it runs in the foreground, staying as PID 1

#The openssl req block:
# — generates a self-signed certificate (-x509)
# a 2048-bit RSA key (-newkey rsa:2048)
# unencrypted (-nodes, so nginx can read the key without a passphrase prompt at boot \
# — important, otherwise nginx would hang waiting for input)
# valid 365 days (-days 365)
# writing key and cert to the paths made (/etc/nginx/ssl/...)
# -subj "/CN=akoca.42.fr" sets the cert's Common Name non-interactively \
# (without it, openssl would prompt you during build and hang)
