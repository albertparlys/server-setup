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
#
set -euo pipefail

WORKDIR="${1:-$PWD}"
WORKDIR="$(cd "$WORKDIR" && pwd)" # absolutkan path
SESSION="${2:-$(basename "$WORKDIR" | tr -c 'a-zA-Z0-9_-' '_')}"

# Lebar kolom kanan (Files + Git). Default 32% -> sisakan ~68% buat Claude.
# Override: CC_IDE_RIGHT_PCT=40 cc-ide.sh
RIGHT_PCT="${CC_IDE_RIGHT_PCT:-32}"

# Kalau session sudah ada, tinggal masuk
if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [ -n "${TMUX:-}" ]; then
    tmux switch-client -t "$SESSION"
  else tmux attach -t "$SESSION"; fi
  exit 0
fi

# Pilih tool terbaik yang tersedia (dengan fallback aman)
if command -v yazi >/dev/null 2>&1; then
  TREE_CMD="yazi \"$WORKDIR\""
elif command -v broot >/dev/null 2>&1; then
  TREE_CMD="broot \"$WORKDIR\""
elif command -v eza >/dev/null 2>&1; then
  TREE_CMD='eza --tree --level=2 --icons --git -a'
else
  TREE_CMD='ls -la'
fi

if command -v lazygit >/dev/null 2>&1; then
  GIT_CMD="lazygit -p \"$WORKDIR\""
else
  GIT_CMD='git status'
fi

# Buat session detached, ukur sesuai terminal sekarang
tmux new-session -d -s "$SESSION" -c "$WORKDIR" \
  -x "$(tput cols 2>/dev/null || echo 220)" \
  -y "$(tput lines 2>/dev/null || echo 50)"

main=$(tmux list-panes -t "$SESSION" -F '#{pane_id}' | head -n1)

# Kolom kanan (lebar = $RIGHT_PCT, default 32%) -> file tree
right=$(tmux split-window -h -l "${RIGHT_PCT}%" -c "$WORKDIR" -t "$main" -P -F '#{pane_id}')
# Bagi kolom kanan: pane bawahnya jadi git (50% dari kolom kanan)
gitp=$(tmux split-window -v -l 50% -c "$WORKDIR" -t "$right" -P -F '#{pane_id}')
# Strip bawah di bawah pane utama (25% tinggi) -> build/log
botp=$(tmux split-window -v -l 25% -c "$WORKDIR" -t "$main" -P -F '#{pane_id}')

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

# Masuk ke session
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION"
else tmux attach -t "$SESSION"; fi
