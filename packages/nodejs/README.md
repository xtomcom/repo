# Node.js

The official Node.js builds from [nodejs.org](https://nodejs.org/), repackaged as
`.deb` and `.rpm`. Nothing is recompiled or patched: each package holds the
upstream `linux-x64` / `linux-arm64` tarball as released. Before packaging, we
check the signature on `SHASUMS256.txt.asc` against the Node.js release keys and
then check the tarball against the signed checksum.

Only LTS lines are published, and only the newest release of each line.

## Which package to install

| Package     | What you get                                                        | Upstream end of life |
|-------------|---------------------------------------------------------------------|----------------------|
| `nodejs`    | The newest LTS line (now `nodejs-26`). Follows new LTS lines.        | n/a                  |
| `nodejs-26` | Node.js 26 LTS                                                       | 2029-04-30           |
| `nodejs-24` | Node.js 24 LTS                                                       | 2028-04-30           |
| `nodejs-22` | Node.js 22 LTS                                                       | 2027-04-30           |

- Install **`nodejs`** if you want the current LTS and are fine with moving to
  the next LTS line when it comes out. `nodejs` is a metapackage with no files.
  It depends on the newest LTS line, and its version is that line's version.
- Install **`nodejs-NN`** if your application needs one major version. A
  `nodejs-NN` package only gets updates within its line. `apt upgrade` and
  `dnf upgrade` never move you to another major version.

Each line includes npm. Node.js 22 and 24 also include corepack, which Node.js 25
and later no longer ship.

First add the repository (see the main README), then:

```sh
# Debian / Ubuntu
apt install nodejs          # newest LTS
apt install nodejs-24       # or one line

# RHEL / Rocky / AlmaLinux 9 and 10
dnf install nodejs
dnf install nodejs-24
```

### Aliases

You can also use these names:

| Alias        | Installs    |
|--------------|-------------|
| `nodejs26`   | `nodejs-26` |
| `nodejs24`   | `nodejs-24` |
| `nodejs22`   | `nodejs-22` |
| `nodejs-lts` | `nodejs`    |

The aliases are virtual names (`Provides`). apt prints
`Note, selecting 'nodejs-24' instead of 'nodejs24'`. After that, `dpkg -l`,
`apt list --installed`, `rpm -q` and `dnf list installed` show only the real
name. Anything that refers to an installed package needs the real name, for
example:

```sh
apt-mark hold nodejs-24
apt install nodejs-24=1:24.22.2-1     # note the epoch "1:"
dnf versionlock add nodejs-24
```

In an apt preferences file (`/etc/apt/preferences.d/`), use `Package: nodejs-24`
too. The repository only keeps the newest release of each line, so you can't
install an older release from it.

On RHEL 10, `nodejs24` is also the name of Red Hat's own package. Our
`nodejs-24` obsoletes it, so `dnf install nodejs24` installs `nodejs-24` from this
repository instead.

## What gets installed

Using Node.js 24 as the example:

| Path | Contents |
|------|----------|
| `/usr/lib/nodejs-24/` | The upstream tarball: `bin/node`, `lib/node_modules/{npm,corepack}`, `include/node` (headers), `share/man`, `share/doc` |
| `/usr/bin/node-24` | Node.js 24 |
| `/usr/bin/npm-24`, `/usr/bin/npx-24`, `/usr/bin/corepack-24` | npm, npx and corepack, always run by Node.js 24 |
| `/usr/bin/node`, `nodejs`, `npm`, `npx`, `corepack`, `/usr/share/man/man1/node.1.gz` | Links managed by `update-alternatives` (group `node`), pointing to the default line |

Every package also declares `Provides: nodejs` and `npm`, with its own version.
Distribution packages that need `nodejs (>= 18)` or `npm` (Debian), or
`nodejs`, `npm` or `nodejs(engine)` (RHEL), are satisfied.

## Several lines side by side

The `nodejs-NN` packages don't conflict with each other. Install as many as
you need:

```sh
apt install nodejs-26 nodejs-24 nodejs-22
```

`node`, `nodejs`, `npm`, `npx`, `corepack` and the `node(1)` man page form one
alternatives group, `node`. They always switch together, so `npm` never runs
under a different `node`. By default the newest line wins: its priority is the
major version × 10, e.g. 260 for Node.js 26.

Show and change the default:

```sh
# Debian / Ubuntu
update-alternatives --display node
update-alternatives --config node                             # interactive
update-alternatives --set node /usr/lib/nodejs-24/bin/node    # pick Node.js 24
update-alternatives --auto node                               # back to the newest

# RHEL / Rocky / AlmaLinux
alternatives --display node
alternatives --config node
alternatives --set node /usr/lib/nodejs-24/bin/node
alternatives --auto node
```

A manual choice survives package upgrades. If you remove the line you selected,
the group goes back to automatic mode, i.e. the newest remaining line. If you
remove the last line, `/usr/bin/node` and the other links go away.

### Versioned commands

`node-NN`, `npm-NN`, `npx-NN` and `corepack-NN` (22 and 24 only) always run
that line, whatever the default is:

```sh
node-22 app.js
npm-24 ci
npx-22 some-tool
```

`npm-NN`, `npx-NN` and `corepack-NN` are small wrappers. They run the tool with
`node-NN` and put `/usr/lib/nodejs-NN/bin` first in `PATH`, so anything they
start (package scripts, `#!/usr/bin/env node` tools) also uses Node.js NN. The
default `npm`/`npx` links point at the same wrappers of the default line.

Your own scripts with `#!/usr/bin/env node` or `#!/usr/bin/node` use the
default line. To pin one, use `#!/usr/bin/node-24`, or `ExecStart=/usr/bin/node-24 ...`
in a systemd unit.

## npm global installs

npm's built-in configuration (`/usr/lib/nodejs-NN/lib/node_modules/npm/npmrc`)
sets `prefix=/usr/local`, as Debian's and Fedora's npm do. So

```sh
npm install -g pm2
```

installs into `/usr/local/lib/node_modules` and puts the command in
`/usr/local/bin`, which is on `PATH`. The files that dpkg or rpm own are never
changed, and package upgrades never delete your global packages. The same file
sets `globalconfig=/etc/npmrc` and turns off npm's update notifier. Put your
own settings in `/etc/npmrc` or `~/.npmrc`; they override the built-in ones.

All lines share `/usr/local`. Keep these points in mind:

- **Native modules are built for one major version.** A global package with a
  compiled addon (e.g. `bcrypt`, `sqlite3`) fails under another line with
  `was compiled against a different Node.js version using NODE_MODULE_VERSION …`.
  After you switch the default to another major, rebuild with `npm rebuild -g`
  or reinstall the package. If several lines must use global packages at the
  same time, give each its own prefix, e.g. `npm_config_prefix=/opt/node24 npm-24 install -g …`.
- **corepack** (22 and 24) would by default write its `yarn`/`pnpm` shims into
  `/usr/lib/nodejs-NN/bin`. Install them into `/usr/local/bin` instead:
  `corepack enable --install-directory /usr/local/bin`. On Node.js 26, install
  corepack with `npm install -g corepack` if you need it.

## Updating npm and global packages

npm is released separately from Node.js. Each package ships the npm bundled
with that Node.js release, so a newer npm may exist before Node.js picks it up.

```sh
npm update -g                 # update your global packages (in /usr/local)
npm install -g npm@latest     # a newer npm, into /usr/local
```

`npm install -g npm@latest` installs the new npm in `/usr/local/lib/node_modules/npm`
with the command in `/usr/local/bin/npm`. That comes before `/usr/bin` on `PATH`,
so it is the `npm` you run from then on, for every Node.js line; it keeps using
the `/usr/local` prefix. The npm in the package is not changed, and
`npm-24`, `npm-26` etc. keep running the bundled one.

Your `/usr/local` npm is yours to update: package upgrades no longer change
the `npm` you run. Update it with `npm install -g npm@latest` again, or remove
it to go back to the bundled npm of the default line:

```sh
npm uninstall -g npm
hash -r
```

## Native addons

The headers are in `/usr/lib/nodejs-NN/include/node`. node-gyp (bundled with
npm) downloads matching headers by default. To build offline, run
`npm install --nodedir=/usr/lib/nodejs-24`. Building addons also needs
`python3`, `make` and a C++ compiler (`g++` / `gcc-c++`). The packages suggest
these but don't depend on them.

## Replacing the distribution's or NodeSource's Node.js

The packages have epoch 1, so `nodejs` sorts above the `nodejs` of Debian,
Ubuntu, NodeSource (all without an epoch) and RHEL (epoch 1, lower versions).
Installing it upgrades those packages in place.

### Debian and Ubuntu

`apt install nodejs` replaces the distribution's `nodejs`. Every `nodejs-NN`
conflicts with `nodejs` and `npm` versions without an epoch, so apt removes the
separate `npm` package. `nodejs-22` and `nodejs-24` also remove `node-corepack`,
because they bring their own corepack. `libnodeNNN`, `libnode-dev` and
`nodejs-doc` stay installed; none of their files clash. You can remove them if
nothing else needs them.

`apt upgrade` holds `nodejs` back while Debian's `npm` is installed, because the
upgrade has to remove a package. Use `apt install nodejs` or `apt full-upgrade`.

Debian's `node-*` library packages (in `/usr/share/nodejs`) stay installed, but
our Node.js doesn't search that directory. Install the libraries you need with
npm instead.

### NodeSource

NodeSource's single `nodejs` package (with npm inside) is replaced the same
way. But NodeSource's setup script also pins its repository to priority 600
in `/etc/apt/preferences.d/nodejs` (and `nsolid`). As long as that pin exists,
apt keeps NodeSource's package, even though ours has the higher version.
Remove the NodeSource repository and its pins first:

```sh
rm -f /etc/apt/sources.list.d/nodesource.sources /etc/apt/sources.list.d/nodesource.list \
  /etc/apt/preferences.d/nodejs /etc/apt/preferences.d/nsolid /usr/share/keyrings/nodesource.gpg
apt update
apt install nodejs
```

### RHEL, Rocky Linux, AlmaLinux

`dnf install nodejs` or `dnf upgrade` upgrades RHEL's `nodejs` to our
metapackage. The metapackage obsoletes the packages that require the exact
version of RHEL's `nodejs`: `nodejs-npm` / `npm`, `nodejs-docs`, `nodejs-devel`
and `nodejs-full-i18n`. Our builds include full ICU, so nothing is lost. Every
`nodejs-NN` conflicts with RHEL's `nodejs` (versions below 1:26 own
`/usr/bin/node`). So with RHEL's `nodejs` installed, `dnf install nodejs-24`
also upgrades it to our `nodejs`, which brings `nodejs-26` along. On RHEL 10,
`nodejs-NN` also obsoletes Red Hat's versioned `nodejsNN`, `nodejsNN-npm`,
`nodejsNN-docs`, `nodejsNN-devel` and `nodejsNN-full-i18n`. Those ship the same
`/usr/bin/node-NN` and `npm-NN` names. `nodejs-libs` / `nodejsNN-libs` (only
`libnode.so`) stay installed.

A changed `/etc/npmrc` from RHEL's npm is saved as `/etc/npmrc.rpmsave`. Our npm
reads `/etc/npmrc`, so move it back if you need those settings.

#### RHEL 9: module streams

On RHEL 9 and its rebuilds, Node.js 18 to 24 are also available as module streams
(`dnf module list nodejs`). If you enabled a stream (e.g. with
`dnf module enable nodejs:22` or `dnf module install nodejs:22`), dnf's
modular filtering hides every non-modular package named `nodejs`, `npm`, … from
other repositories, including ours. `dnf install nodejs` then keeps installing
the module's build. Reset the module first:

```sh
dnf module reset nodejs
dnf install nodejs
```

`nodejs-NN` has a name that no module uses, so it isn't hidden. But it
conflicts with the module's `nodejs`, and dnf can't replace that with our
hidden metapackage. Reset the module in that case too.

## LTS lines and end of life

| Line | LTS since | End of life |
|------|-----------|-------------|
| 22 (Jod) | 2024-10 | 2027-04-30 |
| 24 (Krypton) | 2025-10 | 2028-04-30 |
| 26 (Lithium) | 2026-10 | 2029-04-30 |

See the [Node.js release schedule](https://github.com/nodejs/release#release-schedule).

When a line reaches end of life, we remove its package (e.g. `nodejs-22`) from the
repository. Installed copies keep working, but they get no more updates,
including security fixes. Move to a supported line yourself:

```sh
apt install nodejs-26 && apt purge nodejs-22
dnf install nodejs-26 && dnf remove nodejs-22
```

When a newer line becomes LTS (say Node.js 28), it gets its own `nodejs-28`
package, and the `nodejs` metapackage moves to it. The next
`apt full-upgrade` / `apt upgrade` / `dnf upgrade` then installs `nodejs-28` next
to `nodejs-26`. `nodejs-28` becomes the default because of its higher priority.
`nodejs-26` stays installed and keeps receiving updates until its own end of
life. If apt installed it only as a dependency of `nodejs`, `apt autoremove`
(or `dnf autoremove`) offers to remove it. Mark it as manually installed
(`apt-mark manual nodejs-26`, `dnf mark install nodejs-26`) to keep it.
`apt-get upgrade` (not `apt upgrade`) never installs new packages, so it holds
`nodejs` back until you run `apt-get dist-upgrade`.

## Removal

```sh
apt purge nodejs nodejs-26          # Debian / Ubuntu
dnf remove nodejs nodejs-26         # RHEL family
```

Removing a line also removes its alternatives. Removing the last line removes
`/usr/bin/node`, `npm` and the rest. Global npm packages in `/usr/local` and your
`/etc/npmrc` are yours; remove them yourself.
