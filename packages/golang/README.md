# Go (golang)

The official [Go](https://go.dev/) toolchain from [go.dev/dl](https://go.dev/dl/), repackaged unchanged. The tarball is checked against the SHA-256 that go.dev publishes. Nothing is compiled.

Every supported Go minor version is a separate package, and they can be installed side by side:

| Package | Installs | Default `go`? |
|---|---|---|
| `golang` | The newest Go, currently `golang-1.27`. A metapackage with no files of its own. | Yes |
| `golang-1.27` | Go 1.27.x in `/usr/lib/go-1.27` | Yes, as the newest one installed |
| `golang-1.26` | Go 1.26.x in `/usr/lib/go-1.26` | Only if nothing newer is installed, or you select it |

## Which package to install

- **You want the current Go and want it kept current:** install `golang`. It always depends on the newest Go version. When a new minor version comes out (Go 1.28), the next upgrade installs `golang-1.28` and makes it the default `go`. The older version stays installed until you remove it.
- **You want one minor version only:** install `golang-1.26` (or `golang-1.27`). Upgrades bring its patch releases (1.26.10 to 1.26.11) and never a newer minor version. A full upgrade with only `golang-1.26` installed never pulls in 1.27.
- **You need several versions:** install all of them. The newest is the default `go`. Every version also has its own `go-1.NN` command (see below).

```sh
# Debian / Ubuntu
sudo apt install golang          # newest Go
sudo apt install golang-1.26     # an older one, alongside or alone

# RHEL / Rocky / AlmaLinux
sudo dnf install golang
sudo dnf install golang-1.26
```

### Aliases

These names install the same packages:

| Name | Installs | Where |
|---|---|---|
| `go` | `golang` | apt and dnf |
| `golang1.26`, `go1.26`, `go-1.26` | `golang-1.26` (same pattern for every version) | apt and dnf |
| `golang-1.26-go`, `golang-1.26-src`, `golang-1.26-doc` | `golang-1.26` | apt, where the distribution has no package of that name (Debian 13 has `golang-1.24-*` only, Ubuntu 26.04 has its own `golang-1.26-go`) |
| `golang-go`, `golang-src`, `golang-doc` | Provided by `golang`, so packages that depend on them accept our Go | apt; `apt install golang-go` itself installs the distribution's package |
| `golang-bin`, `golang-src`, `golang-race`, `golang-misc`, `golang-tests`, `golang-docs` | Provided by `golang` | dnf |

An alias is resolved once, at install time. After `apt install go1.26`, `apt list --installed`, `dpkg -l` and `rpm -qa` show `golang-1.26`, and that is the name to use from then on. Commands that act on an installed package (`apt remove`, `dnf remove`, `apt-mark hold`, `dnf versionlock`, apt pinning in `/etc/apt/preferences.d/`) need the real name, `golang-1.26`. The same applies to `go`, which is `golang`.

To pin an exact patch release, install it by its real name and full version:

```sh
apt-cache madison golang-1.26                 # list versions
sudo apt install golang-1.26=2:1.26.10-1
sudo apt-mark hold golang-1.26

dnf --showduplicates list golang-1.26
sudo dnf install golang-1.26-1.26.10
```

The repository only keeps the newest patch release of each minor version, so older patch releases cannot be installed from it.

## What a version package installs

| Path | |
|---|---|
| `/usr/lib/go-1.NN/` | GOROOT: the upstream tarball, unchanged |
| `/usr/bin/go-1.NN`, `/usr/bin/gofmt-1.NN` | Versioned commands, always present |
| `/usr/share/go-1.NN` | Link to `/usr/lib/go-1.NN`, where Debian's `golang-1.NN-src` keeps the sources (deb only) |
| `/usr/bin/go`, `/usr/bin/gofmt` | Managed by alternatives, see below |
| `/usr/lib/go` | Link to the default GOROOT, like Debian's `golang-go`; managed by alternatives |
| `/usr/share/go` | Same, like Debian's `golang-src` (deb only); managed by alternatives |

Go finds its GOROOT from the real path of the binary, so every command uses its own version's standard library and tools, whether it is run as `go`, `go-1.26` or `/usr/lib/go-1.26/bin/go`. There is no need to set `GOROOT`.

```console
$ go-1.26 version
go version go1.26.10 linux/amd64
$ go-1.26 env GOROOT
/usr/lib/go-1.26
```

The packages recommend `gcc` (and, on Debian and Ubuntu, `g++`, `libc6-dev` and `pkgconf`) for cgo. Without a C compiler, Go builds with `CGO_ENABLED=0`.

## Choosing the default `go`

`/usr/bin/go` is the alternative group `go`. Its followers are `/usr/bin/gofmt`, `/usr/lib/go` and, on deb, `/usr/share/go`, so they always switch together. Each version registers with priority 100 × major + minor (1.27 is 127, 1.26 is 126), so by default the newest installed version wins. Fedora and RHEL's own `golang-bin` uses the same group with priority 90.

Debian / Ubuntu:

```sh
update-alternatives --display go                         # what is installed and selected
sudo update-alternatives --config go                     # choose interactively
sudo update-alternatives --set go /usr/lib/go-1.26/bin/go
sudo update-alternatives --auto go                       # back to the newest
```

RHEL / Rocky / AlmaLinux:

```sh
alternatives --display go
sudo alternatives --config go
sudo alternatives --set go /usr/lib/go-1.26/bin/go
sudo alternatives --auto go
```

A manual choice survives upgrades of the packages. If the selected version is removed, the group goes back to automatic mode and the newest remaining version becomes the default. Removing the last version removes `/usr/bin/go`, `/usr/bin/gofmt`, `/usr/lib/go` and `/usr/share/go`.

For a single command or a shell session, use the versioned command or put a version first in `PATH` instead:

```sh
go-1.26 test ./...
PATH=/usr/lib/go-1.26/bin:$PATH make
```

`GOTOOLCHAIN` works as upstream documents it: a `go.mod` that asks for a newer Go can make `go` download that toolchain into the module cache. Set `GOTOOLCHAIN=local` to stay on the installed version.

## Supported versions

The Go project supports the two newest minor versions, and so do we: when a version stops being supported upstream, its package leaves the repository.

When Go 1.28 is released:

- `golang-1.28` is added, and `golang` moves to it. Upgrading `golang` installs `golang-1.28`, which becomes the default `go`. `golang-1.27` stays installed and keeps getting patch releases.
- `golang-1.26` is removed from the repository. Installed copies keep working (`go-1.26`, and `go` if it is the only or selected version) but get no more updates. Remove it with `apt remove golang-1.26` / `dnf remove golang-1.26` when you no longer need it.

## Replacing the distribution's Go

Every package has epoch 2, which Debian also uses for `golang-go`. RHEL's packages have no epoch, so ours always sort higher than the distribution's Go.

### Debian and Ubuntu

The distribution splits its Go into `golang` and `golang-go`, `golang-src`, `golang-doc` (which own `/usr/bin/go`, `/usr/bin/gofmt`, `/usr/lib/go` and `/usr/share/go` and pick the default version), plus `golang-1.NN-go`, `-src` and `-doc` (one GOROOT in `/usr/lib/go-1.NN`). Ubuntu also has a `golang-1.NN` metapackage.

- Our `golang` upgrades the distribution's `golang`. It conflicts with, replaces and provides `golang-go`, `golang-src` and `golang-doc`, so they are removed. Packages that depend on them, for example `golang-go (>= 2:1.22~)`, are satisfied by our `golang`.
- Our `golang-1.NN` conflicts with, replaces and provides the distribution's `golang-1.NN-go`, `-src` and `-doc` of the same version and upgrades Ubuntu's `golang-1.NN`. Distribution packages of other versions (Debian 13's `golang-1.24-go`) can stay installed; they live in their own `/usr/lib/go-1.NN` and are not part of the `go` alternatives.
- `golang-1.NN` also conflicts with the distribution's `golang-go` and `golang-src`, whose `/usr/bin/go` and `/usr/share/go` would be in the way of the alternatives.

The switch removes packages, which `apt upgrade` does not do. Use `apt install golang` or `apt full-upgrade`:

```sh
sudo apt install golang      # replaces golang-go, golang-src, golang-doc
sudo apt autoremove          # drops the distribution's golang-1.NN-go, now unused
```

### RHEL, Rocky Linux and AlmaLinux

The distribution ships `golang`, `golang-bin` (with `/usr/bin/go` as alternative `go`), `golang-src`, `golang-race`, `golang-misc`, `golang-tests` and `golang-docs`, all with GOROOT `/usr/lib/golang`.

Our `golang` upgrades the distribution's `golang`, provides all of these names and obsoletes the others, so `dnf upgrade` or `dnf install golang` replaces them. `go-toolset` requires the distribution's exact `golang` version and has to be removed first (`dnf remove go-toolset`).

`golang-1.NN` alone does not replace anything: next to the distribution's `golang` it adds its version to the same `go` alternatives with a higher priority.

### The single `golang` package used before

Up to Go 1.27.3 this repository had one package, `golang` (2:1.27.3-1 and 2:1.26.10-1), that held the whole toolchain: in `/usr/lib/go-1.NN` with fixed `/usr/bin/go` links on deb, in `/usr/lib/golang` with alternative `go` on rpm. It is now the metapackage, so a normal upgrade moves you over:

```sh
sudo apt upgrade     # or: sudo dnf upgrade
```

The upgrade replaces `golang` with the metapackage and installs `golang-1.27`. On deb, `golang-1.27` takes over `/usr/lib/go-1.27` (it `Replaces` and `Breaks` `golang (<< 2:1.27.3-2~)`), and the old fixed links make way for the alternatives. On rpm, `golang-1.27` removes the old package's `/usr/lib/golang/bin/go` alternative, which the old package only removed on erase, not on upgrade. If you had the old 1.26 build, you end up on 1.27; install `golang-1.26` to keep 1.26.

## Maintainers

- `packages/golang-1.NN/package.sh` sets `BRANCHES=(1.NN)` and sources `packages/_shared/golang/common.sh`. Everything else (`nfpm.yaml`, the maintainer scripts) is linked from `packages/_shared/golang/`; `@BRANCH@` and the other placeholders are filled in by `prepare()`.
- The metapackage follows the newest `packages/golang-1.NN` directory. New minor version: copy `packages/golang-1.27` to `packages/golang-1.28` and change `BRANCHES`, then remove the oldest directory. `publish.sh` then drops the retired package from the repository. `check.sh` warns about a newer minor version only for the newest version package and `golang`.
- `golang` sets `TEST_DEPS=(golang-1.NN)`, so `scripts/test.sh` builds that package too and installs both together. `tests/golang.sh` tests everything through a local repository: aliases, side-by-side installs, switching, removal, and the upgrades from the old package and from the distributions' Go.
- This README is not packaged.
