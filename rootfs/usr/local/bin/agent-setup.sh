#!/usr/bin/env bash
set -e

: "${CARGO_HOME:?CARGO_HOME is unset or empty}"
: "${NVM_DIR:?NVM_DIR is unset or empty}"
: "${BUN_INSTALL:?BUN_INSTALL is unset or empty}"
: "${ANDROID_HOME:?ANDROID_HOME is unset or empty}"
: "${GRADLE_HOME:?GRADLE_HOME is unset or empty}"

retry() {
    local attempts=$1 max_backoff=$2
    shift 2
    local n=0 wait=$max_backoff
    until "$@"; do
        n=$((n + 1))
        if [ "$n" -ge "$attempts" ]; then
            echo "retry: command failed after $attempts attempts: $*" >&2
            return 1
        fi
        echo "retry: attempt $n/$attempts failed, retrying in ${wait}s..." >&2
        sleep "$wait"
        wait=$((wait * 2))
    done
}

echo "Ensuring tools are installed for user $(id -un)..."

if [ ! -d "$CARGO_HOME" ]; then
    echo "Installing Cargo/Rustup..."
    RUSTUP_VERSION=1.29.0
    RUSTUP_SHA256=4acc9acc76d5079515b46346a485974457b5a79893cfb01112423c89aeb5aa10
    curl -fsSL "https://static.rust-lang.org/rustup/archive/${RUSTUP_VERSION}/x86_64-unknown-linux-gnu/rustup-init" -o /tmp/rustup-init
    echo "${RUSTUP_SHA256}  /tmp/rustup-init" | sha256sum -c -
    chmod +x /tmp/rustup-init
    /tmp/rustup-init -y
    rm /tmp/rustup-init
else
    echo "Cargo/Rustup already installed."
fi

if ! command -v cargo-binstall &>/dev/null; then
    echo "Installing cargo-binstall..."
    BINSTALL_SHA256=d3a93702160e0ec03e2a4e996855db1f01adee801fb84a43add24e0877ef8eae
    curl -fsSL "https://raw.githubusercontent.com/cargo-bins/cargo-binstall/30b5ca8b54e1dcffd9548bc87ede1531310fdc67/install-from-binstall-release.sh" -o /tmp/install-binstall.sh
    echo "${BINSTALL_SHA256}  /tmp/install-binstall.sh" | sha256sum -c -
    bash /tmp/install-binstall.sh
    rm /tmp/install-binstall.sh

    # Needed possibly due to a bug in cargo-binstall where the binary is not marked executable after installation.
    chmod +x /home/agent/.cargo/bin/cargo-binstall
else
    echo "cargo-binstall already installed."
fi

echo "Installing/Updating sccache..."
cargo binstall sccache --no-confirm

if [ ! -d "$NVM_DIR" ]; then
    echo "Installing nvm..."
    NVM_VERSION=v0.40.1
    NVM_SHA256=abdb525ee9f5b48b34d8ed9fc67c6013fb0f659712e401ecd88ab989b3af8f53
    curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" -o /tmp/nvm-install.sh
    echo "${NVM_SHA256}  /tmp/nvm-install.sh" | sha256sum -c -
    bash /tmp/nvm-install.sh
    rm /tmp/nvm-install.sh
fi

[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

echo "Installing/Updating Node LTS..."
nvm install lts/*
nvm alias default lts/*
nvm use default
ln -sfn "$(dirname "$(dirname "$(nvm which default)")")" "$NVM_DIR/current"

if [ ! -d "$BUN_INSTALL" ]; then
    echo "Installing Bun..."
    BUN_VERSION=1.1.20
    BUN_SHA256=6cb70ad0349a2cecc94ab2113cd1d07a5779aae77c71cab1cf20c881ac0c0775
    curl -fsSL "https://github.com/oven-sh/bun/releases/download/bun-v${BUN_VERSION}/bun-linux-x64.zip" -o /tmp/bun-linux-x64.zip
    echo "${BUN_SHA256}  /tmp/bun-linux-x64.zip" | sha256sum -c -
    unzip -q /tmp/bun-linux-x64.zip -d /tmp/bun-extract
    mkdir -p "${BUN_INSTALL}/bin"
    mv /tmp/bun-extract/bun-linux-x64/bun "${BUN_INSTALL}/bin/bun"
    ln -sf "${BUN_INSTALL}/bin/bun" "${BUN_INSTALL}/bin/bunx"
    rm -rf /tmp/bun-linux-x64.zip /tmp/bun-extract
fi

# SHA-1 is the only checksum Google publishes for cmdline-tools.
CMDLINETOOLS_BUILD=15641748
CMDLINETOOLS_SHA1=63523a02a975a81102238566f2a16c057d52301e
if [ ! -d "$ANDROID_HOME/cmdline-tools/latest" ]; then
    echo "Installing Android SDK Command-line Tools (build ${CMDLINETOOLS_BUILD})..."
    curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINETOOLS_BUILD}_latest.zip" -o /tmp/cmdline-tools.zip
    echo "${CMDLINETOOLS_SHA1}  /tmp/cmdline-tools.zip" | sha1sum -c -
    unzip -q /tmp/cmdline-tools.zip -d /tmp/cmdline-tools-extract
    mkdir -p "$ANDROID_HOME/cmdline-tools"
    mv /tmp/cmdline-tools-extract/cmdline-tools "$ANDROID_HOME/cmdline-tools/latest"
    rm -rf /tmp/cmdline-tools.zip /tmp/cmdline-tools-extract
else
    echo "Android SDK Command-line Tools already installed."
fi

if [ ! -L "$ANDROID_HOME/ndk/current" ]; then
    echo "Accepting Android SDK licenses..."
    retry 3 5 bash -c 'yes | sdkmanager --licenses' >/dev/null 2>&1 || true

    echo "Installing Android SDK components (build-tools 36.0.0, platform android-36, cmake 3.22.1)..."
    retry 5 5 sdkmanager "build-tools;36.0.0" "platforms;android-36" "cmake;3.22.1"

    echo "Installing latest NDK r28.x..."
    NDK_VERSION=$(retry 5 5 sdkmanager --list | grep -oP 'ndk;28\.\K[0-9.]+' | sort -V | tail -1)
    if [ -z "$NDK_VERSION" ]; then
        echo "ERROR: No NDK r28.x found in sdkmanager --list. Skipping NDK install." >&2
    else
        retry 5 5 sdkmanager "ndk;28.${NDK_VERSION}"
        ln -sfn "$ANDROID_HOME/ndk/28.${NDK_VERSION}" "$ANDROID_HOME/ndk/current"
        echo "NDK 28.${NDK_VERSION} installed, symlinked to ndk/current."
    fi
else
    echo "Android NDK already installed (ndk/current symlink exists)."
fi

GRADLE_VERSION=9.5.1
GRADLE_SHA256=bafc141b619ad6350fd975fc903156dd5c151998cc8b058e8c1044ab5f7b031f
if [ ! -d "$GRADLE_HOME" ]; then
    echo "Installing Gradle ${GRADLE_VERSION}..."
    curl -fsSL "https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip" -o /tmp/gradle-bin.zip
    echo "${GRADLE_SHA256}  /tmp/gradle-bin.zip" | sha256sum -c -
    unzip -q /tmp/gradle-bin.zip -d /tmp/gradle-extract
    mkdir -p "$(dirname "$GRADLE_HOME")"
    mv "/tmp/gradle-extract/gradle-${GRADLE_VERSION}" "$GRADLE_HOME"
    rm -rf /tmp/gradle-bin.zip /tmp/gradle-extract
else
    echo "Gradle already installed."
fi

echo "Installing/Upgrading OpenCode..."
bun add -g opencode-ai@latest --no-summary
bun update -g --latest opencode-ai@latest

echo "Running OpenCode postinstall script..."
# https://github.com/anomalyco/opencode/issues/27906
pushd "${BUN_INSTALL}/install/global/node_modules/opencode-ai"
node postinstall.mjs
popd

echo "Installing/Upgrading OpenChamber..."
bun add -g @openchamber/web@latest --no-summary
bun update -g --latest @openchamber/web@latest

echo "Removing stale OpenChamber pids..."
rm -rf "$HOME/.config/openchamber/run"

echo "Clearing stale OpenCode plugin cache..."
rm -rf "$HOME/.cache/opencode/packages"

echo "Agent setup complete."
