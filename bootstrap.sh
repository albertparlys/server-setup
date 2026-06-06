#!/usr/bin/env bash
# ============================================================
#  bootstrap.sh — ENTRY dari nol (cukup: internet + curl).
#  Pasang git kalau belum ada, clone repo, lalu jalankan setup.sh.
#
#  PEMAKAIAN (di server baru):
#     curl -fsSL https://raw.githubusercontent.com/albertparlys/server-setup/main/bootstrap.sh | bash
#
#  Teruskan argumen ke setup.sh dengan `-s --`:
#     curl -fsSL .../bootstrap.sh | bash -s -- uv rust docker
#     curl -fsSL .../bootstrap.sh | bash -s -- --only uv
#
#  Override lewat env var:
#     REPO_URL   (default: https://github.com/albertparlys/server-setup.git)
#     REPO_REF   (branch/tag, default: main)
#     DEST_DIR   (default: $HOME/server-setup)
#
#  Contoh:
#     curl -fsSL .../bootstrap.sh | REPO_REF=dev bash -s -- docker
# ============================================================

set -eo pipefail

REPO_URL="${REPO_URL:-https://github.com/albertparlys/server-setup.git}"
REPO_REF="${REPO_REF:-main}"
DEST_DIR="${DEST_DIR:-$HOME/server-setup}"

log() { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
die() {
  printf '\033[1;31merr \033[0m %s\n' "$*" >&2
  exit 1
}
have() { command -v "$1" >/dev/null 2>&1; }

# ---- 1) pastikan git ada (coba pasang via apt kalau hilang) ----
if ! have git; then
  log "git belum ada, mencoba memasang..."
  if have apt-get; then
    sudo apt-get update -y && sudo apt-get install -y --no-install-recommends git
  elif have dnf; then
    sudo dnf install -y git
  elif have pacman; then
    sudo pacman -Sy --noconfirm git
  else
    die "git tidak ada & package manager tak dikenal. Pasang git manual lalu ulangi."
  fi
fi
have git || die "gagal memasang git."

# ---- 2) clone atau update repo ----
if [ -d "$DEST_DIR/.git" ]; then
  log "Repo sudah ada di $DEST_DIR — update ke $REPO_REF"
  git -C "$DEST_DIR" fetch --depth 1 origin "$REPO_REF"
  git -C "$DEST_DIR" reset --hard FETCH_HEAD
else
  log "Clone $REPO_URL ($REPO_REF) -> $DEST_DIR"
  git clone --depth 1 --branch "$REPO_REF" "$REPO_URL" "$DEST_DIR"
fi

# ---- 3) jalankan dispatcher, teruskan semua argumen ----
log "Menjalankan setup.sh..."
exec bash "$DEST_DIR/setup.sh" "$@"
