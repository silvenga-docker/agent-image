# agent-image

beep boop - I'm a bot, building my own container image.

This is an opinionated agent container image for personal use in experimenting with agentic workflows. It packages a Debian-based environment with the tooling an AI coding agent typically needs - runtimes, network utilities, debugging tools, and an init system.

The goal is to enable agents with the tools they need, while also limiting the blast radius when something goes wrong.

## What's Inside

- **Base**: Debian Trixie (slim) with Docker-in-Docker support (enabled by Sysbox).
- **Init**: [s6-overlay](https://github.com/just-containers/s6-overlay) for process supervision.
- **Development Environments**:
  - **Rust**: Rust toolchain (cmake, clang, lld), plus cargo-binstall, sccache.
  - **Node**: Bun, Node LTS (via nvm).
  - **Android**: OpenJDK 21 LTS, Android SDK (cmdline-tools, build-tools, platform android-36), NDK, CMake, Gradle.
  - **Python**: Python 3.
- **Tools**: Git, ripgrep, fd, jq, file, xxd, sqlite3, PostgreSQL client, Redis client, 7-Zip (`7zz`/`7z`), unzip, xz, b3sum, gnupg.
- **Network**: nmap, mtr, tshark, tcpdump, socat, proxychains4, dnsutils.
- **Browser**: Google Chrome stable (headless-capable, for Playwright/MCP browser tools).
- **Agent**: [OpenCode](https://github.com/anomalyco/opencode) and [OpenChamber](https://github.com/openchamber/openchamber) pre-installed. Both are updated automatically on container start (including OpenCode packages).
- **Quality of Life**:
  - **Container Restarts**: A `reboot` command in this image will trigger a graceful shutdown of all services. If the container is set to restart, then this provides the agent the ability to self-restart as needed.
  - **Rm Protection**: The `rm` command was replaced with a simple wrapper to detect destructive acts like deleting the home directory (ask me why this exists...). Still, backup your agent directory!

## Usage

```bash
docker compose up -d
```

The compose file exposes ports `4096` and `3000`, mounts a persistent volume at `/home/agent` and a separate Docker image cache volume at `/var/lib/docker`. `/tmp` is an anonymous volume and should be treated as ephemeral. Run `reboot` to halt the container (triggers a restart if Docker is configured with a restart policy). By default the Docker Compose runs with `privileged: true` to allow Docker-in-Docker. When running under [Sysbox](https://github.com/nestybox/sysbox), replace `privileged: true` with `runtime: sysbox-runc` in `docker-compose.yml`.

## OpenCode Configuration

Configure OpenCode to load the in-container tool reference by adding the following to your `opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["/IMAGES.md"]
}
```

This instructs OpenCode to include `/IMAGES.md` (the authoritative tool reference baked into the image) as context.

## Security Posture

This image is designed to run under the [Sysbox](https://github.com/nestybox/sysbox) container runtime, which provides VM-like isolation. The Docker daemon runs as root inside the container. Application services (`opencode`, `openchamber`) run as the unprivileged `agent` user (uid 1000) via `s6-setuidgid`.

Sysbox runtime 0-day exploits are out of scope. No additional capability grants, seccomp overrides, or SELinux workarounds are needed when running under Sysbox.
