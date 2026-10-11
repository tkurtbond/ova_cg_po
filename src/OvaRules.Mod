MODULE OvaRules; (* The rulebook's names, pages and numbers: no descriptions *)

(* PLAN.md, "Data tables" and "The rules the program computes". Every
   Ability, Weakness, Perk and Flaw of the OVA rulebook, in the book's
   order (alphabetical within each kind), with the page it is described
   on and what the calculations need of it; and the rulebook's small
   tables (Tough, Vigorous, Endurance Reserve, Endurance Use, spell
   costs). The rulebook's text stays out (AGENTS.md): to explain an item
   the program opens the book at its page.

   Pages are the book's printed numbers, which are also the PDF's page
   labels; the PDF's page index is the printed page + PdfPageOffset. The
   pages were checked against the PDF by the font of the entries'
   headings (tools/rulebook-headings.py, make check-pages), and pages 79
   and 86 by eye (PLAN.md, Phase 1).

   Imports nothing of the window or the files, so its tests need no
   display. *)

IMPORT Strings;

CONST
  (* Where the NPC types, Heroic, Secondary and Extra (ova_fmt's
     npc-type:), are described: their Health and Endurance; TV's step
     for them is on p. 124. *)
  NpcTypesPage* = 123;

  (* Kinds *)
  Ability* = 0; Weakness* = 1; Perk* = 2; Flaw* = 3;

  NameLength* = 32;  (* the longest name, "Accidental Transformation", is 25 *)
  PdfPageOffset* = 2;  (* PDF page index = printed page + 2 *)

  (* What an Ability or Weakness does to the sheet (flags). Its signed
     level is what it adds: Agile +2 adds 2 dice, Clumsy -2 takes 2. *)
  Agility* = 0;          (* Attack Rolls, but a Will Attack's: Agile, Clumsy (p. 105, 86) *)
  CombatSkill* = 1;      (* Attack Rolls, a Will Attack's too: Combat Expert *)
  Will* = 2;             (* a Will Attack's roll, in Agility's place: Iron-Willed, Weak-Willed *)
  DefenseRoll* = 3;      (* Defense Rolls: Evasive, Quick, Slow (p. 105) *)
  Damage* = 4;           (* the Damage Multiplier: Attack (p. 106) *)
  Strength* = 5;         (* the Damage Multiplier, but a Ranged attack's: Strong, Weak (p. 85) *)
  HealthTable* = 6;      (* Health + the Tough table (p. 63) *)
  HealthTens* = 7;       (* Health - 10 a level: Frail (p. 71) *)
  EnduranceTable* = 8;   (* Endurance + the Vigorous table (p. 65) *)
  EnduranceTens* = 9;    (* Endurance - 10 a level: Languid (p. 73) *)
  Armor* = 10;           (* Armored: in TV (p. 124) *)
  SecondDefense* = 11;   (* a second Defense Roll, 2 + its level: Barrier (p. 51) *)
  Telekinetic* = 12;     (* its level adds to an attack made with it: Telekinesis (p. 62) *)
  HalfTV* = 13;          (* adds half its level to TV unless unmarked: Healer, Magic (p. 124) *)
  NoTV* = 14;            (* never in TV, which is its own: Companion, Minions (p. 124) *)
  HalfCost* = 15;        (* may cost half under the limits: Knowledge, Ineptitude (p. 57) *)
  Reserve* = 16;         (* a separate store of Endurance, 20 a level: Endurance Reserve (p. 53) *)
  CostUp* = 17;          (* raises one Ability's Endurance cost: Endurance Use (p. 70) *)
  OwnCost* = 18;         (* spends Endurance of its own as it is used, so a spell of it
                            costs more than the table's, "10+": Barrier (p. 51, 58) *)

  (* What linked content an Ability has (Item.linked) *)
  NoLink* = 0; Spells* = 1; Form* = 2; Partner* = 3; Machine* = 4;

  (* What a Perk or Flaw does to an attack's numbers (flags) *)
  RollEach* = 20;        (* +1 die a time (Accurate), or -1 (Inaccurate) *)
  DamageEach* = 21;      (* +1 DX a time (Effective), or -1 (Ineffective) *)
  RangedAttack* = 22;    (* drops Strong and Weak (Ranged, p. 85) *)
  StrengthRanged* = 23;  (* keeps them (Ranged, Strength-Powered, p. 86) *)
  WillAttack* = 24;      (* Iron-Willed and Weak-Willed for Agile and Clumsy (p. 86) *)
  NoDamageDone* = 25;    (* DX 0 (No Damage, p. 88) *)

  (* How a Perk's or Flaw's cost is set (Item.costKind) *)
  FixedCost* = 0;  (* cost, each time it is taken *)
  RangeCost* = 1;  (* chosen from minCost..maxCost, in steps of 5 (Cancel, Requirement) *)
  UserCost* = 2;   (* any the user and GM agree on (Unique Perk, Unique Flaw) *)

  Unlimited* = MAX(INTEGER);  (* Item.maxTimes of a Perk or Flaw taken as often as wanted *)

  (* Pages of the rules themselves, for the window's "?" buttons *)
  LimitsPage* = 21;          (* Limiting the Character *)
  PerksFlawsPage* = 83;      (* Ability Perks and Flaws: how they cost *)
  AffinitiesPage* = 89;
  QuickListPage* = 90;
  SpellCostPage* = 58;       (* the Spell Endurance Cost table *)
  RollsPage* = 105;          (* Attack and Defense Rolls *)
  DamagePage* = 106;
  HealthEndurancePage* = 107;
  ThreatValuePage* = 124;

  MaxItems = 200;

TYPE
  Name* = ARRAY NameLength OF CHAR;
  Item* = POINTER TO ItemDesc;
  ItemDesc* = RECORD
    name-: Name;
    kind-, page-: INTEGER;
    flags-: SET;
    linked-: INTEGER;  (* an Ability's linked content: NoLink, Spells, ... *)
    (* A Perk's or Flaw's Endurance cost, each time it is taken (negative
       for a Flaw); for a RangeCost one, minCost..maxCost; and how often
       it may be taken. *)
    costKind-, cost-, minCost-, maxCost-, maxTimes-: INTEGER
  END;

VAR
  items: ARRAY MaxItems OF Item;
  nItems: INTEGER;
  first, count: ARRAY 4 OF INTEGER;  (* each kind's span of items *)
  (* Other names an item is found by: the Quick List's abbreviation, and
     the name without its parenthesis. *)
  aliases: ARRAY 4 OF RECORD alias: Name; item: Item END;
  nAliases: INTEGER;
  spellCost: ARRAY 5, 5 OF INTEGER;  (* [magic - 1, ability - 1] *)

(* ---- Text ---- *)

(* c in lower case, ASCII only: names are ASCII. *)
PROCEDURE Lower(c: CHAR): CHAR;
BEGIN
  IF (c >= "A") & (c <= "Z") THEN RETURN CHR(ORD(c) + 32) ELSE RETURN c END
END Lower;

(* a = b, ignoring ASCII case. *)
PROCEDURE SameName(a, b: ARRAY OF CHAR): BOOLEAN;
  VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < LEN(a)) & (i < LEN(b)) & (a[i] # 0X) & (Lower(a[i]) = Lower(b[i])) DO INC(i) END;
  RETURN ((i = LEN(a)) OR (a[i] = 0X)) & ((i = LEN(b)) OR (b[i] = 0X))
END SameName;

(* n >= 0 in decimal, appended to s. *)
PROCEDURE AppendInt(n: INTEGER; VAR s: ARRAY OF CHAR);
  VAR d: ARRAY 12 OF CHAR; i: INTEGER; c: ARRAY 2 OF CHAR;
BEGIN
  ASSERT(n >= 0);
  i := 0; REPEAT d[i] := CHR(ORD("0") + n MOD 10); n := n DIV 10; INC(i) UNTIL n = 0;
  c[1] := 0X;
  WHILE i > 0 DO DEC(i); c[0] := d[i]; Strings.Append(c, s) END
END AppendInt;

(* ---- The tables ---- *)

PROCEDURE New(name: ARRAY OF CHAR; kind, page: INTEGER; flags: SET): Item;
  VAR it: Item;
BEGIN
  ASSERT(nItems < MaxItems); ASSERT(Strings.Length(name) < NameLength);
  NEW(it); COPY(name, it.name); it.kind := kind; it.page := page; it.flags := flags;
  it.linked := NoLink; it.costKind := FixedCost; it.cost := 0; it.minCost := 0; it.maxCost := 0; it.maxTimes := 1;
  IF count[kind] = 0 THEN first[kind] := nItems END;
  INC(count[kind]);
  items[nItems] := it; INC(nItems);
  RETURN it
END New;

PROCEDURE A(name: ARRAY OF CHAR; page: INTEGER; flags: SET);
  VAR it: Item;
BEGIN it := New(name, Ability, page, flags)
END A;

PROCEDURE L(name: ARRAY OF CHAR; page: INTEGER; flags: SET; linked: INTEGER);
  VAR it: Item;
BEGIN it := New(name, Ability, page, flags); it.linked := linked
END L;

PROCEDURE W(name: ARRAY OF CHAR; page: INTEGER; flags: SET);
  VAR it: Item;
BEGIN it := New(name, Weakness, page, flags)
END W;

(* A Perk or Flaw of fixed cost, taken at most maxTimes. *)
PROCEDURE PF(name: ARRAY OF CHAR; kind, page, cost, maxTimes: INTEGER; flags: SET);
  VAR it: Item;
BEGIN it := New(name, kind, page, flags); it.cost := cost; it.maxTimes := maxTimes
END PF;

PROCEDURE RangeFlaw(name: ARRAY OF CHAR; page, min, max: INTEGER);
  VAR it: Item;
BEGIN it := New(name, Flaw, page, {}); it.costKind := RangeCost; it.minCost := min; it.maxCost := max
END RangeFlaw;

PROCEDURE Unique(name: ARRAY OF CHAR; kind, page: INTEGER);
  VAR it: Item;
BEGIN it := New(name, kind, page, {}); it.costKind := UserCost
END Unique;

PROCEDURE Alias(alias, name: ARRAY OF CHAR);
  VAR i: INTEGER;
BEGIN
  i := 0; WHILE (i < nItems) & (items[i].name # name) DO INC(i) END;
  ASSERT(i < nItems);
  COPY(alias, aliases[nAliases].alias); aliases[nAliases].item := items[i]; INC(nAliases)
END Alias;

PROCEDURE Abilities;
BEGIN
  A("Agile", 49, {Agility});
  A("Armored", 49, {Armor});
  A("Art of Invisibility", 50, {});
  A("Attack", 50, {Damage});
  A("Barrier", 51, {SecondDefense, OwnCost});
  A("Beautiful", 51, {});
  A("Charismatic", 51, {});
  A("Combat Expert", 51, {CombatSkill});
  L("Companion", 52, {NoTV}, Partner);
  A("Connected", 52, {});
  A("Cute!", 52, {});
  A("Dexterous", 52, {});
  A("Dimensional Pocket", 52, {});
  A("Endurance Reserve", 53, {Reserve});
  A("Evasive", 53, {DefenseRoll});
  A("Famous", 53, {});
  A("Flight", 54, {});
  A("Gear", 54, {});
  A("Healer", 54, {HalfTV});
  A("Heightened Sense", 54, {});
  A("Illusionist", 54, {});
  A("Incorporeal Form", 55, {});
  A("Intimidating", 55, {});
  A("Intuitive", 56, {});
  A("Inventor", 56, {});
  A("Invisibility", 56, {});
  A("Iron-Willed", 56, {Will});
  A("Knowledge", 57, {HalfCost});
  A("Life Support", 57, {});
  A("Lucky", 57, {});
  L("Magic, Arcane", 57, {HalfTV}, Spells);
  L("Magic, Witchcraft", 58, {HalfTV}, Spells);
  A("Minions", 58, {NoTV});
  A("Passion", 59, {});
  A("Perceptive", 59, {});
  A("Performer", 59, {});
  A("Pilot", 59, {});
  A("Position of Power", 59, {});
  A("Psychic", 59, {});
  A("Quick", 60, {DefenseRoll});
  A("Resistance", 60, {});
  A("Shape-Shifter", 60, {});
  A("Sixth Sense", 61, {});
  A("Smart", 61, {});
  A("Spirit Medium", 61, {});
  A("Strong", 62, {Strength});
  A("Telekinesis", 62, {Telekinetic});
  A("Teleport", 62, {});
  A("Time Freeze", 63, {});
  A("Tough", 63, {HealthTable});
  L("Transformation", 63, {}, Form);
  A("Unique Ability", 64, {});
  L("Vehicle (Mecha)", 64, {}, Machine);
  A("Vigorous", 65, {EnduranceTable});
  A("Walking Arsenal", 65, {});
  A("Wealthy", 65, {})
END Abilities;

PROCEDURE Weaknesses;
BEGIN
  W("Absent-Minded", 66, {});
  W("Accidental Transformation", 66, {});
  W("Ageism", 66, {});
  W("Airhead", 66, {});
  W("Amnesia", 67, {});
  W("Arrogant", 67, {});
  W("Awkward Size", 67, {});
  W("Bizarre Appearance", 68, {});
  W("Clumsy", 68, {Agility});
  W("Code of Conduct", 68, {});
  W("Compulsion", 69, {});
  W("Coward", 69, {});
  W("Crybaby", 69, {});
  W("Dense", 69, {});
  W("Dependency", 70, {});
  W("Dull", 70, {});
  W("Easily Distracted", 70, {});
  W("Emotionless", 70, {});
  W("Endurance Use", 70, {CostUp});
  W("Fear", 70, {});
  W("Focus", 71, {});
  W("Frail", 71, {HealthTens});
  W("Fussy", 71, {});
  W("Greedy", 71, {});
  W("Guardian", 72, {});
  W("Hatred", 72, {});
  W("Impaired Sense", 72, {});
  W("Impulsive", 72, {});
  W("Ineptitude", 72, {HalfCost});
  W("Infamous", 73, {});
  W("Jittery", 73, {});
  W("Kind-Hearted", 73, {});
  W("Languid", 73, {EnduranceTens});
  W("Lecherous", 73, {});
  W("Limited Uses", 74, {});
  W("Loner", 74, {});
  W("Love Interest", 74, {});
  W("Love Magnet", 75, {});
  W("Mute", 75, {});
  W("Naive", 75, {});
  W("Nosebleeder", 75, {});
  W("Oblivious", 76, {});
  W("Obsession", 76, {});
  W("Outcast", 76, {});
  W("Overconfident", 76, {});
  W("Pacifist", 77, {});
  W("Poor", 77, {});
  W("Quirk", 77, {});
  W("Restricted Freedom", 77, {});
  W("Rival", 77, {});
  W("Room for Two", 78, {});
  W("Rude", 78, {});
  W("Secret", 78, {});
  W("Sensitivity", 78, {});
  W("Servitude", 78, {});
  W("Short-Tempered", 79, {});
  W("Shy", 80, {});
  W("Slow", 80, {DefenseRoll});
  W("Soft Spot", 80, {});
  W("Split Personality", 80, {});
  W("Stubborn", 80, {});
  W("Suppressed Power", 81, {});
  W("Trigger", 81, {});
  W("Unique Weakness", 81, {});
  W("Unlucky", 81, {});
  W("Vulnerability", 82, {});
  W("Wanted", 82, {});
  W("Weak", 82, {Strength});
  W("Weak-Willed", 82, {Will})
END Weaknesses;

(* Costs from the Quick List (p. 90) and the headings; how often each
   may be taken from its own text (PLAN.md, "Perk and Flaw costs"). *)
PROCEDURE PerksAndFlaws;
BEGIN
  PF("Accurate", Perk, 83, 5, Unlimited, {RollEach});
  PF("Area Effect", Perk, 83, 10, Unlimited, {});
  PF("Armor Piercing", Perk, 83, 5, Unlimited, {});
  PF("Barrier Buster", Perk, 83, 5, 1, {});
  PF("Blinding", Perk, 84, 20, 1, {});
  PF("Continued Effect", Perk, 84, 10, 2, {});
  PF("Defensive", Perk, 84, 5, Unlimited, {});
  PF("Disarming", Perk, 84, 10, 1, {});
  PF("Effective", Perk, 84, 5, Unlimited, {DamageEach});
  PF("Fatiguing", Perk, 84, 0, 1, {});
  PF("Impairing", Perk, 85, 10, 1, {});
  PF("Multiple Targets", Perk, 85, 10, Unlimited, {});
  PF("No Gesture", Perk, 85, 5, 1, {});
  PF("Overwhelming", Perk, 85, 15, 1, {});
  PF("Paralyzing", Perk, 85, 10, 2, {});
  PF("Ranged", Perk, 85, 0, 1, {RangedAttack});
  PF("Ranged, Strength-Powered", Perk, 86, 5, 1, {StrengthRanged});
  PF("Reach", Perk, 86, 5, Unlimited, {});
  PF("Redirectable", Perk, 86, 5, 1, {});
  PF("Strike Through", Perk, 86, 5, 1, {});
  PF("Stunning", Perk, 86, 10, 1, {});
  PF("Trap", Perk, 86, 5, 1, {});
  Unique("Unique Perk", Perk, 86);
  PF("Vampire", Perk, 86, 5, Unlimited, {});
  PF("Will Attack", Perk, 86, 0, 1, {WillAttack});

  PF("Activation", Flaw, 87, -10, 1, {});
  PF("Ammunition", Flaw, 87, -5, 3, {});
  PF("Assisted", Flaw, 87, -15, Unlimited, {});
  PF("Backlash", Flaw, 87, -5, Unlimited, {});
  PF("Break", Flaw, 87, -10, 1, {});
  PF("Buildup", Flaw, 87, -5, Unlimited, {});
  RangeFlaw("Cancel", 87, -20, 0);
  PF("Concentration", Flaw, 87, -20, Unlimited, {});
  PF("Delayed", Flaw, 88, -5, 1, {});
  PF("Elaborate Gestures", Flaw, 88, -5, 1, {});
  PF("Feather Blow", Flaw, 88, -5, 1, {});
  PF("Finisher", Flaw, 88, -10, 1, {});
  PF("Inaccurate", Flaw, 88, -5, Unlimited, {RollEach});
  PF("Ineffective", Flaw, 88, -5, Unlimited, {DamageEach});
  PF("Low Penetration", Flaw, 88, -5, Unlimited, {});
  PF("No Damage", Flaw, 88, -20, 1, {NoDamageDone});
  PF("Open to Attack", Flaw, 88, -25, 1, {});
  PF("Recoil", Flaw, 88, -10, 1, {});
  RangeFlaw("Requirement", 88, -20, -5);
  PF("Self-Only", Flaw, 88, -5, 1, {});
  Unique("Unique Flaw", Flaw, 88);
  PF("Unwieldy", Flaw, 89, -5, Unlimited, {});
  PF("Weapon", Flaw, 89, -5, 1, {})
END PerksAndFlaws;

(* ---- Finding items ---- *)

(* How many items of a kind there are. *)
PROCEDURE Count*(kind: INTEGER): INTEGER;
BEGIN RETURN count[kind]
END Count;

(* The i'th item of a kind, 0 <= i < Count(kind), in the book's order. *)
PROCEDURE Get*(kind, i: INTEGER): Item;
BEGIN ASSERT((i >= 0) & (i < count[kind])); RETURN items[first[kind] + i]
END Get;

(* The item named name, ignoring case, or by an alias ("Vehicle" for
   "Vehicle (Mecha)"); NIL if there is none. Names are unique across the
   four kinds. *)
PROCEDURE Find*(name: ARRAY OF CHAR): Item;
  VAR i: INTEGER;
BEGIN
  FOR i := 0 TO nItems - 1 DO
    IF SameName(items[i].name, name) THEN RETURN items[i] END
  END;
  FOR i := 0 TO nAliases - 1 DO
    IF SameName(aliases[i].alias, name) THEN RETURN aliases[i].item END
  END;
  RETURN NIL
END Find;

(* ---- What the window shows (PLAN.md, "Page numbers beside names") ---- *)

(* "p. 50"; "p. ?" for NIL, an item the tables don't have. *)
PROCEDURE PageText*(it: Item; VAR s: ARRAY OF CHAR);
BEGIN
  COPY("p. ", s);
  IF it = NIL THEN Strings.Append("?", s) ELSE AppendInt(it.page, s) END
END PageText;

(* "Attack (p. 50)": an item's name with its page, as every name is shown. *)
PROCEDURE Label*(it: Item; VAR s: ARRAY OF CHAR);
  VAR p: ARRAY 16 OF CHAR;
BEGIN
  COPY(it.name, s); PageText(it, p);
  Strings.Append(" (", s); Strings.Append(p, s); Strings.Append(")", s)
END Label;

(* "Secondary (p. 123)": a name that isn't one of the items', with the
   page it is described on. *)
PROCEDURE PageLabel*(name: ARRAY OF CHAR; page: INTEGER; VAR s: ARRAY OF CHAR);
BEGIN
  COPY(name, s); Strings.Append(" (p. ", s); AppendInt(page, s); Strings.Append(")", s)
END PageLabel;

(* name's label, as written, if the tables have it: "Magic, Testing
   (p. ?)" if they don't. *)
PROCEDURE LabelOf*(name: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
  VAR it: Item; p: ARRAY 16 OF CHAR;
BEGIN
  it := Find(name);
  IF it # NIL THEN Label(it, s)
  ELSE COPY(name, s); PageText(NIL, p); Strings.Append(" (", s); Strings.Append(p, s); Strings.Append(")", s)
  END
END LabelOf;

(* The PDF's page index of a printed page. *)
PROCEDURE PdfIndex*(page: INTEGER): INTEGER;
BEGIN RETURN page + PdfPageOffset
END PdfIndex;

(* ---- The rulebook's small tables ---- *)

(* Tough's bonus to Health (p. 63), and Vigorous's to Endurance (p. 65),
   the same table: 10, 20, 30, 40, 60 for +1 to +5; 0 for 0. *)
PROCEDURE ToughBonus*(level: INTEGER): INTEGER;
BEGIN
  ASSERT((level >= 0) & (level <= 5));
  IF level = 5 THEN RETURN 60 ELSE RETURN 10 * level END
END ToughBonus;

(* Endurance Reserve's store (p. 53): 20 a level. *)
PROCEDURE ReserveBonus*(level: INTEGER): INTEGER;
BEGIN ASSERT((level >= 0) & (level <= 5)); RETURN 20 * level
END ReserveBonus;

(* What Endurance Use adds to an Ability's cost (p. 70): 5, 10, 20 at
   -1, -2, -3; 0 at 0. *)
PROCEDURE EnduranceUseCost*(level: INTEGER): INTEGER;
BEGIN
  ASSERT((level <= 0) & (level >= -3));
  CASE -level OF 0: RETURN 0 | 1: RETURN 5 | 2: RETURN 10 | 3: RETURN 20 END
END EnduranceUseCost;

(* The Spell Endurance Cost table (p. 58): casting a spell that mimics an
   Ability of level ability, at Magic level magic, both 1..5. *)
PROCEDURE SpellCost*(magic, ability: INTEGER): INTEGER;
BEGIN
  ASSERT((magic >= 1) & (magic <= 5) & (ability >= 1) & (ability <= 5));
  RETURN spellCost[magic - 1, ability - 1]
END SpellCost;

(* Row magic of the spell cost table, for Abilities of level 1 to 5. *)
PROCEDURE SpellRow(magic, a1, a2, a3, a4, a5: INTEGER);
BEGIN
  spellCost[magic - 1, 0] := a1; spellCost[magic - 1, 1] := a2; spellCost[magic - 1, 2] := a3;
  spellCost[magic - 1, 3] := a4; spellCost[magic - 1, 4] := a5
END SpellRow;

BEGIN
  nItems := 0; nAliases := 0;
  count[Ability] := 0; count[Weakness] := 0; count[Perk] := 0; count[Flaw] := 0;
  Abilities; Weaknesses; PerksAndFlaws;
  SpellRow(1, 20, 30, 40, 50, 60);
  SpellRow(2, 10, 20, 30, 40, 50);
  SpellRow(3, 5, 10, 20, 30, 40);
  SpellRow(4, 2, 5, 10, 20, 30);
  SpellRow(5, 0, 2, 5, 10, 20);
  Alias("Vehicle", "Vehicle (Mecha)");
  Alias("Ranged, Str.-Powered", "Ranged, Strength-Powered")  (* the Quick List's (p. 90) *)
END OvaRules.
