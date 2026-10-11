# Where the generator's numbers differ from the book's

The rulebook's sample sheets, as ova_fmt's fixtures transcribe them
(`test/data/`, from the Ada ova_fmt's `test-data/`), are the
generator's main check of its rules: loaded, every number a sheet
prints is compared with the one `OvaCalc` computes. This file lists
every number on which they disagree, and why, as far as it can be
told. Page numbers are the book's printed ones.

A file's number that disagrees is kept, as an override, never
replaced. Either the fixture's `overrides:` lists it (a ruling the
book makes on purpose), or loading it gives a notice ("HEALTH is 20 in
the file, 40 by the rules: kept as an override"). `TestFiles` expects
exactly the notices below, for every file the generator can load, and
saving a copy lists them, so a copy loads with none.

po_ova_fmt's own fixtures (Escaping, Unsorted, Vehicle) aren't the
book's, and their numbers were never meant to be the rules'; they are
left out here.

## Sample Characters (p. 23-47)

Every number is the rules', but two the book rules on, which the
fixtures' `overrides:` lists, so they give no notice:

| Character | Number | Book | Rules | Why |
|---|---|---|---|---|
| Braun (p. 31-33) | First Day of Sale Shove!'s ROLL | −2 | 0 | The book's joke attack; a ruling. |
| Natsuki (p. 33-35) | Stiletto Kick's DX | 3 | 6 | A ruling. |

Before the fixtures had `telekinesis` (Ai's attacks) and `transformed`
(Fukiko's combat, Miho's Mode SP), 13 more numbers differed: the book
computes those attacks with Telekinesis and those sheets in the
transformed form (PLAN.md, Phase 3a).

## Sample NPCs (p. 134-141)

Ancel (p. 138), Saspar (p. 135), Zurkrieg (p. 137) and his Men in Black,
and Acacia's two demons (p. 134) match the rules everywhere.

Dr. Tomori (p. 140) and Jiro (p. 141) are Secondary NPCs. They match
once `npc-type` sets the sheet: 20 Health and Endurance, not 40, and TV
4 less (p. 123-124). Without it, each had three notices.

The rest:

| NPC | Number | Book | Rules | Why |
|---|---|---|---|---|
| Acacia (p. 134) | Lock Heaven's Door's END | 10 | 0 | Its Perks are Fatiguing, which costs nothing, and a Unique Perk, whose cost the book doesn't print; 10 would be that Unique Perk's. The fixture leaves its cost out, since ova_fmt would print it and the book doesn't. |
| Acacia | DEFENSE | 4 | 2 | An alternate Defense printed as the only one: 2 + Barrier 2 (p. 51), or 2 + Incorporeal Form 2 (p. 55), which both give 4. |
| Nazo (p. 139) | DEFENSE | 5 | 2 | 2 + Incorporeal Form 3: its dice may be the Defense Roll (p. 55). The generator computes only Barrier's alternate Defense. |
| Nazo | TV | 16 | 15 | Which other Abilities count half toward TV is the GM's choice (p. 124). The generator counts Magic, Witchcraft 3's 2, as it marks Healer and Magic to start with; the book counts one point more. |
| Shadowman (p. 136) | DEFENSE | 6 | 2 | 2 + Barrier 4 (p. 51), printed as the only Defense. The rules give "2/6", which ova_fmt prints as a pair; the generator saves the single value, as the book has it (`OvaCharacter.omitBarrier`). |

Nazo's Fox Fire is made with Telekinesis 2, which adds to its DX (p.
62): its fixture says so (`telekinesis: true`, as Ai's attacks have
it), and its DX of 3 is the rules'.

The Sample NPCs print a single DEFENSE, the best of the character's.
The Sample Characters print Barrier's as a second one (Fukiko's "4/5").

Acacia's file holds three entities, herself and her demons, and so
does Zurkrieg's (two). The generator edits one character at a time
and refuses both. The numbers above come from loading each entity on
its own.

Acacia's three spells (Break, Impede, Wither) cost 10, 10 and 20 in the
book. The generator gave them no cost until it learned that a spell at
−1 to −3 casts a Weakness, as Witchcraft's do, at Arcane Magic's costs
by the Weakness's size (p. 58). Now they match.

## NPC Fragments (p. 142-144)

None has a `combat:` block, so there is nothing to compare.
