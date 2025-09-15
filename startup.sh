#!/usr/bin/env bash
set -euo pipefail

# Hardened startup for Kali + TigerVNC + noVNC
# - Fix password path/perm (XDG: ~/.config/tigervnc/passwd, 0600)
# - Pin DISPLAY :1 (maps to TCP 5901)
# - Clean stale locks before start
# - Provide minimal XFCE xstartup if missing
# - Support GEOMETRY and BIND env vars

export DISPLAY=:1
PASSWORD="${PASSWORD:-kalilinux}"
GEOMETRY="${GEOMETRY:-1920x1080}"
BIND="${BIND:-0.0.0.0:8080}"

# Prepare TigerVNC passwd in new path
CONF="$HOME/.config/tigervnc"
install -d -m 700 "$CONF"
printf '%s' "$PASSWORD" | vncpasswd -f > "$CONF/passwd"
chmod 600 "$CONF/passwd"

# Minimal XFCE xstartup if missing
if [ ! -x "$HOME/.vnc/xstartup" ]; then
  mkdir -p "$HOME/.vnc"
  cat > "$HOME/.vnc/xstartup" <<'EOF'
#!/bin/bash
export XKL_XMODMAP_DISABLE=1
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start D-Bus session
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval `dbus-launch --sh-syntax --exit-with-session`
fi

# Start desktop environment
exec startxfce4
EOF
  chmod +x "$HOME/.vnc/xstartup"
fi

# Basic Xauthority
[ -f "$HOME/.Xauthority" ] || touch "$HOME/.Xauthority"

# Clean locks and start VNC on :1 (5901)
vncserver -kill :1 >/dev/null 2>&1 || true
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
# 若密碼>8，僅前8字元有效（VNC 傳統行為）
if [ ${#PASSWORD} -gt 8 ]; then
  echo "WARN: VNC password > 8 chars; only first 8 are used."
fi

vncserver :1 -geometry "$GEOMETRY" -localhost yes \
  -SecurityTypes=VncAuth \
  -PasswordFile="$CONF/passwd"

# Optional: start a session dbus for DE features (non-fatal if fails)
if command -v dbus-daemon >/dev/null 2>&1; then
  dbus-daemon --session --fork || true
fi

# Start noVNC proxy (prefer novnc_proxy, fallback to websockify)
if [ -x /usr/share/novnc/utils/novnc_proxy ]; then
  /usr/share/novnc/utils/novnc_proxy --listen "$BIND" --vnc 127.0.0.1:5901
else
  websockify --web=/usr/share/novnc "$BIND" 127.0.0.1:5901
fi
