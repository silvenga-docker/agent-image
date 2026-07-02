# Agent Environment

Agent workloads (OpenCode, OpenChamber) run as `agent` (uid 1000) inside a Debian Trixie container. The container init (PID 1) and Docker daemon run as root - no escalation path to root is available.

## Constraints

- **No root access.** sudo, su, and privilege escalation are not available.
- **System files are ephemeral.** Changes to `/usr`, `/etc`, `/bin`, `/lib`, and other system paths are wiped when the image is rebuilt. Do not modify system directories.
- **Persistent storage.** `/home/agent` is a persistent Docker volume; files here survive restarts and reboots.
- **Temporary storage.** `/tmp` is available for scratch work. Contents may or may not survive container restarts - treat it as unreliable between runs. It is sized as a Docker volume (many GB), not memory-backed.

## Installed Tools

**CLI**
`git`, `curl`, `jq`, `less`, `unzip`, `7z`/`7zz`, `xz`, `b3sum`, `gnupg`, `ripgrep` (`rg`), `fdfind` (`fd-find`), `file`, `xxd`, `bsdextrautils` (`hexdump`, `col`, etc.)

**Data**
`sqlite3`, `psql` (PostgreSQL client), `redis-cli`

**Network**
`openssh-client`, `nmap`, `mtr`, `socat`, `proxychains4`, `tshark`, `tcpdump` (`dumpcap` has `cap_net_raw`), `dig`/`nslookup`, `whois`

**Browser**
`google-chrome-stable` - Google Chrome, headless-capable; used by Playwright/MCP browser tools

**Build**
`gcc`, `g++`, `clang`, `lld`, `cmake`, `make`, `pkg-config`, `libssl-dev`, `libclang-dev`, `libwebkit2gtk-4.1-dev`, `libgtk-3-dev`, `libglib2.0-dev`, `libgio-2.0-dev`, `libdbus-1-dev`, `librsvg2-dev`, `libsoup-3.0-dev`

**Runtimes** (user-space, persistent in `/home/agent`)
- `python3`, `pip` (`python3-pip`), `pipx`
- Rust / Cargo: `~/.cargo` - `cargo`, `rustc`, `rustup`, `cargo-binstall`, `sccache`
- Node LTS / npm / npx: `~/.nvm/current/bin`
- Bun: `~/.bun` - `bun`, `bunx`

**Android** (user-space, persistent in `/home/agent/Android` and `/home/agent/.local`)
- OpenJDK 21 LTS: `java`, `javac` (`$JAVA_HOME/bin`)
- Android SDK: `sdkmanager`, `avdmanager` (`$ANDROID_HOME/cmdline-tools/latest/bin`)
- Build-tools 36.0.0: `aapt2`, `d8`, etc. (`$ANDROID_HOME/build-tools/36.0.0`)
- NDK r28.x: `ANDROID_NDK_HOME` / `ANDROID_NDK_ROOT` point to `$ANDROID_HOME/ndk/current` (symlink to the installed version)
- Gradle 9.5.1: `gradle` (`$GRADLE_HOME/bin`)

**Containers**
`docker`, `docker compose` - inner Docker daemon runs inside this container (Docker-in-Docker)

## PATH

```
~/.cargo/bin
~/.bun/bin
~/.nvm/current/bin
~/.local/bin
$JAVA_HOME/bin
$ANDROID_HOME/cmdline-tools/latest/bin
$ANDROID_HOME/build-tools/36.0.0
$GRADLE_HOME/bin
/usr/local/bin  (and standard system paths)
```

## Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `JAVA_HOME` | `/usr/lib/jvm/java-21-openjdk-amd64` | JDK 21 location (apt-installed) |
| `ANDROID_HOME` | `/home/agent/Android/Sdk` | Android SDK root |
| `ANDROID_SDK_ROOT` | `/home/agent/Android/Sdk` | Alias of `ANDROID_HOME` |
| `ANDROID_NDK_HOME` | `/home/agent/Android/Sdk/ndk/current` | NDK root (symlink to installed version) |
| `ANDROID_NDK_ROOT` | `/home/agent/Android/Sdk/ndk/current` | Alias of `ANDROID_NDK_HOME` |
| `GRADLE_HOME` | `/home/agent/.local/gradle-9.5.1` | Gradle install dir |

## Installing New Tools

`apt` and system directories are off-limits. Install tools user-scoped:

| Method | Command | Destination |
|--------|---------|-------------|
| Rust binary | `cargo install <crate>` | `~/.cargo/bin` |
| Node package | `bun add -g <pkg>` | `~/.bun/bin` |
| Python package | `pip install --user <pkg>` | `~/.local/lib`; binary in `~/.local/bin` |
| Python app | `pipx install <pkg>` | `~/.local/bin` |
| Static binary | Download to `~/.local/bin` and `chmod +x` | `~/.local/bin` |

For other install locations, add to `~/.bashrc` and re-source.

## Restarting the Container

Run `reboot` (or `/usr/local/bin/reboot`) to reboot the container.
