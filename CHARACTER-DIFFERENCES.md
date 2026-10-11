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

ova_fmt_po's own fixtures (Escaping, Unsorted, Vehicle) aren't the
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

Ancel (p. 138), Saspar (p. 135), Shadowman (p. 136), Zurkrieg (p. 137)
and his Men in Black, and Acacia's two demons (p. 134) match the rules
everywhere.

Dr. Tomori (p. 140) and Jiro (p. 141) are Secondary NPCs. They match
once `npc-type` sets the sheet: 20 Health and Endurance, not 40, and TV
4 less (p. 123-124). Without it, each had three notices.

The rest:

| NPC | Number | Book | Rules | Why |
|---|---|---|---|---|
| Acacia (p. 134) | Lock Heaven's Door's END | 10 | 0 | Its Perks are Fatiguing, which costs nothing, and a Unique Perk, whose cost the book doesn't print; 10 would be that Unique Perk's. The fixture leaves its cost out, since ova_fmt would print it and the book doesn't. |
| Nazo (p. 139) | TV | 16 | 15 | Which other Abilities count half toward TV is the GM's choice (p. 124). The generator counts Magic, Witchcraft 3's 2, as it marks Healer and Magic to start with; the book counts one point more. |

Nazo's Fox Fire is made with Telekinesis 2, which adds to its DX (p.
62): its fixture says so (`telekinesis: true`, as Ai's attacks have
it), and its DX of 3 is the rules'.

The Sample NPCs print a single DEFENSE, the best of the character's.
The Sample Characters print Barrier's as a second one (Fukiko's
"4/5"). The generator reads a file's single DEFENSE, where Barrier
(p. 51) or Incorporeal Form (p. 55) gives an alternate, as the best of
them, and saves it so (`OvaCharacter.SingleDefense`). Acacia's 4 is
2 + Barrier 2 and 2 + Incorporeal Form 2 (the rules' "2/4/4"), Nazo's
5 is 2 + Incorporeal Form 3 ("2/5"), and Shadowman's 6 is 2 + Barrier
4 ("2/6"), so none gives a notice. Until ova_fmt's `defense` held
three values, the generator computed only Barrier's alternate, and
these were three notices.

Acacia's file holds three entities, herself and her demons, and
Zurkrieg's two, him and his Men in Black. The generator loads every
character of a file (PLAN.md, Phase 13); until then it refused both,
and the numbers above came from loading each entity on its own.

Acacia's three spells (Break, Impede, Wither) cost 10, 10 and 20 in the
book. The generator gave them no cost until it learned that a spell at
−1 to −3 casts a Weakness, as Witchcraft's do, at Arcane Magic's costs
by the Weakness's size (p. 58). Now they match.

## NPC Fragments (p. 142-144)

None has a `combat:` block, so there is nothing to compare.
