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
#
set -euo pipefail

WORKDIR="${1:-$PWD}"
WORKDIR="$(cd "$WORKDIR" && pwd)" # absolutkan path
# Suffix '-2w' supaya TIDAK bentrok dengan cc-ide.sh (layout 4-pane 1-window).
# Tanpa ini nama session sama -> has-session match -> re-attach ke session lama,
# jadi layout 2-window tak pernah kebentuk (gejalanya "masih 4 pane").
SESSION="${2:-$(basename "$WORKDIR" | tr -c 'a-zA-Z0-9_-' '_')-2w}"

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

# Buat session detached (window 0 = "code"), ukur sesuai terminal sekarang
tmux new-session -d -s "$SESSION" -n code -c "$WORKDIR" \
  -x "$(tput cols 2>/dev/null || echo 220)" \
  -y "$(tput lines 2>/dev/null || echo 50)"

# --- Window 0 "code": Claude Code (atas) + Build/Test/Logs (strip bawah 25%) ---
main=$(tmux list-panes -t "$SESSION:code" -F '#{pane_id}' | head -n1)
botp=$(tmux split-window -v -l 25% -c "$WORKDIR" -t "$main" -P -F '#{pane_id}')

# --- Window 1 "nav": Files (atas) + Git (bawah) ---
filesp=$(tmux new-window -t "$SESSION" -n nav -c "$WORKDIR" -P -F '#{pane_id}')
gitp=$(tmux split-window -v -l 50% -c "$WORKDIR" -t "$filesp" -P -F '#{pane_id}')

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

# Masuk ke session
if [ -n "${TMUX:-}" ]; then
  tmux switch-client -t "$SESSION"
else tmux attach -t "$SESSION"; fi
