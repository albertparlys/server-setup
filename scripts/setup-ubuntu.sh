#!/usr/bin/env bash
# ============================================================
#  scripts/setup-ubuntu.sh — provisioning server Ubuntu
#  Idempotent: aman dijalankan berkali-kali.
#
#  Biasanya dipanggil lewat dispatcher / bootstrap di root repo:
#     bash setup.sh [module...]          # auto-deteksi OS
#     curl -fsSL .../bootstrap.sh | bash # dari nol (internet + git)
#
#  Tapi bisa juga langsung:
#     bash scripts/setup-ubuntu.sh             # default + menu (kalau interaktif)
#     bash scripts/setup-ubuntu.sh uv go docker
#     bash scripts/setup-ubuntu.sh --only uv rust
#     bash scripts/setup-ubuntu.sh --list
#
#  Helper & module ada di ../lib/ (common.sh, modules.sh, menu.sh).
#  Lihat README.md dan docs/ untuk detail.
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
# ║  Nambah paket = cukup tambahkan namanya ke array di bawah ║
# ╚══════════════════════════════════════════════════════════╝

# --- paket sistem (apt): tinggal tambah nama ---
APT_PKGS=(
  build-essential procps curl file git ca-certificates unzip # deps dasar
  gnupg pass                                                  # gpg & password manager
  tmux
  btop net-tools
  htop ncdu iotop sysstat iftop nethogs # monitoring
  ripgrep jq httpie                     # cli util (binary: rg, jq, http)
)

# --- formula brew: tinggal tambah nama ---
# Pakai brew utk tool modern: nama binary benar (bat/fd, bukan batcat/fdfind)
# & versi lebih baru daripada apt.
BREW_PKGS=(
  fzf zoxide        # fuzzy finder + smarter cd
  bat eza fd        # cat/ls/find modern
  lazygit git-delta # TUI git + diff cantik (binary: lazygit, delta)
  tealdeer          # tldr pages cepat (binary: tldr)
  neovim            # editor (binary: nvim)
  # contoh tambahan: glances duf dust bandwhich procs
)

# --- module (installer khusus) yang dijalanin secara default ---
MODULES=(
  nvm pnpm dotfiles
)

# toggle global
INSTALL_APT=true
INSTALL_BREW=true

# snapshot module default (untuk pre-check di menu)
DEFAULT_MODULES=("${MODULES[@]}")

# ╔══════════════════════════════════════════════════════════╗
# ║         MODULE KHUSUS UBUNTU (berbasis apt)             ║
# ║  Module lintas-distro ada di lib/modules.sh. Yang di sini ║
# ║  spesifik apt/Ubuntu; OS lain mendefinisikan versinya     ║
# ║  sendiri di scripts/setup-<os>.sh.                        ║
# ╚══════════════════════════════════════════════════════════╝
MOD_DESC[php]="PHP (cli + ekstensi umum)"
MOD_DESC[postgres]="PostgreSQL server + client"
MOD_DESC[mariadb]="MariaDB server + client"

mod_php() {
  if have php; then
    skip "php sudah ada ($(php -r 'echo PHP_VERSION;' 2>/dev/null))"
    return
  fi
  sudo apt-get install -y --no-install-recommends \
    php-cli php-common php-curl php-mbstring php-xml php-zip php-bcmath php-intl php-gd
  ok "php $(php -r 'echo PHP_VERSION;' 2>/dev/null)"
}

mod_postgres() {
  if have psql; then
    skip "postgres sudah ada"
    return
  fi
  sudo apt-get install -y postgresql postgresql-contrib
  ok "postgresql (status: sudo systemctl status postgresql)"
}

mod_mariadb() {
  if have mariadb || have mysql; then
    skip "mariadb/mysql sudah ada"
    return
  fi
  sudo apt-get install -y mariadb-server mariadb-client
  ok "mariadb (amankan: sudo mariadb-secure-installation)"
}

usage() {
  cat <<'EOF'
setup-ubuntu.sh — provisioning server Ubuntu (idempotent).

PEMAKAIAN:
  bash scripts/setup-ubuntu.sh [module...]   # default + module yang disebut
  bash scripts/setup-ubuntu.sh --only m1 m2  # HANYA module m1 m2 (abaikan default)
  bash scripts/setup-ubuntu.sh --menu        # paksa menu interaktif
  bash scripts/setup-ubuntu.sh --defaults    # paksa pakai default, tanpa menu
  bash scripts/setup-ubuntu.sh --list        # daftar module tersedia

OPSI:
  --only            module berikutnya jadi satu-satunya yang dipasang
  -m, --menu        tampilkan menu pemilih module (whiptail/fzf/angka)
  --defaults        pakai default, lewati menu walau interaktif
  --no-apt          lewati instalasi paket apt
  --no-brew         lewati instalasi Homebrew + formula
  --list            cetak daftar module lalu keluar
  -h, --help        tampilkan bantuan ini

CATATAN:
  - Jalankan sebagai user biasa yang punya sudo (JANGAN root).
  - Set SETUP_FORCE_OS=1 untuk paksa lanjut di turunan Ubuntu/Debian.
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
  --defaults) MENU=-1 ;; # paksa pakai default, tanpa menu
  -h | --help)
    usage
    exit 0
    ;;
  --no-apt) INSTALL_APT=false ;;
  --no-brew) INSTALL_BREW=false ;;
  -*) die "opsi tak dikenal: $1 (coba --help)" ;;
  *) POS+=("$1") ;;
  esac
  shift
done

# ╔══════════════════════════════════════════════════════════╗
# ║              GUARD: Ubuntu & bukan root                  ║
# ╚══════════════════════════════════════════════════════════╝
[ -r /etc/os-release ] || die "Tidak bisa baca /etc/os-release."
# shellcheck disable=SC1091
. /etc/os-release
if [ "${ID:-}" != "ubuntu" ] && [ "${SETUP_FORCE_OS:-0}" != "1" ]; then
  warn "OS ini ID='${ID:-?}', bukan 'ubuntu'. Dibatalkan."
  warn "Set SETUP_FORCE_OS=1 untuk paksa lanjut (mis. turunan Ubuntu)."
  exit 0
fi
[ "$(id -u)" -eq 0 ] && die "Jangan dijalankan sebagai root. Pakai user biasa yang punya sudo."
have sudo || die "Butuh 'sudo'."

# ╔══════════════════════════════════════════════════════════╗
# ║                  TENTUKAN MODULES                        ║
# ║  1) argumen eksplisit menang.                            ║
# ║  2) --menu, atau interaktif tanpa argumen -> menu.       ║
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
log "Ubuntu ${VERSION_ID:-?} (${VERSION_CODENAME:-?}), arch ${ARCH}"
log "Module: ${MODULES[*]:-(none)}"

# ---------- 1) apt ----------
if $INSTALL_APT && [ "${#APT_PKGS[@]}" -gt 0 ]; then
  log "apt update + paket sistem"
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get update -y
  have add-apt-repository || sudo apt-get install -y --no-install-recommends software-properties-common
  sudo add-apt-repository -y universe >/dev/null 2>&1 || true
  sudo apt-get update -y
  sudo apt-get install -y --no-install-recommends "${APT_PKGS[@]}"
  ok "apt selesai"
fi

# ---------- 2) brew + formula ----------
BREW_BIN="/home/linuxbrew/.linuxbrew/bin/brew"
if $INSTALL_BREW && [ "${#BREW_PKGS[@]}" -gt 0 ]; then
  if ! have brew && [ ! -x "$BREW_BIN" ]; then
    log "Install Homebrew"
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  [ -x "$BREW_BIN" ] && eval "$("$BREW_BIN" shellenv)"
  if have brew; then
    log "brew install: ${BREW_PKGS[*]}"
    brew install "${BREW_PKGS[@]}"
    ok "brew selesai"
  else skip "brew gagal terpasang"; fi
fi

# ---------- 3) modules ----------
declare -A _seen=()
for m in "${MODULES[@]}"; do
  [ -n "${_seen[$m]:-}" ] && continue # dedup
  _seen[$m]=1
  if declare -F "mod_${m}" >/dev/null; then
    log "Module: $m"
    "mod_${m}"
  else
    skip "module '$m' tidak dikenal (lihat --list)"
  fi
done

# ---------- 4) shell env ----------
setup_shell_env

# ---------- selesai ----------
log "Selesai. Muat ulang shell:  source ~/.bashrc  (atau logout & ssh lagi)"
[ -n "${_seen[docker]:-}" ] && echo "  catatan: untuk docker tanpa sudo, logout/login dulu."
[ -n "${_seen[dotfiles]:-}" ] && echo "  catatan: 'pass' butuh GPG key dulu (gpg --full-generate-key; pass init <key>)."
