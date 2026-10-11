#!/bin/bash
# The round trip through po_ova_fmt (PLAN.md, "Files"): each fixture
# TestFiles loaded and saved (obj/files/NAME.yaml) must format exactly
# as the fixture does (test/data/NAME.yaml), in every format po_ova_fmt
# has, and with -O, which shows the options: block. Run after TestFiles.
#
# A fixture that loaded with notices (numbers that differ from the rules
# without its overrides: listing them) saves with those numbers listed,
# so its copy prints them with po_ova_fmt's "*" (or "\*") after them.
# For such a fixture (po_ova_fmt's own three, and the Sample NPCs whose
# book numbers aren't the rules', named here, as TestFiles expects their
# notices), the two outputs are compared with that mark
# taken out of both; TestFiles checks that the copy lists every such
# number, since it reloads with no notices. Every other fixture's copy
# must format exactly the same, so an override listed wrongly shows.
#
# usage: test/files.sh PO_OVA_FMT
set -u
fmt=${1:?usage: files.sh PO_OVA_FMT}
cd "$(dirname "$0")/.." || exit 1
if [ ! -x "$fmt" ]; then
  echo "FAIL - $fmt isn't there: build po_ova_fmt (make in its repo), or set PO_OVA_FMT"
  exit 1
fi
# Takes out the override mark: a "\*", or a "*" after a number but
# not before another (a bold "**DX 4**" keeps its stars), or the first
# of three after one (a mark inside bold: "**DX 4***").
unmark() { sed -E 's/\\\*//g; s/([0-9+])\*(\*\*)/\1\2/g; s/([0-9+])\*([^*]|$)/\1\2/g'; }
failed=0; n=0
for saved in obj/files/*.yaml; do
  name=$(basename "$saved" .yaml)
  orig=test/data/$name.yaml
  [ -f "$orig" ] || continue
  case $name in
    # Its copy gains Incorporeal Form's Defense, which the file left out
    # (TestFiles checks it).
    defense-two) continue ;;
    Escaping|Unsorted|Vehicle|Nazo|defense-best-differs) filter=unmark; but=", but for its overrides' marks" ;;
    *) filter=cat; but= ;;
  esac
  for opt in "" -H -G -M -g -m -O; do
    n=$((n + 1))
    label="$name ${opt:-(terse)} formats the same as the fixture$but"
    if diff <("$fmt" $opt "$orig" 2>&1 | $filter; echo "status ${PIPESTATUS[0]}") \
            <("$fmt" $opt "$saved" 2>&1 | $filter; echo "status ${PIPESTATUS[0]}") \
         > obj/files/$name$opt.diff; then
      echo "ok   - $label"; rm -f obj/files/$name$opt.diff
    else
      echo "FAIL - $label (obj/files/$name$opt.diff)"; failed=$((failed + 1))
    fi
  done
done
if [ $n -eq 0 ]; then echo "FAIL - no saved files: run TestFiles first"; exit 1; fi
if [ $failed -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
