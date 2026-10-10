#!/bin/sh
# A viewer for TestSpawn and TestViewer: records how it was started, in
# FAKE_VIEWER_LOG (../obj/fake-viewer.log from this directory), then
# stays running (as sleep, under its own pid) until ended, or for
# FAKE_VIEWER_SECONDS (30).  The record, written whole, is:
#   argc N            its arguments
#   arg <A>           each, between < and >
#   ppid P sid S      its parent, and its session
#   tty T             its terminal, ? for none
#   fds I O E         what its standard input, output and error are
#   pid P             its own
log=${FAKE_VIEWER_LOG:-$(dirname "$0")/../obj/fake-viewer.log}
fds="$(readlink /proc/$$/fd/0) $(readlink /proc/$$/fd/1) $(readlink /proc/$$/fd/2)"
{ echo "argc $#"
  for a in "$@"; do printf 'arg <%s>\n' "$a"; done
  set -- $(ps -o ppid=,sid=,tty= -p $$)
  echo "ppid $1 sid $2"
  echo "tty $3"
  echo "fds $fds"
  echo "pid $$"
} > "$log.tmp" && mv "$log.tmp" "$log"
exec sleep "${FAKE_VIEWER_SECONDS:-30}"
