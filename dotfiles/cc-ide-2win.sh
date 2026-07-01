#!/usr/bin/env bash
#
# cc-ide-2win.sh — Layout tmux bergaya IDE untuk Claude Code (2 window, 2 pane per window)
#
#   Window 0 "code"                  Window 1 "nav"
#   ┌─────────────────────┐          ┌─────────────────────┐
#   │                     │          │                     │
#   │     Claude Code     │          │  Files (yazi/eza)   │
#   │      (main)         │          │                     │
#   ├─────────────────────┤          ├─────────────────────┤
#   │ Build / Test / Logs │          │   Git (lazygit)     │
#   └─────────────────────┘          └─────────────────────┘
#
# Pindah antar window: prefix + n / p  (atau prefix + 0 / 1)
#
# Pakai:
#   cc-ide-2win.sh                  # session di direktori sekarang
#   cc-ide-2win.sh ~/proj/foo       # session di folder foo
#   cc-ide-2win.sh ~/proj/foo api   # + nama session custom "api"
#   cc-ide-2win.sh -k ~/proj/foo    # kill session lama dulu, baru bikin ulang
#   cc-ide-2win.sh -h               # bantuan
#
# Override persentase layout lewat env var:
#   CC_IDE_BOTTOM_PCT=30  # tinggi strip Build/Logs di window "code", default 25
#   CC_IDE_SPLIT_PCT=60   # window "nav" dibagi: Files vs Git, default 50
#
set -euo pipefail

_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=cc-ide-lib.sh
source "$_DIR/cc-ide-lib.sh"

cc_ide_require_deps

KILL=0
POSITIONAL=()
while [ $# -gt 0 ]; do
  case "$1" in
  -h | --help)
    cc_ide_usage "$(basename "$0")" "2 window, 2 pane per window: code (Claude+Logs) / nav (Files+Git)."
    ;;
  -k | --kill)
    KILL=1
    shift
    ;;
  --)
    shift
    POSITIONAL+=("$@")
    break
    ;;
  -*)
    echo "cc-ide: opsi tidak dikenal: $1" >&2
    exit 1
    ;;
  *)
    POSITIONAL+=("$1")
    shift
    ;;
  esac
done
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

WORKDIR="$(cc_ide_resolve_workdir "${1:-$PWD}")"
# Suffix '-2w' cuma dipasang kalau nama session DEFAULT (dari nama folder),
# supaya TIDAK bentrok dengan cc-ide.sh (layout 4-pane 1-window). Tanpa ini
# nama session sama -> has-session match -> re-attach ke session lama, jadi
# layout 2-window tak pernah kebentuk (gejalanya "masih 4 pane").
SESSION="${2:-$(cc_ide_sanitize_name "$(basename "$WORKDIR")")-2w}"

# Tinggi/lebar pane, semua bisa di-override lewat env var (lihat header).
BOTTOM_PCT="${CC_IDE_BOTTOM_PCT:-25}"
SPLIT_PCT="${CC_IDE_SPLIT_PCT:-50}"

if [ "$KILL" = 1 ] && tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux kill-session -t "$SESSION"
  echo "cc-ide: session lama '$SESSION' dimatikan"
fi

# Kalau session sudah ada (dan tidak baru saja di-kill), tinggal masuk
cc_ide_attach_or_switch_if_exists "$SESSION" || true

TREE_CMD="$(cc_ide_pick_tree_cmd "$WORKDIR")"
GIT_CMD="$(cc_ide_pick_git_cmd "$WORKDIR")"

# Buat session detached (window 0 = "code"), ukur sesuai terminal sekarang
tmux new-session -d -s "$SESSION" -n code -c "$WORKDIR" \
  -x "$(tput cols 2>/dev/null || echo 220)" \
  -y "$(tput lines 2>/dev/null || echo 50)"

# --- Window 0 "code": Claude Code (atas) + Build/Test/Logs (strip bawah) ---
main=$(tmux list-panes -t "$SESSION:code" -F '#{pane_id}' | head -n1)
botp=$(tmux split-window -v -l "${BOTTOM_PCT}%" -c "$WORKDIR" -t "$main" -P -F '#{pane_id}')

# --- Window 1 "nav": Files (atas) + Git (bawah) ---
filesp=$(tmux new-window -t "$SESSION" -n nav -c "$WORKDIR" -P -F '#{pane_id}')
gitp=$(tmux split-window -v -l "${SPLIT_PCT}%" -c "$WORKDIR" -t "$filesp" -P -F '#{pane_id}')
# `new-window` bisa mancing hook plugin (mis. tmux-agent-sidebar) yang
# nyisipin pane sidebar sendiri -> buang pane apa pun selain punya kita.
cc_ide_prune_extra_panes "$SESSION:nav" "$filesp" "$gitp"

# Judul di border tiap pane (biar berasa IDE), aktifkan di kedua window.
# @ide_title = label STATIS supaya tak ditimpa judul OSC dinamis aplikasi
# (mis. Claude Code menulis task berjalan + spinner ke title pane).
for w in code nav; do
  tmux set-option -w -t "$SESSION:$w" pane-border-status top
  tmux set-option -w -t "$SESSION:$w" pane-border-format ' #{?@ide_title,#{@ide_title},#{pane_title}} '
done
tmux set-option -p -t "$main"   @ide_title 'Claude Code'
tmux set-option -p -t "$botp"   @ide_title 'Build / Test / Logs'
tmux set-option -p -t "$filesp" @ide_title 'Files'
tmux set-option -p -t "$gitp"   @ide_title 'Git'

# Isi tiap pane
tmux send-keys -t "$botp"   "clear" C-m
tmux send-keys -t "$filesp" "clear; $TREE_CMD" C-m
tmux send-keys -t "$gitp"   "clear; $GIT_CMD" C-m
tmux send-keys -t "$main"   "clear; claude" C-m

# Fokus balik ke window code + pane Claude Code
tmux select-window -t "$SESSION:code"
tmux select-pane -t "$main"

# Masuk ke session yang baru dibuat
cc_ide_attach_or_switch_if_exists "$SESSION" || true
