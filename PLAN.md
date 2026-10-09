# PLAN.md - an OVA character generator in Oberon-2, with poc

`po_ova_cg` builds a character for OVA, the Open Versatile Anime
engine, in a window laid out like the official character sheet. The
user picks Abilities and Weaknesses by name and level, builds attacks
from Perks and Flaws, and the program works out each attack's and
Ability's Endurance cost, and the sheet's ROLL, DX, Defense, Health,
Endurance and TV, as the character changes. It knows no descriptions:
asked about an item, it opens the rulebook at that item's page in the
system's PDF viewer. It saves and loads YAML in ova_fmt's format, so
po_ova_fmt and the Ada ova_fmt print what it makes.

It is written in Oberon-2 and compiled with poc 0.5.0 (`-OC`), with
pofltk (FLTK 1.4) for the window, polibfyaml for YAML, Ropes for text
and ArgParser for the command line. Its build and test setup follows
po_ova_fmt (`~/Repos/RPG/Tools/po_ova_fmt`).

## Sources and findings

The rulebook is `~/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf`.
Pages below are its printed page numbers.

- **Page numbers.** The PDF's page index is the printed page + 2
  (checked at printed pages 9, 49, 83, 101, 133, 148 and 158). Its
  `/PageLabels` make indexes 0 and 1 roman and number index 2 as 1, so
  a page *label* is the printed number (`qpdf --json=2
  --json-key=pagelabels`). [done]
- **Contents**: Creating a Character 17, Sample Characters 23,
  Abilities & Weaknesses 49 (Perks and Flaws 83, Quick List 90),
  Taking Action 93, Combat, Health, & Endurance 103, Game Master's
  Section 119 (Threat Value 124), Sample NPCs 133, Appendix 148,
  Index 158, Character sheet 164.
- **The sheet** (`OVA-CharacterRecord-Letter.pdf`, landscape letter):
  - Right half: the OVA logo with Character Name and Player Name;
    ABILITIES and WEAKNESSES side by side, each a narrow level column
    and a name column; COMBAT NOTES ("damage, complications, etc.");
    the combat box, four attack rows (name, ROLL, DX, END) over a row
    of DEFENSE, HEALTH, ENDURANCE, TV.
  - Left half: Background, Character Portrait, Appearance,
    Personality, Other Notes.
- **Every entry's page** was found by a script over the PDF's text
  (each item's name at the start of a paragraph, on PDF pages 51 to
  91), and every name on the Quick List (p. 90) was found once, but for
  two found twice, where the first is the description: Weapon's other
  hit is the Attack example on p. 50, and Ammunition's the Affinities
  note on p. 89. Each page is to be checked by eye in Phase 1, and the
  check recorded here.
- **The sample characters reproduce the rules below.** Raine, Shou,
  Fukiko and Daisuke (ova_fmt's `test-data/`, from pp. 23-47) were
  checked by hand: every ROLL, DX and END, and Defense, Health and
  Endurance, come out of the rules as written. TV comes out for Raine,
  Shou and Daisuke; Fukiko's is an open question.

## The rules the program computes

Each rule cites its page. Levels are signed: Abilities +1 to +5,
Weaknesses -1 to -3 (p. 18).

### Endurance cost

- **An attack's END** (pp. 50, 83) = the sum, over its Perks, of the
  Perk's cost times the times it is taken, plus the same over its Flaws
  (negative), plus any cost the Ability already has, and never below 0.
  Raine's Electrical Storm: Area Effect x2 (+20), Effective (+5),
  Requirement (-10, as he chose it), Weapon (-5) = 10.
- **Perk and Flaw costs** (pp. 83-89, the Quick List p. 90):
  - fixed: Accurate +5, Area Effect +10, ..., Open to Attack -25 (the
    full list is in "Data tables" below);
  - a range the user picks within, in steps of 5: Cancel -0 to -20,
    Requirement -5 to -20 (p. 87, 88);
  - set by the user and the GM: Unique Perk (+?), Unique Flaw (-?);
  - repeatable: a Perk or Flaw taken more than once is written "x2",
    "x3" (p. 83), ova_fmt's `counts-as`. Which ones the book allows
    to repeat is in each one's text; the table marks them, and the
    window offers a count only for those.
  - **Affinities** cost nothing (p. 89): a name beside the Perks.
- **An Ability with Perks and Flaws** costs the same way (p. 83):
  Fukiko's transformed Barrier, Area Effect (+10) and Elaborate
  Gestures (-5), costs 5. Barrier's Perks and Flaws change only the cost
  of raising it (p. 51); the Endurance spent to stop Damage stays one
  for one, and isn't part of the sheet.
- **Endurance Use** (p. 70), a Weakness tied to one Ability: +5, +10 or
  +20 Endurance at -1, -2, -3, added to that Ability's (or attack's)
  cost before Flaws are taken off.
- **Spells** (Magic, Arcane, p. 57-58; Witchcraft, p. 58, uses the
  same costs): casting a spell that mimics an Ability costs, by the
  caster's Magic level (rows) and the Ability's level (columns):

  | Magic | 1 | 2 | 3 | 4 | 5 |
  |---|---|---|---|---|---|
  | 1 | 20 | 30 | 40 | 50 | 60 |
  | 2 | 10 | 20 | 30 | 40 | 50 |
  | 3 | 5 | 10 | 20 | 30 | 40 |
  | 4 | 2 | 5 | 10 | 20 | 30 |
  | 5 | 0 | 2 | 5 | 10 | 20 |

  plus any cost of the Ability itself (Auren's Mana Shield, Barrier +2
  at Magic 3: 10, written "10+" since Barrier can cost more).
- Situational modifiers (Reckless Offense and the rest, p. 108) don't
  change a cost and aren't modelled.

### The combat box

- **ROLL**, dice for an attack (p. 105) = 2 + Agile + Combat Expert -
  Clumsy + Accurate x n - Inaccurate x n. A **Will Attack** (p. 86) uses
  Iron-Willed and Weak-Willed in place of Agile and Clumsy. Attack and
  Strong never add to it.
- **DX**, the Damage Multiplier (p. 106) = 1 + Attack + Strong - Weak +
  Effective x n - Ineffective x n. A **Ranged** attack (p. 85) loses
  Strong (Shou's Dark Spark: 5, not 6); **Ranged, Strength-Powered**
  (p. 86) keeps Strong and Weak. **No Damage** (p. 88) makes it 0. A DX
  that would be 0 or less without No Damage is 1/2 (Ineffective, p. 88).
- **DEFENSE** (p. 105) = 2 + Evasive + Quick - Slow. Barrier gives a
  second Defense Roll, 2 + Barrier (p. 51), written as ova_fmt's
  `defense: 4/5` (Fukiko).
- **HEALTH** = 40 (p. 19) + Tough (p. 63: 10, 20, 30, 40, 60 at +1 to
  +5) - 10 per level of Frail (p. 71). **ENDURANCE** = 40 + Vigorous
  (p. 65: the same table) - 10 per level of Languid (p. 73). A
  Companion has 20 and 20 (p. 52); Minions 10 and 10 (p. 58).
  Endurance Reserve (p. 53: 20 per level) is a separate store, shown
  beside Endurance, not added to it.
- **TV**, the Threat Value (p. 124) = the best Attack Roll + Defense
  Roll + DX, all without Perks and Flaws, + Armored + the levels of the
  Abilities and Weaknesses that change Health and Endurance (Tough,
  Vigorous, Frail, Languid), + half (rounded up) of the level of any
  other Ability that could matter in a fight, which the user marks
  (Healer and Magic are the book's examples). Raine: 7 + 5 + 4 +
  Vigorous 2 = 18.
- **Transformation** (p. 63): the transformed form's Abilities and
  Weaknesses (worth 2 levels per level of Transformation) count when
  the attacks use them; Fukiko's sheet shows her transformed attacks.
  The window computes the combat box for the form chosen (ordinary or
  transformed).

### Limiting the character (p. 21)

The user turns these on in a settings dialog, saved with the character
in ova_fmt's `options:` mapping (which has `base-zero`, `power-ceiling`,
`scaled-cost` and `combined-effectiveness`; the starting levels and
half-cost Knowledge are new keys, "Changes to ova_fmt" below):

- **Base Zero**: the Character Total (Ability levels + Weakness levels)
  should be within -5 to +5, or as the GM sets.
- **Power Ceiling**: a number of starting levels, plus as many as the
  Weaknesses' levels, up to a ceiling for Abilities.
- **Scaled Cost**: a level costs 1, 2, 4, 8, 15 points for +1 to +5;
  Weaknesses the same, taken away.
- **Knowledge, Ineptitude at half cost**, rounded up, with any of the
  three above (p. 57).
- **Combined Effectiveness**: rarely more than +5 to any roll; the
  program warns when an attack's ROLL bonus or the Defense's goes over.

The running totals (levels of Abilities, of Weaknesses, the Character
Total, points under Scaled Cost) are always shown; a broken limit turns
its total red and says why, but never stops the user: the GM decides.

## Data tables

`OvaRules` holds, for each item, its name, its kind, its page, and for
Perks and Flaws its cost (fixed, a range, or the user's), and whether it
repeats. For Abilities and Weaknesses it also holds the flags the
calculations need (which roll it changes, whether it changes Health or
Endurance, whether it may carry a detail such as Knowledge's subject).
Nothing else.

Pages (printed), from the script above, to be checked in Phase 1:

| Page | Abilities |
|---|---|
| 49 | Agile; Armored |
| 50 | Art of Invisibility; Attack |
| 51 | Barrier; Beautiful; Charismatic; Combat Expert |
| 52 | Companion; Connected; Cute!; Dexterous; Dimensional Pocket |
| 53 | Endurance Reserve; Evasive; Famous |
| 54 | Flight; Gear; Healer; Heightened Sense; Illusionist |
| 55 | Incorporeal Form; Intimidating |
| 56 | Intuitive; Inventor; Invisibility; Iron-Willed |
| 57 | Knowledge; Life Support; Lucky; Magic, Arcane |
| 58 | Magic, Witchcraft; Minions |
| 59 | Passion; Perceptive; Performer; Pilot; Position of Power; Psychic |
| 60 | Quick; Resistance; Shape-Shifter |
| 61 | Sixth Sense; Smart; Spirit Medium |
| 62 | Strong; Telekinesis; Teleport |
| 63 | Time Freeze; Tough; Transformation |
| 64 | Unique Ability; Vehicle (Mecha) |
| 65 | Vigorous; Walking Arsenal; Wealthy |

| Page | Weaknesses |
|---|---|
| 66 | Absent-Minded; Accidental Transformation; Ageism; Airhead |
| 67 | Amnesia; Arrogant; Awkward Size |
| 68 | Bizarre Appearance; Clumsy; Code of Conduct |
| 69 | Compulsion; Coward; Crybaby; Dense |
| 70 | Dependency; Dull; Easily Distracted; Emotionless; Endurance Use; Fear |
| 71 | Focus; Frail; Fussy; Greedy |
| 72 | Guardian; Hatred; Impaired Sense; Impulsive; Ineptitude |
| 73 | Infamous; Jittery; Kind-Hearted; Languid; Lecherous |
| 74 | Limited Uses; Loner; Love Interest |
| 75 | Love Magnet; Mute; Naive; Nosebleeder |
| 76 | Oblivious; Obsession; Outcast; Overconfident |
| 77 | Pacifist; Poor; Quirk; Restricted Freedom; Rival |
| 78 | Room for Two; Rude; Secret; Sensitivity; Servitude |
| 79 | Short-Tempered |
| 80 | Shy; Slow; Soft Spot; Split Personality; Stubborn |
| 81 | Suppressed Power; Trigger; Unique Weakness; Unlucky |
| 82 | Vulnerability; Wanted; Weak; Weak-Willed |

| Page | Perks (Endurance) |
|---|---|
| 83 | Accurate (+5); Area Effect (+10); Armor Piercing (+5); Barrier Buster (+5) |
| 84 | Blinding (+20); Continued Effect (+10); Defensive (+5); Disarming (+10); Effective (+5); Fatiguing (+0) |
| 85 | Impairing (+10); Multiple Targets (+10); No Gesture (+5); Overwhelming (+15); Paralyzing (+10); Ranged (+0) |
| 86 | Ranged, Strength-Powered (+5); Reach (+5); Redirectable (+5); Strike Through (+5); Stunning (+10); Trap (+5); Unique Perk (+?); Vampire (+5); Will Attack (+0) |

| Page | Flaws (Endurance) |
|---|---|
| 87 | Activation (-10); Ammunition (-5); Assisted (-15); Backlash (-5); Break (-10); Buildup (-5); Cancel (-0 to -20); Concentration (-20) |
| 88 | Delayed (-5); Elaborate Gestures (-5); Feather Blow (-5); Finisher (-10); Inaccurate (-5); Ineffective (-5); Low Penetration (-5); No Damage (-20); Open to Attack (-25); Recoil (-10); Requirement (-5 to -20); Self-Only (-5); Unique Flaw (-?) |
| 89 | Unwieldy (-5); Weapon (-5); Affinities (+0) |

Also cited: Ability Perks and Flaws (the rules of cost) p. 83; the
Spell Endurance Cost table p. 58; Attack and Defense Rolls p. 105;
Damage p. 106; Health & Endurance p. 107; Threat Value p. 124;
Limiting the Character p. 21. The window's "?" buttons on the combat
box open these.

Some rules forbid combinations (p. 89: a Flaw may not double a
Weakness, as Ammunition with Limited Uses, Requirement with Focus,
Weapon with Gear; No Damage not with Ineffective, p. 88; Redirectable
only with Ranged, p. 86). The program warns of them, as of a broken
limit, and doesn't forbid them.

## The window

One window, `Fl.DoubleWindow`, sized for a laptop (about 1280 x 800),
resizable: a menu bar, and under it an `FlLayout.Tabs` of two tabs, the
sheet's two halves in swapped order (decided by the user, 2026-10-09).
The first tab is the one shown when the window opens.

The menu bar, above the tabs: File (New, Open, Save, Save As, Quit),
Character (Limits..., Transformed form), Rulebook (Open, Choose PDF...,
Viewer command...).

1. **First tab, "Character" (the sheet's right half)**:
   - Character Name and Player Name inputs, and a tagline;
   - **Abilities** and **Weaknesses**, side by side as on the sheet:
     each a browser of lines (`+3 Attack (Kaze Satsujinsha)`), and
     under it a `Choice` of every name, a `Spinner` for the level (+1
     to +5, or -1 to -3), a detail `Input`, and Add, Change, Remove and
     **?** buttons. **?** opens the rulebook at the chosen name's page.
     An Ability with linked content (Transformation, Companion, Magic's
     spells, Vehicle) gets an Edit button that opens a dialog of the
     same shape for its own items;
   - the running totals and limit warnings, under the two lists;
   - **Combat Notes**, a multi-line input;
   - **the combat box**: a table (`FlTable`) of attacks, one row each:
     name, ROLL, DX, END, computed, never typed. Add/Edit opens the
     **attack dialog**: name, description, affinity, the Perks and the
     Flaws each as a browser of names with a count (repeatable ones
     only) and a cost (Cancel, Requirement, Unique), each with **?**,
     and its ROLL, DX and END updated as Perks and Flaws change. Below,
     DEFENSE, HEALTH, ENDURANCE and TV, computed; Endurance Reserve
     beside Endurance when there is one.
2. **Second tab, "Background" (the sheet's left half)**: Background, the Character
   Portrait (an image file chosen with `FlDialogs.NativeFileChooser`,
   shown scaled with `FlImages`; its path is saved), Appearance,
   Personality and Other Notes, each a `FlText.TextEditor`; and the
   sheet's fluff fields (Concept, Age, Gender, Height, Weight, Hair,
   Eyes, Association, Hobbies, Favorite Food, Allies, Enemies, Love
   Interests; p. 20) in a `FlLayout.Grid`.

### Page numbers beside names

**Wherever the window shows the name of an Ability, Weakness, Perk or
Flaw, it shows that item's rulebook page beside it**: the page number
printed on the book's page (the same numbers as "Data tables", the
PDF's page labels), not the PDF's page index. The user can turn to it
in a printed copy as well as through **?**. That covers:

- the Abilities and Weaknesses lists: `+3 Attack (Kaze Satsujinsha)`
  in one column, `p. 50` in a narrow right-hand column
  (`Browser.SetColumnWidths`, a tab between them);
- the name `Choice`s: `Attack  (p. 50)`, the page in the item's text,
  since a menu has no columns;
- the attack dialog's Perks and Flaws, and the menus that add them:
  `Area Effect x2  +20  p. 83`, `Requirement  -10  p. 88`;
- the Edit dialogs for linked content (a Transformation's or
  Companion's Abilities and Weaknesses, a spell's Ability);
- the warnings, where they name items: `Ammunition (p. 87) with
  Limited Uses (p. 74)`;
- the TV marks dialog, which lists the character's Abilities.

Every one of these is made by one procedure, `OvaRules.Label(item)`
(and `OvaRules.PageText(item)`, `p. 50`, for the lists' page column), so the format can't differ
from place to place and an item with no page can't be shown: every name
in `OvaRules` has a page (`TestRules`). A name in a file that isn't in
`OvaRules` (a misspelling, or an item from another book) is shown with
`p. ?` and a warning. Pages appear only on the window: the saved YAML
holds names as ova_fmt expects them.

### Overriding a computed number

**Beside every number the program computes is an empty entry box**
(decided by the user, 2026-10-09). Left empty, the computed number is
the one in effect. A number typed there overrides it: a GM's ruling, a
house rule, or a case the rules here don't cover. The computed number
stays shown beside the box, so the difference is always visible, and
the box's tooltip says "empty: use the computed value".

- **The numbers**: each attack's ROLL, DX and END; the END of an
  Ability with Perks and Flaws, or with Endurance Use; each spell's
  END; DEFENSE and Barrier's second Defense; HEALTH, ENDURANCE,
  Endurance Reserve and TV; the same for each linked character
  (Companion, Vehicle, the transformed form); and the running totals
  (Ability levels, Weakness levels, Character Total, Scaled Cost
  points).
- **The box** is an `FlInputs.Input`, not an `IntInput`, since some
  numbers on the sheet aren't plain integers (Auren's spell's `10+`,
  Fukiko's `4/5` is two numbers, each with its own box). The text is
  checked as the user leaves the box: an integer, or for an END the
  integer with a trailing `+`; anything else is refused with a message
  and the box emptied.
- **An override counts downstream**: a number computed from another
  uses the other's override (the totals' overrides are what the limits
  check; TV, which the book computes without Perks and Flaws, uses
  overridden Defense and DX when the override is on the base value).
  `OvaCalc` takes the overrides as input, so the rule lives in one
  place.
- **Clearing** the box returns to the computed number.

Every change goes through the model (`OvaCharacter`), and then
`OvaCalc` recomputes and the window shows the result: no widget holds
the only copy of anything. The window title has the file's name and a
mark when there are unsaved changes; Quit, New and Open ask first.

## Starting

`OvaCg` reads its command line (ArgParser), then checks for a display
before calling FLTK. With neither `DISPLAY` nor `WAYLAND_DISPLAY` set
(decided by the user, 2026-10-09) it prints

```
po_ova_cg: no display: neither DISPLAY nor WAYLAND_DISPLAY is set
```

and, inside tmux (`TMUX` set), a second line, since that is where it
was found to happen ("Findings"):

```
po_ova_cg: in tmux, the session may have been attached from a terminal without one; reattach from the desktop, or set them from `tmux show-environment -g`
```

and exits with status 1. A display that is set but can't be opened is
FLTK's to report ("Can't open display", status 1; pofltk's AGENTS.md).
`test/cli.sh` checks both messages and the status, with the variables
unset.

## The rulebook viewer

**Reuse a viewer that is already open**; start one only when none is.
Decided from the experiments below (2026-10-09), all run on a headless
sway with a private D-Bus session (`dbus-run-session`), never on the
desktop.

- **The PDF**: found from, in order, `--rulebook`, the `OVA_RULEBOOK`
  environment variable, the path saved in `FlPreferences`, and
  `~/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf`; else
  Rulebook > Choose PDF asks once and saves it.
- **The viewer**: the user's choice in Rulebook > Viewer (okular,
  evince, mupdf, xdg-open, or a command template), saved in the
  preferences; by default the first of okular, evince, mupdf on `PATH`
  (okular is the desktop's default for PDFs here), else xdg-open.
- **How each is driven** (page index = printed page + 2; page label =
  printed page):

  | Viewer | Reuse | How |
  |---|---|---|
  | okular | yes, over D-Bus | look on the session bus for `org.kde.okular*` services; in each, the objects `/okular`, `/okular2`, ... are its tabs, and `org.kde.okular.currentDocument` says which shows the rulebook. If one does: `/okularshell` `openDocument(file://PDF)` brings that tab forward (no new tab), then that tab's `goToPage(index)`. If none: start `okular --unique -p INDEX PDF` |
  | evince | yes, by itself | `evince -i INDEX PDF` (or `--page-label=LABEL`): a running evince with that file takes the page and no second window opens; the command exits at once |
  | mupdf | no | `mupdf PDF INDEX`; mupdf has no remote control, so the program ends the mupdf it started last (by its pid) before starting the next, so lookups don't pile up windows |
  | xdg-open | no page | `xdg-open PDF`; the program then says which page to turn to |
  | a template | as the command does | `%f` file, `%p` index, `%l` label, split into words by the program, each substitution one word |

- **Running a program** is `OvaSpawn`, a module with a C part
  (`OvaSpawn.c`): `Detached` starts a program in its own session
  (fork, `setsid`, fork, `execvp`), with standard input, output and
  error on `/dev/null`, and reports a failed `exec` (as `errno`) through
  a close-on-exec pipe; `Capture` runs a program and returns its
  standard output and status, for the D-Bus queries (`busctl --user
  list`, `gdbus call`). Arguments are an argument vector, never a shell
  command line, so nothing is quoted. Without `gdbus`, okular is
  started `--unique` instead (it then reuses only the instance it
  started).
- **xdg-open and FLTK's `fl_open_uri`** (which runs `xdg-open
  file://...`) can't choose a page, so they are the last resort.

### Findings

- **okular** (with this user's `ShellOpenFileInTabs=true`): a second
  `okular -p N PDF` doesn't open a window; the running okular opens the
  PDF again in a *new tab* at page N, each time. `--unique` reuses one
  tab only if the running okular was itself started `--unique`;
  started by the user without it (the usual case), `--unique` adds a
  tab each time too. Its D-Bus interface reports each tab's document
  and page, and `goToPage` turns a tab not in front; `openDocument` of
  an open file on `/okularshell` brings its tab forward without a new
  one. okular's page box shows the label (60) beside the index (62),
  as expected. The bus name is `org.kde.okular-PID`, or
  `org.kde.okular` for `--unique`, with an `Instance_...` alias.
- **evince** reuses its window for a file already open, through its
  D-Bus daemon (`org.gnome.evince.Daemon`), and turns to the page given
  by `-i` or `--page-label`: pages 50, 60 and 85 shown correctly.
- **mupdf** (1.28.2, X11 only, under Xwayland) opens a new window
  every time, at the right page.
- **xdg-open** treats sway as a generic desktop with or without
  `XDG_CURRENT_DESKTOP` (`DE=generic`), and opens the default
  (`okularApplication_pdf.desktop`) with no page. A `#page=N` suffix on
  a `file://` URL is passed to okular as is.
- **`Platform.System` against `OvaSpawn`** (a poc test program with the
  C part above, `sleep` and a recording script as viewers):
  - a missing viewer: `System("... &")` returns 0 and the shell's "not
    found" goes to the terminal; `Detached` returns `ENOENT`;
  - without `&`, `System` waits for the viewer (a new okular runs
    until it is closed), so `&` is needed;
  - both return in 1-2 ms and leave no zombie;
  - a path with a space and a `'`: right with either, but `System`
    needs the quoting, `Detached` none;
  - **a hangup** (what closing the tmux pane sends) **killed the viewer
    `System` started**, which shares the program's session and process
    group; the `Detached` one, in its own session, survived. SIGINT
    (Ctrl-C) killed neither.
  So `OvaSpawn`, not `Platform.System`.
- **tmux**: a pane of a tmux session last attached from a tty has no
  `DISPLAY`, `WAYLAND_DISPLAY` or `XDG_CURRENT_DESKTOP` (tmux's
  `update-environment` removed them), though tmux's global environment
  and systemd's user environment (`systemctl --user
  show-environment`) have them. This stops po_ova_cg itself, before
  any viewer: FLTK can't open a window. `DBUS_SESSION_BUS_ADDRESS` is
  kept, so D-Bus reuse works wherever the program can run. With no
  display, the program stops at once ("Starting").

## Files

- **YAML in ova_fmt's format** (the Ada repo's `PLAN.md`, sections 5
  and 9, and `test-data/*.yaml`): one document, a sequence of one
  entity. Abilities and Weaknesses as `{name, level, detail}`; attacks
  under `combat.attacks` with `perks`, `flaws` (a name, or
  `{name, counts-as}`, or `{name, detail, cost}`), `affinity`,
  `description`, `roll`, `dx`, `endurance`; `combat.defense`,
  `health`, `endurance`, `threat-value`; `fluff:`; `notes:`;
  `options:`; linked content (`companion:`, Transformation's
  `abilities:`/`weaknesses:`, `spells:`, `vehicle:`), and the keys
  below that ova_fmt gains.
- **The numbers written are the ones in effect**: the override where
  there is one, else the computed number, so ova_fmt prints what the
  window shows. Each mapping that holds an overridden number also gets
  `overrides:`, the list of its keys the user typed (`overrides: [roll,
  dx]`). On loading, a listed key's number becomes the override; any
  other number is recomputed, and one that disagrees is reported in a
  notice (a hand-edited file) and replaced.
- **Loading** reuses po_ova_fmt's `OvaEntities` (copied, as po_ova_fmt
  copies `Besm2Out`, and kept in step with it), so the generator reads
  exactly what po_ova_fmt reads.
- **Saving** builds a document with polibfyaml's emitter
  (`Fyaml.NewDocument`, `CreateScalar`, `CreateSequence`,
  `CreateMapping`, `SetRoot`, `Append`, `AppendPair`, then `ToFile`,
  with `emitModeBlock`), so quoting is libfyaml's, not ours. Keys are
  written in the order of ova_fmt's fixtures. To check in Phase 3: how
  libfyaml writes multi-line text (Background and the rest), which
  ova_fmt reads as block scalars, and that the result reads back the
  same; a scratch program first. A failed write leaves the old file in
  place: write to `NAME.tmp`, then rename.

### Changes to ova_fmt

What the generator saves and ova_fmt has no key for is added to **both
the Ada ova_fmt and po_ova_fmt** (decided by the user, 2026-10-09),
Ada first, as po_ova_fmt's AGENTS.md requires ("A change to the Ada
program belongs here too"):

| Key | Where | What |
|---|---|---|
| `player` | entity | the Player Name |
| `appearance` | entity | text, like `background` and `personality` |
| `other-notes` | entity | the sheet's Other Notes, text (`notes:` is the headed callouts already) |
| `portrait` | entity | the portrait image's path, relative to the YAML file |
| `notes` | `combat` | the sheet's Combat Notes, text |
| `threat-value-half` | an Ability item | `true`: counts half its level toward TV (p. 124) |
| `starting-levels` | `options` | Power Ceiling's starting levels |
| `half-cost-knowledge` | `options` | Knowledge and Ineptitude at half cost |
| `overrides` | any mapping with computed numbers | the keys the user overrode |

Each is optional, as every ova_fmt key but `name` is. For each, the
Ada repo's PLAN.md gets the schema, how every output format prints it
(open question 2), a fixture (`test-data/Sheet.yaml`, a character
using all of them, made with the generator once it saves), and golden
files; then po_ova_fmt ports it, its golden files regenerated from the
new Ada binary (`make golden`), its `test/data/` copied over. Both are
committed in their own repos, with the user's go-ahead.

## Modules

| Module | Contents |
|---|---|
| `OvaCg` (main) | the command line (ArgParser: a file to open, `--rulebook`, `--viewer`), then the window |
| `OvaRules` | the data tables above: names, kinds, pages, costs, flags |
| `OvaCalc` | the calculations: END, ROLL, DX, Defense, Health, Endurance, TV, totals, limits and warnings |
| `OvaCharacter` | the character being built, with change notification |
| `OvaEntities` | po_ova_fmt's loader, copied |
| `OvaSave` | the YAML writer, through polibfyaml's emitter |
| `OvaViewer` | the rulebook's path, the viewer chosen, reusing a running one (okular over D-Bus, evince, mupdf) |
| `OvaSpawn` (with `OvaSpawn.c`) | starting a program detached; running one and capturing its output |
| `OvaWindow` | the main window, its menu bar and both tabs |
| `OvaAttackDialog` | the attack dialog, and the Perks/Flaws editor an Ability with Perks uses |
| `OvaLinkedDialog` | Transformation, Companion, spells, Vehicle |
| `OvaText`, `OvaOut` | po_ova_fmt's, copied, as needed |

`OvaRules`, `OvaCalc`, `OvaCharacter`, `OvaSave`, `OvaSpawn` and
`OvaViewer` import no pofltk: they are tested with no display.

## Build order

0. **Skeleton.** `GNUmakefile` (from po_ova_fmt's and pofltk's, with
   `test-headless` and `test-sway`), `README.md`, `test/Check.Mod`,
   `test/poc-gc.supp` (po_ova_fmt's plus pofltk's), a window with a
   menu bar that opens and quits under Xvfb.
1. **`OvaRules`.** The tables, each page checked by eye against the PDF
   and recorded here; `Label`, `PageText`; `TestRules`: every Quick
   List name present once, each with a page within its section's range,
   costs as the Quick List gives them, and the labels' format.
2. **`OvaCalc`.** Every rule above, with `TestCalc` over the sample
   characters (every one in `test-data/`, as fixtures) and hand-made
   cases for each Perk and Flaw that changes ROLL or DX, floors at 0,
   the 1/2 DX, Endurance Use, spells, each limit, and overrides feeding
   what is computed from them.
3. **Files.** `OvaEntities` copied, `OvaCharacter`, `OvaSave` (with
   `Fyaml.ToFile`); `TestFiles`: each fixture loaded, saved and
   formatted by po_ova_fmt gives the same output as the fixture (`-H`
   and the terse format), and overrides survive a save and a load.
3a. **ova_fmt's new keys**, in the Ada ova_fmt and then po_ova_fmt
   ("Changes to ova_fmt"), before the generator saves them; then
   `OvaEntities` copied again.
4. **The viewer.** `OvaSpawn` and `OvaViewer`. `TestSpawn`: a missing
   program's `ENOENT`, arguments arriving exactly (a recording script,
   `test/fake-viewer.sh`, with a path holding a space and a `'`), the
   started program in its own session, no zombie, `Capture`'s output
   and status. `TestViewer`, under `make test-sway` with
   `dbus-run-session`: okular found and turned over D-Bus (one tab, the
   right page, read back with `currentPage`), evince reused (one
   window), mupdf replaced, each viewer's page checked as in the
   experiments (scratchpad scripts to become `test/viewer.sh`).
5. **The first tab**: names, Abilities and Weaknesses, totals, the
   combat box and the attack dialog, and the override box beside every
   computed number; `TestWindow` driving
   it as pofltk's tests do, checking the model, the shown numbers, and
   the page beside every name shown, and that an override changes what
   is shown, saved, and computed from it, and clearing it undoes that.
6. **The second tab**: the text fields, the fluff grid, the portrait.
7. **Linked content**: Transformation (and the transformed form's
   combat box), Companion, spells, Vehicle.
8. **Limits and warnings**, the settings dialog, preferences.
9. **Finish**: valgrind clean, `make install`, README's user guide.

## Testing

- `make test` (no display): `TestRules`, `TestCalc`, `TestFiles`,
  `TestViewer`, and a command-line check (`test/cli.sh`).
- `make test-headless` / `test-sway`: the window tests, never on the
  desktop (AGENTS.md).
- `make valgrind`: the unit tests and window tests under valgrind, with
  po_ova_fmt's and pofltk's suppressions and pofltk's `vg-check.sh`.
- The oracle for calculations is the sample characters; the oracle for
  files is po_ova_fmt.

## Open questions

1. **Fukiko's TV.** Her sheet says 12. Best Attack Roll 4 + best Defense
   5 (Barrier) + DX 3 = 12, with Frail not counted; or + Frail (-1) +
   Healer halved (+1) = 12 too. Which Defense counts, and whether a
   Weakness's level is subtracted, decides the rule; check against the
   other samples (Ai, Auren, Braun, Cora, Karis, Miho, Natsuki, Yuu)
   and the NPCs (p. 133-147) in Phase 2.
2. **Which Perks and Flaws repeat**: from each one's text (pp. 83-89);
   recorded in `OvaRules`' flags, as numbers only.

Decided (2026-10-09, by the user):

- ~~Where the sheet's two parts go~~: two tabs ("The window").
- ~~Fields ova_fmt lacks~~: added to both ova_fmts ("Changes to
  ova_fmt").
- ~~Overriding a computed number~~: an empty entry box beside each
  ("Overriding a computed number").
- ~~Does polibfyaml emit YAML~~: yes, `Fyaml.Document.ToYAML` and
  `ToFile` (`src/Fyaml.Mod`), with `NewDocument` and the `Create*`
  procedures to build it. ova_fmt ignores a key it doesn't know (tried
  on po_ova_fmt), but the new keys are added to it anyway.
- ~~How ova_fmt prints the new keys~~: as proposed: `player` beside the
  name in the header; `appearance` and `other-notes` as text sections
  like `personality` and `notes`; combat `notes` after the combat
  stats; `portrait` as an image in the HTML-in-reST format only;
  `threat-value-half`, `starting-levels` and `half-cost-knowledge` as
  the existing options are; an overridden number (one its mapping's
  `overrides` lists) printed with `*` after it (`ROLL 8*`), in every
  format. In the reST and Markdown formats the `*` is escaped (`\*`),
  so it isn't read as emphasis; the golden files show it.
- ~~No display~~: po_ova_cg needs one for its own window, so with
  neither `DISPLAY` nor `WAYLAND_DISPLAY` set it prints an error and
  exits with status 1, before opening anything ("Starting").
- ~~The viewer through the shell or a C part~~: a C part, `OvaSpawn`,
  from the experiments ("The rulebook viewer", "Findings").
