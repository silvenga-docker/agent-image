#!/usr/bin/env bash
set -euo pipefail

check_http() {
  local name="$1"
  local url="$2"
  curl -sf --connect-timeout 2 --max-time 3 "$url" >/dev/null 2>&1 || {
    echo "healthcheck: ${name} not responding at ${url}" >&2
    return 1
  }
}

# OpenChamber is the terminal service in the boot chain — it depends on
# dockerd-ready, which depends on agent-init, and manages OpenCode's lifecycle.
# If OpenChamber is serving, the entire chain has completed successfully.
check_http openchamber http://localhost:3000/health
