#!/usr/bin/env bash
# ============================================================
#  lib/common.sh — helper dasar yang dipakai semua script.
#  Di-source (bukan dieksekusi). TIDAK meng-set `set -e` — itu
#  tanggung jawab script utama yang men-source-nya.
# ============================================================

# include guard: aman di-source berkali-kali
[ -n "${_RS_COMMON_LOADED:-}" ] && return 0
_RS_COMMON_LOADED=1

# ---- logging berwarna ----
log()  { printf '\n\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m  ok\033[0m %s\n' "$*"; }
skip() { printf '\033[1;33mskip\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merr \033[0m %s\n' "$*" >&2; exit 1; }

# ---- util ----
have() { command -v "$1" >/dev/null 2>&1; }

# Arsitektur dalam istilah dpkg (amd64/arm64/armhf) supaya konsisten lintas-OS.
# Module seperti `go` mengandalkan nilai ini.
if have dpkg; then
  ARCH="$(dpkg --print-architecture 2>/dev/null || echo unknown)"
else
  case "$(uname -m 2>/dev/null)" in
  x86_64) ARCH=amd64 ;;
  aarch64 | arm64) ARCH=arm64 ;;
  armv6l | armv7l) ARCH=armhf ;;
  *) ARCH=unknown ;;
  esac
fi

# BSD sed (macOS) butuh -i '' bukan -i. Gunakan _sed_i() supaya portabel.
if [ "$(uname -s 2>/dev/null)" = "Darwin" ]; then
  _sed_i() { sed -i '' "$@"; }
else
  _sed_i() { sed -i "$@"; }
fi

# in_arr <needle> <haystack...>  -> 0 kalau ada, 1 kalau tidak
in_arr() {
  local x="$1"
  shift
  local e
  for e in "$@"; do [ "$e" = "$x" ] && return 0; done
  return 1
}

# Inject blok bertanda ke file rc (idempotent: blok lama diganti, bukan ditumpuk).
# pakai:  printf '%s\n' "$ISI" | inject_block <file> <begin-marker> <end-marker>
inject_block() {
  local rc="$1" b="$2" e="$3"
  [ -e "$rc" ] || touch "$rc"
  grep -qF "$b" "$rc" 2>/dev/null && _sed_i "\|$b|,\|$e|d" "$rc"
  {
    echo "$b"
    cat
    echo "$e"
  } >>"$rc"
}
