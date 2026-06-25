# AGENTS.md

Guide for AI agents editing this repository. This repo defines a hardened Docker image for AI coding agents.

## Architecture

- Base: Debian trixie-slim
- Init: s6-overlay manages services
- User: Container runs as root; application services (opencode, openchamber, agent-init) run as `agent` (uid 1000) via `s6-setuidgid`
- Volume: `/home/agent` is a persistent volume
- Services (s6 boot order): `agent-init` (oneshot) → `dockerd` (longrun) → `dockerd-ready` (oneshot) → `opencode` (longrun, :4096) → `openchamber` (longrun, :3000)
- External deps: [OpenCode](https://github.com/anomalyco/opencode), [OpenChamber](https://github.com/btriapitsyn/openchamber) - pinned by version in Dockerfile/agent-setup.sh

## Security Model - HIGH SENSITIVITY

This image defines a security boundary. All changes must preserve these invariants:

### Scope

Sysbox runtime 0-day exploits are out of scope. The threat model assumes Sysbox provides VM-like isolation. This image is designed to run under the Sysbox runtime. The example runs with `privileged: true`, this is only for CI and to provide a reference example. It is always expected this container image be deployed under Sysbox.

### Hard Rules

- Non-root services: Container runs as root for dockerd; opencode, openchamber, and agent-init drop to `agent` (uid 1000) via `s6-setuidgid`. Never install sudo/doas/su.
- No privilege escalation: Never add sudo, doas, su, or any root-escalation mechanism.
- TLS-only downloads: Use `https://` for all fetched URLs. Use `--proto '=https' --tlsv1.2` for curl where supported.
- No secrets in image: Never bake API keys, tokens, or credentials into the Dockerfile or rootfs.

### Package Installation

- System packages (apt): Add to the Dockerfile only. Group related packages. Clean up apt caches in the same RUN layer.
- User-space tools (cargo/npm/pip/bun): Add to `agent-setup.sh` for tools needed at runtime. These install into the persistent volume under `/home/agent`.
- Prefer official package registries (apt, crates.io, npmjs, PyPI). Curl-pipe-bash installs are acceptable only from well-known installers (rustup, nvm) and must use HTTPS.
- Do not pin apt package versions, install the latest stable release when possible.

## Editing Guidelines

### Dockerfile

- Layers (e.g., the `RUN` blocks) should be designed thoughtfully. Goals:
  - Minimal layers: Minimize the number of small layers, merging small layers into larger layers.
  - Caching: Layers should be order to maximize caching. Layers that are unlikely to change should be before layers that are more likely to change.
  - Self contained: Each layer should cleanup after performing actions - so minimize wasted space.
  - Maximize down concurrency: While one single `RUN` block would minimize layers, Docker downloads layers currently. Massive layers should be split into smaller layers when appropriate.
- Validate installed software - either by using the existing infrastructure (e.g., apt-get verifies downloads) or if installing manually, use SHA256 hashes to verify downloads.
- If a package needs special capabilities (like `dumpcap`), grant them via `setcap` - never via setuid.

## Areas

There are two logical areas of focus:

- System installed tools (this `agent-image` project). Anything that requires `root` to install/configure, are system installed tools. System installed tools generally should be built with the latest, unless installing the latest isn't possible without verification of the download.
- Tools managed by the agent running inside the container. Anything within `/home/agent` should be managed by the agent. The `agent-setup.sh` script runs as the agent user to bootstrap tooling if the tooling doesn't exist. Once installed, the agent is responsible for updates and continued maintenance.
  - The only exception is tooling the agent can't self update safely - `opencode` and `openchamber` (which are automatically updated on container start). Note that Node is a dependency, so is also installed/updated as needed by `agent-setup.sh`.

### rootfs/

- `agent-setup.sh`: Runs as `agent` user at container boot. Idempotent - always check before installing.
- s6 service files use execlineb syntax. Service types: `oneshot` (run-once) or `longrun` (daemon).
- Dependencies between services are declared via empty files in `dependencies.d/`.
- Services are registered in `user/contents.d/`.
- Agent services must set `HOME` and `cd`: Any service or script that runs as `agent` via `s6-setuidgid` must explicitly set `export HOME /home/agent` (before `s6-setuidgid`) and `cd /home/agent`. `s6-setuidgid` drops the uid but does not update `HOME`, so without this tools like rustup, cargo, and nvm will attempt to write to `/root` and fail.

### docker-compose.yml

- The `docker-compose.yaml` is used both as a reference example and for CI.
- `privileged: true` is set for Docker-in-Docker to work under the default runtime.

### Verification

After making changes, verify the container boots and becomes healthy within 10 minutes:

```bash
docker compose up --build --force-recreate --renew-anon-volumes --wait --wait-timeout 600
```

### Documentation Maintenance

When packages or tools are added to (or removed from) the Dockerfile or `agent-setup.sh`, update the `README.md` and `rootfs/IMAGES.md` to reflect the change. If, when reading the `README.md` or `rootfs/IMAGES.md` you see inconsistencies, ask the user if these inconsistencies should be corrected.

## Conventions

- Conventional Commits: Keep commits concise.
- Branch: `master` is the sole release branch. CI publishes on push to master and weekly.
- CI uses a reusable workflow from `silvenga-docker/building`. Don't modify the workflow unless the upstream contract changes.

## PRs

New changes should be introduced with a PR. When making a PR, make sure you've fetched and rebased onto origin/master. PR titles must be in Conventional Commit format (the PR will be squashed, and the title will be the commit).

Before making the PR, run the `open-code-review` skill, considering any findings, and if the findings are relevant, apply the required changes.
