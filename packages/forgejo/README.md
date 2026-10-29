# forgejo and forgejo-lts

Both packages install the same Forgejo server, so only one can be installed:

- `forgejo` follows the newest stable release. It moves to the next major version (17 → 18) when that is released.
- `forgejo-lts` follows the long-term support release. It moves to the next LTS (15 → 19) when the current one reaches its end of life.

Which version is stable or LTS, and when an LTS ends, comes from Forgejo's [release schedule](https://forgejo.org/releases/).

## Package contents

| Path | Description |
|---|---|
| `/usr/lib/forgejo/forgejo` | The upstream release binary |
| `/usr/bin/forgejo` | Upstream's FHS wrapper: uses `/etc/forgejo/app.ini` and `/var/lib/forgejo` by default |
| `/usr/lib/systemd/system/forgejo.service` | Upstream's unit, with `Type=simple` instead of `Type=notify` |
| `/etc/forgejo` | Configuration, `root:git` 0770 until the setup is done |
| `/var/lib/forgejo` | Data, owned by `git` |

The `git` user is the same one the `gitea` package uses. Upstream's unit uses `Type=notify` from Forgejo 16 on, but Forgejo never reports itself ready while the web installer runs, so `systemctl enable --now forgejo` would time out on a fresh install.

## Setup

1. `systemctl enable --now forgejo`
2. Open `http://<this server>:3000` and finish the setup.
3. Lock down the configuration: `chmod 750 /etc/forgejo && chmod 640 /etc/forgejo/app.ini`

## Switching between forgejo and forgejo-lts

Going from `forgejo-lts` to `forgejo` upgrades the database, which cannot be undone, so back up `/var/lib/forgejo` and `/etc/forgejo` first. Going from `forgejo` back to `forgejo-lts` is a downgrade, which Forgejo does not support.

```bash
apt install forgejo                  # removes forgejo-lts
dnf swap forgejo-lts forgejo
systemctl enable --now forgejo       # the removal disabled the service
```

## Forgejo Actions

Install `forgejo-runner` on the machine that runs the jobs; the installation notice lists the steps. See [Forgejo Runner registration](https://forgejo.org/docs/latest/admin/actions/registration/).
