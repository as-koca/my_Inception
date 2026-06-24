*This activity has been created as part of the 42 curriculum by akoca.*
 
# Inception
 
## Description
 
Inception sets up a small web infrastructure inside a virtual machine using
Docker Compose. It runs three services, each in its own container built from a
custom Dockerfile (base image: Debian *bookworm*):
 
- **NGINX** — the sole entry point, serving HTTPS on port 443 with TLS 1.2/1.3
  only.
- **WordPress + php-fpm** — the website.
- **MariaDB** — the database storing WordPress content.
The services communicate over a private Docker network. Two volumes (the database
and the website files) are bind-mounted to `/home/akoca/data` on the host so data
persists across restarts. Credentials are kept out of the images using a `.env`
file and Docker secrets.
 
## Instructions
 
The domain `akoca.42.fr` must resolve locally — add to `/etc/hosts`:
 
```
127.0.0.1   akoca.42.fr
```
 
From the project root:
 
```bash
make        # build images and start the stack
make down   # stop the stack
make re     # full clean rebuild
```
 
Then open `https://akoca.42.fr` (accept the self-signed certificate). The admin
panel is at `https://akoca.42.fr/wp-admin`.
 
See `USER_DOC.md` and `DEV_DOC.md` for usage and development details.
 
## Project description
 
Each service has its own Dockerfile and runs a single foreground process as PID 1
(no daemonizing, no infinite-loop hacks), so Docker manages it correctly.
MariaDB and WordPress use entrypoint scripts that initialize the database and
site on first run and are idempotent on restart. NGINX is the only container that
publishes a port; the others are reachable only on the internal network.
 
### Technical comparisons
 
- **Virtual Machines vs Docker** — A VM emulates a full machine with its own
  kernel, making it heavy and slow to boot. A container shares the host kernel
  and isolates only the process and its filesystem, making it lightweight and
  fast. Inception runs *in* a VM but builds its services *as* containers.
- **Secrets vs Environment Variables** — Environment variables are convenient for
  non-sensitive configuration (names, the domain), but they are visible via
  `docker inspect` and the process environment. Secrets are mounted as files
  readable only inside the container, so passwords never appear in images,
  layers, or inspection output. Here, identifiers go in `.env`; passwords go in
  Docker secrets.
- **Docker Network vs Host Network** — Host networking shares the host's network
  stack directly, removing isolation. A custom Docker network gives the
  containers a private subnet where they reach each other by service name, while
  staying hidden from the host except for the one published port. Inception uses
  a dedicated bridge network.
- **Docker Volumes vs Bind Mounts** — A named volume is stored and managed by
  Docker in its own area. A bind mount maps a specific host directory into the
  container. Inception uses bind mounts so the data lives at a known host path
  (`/home/akoca/data`), as required.
## Resources
 
- Docker documentation — Dockerfiles, Compose, networks, volumes, secrets
- NGINX documentation — TLS configuration and FastCGI
- MariaDB and WordPress (WP-CLI) documentation
- Debian official base image
**Use of AI:** AI (Claude) was used as a learning and debugging aid throughout
this project. Specifically, it was used to explain underlying concepts (PID 1,
reverse proxying, the NGINX–php-fpm FastCGI handoff, Docker networking, volumes
vs bind mounts), to help diagnose runtime errors (notably a MariaDB bootstrap
failure and a WordPress idempotency bug), and to draft the documentation files.
The configuration files (Dockerfiles, `nginx.conf`, init scripts,
`docker-compose.yml`, `Makefile`) were written and reviewed by me, with AI
providing guidance rather than ready-made solutions.

