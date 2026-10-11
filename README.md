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

**Status: complete** (the nine phases of PLAN.md). It covers what the
character sheet holds: the names, the Abilities and Weaknesses, the
attacks with their Perks and Flaws, the derived numbers with an
override beside each, the limits of p. 21, linked content (a
Transformation's form, a Magic's spells, a Companion or a Vehicle), and
the sheet's other half, the background, portrait, fluff and notes.

## Usage

```
po_ova_cg [options] [file.yaml]
```

`-h` lists the options: `-r`/`--rulebook PATH` gives the rulebook's PDF
(else `OVA_RULEBOOK`, else the one chosen with Rulebook > Choose
PDF..., else `~/Reference/RPG/OVA/`), and `-v`/`--viewer` the viewer
(`okular`, `evince`, `mupdf`, `xdg-open`, or a command with `%f` for
the PDF, `%p` its page and `%l` the printed page), else the one chosen
with Rulebook > Viewer.... Those two choices are kept in
`$XDG_CONFIG_HOME/po_ova_cg/po_ova_cg.prefs` (else under `~/.config`). A file that
can't be read, or holds mistakes, is reported and the program exits
with status 1. The program needs a display (`DISPLAY` or
`WAYLAND_DISPLAY`); without one it says so and exits with status 1.

## Using the window

The window is the character sheet in two tabs: **Character**, the
sheet's right half, and **Background**, its left. Every change goes
into the character at once and every number is recomputed as you work;
the title shows the file's name, and ` *` after it while there are
unsaved changes.

### Menus

| Menu | Item | Key |
|---|---|---|
| File | New, Open..., Save, Save As..., Quit | Ctrl+N, Ctrl+O, Ctrl+S, Ctrl+Shift+S, Ctrl+Q |
| Character | Limits... | Ctrl+E |
| Character | Transformed form | Ctrl+T |
| Rulebook | Open, Choose PDF..., Viewer... | |

New, Open and Quit ask first whether to save unsaved changes (Save,
Don't save, Cancel), and so does the window's close button.

### The Character tab

**NPC Type**, beside the Tagline, is none for a player's character, or
Heroic, Secondary or Extra for an NPC (p. 123): it sets where Health
and Endurance start (40, 20 or 10) and the TV's last step (4 less for
a Secondary NPC, always 1 for an Extra), and is saved with the
character.

**Abilities and Weaknesses.** Each list shows a trait's level, name
and detail, and the rulebook page its name is on. To add one, choose
its name from the menu under the list (each name shows its page), set
its level and its detail, and press **Add**. Clicking a line puts it
back in those controls: change them and press **Change** to replace
it, or **Remove** to take it out. **?** opens the rulebook at the
chosen name's page.

With an Ability selected, **Perks and Flaws...** opens the attack
dialog for its Perks and Flaws, without the attack's own fields; its
END, when it has one, is beside the button. An Ability with linked
content turns the button under the Weaknesses into one for it:

- **Form...**, a Transformation's: the transformed form's Abilities
  and Weaknesses, two levels for each level of Transformation.
- **Spells...**, a Magic's: each spell's name, the Ability it mimics,
  its level, and its END.
- **Companion...** or **Vehicle...**: the partner's own sheet: its
  name, whether it is a Fragment, whether it has combat stats, and its
  Abilities, Weaknesses, attacks and numbers.

These dialogs change the character as you work, and **Close** closes
them.

**Totals and warnings.** Under the lists are the Abilities' and
Weaknesses' levels and the Character Total (and the Scaled Cost points
when Scaled Cost is on). Warnings say what the rules find wrong, with
the pages of the rules: a name the rulebook doesn't have (shown with
`p. ?`), a level out of range, a Perk taken too often, a Perk or Flaw
the rules don't allow with the others, a limit broken. A total a limit
finds too high turns red.

**Attacks.** Each attack is a row with its ROLL, DX and END. **Add
attack...** and **Edit** open the attack dialog: the attack's name,
affinity and description, whether it is made with Telekinesis or in
the transformed form, and its Perks and Flaws, chosen as the traits
are, with how many times (for one that can be taken more than once)
and a cost (for one whose cost you choose: Cancel, Requirement,
Unique). Its ROLL, DX and END follow each change. **OK** keeps it;
**Cancel** puts it back as it was, and takes out an attack just added.
**Remove** deletes the row's attack.

Below the attacks are DEFENSE, HEALTH, ENDURANCE and TV, with
Barrier's second DEFENSE and an Endurance Reserve when the character
has them.

**Overrides.** Beside every computed number is an empty box. Type a
number there to override it, for a GM's ruling, a house rule, or a
case the rules here don't cover: the computed number stays shown
beside it, and anything computed from it uses the override. A number
is an integer, except that an attack's DX may be `1/2` and a spell's
END may end in `+` (`10+`); anything else is refused with a message.
Empty the box to go back to the computed number. A file whose numbers
differ from the rules' keeps them as overrides, and says which when it
opens.

**Character > Transformed form** shows and computes the sheet in the
Transformation's form (p. 63), and is saved with the character.

**Character > Limits...** turns on the rules of p. 21 and 57: Base
Zero (the Character Total within so many points of zero), starting
levels, a Power Ceiling, Scaled Cost, Knowledge and Ineptitude at half
cost, and Combined Effectiveness. Each number is active only while its
rule is on, and each rule has a **?**. The window follows each change;
**OK** keeps them, and **Cancel**, the close button or Escape puts
them back. They are saved with the character.

### The Background tab

The Summary; the Background, Appearance, Personality, Character Hooks
and Other Notes;
the Character Portrait, an image chosen with **Choose...** (its path
is saved relative to the character's file, and **Remove** takes it
off); the sheet's fluff (Concept, Age, Birthday and the rest); and the
notes, each a header and text, added, changed and removed as the
traits are.

### The rulebook

The program holds no rules text. Every name shows its page in the
rulebook, and **?** or **Rulebook > Open** opens the rulebook's PDF in
your PDF viewer, reusing a viewer that already shows it (okular or
evince). If the program can't find the PDF it asks for it once.
**Rulebook > Choose PDF...** and **Viewer...** choose the PDF and the
viewer, and they are kept for the next time.

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
