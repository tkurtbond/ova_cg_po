# PLAN.md - an OVA character generator in Oberon-2, with poc

`ova_cg_po` builds a character for OVA, the Open Versatile Anime
engine, in a window laid out like the official character sheet. The
user picks Abilities and Weaknesses by name and level, builds attacks
from Perks and Flaws, and the program works out each attack's and
Ability's Endurance cost, and the sheet's ROLL, DX, Defense, Health,
Endurance and TV, as the character changes. It knows no descriptions:
asked about an item, it opens the rulebook at that item's page in the
system's PDF viewer. It saves and loads YAML in ova_fmt's format, so
ova_fmt_po and the Ada ova_fmt print what it makes.

It is written in Oberon-2 and compiled with poc 0.5.0 (`-OC`), with
pofltk (FLTK 1.4) for the window, polibfyaml for YAML, Ropes for text
and ArgParser for the command line. Its build and test setup follows
ova_fmt_po (`~/Repos/RPG/Tools/ova_fmt_po`).

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
  note on p. 89. **Checked in Phase 1** (2026-10-09): the entries'
  headings are set in Calluna-Bold, and every such heading on PDF pages
  51-91, found by font (`tools/rulebook-headings.py`), is one of the
  173 names, on the page the table has; `make check-pages` repeats the
  comparison. Pages 79 (Short-Tempered alone, after the end of
  Servitude and above art) and 86 (nine Perks) were also checked by
  eye, and agree. There are 56 Abilities, 69 Weaknesses, 25 Perks and
  23 Flaws.
- **The sample characters reproduce the rules below.** All twelve in
  ova_fmt's `test-data/` (pp. 23-47), the two Companions (Arasuni,
  Fenrir) included, were checked by hand (2026-10-09): every ROLL, DX,
  END, Defense, Health, Endurance and TV comes out of the rules as
  written, but for two numbers the book gives by ruling ("Sample
  characters the rules don't reproduce", below).
- **TV, settled by Ai.** Fukiko's TV of 12 fits four readings of the
  TV rule (which Defense counts; whether Frail subtracts; whether
  Healer adds half). Ai (TV 10) fits only one: Attack Roll 2 + her
  best Defense, Barrier's 5 (not 4) + DX 5 + Frail -2 = 10; with
  Frail not counted, or her ordinary Defense, it can't be 10. That is
  the literal rule, and it gives Fukiko 4 + 5 + 3 - 1 + Healer 1 = 12.
  Half levels were added only for Magic (Auren: Arcane 3, +2; Cora:
  Witchcraft 2, +1) and Healer (Fukiko: 2, +1), the book's own
  examples; never for Psychic, Sixth Sense, Teleport, Shape-Shifter,
  Life Support or Transformation, which the samples also have.
- **Companions are Secondary NPCs for TV**: Arasuni 3 + 2 + 5 +
  Armored 2 + Tough 2 = 14, sheet 10; Fenrir 4 + 5 + 4 + Tough 2 +
  Vigorous 3 = 18, sheet 14. Both are 4 less, the rule's "Subtract 4
  from Secondary NPCs (minimum of 1)" (p. 124), and the book says
  Secondary NPCs have 20 Health and Endurance, "the same as
  characters created with the Companion Ability" (p. 123). Their
  Health and Endurance start at 20 (Arasuni: 20 + Tough 2 = 40;
  Fenrir: 20 + Tough 20, 20 + Vigorous 30).

### Sample characters the rules don't reproduce

The book's own rulings, which the program meets with an override (and
`TestCalc` checks as overrides, not as failures):

- **Braun's First Day of Sale Shove!**: roll -2 (the book prints it so,
  p. 33); the rule gives 2 - Clumsy 2 = 0. His TV of 0 follows from
  the -2: -2 + Defense 2 + DX 1/2 counted as 0. The program computes
  roll 0 and TV 2 (DX 1/2 counts as 0 in TV, rounding down; to
  confirm with an NPC whose DX is 1/2).
- **Natsuki's Stiletto Kick**: DX 3; the rule gives 1 + Attack 2 +
  Strong 3 = 6. Its text says it is "without her signature gauntlet",
  her Attack (Iron Fist), so the GM ruled that one attack's DX.

The fixtures list both in their `overrides:` (Phase 3a), so ova_fmt
prints them with `*` and the generator loads them as overrides.

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
    "x3" (p. 83), ova_fmt's `counts-as`; its cost is multiplied by the
    count. "Many Perks and Flaws may be purchased multiple times ... If
    possible, it will be mentioned in the text" (p. 83), so only those
    whose text says so repeat (checked 2026-10-09, every entry on
    pp. 83-89):

    | | No limit | At most 2 | At most 3 |
    |---|---|---|---|
    | Perks | Accurate, Area Effect, Armor Piercing, Defensive, Effective, Multiple Targets, Reach, Vampire | Continued Effect ("if taken twice"), Paralyzing ("may be taken twice") | |
    | Flaws | Assisted (its text says "this Perk", a slip), Backlash, Buildup, Concentration, Inaccurate, Ineffective, Low Penetration ("for each time you take"), Unwieldy | | Ammunition (once, twice, three times: about five uses, three, one) |

    The other 29 are taken once. Cancel and Requirement repeat in
    neither sense: one cost, chosen within their range. Unique Perk
    and Unique Flaw are one entry with the cost the user gives. The
    window offers a count only for the 19 above, up to the limit. The
    sample characters keep to this: Effective x6 (Miho, Fenrir),
    Inaccurate x3 (Miho), Ineffective x3 (Karis), Paralyzing x2 (Cora,
    Karis), and Accurate, Area Effect and Armor Piercing x2.
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
  at Magic 3: 10, written "10+" since Barrier can cost more). A spell
  at -1 to -3 casts a Weakness, as Witchcraft's curses do, at the same
  costs by the Weakness's size: Acacia's Frail -2, Slow -2 and Weak -3
  at Witchcraft 3 cost 10, 10 and 20 (p. 134; added with the Sample
  NPCs).
- Situational modifiers (Reckless Offense and the rest, p. 108) don't
  change a cost and aren't modelled.

### The combat box

- **ROLL**, dice for an attack (p. 105) = 2 + Agile + Combat Expert -
  Clumsy + Accurate x n - Inaccurate x n. A **Will Attack** (p. 86) uses
  Iron-Willed and Weak-Willed in place of Agile and Clumsy. Attack and
  Strong never add to it.
- **DX**, the Damage Multiplier (p. 106) = 1 + Attack + Strong - Weak +
  Effective x n - Ineffective x n. A **Ranged** attack (p. 85) loses
  Strong and Weak (Shou's Dark Spark: 5, not 6; Ai's attacks keep DX 5
  despite her Weak -1); **Ranged, Strength-Powered** (p. 86) keeps
  Strong and Weak. **Telekinesis** (p. 62) adds its level to the DX of
  an attack made with it (Ai: 1 + Attack 1 + Telekinesis 3 = 5); the
  attack dialog has a "made with Telekinesis" check. **No Damage** (p. 88) makes it 0. A DX
  that would be 0 or less without No Damage is 1/2 (Ineffective, p. 88).
- **DEFENSE** (p. 105) = 2 + Evasive + Quick - Slow. Barrier gives an
  alternate Defense Roll, 2 + Barrier (p. 51), written as ova_fmt's
  `defense: 4/5` (Fukiko); Incorporeal Form another, 2 + its level,
  its dice as the Defense Roll (p. 55), written after Barrier's
  (`2/4/6`), or second without Barrier. A file's single value where
  the rules give more is the best of them, as the Sample NPCs print
  it (Phase 11).
- **HEALTH** = 40 (p. 19) + Tough (p. 63: 10, 20, 30, 40, 60 at +1 to
  +5) - 10 per level of Frail (p. 71). **ENDURANCE** = 40 + Vigorous
  (p. 65: the same table) - 10 per level of Languid (p. 73). A
  Companion starts at 20 and 20 instead of 40 (p. 52; Arasuni,
  Fenrir), Tough and Vigorous added the same way; Minions 10 and 10
  (p. 58). An NPC's `npc-type` (p. 123) sets its sheet: a Heroic NPC's
  is a character's, a Secondary NPC's a Companion's (20 and 20, TV 4
  less), an Extra's 10 and 10 with a TV of 1 (p. 124).
  Health is not floored (no rule says so); Tough, Vigorous and
  Endurance Reserve summed past +5 (a form's added to the base's)
  count as +5, with a warning. A Vehicle's start at 40 and 40 (p. 64:
  "They behave in the way you expect"). Endurance Reserve (p. 53: 20
  per level) is a separate store, shown
  beside Endurance, not added to it.
- **TV**, the Threat Value (p. 124) = the best Attack Roll + the best
  Defense Roll (Barrier's or Incorporeal Form's, if higher) + the best DX, all without Perks
  and Flaws, + Armored + the signed levels of the Abilities and
  Weaknesses that change Health and Endurance (Tough and Vigorous add,
  Frail and Languid subtract), + half (rounded up) of the level of any
  other Ability that could matter in a fight, which the user marks.
  Healer and Magic (Arcane, Witchcraft) are marked to start with, as
  the book's examples and the only ones the samples count; Companion
  and Minions can't be (their TVs are their own). A Companion's TV is
  4 less, at least 1 (a Secondary NPC); an Extra's is 1. Every sample checks: Raine 7 +
  5 + 4 + Vigorous 2 = 18; Ai 2 + 5 + 5 - Frail 2 = 10; Auren 5 + 4 +
  4 + Armored 1 + Vigorous 2 + Magic 3/2 = 18.
  - **"Without Perks and Flaws" means without the ones that add each
    time** (Accurate, Inaccurate, Effective, Ineffective, and No
    Damage's 0), found in Phase 2: the best ROLL and DX are taken over
    the attacks, each less what those added, keeping what Ranged,
    Ranged, Strength-Powered, Will Attack and Telekinesis do to how the
    number is made. Ai shows it: her attacks are Ranged and made with
    Telekinesis, and only with Ranged's dropping her Weak -1 is her DX
    5 and her TV 10. A DX of 1/2 counts as 0. With no attack, the plain
    one: 2 + Agile + Combat Expert - Clumsy, and 1 + Attack + Strong -
    Weak.
  - An attack made in a form the sheet isn't shown in doesn't count:
    Miho's Mode SP, made transformed (Combat Expert +2 more, ROLL 10),
    would make her TV 22, not 20.
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
  The bonus is the Abilities' alone ("a character's Abilities should
  rarely give", p. 21): ROLL or Defense less 2, before Accurate and
  Inaccurate.

How the program applies them (Phase 2): under Scaled Cost, Base Zero
checks the points (Abilities' less Weaknesses') and the Power Ceiling
and starting levels the Abilities' points, the Weaknesses' points
adding to the starting ones; without it, levels. Half cost halves a
Knowledge's or Ineptitude's level, or its points, rounding away from 0
(Knowledge 3 counts 2, Ineptitude -3 counts -2), and only when one of
the three is on (p. 57). A Transformation's form is in no total: its
level pays for it (p. 63).

The running totals (levels of Abilities, of Weaknesses, the Character
Total; under Scaled Cost the Abilities' points and the net points) are
shown; a broken limit turns
its total red and says why, but never stops the user: the GM decides.

## Data tables

`OvaRules` holds, for each item, its name, its kind, its page, and for
Perks and Flaws its cost (fixed, a range, or the user's), and how often
it may be taken. For Abilities and Weaknesses it also holds the flags
the calculations need (which roll it changes, whether it changes Health
or Endurance, TV, half cost) and its linked content (spells, a
Transformation's form, a Companion, a Vehicle). Every item may carry a
detail (the samples give one to Attack, Armored, Knowledge, Position
of Power and others), so that needs no flag. Nothing else.

`OvaRules.Find` ignores case, and knows two aliases: `Vehicle` for
`Vehicle (Mecha)` (ova_fmt's `Vehicle.yaml` uses it) and the Quick
List's `Ranged, Str.-Powered`. The names in ova_fmt's fixtures are all
found but those two and `Magic, Testing`, a made-up name in a
formatter test, which is shown with `p. ?`.

Pages (printed), checked against the PDF in Phase 1:

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

One window, `Fl.DoubleWindow`, 640 x 800, narrow enough to sit beside
the PDF viewer: a menu bar, and under it an `FlLayout.Tabs` of five
tabs, each one column: the sheet's two halves in swapped order (decided
by the user, 2026-10-09; the window was 1280 wide, two tabs of two
columns, until Phase 12), then the Markdown sheet (Phase 14). The first tab is the one shown when the
window opens.

The menu bar, above the tabs: File (New, Open, Save, Save As, Quit),
Character (Limits..., Transformed form; Add Character, Duplicate
Character, Remove Character...; Move Up, Move Down; Next Character,
Previous Character), Rulebook (Open, Choose PDF..., Viewer...). At its
right, a `Choice` of the file's characters (Phase 13, "Several
characters in a file", below).

The window can be resized (Phase 15), no smaller than 640 x 800, and
everything in it stretches in proportion: the menu bar and the tabs'
bar only across, keeping their height (`window.SetResizable(tabs)`,
`tabs.SetResizable(sheetTab)`), each page in both directions. Fonts
keep their size. What FLTK doesn't stretch is fitted after a resize,
from an `Fl.Timer` (`fit`) the window's `Resize` starts: the combat
box's rows (a `Scroll` moves its children but doesn't stretch them),
made again at the first size and resized, so FLTK stretches what is in
them; the traits' columns (`OvaTraitPanel.Fit`), whose widths the
browser keeps in pixels; and the portrait (`OvaBackground.Fit`), whose
drawing size is set when it's shown.

1. **First and second tabs, "Character" and "Attacks" (the sheet's
   right half)**; Attacks has the combat box and the numbers below it,
   Character the rest:
   - Character Name and Player Name inputs, a tagline, and the NPC
     Type (none, Heroic, Secondary, Extra), which sets the sheet's
     starting Health and Endurance and its TV;
   - **Abilities** and **Weaknesses**, side by side as on the sheet:
     each a browser of lines (`+3 Attack (Kaze Satsujinsha)`; under
     Scaled Cost with its points, `4 pts`, before the page), and
     under it a `Choice` of every name, a `Spinner` for the level (+1
     to +5, or -1 to -3), a detail `Input`, and Add, Change, Remove and
     **?** buttons. **?** opens the rulebook at the chosen name's page.
     An Ability with linked content (Transformation, Companion, Magic's
     spells, Vehicle) activates a button under the Abilities, labelled
     for it (Form..., Companion..., Spells..., Vehicle...), that opens
     the linked dialog (Phase 7);
   - the running totals and limit warnings, under the two lists;
   - **Combat Notes**, a multi-line input;
   - **the combat box**: a scrolled list of attacks, one row each:
     name, ROLL, DX, END, computed, each with its override box, and
     Edit and Remove (Phase 5: rows of widgets in an `FlLayout.Scroll`,
     not an `FlTable`, since every number needs its own box beside it,
     which a table would have to place as widgets anyway). Add/Edit opens the
     **attack dialog**: name, description, affinity, the Perks and the
     Flaws each as a browser of names with a count (repeatable ones
     only) and a cost (Cancel, Requirement, Unique), each with **?**,
     and its ROLL, DX and END updated as Perks and Flaws change. Below,
     DEFENSE, HEALTH, ENDURANCE and TV, computed; Endurance Reserve
     beside Endurance when there is one.
2. **Third and fourth tabs, "Background" and "Fluff" (the sheet's
   left half)**; Fluff has the portrait, the fluff grid and the notes,
   Background the Summary and the prose: Background, the Character
   Portrait (an image file chosen with `FlDialogs.NativeFileChooser`,
   shown scaled with `FlImages`; its path is saved), Appearance,
   Personality, Character Hooks and Other Notes, each a
   `FlText.TextEditor`; and the
   sheet's fluff fields (Concept, Age, Gender, Height, Weight, Hair,
   Eyes, Association, Hobbies, Favorite Food, Allies, Enemies, Love
   Interests; p. 20) in a `FlLayout.Grid`. Added in Phase 6, so that
   everything a file holds can be edited: the Summary (a line), the
   fluff's Birthday, which ova_fmt has, and the headed notes ova_fmt
   prints as callouts (`notes:`, a list of headers with Add, Change and
   Remove; a new note goes last).
3. **Fifth tab, "Markdown"** (Phase 14, "The Markdown sheet" below):
   the character's sheet as `ova_fmt_po -M` makes it, in an
   `FlText.TextDisplay`, with **Copy** and **Save Markdown...**.

### The Markdown sheet

Asked for by the user, 2026-10-11: show the character's Markdown sheet,
made with ova_fmt_po's code, to copy or save. `OvaMarkdown.Sheet`
writes the character as it would be saved, reads it back as ova_fmt_po
reads a file's entity (`OvaSave.ToEntity`), and formats it with
ova_fmt_po's `OvaCommon.ProcessEntity` in its Markdown format, copied
with `OvaConfig` and `OvaOut`: so the sheet is the text `ova_fmt_po -M`
makes of the saved file, override marks (`\*`) included, and
`test/files.sh` checks it is, byte for byte, for every fixture.

- **Output into a rope**: ova_fmt_po's `OvaOut` writes to standard
  output or a file; it gained `ToRope` and `TakeRope` (in ova_fmt_po,
  with its own `TestOut`), which keep what is written in a rope.
- **The character shown**, not the whole file: the tab is the
  character's sheet. A file's characters, one sheet after another, are
  `ova_fmt_po -M`'s of the file (`TestFiles` writes them so for
  `files.sh`).
- **Kept current**: the sheet is made again after every change
  (`Changed`, a name or text typed, the Background tab's text, a
  character shown), not when the tab is chosen, so it doesn't depend on
  how FLTK calls back a `Tabs`. A sheet takes about 0.4 ms (measured:
  600 of Sheet, Fukiko and Acacia in 0.25 s).
- **Copy** puts the whole sheet on the clipboard (`Fl.Copy`); the
  display's text can be selected too. **Save Markdown...** asks for a
  path (a procedure variable, as every dialog here), suggesting the
  character's name with `.md`, and writes through `path.tmp`, renamed
  once written, as `OvaSave.SaveAll` does; through `Platform`, not
  `OvaOut`, whose first write error stays for the rest of a run. Saving
  the sheet doesn't mark the character changed.

### Page numbers beside names

**Wherever the window shows the name of an Ability, Weakness, Perk or
Flaw, it shows that item's rulebook page beside it**: the page number
printed on the book's page (the same numbers as "Data tables", the
PDF's page labels), not the PDF's page index. The user can turn to it
in a printed copy as well as through **?**. That covers:

- the Abilities and Weaknesses lists: `+3 Attack (Kaze Satsujinsha)`
  in one column, `p. 50` in a narrow right-hand column
  (`Browser.SetColumnWidths`, a tab between them);
- the name `Choice`s: `Attack (p. 50)`, the page in the item's text,
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
  (Ability levels, Weakness levels, Character Total, Ability points,
  Scaled Cost points).
- **The box** is an `FlInputs.Input`, not an `IntInput`, since some
  numbers on the sheet aren't plain integers (Auren's spell's `10+`,
  Fukiko's `4/5` is two numbers, each with its own box). The text is
  checked as the user leaves the box: an integer, or for an END the
  integer with a trailing `+`; anything else is refused with a message
  and the box emptied.
- **An override counts downstream**: a number computed from another
  uses the other's override. The Character Total and the limits use
  the totals' overrides; TV uses Defense's and Barrier's, and each
  attack's ROLL and DX in effect, less what its Accurate, Inaccurate,
  Effective and Ineffective add ("The combat box"). Braun's TV of 0
  comes out of his ROLL overridden to -2 that way.
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
ova_cg_po: no display: neither DISPLAY nor WAYLAND_DISPLAY is set
```

and, inside tmux (`TMUX` set), a second line, since that is where it
was found to happen ("Findings"):

```
ova_cg_po: in tmux, the session may have been attached from a terminal without one; reattach from the desktop, or set them from `tmux show-environment -g`
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
  | okular | yes, over D-Bus | look on the session bus for okular's services, `org.kde.okular` and `org.kde.okular-PID` (not the `Instance_` alias); in each, the objects `/okular`, `/okular2`, ... are its tabs, and `org.kde.okular.currentDocument` says which shows the rulebook. If one does: `/okularshell` `openDocument(file://PDF)`, with only `%`, `#`, `?` and control characters encoded, brings that tab forward (no new tab), then that tab's `goToPage(index)`. If none: start `okular --unique -p INDEX PDF` |
  | evince | yes, by itself | `evince -i INDEX PDF` (or `--page-label=LABEL`): a running evince with that file takes the page and no second window opens; the command exits at once |
  | mupdf | no | `mupdf PDF INDEX`; mupdf has no remote control, so the program ends the mupdf it started last (by its pid) before starting the next, so lookups don't pile up windows |
  | xdg-open | no page | `xdg-open PDF`; the program then says which page to turn to |
  | a template | as the command does | `%f` file, `%p` index, `%l` label, split into words by the program, each substitution one word |

- **Running a program** is `OvaSpawn`, a module with a C part
  (`OvaSpawn.c`): `Detached` starts a program in its own session
  (fork, `setsid`, fork, `execvp`), with standard input, output and
  error on `/dev/null`, and reports a failed `exec` (as `errno`) through
  a close-on-exec pipe; `Capture` runs a program and returns its
  standard output and status, for the D-Bus queries (`gdbus call`,
  `ListNames` among them). Arguments are an argument vector, never a
  shell command line, so nothing is quoted. Without `gdbus`, okular is
  started `--unique` instead (it then reuses only the instance it
  started). A started program is a `Process`, its pid and its start
  time (`/proc/PID/stat`), so `Terminate` (mupdf's replacement) ends it
  only if that pid is still the same process, never a later one given
  the pid, and never a viewer found by name.
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
- **okular's `openDocument` matches the URL as given** (Phase 4, on
  okular 25, a PDF named `O'Brien #1 100% ?.pdf` in `viewer test/`):
  a tab opened from a plain path holds `'` and blanks unencoded, so
  `file://` with every reserved byte encoded (`%27`, `%20`) didn't
  match and opened the PDF again in a new tab; `file://` and the raw
  path matched, but not with `#`, `%` or `?` in it (the URL ends at the
  first two, and `%` starts an escape); a plain path, no `file://`,
  added an empty tab. With only `%`, `#`, `?` (and control
  characters) encoded it matched every time, with no new tab, and
  `okular --unique -p 62 PATH` opened that name at the page. So
  `OvaViewer.FileUrl` encodes those only. okular's `currentDocument`
  gives the plain path, but a `file:` URL is decoded in full anyway.
- **gdbus quotes a string as GLib prints a `GVariant`**: in `'...'`, or
  in `"..."` if it holds a `'`, with `\` escapes (checked with
  `GLib.Variant.print_`); `OvaViewer` reads both.
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
  show-environment`) have them. This stops ova_cg_po itself, before
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
  other number is recomputed, and one that disagrees is **kept as an
  override, with a notice** (changed in Phase 3 from "replaced": the
  file is the user's, a GM's ruling or a hand edit, and replacing it
  would lose what they wrote). Since Phase 3a no sample gives a notice;
  ova_fmt_po's own Escaping, Unsorted and Vehicle, whose numbers were
  never the rules', do. A copy saved lists every override, so it loads
  with none. A file may hold several characters (Phase 13): each is
  loaded, and saved, in order.
- **Several characters in a file** (asked for by the user, 2026-10-10;
  designed with them: the switcher a `Choice` at the menu bar's right,
  and Duplicate and Move Up/Down as well as Add and Remove).
  `OvaCharacter.LoadAll` reads every entity of every document in the
  file, in order, and builds each (`FromEntity`); the notices of all of
  them are listed together, each starting with its character's name.
  `OvaSave.SaveAll` writes them as one document, a sequence in that
  order, so a file of several `---` documents is saved as one; ova_fmt_po
  numbers a file's entities across its documents, so it formats both
  the same (`two-documents.yaml`). The window holds `characters` and
  shows one, `characters[current]`, as `character`, so the rest of it is
  unchanged. "Modified" is the file's: a change to any character marks
  it, and the save-first question names the file. The title says which
  is shown of how many ("Acacia.yaml (1 of 3)"), when there are more
  than one. Add Character and Duplicate Character put the new one last
  and show it; Duplicate copies by building the character's YAML and
  reading it back (`OvaSave.Copy`), so the copy holds exactly what a
  save would, and shares nothing. Remove Character... asks first, and
  is inactive for the only character, since a file holds at least one;
  the one after shows, or before, if it was last. Move Up and Move
  Down reorder; Next and Previous (Ctrl+PgDn, Ctrl+PgUp) don't wrap,
  and like Move are inactive at the ends. Save As rebases every
  character's portrait. ova_fmt underlines entities after the first
  with `-U`'s character, so the first is the file's main character.
  FLTK's text editors take Ctrl+PgUp and Ctrl+PgDn themselves, so
  those keys don't switch characters from the Background tab's prose
  or Combat Notes. `OvaCharacter.Load` remains, for a file of exactly
  one (the tests').
- **Loading** reuses ova_fmt_po's `OvaEntities` (copied, as ova_fmt_po
  copies `Besm2Out`, and kept in step with it), so the generator reads
  exactly what ova_fmt_po reads.
- **Saving** builds a document with polibfyaml's emitter
  (`Fyaml.NewDocument`, `CreateStyledScalar`, `CreateSequence`,
  `CreateMapping`, `SetRoot`, `Append`, `AppendPair`, then `ToFile`,
  with `emitModeBlock`), so no YAML text is written by hand. Keys are
  written in the order of ova_fmt's fixtures. A failed write leaves the
  old file in place: it goes to `NAME.tmp`, then is renamed.
- **Found in Phase 3: libfyaml's emitter writes a `CreateScalar`'s text
  plain even where plain YAML can't hold it** (scratch probes,
  2026-10-09): `#1 fan` reads back as a comment, blanks at either end
  are lost, and text starting with a quote, `- `, `? `, `|`, `>`, `%`,
  `@` or a backquote makes a file that doesn't parse. libfyaml 0.8 has
  no way to set a scalar's style. Fixed in polibfyaml, with the user's
  go-ahead: `CreateStyledScalar(text, style)` parses the scalar from
  YAML text the binding writes itself (double-quoted, a literal block,
  or plain where surely safe), which the emitter then keeps (its
  PLAN.md, "Scalar styles"; `TestStyles`). `OvaSave` writes text of
  more than one line as a literal block, as ova_fmt's fixtures have
  it, and any other text plain where that is safe, else double-quoted;
  numbers, booleans and keys plain.
- OvaEntities trims the background and the other text sections on
  loading, as both ova_fmts do, so blanks at their ends don't survive
  a load, though the file keeps them.

### Changes to ova_fmt

What the generator saves and ova_fmt has no key for is added to **both
the Ada ova_fmt and ova_fmt_po** (decided by the user, 2026-10-09),
Ada first, as ova_fmt_po's AGENTS.md requires ("A change to the Ada
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
| `telekinesis` | an attack | `true`: made with Telekinesis, which adds to its DX (p. 62) |
| `transformed` | an attack | `true`: made in the transformed form (p. 63) |
| `transformed` | `combat` | `true`: the combat box is the transformed form's |

Endurance Use needs no key: its `detail` names the Ability or attack
it is tied to.

Each is optional, as every ova_fmt key but `name` is. For each, the
Ada repo's PLAN.md gets the schema, how every output format prints it
(open question 2), a fixture (`test-data/Sheet.yaml`, a character
using all of them, made with the generator once it saves), and golden
files; then ova_fmt_po ports it, its golden files regenerated from the
new Ada binary (`make golden`), its `test/data/` copied over. Both are
committed in their own repos, with the user's go-ahead.

## Modules

| Module | Contents |
|---|---|
| `OvaCg` (main) | the command line (ArgParser: a file to open, `--rulebook`, `--viewer`), then the window |
| `OvaRules` | the data tables above: names, kinds, pages, costs, flags |
| `OvaCalc` | the calculations: END, ROLL, DX, Defense, Health, Endurance, TV, totals, limits and warnings |
| `OvaCharacter` | the character being built, loaded from a file; the edits the window makes, and `Recompute` (Endurance Use tied, then `OvaCalc.Compute`) |
| `OvaEntities` | ova_fmt_po's loader, copied |
| `OvaSave` | the YAML writer, through polibfyaml's emitter |
| `OvaViewer` | the rulebook's path, the viewer chosen, reusing a running one (okular over D-Bus, evince, mupdf) |
| `OvaSpawn` (with `OvaSpawn.c`) | starting a program detached; running one and capturing its output |
| `OvaWidgets` | what the window and its dialogs share: `NumberBox` (a computed number and its override box), the **?** `HelpButton`, and `Panel` (a list and its editor) |
| `OvaWindow` | the main window, its menu bar, the Character and Attacks tabs, and the file |
| `OvaBackground` | the Background and Fluff tabs: the summary, the prose, the portrait, the fluff and the notes |
| `OvaPaths` | paths made absolute, a file's directory, a path relative to a directory, rebasing the portrait's |
| `OvaAttackDialog` | the attack dialog, and the Perks/Flaws editor an Ability with Perks uses |
| `OvaTraitPanel` | a list of Abilities or Weaknesses and its editor: the character's, a form's, a partner's |
| `OvaSettings` | Character > Limits...: the rules that limit a character, in its `options:` |
| `OvaLinkedDialog` | an Ability's linked content: a Transformation's form, a Magic's spells, a Companion's or Vehicle's sheet |
| `OvaMarkdown` | the character's Markdown sheet, through ova_fmt_po's `OvaCommon`; saving it to a file |
| `OvaMarkdownTab` | the Markdown tab: the sheet shown, Copy, Save Markdown... |
| `OvaText`, `OvaOut`, `OvaConfig`, `OvaCommon` | ova_fmt_po's, copied |

`OvaRules`, `OvaCalc`, `OvaCharacter`, `OvaSave`, `OvaMarkdown`,
`OvaSpawn`, `OvaViewer` and `OvaPaths` import no pofltk: they are
tested with no display.

## Build order

0. **Skeleton.** [done] `GNUmakefile` (from ova_fmt_po's and pofltk's,
   with `test-headless` and `test-sway`), `README.md`, `test/Check.Mod`,
   `test/poc-gc.supp` (ova_fmt_po's plus pofltk's), a window with a
   menu bar that opens and quits under Xvfb.
   - `OvaCg` (main): `-h`; a file argument is refused (status 2) until
     Phase 3; the display check of "Starting". `OvaWindow`: a 1280 x 800
     `Fl.DoubleWindow`, a menu bar with File > Quit (Ctrl+Q), an empty
     box for the tabs to come; Quit and the close button hide the
     window, ending `Fl.Run`.
   - Tests: `test/cli.sh` (14 checks: `-h`, mistakes, no display, in
     and out of tmux, empty variables); `TestWindow` (8: opening, File >
     Quit, the close button, every widget deleted); the program still
     running after 3 s; `test/quit.sh`, Ctrl+Q sent by `xdotool` ends the
     real program with status 0 (X11 only). Passed on Xvfb and on a
     headless sway (2026-10-09); valgrind clean on both (no errors, no
     leak of pofltk's). The tmux hint and the Ctrl+Q check were each
     shown to fail with the bug planted.
   - `tools/with-sway.sh` is pofltk's, copied.
1. **`OvaRules`.** [done] The tables, each page checked by eye against
   the PDF and recorded here; `Label`, `PageText`; `TestRules`: every
   Quick List name present once, each with a page within its section's
   range, costs as the Quick List gives them, and the labels' format.
   - `src/OvaRules.Mod`: the 173 items in the book's order, with flags
     for the calculations (Phase 2 will use them), costs, repeat limits,
     linked content; `Find`, `Count`, `Get`, `Label` (`Attack (p.
     50)`), `PageText` (`p. 50`), `LabelOf` (`Magic, Testing (p. ?)`
     for an unknown name), `PdfIndex`; the Tough/Vigorous, Endurance
     Reserve, Endurance Use and spell cost tables; the rules' own pages.
   - `test/TestRules.Mod` (35 checks, no display): its Quick List
     entries are generated from the PDF's text of p. 90, not typed, and
     each must be found, of its kind, at its place in the book's order,
     at its cost. Shown to fail with four planted bugs (a page, two
     Weaknesses swapped, a cost, a repeat limit).
   - `make check-pages` (not in `make test`; needs the PDF and mutool):
     every page against the headings found by font. Shown to fail with
     a planted page.
   - The pages were checked by font rather than by looking at each of
     41 page images, which the plan asked for: the font check covers
     every heading, and two pages looked at by eye agree with it.
2. **`OvaCalc`.** Every rule above, with `TestCalc` over the sample
   characters (every one in `test-data/`, as fixtures) and hand-made
   cases for each Perk and Flaw that changes ROLL or DX, floors at 0,
   the 1/2 DX, Endurance Use, spells, each limit, and overrides feeding
   what is computed from them. [done]
   - `src/OvaCalc.Mod`: a `Sheet` of `Trait`s (each with its Perks and
     Flaws as `Mod`s, a Transformation's form, a Magic's `Spell`s, a
     Companion's or Vehicle's own `Sheet`) and `Attack`s; every computed
     number a `Number`, holding its override; `Compute` sets them all,
     reading the overrides others depend on, and lists `Warning`s (a
     code, and the trait, attack, Perk or Flaw, or spell it is about:
     the window words them, with labels). The client allocates the
     records (`Init*`, `Add*`), so `OvaCharacter` can extend them.
     `Parse` and `Text` are the override box's text: an integer, `1/2`
     for a DX, `10+` for an END.
   - `OvaRules` gained `OwnCost`, Barrier's: an Ability that spends
     Endurance of its own as it is used (p. 51), so a spell of it is
     written `10+` (Auren's Mana Shield).
   - `test/TestCalc.Mod` (384 checks, no display): each of the twelve
     samples in `test/data/` (ova_fmt's `test-data/`, all 18 copied)
     loaded by `test/Samples.Mod` through `OvaEntities`, and every
     number its file holds compared, the two Companions' included
     (231 checks); Braun's ROLL and Natsuki's Stiletto Kick checked
     computed (0 and 6), then as overrides, with Braun's TV of 0
     following. What the files have no key for is set in the test: Ai's
     attacks made with Telekinesis, Fukiko's sheet shown transformed,
     Miho's Mode SP made transformed (keys decided for Phase 3a). Then hand-made
     cases for every rule and warning, and `Parse`.
   - Shown to fail with twelve bugs planted one at a time in `OvaCalc`
     (Ranged keeping Strong, no Companion -4, TV ignoring a ROLL
     override, END not floored, half TV rounded down, Telekinesis not
     added, no `+` on a spell, no half cost, Will Attack ignored, no
     1/2, Barrier not in TV, the form always counted): each failed the
     checks aimed at it. Valgrind clean (no errors, nothing lost, only
     the collector's blocks reachable).
3. **Files.** `OvaEntities` copied (done in Phase 2, with `OvaText`,
   for `TestCalc`), `OvaCharacter` (extending `OvaCalc`'s records, and
   taking over `test/Samples.Mod`'s building), `OvaSave` (with
   `Fyaml.ToFile`); `TestFiles`: each fixture loaded, saved and
   formatted by ova_fmt_po gives the same output as the fixture (`-H`
   and the terse format), and overrides survive a save and a load.
   [done]
   - `src/OvaCharacter.Mod`: `Character` extends `OvaCalc.Sheet` (and
     `Trait`, `Mod`, `Attack`, `Spell` theirs) with names, details,
     notes, text, fluff, and which optional keys the file had; `Build`
     makes one from what OvaEntities read; `Load` reads a file
     (`ReadEntity`), builds it, and keeps each number of the file that
     differs from the rules' as an override, in `notices`.
   - `src/OvaSave.Mod`: `Save` (through `NAME.tmp`) and `ToText`, the
     keys of every key OvaEntities reads but none of Phase 3a's.
   - polibfyaml gained `CreateStyledScalar` ("Saving", above).
   - `test/TestFiles.Mod` (104 checks): the 15 fixtures with one
     character loaded, saved into `obj/files/`, loaded again (the same
     YAML, the same notices), with the notices each must give (none for
     seven samples; Ai 2, Braun 1, Fukiko 9, Miho 2, Natsuki 1, which
     Phase 3a's keys and the overrides key will remove; ova_fmt_po's
     own Escaping, Unsorted and Vehicle, whose numbers aren't the
     rules'); the files refused (Broken, two characters, missing); a
     failed save; a character with awkward text (a leading `#`, quotes,
     a block's first line indented) saved and read back. `test/files.sh`
     (105 checks): each saved copy formats as its fixture in all seven
     of ova_fmt_po's formats (terse, `-H`, `-G`, `-M`, `-g`, `-m`,
     `-O`); `make test` runs it with `OVA_FMT_PO`. `TestCalc` builds
     through `OvaCharacter` now; `test/Samples.Mod` is gone.
   - Shown to fail with nine bugs planted in `OvaSave` and
     `OvaCharacter` (affinity, counts-as, a form's Weaknesses, a spell's
     ability or Barrier's Defense not written, the computed number
     written for an override, a fluff key misspelled, the file's numbers
     ignored, plain `CreateScalar` for text): each failed TestFiles,
     files.sh or both; the last only the awkward-text check, as no
     fixture has such text. Valgrind clean.
   - "Overrides survive a save and a load" needs the overrides key:
     Phase 3a. Until then they survive as numbers that come back as
     overrides, with notices (checked: the same notices after a save).
     Done in Phase 3a.
3a. **ova_fmt's new keys**, in the Ada ova_fmt and then ova_fmt_po
   ("Changes to ova_fmt"), before the generator saves them; then
   `OvaEntities` copied again. [done]
   - The Ada ova_fmt: every key of "Changes to ova_fmt", printed as
     decided (its PLAN.md, §9 step 9, has the details: `overrides` is a
     list of the mapping's computed keys, anything else a load error;
     the `*` is `\*` in reST and Markdown; `telekinesis` and
     `transformed` aren't printed, being the calculation's inputs,
     which the user may revisit). `test-data/Sheet.yaml`, written by
     hand, uses every key; each number it doesn't list is the rules',
     checked here (it loads with no notices). The samples gained the
     keys: Ai's attacks `telekinesis`, Fukiko's combat `transformed`,
     Miho's Mode SP `transformed`, and Braun's and Natsuki's rulings
     `overrides` (now printed with `*`). Every other output of every
     fixture was the same bytes before and after (ova_fmt_po's 368
     golden cases).
   - ova_fmt_po ported it (its PLAN.md, "Keys for the character
     generator"), golden files regenerated (390 cases, two new `bad-`
     and `edge-overrides` fixtures), planted bugs caught, valgrind
     clean.
   - Here: `OvaEntities` copied again; `OvaCharacter` reads the text
     keys, `threat-value-half` (into `halfTV`, the rules' default when
     absent; `hasHalfTV` says it was written), `telekinesis`,
     `transformed`, the two options, and adopts a listed number as an
     override with no notice; `OvaSave` writes them all, and each
     mapping's `overrides:` for its overridden numbers. `TestFiles`
     (110 checks): every sample, and Sheet, loads with no notices
     (there were 15), and each saved copy with none. `TestCalc` checks
     that `Build` reads the flags instead of setting them. `files.sh`
     compares Escaping's, Unsorted's and Vehicle's copies (whose
     noticed numbers the copies list, so print with `*`) with the
     marks taken out of both outputs, every other copy exactly.
   - Shown to fail with six bugs planted in `OvaCharacter` and
     `OvaSave` (a listed number given a notice, no `overrides:`
     written, `telekinesis` not written, `health` always listed, the
     combat's `transformed` not read, `other-notes` not written): each
     failed between 2 and 84 checks. Valgrind clean.
4. **The viewer.** `OvaSpawn` and `OvaViewer`. `TestSpawn`: a missing
   program's `ENOENT`, arguments arriving exactly (a recording script,
   `test/fake-viewer.sh`, with a path holding a space and a `'`), the
   started program in its own session, no zombie, `Capture`'s output
   and status. The real viewers on a headless sway inside
   `dbus-run-session` (`make test-viewers`, below; `TestViewer` runs on
   fakes, with no display): okular found and turned over D-Bus (one tab, the
   right page, read back with `currentPage`), evince reused (one
   window), mupdf replaced, each viewer's page checked as in the
   experiments (scratchpad scripts to become `test/viewer.sh`). [done]
   - `OvaSpawn` (with `OvaSpawn.c`): `Args` (`Add`, `AddRope`, `Arg`;
     too long is `E2BIG`), `Detached` (fork, `setsid`, fork, `execvp`;
     standard files on `/dev/null`; the pid and the `exec`'s `errno`
     back through close-on-exec pipes), `Capture` (standard output
     read in chunks into a rope; the exit status, -1 for a signal),
     `Process` with `Alive` and `Terminate` (pid and start time),
     `OnPath`, `ErrorText` (`strerror`), `Session`. `TestSpawn` (28
     checks): the above, and the started program's parent not us, its
     session its own, no terminal, its standard files `/dev/null`, a
     `Capture` of 108,894 bytes whole.
   - `OvaViewer`: `Choose`/`FindRulebook` (the PDF's search order, made
     absolute), `Default`, `Parse` and `Name` (a viewer's name or a
     template with `%f`), `Command` (each viewer's start; a template's
     `%f`, `%p`, `%l`, `%%`, each within its word), `FileUrl`, `Open`
     (okular over gdbus, else started; mupdf's last ended first;
     xdg-open's message giving the page; a failed start's `FALSE` and
     message), `EndMupdf`. The programs' names are exported variables,
     so `TestViewer` (28 checks, no display) runs it on
     `test/fake-viewer.sh` and `test/fake-gdbus.sh`: the D-Bus calls
     made, in order, for two okulars with a decoy name and alias, a
     document given as a URL, none showing the PDF, and no gdbus.
   - The real viewers: `make test-viewers` (`test/viewer.sh`, driving
     `test/OpenPage.Mod`), on its own headless sway with Xwayland, on a
     private bus, with a scratch `HOME`, over a generated 100-page PDF
     whose page n is filled with a colour encoding n, so a pixel at a
     window's centre (grim) says which page it shows; okular's is read
     over D-Bus too. 28 checks: okular started `--unique` and reused
     (one window, one tab, pages 62 then 72); okular as the user runs it
     (another file in front, the PDF in a tab behind) turned with no
     tab added and its tab brought forward, the other tab left alone;
     evince reused (one window); mupdf's first window replaced; nothing
     started left running. It found okular's URL matching (Findings).
     Not in `make test`: it needs the viewers and takes about 30 s.
   - Shown to fail with bugs planted: in `OvaSpawn.c` (no `setsid`,
     the middle child not waited for, the `errno` pipe not
     close-on-exec, standard output kept, the last argument dropped,
     `Terminate` not killing), each failing 1 to 9 checks; in
     `OvaViewer` (any `org.kde.okular*` name taken, no URL decoding,
     `goToPage` on the first tab, mupdf not replaced, `'` encoded,
     the search order swapped, `%f` its own word, two tabs at most),
     each failing `TestViewer`; and against the real viewers (mupdf not
     replaced, the start commands or `goToPage` a page off, a mupdf left
     running), each failing `viewer.sh`. Valgrind clean
     (`--child-silent-after-fork`: a forked child only execs or exits).
   - Not yet: the window's use of it, the Rulebook menu, the **?**
     buttons, `--rulebook` and `--viewer`, and the path and viewer saved
     in `FlPreferences`, which come with the window in Phases 5 and 8.
5. **The first tab**: names, Abilities and Weaknesses, totals, the
   combat box and the attack dialog, and the override box beside every
   computed number; `TestWindow` driving
   it as pofltk's tests do, checking the model, the shown numbers, and
   the page beside every name shown, and that an override changes what
   is shown, saved, and computed from it, and clearing it undoes that.
   [done]
   - `OvaCharacter`: `Recompute` ties each Endurance Use to the
     Ability, else the attack, its detail names ("Name" or "Name
     (detail)", ignoring case), then runs `OvaCalc.Compute`; `Build`
     and the loader use it. Phase 3 had left the tie out, so
     Endurance Use counted in no END (found writing `TestModel`). The edits:
     `NewTrait`, `InsertTrait` (Abilities before Weaknesses, each by
     name, then detail, ignoring case, as the loader keeps them),
     `RemoveTrait`, `ChangeTrait` (moved to its new place), `NewAttack`,
     `RemoveAttack`, `NewMod`, `InsertMod` (Perks before Flaws),
     `RemoveMod`, `CopyMods`, `SetText`. `TestModel` (18 checks, no
     display): the orders, the changes, the tie, and a save and load
     with no notices.
   - `OvaWidgets`: `NumberBox` (the computed number, read-only, and
     the override box; its `Target` says where the number lives, so it
     reads and sets the model, never a copy; the text is taken on
     leaving the box or Enter, and refused text said so and the box
     emptied), `HelpButton` (through `openPage`), and `Panel`, the
     shape of the Abilities, the Weaknesses, and the dialog's Perks and
     Flaws: a browser with the page column, a `Choice` of
     `OvaRules.Label`s, a `Spinner`, a text field, Add, Change, Remove
     and **?**; its extension says what the lines are and what the
     buttons do.
   - `OvaAttackDialog`: one dialog for an attack (name, affinity,
     description, made with Telekinesis, made transformed, Perks,
     Flaws, ROLL, DX, END) and for an Ability's Perks and Flaws (its
     END alone). It edits the model as the user works, so its numbers
     are `OvaCalc`'s; Cancel puts back what was there (a deep copy of
     the mods, the attack's record), or takes out an attack just added.
     It is modal but doesn't wait: OK and Cancel call back.
   - `OvaWindow`: the menu bar (File: New, Open, Save, Save As, Quit,
     with their shortcuts; Rulebook > Open), the tabs, and the first
     tab: the names and tagline, the two panels, the chosen Ability's
     END and its Perks and Flaws button, the totals (Scaled Cost's
     points, the Abilities' and the net, only under it), the warnings in words with each item's
     page, the Combat Notes, and the combat box with DEFENSE, Barrier's
     (only with Barrier), HEALTH, ENDURANCE, the Reserve (only with
     one) and TV under it. The title has the file's name and `*` for
     unsaved changes; New, Open, Quit and the close button ask first.
     Messages, the question, the file chooser and the rulebook go
     through procedure variables (`tell`, `ask`, `choosePath`,
     `OvaWidgets.openPage`) a test answers. A row's Remove rebuilds
     the rows from a timer, since FLTK can't delete the button whose
     callback is running. `OvaCg` takes the file argument (loaded
     before the display is looked for: a bad file exits 1 with the
     reasons), `--rulebook` and `--viewer`.
   - `TestWindow` (71 checks, on Xvfb and on sway): the menu items; a
     fixture loaded, every list line and every Choice and Perk/Flaw
     label against `OvaRules`' page, every number box against the
     model; an override shown, marked, saved in `overrides`, cleared,
     refused (`lots`, a HEALTH of `1/2`); Braun's TV from his ROLL
     override, cleared and set again; an unknown name with `p. ?` in
     its list line and its warning; Add, Change and Remove of an
     Ability; Endurance Use added and the Ability's END shown and
     overridden; an Ability's Perk added, cancelled, added; an attack
     added through the dialog, with a counted Perk and a costed Flaw,
     a bad cost, edited and cancelled, a new one cancelled, OK with no
     name refused, a row removed; the player and Combat Notes saved;
     Save As, the file loaded again the same; New, and Quit and the
     close button asking. `test/cli.sh` covers the new command line.
   - Shown to fail with bugs planted: the override not stored (5
     checks failed), no page column (6), the rows' numbers not shown
     again (12), Cancel keeping the edited mods (2), no `*` in the title
     (1), Remove not rebuilding the rows (1), an unknown name's warning
     without `(p. ?)` (1); in `OvaCharacter`, no
     Endurance Use tie (3) and traits appended unsorted (4). Valgrind
     clean on Xvfb and sway.
   - Seen on a screenshot of `Sheet.yaml`: its Ability was plain
     "Magic", which isn't an `OvaRules` name (the book has "Magic,
     Arcane" and "Magic, Witchcraft"), so it showed `p. ?` and a
     warning. Renamed "Magic, Arcane" in all three repos' copies (the
     user's decision, 2026-10-09; ova_fmt_po's golden files
     regenerated); its spell's END is still overridden (15, the rules'
     10), and it loads with no warnings or notices. An unknown name's
     `p. ?` and warning are checked in `TestWindow` with a made-up name
     instead.
6. **The second tab**: the text fields, the fluff grid, the portrait.
   [done]
   - `OvaBackground`, its own module, since `OvaWindow` was already
     large: `Build` makes the tab inside the window's Tabs, `Show`
     shows a character from a file in a directory, `SetDir` after a
     Save As; it reports each change through `changed` (the window
     marks the title), and asks through `tell` and `chooseImage`, which
     a test sets. Every change goes into the character as the user
     types, trimmed as the loader trims it (blank is absent), so a file
     saved loads the same; the fluff's block is written while any field
     has text. The editors' buffers report changes from
     `TextBuffer.Modified`, which FLTK also calls when the program sets
     the text: a `filling` flag keeps a load from counting as a change.
   - **The portrait's path** is saved relative to the YAML file
     (`OvaPaths.Relative` to the file's directory), and found from it;
     a character never saved holds the absolute path until its first
     save. Save and Save As rebase it (`OvaPaths.Rebase`) to the new
     file's directory, and put it back if the save fails. An image
     that can't be read leaves the path, and the box says so; it is no
     error, since a file may name an image not copied with it (Sheet's
     `images/hana.png`). Paths are handled as text: `..` takes out the
     name before it, and symbolic links aren't followed. `OvaSave`
     double-quotes a path starting with `.`, as it does any text it
     can't be sure is safe plain.
   - `TestPaths` (21 checks, no display): normalizing, absolute,
     `Dir`, relative (below, beside, up to the root, a name's prefix
     not a directory), rebasing. `TestBackground` (41 checks, on Xvfb
     and sway): a new character's empty tab; Sheet's text, fluff and
     missing portrait shown; Raine's notes listed and one selected;
     typing in a section (the title marked, saved, trimmed, emptied and
     not saved); the summary; the fluff (its keys, the block dropped
     with every field empty and back with one); notes refused without
     text, added, changed, removed; an image this test writes as a PNG
     chosen, shown scaled, saved relative, kept by a failed save,
     rebased by Save As, found again on loading; the chooser
     cancelled; the portrait removed; New, and a first save making an
     absolute path relative.
   - Shown to fail with bugs planted: no rebase on Save As (4 checks
     failed), a failed save keeping the rebased path (4), the prose not
     trimmed (6), `fluff:` kept with every field empty (1), showing a
     character counting as a change (2), the portrait found from the
     working directory (4), a note with no text added (3); in
     `OvaPaths`, `..` kept as a name (4) and one `..` too few (5).
     Valgrind clean on Xvfb and sway.
7. **Linked content**: Transformation (and the transformed form's
   combat box), Companion, spells, Vehicle. [done]
   - **One button**, under the Abilities' editor, labelled for the
     selected Ability's linked content (Form..., Spells...,
     Companion..., Vehicle...; "Linked..." and inactive for none),
     rather than a button per kind.
   - **`OvaTraitPanel`**: the first tab's Abilities and Weaknesses
     panel, moved out of `OvaWindow` and generalized, so the same panel
     edits the character's traits, a form's (an owner's `form` list),
     and a partner's. After a change it recomputes `top`, the
     character the list belongs to, and calls `changed`.
   - **`OvaLinkedDialog`**, one modal dialog in three shapes: a form
     (its Abilities and Weaknesses, the selected one's Perks, Flaws and
     END, and a line of its levels against the 2 a level Transformation
     pays for, in red when over; p. 63); spells (name, the Ability
     mimicked, level, and END with its override box; p. 57-58); a
     partner's sheet (name, Fragment, combat stats, Abilities and
     Weaknesses, attacks through the attack dialog, and the numbers
     with their override boxes; Barrier's and Reserve's inactive
     unless it has them). **It edits live and has only Close**, like
     the first tab: every change is in the character at once. Close
     waits while the attack dialog is open.
   - **Character > Transformed form** (a toggle, Ctrl+T) shows and
     computes the sheet in the form, and saves `transformed:`; the
     combat box shows the form's numbers at once.
   - `OvaCharacter.ChangeTrait` drops the form, spells or partner when
     an Ability changes to one with another kind of linked content
     (Magic, Arcane to Witchcraft keeps the spells; to Flight drops
     them). A partner's sheet is made when its dialog first opens: a
     Companion's starts as a Companion's sheet (20 and 20, p. 52), a
     Vehicle's as a character's (p. 64); its name is the Ability's
     detail, or the label ("Companion", "Vehicle") without one, and a
     blank name typed becomes the label too, since the file needs one.
   - **Found, and fixed in pofltk: deferred deletion freed twice.** A
     widget deleted, or its group cleared, inside a callback is queued
     with `Fl::delete_widget` but stays in its group; clearing or
     deleting that group again outside a callback, before the queue
     ran, deleted it at once, and the queue then freed it again (a
     segfault in `Fl::do_widget_deletion`). The program never met it,
     since `Fl::run` empties the queue between callbacks, but
     `TestLinked` did: File > New from the menu, then
     `OvaWindow.Load` called directly. pofltk now runs the queue
     before deleting outside a callback (its `doc/fltk-issues.md`, 72;
     2026-10-10, with the user's go-ahead), and `TestLinked` needs no
     workaround.
   - `TestLinked` (51 checks, on Xvfb and sway): the button's labels;
     Fukiko's form listed, its levels against Transformation's, an
     Ability added (her HEALTH counts it, saved, over in red), a form
     Barrier's Perks and END, Close waiting for the attack dialog;
     Transformed form off and on; Azyrus (a Fragment, no combat stats
     then combat stats, renamed, a blank name, an Ability, a HEALTH
     override saved, an attack added and removed); Auren's six spells
     with their pages and END, one added, a level and an override, a
     nameless one refused, one selected and removed; Magic, Arcane to
     Witchcraft and to Flight; a new Companion (its sheet, 20 and 20,
     saved) and a new Vehicle with no detail; Vehicle.yaml's
     Thunderhawk; every widget deleted.
   - Shown to fail with bugs planted: the spells kept on a change to
     Flight (1 check failed), a Companion made on a character's sheet
     (2), the over-budget line not red (1), Reserve's box active (1),
     Spells... mislabelled (1), Transformed form inverted (2), the
     combat box not shown again after the toggle (1), a
     partner not named its detail (2), a Vehicle labelled Companion
     (1); and, before pofltk's fix, the segfault.
     `TestWindow` and `TestBackground` unchanged by the move to
     `OvaTraitPanel`. Valgrind clean on Xvfb and sway.
8. **Limits and warnings**, the settings dialog, preferences. [done]
   - The limits' rules and warnings were `OvaCalc`'s since Phase 2;
     this phase adds the dialog that turns them on, the red totals,
     and the preferences.
   - **`OvaSettings`**, Character > Limits... (Ctrl+E; Ctrl+L until
     Phase 9, which found a text input types it): a check box
     for each rule, with its number (Base Zero's range, the starting
     levels, the Power Ceiling) beside it, active only while the rule
     is on, and a **?** for its page (21; half cost 57). Half cost is
     active only with Base Zero, a Power Ceiling or Scaled Cost, the
     rules it applies under (p. 57), but keeps its value. A number
     never set starts at p. 21's example (decided 2026-10-10): Base
     Zero's 5, 5 starting levels, a Power Ceiling of 15; one turned off
     keeps what it was. It edits live, as the attack dialog does, with
     OK and Cancel; Cancel (or the close button) puts back the options
     and the title's mark. The `options:` block is saved while a rule
     is on, or if the file had one and the user changed nothing that
     is saved (a number counts only while its rule is on: found
     writing `TestLimits`, where turning a rule on and off again
     otherwise dropped a file's empty block).
   - **Red totals** (p. 21's "says why" is the warning beside them):
     Base Zero's the Character Total, or the points under Scaled Cost,
     which it measures; a Power Ceiling's and the starting levels' the
     Abilities' levels, or under Scaled Cost the Abilities' points,
     which they count there (shown since 2026-10-11, in a box of their
     own beside the net points, with its override as every total has).
   - **Each trait's Scaled Cost points in the lists** (decided
     2026-10-11): under Scaled Cost a line shows its trait's points
     (`+3 Attack`, `4 pts`, `p. 50`), as the totals count them
     (Knowledge and Ineptitude halved under half cost), from
     `OvaCalc`'s `Trait.points`. Not a form's lines, which no total
     counts (p. 63). A line's points have no override box of their
     own: they are the parts of the Ability or Weakness points, and
     the Ability points' box overrides what they add up to. The lists
     refresh when the limits change, so turning Scaled Cost on or off
     shows them or takes them away.
   - **Preferences**: `FlPreferences`, `$XDG_CONFIG_HOME/ova_cg_po/
     ova_cg_po.prefs` (FLTK's vendor and application both
     `ova_cg_po`), holding `rulebook` and `viewer`, written as each is
     chosen. `OvaCg` opens them after the window and closes them on
     quitting; FLTK writes nothing back unless one changed (its
     source, `RootNode::~RootNode`), and `make test-gui` points
     `XDG_CONFIG_HOME` into `obj/`, so the tests' runs of the program
     never touch the user's. The window's `UsePreferences` reads them:
     `--viewer`'s viewer wins over the one kept, and one kept that
     isn't a viewer is ignored; the rulebook kept comes after
     `--rulebook` and `OVA_RULEBOOK` (`OvaViewer.FindRulebook`).
   - **The Rulebook menu**: Open, Choose PDF... (a file chooser,
     filtered to PDFs; the path made absolute, used from then on in
     this run even over `--rulebook`, and kept), Viewer... (a line of
     text: a viewer's name or a command, refused with a message if it
     isn't one, else kept). A rulebook not found is asked for once,
     with the same chooser; cancelled, the message says where it
     looked and how to give it.
   - `TestLimits` (41 checks, on Xvfb and sway): a new character with
     Attack +3 through each rule, its number, what is saved, and which
     total is red; half cost's activity and count; Cancel, OK, the
     close button; an empty `options:` block kept; Sheet's limits
     shown; Choose PDF..., Viewer... (a name, a command, not a viewer,
     cancelled), kept in a preferences file in `obj/` and read back,
     `--viewer` winning, a bad viewer kept ignored; a rulebook not
     found asked for, cancelled, then chosen and opened, and found the
     next time.
   - Shown to fail with bugs planted: the Total red under Scaled Cost
     (1 check failed), the starting levels not red (1), Cancel keeping
     the options (2) or the title's mark (1), half cost always active
     (3), a ceiling of 20 to start (2), the kept viewer beating
     `--viewer` (1), the chosen PDF kept relative (3), a missing
     rulebook not asked for (3), the range's spinner ignored (4), and
     a file's empty block dropped (1); the Abilities' points not
     shown and their levels red under Scaled Cost (2), the net points
     ignoring the Abilities' points' override (2, `TestCalc`); a
     trait's points not halved (2, `TestCalc`), the lists not
     refreshed when the limits change (2).
9. **Finish**: valgrind clean, `make install`, README's user guide.
   [done]
   - **README's user guide**, "Using the window": the menus and their
     keys, each tab, the dialogs, overrides, the limits and the
     rulebook, written from the code and from the window captured on
     Xvfb with Miho loaded.
   - **Limits' shortcut is Ctrl+E**, not Ctrl+L: capturing the Limits
     dialog for the guide, Ctrl+L typed a form feed into Character
     Name, where the cursor starts, and marked the character changed.
     FLTK's `Fl_Input` inserts Ctrl+H, I, J, L and M literally
     (`Fl_Input::handle_key`, FLTK 1.4.5), and a key the focused widget
     takes never reaches the menu's shortcuts; it also takes Ctrl+A, C,
     V, X and Z, as `Fl_Text_Editor` does. Ctrl+E is none of these.
     `test/quit.sh` now sends Ctrl+E with the cursor in Character Name
     and checks that Limits opens and the title has no mark, then that
     Escape closes it, before Ctrl+Q; with Ctrl+L sent to the old
     build it failed.
   - `make test-gui` makes `obj/files` itself, so `make test-headless`
     right after `make clean` no longer fails four `TestBackground`
     checks (its Save As writes there).
   - `make install` checked with `DESTDIR`: `ova_cg_po` alone, mode
     755, in `$(DESTDIR)$(PREFIX)/bin`; `make uninstall` removes it.
   - From `make clean`: `make test`, `test-headless` and `test-sway`
     pass; valgrind clean on Xvfb and sway (no errors in any of the
     11 programs, nothing of pofltk's left; 2026-10-10).

10. **The Sample NPCs**: ova_fmt's `npc-type` and `character-hooks`,
   its Sample NPCs and NPC Fragments as fixtures, and the differences
   from the book they show. [done]
   - `OvaEntities` copied again, with ova_fmt_po's port of the Ada
     ova_fmt's commits of 2026-10-10; the 30 new fixtures and five
     re-synced ones copied from ova_fmt_po's `test/data/`.
   - `OvaCharacter`: `characterHooks`, and `npcType`, which sets the
     sheet's kind (`SetNpcType`): none and Heroic `OvaCalc.Character`,
     Secondary `CompanionSheet`, Extra the new `ExtraSheet` (10 and
     10, TV 1). `OvaSave` writes both; `OvaWindow` has an NPC Type
     `Choice` beside the tagline, each type with its page
     (`OvaRules.PageLabel`, `NpcTypesPage`); `OvaBackground` a Character
     Hooks editor after Personality.
   - An Ability's END of 0 isn't saved unless it is an override, as
     the fixtures write none: Unsorted's copy wrote `endurance: 0`,
     which ova_fmt_po now prints ("0 Endurance").
   - A file's single DEFENSE, where Barrier gives a second, is saved
     single (`omitBarrier`), as the Sample NPCs print it (Shadowman).
   - Witchcraft's Weakness spells cost by their size ("Spells", above).
     The spell dialog follows: for Witchcraft (`OvaRules.CastsWeaknesses`)
     its Choice lists the Weaknesses and its level runs -3 to -1, a
     curse's line shows its level unsigned ("Frail -2"); for Arcane,
     the Abilities at +1 to +5, as before. `TestLinked` adds a curse
     to Cora's Witchcraft; three bugs planted there (Witchcraft not
     flagged, the curse's bounds, a "+" before its level) each failed
     it.
   - `CHARACTER-DIFFERENCES.md`: every number of the book's samples the
     rules don't give, and why. `TestFiles` loads 28 new fixtures with
     the notices it lists (Nazo 2, Shadowman 1, the rest none) and
     refuses Acacia and Zurkrieg (several entities); `files.sh` takes
     the marks out of Nazo's and Shadowman's copies.
   - Shown to fail with eight bugs planted (Secondary as a character,
     an Extra's TV, `npc-type` and `character-hooks` not saved or not
     read, END 0 written, `omitBarrier` ignored, the Choice's items
     off by one): each failed between 2 and 50 checks. Valgrind clean
     on Xvfb.
11. **Up to three Defense values**: Incorporeal Form's alternate
   Defense, beside Barrier's, after ova_fmt's `defense` came to hold
   three values (2026-10-10; designed with the user: positional
   values, `defense-2` and `defense-3`, a single value the best). [done]
   - `OvaEntities` copied again from ova_fmt_po: `OvDefense2` (was
     `OvBarrier`, and `barrier` still read as it) and `OvDefense3`.
   - `OvaRules.ThirdDefense` on Incorporeal Form (p. 55); it was 20,
     which was also `RollEach`'s, the first Perk flag, so the Perk
     flags (`RollEach` to `NoDamageDone`) now start at 24, past the
     Abilities' and Weaknesses' with room for more. No item has both
     kinds, so nothing showed it; found porting to Go. `OvaCalc`'s
     `incorporeal` and `hasIncorporeal`, 2 + its level, warned past +5
     under Combined Effectiveness like Barrier's (`ComputeAlternate`);
     TV takes the best of the three.
   - `OvaCharacter.AdoptDefenses`: one value, where the character has
     an alternate, is read into the best slot (`BestDefense`, the
     earliest on a tie), with a notice only if it isn't that number,
     and `omitAlternates` (was `omitBarrier`) set; two, the Defense and
     the first alternate the character has (Barrier's, or Incorporeal
     Form's without Barrier); three, positional. `OvaSave.Defenses`
     writes one value while `SingleDefense` holds (no override but on
     the slot the value was read into, `singleSlot`), else each the
     character has or that is overridden, in order. An overridden
     Incorporeal Form's the character doesn't have gets Barrier's
     before it, so that it reads back as the third.
   - `OvaWindow` and `OvaLinkedDialog`: an Incorporeal DEFENSE box under
     Barrier's, shown (active) only with Incorporeal Form; it is the
     last number box (10, and 6), so the others keep their indexes.
     The dialog's box ends at 620 of its 640.
   - Fixtures: the Ada repo's `Defenses.yaml` and `Wisp.yaml` (and
     `Sheet.yaml`, now `defense-2`); the generator's own
     `defense-best.yaml` (Acacia's 2/4/4 printed 4), `defense-best-differs`
     (a notice, saved single) and `defense-two` (two of three values,
     saved with all three, so `files.sh` skips it). Nazo now has one
     notice (TV), Shadowman none; Acacia alone, only its END.
   - Shown to fail with eleven bugs planted (no flag, TV or the best
     ignoring Incorporeal Form, `omitAlternates` for Barrier only, the
     second value always Barrier's, the single slot ignored, no
     Barrier's before an absent Incorporeal Form's, the override key
     not advanced, the wrong slot saved, the window's and the dialog's
     boxes): each failed between 1 and 27 checks. Valgrind clean on
     Xvfb.
12. **A narrower window** (asked for by the user, 2026-10-10, to sit
   beside the PDF viewer): 640 wide, not 1280, and four tabs of one
   column each, not two of two. The Character tab's right column, the
   combat box and the numbers, is the new Attacks tab after it
   (`OvaWindow.attacksTab`); the Background tab's right column, the
   portrait, the fluff and the notes, is the new Fluff tab after
   Background (`OvaWindow.fluffTab`, built by `OvaBackground.Build`
   with the Background tab). Every widget kept its place in its column,
   so each `RightX` became `LeftX`, but the combat box, which now has
   the tab's height, shows 17 attacks before it scrolls, not 10. The
   notes' Text label is beside its box, at its top (`AlignLeftTop`); it
   was above it (`AlignLeft + AlignTop` is `AlignTopLeft`), over the
   Header field. Screenshots of each tab under Xvfb
   (Fukiko) showed nothing clipped. `TestWindow` checks the width, the
   tabs' order, and which holds the attacks and the portrait; two bugs
   planted (the attacks, or the fluff, left inside the tab before)
   failed it. Valgrind clean on Xvfb. [done]
13. **Several characters in a file** (asked for by the user, 2026-10-10;
   "Files", "Several characters in a file"). [done]
   - `OvaCharacter`: `Characters`, `ReadEntities`, `FromEntity`,
     `LoadAll`, `One`; `Load` keeps exactly one. `OvaSave`: `SaveAll`,
     `AllToText`, and `Copy` for Duplicate. `OvaCg` opens a file of
     any number.
   - `OvaWindow`: `characters` and `current`; the `Choice` at the menu
     bar's right (the bar 390 wide, the Choice 250); Character > Add,
     Duplicate, Remove..., Move Up, Move Down, Next, Previous, each
     inactive where it can do nothing; `confirm`, a question with its
     own button and Cancel, for Remove; the title's "(N of M)"; Save As
     rebasing every portrait.
   - `TestFiles` round-trips Acacia (one notice, so `files.sh` unmarks
     it), Zurkrieg, Fragment, Options and the new `two-documents.yaml`
     (two `---` documents, saved as one, which ova_fmt_po formats the
     same), and checks their order and notices. `TestWindow` checks
     switching, renaming, adding, duplicating (the copy shares
     nothing), moving, removing, saving all and loading them back, the
     save question, and the menu items' states.
   - Shown to fail with 13 bugs planted (only the first saved, every
     character built from the first, the Choice not following a rename,
     "&" not doubled, Move leaving the shown one behind, only the shown
     portrait rebased, Duplicate sharing the character, Next always
     active, no count in the title, the question not naming the file,
     switching leaving `character` behind, Remove not asking, the first
     shown after Remove): each failed between 1 and 53 checks. Found
     doing so: a planted file put back with its backup's older time
     isn't rebuilt by make, so later runs used the planted binary; the
     plants were run again, each restored file touched, with the same
     results. Valgrind clean on Xvfb.
   - Screenshots under Xvfb (Acacia): the Choice beside the menus, the
     Character menu, the Choice open. FLTK names the keys by their X
     keysyms there: "Ctrl+Next", "Ctrl+Prior".
14. **The Markdown sheet** (asked for by the user, 2026-10-11; "The
   Markdown sheet"). [done]
   - ova_fmt_po: `OvaOut.ToRope` and `TakeRope`, and `TestOut` (5
     checks; shown to fail with `TakeRope` not flushing). Copied here
     with `OvaConfig` and `OvaCommon`.
   - `OvaSave.ToEntity` (what `Copy` did, now its first half);
     `OvaMarkdown` (`Sheet`, `Save`); `OvaMarkdownTab`; the window's
     fifth tab, shown again after every change.
   - `TestFiles` saves each fixture's sheet as `obj/files/NAME.md`
     (deleting the old one first) and checks `Save` failing and then
     working; `files.sh` compares each with `ova_fmt_po -M` of the
     saved copy, and fails for a missing one (54 checks).
     `TestMarkdown` (13 checks): the sheet after a name typed, an
     Ability added, Background text, a file opened; Copy, read back by
     pasting; Save Markdown..., cancelled, failing, unnamed.
     `TestWindow` counts five tabs.
   - Shown to fail with bugs planted: ASCII minus (49 of files.sh's), no
     refresh after typing (1) or Background text (1), Copy putting a
     fragment (1), and no rename after writing, which at first passed:
     `files.sh` skipped missing sheets and the read-back check read an
     old file. Both now delete the file first and `files.sh` fails a
     missing sheet; the plant then failed 55 checks.
   - Screenshot under Xvfb (Ai): the tab, its buttons and the sheet.
15. **A resizable window** (asked for by the user, 2026-10-11: stretch
   proportionately when resized, not stay a static size; "The window").
   [done]
   - `OvaWindow`: the window an extension of `DoubleWindow` whose
     `Resize` starts `fit` when the size changes; `SizeRange(640, 800,
     0, 0)`, the first size the smallest, since the fonts don't shrink.
     `ShowRows` stretches each row by the combat box's size over its
     first. `OvaTraitPanel.Fit` (from `Fill`, which set the widths
     itself before) and `nameW`; `OvaBackground.Fit`, and
     `ShowPortrait` scaling to the box's size, not the constants.
   - `TestResize` (17 checks): the window resized to 960 x 1200 and back
     with `Size` (FLTK calls `Resize`), never shown; the bars' heights,
     the pages, the rows (size, spacing, ROLL box), both names' columns,
     the portrait, a row made again after Remove.
   - Shown to fail with bugs planted: rows not resized (2), no
     `abilities.Fit`/`weaknesses.Fit` (2), no `OvaBackground.Fit` (1),
     the tabs stretching their own bar (1), the window stretching the
     menu bar (2), `fit` never started (5). As in Phase 13, a restored
     file older than the planted build left a planted binary for the
     next run; touched and run again. Valgrind clean on Xvfb.
   - Screenshots under Xvfb (Ai with a portrait), resized with
     `xdotool windowsize` to 960 x 1200, 640 x 800 and 1100 x 1000: the
     Character, Attacks, Fluff and Markdown tabs.

## Testing

- `make test` (no display): `TestRules`, `TestCalc`, `TestFiles`,
  `TestModel`, `TestPaths`, `TestSpawn`, `TestViewer` (on fake viewers and a fake gdbus),
  `test/files.sh`, and a command-line check (`test/cli.sh`).
- `make test-viewers`: `OvaViewer` with the real okular, evince and
  mupdf, on `test/viewer.sh`'s own headless sway and private bus.
- `make test-headless` / `test-sway`: the window tests (`TestWindow`,
  `TestBackground`, `TestLinked`, `TestLimits`),
  never on the desktop (AGENTS.md).
- `make valgrind`: the unit tests and window tests under valgrind, with
  ova_fmt_po's and pofltk's suppressions and pofltk's `vg-check.sh`.
- The oracle for calculations is the sample characters; the oracle for
  files is ova_fmt_po.

## Open questions

None just now.

Decided (2026-10-09; by the user unless it says checked):

- ~~How a file records what `OvaCalc` needs and ova_fmt has no key
  for~~ (found in Phase 2): the attack keys `telekinesis: true` (made
  with Telekinesis, Ai's) and `transformed: true` (made in the
  transformed form, Miho's Mode SP); the combat key `transformed: true`
  (the sheet shown transformed, Fukiko's); and Endurance Use's
  `detail` naming the Ability or attack it is tied to, so it needs no
  key ("Changes to ova_fmt").

- ~~Which Perks and Flaws repeat~~: from each one's text ("Perk and
  Flaw costs"; checked 2026-10-09).
- ~~Fukiko's TV~~: the literal rule, settled by Ai ("Sources and
  findings"; checked 2026-10-09).
- ~~Where the sheet's two parts go~~: two tabs ("The window").
- ~~Fields ova_fmt lacks~~: added to both ova_fmts ("Changes to
  ova_fmt").
- ~~Overriding a computed number~~: an empty entry box beside each
  ("Overriding a computed number").
- ~~Does polibfyaml emit YAML~~: yes, `Fyaml.Document.ToYAML` and
  `ToFile` (`src/Fyaml.Mod`), with `NewDocument` and the `Create*`
  procedures to build it. ova_fmt ignores a key it doesn't know (tried
  on ova_fmt_po), but the new keys are added to it anyway.
- ~~How ova_fmt prints the new keys~~: as proposed: `player` beside the
  name in the header; `appearance` and `other-notes` as text sections
  like `personality` and `notes`; combat `notes` after the combat
  stats; `portrait` as an image in the HTML-in-reST format only;
  `threat-value-half`, `starting-levels` and `half-cost-knowledge` as
  the existing options are; an overridden number (one its mapping's
  `overrides` lists) printed with `*` after it (`ROLL 8*`), in every
  format. In the reST and Markdown formats the `*` is escaped (`\*`),
  so it isn't read as emphasis; the golden files show it.
- ~~No display~~: ova_cg_po needs one for its own window, so with
  neither `DISPLAY` nor `WAYLAND_DISPLAY` set it prints an error and
  exits with status 1, before opening anything ("Starting").
- ~~The viewer through the shell or a C part~~: a C part, `OvaSpawn`,
  from the experiments ("The rulebook viewer", "Findings").
