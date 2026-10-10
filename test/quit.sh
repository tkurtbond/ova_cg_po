#!/bin/bash
# quit.sh PROGRAM: the program, started for real, opens Character >
# Limits... on Ctrl+E with the cursor in Character Name, where it
# starts (a text input types Ctrl+H, I, J, L and M into itself, so a
# shortcut must be none of those), and Escape closes it; then it quits
# on Ctrl+Q (File > Quit's shortcut) with status 0. X11 only (xdotool sends the key), so
# make test-gui runs it under test-headless (Xvfb), and skips it on
# Wayland.
set -u
prog=$1
if [ -n "${WAYLAND_DISPLAY:-}" ] || [ -z "${DISPLAY:-}" ] || ! command -v xdotool >/dev/null; then
  echo "skip - quit.sh needs X11 and xdotool"; exit 0
fi
"$prog" & pid=$!
# Wait for the window (up to 10 s).
for i in $(seq 50); do
  win=$(xdotool search --name '^OVA Character Generator$' 2>/dev/null | head -1)
  [ -n "$win" ] && break; sleep 0.2
done
if [ -z "$win" ]; then echo "FAIL - the window never appeared"; kill $pid; exit 1; fi
xdotool windowfocus --sync "$win" key ctrl+e
for i in $(seq 25); do
  lim=$(xdotool search --name '^Limits$' 2>/dev/null | head -1)
  [ -n "$lim" ] && break; sleep 0.2
done
if [ -z "$lim" ]; then echo "FAIL - Ctrl+E in Character Name didn't open Limits"; kill $pid; exit 1; fi
title=$(xdotool getwindowname "$win")
if [ "$title" != "OVA Character Generator" ]; then
  echo "FAIL - Ctrl+E changed the character: the title is $title"; kill $pid; exit 1
fi
echo "ok   - Ctrl+E in Character Name opens Limits, the character unchanged"
xdotool windowfocus --sync "$lim" key Escape
for i in $(seq 25); do
  [ -z "$(xdotool search --name '^Limits$' 2>/dev/null)" ] && break; sleep 0.2
done
if [ -n "$(xdotool search --name '^Limits$' 2>/dev/null)" ]; then echo "FAIL - Escape didn't close Limits"; kill $pid; exit 1; fi
echo "ok   - Escape closes Limits"
xdotool windowfocus --sync "$win" key ctrl+q
# It must exit by itself (up to 10 s).
for i in $(seq 50); do kill -0 $pid 2>/dev/null || break; sleep 0.2; done
if kill -0 $pid 2>/dev/null; then echo "FAIL - Ctrl+Q didn't end the program"; kill $pid; exit 1; fi
wait $pid; st=$?
if [ $st -eq 0 ]; then echo "ok   - Ctrl+Q quits, status 0"; else echo "FAIL - Ctrl+Q quit with status $st"; exit 1; fi
