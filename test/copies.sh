#!/bin/bash
# The modules copied from ova_fmt_po (AGENTS.md) must be exactly its,
# so the generator reads what ova_fmt_po reads and writes what it
# writes. A copy that differs was edited here, or ova_fmt_po changed
# and it wasn't copied again: change it there, then copy it.
#
# usage: test/copies.sh OVA_FMT_PO_SRC
set -u
src=${1:?usage: copies.sh OVA_FMT_PO_SRC}
cd "$(dirname "$0")/.." || exit 1
modules="OvaEntities OvaText OvaOut OvaConfig OvaCommon OvaInline"
failed=0
for m in $modules; do
  label="src/$m.Mod is ova_fmt_po's"
  if [ ! -f "$src/$m.Mod" ]; then
    echo "FAIL - $label: $src/$m.Mod isn't there (set OVA_FMT_PO_SRC)"
    failed=$((failed + 1))
  elif cmp -s "$src/$m.Mod" "src/$m.Mod"; then
    echo "ok   - $label"
  else
    echo "FAIL - $label: it differs (diff $src/$m.Mod src/$m.Mod)"
    failed=$((failed + 1))
  fi
done
if [ $failed -eq 0 ]; then echo "All checks passed."; else echo "$failed check(s) failed."; exit 1; fi
