#!/usr/bin/env bash
# ============================================================
#  scripts/setup-macos.sh — provisioning macOS
#  Idempotent: aman dijalankan berkali-kali.
#
#  Biasanya dipanggil lewat dispatcher / bootstrap di root repo:
#     bash setup.sh [module...]          # auto-deteksi OS
#     curl -fsSL .../bootstrap.sh | bash # dari nol (internet + git)
#
#  Tapi bisa juga langsung:
#     bash scripts/setup-macos.sh             # default + menu (kalau interaktif)
#     bash scripts/setup-macos.sh uv go docker
#     bash scripts/setup-macos.sh --only uv rust
#     bash scripts/setup-macos.sh --list
#
#  Helper & module ada di ../lib/ (common.sh, modules.sh, menu.sh).
# ============================================================

set -eo pipefail

# ---- lokasi diri & muat library ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"
# shellcheck source=lib/modules.sh
. "$ROOT_DIR/lib/modules.sh"
# shellcheck source=lib/menu.sh
. "$ROOT_DIR/lib/menu.sh"

# ╔══════════════════════════════════════════════════════════╗
# ║                    KONFIGURASI                           ║
# ╚══════════════════════════════════════════════════════════╝

# --- formula brew: semua tool CLI utama ---
BREW_PKGS=(
  zsh                         # shell (module 'zsh' bikin keren)
  tmux
  btop htop ncdu              # monitoring
  ripgrep jq httpie           # cli util (binary: rg, jq, http)
  fzf zoxide                  # fuzzy finder + smarter cd
  bat eza fd                  # cat/ls/find modern
  lazygit git-delta           # TUI git + diff cantik (binary: lazygit, delta)
  tealdeer                    # tldr pages cepat (binary: tldr)
  neovim                      # editor (binary: nvim)
  yazi                        # file manager TUI (pane Files di cc-ide)
)

# --- module yang dijalankan secara default ---
MODULES=(
  zsh nvm pnpm dotfiles
)

INSTALL_BREW=true

# snapshot module default (untuk pre-check di menu)
DEFAULT_MODULES=("${MODULES[@]}")

# ╔══════════════════════════════════════════════════════════╗
# ║         MODULE KHUSUS MACOS (berbasis brew)             ║
# ╚══════════════════════════════════════════════════════════╝
_MOD_DESC_php="PHP (via brew)"
_MOD_DESC_postgres="PostgreSQL server + client (via brew)"
_MOD_DESC_mariadb="MariaDB server + client (via brew)"

mod_php() {
  if have php; then
    skip "php sudah ada ($(php -r 'echo PHP_VERSION;' 2>/dev/null))"
    return
  fi
  brew install php
  ok "php $(php -r 'echo PHP_VERSION;' 2>/dev/null)"
}

mod_postgres() {
  if have psql; then
    skip "postgres sudah ada"
    return
  fi
  brew install postgresql@17
  brew services start postgresql@17
  ok "postgresql (status: brew services info postgresql@17)"
}

mod_mariadb() {
  if have mariadb || have mysql; then
    skip "mariadb/mysql sudah ada"
    return
  fi
  brew install mariadb
  brew services start mariadb
  ok "mariadb (amankan: sudo mariadb-secure-installation)"
}

usage() {
  cat <<'EOF'
setup-macos.sh — provisioning macOS (idempotent).

PEMAKAIAN:
  bash scripts/setup-macos.sh [module...]   # default + module yang disebut
  bash scripts/setup-macos.sh --only m1 m2  # HANYA module m1 m2 (abaikan default)
  bash scripts/setup-macos.sh --menu        # paksa menu interaktif
  bash scripts/setup-macos.sh --defaults    # paksa pakai default, tanpa menu
  bash scripts/setup-macos.sh --list        # daftar module tersedia

OPSI:
  --only            module berikutnya jadi satu-satunya yang dipasang
  -m, --menu        tampilkan menu pemilih module (fzf/angka)
  --defaults        pakai default, lewati menu walau interaktif
  --no-brew         lewati instalasi Homebrew + formula
  --list            cetak daftar module lalu keluar
  -h, --help        tampilkan bantuan ini

CATATAN:
  - Jalankan sebagai user biasa (JANGAN root / sudo bash).
  - Homebrew harus sudah terinstall. Kalau belum:
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
EOF
}

# ╔══════════════════════════════════════════════════════════╗
# ║                    PARSE ARGUMEN                         ║
# ╚══════════════════════════════════════════════════════════╝
ONLY=0
MENU=0
POS=()
while [ $# -gt 0 ]; do
  case "$1" in
  --list)
    list_modules
    exit 0
    ;;
  --only) ONLY=1 ;;
  --menu | -m) MENU=1 ;;
  --defaults) MENU=-1 ;;
  -h | --help)
    usage
    exit 0
    ;;
  --no-brew) INSTALL_BREW=false ;;
  -*) die "opsi tak dikenal: $1 (coba --help)" ;;
  *) POS+=("$1") ;;
  esac
  shift
done

# ╔══════════════════════════════════════════════════════════╗
# ║                  GUARD: macOS & bukan root               ║
# ╚══════════════════════════════════════════════════════════╝
[ "$(uname -s)" = "Darwin" ] || die "Script ini hanya untuk macOS."
[ "$(id -u)" -eq 0 ] && die "Jangan dijalankan sebagai root. Pakai user biasa."

# ╔══════════════════════════════════════════════════════════╗
# ║                  TENTUKAN MODULES                        ║
# ╚══════════════════════════════════════════════════════════╝
if [ "$ONLY" -eq 1 ]; then
  MODULES=("${POS[@]}")
elif [ "${#POS[@]}" -gt 0 ]; then
  MODULES+=("${POS[@]}")
elif [ "$MENU" -eq 1 ] || { [ "$MENU" -ne -1 ] && [ -t 0 ]; }; then
  choose_modules || {
    echo "Dibatalkan."
    exit 0
  }
fi
log "macOS $(sw_vers -productVersion), arch ${ARCH}"
log "Module: ${MODULES[*]:-(none)}"

# ---------- 1) Homebrew + formula ----------
if $INSTALL_BREW && [ "${#BREW_PKGS[@]}" -gt 0 ]; then
  if ! have brew; then
    log "Install Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # muat brew ke PATH di sesi ini
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [ -x /usr/local/bin/brew ]; then
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi
  if have brew; then
    log "brew install: ${BREW_PKGS[*]}"
    brew install "${BREW_PKGS[@]}"
    ok "brew selesai"
  else
    skip "brew gagal terpasang"
  fi
fi

# ---------- 2) modules ----------
for m in "${MODULES[@]}"; do
  eval "_s=\${_seen_${m}:-}"
  [ -n "$_s" ] && continue
  eval "_seen_${m}=1"
  if declare -F "mod_${m}" >/dev/null; then
    log "Module: $m"
    "mod_${m}"
  else
    skip "module '$m' tidak dikenal (lihat --list)"
  fi
done

# ---------- 3) shell env ----------
setup_shell_env

# ---------- selesai ----------
log "Selesai. Muat ulang shell:  source ~/.zshrc  (atau buka terminal baru)"
eval "_chk=\${_seen_docker:-}"; [ -n "$_chk" ] && echo "  catatan: buka aplikasi Docker Desktop untuk menyelesaikan setup."
eval "_chk=\${_seen_dotfiles:-}"; [ -n "$_chk" ] && echo "  catatan: 'pass' butuh GPG key dulu (gpg --full-generate-key; pass init <key>)."
