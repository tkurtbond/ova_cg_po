#!/bin/bash
# The round trip through po_ova_fmt (PLAN.md, "Files"): each fixture
# TestFiles loaded and saved (obj/files/NAME.yaml) must format exactly
# as the fixture does (test/data/NAME.yaml), in every format po_ova_fmt
# has, and with -O, which shows the options: block. Run after TestFiles.
#
# usage: test/files.sh PO_OVA_FMT
set -u
fmt=${1:?usage: files.sh PO_OVA_FMT}
cd "$(dirname "$0")/.." || exit 1
if [ ! -x "$fmt" ]; then
  echo "FAIL - $fmt isn't there: build po_ova_fmt (make in its repo), or set PO_OVA_FMT"
  exit 1
fi
failed=0; n=0
for saved in obj/files/*.yaml; do
  name=$(basename "$saved" .yaml)
  orig=test/data/$name.yaml
  [ -f "$orig" ] || continue
  for opt in "" -H -G -M -g -m -O; do
    n=$((n + 1))
    label="$name ${opt:-(terse)} formats the same as the fixture"
    if diff <("$fmt" $opt "$orig" 2>&1; echo "status $?") <("$fmt" $opt "$saved" 2>&1; echo "status $?") \
         > obj/files/$name$opt.diff; then
      echo "ok   - $label"; rm -f obj/files/$name$opt.diff
    else
      echo "FAIL - $label (obj/files/$name$opt.diff)"; failed=$((failed + 1))
    fi
  done
done
if [ $n -eq 0 ]; then echo "FAIL - no saved files: run TestFiles first"; exit 1; fi
if [ $failed -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
