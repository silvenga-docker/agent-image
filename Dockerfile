FROM debian:trixie-slim AS base

ARG URL_7Z=https://github.com/ip7z/7zip/releases/download/26.01/7z2601-linux-x64.tar.xz
ARG URL_7Z_SHA256=8ea0fc8a135e7b848e80a4116fe22dff56c8c4518dde1f43cce67f4e340b437a

ARG S6_OVERLAY_VERSION=3.2.3.1
ARG S6_OVERLAY_NOARCH_SHA256=43d99d266fefe32cdc1510963aaadeb211cc8450b60af27817b64af450c934be
ARG S6_OVERLAY_X86_64_SHA256=ed72fdb3abf196472d121b026bed63b46f3443507bd2ce67df6bd187f7d4dc0a

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -xe \
    set -xe \
    && apt-get update \
    && apt-get dist-upgrade -y \
    && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    xz-utils \
    && curl -fsSL ${URL_7Z} -o /tmp/7z.tar.xz \
    && echo "${URL_7Z_SHA256}  /tmp/7z.tar.xz" | sha256sum -c - \
    && tar xf /tmp/7z.tar.xz -C /tmp/ \
    && install /tmp/7zz /usr/bin/7zz \
    && install /tmp/7zz /usr/bin/7z \
    && rm /tmp/7z.tar.xz /tmp/7zz \
    && curl -fsSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz -o /tmp/s6-overlay-noarch.tar.xz \
    && echo "${S6_OVERLAY_NOARCH_SHA256}  /tmp/s6-overlay-noarch.tar.xz" | sha256sum -c - \
    && curl -fsSL https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-x86_64.tar.xz -o /tmp/s6-overlay-x86_64.tar.xz \
    && echo "${S6_OVERLAY_X86_64_SHA256}  /tmp/s6-overlay-x86_64.tar.xz" | sha256sum -c - \
    && tar -C / -Jxpf /tmp/s6-overlay-noarch.tar.xz \
    && tar -C / -Jxpf /tmp/s6-overlay-x86_64.tar.xz \
    && rm /tmp/s6-overlay-noarch.tar.xz /tmp/s6-overlay-x86_64.tar.xz

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -xe \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl --proto '=https' --tlsv1.2 -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
    && chmod a+r /etc/apt/keyrings/docker.asc \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    bash \
    git \
    less \
    openssh-client \
    python3 \
    build-essential \
    pkg-config \
    libssl-dev \
    ripgrep \
    fd-find \
    gnupg \
    libcap2-bin \
    cmake \
    clang \
    lld \
    libclang-dev \
    openjdk-21-jdk-headless \
    jq \
    sqlite3 \
    unzip \
    dnsutils \
    postgresql-client \
    redis-tools \
    python3-pip \
    pipx \
    whois \
    nmap \
    mtr-tiny \
    tshark \
    tcpdump \
    socat \
    proxychains4 \
    bsdextrautils \
    b3sum \
    file \
    xxd \
    libwebkit2gtk-4.1-dev \
    libgtk-3-dev \
    libglib2.0-dev \
    libgio-2.0-dev \
    libdbus-1-dev \
    librsvg2-dev \
    libsoup-3.0-dev \
    containerd.io \
    docker-ce \
    docker-ce-cli \
    docker-compose-plugin

RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    set -xe \
    && install -m 0755 -d /etc/apt/keyrings \
    && curl --proto '=https' --tlsv1.2 -fsSL https://dl.google.com/linux/linux_signing_key.pub -o /etc/apt/keyrings/google-chrome.asc \
    && chmod a+r /etc/apt/keyrings/google-chrome.asc \
    && echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google-chrome.asc] https://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    google-chrome-stable \
    && rm -f /etc/ssh/ssh_config.d/20-systemd-ssh-proxy.conf

COPY rootfs/ /

RUN groupadd -g 1000 agent \
    && useradd -u 1000 -g 1000 -m -s /bin/bash agent \
    && usermod -aG docker agent \
    && chmod +x /usr/local/bin/agent-setup.sh \
    && chmod +x /usr/local/bin/healthcheck.sh \
    && chmod +x /usr/local/bin/rm \
    && setcap cap_net_raw,cap_net_admin=eip /usr/bin/dumpcap \
    && git config --system core.excludesFile /etc/gitignore_global \
    && install -d -m 0755 /var/lib/java-cacerts \
    && ln -sfn /var/lib/java-cacerts/cacerts /usr/lib/jvm/java-21-openjdk-amd64/lib/security/cacerts \
    && javac -d /usr/local/bin /usr/local/bin/gen-cacerts.java \
    && rm /usr/local/bin/gen-cacerts.java

RUN printf '#include <signal.h>\n#include <stdio.h>\nint main(void){if(kill(1,SIGTERM)!=0){perror("reboot: kill");return 1;}return 0;}' > /tmp/reboot.c \
    && gcc -O2 -o /usr/local/bin/reboot /tmp/reboot.c \
    && setcap cap_kill=eip /usr/local/bin/reboot \
    && rm /tmp/reboot.c

ENV S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_KEEP_ENV=1 \
    CI=true \
    DEBIAN_FRONTEND=noninteractive \
    GIT_TERMINAL_PROMPT=0 \
    GIT_EDITOR=: \
    EDITOR=: \
    VISUAL= \
    GIT_SEQUENCE_EDITOR=: \
    GIT_MERGE_AUTOEDIT=no \
    GIT_PAGER=cat \
    PAGER=cat \
    npm_config_yes=true \
    PIP_NO_INPUT=1 \
    YARN_ENABLE_IMMUTABLE_INSTALLS=false \
    BUN_INSTALL="/home/agent/.bun" \
    CARGO_HOME="/home/agent/.cargo" \
    RUSTC_WRAPPER="/home/agent/.cargo/bin/sccache" \
    NVM_DIR="/home/agent/.nvm" \
    JAVA_HOME="/usr/lib/jvm/java-21-openjdk-amd64" \
    ANDROID_HOME="/home/agent/Android/Sdk" \
    ANDROID_SDK_ROOT="/home/agent/Android/Sdk" \
    ANDROID_NDK_HOME="/home/agent/Android/Sdk/ndk/current" \
    ANDROID_NDK_ROOT="/home/agent/Android/Sdk/ndk/current" \
    GRADLE_HOME="/home/agent/.local/gradle-9.5.1"

ENV PATH="${JAVA_HOME}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/build-tools/36.0.0:${GRADLE_HOME}/bin:/home/agent/.cargo/bin:/home/agent/.bun/bin:/home/agent/.nvm/current/bin:/home/agent/.local/bin:${PATH}"

VOLUME ["/home/agent", "/var/lib/docker", "/tmp"]

ENTRYPOINT ["/init"]

HEALTHCHECK --start-interval=2s --timeout=5s --start-period=10m CMD /usr/local/bin/healthcheck.sh
