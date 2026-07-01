#!/usr/bin/env bash
#
# cc-ide-lib.sh — helper untuk cc-ide.sh (launcher tmux ala-IDE Claude Code).
# Di-source, bukan dieksekusi. Ikut di-install ke ~/.local/bin oleh
# mod_dotfiles supaya launcher tetap bisa nemu file ini walau dijalankan
# dari luar checkout repo.

# cc_ide_require_deps — tmux wajib ada (exit kalau tidak). claude cuma
# di-warning karena mungkin dipasang dengan nama binary lain.
cc_ide_require_deps() {
  command -v tmux >/dev/null 2>&1 || {
    echo "cc-ide: tmux tidak ditemukan di PATH" >&2
    exit 1
  }
  command -v claude >/dev/null 2>&1 ||
    echo "cc-ide: peringatan — 'claude' tidak ditemukan di PATH, pane utama kemungkinan gagal" >&2
}

# cc_ide_resolve_workdir <path> — absolutkan & validasi direktori project
cc_ide_resolve_workdir() {
  local dir="${1:-$PWD}"
  [ -d "$dir" ] || {
    echo "cc-ide: direktori tidak ditemukan: $dir" >&2
    exit 1
  }
  (cd "$dir" && pwd)
}

# cc_ide_sanitize_name <string> — jadi nama session tmux yang valid & rapi
# (tanpa underscore dobel/di ujung akibat karakter aneh berturut-turut)
cc_ide_sanitize_name() {
  printf '%s' "$1" | tr -c 'a-zA-Z0-9_-' '_' | sed -E 's/_+/_/g; s/^_+|_+$//g'
}

# cc_ide_attach_or_switch_if_exists <session> — kalau session sudah ada,
# masuk ke situ lalu exit dari script pemanggil. No-op kalau belum ada.
cc_ide_attach_or_switch_if_exists() {
  local session="$1"
  tmux has-session -t "$session" 2>/dev/null || return 1
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$session"
  else
    tmux attach -t "$session"
  fi
  exit 0
}

# cc_ide_pick_tree_cmd <workdir> — echo command file-tree terbaik yang ada,
# path di-quote aman lewat printf %q (gak jebol walau ada spasi/quote/$).
cc_ide_pick_tree_cmd() {
  local workdir="$1"
  if command -v yazi >/dev/null 2>&1; then
    printf 'yazi %q' "$workdir"
  elif command -v broot >/dev/null 2>&1; then
    printf 'broot %q' "$workdir"
  elif command -v eza >/dev/null 2>&1; then
    printf 'eza --tree --level=2 --icons --git -a'
  else
    printf 'ls -la'
  fi
}

# cc_ide_pick_git_cmd <workdir> — echo command git UI terbaik yang ada
cc_ide_pick_git_cmd() {
  local workdir="$1"
  if command -v lazygit >/dev/null 2>&1; then
    printf 'lazygit -p %q' "$workdir"
  else
    printf 'git status'
  fi
}

# cc_ide_prune_extra_panes <window-target> <known-pane-id...> — kill pane apa
# pun di window itu yang bukan salah satu pane yang kita bikin sendiri. Perlu
# karena plugin tmux (mis. tmux-agent-sidebar) pasang hook global
# `after-new-window` yang otomatis nyisipin pane sidebar tiap kali
# `tmux new-window` dipanggil, di luar kendali script ini.
cc_ide_prune_extra_panes() {
  local window="$1"
  shift
  local known=" $* " pane
  while IFS= read -r pane; do
    case "$known" in
    *" $pane "*) ;;
    *) tmux kill-pane -t "$pane" 2>/dev/null || true ;;
    esac
  done < <(tmux list-panes -t "$window" -F '#{pane_id}')
}

# cc_ide_usage <nama-script> <deskripsi-layout> — cetak bantuan lalu exit 0
cc_ide_usage() {
  local prog="$1" desc="$2"
  cat <<EOF
Pakai: $prog [-k|--kill] [-h|--help] [direktori] [nama-session]

$desc

  direktori       folder project (default: direktori sekarang)
  nama-session    nama session tmux custom (default: nama folder)
  -k, --kill      kill session lama dulu (kalau ada) sebelum bikin ulang
  -h, --help      tampilkan bantuan ini

Override persentase layout lewat env var (lihat komentar header script).
EOF
  exit 0
}
