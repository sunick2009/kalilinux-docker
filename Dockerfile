FROM kalilinux/kali-rolling:latest
RUN apt-get update && \
    apt-get -y upgrade
# apt-get install -yq kali-linux-headless

RUN DEBIAN_FRONTEND=noninteractive apt-get -yq install \
    sudo \
    openssh-server \
    python2 \
    python3 \
    dialog \
    firefox-esr \
    inetutils-ping \
    htop \
    vim \
    neovim \
    tmux \
    zsh \
    curl \
    git \
    net-tools \
    tigervnc-standalone-server \
    tigervnc-xorg-extension \
    tigervnc-viewer \
    novnc \
    dbus-x11 \
    xterm \
    x11-xserver-utils

RUN DEBIAN_FRONTEND=noninteractive apt-get -yq install \
    xfce4-goodies \
    kali-desktop-xfce && \
    apt-get -y full-upgrade

# Install VS Code
RUN apt-get update && \
    apt-get install -yq wget gpg && \
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg && \
    install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/ && \
    sh -c 'echo "deb [arch=arm64,armhf,amd64 signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' && \
    apt-get update && \
    apt-get install -yq code

# Install Go 1.25.1 with automatic architecture detection
RUN ARCH=$(dpkg --print-architecture) && \
    case $ARCH in \
        amd64) GO_ARCH="amd64" ;; \
        arm64) GO_ARCH="arm64" ;; \
        armhf) GO_ARCH="armv6l" ;; \
        *) echo "Unsupported architecture: $ARCH" && exit 1 ;; \
    esac && \
    GO_VERSION="1.25.1" && \
    GO_URL="https://golang.org/dl/go${GO_VERSION}.linux-${GO_ARCH}.tar.gz" && \
    echo "Installing Go ${GO_VERSION} for architecture: ${GO_ARCH}" && \
    wget -q "$GO_URL" -O /tmp/go.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm /tmp/go.tar.gz

RUN apt-get -y autoremove && \
    apt-get clean all && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -c "kali" -s /bin/bash -d /home/kali kali && \
    sed -i "s/#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/g" /etc/ssh/sshd_config && \
    sed -i "s/off/remote/g" /usr/share/novnc/app/ui.js && \
    echo "kali ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers && \
    mkdir /run/dbus && \
    touch /usr/share/novnc/index.htm && \
    mkdir -p /home/kali/.vnc && \
    chown -R kali:kali /home/kali/.vnc

# Remove any screen locker to avoid conflict with VNC
# 讓任何鎖屏呼叫失效
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/xflock4 && chmod +x /usr/local/bin/xflock4

# 禁用自動啟動（兼容多種檔名）
RUN <<'SH'
set -e
for f in /etc/xdg/autostart/*screensaver*.desktop; do
  [ -f "$f" ] || continue
  sed -i 's/^Exec=.*/Exec=true/' "$f"
  if grep -q '^X-GNOME-Autostart-enabled=' "$f"; then
    sed -i 's/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/' "$f"
  else
    echo 'X-GNOME-Autostart-enabled=false' >> "$f"
  fi
  grep -q '^Hidden=' "$f" || echo 'Hidden=true' >> "$f"
done
SH

# 只對「存在且為檔案」的目標做 divert → 空殼
RUN <<'SH'
set -e
for p in /usr/bin/xfce4-screensaver /usr/libexec/xfce4-screensaver /usr/libexec/xfce4-screensaver-dialog; do
  if [ -f "$p" ]; then
    dpkg-divert --quiet --rename --add "$p" || true
    printf '#!/bin/sh\nexit 0\n' > "$p"
    chmod +x "$p"
  fi
done
SH

# 建立登入後自動復位腳本
RUN <<'SH'
cat >/usr/local/bin/xfce-napless.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# 自動偵測 DISPLAY（預設 :1）
if [[ -z "${DISPLAY:-}" ]]; then
  dspy=$(ps -ef | awk '/Xtigervnc/ && $0 ~ /:[0-9]+/ {match($0, /:[0-9]+/); print substr($0, RSTART, RLENGTH); exit}')
  export DISPLAY="${dspy:-:1}"
fi

# 等 X 就緒（用 xset，比 xdpyinfo 泛用）
for i in $(seq 1 30); do
  (command -v xset >/dev/null 2>&1 && xset q >/dev/null 2>&1) && break || sleep 1
done

# X11 層：關 screensaver/DPMS
if command -v xset >/dev/null 2>&1; then
  xset s off; xset s noblank; xset s 0 0; xset -dpms || true
fi

# XFCE 層：關鎖定
if command -v xfconf-query >/dev/null 2>&1; then
  xfconf-query -c xfce4-power-manager   -p /xfce4-power-manager/lock-screen-suspend-hibernate -n -t bool -s false || true
  xfconf-query -c xfce4-screensaver     -p /lock-enabled            -n -t bool -s false      || true
  xfconf-query -c xfce4-screensaver     -p /idle-activation-enabled -n -t bool -s false      || true
fi

# 清掉殘留鎖屏進程
pkill -f -e "xfce4-screensaver|xfce4-screensaver-dialog" || true
exit 0
EOF
chmod +x /usr/local/bin/xfce-napless.sh
SH

# 系統層 autostart（不吃 $HOME）
RUN <<'SH'
cat >/etc/xdg/autostart/10-napless.desktop <<'EOF'
[Desktop Entry]
Type=Application
Name=Disable sleep/lock (container)
Exec=/usr/local/bin/xfce-napless.sh
OnlyShowIn=XFCE;
X-GNOME-Autostart-enabled=true
EOF
SH

# --- Yazi & deps (Debian/Kali) ---
# 基本與可選相依
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      ca-certificates curl unzip \
      file jq ripgrep fzf zoxide poppler-utils ffmpeg imagemagick fd-find \
      7zip || apt-get install -y p7zip-full && \
    # Debian 將 fd 命名為 fdfind，建立一致的 fd 名稱
    ln -sf /usr/bin/fdfind /usr/local/bin/fd && \
    rm -rf /var/lib/apt/lists/*

# 下載並安裝 Yazi（自動偵測架構 + 自動尋找解壓後的二進位路徑）
ARG YAZI_VERSION=v25.5.31
RUN set -eux; \
    arch="$(dpkg --print-architecture)"; \
    case "$arch" in \
      amd64)   yarch="x86_64-unknown-linux-gnu" ;; \
      arm64)   yarch="aarch64-unknown-linux-gnu" ;; \
      i386)    yarch="i686-unknown-linux-gnu" ;; \
      riscv64) yarch="riscv64gc-unknown-linux-gnu" ;; \
      *) echo "unsupported arch: $arch"; exit 1 ;; \
    esac; \
    tmpdir="$(mktemp -d)"; \
    url="https://github.com/sxyazi/yazi/releases/download/${YAZI_VERSION}/yazi-${yarch}.zip"; \
    echo "[yazi] fetching $url"; \
    curl -fsSL "$url" -o "$tmpdir/yazi.zip"; \
    unzip -q "$tmpdir/yazi.zip" -d "$tmpdir"; \
    bindir="$(find "$tmpdir" -maxdepth 2 -type f -name yazi -printf '%h\n' -quit)"; \
    [ -n "$bindir" ] || { echo "yazi binary not found after unzip"; ls -R "$tmpdir"; exit 1; }; \
    install -m 0755 "$bindir/yazi" /usr/local/bin/yazi; \
    install -m 0755 "$bindir/ya"   /usr/local/bin/ya; \
    rm -rf "$tmpdir"

# 安裝 Zsh/Bash 的 `y` wrapper：離開 Yazi 後自動 cd 到最後所在子目錄（官方 Quick Start）
RUN <<'SH'
set -e
# for Bash（/etc/profile.d）
cat >/etc/profile.d/50-yazi-wrapper.sh <<'EOF'
# Bash wrapper: use `y` instead of `yazi` to preserve CWD on exit
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp" || true
  [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
EOF

# for Zsh（/etc/zsh/zshrc.d，Debian/Kali 會自動 source 這個目錄）
mkdir -p /etc/zsh/zshrc.d
cat >/etc/zsh/zshrc.d/50-yazi-wrapper.zsh <<'EOF'
# Zsh wrapper
function y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp" || true
  [[ -n "$cwd" && "$cwd" != "$PWD" ]] && builtin cd -- "$cwd"
  rm -f -- "$tmp"
}
EOF
SH
# —— 安裝 CJK 與 Emoji（供 fallback）——
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
      fonts-noto-cjk fonts-noto-color-emoji \
  && rm -rf /var/lib/apt/lists/*

# —— 安裝 Nerd Fonts「Symbols Only」（補齊常見圖示）——
ARG NF_VERSION=v3.2.1
RUN set -eux; \
    mkdir -p /usr/local/share/fonts/NerdFonts/Symbols; \
    curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/download/${NF_VERSION}/NerdFontsSymbolsOnly.zip" \
      -o /tmp/NerdFontsSymbolsOnly.zip; \
    unzip -q /tmp/NerdFontsSymbolsOnly.zip -d /usr/local/share/fonts/NerdFonts/Symbols; \
    rm -f /tmp/NerdFontsSymbolsOnly.zip; \
    fc-cache -f
# --- end Yazi ---

# burpsuite dependencies
RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    apt-get -yq install \
    openjdk-21-jdk \
    chromium

COPY startup.sh /startup.sh
RUN chmod +x /startup.sh && chown kali:kali /startup.sh
COPY bootstrap-dotfiles.sh /usr/local/bin/bootstrap-dotfiles.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/bootstrap-dotfiles.sh /usr/local/bin/entrypoint.sh \
    && chown kali:kali /usr/local/bin/bootstrap-dotfiles.sh /usr/local/bin/entrypoint.sh

USER kali
WORKDIR /home/kali
ENV PASSWORD=kalilinux
ENV SHELL=/bin/bash
ENV PATH=/usr/local/go/bin:$PATH
ENV GOPATH=/home/kali/go
ENV GOROOT=/usr/local/go
ENV GOBIN=/home/kali/go/bin


# Create Go workspace directory
RUN mkdir -p /home/kali/go/{bin,src,pkg}
# for vnc web client
EXPOSE 8080
# for vscode server
EXPOSE 8088
ENTRYPOINT ["/bin/zsh", "/usr/local/bin/entrypoint.sh"]
