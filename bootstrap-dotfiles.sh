#!/usr/bin/env bash
set -euo pipefail

: "${DOTFILES_REPO:=https://github.com/sunick2009/my-dotfiles}"
: "${DOTFILES_BRANCH:=master}"
: "${DOTFILES_DIR:=$HOME/my-dotfiles}"
: "${DOTFILES_MARK:=$HOME/my-dotfiles.installed}"
: "${DOTFILES_FORCE:=0}"       # "1" = 強制硬重置
: "${BOOTSTRAP_STRICT:=1}"     # "0" = 失敗也繼續啟動
# 跳過 Neovim 安裝腳本（僅限啟動期，跑完還原）
: "${DOTFILES_SKIP_NVIM:=1}"   # 需要時改成 "0" 恢復原行為

echo "[bootstrap] env: DOTFILES_FORCE=${DOTFILES_FORCE:-<unset>} BOOTSTRAP_STRICT=${BOOTSTRAP_STRICT:-<unset>}"

need_run() { [[ ! -f "$DOTFILES_MARK" ]] || [[ "$DOTFILES_FORCE" == "1" ]]; }
is_dirty() { test -n "$(git -C "$DOTFILES_DIR" status --porcelain 2>/dev/null || true)"; }

# ===== 安全接管（takeover）設定 =====
: "${DOTFILES_TAKEOVER_MODE:=backup}"   # backup|replace|skip
: "${DOTFILES_BAKDIR:=$HOME/.dotfiles-prebootstrap-bak}"
# 依你的 dotfiles 實際會處理到的目標列清單（可再加 .zshrc、.gitconfig 等）
TAKEOVER_TARGETS=(
  "$HOME/.config"
  "$HOME/.local"
  "$HOME/.cache"
  "$HOME/.oh-my-zsh"
)

timestamp() { date +"%Y%m%d-%H%M%S"; }

safe_takeover_one() {
  local dst="$1"
  # 已經是 symlink → 無需動作
  if [ -L "$dst" ]; then return 0; fi
  # 不存在 → 無需動作
  if [ ! -e "$dst" ]; then return 0; fi

  case "$DOTFILES_TAKEOVER_MODE" in
    backup)
      mkdir -p "$DOTFILES_BAKDIR"
      local bak="$DOTFILES_BAKDIR/$(basename "$dst").$(timestamp)"
      echo "[bootstrap] takeover: backup '$dst' -> '$bak'"
      mv -v "$dst" "$bak"
      ;;
    replace)
      echo "[bootstrap] takeover: replace '$dst' (rm -rf)"
      rm -rf --one-file-system -- "$dst"
      ;;
    skip)
      echo "[bootstrap] takeover: skip existing '$dst' (not a symlink)";;
    *)
      echo "[bootstrap] takeover: unknown mode '$DOTFILES_TAKEOVER_MODE' (use backup|replace|skip)" >&2
      exit 1
      ;;
  esac
}

safe_takeover_batch() {
  for p in "${TAKEOVER_TARGETS[@]}"; do
    safe_takeover_one "$p"
  done
}

if need_run; then
  echo "[bootstrap] installing from $DOTFILES_REPO ($DOTFILES_BRANCH)…"

  if [[ -d "$DOTFILES_DIR/.git" ]]; then
    if [[ "$DOTFILES_FORCE" == "1" ]]; then
      echo "[bootstrap] FORCE=1 -> hard reset local repo"
      git -C "$DOTFILES_DIR" reset --hard HEAD || true
      git -C "$DOTFILES_DIR" clean -fdx || true
    elif is_dirty; then
      echo "[bootstrap] repo dirty -> discard local changes"
      # 將追蹤檔恢復；避免 rebase/pull 被檔
      git -C "$DOTFILES_DIR" checkout -- . || true
      git -C "$DOTFILES_DIR" restore . || true
      # 若仍有殘留（未追蹤檔）
      git -C "$DOTFILES_DIR" clean -fd || true
    else
      echo "[bootstrap] repo clean"
    fi

    # 對齊遠端
    git -C "$DOTFILES_DIR" fetch --depth=1 origin "$DOTFILES_BRANCH" || true
    git -C "$DOTFILES_DIR" checkout -f "$DOTFILES_BRANCH" || true
    git -C "$DOTFILES_DIR" reset --hard "origin/$DOTFILES_BRANCH" || true
    git -C "$DOTFILES_DIR" submodule update --init --recursive --depth 1 || true
  else
    rm -rf "$DOTFILES_DIR"
    git clone --depth 1 --recurse-submodules -b "$DOTFILES_BRANCH" \
      "$DOTFILES_REPO" "$DOTFILES_DIR"
  fi
  
  # 先做 takeover，避免 ln: cannot overwrite directory
  safe_takeover_batch

  # --- PATH shim: 讓 chsh 成功且不動系統 ---
  if [ "${DOTFILES_SHIM_CHSH:-1}" = "1" ]; then
    SHIM_DIR="$HOME/.shim-bin"
    mkdir -p "$SHIM_DIR"

  cat > "$SHIM_DIR/chsh" <<'EOF'
#!/usr/bin/env bash
# no-op chsh for container/non-interactive bootstrap
echo "[shim] chsh skipped (container/non-interactive)."
exit 0
EOF
  chmod +x "$SHIM_DIR/chsh"

  # 只需要攔 chsh；sudo 的 secure_path 會忽略我們的 PATH，不影響 root 命令
  export PATH="$SHIM_DIR:$PATH"
  fi
  # modified dotfiles script exec permission
  echo "[bootstrap] fix script/neovim_install.sh permission problem"
  chmod +x "$DOTFILES_DIR/script/neovim_install.sh"
  if [ "$DOTFILES_SKIP_NVIM" = "1" ]; then
    tgt="$DOTFILES_DIR/script/neovim_install.sh"
    if [ -f "$tgt" ]; then
      echo "[bootstrap] skipping $tgt (preinstalled by image)"
      # 在檔頭插入守門條件；保持可執行；離開時用 git 還原，工作樹保持乾淨
      if ! head -n1 "$tgt" | grep -q 'bootstrap-skip-nvim'; then
        tmp="$(mktemp)"
        {
          echo '# bootstrap-skip-nvim'
          echo 'echo "[bootstrap] nvim installer bypassed"; exit 0'
        } >"$tmp"
        cat "$tgt" >>"$tmp" && cat "$tmp" >"$tgt"
        rm -f "$tmp"
        chmod +x "$tgt" || true
      fi
      trap 'git -C "$DOTFILES_DIR" checkout -- script/neovim_install.sh >/dev/null 2>&1 || true' RETURN
    fi
  fi

  
  if ! ( cd "$DOTFILES_DIR" && bash ./main.sh ); then
    echo "[bootstrap] main.sh failed" >&2
    [[ "$BOOTSTRAP_STRICT" == "1" ]] && exit 1
  fi

  date -Is > "$DOTFILES_MARK"
  echo "[bootstrap] dotfiles installed."
else
  echo "[bootstrap] skipped (already installed)."
fi