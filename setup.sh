#!/usr/bin/env bash
# ============================================================
#  setup.sh — DISPATCHER.
#  Deteksi OS dari /etc/os-release, lalu jalankan
#  scripts/setup-<id>.sh dengan SEMUA argumen diteruskan apa adanya.
#
#     bash setup.sh                  # default module utk OS terdeteksi
#     bash setup.sh uv go docker     # default + uv,go,docker
#     bash setup.sh --only uv        # cuma uv  (diteruskan ke script OS)
#     bash setup.sh --list           # daftar module (diteruskan)
#     bash setup.sh --list-os        # OS yang punya script di repo ini
#     bash setup.sh --help           # bantuan dispatcher
#
#  OS belum didukung? Lihat docs/adding-an-os.md (tinggal tambah
#  scripts/setup-<id>.sh, dispatcher otomatis menemukannya).
# ============================================================

set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$ROOT_DIR/scripts"
# shellcheck source=lib/common.sh
. "$ROOT_DIR/lib/common.sh"

# Daftar OS yang punya script setup-<id>.sh
supported_os() {
  local f found=0
  for f in "$SCRIPTS_DIR"/setup-*.sh; do
    [ -e "$f" ] || continue
    found=1
    basename "$f" | sed -E 's/^setup-(.*)\.sh$/  - \1/'
  done
  [ "$found" -eq 1 ] || echo "  (belum ada)"
}

usage() {
  cat <<EOF
setup.sh — deteksi OS lalu jalankan provisioner yang sesuai.

PEMAKAIAN:
  bash setup.sh [argumen...]   # argumen diteruskan apa adanya ke script OS
  bash setup.sh --help         # bantuan dispatcher ini
  bash setup.sh --list-os      # OS yang punya script di repo

CONTOH:
  bash setup.sh                # default module untuk OS terdeteksi
  bash setup.sh uv rust docker # default + uv,rust,docker
  bash setup.sh --only uv      # cuma uv
  bash setup.sh --list         # (diteruskan) daftar module OS ini

OS yang didukung saat ini:
$(supported_os)

Menambah OS baru: lihat docs/adding-an-os.md
EOF
}

case "${1:-}" in
-h | --help)
  usage
  exit 0
  ;;
--list-os)
  echo "OS yang didukung (punya scripts/setup-<id>.sh):"
  supported_os
  exit 0
  ;;
esac

[ -r /etc/os-release ] || die "Tidak bisa baca /etc/os-release — OS tak dikenal."
# shellcheck disable=SC1091
. /etc/os-release

os="${ID:-unknown}"
target="$SCRIPTS_DIR/setup-${os}.sh"

# Fallback ke turunan via ID_LIKE (mis. linuxmint/pop -> ubuntu, raspbian -> debian).
if [ ! -f "$target" ] && [ -n "${ID_LIKE:-}" ]; then
  for like in $ID_LIKE; do
    if [ -f "$SCRIPTS_DIR/setup-${like}.sh" ]; then
      warn "OS '$os' belum punya script khusus; pakai turunan '$like' (mirip)."
      os="$like"
      target="$SCRIPTS_DIR/setup-${like}.sh"
      export SETUP_FORCE_OS=1 # lewati guard OS di script turunan
      break
    fi
  done
fi

if [ ! -f "$target" ]; then
  die "OS '$os' belum didukung. Yang tersedia:
$(supported_os)
Tambah dukungan: docs/adding-an-os.md"
fi

log "OS terdeteksi: ${PRETTY_NAME:-$os} -> scripts/setup-${os}.sh"
exec bash "$target" "$@"
