#!/bin/bash
# cli.sh PROGRAM: the command line, and starting with no display
# (PLAN.md, "Starting"). Needs no display: nothing here opens a window.
set -u
prog=$1
status=0
out=$(mktemp -d) || exit 2
trap 'rm -rf "$out"' EXIT

check() { # check LABEL CONDITION...
  local label=$1; shift
  if "$@"; then echo "ok   - $label"; else echo "FAIL - $label"; status=1; fi
}

# run ARGS...: the program with no display, its output in $out, status in $st.
run() { env -u DISPLAY -u WAYLAND_DISPLAY -u TMUX "$prog" "$@" >"$out/stdout" 2>"$out/stderr"; st=$?; }

run -h
check "-h exits 0" test $st -eq 0
check "-h prints the usage" grep -q 'po_ova_cg \[options\]' "$out/stdout"
check "-h needs no display" test ! -s "$out/stderr"

run --no-such-option
check "an unknown option exits 2" test $st -eq 2

run some-file.yaml
check "a file argument exits 2 until Phase 3" test $st -eq 2
check "a file argument says why" grep -q "opening a file isn't written yet: some-file.yaml" "$out/stderr"

run
check "no display exits 1" test $st -eq 1
check "no display says so" grep -qx 'po_ova_cg: no display: neither DISPLAY nor WAYLAND_DISPLAY is set' "$out/stderr"
check "no display, outside tmux: one line" test "$(wc -l < "$out/stderr")" -eq 1
check "no display writes nothing to standard output" test ! -s "$out/stdout"

env -u DISPLAY -u WAYLAND_DISPLAY TMUX=/tmp/tmux-test/default,1,0 "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "no display in tmux exits 1" test $st -eq 1
check "no display in tmux: the tmux hint" grep -q '^po_ova_cg: in tmux, .*tmux show-environment -g' "$out/stderr"
check "no display in tmux: two lines" test "$(wc -l < "$out/stderr")" -eq 2

env -u TMUX DISPLAY= WAYLAND_DISPLAY= "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "empty DISPLAY and WAYLAND_DISPLAY count as none" test $st -eq 1

if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $status
