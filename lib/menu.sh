#!/usr/bin/env bash
# ============================================================
#  lib/menu.sh — daftar & pemilih module interaktif.
#  Butuh MOD_DESC (dari lib/modules.sh) dan DEFAULT_MODULES
#  (di-set oleh script OS) untuk pre-check default di menu.
# ============================================================

[ -n "${_RS_MENU_LOADED:-}" ] && return 0
_RS_MENU_LOADED=1

_RS_MENU_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
. "$_RS_MENU_DIR/common.sh"

# Daftar semua module yang tersedia (berdasarkan fungsi mod_*).
list_modules() {
  echo "Module tersedia:"
  compgen -A function | sed -n 's/^mod_/  - /p' | sort
}

# Menu interaktif (SPASI=toggle, ENTER=ok). Set MODULES dari pilihan.
# Prioritas: whiptail -> fzf -> fallback baca angka.
choose_modules() {
  local mods=() m
  while read -r m; do mods+=("$m"); done < <(compgen -A function | sed -n 's/^mod_//p' | sort)

  if have whiptail; then
    local args=() state
    for m in "${mods[@]}"; do
      in_arr "$m" "${DEFAULT_MODULES[@]}" && state=ON || state=OFF
      args+=("$m" "${MOD_DESC[$m]:-}" "$state")
    done
    local sel
    sel="$(whiptail --title "Pilih module" \
      --checklist "SPASI = pilih/batal,  ENTER = lanjut" \
      20 60 "${#mods[@]}" "${args[@]}" 3>&1 1>&2 2>&3)" || return 1
    sel="${sel//\"/}"
    read -ra MODULES <<<"$sel"
    return 0
  fi

  if have fzf; then
    local sel
    sel="$(printf '%s\n' "${mods[@]}" |
      fzf --multi --bind space:toggle+down \
        --header "TAB/SPASI = pilih, ENTER = lanjut" || true)"
    [ -n "$sel" ] || return 1
    read -ra MODULES <<<"$(echo "$sel" | tr '\n' ' ')"
    return 0
  fi

  # fallback paling sederhana: ketik angka dipisah spasi
  echo "Pilih module (ketik nomor, pisah spasi). Default: ${DEFAULT_MODULES[*]}"
  local i=1
  for m in "${mods[@]}"; do
    printf "  %d) %-9s %s\n" "$i" "$m" "${MOD_DESC[$m]:-}"
    i=$((i + 1))
  done
  read -rp "> " line
  [ -n "$line" ] || {
    MODULES=("${DEFAULT_MODULES[@]}")
    return 0
  }
  MODULES=()
  for n in $line; do MODULES+=("${mods[$((n - 1))]}"); done
  return 0
}
