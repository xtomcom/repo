# vaultwarden

[Vaultwarden](https://github.com/dani-garcia/vaultwarden) is a lightweight server for the Bitwarden clients. The package repackages the static musl binary and web vault from [xtomcom/vaultwarden](https://github.com/xtomcom/vaultwarden/releases), which extracts them unchanged from the official `-alpine` Docker image.

## What the package installs

| Path | |
|---|---|
| `/usr/bin/vaultwarden` | The server, statically linked (SQLite, MySQL/MariaDB and PostgreSQL built in) |
| `/usr/share/vaultwarden/web-vault/` | The web vault |
| `/usr/lib/systemd/system/vaultwarden.service` | The unit, hardened (`ProtectSystem=strict`) |
| `/etc/vaultwarden/vaultwarden.env` | Configuration, `root:vaultwarden 0640`, kept on upgrade |
| `/var/lib/vaultwarden/` | Data folder, `vaultwarden 0700`, created on install |

The service runs as the `vaultwarden` system user. It is not started on install.

## Setup

1. Edit `/etc/vaultwarden/vaultwarden.env`:
   - `DOMAIN`: the public HTTPS URL, e.g. `https://vault.example.com`.
   - `ADMIN_TOKEN`: enables the admin page at `/admin` (see below).
   - `ROCKET_ADDRESS` / `ROCKET_PORT`: default `127.0.0.1:8000`, for a reverse proxy on the same host.
   - `SIGNUPS_ALLOWED=false` once your accounts exist.
   - All options are in upstream's [.env.template](https://github.com/dani-garcia/vaultwarden/blob/main/.env.template).
2. `systemctl enable --now vaultwarden`
3. Check `journalctl -u vaultwarden`.

## HTTPS

Browsers only allow the web vault's crypto over HTTPS (or on `localhost`), so put a reverse proxy such as Caddy or nginx in front of it and keep Vaultwarden on `127.0.0.1`. With Caddy:

```
vault.example.com {
    reverse_proxy 127.0.0.1:8000
}
```

## Admin token

Generate an Argon2 hash with `vaultwarden hash` and put it in the env file in single quotes, since it contains `$`:

```
ADMIN_TOKEN='$argon2id$v=19$m=65540,t=3,p=4$...'
```

A plain-text token also works but logs a warning. Settings saved in the admin page go to `/var/lib/vaultwarden/config.json` and override the env file.

## Other data folders or databases

The unit can only write to `/var/lib/vaultwarden`. If `DATA_FOLDER` points elsewhere, allow it with `systemctl edit vaultwarden`:

```ini
[Service]
ReadWritePaths=/srv/vaultwarden
```

For MySQL/MariaDB or PostgreSQL set `DATABASE_URL`. The unit already starts after `mariadb`, `mysql` and `postgresql`.

## Backups

Everything is in `/var/lib/vaultwarden`: `db.sqlite3`, `rsa_key*`, `attachments/`, `sends/` and `config.json`. Copy the SQLite database safely while the service runs with:

```
sqlite3 /var/lib/vaultwarden/db.sqlite3 ".backup '/root/vaultwarden-$(date +%F).sqlite3'"
```

Removing the package, even with `apt purge`, leaves `/var/lib/vaultwarden` and the `vaultwarden` user in place.

## Coming from Fedora/EPEL or upstream's packages

Fedora and EPEL 9/10 ship their own `vaultwarden` (plus `vaultwarden-web`). Ours replaces it, but uses `/etc/vaultwarden/vaultwarden.env` instead of `/etc/vaultwarden/vaultwarden.cfg`: move your settings over, and remove `vaultwarden-web`, which is no longer used. xtomcom/vaultwarden's own .deb/.rpm have the same layout as this package and are replaced in place.
