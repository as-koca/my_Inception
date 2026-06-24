# DEV_DOC.md — Developer Documentation

Developer documentation for the **Inception** project: a multi-service Docker
infrastructure (NGINX + WordPress/php-fpm + MariaDB) orchestrated with Docker
Compose, running inside a virtual machine.

---

## 1. Prerequisites

The project is developed and run **inside a virtual machine** (the whole stack
must run in a VM per the subject). The host is irrelevant to the build as long
as it can run the VM.

Inside the VM you need:

- **Debian** (penultimate stable — *bookworm*, used both as the VM OS and as the
  base image for every service Dockerfile).
- **Docker Engine** + the **Docker Compose plugin** (`docker compose`, v2),
  installed from Docker's official apt repository.
- **make**, **git**.
- Network access (the image builds download the Debian base image and install
  packages via `apt`).
- A few GB of free disk space. Docker stores images and build cache under
  `/var/lib/docker`; on a small VM consider relocating Docker's `data-root` to a
  partition with room, or enlarging the disk.

Verify Docker is working before building:

```bash
docker --version
docker compose version
sudo systemctl status docker
```

---

## 2. Repository layout

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── secrets/                      # local-only, gitignored
│   ├── db_password.txt
│   ├── db_root_password.txt
│   ├── wp_admin_password.txt
│   └── wp_user_password.txt
└── srcs/
    ├── .env                      # local-only, gitignored
    ├── docker-compose.yml
    └── requirements/
        ├── mariadb/
        │   ├── Dockerfile
        │   ├── conf/             # MariaDB config (bind-address, etc.)
        │   └── tools/init.sh     # runtime init: DB + users, then exec mariadbd
        ├── nginx/
        │   ├── Dockerfile        # also generates the self-signed cert
        │   └── conf/nginx.conf   # TLS 1.2/1.3, server block, php FastCGI
        └── wordpress/
            ├── Dockerfile
            └── tools/init.sh     # wait for DB, install WP, create users, exec php-fpm
```

---

## 3. Configuration files and secrets

### 3.1 Environment variables — `srcs/.env`

Non-sensitive configuration (identifiers, names, domain). **Gitignored.**

```env
DOMAIN_NAME=akoca.42.fr
MYSQL_DATABASE=maria
MYSQL_USER=akoca
WP_USER=Spike
WP_USER_EMAIL=totally_legit@email.com
WP_ADMIN=BigGuy
WP_ADMIN_EMAIL=also_legit_email@tech.smth
```

These are injected into the containers via the `env_file:` directive in
`docker-compose.yml`. The init scripts read them as ordinary shell variables
(e.g. `$MYSQL_DATABASE`).

### 3.2 Secrets — `secrets/*.txt`

Sensitive values (passwords) are **never** placed in `.env`, the Dockerfiles, or
the images. They are stored as plain files under `secrets/`, declared as Docker
secrets in `docker-compose.yml`, and mounted read-only into the containers at
`/run/secrets/<name>`. The init scripts read them with `cat`:

```bash
DB_PASSWORD=$(cat /run/secrets/db_password)
```

Secrets used:

| Secret              | Used by   | Purpose                         |
|---------------------|-----------|---------------------------------|
| `db_password`       | mariadb, wordpress | WordPress DB user password |
| `db_root_password`  | mariadb   | MariaDB root password           |
| `wp_admin_password` | wordpress | WordPress admin account         |
| `wp_user_password`  | wordpress | WordPress second (author) user  |

> **Both `secrets/*.txt` and `srcs/.env` must be gitignored and never
> committed.** Committed credentials cause automatic project failure. Verify with
> `git ls-files | grep -E '\.env|secrets'` (should return nothing).

---

## 4. Building and launching

### 4.1 With the Makefile

The Makefile sets up the entire application by building the images and starting
the stack via Docker Compose. It also creates the host directories the bind
mounts depend on.

```bash
make
make down
make clean
make fclean
make re
```

### 4.2 Directly with Docker Compose

From `srcs/`:

```bash
docker compose up --build -d      # build images and start detached
docker compose up --build         # same, attached (watch logs live) — useful for debugging
docker compose down               # stop and remove containers and network
docker compose down -v            # same, removes volumes too.
```

### 4.3 Host prerequisite for the bind mounts

Because the volumes are **bind mounts** to explicit host paths, those paths must
exist before the stack starts (the Makefile handles this):

```bash
mkdir -p /home/akoca/data/mariadb /home/akoca/data/wordpress
```

### 4.4 Domain resolution

Add the project domain to the VM's hosts file so the browser/curl can resolve it
to the local machine where NGINX listens:

```
127.0.0.1   akoca.42.fr
```

---

## 5. Managing containers and volumes

```bash
docker compose ps -a              # status of all containers (up / restarting / exited)
docker compose logs               # all logs
docker compose logs -f <service>  # follow one service's logs
docker compose exec mariadb mariadb -u root -p   # shell into the DB as root

docker exec -it <container> sh    # shell into a running container
docker compose exec nginx nginx -t               # validate nginx config

docker system df                  # disk usage by images/containers/cache
docker system prune -a            # reclaim space (removes unused images + cache)
```

Notes:

- Containers are named `inception-<service>-1` by default (project name
  `inception` + service + index). Use `docker compose exec <service>` to avoid
  tracking the suffix.
- All services use `restart: always`, so a crashing container re-launches in a
  loop — a service stuck in `Restarting` means its main process keeps dying;
  read that service's logs for the cause.

---

## 6. Where data lives and how it persists

The stack defines **two persistent stores**, both bind-mounted from the VM host
into the containers:

| Host path (VM)                  | Container path     | Service   | Contents                         |
|---------------------------------|--------------------|-----------|----------------------------------|
| `/home/akoca/data/mariadb`      | `/var/lib/mysql`   | mariadb   | Database files (system + WP DB)  |
| `/home/akoca/data/wordpress`    | `/var/www/html`    | wordpress | WordPress core, config, uploads  |

The WordPress files volume is **also** mounted into the NGINX container at
`/var/www/html`, so NGINX can serve static files directly and reach `index.php`.

**Persistence model:** containers are disposable; the data is not. Because the
data directories live on the host via bind mounts, they survive
`docker compose down`, image rebuilds, and container recreation. The init
scripts are **idempotent** and detect existing data so they do not re-initialize
on restart:

- **MariaDB** — `tools/init.sh` checks for `/var/lib/mysql/mysql` (the system
  database directory). Present ⇒ skip initialization, just launch `mariadbd`.
- **WordPress** — `tools/init.sh` guards each step independently: download
  guarded by `wp-load.php`, config by `wp-config.php`, install/users by
  `wp core is-installed`. An already-installed site skips straight to php-fpm.

**Resetting data** (forces a clean first-run on next launch):

```bash
docker compose down
sudo rm -rf /home/akoca/data/mariadb/* /home/akoca/data/wordpress/*
```

> Important: whenever an init script's setup logic changes, the persisted volume
> still holds the *old* result — the idempotency guard will skip re-running. To
> apply changes you must wipe the relevant data directory and bring the stack up
> again.

---

## 7. Verifying a correct setup

```bash
# All three containers up; only nginx publishes 443
docker compose ps -a

# Database user and schema exist
docker compose exec mariadb mariadb -u root -p -e \
  "SELECT user,host FROM mysql.user; SHOW DATABASES;"

# Full chain (TLS termination -> php-fpm -> MariaDB)
curl -k https://akoca.42.fr

# TLS restricted to 1.2/1.3
openssl s_client -connect akoca.42.fr:443 -tls1_2   # connects
openssl s_client -connect akoca.42.fr:443 -tls1_1   # refused

# Idempotency: second start must skip all init and keep data
docker compose down && docker compose up -d
docker compose logs wordpress    # no "Downloading" / no user-create errors
```
