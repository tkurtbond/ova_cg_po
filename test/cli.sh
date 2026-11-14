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
check "-h prints the usage" grep -q 'ova_cg_po \[options\]' "$out/stdout"
check "-h needs no display" test ! -s "$out/stderr"

run --no-such-option
check "an unknown option exits 2" test $st -eq 2

run --viewer nonsense
check "a --viewer it doesn't know exits 2" test $st -eq 2
check "and says what it takes" grep -q '^ova_cg_po: --viewer takes okular, evince, mupdf, xdg-open' "$out/stderr"

run test/data/Ai.yaml test/data/Braun.yaml
check "two files exit 2" test $st -eq 2
check "and say one at a time" grep -qx 'ova_cg_po: one file at a time: test/data/Braun.yaml' "$out/stderr"

# The file is read before the display is looked for, so these need none.
run some-file.yaml
check "a file that isn't there exits 1" test $st -eq 1
check "and says why" grep -qx 'ova_cg_po: some-file.yaml: error: No such file or directory' "$out/stderr"

run test/data/Broken.yaml
check "a file with mistakes exits 1" test $st -eq 1
check "and lists them" grep -q 'missing required key "name"' "$out/stderr"

run -v okular -r /nowhere.pdf test/data/Ai.yaml
check "a good file and options: on to the display" grep -q '^ova_cg_po: no display' "$out/stderr"

run
check "no display exits 1" test $st -eq 1
check "no display says so" grep -qx 'ova_cg_po: no display: neither DISPLAY nor WAYLAND_DISPLAY is set' "$out/stderr"
check "no display, outside tmux: one line" test "$(wc -l < "$out/stderr")" -eq 1
check "no display writes nothing to standard output" test ! -s "$out/stdout"

env -u DISPLAY -u WAYLAND_DISPLAY TMUX=/tmp/tmux-test/default,1,0 "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "no display in tmux exits 1" test $st -eq 1
check "no display in tmux: the tmux hint" grep -q '^ova_cg_po: in tmux, .*tmux show-environment -g' "$out/stderr"
check "no display in tmux: two lines" test "$(wc -l < "$out/stderr")" -eq 2

env -u TMUX DISPLAY= WAYLAND_DISPLAY= "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "empty DISPLAY and WAYLAND_DISPLAY count as none" test $st -eq 1

# Named but gone, as a tmux pane may keep it: both name nothing, so
# neither back end can reach a real display.
env -u TMUX DISPLAY=:9999 WAYLAND_DISPLAY=no-such-wayland-display "$prog" >"$out/stdout" 2>"$out/stderr"; st=$?
check "a display named but gone exits 1" test $st -eq 1
check "and says so" grep -qx "ova_cg_po: no display: the one DISPLAY or WAYLAND_DISPLAY names can't be opened" "$out/stderr"

if [ $status -eq 0 ]; then echo "All checks passed."; else echo "Some checks failed."; fi
exit $status
