# po_ova_cg - an OVA character generator in Oberon-2, built with poc

`po_ova_cg` builds a character for OVA, the Open Versatile Anime
engine, in a window laid out like the official character sheet: pick
Abilities and Weaknesses by name and level, build attacks from Perks and
Flaws, and it works out Endurance costs, ROLL, DX, Defense, Health,
Endurance and Threat Value as you go. It holds no rules text: each name
shows its rulebook page, and the program can open the rulebook's PDF at
that page in your PDF viewer. Characters are saved as YAML that
[po_ova_fmt](../po_ova_fmt) and the Ada [ova_fmt](../ova_fmt) format.

It is written in Oberon-2 for poc, the
[Peaseblossom](https://github.com/tkurtbond/peaseblossom) Oberon
compiler, with pofltk (FLTK 1.4) for the window and polibfyaml for YAML.

**Status: Phase 7 of PLAN.md** -- the rules and their calculations,
tested against the book's sample characters; loading and saving
characters in ova_fmt's YAML, with the keys added to both ova_fmts for
the generator (overrides among them); opening the rulebook at a page
in okular, evince, mupdf or another viewer, reusing one already open;
and both tabs of the window. The Character tab has the names, the
Abilities and Weaknesses with their pages and **?** buttons, the totals
and warnings, the Combat Notes, and the combat box with the attack
dialog, with an override box beside every computed number. The
Background tab has the summary, the Background, Appearance,
Personality and Other Notes, the portrait, the fluff and the notes.
An Ability with linked content opens a dialog for it: a
Transformation's form, a Magic's spells, or a Companion's or Vehicle's
sheet; Character > Transformed form shows the sheet in the form. The
File menu has New, Open, Save and Save As. Limits and preferences are
still to come.

## Usage

```
po_ova_cg [options] [file.yaml]
```

`-h` lists the options: `-r`/`--rulebook PATH` gives the rulebook's PDF
(else `OVA_RULEBOOK`, else `~/Reference/RPG/OVA/`), and `-v`/`--viewer`
the viewer (`okular`, `evince`, `mupdf`, `xdg-open`, or a command with
`%f` for the PDF, `%p` its page and `%l` the printed page). A file that
can't be read, or holds mistakes, is reported and the program exits
with status 1. The program needs a display (`DISPLAY` or
`WAYLAND_DISPLAY`); without one it says so and exits with status 1.

## Building

You need:

- poc, with its runtime library, on `PATH` (override with `POC=`), and
  clang, which poc runs.
- FLTK 1.4 and libfyaml.
- The poc libraries `argparser`, `ropes`, `polibfyaml` and `pofltk`,
  each installed by its own repo into its own directory under
  `POC_OBERON_LIBRARIES` (default `/usr/local/sw/versions/oberon/poc/lib`).
  Install them again after upgrading poc, which refuses a library
  another version built.
- For `make test`: po_ova_fmt, built, at `PO_OVA_FMT` (default
  `~/Repos/RPG/Tools/po_ova_fmt/po_ova_fmt`): what the generator saves
  must format as the file it loaded.
- polibfyaml with `CreateStyledScalar` (2026-10-09 or later).
- For the window tests: Xvfb (`xvfb-run`) and `xdotool`, or sway.
- For `make test-viewers`: sway (with Xwayland), okular, evince, mupdf,
  `gdbus`, `dbus-run-session`, grim, jq and python3.
- For `make valgrind`: valgrind, and a checkout of pofltk at `POFLTK`
  (default `~/Repos/Oberon/pofltk`), for its `test/vg-check.sh`.

```sh
make                 # ./po_ova_cg
make test            # the tests that need no display
make test-headless   # the window tests, on Xvfb
make test-sway       # the window tests, on a headless sway (Wayland)
make test-viewers    # the real PDF viewers, on a headless sway of its own
make valgrind-headless   # the tests under valgrind, on Xvfb
make valgrind-sway       # the same, on a headless sway
make install         # to $(PREFIX)/bin, default ~/local/bin
make uninstall
make clean
```

## Documents

- [PLAN.md](PLAN.md): the design, the rules the program computes, and
  the build order.
- [AGENTS.md](AGENTS.md): working notes on the build, the tests, poc and
  the libraries.
