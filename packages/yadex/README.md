# yadex

[yadex](https://github.com/ustclug/yadex) generates directory index pages for files that another web server (usually nginx) serves. It does not serve the files itself.

## What the package installs

| Path | |
|---|---|
| `/usr/bin/yadex` | The upstream release binary |
| `/usr/lib/systemd/system/yadex.service` | Upstream's unit, unchanged |
| `/etc/yadex/config.toml` | Configuration, kept on upgrade |
| `/etc/yadex/index.html` | Index page template, kept on upgrade |
| `/usr/share/doc/yadex/nginx.*.example.conf` | Upstream's nginx examples |

The service is not started on install.

## Setup

1. Set `root` in `/etc/yadex/config.toml` to the directory you serve. The default is `/srv/repo/`.
2. If `root` is not `/srv/repo/`, add a systemd override (see below).
3. Start it: `systemctl enable --now yadex`. It listens on `127.0.0.1:8880`.
4. Point nginx at it, following one of the examples in `/usr/share/doc/yadex/`. The `index` example falls back to yadex for directories without an `index.html`. The `try_files` example sends every directory request through yadex.

## Why it fails with "Permission denied"

Upstream's unit sandboxes yadex heavily. Two settings decide whether it can read `root`:

- `DynamicUser=yes`: yadex runs as a throwaway user, which counts as "other" for file permissions. `root` needs `o+rx`, and every directory above it needs `o+x`. Check with `namei -l /your/root`.
- `ProtectHome=yes`: `/home`, `/root` and `/run/user` are invisible to the service. A `root` under `/home` always fails, whatever its permissions.

The unit also lists `/srv/repo` in `ReadOnlyPaths=`. If you serve another directory, replace that list.

## Overriding the unit

Run `systemctl edit yadex` and put your changes in the editor. They go to `/etc/systemd/system/yadex.service.d/override.conf`, which package upgrades never touch.

`root` under `/home`, e.g. `/home/xtom/repo.xtom.com/`:

```ini
[Service]
ProtectHome=read-only
ReadOnlyPaths=
ReadOnlyPaths=/etc/yadex /home/xtom/repo.xtom.com
```

`root` elsewhere, e.g. `/data/mirror/`:

```ini
[Service]
ReadOnlyPaths=
ReadOnlyPaths=/etc/yadex /data/mirror
```

The empty `ReadOnlyPaths=` line clears the unit's list; otherwise your paths are only added to it.

To read a directory that "other" may not enter, run yadex as a fixed user that can read it instead of a dynamic one:

```ini
[Service]
DynamicUser=no
User=mirror
```

Then run `systemctl restart yadex` and check `journalctl -u yadex`.

## `security` in config.toml

- `landlock` (the default) confines yadex to `root` without needing root privileges. It needs Linux 5.13 or newer.
- `chroot` needs root privileges, which the sandboxed unit does not have. Don't use it with this unit.
- `none` lets symlinks inside `root` point anywhere on the system.
