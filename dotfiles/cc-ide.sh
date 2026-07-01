#!/usr/bin/env bash
#
# cc-ide.sh — Layout tmux bergaya IDE/OpenCode untuk Claude Code
#
#   ┌───────────────────────────┬──────────────┐
#   │                           │  Files       │  (yazi / broot / eza)
#   │      Claude Code          ├──────────────┤
#   │       (main)              │  Git         │  (lazygit / git status)
#   ├───────────────────────────┴──────────────┤
#   │  Build / Test / Logs                      │
#   └───────────────────────────────────────────┘
#
# Pakai:
#   cc-ide.sh                  # session di direktori sekarang
#   cc-ide.sh ~/proj/foo       # session di folder foo
#   cc-ide.sh ~/proj/foo api   # + nama session custom "api"
#   cc-ide.sh -k ~/proj/foo    # kill session lama dulu, baru bikin ulang
#   cc-ide.sh -h               # bantuan
#
# Override persentase layout lewat env var:
#   CC_IDE_RIGHT_PCT=40   # lebar kolom kanan (Files+Git), default 32
#   CC_IDE_BOTTOM_PCT=30  # tinggi strip Build/Logs, default 25
#   CC_IDE_SPLIT_PCT=60   # kolom kanan dibagi: Files vs Git, default 50
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
    cc_ide_usage "$(basename "$0")" "4 pane, 1 window: Claude Code (main) + Files + Git + Build/Logs."
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
SESSION="${2:-$(cc_ide_sanitize_name "$(basename "$WORKDIR")")}"

# Lebar/tinggi pane, semua bisa di-override lewat env var (lihat header).
RIGHT_PCT="${CC_IDE_RIGHT_PCT:-32}"
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

# Buat session detached, ukur sesuai terminal sekarang
tmux new-session -d -s "$SESSION" -c "$WORKDIR" \
  -x "$(tput cols 2>/dev/null || echo 220)" \
  -y "$(tput lines 2>/dev/null || echo 50)"

main=$(tmux list-panes -t "$SESSION" -F '#{pane_id}' | head -n1)

# Kolom kanan (lebar = $RIGHT_PCT) -> file tree
right=$(tmux split-window -h -l "${RIGHT_PCT}%" -c "$WORKDIR" -t "$main" -P -F '#{pane_id}')
# Bagi kolom kanan: pane bawahnya jadi git ($SPLIT_PCT dari kolom kanan)
gitp=$(tmux split-window -v -l "${SPLIT_PCT}%" -c "$WORKDIR" -t "$right" -P -F '#{pane_id}')
# Strip bawah di bawah pane utama ($BOTTOM_PCT tinggi) -> build/log
botp=$(tmux split-window -v -l "${BOTTOM_PCT}%" -c "$WORKDIR" -t "$main" -P -F '#{pane_id}')

# Judul di border tiap pane (biar berasa IDE).
# Pakai user-option @ide_title supaya label STATIS — tidak ditimpa judul OSC
# dinamis yang dikirim aplikasi ke title pane (mis. Claude Code menulis task
# berjalan + spinner ke title). Fallback ke #{pane_title} untuk pane yang
# nanti dibuat manual.
tmux set-option -w -t "$SESSION" pane-border-status top
tmux set-option -w -t "$SESSION" pane-border-format ' #{?@ide_title,#{@ide_title},#{pane_title}} '
tmux set-option -p -t "$main"  @ide_title 'Claude Code'
tmux set-option -p -t "$right" @ide_title 'Files'
tmux set-option -p -t "$gitp"  @ide_title 'Git'
tmux set-option -p -t "$botp"  @ide_title 'Build / Test / Logs'

# Isi tiap pane
tmux send-keys -t "$right" "clear; $TREE_CMD" C-m
tmux send-keys -t "$gitp" "clear; $GIT_CMD" C-m
tmux send-keys -t "$botp" "clear" C-m
tmux send-keys -t "$main" "clear; claude" C-m

# Fokus balik ke Claude Code
tmux select-pane -t "$main"

# Masuk ke session yang baru dibuat
cc_ide_attach_or_switch_if_exists "$SESSION" || true
