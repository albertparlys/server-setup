#!/usr/bin/env bash
# ============================================================
#  lib/modules.sh — installer khusus (idempotent) + setup env shell.
#
#  Setiap "module" adalah fungsi  mod_<nama>  yang aman dijalankan
#  berkali-kali. Module di sini sengaja dibuat lintas-distro: rata-rata
#  pakai installer resmi via curl ke ruang user ($HOME), bukan apt.
#
#  NAMBAH MODULE: tulis fungsi  mod_<nama>  di bawah, lalu daftarkan
#  deskripsinya di MOD_DESC. Lihat docs/adding-a-module.md.
# ============================================================

[ -n "${_RS_MODULES_LOADED:-}" ] && return 0
_RS_MODULES_LOADED=1

_RS_MODULES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$_RS_MODULES_DIR/common.sh"

# Deskripsi module (dipakai menu interaktif & dokumentasi).
# Pakai eval-based variable (_MOD_DESC_<nama>) supaya kompatibel Bash 3.2 (macOS sistem).
_MOD_DESC_nvm="Node.js (nvm) + LTS"
_MOD_DESC_pnpm="pnpm package manager"
_MOD_DESC_dotfiles=".tmux.conf + aliases"
_MOD_DESC_uv="uv - Python pkg/proj (Astral)"
_MOD_DESC_rust="Rust (rustup + cargo)"
_MOD_DESC_go="Go toolchain (go.dev)"
_MOD_DESC_docker="Docker Engine"
_MOD_DESC_bun="Bun runtime"
_MOD_DESC_deno="Deno runtime"
_MOD_DESC_fvm="Flutter Version Management"
_MOD_DESC_composer="PHP Composer (butuh php)"

# _moddesc <nama> — cetak deskripsi module, atau string kosong jika tidak ada.
_moddesc() { eval "printf '%s' \"\${_MOD_DESC_${1}:-}\""; }

mod_nvm() {
  export NVM_DIR="$HOME/.nvm"
  if [ -s "$NVM_DIR/nvm.sh" ]; then skip "nvm sudah ada"; else
    local tag
    tag="$(curl -fsSL https://api.github.com/repos/nvm-sh/nvm/releases/latest |
      grep -oP '"tag_name":\s*"\K[^"]+' || true)"
    [ -n "$tag" ] || tag="v0.40.1"
    curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${tag}/install.sh" | bash
    ok "nvm ${tag}"
  fi
  # shellcheck disable=SC1091
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  if have nvm && ! nvm which default >/dev/null 2>&1; then
    nvm install --lts && nvm alias default 'lts/*'
    ok "node $(node -v)"
  else skip "node default sudah ada"; fi
}

mod_pnpm() {
  if have pnpm; then
    skip "pnpm sudah ada"
    return
  fi
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  ok "pnpm"
}

mod_uv() {
  if have uv; then
    skip "uv sudah ada"
    return
  fi
  curl -LsSf https://astral.sh/uv/install.sh | sh
  ok "uv (+uvx) -> ~/.local/bin"
}

mod_rust() {
  if have rustc || [ -d "$HOME/.cargo" ]; then
    skip "rust sudah ada"
    return
  fi
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  ok "rust (rustup, cargo)"
}

mod_go() {
  if [ -x /usr/local/go/bin/go ]; then
    skip "go sudah ada"
    return
  fi
  local goarch goos ver
  case "$(uname -s)" in Darwin) goos=darwin ;; *) goos=linux ;; esac
  case "$ARCH" in
  amd64) goarch=amd64 ;;
  arm64) goarch=arm64 ;;
  armhf) goarch=armv6l ;;
  *)
    skip "arch '$ARCH' tidak didukung untuk Go"
    return
    ;;
  esac
  ver="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1 || true)"
  [ -n "$ver" ] || {
    skip "gagal ambil versi Go"
    return
  }
  curl -fsSL "https://go.dev/dl/${ver}.${goos}-${goarch}.tar.gz" -o /tmp/go.tgz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tgz
  rm -f /tmp/go.tgz
  ok "go ${ver} -> /usr/local/go"
}

mod_docker() {
  if have docker; then
    skip "docker sudah ada"
    return
  fi
  if [ "$(uname -s)" = "Darwin" ]; then
    if have brew; then
      brew install --cask docker
      ok "Docker Desktop — buka aplikasi Docker untuk menyelesaikan setup"
    else
      warn "docker: di macOS butuh Docker Desktop — install manual dari docker.com/products/docker-desktop"
    fi
    return
  fi
  curl -fsSL https://get.docker.com | sudo sh
  ok "docker"
  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    ok "user '$USER' ditambah ke grup docker (perlu logout/login agar aktif)"
  fi
}

mod_bun() {
  if have bun; then
    skip "bun sudah ada"
    return
  fi
  curl -fsSL https://bun.sh/install | bash
  ok "bun"
}

mod_deno() {
  if have deno; then
    skip "deno sudah ada"
    return
  fi
  curl -fsSL https://deno.land/install.sh | sh -s -- -y 2>/dev/null ||
    curl -fsSL https://deno.land/install.sh | sh
  ok "deno"
}

mod_fvm() {
  if have fvm || [ -x "$HOME/fvm/bin/fvm" ]; then
    skip "fvm sudah ada"
    return
  fi
  # installer resmi: user-local ke ~/fvm/bin, non-interaktif, tanpa sudo
  curl -fsSL https://fvm.app/install.sh | bash
  ok "fvm -> ~/fvm/bin"
}

mod_composer() {
  if have composer; then
    skip "composer sudah ada"
    return
  fi
  if ! have php; then
    skip "composer butuh php (pasang module 'php' dulu)"
    return
  fi
  # install resmi + verifikasi signature (SHA-384)
  local expected actual
  expected="$(curl -fsSL https://composer.github.io/installer.sig || true)"
  curl -fsSL https://getcomposer.org/installer -o /tmp/composer-setup.php
  actual="$(php -r "echo hash_file('sha384', '/tmp/composer-setup.php');")"
  if [ -z "$expected" ] || [ "$expected" != "$actual" ]; then
    rm -f /tmp/composer-setup.php
    warn "composer: checksum installer tidak cocok — dibatalkan"
    return
  fi
  sudo php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer
  rm -f /tmp/composer-setup.php
  ok "composer -> /usr/local/bin/composer"
}

mod_dotfiles() {
  log "Dotfiles: aliases + tmux.conf"

  # --- aliases (bash & zsh) ---
  local ab="# >>> remote-setup aliases >>>" ae="# <<< remote-setup aliases <<<"
  local ALIASES
  read -r -d '' ALIASES <<'EOF' || true
alias ll='ls -alhF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph --decorate -20'
alias gd='git diff'
alias t='tmux'
alias ta='tmux attach -t'
alias tn='tmux new -s'
alias tl='tmux ls'
command -v btop >/dev/null 2>&1 && alias top='btop'
EOF
  printf '%s\n' "$ALIASES" | inject_block "$HOME/.bashrc" "$ab" "$ae"
  [ -e "$HOME/.zshrc" ] && printf '%s\n' "$ALIASES" | inject_block "$HOME/.zshrc" "$ab" "$ae"
  ok "aliases"

  # --- tmux: tulis config kita, lalu source dari ~/.tmux.conf (gak clobber) ---
  cat >"$HOME/.tmux.remote.conf" <<'EOF'
set -g mouse on
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g history-limit 50000
set -sg escape-time 10
set -g default-terminal "tmux-256color"
set -ga terminal-overrides ",*256col*:Tc"
setw -g mode-keys vi
# reload config
bind r source-file ~/.tmux.conf \; display-message "tmux reloaded"
# split panel, tetap di cwd
bind | split-window -h -c "#{pane_current_path}"
bind - split-window -v -c "#{pane_current_path}"
# navigasi panel ala vim
bind h select-pane -L
bind j select-pane -D
bind k select-pane -U
bind l select-pane -R
set -g status-interval 5
EOF
  local src='source-file ~/.tmux.remote.conf'
  grep -qF "$src" "$HOME/.tmux.conf" 2>/dev/null || echo "$src" >>"$HOME/.tmux.conf"
  ok "tmux.conf"
}

# setup_shell_env — tulis PATH/env semua tool ke ~/.bashrc (& ~/.zshrc kalau ada).
# Idempotent: blok diganti, bukan ditumpuk. Lintas-distro.
setup_shell_env() {
  log "Setup PATH/env ke shell rc"
  local eb="# >>> remote-setup env >>>" ee="# <<< remote-setup env <<<"
  local ENVBLOCK
  read -r -d '' ENVBLOCK <<'EOF' || true
# Homebrew (Linux: /home/linuxbrew, macOS: /opt/homebrew atau /usr/local)
if [ -d /home/linuxbrew/.linuxbrew ]; then eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -d /opt/homebrew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -d /usr/local/Homebrew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi
# ~/.local/bin (uv, dll)
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
# pnpm
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in *":$PNPM_HOME:"*) ;; *) export PATH="$PNPM_HOME:$PATH" ;; esac
# cargo / rust
[ -s "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
# go
[ -d /usr/local/go/bin ] && case ":$PATH:" in *":/usr/local/go/bin:"*) ;; *) export PATH="$PATH:/usr/local/go/bin:$HOME/go/bin" ;; esac
# bun
[ -d "$HOME/.bun" ] && { export BUN_INSTALL="$HOME/.bun"; case ":$PATH:" in *":$BUN_INSTALL/bin:"*) ;; *) export PATH="$BUN_INSTALL/bin:$PATH" ;; esac; }
# deno
[ -d "$HOME/.deno" ] && { export DENO_INSTALL="$HOME/.deno"; case ":$PATH:" in *":$DENO_INSTALL/bin:"*) ;; *) export PATH="$DENO_INSTALL/bin:$PATH" ;; esac; }
# fvm (Flutter)
[ -d "$HOME/fvm/bin" ] && case ":$PATH:" in *":$HOME/fvm/bin:"*) ;; *) export PATH="$HOME/fvm/bin:$PATH" ;; esac
# zoxide
if command -v zoxide >/dev/null 2>&1; then
  if [ -n "$ZSH_VERSION" ]; then eval "$(zoxide init zsh)"; else eval "$(zoxide init bash)"; fi
fi
# fzf
if command -v fzf >/dev/null 2>&1; then
  if [ -n "$ZSH_VERSION" ]; then eval "$(fzf --zsh)" 2>/dev/null; else eval "$(fzf --bash)" 2>/dev/null; fi
fi
EOF
  printf '%s\n' "$ENVBLOCK" | inject_block "$HOME/.bashrc" "$eb" "$ee"
  [ -e "$HOME/.zshrc" ] && printf '%s\n' "$ENVBLOCK" | inject_block "$HOME/.zshrc" "$eb" "$ee"
  ok "shell env"
}
