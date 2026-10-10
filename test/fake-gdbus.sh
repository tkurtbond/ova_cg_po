#!/bin/sh
# A gdbus for TestViewer: answers the calls OvaViewer makes from a
# scenario, FAKE_GDBUS_SCENARIO (../obj/gdbus.scenario from this
# directory), whose lines are tab-separated
#   BUS-NAME  OBJECT  DOCUMENT
# one per okular tab, and logs each call, as one line
#   DEST OBJECT METHOD <ARG>...
# to FAKE_GDBUS_LOG (../obj/gdbus.log).  Its answers are printed as
# gdbus prints them: ListNames gives every bus name of the scenario (in
# its order); currentDocument the tab's document, or gdbus's error and
# status 1 for a tab not there; openDocument (true,) and goToPage ().
dir=$(dirname "$0")
scenario=${FAKE_GDBUS_SCENARIO:-$dir/../obj/gdbus.scenario}
log=${FAKE_GDBUS_LOG:-$dir/../obj/gdbus.log}
[ "$1" = call ] || exit 2
shift
dest= obj= method=
while [ $# -gt 0 ]; do
  case $1 in
    --session) shift ;;
    --timeout) shift 2 ;;
    --dest) dest=$2; shift 2 ;;
    --object-path) obj=$2; shift 2 ;;
    --method) method=$2; shift 2 ;;
    *) break ;;
  esac
done
{ printf '%s %s %s' "$dest" "$obj" "$method"
  for a in "$@"; do printf ' <%s>' "$a"; done
  echo; } >> "$log"
case $method in
  org.freedesktop.DBus.ListNames)
    printf "(['org.freedesktop.DBus', ':1.0'"
    awk -F'\t' '!seen[$1]++ { print $1 }' "$scenario" | while read -r n; do printf ", '%s'" "$n"; done
    echo '],)' ;;
  org.kde.okular.currentDocument)
    if ! doc=$(awk -F'\t' -v d="$dest" -v o="$obj" \
        '$1 == d && $2 == o { print $3; found = 1 } END { exit !found }' "$scenario"); then
      echo "Error: GDBus.Error:org.freedesktop.DBus.Error.UnknownObject: No such object path '$obj'" >&2
      exit 1
    fi
    # GLib quotes a string holding a ' with " instead.
    case $doc in
      *"'"*) printf '("%s",)\n' "$doc" ;;
      *) printf "('%s',)\n" "$doc" ;;
    esac ;;
  org.kde.okular.openDocument) echo '(true,)' ;;
  org.kde.okular.goToPage) echo '()' ;;
  *) echo "fake-gdbus: $method isn't faked" >&2; exit 1 ;;
esac
