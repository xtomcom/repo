# vaultwarden

[Vaultwarden](https://github.com/dani-garcia/vaultwarden) is a lightweight server for the Bitwarden clients. The package repackages the static musl binary and web vault from [xtomcom/vaultwarden](https://github.com/xtomcom/vaultwarden/releases), which extracts them unchanged from the official `-alpine` Docker image.

## Package contents

| Path | Description |
|---|---|
| `/usr/bin/vaultwarden` | The server, statically linked (SQLite, MySQL/MariaDB and PostgreSQL built in) |
| `/usr/share/vaultwarden/web-vault/` | The web vault |
| `/usr/lib/systemd/system/vaultwarden.service` | The unit, hardened (`ProtectSystem=strict`) |
| `/etc/vaultwarden/vaultwarden.env` | Configuration, `root:vaultwarden 0640`, kept on upgrade |
| `/var/lib/vaultwarden/` | Data directory, `vaultwarden 0700`, created on install |

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

Browsers require HTTPS or `localhost` for the web vault's cryptographic functions. Configure a reverse proxy such as Caddy or nginx and keep Vaultwarden bound to `127.0.0.1`. Example Caddy configuration:

```
vault.example.com {
    reverse_proxy 127.0.0.1:8000
}
```

## Admin token

Generate an Argon2 hash with `vaultwarden hash` and store it in the environment file enclosed in single quotes, since it contains `$`:

```
ADMIN_TOKEN='$argon2id$v=19$m=65540,t=3,p=4$...'
```

A plain-text token also works but logs a warning. Settings saved in the admin page go to `/var/lib/vaultwarden/config.json` and override the environment file.

## Alternative data directories and databases

The unit can only write to `/var/lib/vaultwarden`. If `DATA_FOLDER` points elsewhere, allow it with `systemctl edit vaultwarden`:

```ini
[Service]
ReadWritePaths=/srv/vaultwarden
```

For MySQL/MariaDB or PostgreSQL set `DATABASE_URL`. The unit already starts after `mariadb`, `mysql` and `postgresql`.

## Backups

Vaultwarden stores its data in `/var/lib/vaultwarden`: `db.sqlite3`, `rsa_key*`, `attachments/`, `sends/` and `config.json`. To back up the SQLite database while the service is running, use:

```
sqlite3 /var/lib/vaultwarden/db.sqlite3 ".backup '/root/vaultwarden-$(date +%F).sqlite3'"
```

Removing the package, even with `apt purge`, leaves `/var/lib/vaultwarden` and the `vaultwarden` user in place.

## Migration from Fedora/EPEL or upstream packages

Fedora and EPEL 9/10 ship their own `vaultwarden` (plus `vaultwarden-web`). This package replaces it and uses `/etc/vaultwarden/vaultwarden.env` instead of `/etc/vaultwarden/vaultwarden.cfg`: migrate the existing settings, and remove `vaultwarden-web`, which is no longer used. xtomcom/vaultwarden's own .deb/.rpm have the same layout as this package and are replaced in place.
