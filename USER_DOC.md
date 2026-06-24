# USER_DOC.md — User Documentation

User and administrator documentation for the **Inception** stack. This explains,
in plain terms, what the project provides, how to run it, how to access the
website and its admin panel, where credentials are kept, and how to confirm
everything is working.

---

## 1. What this stack provides

Inception runs a small, self-contained web infrastructure made of three services,
each in its own container:

| Service       | Role                                                                 |
|---------------|----------------------------------------------------------------------|
| **NGINX**     | The single entry point. Serves the site over HTTPS (TLS 1.2/1.3) on port 443 and forwards dynamic pages to WordPress. |
| **WordPress** | The website itself (content management system) running on php-fpm.   |
| **MariaDB**   | The database that stores all WordPress content (posts, users, settings). |

Together they serve a WordPress website, reachable over HTTPS at a local domain
name. NGINX is the only service exposed to the outside; WordPress and MariaDB are
private and reachable only from within the stack.

---

## 2. Requirements before starting

- The stack runs inside a **virtual machine** with Docker and the Docker Compose
  plugin installed.
- The project domain must resolve to the local machine. Ensure this line is in
  the VM's `/etc/hosts`:

  ```
  127.0.0.1   akoca.42.fr
  ```

- The credential files must exist (see section 5).

---

## 3. Starting and stopping the stack

All commands are run from the **root of the project** (where the `Makefile` is).

**Start everything** (builds images on first run, then launches all services):

```bash
make
```

**Stop everything** (stops and removes the containers; your data is kept):

```bash
make down
```

**Stop and remove built images** (data still kept):

```bash
make clean
```

**Full reset** (stops everything *and deletes all website/database data*):

```bash
make fclean
```

**Rebuild from a clean state:**

```bash
make re
```

> The first `make` takes a few minutes (it builds the images). Subsequent starts
> are fast and **keep your existing content** — restarting does not wipe the site
> or database.

---

## 4. Accessing the website and admin panel

Once the stack is running:

- **Website:** open `https://akoca.42.fr` in a browser on the VM.
- **Admin panel:** open `https://akoca.42.fr/wp-admin` and log in with the
  administrator account.

> The site uses a **self-signed certificate**, so the browser will show a
> security warning the first time. This is expected for a local project — accept
> it (e.g. "Advanced → Proceed") to continue. The connection is still encrypted
> with TLS.

### Accounts

The site has two WordPress accounts:

| Role          | Username      | Notes                                  |
|---------------|---------------|----------------------------------------|
| Administrator | `akoca`       | Full control of the site               |
| Author        | `Spike`       | Standard non-admin user                |

(The administrator username deliberately avoids the words `admin`/`administrator`,
per the project rules.)

---

## 5. Locating and managing credentials

Passwords are **not** stored in the website, the images, or the configuration
files. They are kept locally as plain files and injected into the containers as
Docker secrets at runtime.

- **Non-sensitive settings** (domain, usernames, database name) live in
  `srcs/.env`.
- **Passwords** live in the `secrets/` directory:

  | File                        | What it is                          |
  |-----------------------------|-------------------------------------|
  | `secrets/db_root_password.txt` | MariaDB root password            |
  | `secrets/db_password.txt`      | WordPress database user password |
  | `secrets/wp_admin_password.txt`| WordPress administrator password |
  | `secrets/wp_user_password.txt` | WordPress second-user password   |

**To change a password:** edit the relevant file in `secrets/` (and/or the
matching value in `.env`), then rebuild from a clean state with `make re` so the
new credentials are applied. (Because credentials are set when the database and
site are first created, an existing install keeps its old credentials until
reset.)

> 🔒 The `secrets/` files and `srcs/.env` are private and must never be shared or
> committed to version control.

---

## 6. Checking that the services are running

**See the status of all containers:**

```bash
docker compose -f srcs/docker-compose.yml ps -a
```

All three (`mariadb`, `wordpress`, `nginx`) should show **Up**, and `nginx`
should show port `443` published. A container shown as *Restarting* or *Exited*
indicates a problem.

**View what a service is doing (logs):**

```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

**Quick end-to-end check from the command line:**

```bash
curl -k https://akoca.42.fr
```

If WordPress HTML is returned, the full chain (NGINX → WordPress → MariaDB) is
working. The simplest confirmation of all is simply that
`https://akoca.42.fr` loads the website in the browser.

---

## 7. Common issues

| Symptom                                  | Likely cause / fix                                              |
|------------------------------------------|----------------------------------------------------------------|
| Browser can't find `akoca.42.fr`         | Missing `/etc/hosts` entry (section 2).                        |
| "Could not connect" on port 443          | Stack not running (`make`), or the firewall is blocking 443.   |
| Certificate warning in browser           | Expected (self-signed) — accept and proceed.                  |
| A container keeps restarting             | Check that service's logs (section 6) for the error.          |
