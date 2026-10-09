#!/bin/bash
# quit.sh PROGRAM: the program, started for real, quits on Ctrl+Q (File >
# Quit's shortcut) with status 0. X11 only (xdotool sends the key), so
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
xdotool windowfocus --sync "$win" key ctrl+q
# It must exit by itself (up to 10 s).
for i in $(seq 50); do kill -0 $pid 2>/dev/null || break; sleep 0.2; done
if kill -0 $pid 2>/dev/null; then echo "FAIL - Ctrl+Q didn't end the program"; kill $pid; exit 1; fi
wait $pid; st=$?
if [ $st -eq 0 ]; then echo "ok   - Ctrl+Q quits, status 0"; else echo "FAIL - Ctrl+Q quit with status $st"; exit 1; fi
