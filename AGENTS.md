# AGENTS.md

Working notes for an agent in this repo, which holds `ova_cg_po`, a
character generator for OVA (Open Versatile Anime engine). It is an
Oberon-2 program compiled with poc, the Peaseblossom Oberon Compiler,
with an FLTK window (pofltk) and YAML files (polibfyaml) in ova_fmt's
format. PLAN.md is the design and the build order; this file is
operational notes, not a design doc.

Its build, test and coding conventions are ova_fmt_po's
(`~/Repos/RPG/Tools/ova_fmt_po`), the poc port of ova_fmt, whose
`AGENTS.md` has the hard-won notes on ropes, polibfyaml and poc. Read it
before writing any code here; what it says applies here too unless this
file says otherwise.

## Reference material

| What | Where |
|---|---|
| OVA rulebook (PDF, 170 pages) | `~/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf` |
| Rulebook as text | `~/Reference/RPG/OVA/ova-rulebook.txt` (layout, form feeds between pages), `ova-rulebook-not-layout.txt` |
| Character sheet | `~/Reference/RPG/OVA/OVA-CharacterRecord-Letter.pdf` (landscape letter) |
| Descriptions as Markdown | `~/Reference/RPG/OVA/abilities.md`, `weaknesses.md` -- **never copy into this repo** (below) |
| The YAML format | the Ada ova_fmt: `~/Repos/RPG/Tools/ova_fmt/PLAN.md` and `test-data/*.yaml` |
| The poc ova_fmt (loader, build, tests to copy) | `~/Repos/RPG/Tools/ova_fmt_po/` |
| The Ada ova_fmt (gets the new keys first) | `~/Repos/RPG/Tools/ova_fmt/` |
| pofltk (FLTK 1.4 binding) | `~/Repos/Oberon/pofltk/` (`README.md`, `AGENTS.md`, `examples/`, `doc/fltk-issues.md`); poc library `pofltk` in `$POCLIBDIR` |
| polibfyaml, Ropes, ArgParser | `~/Repos/Oberon/polibfyaml`, `~/Repos/Oberon/Ropes`, `~/Repos/Oberon/ArgParser`; poc libraries in `$POCLIBDIR` (default `~/.local/lib/poc`) |
| poc | `/usr/bin/poc` (0.5.0); source and docs in `~/Repos/Oberon/Peaseblossom-main` (`doc/users-guide.md`, `doc/reference-guide.md`; the runtime, with `Platform.System`, in `rtl/llvm/`) |

Read the pofltk, polibfyaml, Ropes and ArgParser `AGENTS.md` files
before working around any of those libraries.

## The rulebook's text stays out of the program

The program knows the *names* of Abilities, Weaknesses, Perks and Flaws,
the numbers the rules attach to them (Perk and Flaw Endurance costs, the
Tough, Vigorous, Endurance Reserve, Endurance Use and spell-cost tables),
and the rulebook page each is described on. **It holds no descriptions**:
none in the source, the data tables, tooltips, tests or docs. To explain
an item it opens the rulebook at that page in the system's PDF viewer
(PLAN.md, "The rulebook viewer"). Don't paste text from `abilities.md`,
`weaknesses.md` or the rulebook into this repo, even as a comment.

**Every name the window shows has its page beside it** (`Attack
(p. 50)`), made by `OvaRules.Label` or `PageText`, never formatted by hand (PLAN.md,
"Page numbers beside names").

**Page numbers are the book's printed ones** (as its contents and index
give them). The PDF's page index is the printed page + 2, and its page
labels are the printed numbers (`/PageLabels`: roman for indexes 0 and
1, decimal from index 2 starting at 1; checked with `qpdf --json`).

## Build / test

```sh
make                 # obj/ (poc output) and ./ova_cg_po
make test            # what needs no display: unit tests (TESTS), test/files.sh
                     #   (needs ova_fmt_po built: OVA_FMT_PO), test/cli.sh
make check-pages     # OvaRules' pages against the rulebook PDF's headings (needs mutool)
make test-viewers    # OvaViewer with real okular, evince, mupdf (test/viewer.sh;
                     #   its own headless sway and private bus; ~30 s)
make test-headless   # make test-gui on Xvfb: window tests (GUITESTS), the
                     #   program running RUNTIME seconds, test/quit.sh (Ctrl+E, Ctrl+Q)
make test-sway       # make test-gui on a headless sway (quit.sh skips: X11 only)
make valgrind-headless   # every test under valgrind, on Xvfb; also valgrind-sway
                     #   (forked children silent: --child-silent-after-fork)
make install         # to $(PREFIX)/bin, default ~/local/bin (DESTDIR for staging)
make uninstall
make clean           # rm -rf obj ova_cg_po
make print-VAR       # show a makefile variable
```

- **`make test-gui` and `make valgrind` use whatever display is set**:
  never run them directly here (that is the desktop); run the
  `-headless` and `-sway` targets.
- A test that needs no display goes in `TESTS`, a window test in
  `GUITESTS`. Window tests delete every widget they open
  (`OvaWindow.Close`; `Fl.OpenWidgets() = 0` checks it), or
  `make valgrind`'s `vg-check.sh` (pofltk's, from `POFLTK`) fails.
- `test/quit.sh` drives the real program with `xdotool`, so it runs on
  X11 only. On Xvfb with no window manager a window sits 20 pixels
  below its y (pofltk's note).
- `tools/with-sway.sh` is pofltk's, copied; keep it the same.
- **A shell check's own mistakes look like the program's**: `env`
  takes its options before its assignments (`env -u TMUX DISPLAY= ...`,
  not `env DISPLAY= -u TMUX ...`, which runs `-u` as the command).
  Read a FAIL's cause before changing the program.

- **Everything is compiled with `-OC`**, because polibfyaml and pofltk
  require it.
- Link with `-library-path $(POCLIBDIR)`, which holds `argparser`,
  `ropes`, `polibfyaml` and `pofltk`, and `-link -lfyaml`; pofltk's
  manifest adds its own C++ and FLTK flags. The makefile unexports
  `POC_LIBRARY_PATH`, so `POCLIBDIR` is the only place it takes a
  library from.
- **Don't copy library modules** (`Ropes`, `ArgParser`, polibfyaml's,
  pofltk's) into this repo. A change one of them needs is made in its
  own repo, tested and installed there, with the user's go-ahead. After
  upgrading poc, reinstall all four.
- poc compiles this repo's modules from source on every build into
  `obj/`, so the makefile is `.NOTPARALLEL`. A new module in `src/`
  needs nothing in the makefile; a new unit test only its name in
  `TESTS`.
- **Don't run `make install` with the default `PREFIX` unless asked.**
- **`src/OvaEntities.Mod`, `OvaText.Mod`, `OvaOut.Mod`,
  `OvaConfig.Mod`, `OvaCommon.Mod` and `OvaInline.Mod` are
  ova_fmt_po's, copied**, so the generator reads exactly what
  ova_fmt_po reads, and its Markdown sheet and inline paragraph are
  exactly what `ova_fmt_po -M` and `ova_fmt_po -i` write.
  Change them there (and in the Ada ova_fmt first, for a new key), then
  copy them again; never edit the copies.

## Windows and the display

- **An agent never opens windows on the user's desktop** (pofltk's rule,
  the user's instruction of 2026-10-06): not the program, not a test,
  not a scratch program. The user's desktop is Wayland, and XWayland is
  the desktop too. Use `make test-headless` (Xvfb, `WAYLAND_DISPLAY`
  unset) or `make test-sway` (pofltk's `tools/with-sway.sh`), and for a
  single run `env -u WAYLAND_DISPLAY xvfb-run -a ./ova_cg_po ...`.
- **Never start the user's PDF viewer either.** `TestSpawn` and
  `TestViewer` put fakes in the programs' places (`OvaViewer.okular`,
  `.evince`, `.mupdf`, `.xdgOpen`, `.gdbus`): `test/fake-viewer.sh`
  records its arguments, session and standard files in
  `obj/fake-viewer.log` and runs until ended; `test/fake-gdbus.sh`
  answers okular's calls from `obj/gdbus.scenario` and logs them in
  `obj/gdbus.log`. Only `make test-viewers` runs the real viewers.
- GUI tests drive themselves as pofltk's do: `DoCallback`, events sent
  to windows never shown, timers that answer dialogs, and deleting
  every window before the end. Look at a window by capturing it
  (`xvfb-run`, `import -window root`), not by showing it.
- Every widget opened must be deleted by the end of a test, or
  pofltk's `vg-check.sh` reports it.
- **Nothing in the window waits for the user**: a message, the
  save-first question, the file chooser and the rulebook go through
  procedure variables (`OvaWindow.tell`, `ask`, `choosePath`,
  `OvaWidgets.openPage`), and the attack dialog calls back on OK or
  Cancel (`OvaAttackDialog.Ok`, `Cancel` for tests). `TestWindow` sets
  its own, so it never shows a modal dialog; anything new that would
  wait gets one too.

## Working with ropes, pofltk and poc here

ova_fmt_po's notes hold (the empty rope is NIL; absence needs a flag;
callbacks are module-level procedures; no exceptions; no call chaining;
`(*` nests in comments; string literals of at most 255 characters;
`CONST`, `TYPE` and `VAR` before the first procedure). Beside them:

- **The rules and the window are separate.** `OvaRules` and `OvaCalc`
  (PLAN.md, "Modules") import neither pofltk nor polibfyaml, so their
  tests run with no display. Every number on the window comes from
  `OvaCalc`; no widget callback does arithmetic of its own.
- **`OvaCalc`'s records are allocated by its client** (`NEW`, then
  `Init*` and `Add*`), so the model can extend them with names and
  text; `OvaCalc` holds no strings. A warning is a code and the item it
  is about; the window words it, with `OvaRules.Label`.
- **Every computed number has an override box beside it** (PLAN.md,
  "Overriding a computed number"). `OvaCalc` takes the overrides as
  input, so a number computed from an overridden one uses the override;
  a new computed number on the window gets its box, its `overrides:`
  key when saved, and a test.
- **A C part (`OvaSpawn.c`) is declared with `SYSTEM` types**: C's
  `int` is `SYSTEM.INT32`, a pointer `SYSTEM.ADDRESS`, `int64_t`
  `SYSTEM.INT64`, which isn't assignment compatible with `LONGINT`
  even under `-OC` (`SYSTEM.VAL(LONGINT, x)`). poc compiles and links
  it with the module; nothing in the makefile names it.
- **A string literal can't hold both quote marks**, and has no
  escapes: quote with `'` one that holds `"` (`'printf "%s"'`), or
  build it with `CHR(22H)`.
- **Save through polibfyaml's emitter** (`Fyaml.NewDocument`, the
  `Create*` procedures, `ToFile`), never by writing YAML text by hand.
  **Text goes through `CreateStyledScalar`, never `CreateScalar`**: the
  installed libfyaml writes a `CreateScalar` plain even where that
  changes or breaks it (`#1 fan`, a leading quote; PLAN.md, "Files").
  `CreateScalar` is for keys and numbers.
- **Every Oberon object FLTK can call back into must be reachable from
  a module-level root** (pofltk: the collector can't see FLTK's
  pointers). pofltk keeps open widgets reachable; keep the program's
  own state (the character, the widgets' extensions) in module
  variables too.
- **Labels FLTK keeps are copied by pofltk**, so a local string may die
  with its procedure.
- **Never delete a widget, or clear its group, inside its own
  callback**: a combat-box row's Remove rebuilds the rows from an
  `Fl.Timer` (`Fl.AddTimeout(rebuild, 0.0D0)`), which a test runs with
  `Fl.Wait`.
- **A menu shortcut must be a key no input takes**: a key goes to the
  focused widget first, and `Fl_Input` types Ctrl+H, I, J, L and M
  into itself and takes Ctrl+A, C, V, X and Z (so does
  `Fl_Text_Editor`, the last five). `test/quit.sh` checks Ctrl+E from
  Character Name (PLAN.md, Phase 9).
- **Don't name a method after a widget's**: a `NumberBox` (a `Group`)
  shows its number with `Display`, since `Show` would replace FLTK's.
- **`FlText.TextBuffer.Modified` runs when the program sets the text
  too**, not only when the user types: `OvaBackground` sets `filling`
  while it shows a character, so a load isn't a change.
- **A portrait's path is relative to the YAML file**, so anything that
  moves the file (Save As) rebases it with `OvaPaths.Rebase`; paths are
  text, never looked up on disk.
- **Browser lines are 1-based (`Value()` 0: none), `Choice` items
  0-based (-1: none).** A browser that shows names has
  `SetFormatChar(0X)`, so a name starting with `@` isn't a format code.
- A programmer error halts (`ASSERT`); bad input, a cancelled dialog or
  a viewer that won't start comes back as `FALSE` with a message, shown
  in a dialog.
- **Programs are started with `OvaSpawn`, never `Platform.System`**
  (PLAN.md, "The rulebook viewer"): an argument vector, no shell and no
  quoting, detached in its own session so closing the terminal doesn't
  close the viewer, and a missing program reported as `ENOENT`.
- **Never write the user's preferences** (`~/.config/ova_cg_po/`): a
  test opens its own file in `obj/` (`FlPreferences.OpenFile`), and
  `make test-gui` runs the program with `XDG_CONFIG_HOME` in `obj/`.
- **Reuse the user's running viewer** (okular over D-Bus, evince by
  itself); start one only when none shows the rulebook.
- **Viewer experiments and tests run on a headless sway inside
  `dbus-run-session`, with a scratch `HOME`** (`test/viewer.sh` does
  all three): the agent's environment has the user's real session
  bus, and okular or evince would answer on it, on the desktop; and the
  viewers keep history and per-document state under `HOME`. A copy of
  `test/viewer.sh` is the place to start an experiment.
- **End only the processes you started, by PID.** Never `pkill -x
  okular` (or evince, mupdf): that ends the user's own viewers too. A
  test ends what it started (`OvaSpawn.Terminate`, the fake viewer's
  recorded pid), and `test/viewer.sh` the windows of its own sway and
  the connections of its own private bus (`GetConnectionUnixProcessID`).
  Never `pkill -f` with a pattern your own command line contains.

## Testing policy

- Run `make test` after any change, and `make test-headless` after a
  change to the window.
- **The sample characters are the oracle for the calculations.** Every
  derived number on a sample character's sheet (ROLL, DX, END, Defense,
  Health, Endurance, TV) must come out of `OvaCalc` from its Abilities,
  Weaknesses, Perks and Flaws alone; `test/TestCalc.Mod` checks them
  against ova_fmt's fixtures (`test/data/`, copied from the Ada repo's
  `test-data/`, kept the same). A sample character the rules can't
  reproduce is a finding for PLAN.md and `CHARACTER-DIFFERENCES.md`
  (every number of the book's samples the rules don't give, and why),
  not a test to loosen.
  `OvaCharacter.Build` makes a sheet from a fixture, with the Phase 3a
  keys the samples carry (an attack made with Telekinesis or
  transformed, a sheet shown transformed); the book's two rulings,
  which the fixtures list in `overrides:`, are set in `TestCalc`'s
  `Sample` as overrides, each commented.
- **New YAML keys go into the Ada ova_fmt first, then ova_fmt_po**
  (PLAN.md, "Changes to ova_fmt"), each in its own repo, following that
  repo's AGENTS.md (golden files from the Ada binary, fixtures kept the
  same), and committed only with the user's go-ahead. The generator
  saves a key only once both ova_fmts read it.
- **A file the program saves must load in ova_fmt_po** and format the
  same as the file it was loaded from (round trip, PLAN.md):
  `TestFiles` saves each fixture into `obj/files/`, and `test/files.sh`
  formats both in every ova_fmt_po format and compares. A number a
  file's `overrides:` lists is an override; any other that differs
  from the rules' is kept as one too, with a notice. `TestFiles` fixes
  how many each fixture gives (none but ova_fmt_po's Escaping,
  Unsorted and Vehicle, and the Sample NPCs Nazo and Shadowman, which
  `files.sh` names too), so a new rule or
  key that changes them shows there; a saved copy must give none.
- Unit tests print `ok   - <label>` / `FAIL - <label>` and end with
  `All checks passed.` or `<N> check(s) failed.`, exiting 1 on failure,
  as ova_fmt_po's do (`test/Check.Mod`).
- **Prove a new check can fail**: plant the bug it targets and watch it
  fail.
- `make valgrind` must have no errors, nothing lost, and no
  still-reachable block but the collector's and FLTK's display stack's
  (pofltk's `vg-check.sh` rule: no leak whose allocator is ours).

## Conventions

- Comments explain why and only claim what has been verified. A comment
  that depends on how poc, FLTK, pofltk, libfyaml or a viewer behaves is
  tested with a throwaway program in the scratchpad first (under Xvfb).
- A rule in the code cites its rulebook page (`(* p. 83 *)`), never its
  text.
- Record decisions and findings in PLAN.md as they happen. Mark a
  finished step `[done]` and strike through an open question once it's
  decided.
