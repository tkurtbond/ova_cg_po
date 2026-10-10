#!/bin/sh
# test/viewer.sh OPENPAGE: OvaViewer with the real viewers -- okular,
# evince and mupdf -- through OPENPAGE (obj/OpenPage, test/OpenPage.Mod).
#
# Everything runs on a headless sway of its own (with Xwayland, for
# mupdf), inside a private D-Bus session (dbus-run-session), with a
# scratch HOME: no window reaches the desktop, no viewer of the user's
# is reached or ended, and the viewers' history and settings are the
# scratch ones (okular's: tabs on, one page at a time).  Only processes
# started here are ended, by pid: the windows in this sway, and the
# processes on this private bus -- never by name.
#
# The PDF, made here, fills page n with a colour encoding n (red 2n,
# green 255 - 2n), so the page a viewer shows is read from one pixel at
# its window's centre (grim); okular's is also asked over D-Bus.  Its
# name holds blanks and a ', which a shell would need quoted, and #, %
# and ?, which a URL needs encoded.
set -u

if [ "${1-}" != --inside ]; then
  [ $# -eq 1 ] || { echo "usage: $0 OPENPAGE" >&2; exit 2; }
  for p in sway grim jq gdbus dbus-run-session python3 okular evince mupdf; do
    command -v $p > /dev/null || { echo "$0: $p isn't installed" >&2; exit 2; }
  done
  driver=$(readlink -f "$1")
  self=$(readlink -f "$0")
  dir=$(mktemp -d) || exit 2
  trap 'rm -rf "$dir"' EXIT
  mkdir -p "$dir/home/.config" "$dir/viewer test"
  printf '[General]\nShellOpenFileInTabs=true\n\n[PageView]\nViewContinuous=false\n' \
    > "$dir/home/.config/okularpartrc"
  pdf="$dir/viewer test/O'Brien #1 100% ?.pdf"
  python3 -I - "$pdf" <<'EOF' || exit 2
import sys
n = 100
objs = [b"<< /Type /Catalog /Pages 2 0 R >>",
        b"<< /Type /Pages /Kids [" + b" ".join(b"%d 0 R" % (3 + 2 * i) for i in range(n))
        + b"] /Count %d >>" % n]
for i in range(1, n + 1):
    body = b"%.4f %.4f 0.5 rg 0 0 612 792 re f" % (2 * i / 255, (255 - 2 * i) / 255)
    objs.append(b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents %d 0 R >>"
                % (4 + 2 * (i - 1)))
    objs.append(b"<< /Length %d >>\nstream\n" % len(body) + body + b"\nendstream")
out = bytearray(b"%PDF-1.4\n")
offsets = []
for k, o in enumerate(objs, 1):
    offsets.append(len(out))
    out += b"%d 0 obj\n" % k + o + b"\nendobj\n"
xref = len(out)
out += b"xref\n0 %d\n0000000000 65535 f \n" % (len(objs) + 1)
out += b"".join(b"%010d 00000 n \n" % off for off in offsets)
out += b"trailer\n<< /Size %d /Root 1 0 R >>\nstartxref\n%d\n%%%%EOF\n" % (len(objs) + 1, xref)
open(sys.argv[1], "wb").write(out)
EOF
  cat > "$dir/run" <<'EOF'
#!/bin/sh
cd "$VIEWER_DIR" || exit 2
dbus-run-session -- sh "$VIEWER_SELF" --inside "$VIEWER_DRIVER" "$VIEWER_PDF" > out 2> bus.log < /dev/null
echo $? > status
swaymsg exit > /dev/null
EOF
  chmod +x "$dir/run"
  printf 'output HEADLESS-1 resolution 1280x800\nxwayland enable\nexec %s/run\n' "$dir" > "$dir/config"
  touch "$dir/out"
  env -i HOME="$dir/home" PATH="$PATH" USER="${USER:-}" XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR" \
    LANG="${LANG:-C.UTF-8}" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
    VIEWER_DIR="$dir" VIEWER_SELF="$self" VIEWER_DRIVER="$driver" VIEWER_PDF="$pdf" \
    timeout 600 sway -c "$dir/config" > "$dir/sway.log" 2>&1 &
  swaypid=$!
  tail -n +1 -f --pid=$swaypid "$dir/out"
  wait $swaypid
  if [ ! -s "$dir/status" ]; then
    echo "$0: sway exited before the checks finished; its log:" >&2
    cat "$dir/sway.log" >&2
    exit 2
  fi
  status=$(cat "$dir/status")
  # The private bus's messages, and the viewers' it started.
  [ "$status" = 0 ] || { echo "-- the bus's log:"; cat "$dir/bus.log"; }
  exit "$status"
fi

# ---- Inside: on the headless sway, on the private bus ----

driver=$2 pdf=$3
failed=0
check() { # check LABEL COMMAND...: ok if COMMAND succeeds
  label=$1; shift
  if "$@"; then echo "ok   - $label"; else echo "FAIL - $label"; failed=$((failed + 1)); fi
}

# One line per window: pid x y width height app.
windows() {
  swaymsg -t get_tree | jq -r '.. | objects | select(.type == "con" or .type == "floating_con")
    | select(.pid) | "\(.pid) \(.rect.x) \(.rect.y) \(.rect.width) \(.rect.height) \(.app_id // .window_properties.class)"'
}
count() { windows | wc -l; }
# waitwin N: until there are N windows, up to 30 s.
waitwin() {
  i=0; while [ "$(count)" -ne "$1" ] && [ $i -lt 60 ]; do sleep 0.5; i=$((i + 1)); done
  [ "$(count)" -eq "$1" ]
}
# The page index the first window shows, from the colour at its centre.
shown() {
  set -- $(windows | head -n 1)
  [ $# -ge 5 ] || { echo none; return; }
  grim -g "$(($2 + $4 / 2)),$(($3 + $5 / 2)) 1x1" -t ppm - 2> /dev/null | tail -c 3 | od -An -tu1 |
    { read -r r g b; if [ $((r + g)) -ge 250 ] && [ $((r + g)) -le 260 ]; then echo $(((r + 1) / 2)); else echo "none ($r $g $b)"; fi; }
}
# shows N: the first window shows page index N, within 15 s.
shows() {
  i=0; while [ "$(shown)" != "$1" ] && [ $i -lt 30 ]; do sleep 0.5; i=$((i + 1)); done
  [ "$(shown)" = "$1" ] || { echo "    shows page $(shown), not $1"; return 1; }
}
# The okulars on the bus.
okulars() {
  gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
    --method org.freedesktop.DBus.ListNames | grep -o "'org\.kde\.okular[-0-9]*'" | tr -d "'"
}
# ask NAME OBJECT METHOD: okular's answer, unwrapped: ('x',) is x, (uint32 5,) 5.
ask() {
  gdbus call --session --dest "$1" --object-path "$2" --method "org.kde.okular.$3" 2> /dev/null |
    sed -E "s/^\((uint32 )?//; s/,\)$//; s/^'(.*)'$/\1/; s/^\"(.*)\"$/\1/"
}
# The pids of the processes started here: the windows', and every
# connection's on this private bus; never this shell's, sway's,
# Xwayland's or the bus's own.
ours() {
  { windows | cut -d' ' -f1
    gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
      --method org.freedesktop.DBus.ListNames | grep -o "':[0-9.]*'" | tr -d "'" |
      while read -r n; do
        gdbus call --session --dest org.freedesktop.DBus --object-path /org/freedesktop/DBus \
          --method org.freedesktop.DBus.GetConnectionUnixProcessID "$n" 2> /dev/null
      done | grep -o '[0-9][0-9]*,' | tr -d ,
  } | sort -u | while read -r p; do
    [ "$p" = $$ ] && continue
    case $(cat /proc/$p/comm 2> /dev/null) in sway|Xwayland|dbus-daemon|gdbus|'') continue ;; esac
    echo "$p"
  done
}
endall() {
  for p in $(ours); do kill "$p" 2> /dev/null; done
  waitwin 0 || echo "    windows left: $(windows)"
  sleep 1
}
open() { "$driver" "$@" || { echo "    OpenPage $*: status $?"; return 1; }; }

echo "== okular, none running: started --unique, then reused"
check "okular: OpenPage starts one, at page 60 (index 62)" open okular "$pdf" 60
check "okular: one window" waitwin 1
check "okular: it shows index 62" shows 62
check "okular: on the bus as org.kde.okular (--unique)" [ "$(okulars)" = org.kde.okular ]
check "okular: currentPage 62" [ "$(ask org.kde.okular /okular currentPage)" = 62 ]
check "okular: OpenPage again, page 70" open okular "$pdf" 70
sleep 2
check "okular: still one window, one tab" [ "$(count)" = 1 -a -z "$(ask org.kde.okular /okular2 currentDocument)" ]
check "okular: it shows index 72" shows 72
check "okular: currentPage 72" [ "$(ask org.kde.okular /okular currentPage)" = 72 ]
endall

echo "== okular as the user runs it: another file in front, the PDF in a tab behind"
other="$(dirname "$pdf")/other.pdf"
cp "$pdf" "$other"
okular "$other" > /dev/null 2>&1 &
check "okular: the user's okular is up" waitwin 1
sleep 3
okular -p 10 "$pdf" > /dev/null 2>&1
sleep 2
okular "$other" > /dev/null 2>&1
sleep 2
# okular opens the PDF in a second tab; opening the other file again
# brings its tab, the first, forward.  The copy's pages are the PDF's:
# the first tab shows index 1.
name=$(okulars)
check "okular: the other file in /okular, in front; the PDF in /okular2, behind" \
  [ "$(ask "$name" /okular currentDocument)" = "$other" -a "$(ask "$name" /okular2 currentDocument)" = "$pdf" \
    -a -z "$(ask "$name" /okular3 currentDocument)" ]
check "okular: the other file's page 1 in front" shows 1
check "okular: OpenPage, page 60" open okular "$pdf" 60
sleep 2
check "okular: no tab added" [ -z "$(ask "$name" /okular3 currentDocument)" ]
check "okular: the PDF's tab turned to 62" [ "$(ask "$name" /okular2 currentPage)" = 62 ]
check "okular: and brought forward" shows 62
check "okular: the other file's tab left alone" [ "$(ask "$name" /okular currentPage)" = 1 ]
check "okular: one window" [ "$(count)" = 1 ]
endall
rm -f "$other"

echo "== evince: reused by itself"
check "evince: OpenPage, page 60" open evince "$pdf" 60
check "evince: one window" waitwin 1
check "evince: it shows index 62" shows 62
check "evince: OpenPage again, page 70" open evince "$pdf" 70
sleep 3
check "evince: still one window" [ "$(count)" = 1 ]
check "evince: it shows index 72" shows 72
endall

echo "== mupdf: the last one replaced"
check "mupdf: OpenPage, pages 60 then 70, in one process" open mupdf "$pdf" 60 70
sleep 2
check "mupdf: one window" waitwin 1
check "mupdf: it shows index 72" shows 72
endall

check "nothing started here is left running" [ -z "$(ours)" ]
if [ $failed -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
