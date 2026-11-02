MODULE TestRules; (* OvaRules: the tables against the rulebook's Quick List, labels, small tables *)

(* The Quick List (p. 90) is a source independent of the entries'
   headings, from which OvaRules' pages were taken: every name on it must
   be in OvaRules, of the same kind, at the same place in the book's
   order, with the cost it gives. Its entries below were generated from
   the PDF's text of p. 90 (PLAN.md, Phase 1), not typed. Needs no
   display. *)

IMPORT Check, OvaRules, Out, Strings;

VAR
  next: ARRAY 4 OF INTEGER;  (* the Quick List's place in each kind *)
  quickOk: BOOLEAN;
  label: ARRAY 64 OF CHAR;

(* One Quick List entry: kind, name, and for a Perk or Flaw how its cost
   is given and the cost (min, max for a range). *)
PROCEDURE Q(kind: INTEGER; name: ARRAY OF CHAR; costKind, cost, max: INTEGER);
  VAR it: OvaRules.Item; ok: BOOLEAN;
BEGIN
  it := OvaRules.Find(name);
  ok := (it # NIL) & (it.kind = kind) & (next[kind] < OvaRules.Count(kind))
    & (OvaRules.Get(kind, next[kind]) = it);
  IF ok & (kind >= OvaRules.Perk) THEN
    ok := it.costKind = costKind;
    IF ok & (costKind = OvaRules.FixedCost) THEN ok := it.cost = cost
    ELSIF ok & (costKind = OvaRules.RangeCost) THEN ok := (it.minCost = cost) & (it.maxCost = max)
    END
  END;
  IF ~ok THEN Out.String("    the Quick List's "); Out.String(name); Out.String(" doesn't match"); Out.Ln END;
  quickOk := quickOk & ok;
  INC(next[kind])
END Q;

PROCEDURE QuickList;
BEGIN
  (* Abilities *)
  Q(OvaRules.Ability, "Agile", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Armored", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Art of Invisibility", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Attack", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Barrier", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Beautiful", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Charismatic", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Combat Expert", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Companion", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Connected", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Cute!", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Dexterous", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Dimensional Pocket", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Endurance Reserve", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Evasive", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Famous", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Flight", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Gear", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Healer", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Heightened Sense", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Illusionist", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Incorporeal Form", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Intimidating", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Intuitive", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Inventor", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Invisibility", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Iron-Willed", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Knowledge", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Life Support", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Lucky", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Magic, Arcane", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Magic, Witchcraft", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Minions", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Passion", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Perceptive", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Performer", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Pilot", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Position of Power", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Psychic", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Quick", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Resistance", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Shape-Shifter", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Sixth Sense", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Smart", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Spirit Medium", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Strong", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Telekinesis", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Teleport", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Time Freeze", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Tough", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Transformation", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Unique Ability", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Vehicle (Mecha)", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Vigorous", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Walking Arsenal", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Ability, "Wealthy", OvaRules.FixedCost, 0, 0);
  (* Weaknesses *)
  Q(OvaRules.Weakness, "Absent-Minded", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Accidental Transformation", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Ageism", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Airhead", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Amnesia", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Arrogant", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Awkward Size", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Bizarre Appearance", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Clumsy", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Code of Conduct", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Compulsion", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Coward", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Crybaby", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Dense", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Dependency", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Dull", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Easily Distracted", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Emotionless", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Endurance Use", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Fear", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Focus", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Frail", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Fussy", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Greedy", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Guardian", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Hatred", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Impaired Sense", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Impulsive", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Ineptitude", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Infamous", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Jittery", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Kind-Hearted", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Languid", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Lecherous", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Limited Uses", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Loner", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Love Interest", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Love Magnet", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Mute", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Naive", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Nosebleeder", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Oblivious", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Obsession", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Outcast", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Overconfident", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Pacifist", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Poor", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Quirk", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Restricted Freedom", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Rival", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Room for Two", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Rude", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Secret", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Sensitivity", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Servitude", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Short-Tempered", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Shy", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Slow", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Soft Spot", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Split Personality", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Stubborn", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Suppressed Power", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Trigger", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Unique Weakness", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Unlucky", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Vulnerability", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Wanted", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Weak", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Weakness, "Weak-Willed", OvaRules.FixedCost, 0, 0);
  (* Perks *)
  Q(OvaRules.Perk, "Accurate", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Area Effect", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "Armor Piercing", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Barrier Buster", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Blinding", OvaRules.FixedCost, 20, 0);
  Q(OvaRules.Perk, "Continued Effect", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "Defensive", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Disarming", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "Effective", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Fatiguing", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Perk, "Impairing", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "Multiple Targets", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "No Gesture", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Overwhelming", OvaRules.FixedCost, 15, 0);
  Q(OvaRules.Perk, "Paralyzing", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "Ranged", OvaRules.FixedCost, 0, 0);
  Q(OvaRules.Perk, "Ranged, Str.-Powered", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Reach", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Redirectable", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Strike Through", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Stunning", OvaRules.FixedCost, 10, 0);
  Q(OvaRules.Perk, "Trap", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Unique Perk", OvaRules.UserCost, 0, 0);
  Q(OvaRules.Perk, "Vampire", OvaRules.FixedCost, 5, 0);
  Q(OvaRules.Perk, "Will Attack", OvaRules.FixedCost, 0, 0);
  (* Flaws *)
  Q(OvaRules.Flaw, "Activation", OvaRules.FixedCost, -10, 0);
  Q(OvaRules.Flaw, "Ammunition", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Assisted", OvaRules.FixedCost, -15, 0);
  Q(OvaRules.Flaw, "Backlash", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Break", OvaRules.FixedCost, -10, 0);
  Q(OvaRules.Flaw, "Buildup", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Cancel", OvaRules.RangeCost, -20, 0);
  Q(OvaRules.Flaw, "Concentration", OvaRules.FixedCost, -20, 0);
  Q(OvaRules.Flaw, "Delayed", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Elaborate Gestures", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Feather Blow", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Finisher", OvaRules.FixedCost, -10, 0);
  Q(OvaRules.Flaw, "Inaccurate", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Ineffective", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Low Penetration", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "No Damage", OvaRules.FixedCost, -20, 0);
  Q(OvaRules.Flaw, "Open to Attack", OvaRules.FixedCost, -25, 0);
  Q(OvaRules.Flaw, "Recoil", OvaRules.FixedCost, -10, 0);
  Q(OvaRules.Flaw, "Requirement", OvaRules.RangeCost, -20, -5);
  Q(OvaRules.Flaw, "Self-Only", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Unique Flaw", OvaRules.UserCost, 0, 0);
  Q(OvaRules.Flaw, "Unwieldy", OvaRules.FixedCost, -5, 0);
  Q(OvaRules.Flaw, "Weapon", OvaRules.FixedCost, -5, 0);
END QuickList;

PROCEDURE TestQuickList;
  VAR k: INTEGER;
BEGIN
  FOR k := 0 TO 3 DO next[k] := 0 END;
  quickOk := TRUE;
  QuickList;
  Check.Check(quickOk, "every Quick List name: found, of its kind, in the book's order, at its cost");
  Check.Check((next[OvaRules.Ability] = OvaRules.Count(OvaRules.Ability))
    & (next[OvaRules.Weakness] = OvaRules.Count(OvaRules.Weakness))
    & (next[OvaRules.Perk] = OvaRules.Count(OvaRules.Perk))
    & (next[OvaRules.Flaw] = OvaRules.Count(OvaRules.Flaw)), "nothing beyond the Quick List");
  Check.Check((OvaRules.Count(OvaRules.Ability) = 56) & (OvaRules.Count(OvaRules.Weakness) = 69)
    & (OvaRules.Count(OvaRules.Perk) = 25) & (OvaRules.Count(OvaRules.Flaw) = 23),
    "56 Abilities, 69 Weaknesses, 25 Perks, 23 Flaws")
END TestQuickList;

(* Each kind's pages lie within its part of the chapter and never go
   back, since the book lists each kind alphabetically. *)
PROCEDURE PagesIn(kind, from, to: INTEGER): BOOLEAN;
  VAR i, last: INTEGER; it: OvaRules.Item; ok: BOOLEAN;
BEGIN
  ok := TRUE; last := from;
  FOR i := 0 TO OvaRules.Count(kind) - 1 DO
    it := OvaRules.Get(kind, i);
    ok := ok & (it.page >= last) & (it.page <= to); last := it.page
  END;
  it := OvaRules.Get(kind, 0); ok := ok & (it.page = from);
  it := OvaRules.Get(kind, OvaRules.Count(kind) - 1);
  RETURN ok & (it.page = to)
END PagesIn;

PROCEDURE PageIs(name: ARRAY OF CHAR; page: INTEGER): BOOLEAN;
  VAR it: OvaRules.Item;
BEGIN it := OvaRules.Find(name); RETURN (it # NIL) & (it.page = page)
END PageIs;

PROCEDURE TestPages;
BEGIN
  Check.Check(PagesIn(OvaRules.Ability, 49, 65), "Abilities on pp. 49-65, in order");
  Check.Check(PagesIn(OvaRules.Weakness, 66, 82), "Weaknesses on pp. 66-82, in order");
  Check.Check(PagesIn(OvaRules.Perk, 83, 86), "Perks on pp. 83-86, in order");
  Check.Check(PagesIn(OvaRules.Flaw, 87, 89), "Flaws on pp. 87-89, in order");
  Check.Check(PageIs("Attack", 50) & PageIs("Short-Tempered", 79) & PageIs("Weapon", 89)
    & PageIs("Ammunition", 87) & PageIs("Ranged, Strength-Powered", 86), "pages checked by eye and by hand");
  Check.Check(OvaRules.PdfIndex(50) = 52, "the PDF's page index is the printed page + 2")
END TestPages;

(* How often the item called name may be taken; -1 if there's none. *)
PROCEDURE MaxTimes(name: ARRAY OF CHAR): INTEGER;
  VAR it: OvaRules.Item;
BEGIN it := OvaRules.Find(name); IF it = NIL THEN RETURN -1 ELSE RETURN it.maxTimes END
END MaxTimes;

(* The linked content of the item called name; -1 if there's none. *)
PROCEDURE Linked(name: ARRAY OF CHAR): INTEGER;
  VAR it: OvaRules.Item;
BEGIN it := OvaRules.Find(name); IF it = NIL THEN RETURN -1 ELSE RETURN it.linked END
END Linked;

(* How often a Perk or Flaw may be taken (PLAN.md, "Perk and Flaw costs"). *)
PROCEDURE TestRepeats;
  VAR k, i, unlimited, two, three, once: INTEGER; it: OvaRules.Item;
BEGIN
  unlimited := 0; two := 0; three := 0; once := 0;
  FOR k := OvaRules.Perk TO OvaRules.Flaw DO
    FOR i := 0 TO OvaRules.Count(k) - 1 DO
      it := OvaRules.Get(k, i);
      IF it.maxTimes = OvaRules.Unlimited THEN INC(unlimited)
      ELSIF it.maxTimes = 2 THEN INC(two)
      ELSIF it.maxTimes = 3 THEN INC(three)
      ELSIF it.maxTimes = 1 THEN INC(once)
      END
    END
  END;
  Check.Check((unlimited = 16) & (two = 2) & (three = 1) & (once = 29),
    "16 repeat freely, 2 at most twice, 1 at most three times, 29 once");
  Check.Check((MaxTimes("Continued Effect") = 2) & (MaxTimes("Paralyzing") = 2)
    & (MaxTimes("Ammunition") = 3), "the limited ones: Continued Effect, Paralyzing, Ammunition");
  Check.Check((MaxTimes("Low Penetration") = OvaRules.Unlimited)
    & (MaxTimes("Assisted") = OvaRules.Unlimited)
    & (MaxTimes("Effective") = OvaRules.Unlimited), "Low Penetration, Assisted, Effective repeat");
  Check.Check((MaxTimes("Cancel") = 1) & (MaxTimes("Requirement") = 1)
    & (MaxTimes("Unique Perk") = 1), "Cancel, Requirement, Unique Perk are taken once")
END TestRepeats;

PROCEDURE TestFind;
  VAR it: OvaRules.Item;
BEGIN
  it := OvaRules.Find("attack");
  Check.Check((it # NIL) & (it.name = "Attack"), "Find ignores case");
  it := OvaRules.Find("Vehicle");
  Check.Check((it # NIL) & (it.name = "Vehicle (Mecha)"), "Find: Vehicle is Vehicle (Mecha)");
  it := OvaRules.Find("ranged, str.-powered");
  Check.Check((it # NIL) & (it.name = "Ranged, Strength-Powered"), "Find: the Quick List's Ranged, Str.-Powered");
  Check.Check((OvaRules.Find("Magic, Testing") = NIL) & (OvaRules.Find("") = NIL)
    & (OvaRules.Find("Attac") = NIL) & (OvaRules.Find("Attacks") = NIL), "Find: no near misses")
END TestFind;

PROCEDURE TestLabels;
  VAR i, k, n: INTEGER; ok: BOOLEAN; s: ARRAY 64 OF CHAR;
BEGIN
  OvaRules.Label(OvaRules.Find("Attack"), label);
  Check.Check(label = "Attack (p. 50)", "Label: Attack (p. 50)");
  OvaRules.PageText(OvaRules.Find("Attack"), label);
  Check.Check(label = "p. 50", "PageText: p. 50");
  OvaRules.PageText(NIL, label);
  Check.Check(label = "p. ?", "PageText of an unknown item: p. ?");
  OvaRules.LabelOf("Magic, Testing", label);
  Check.Check(label = "Magic, Testing (p. ?)", "LabelOf an unknown name keeps it, with p. ?");
  OvaRules.LabelOf("vehicle", label);
  Check.Check(label = "Vehicle (Mecha) (p. 64)", "LabelOf a known name gives the book's name");
  ok := TRUE;
  FOR k := 0 TO 3 DO
    FOR i := 0 TO OvaRules.Count(k) - 1 DO
      OvaRules.Label(OvaRules.Get(k, i), s);
      n := Strings.Length(s);
      ok := ok & (n > 0) & (n < LEN(s) - 1) & (s[n - 1] = ")")  (* not cut short *)
    END
  END;
  Check.Check(ok, "every label fits 64 characters")
END TestLabels;

PROCEDURE TestTables;
  VAR ok: BOOLEAN;
  PROCEDURE Row(m, a, b, c, d, e: INTEGER): BOOLEAN;
  BEGIN
    RETURN (OvaRules.SpellCost(m, 1) = a) & (OvaRules.SpellCost(m, 2) = b) & (OvaRules.SpellCost(m, 3) = c)
      & (OvaRules.SpellCost(m, 4) = d) & (OvaRules.SpellCost(m, 5) = e)
  END Row;
BEGIN
  Check.Check((OvaRules.ToughBonus(0) = 0) & (OvaRules.ToughBonus(1) = 10) & (OvaRules.ToughBonus(4) = 40)
    & (OvaRules.ToughBonus(5) = 60), "Tough and Vigorous: 10, 20, 30, 40, 60");
  Check.Check((OvaRules.ReserveBonus(1) = 20) & (OvaRules.ReserveBonus(5) = 100), "Endurance Reserve: 20 a level");
  Check.Check((OvaRules.EnduranceUseCost(0) = 0) & (OvaRules.EnduranceUseCost(-1) = 5)
    & (OvaRules.EnduranceUseCost(-2) = 10) & (OvaRules.EnduranceUseCost(-3) = 20), "Endurance Use: 5, 10, 20");
  ok := Row(1, 20, 30, 40, 50, 60) & Row(2, 10, 20, 30, 40, 50) & Row(3, 5, 10, 20, 30, 40)
    & Row(4, 2, 5, 10, 20, 30) & Row(5, 0, 2, 5, 10, 20);
  Check.Check(ok, "the Spell Endurance Cost table (p. 58)");
  Check.Check(OvaRules.SpellCost(3, 2) = 10, "Auren's Mana Shield: Barrier +2 at Magic 3 costs 10")
END TestTables;

PROCEDURE Has(name: ARRAY OF CHAR; flag: INTEGER): BOOLEAN;
  VAR it: OvaRules.Item;
BEGIN it := OvaRules.Find(name); RETURN (it # NIL) & (flag IN it.flags)
END Has;

PROCEDURE TestFlags;
BEGIN
  Check.Check(Has("Agile", OvaRules.Agility) & Has("Clumsy", OvaRules.Agility)
    & Has("Combat Expert", OvaRules.CombatSkill) & Has("Iron-Willed", OvaRules.Will)
    & Has("Weak-Willed", OvaRules.Will), "the Attack Roll's Abilities and Weaknesses");
  Check.Check(Has("Evasive", OvaRules.DefenseRoll) & Has("Quick", OvaRules.DefenseRoll)
    & Has("Slow", OvaRules.DefenseRoll) & Has("Barrier", OvaRules.SecondDefense), "the Defense Roll's");
  Check.Check(Has("Attack", OvaRules.Damage) & Has("Strong", OvaRules.Strength) & Has("Weak", OvaRules.Strength)
    & Has("Telekinesis", OvaRules.Telekinetic), "the Damage Multiplier's");
  Check.Check(Has("Tough", OvaRules.HealthTable) & Has("Frail", OvaRules.HealthTens)
    & Has("Vigorous", OvaRules.EnduranceTable) & Has("Languid", OvaRules.EnduranceTens)
    & Has("Endurance Reserve", OvaRules.Reserve), "Health's and Endurance's");
  Check.Check(Has("Healer", OvaRules.HalfTV) & Has("Magic, Arcane", OvaRules.HalfTV)
    & Has("Magic, Witchcraft", OvaRules.HalfTV) & Has("Companion", OvaRules.NoTV)
    & Has("Minions", OvaRules.NoTV) & Has("Armored", OvaRules.Armor), "TV's");
  Check.Check(Has("Knowledge", OvaRules.HalfCost) & Has("Ineptitude", OvaRules.HalfCost)
    & Has("Endurance Use", OvaRules.CostUp), "half cost, and Endurance Use");
  Check.Check(Has("Accurate", OvaRules.RollEach) & Has("Inaccurate", OvaRules.RollEach)
    & Has("Effective", OvaRules.DamageEach) & Has("Ineffective", OvaRules.DamageEach)
    & Has("Ranged", OvaRules.RangedAttack) & Has("Ranged, Strength-Powered", OvaRules.StrengthRanged)
    & Has("Will Attack", OvaRules.WillAttack) & Has("No Damage", OvaRules.NoDamageDone), "the Perks' and Flaws'");
  Check.Check((Linked("Transformation") = OvaRules.Form)
    & (Linked("Companion") = OvaRules.Partner)
    & (Linked("Magic, Arcane") = OvaRules.Spells)
    & (Linked("Magic, Witchcraft") = OvaRules.Spells)
    & (Linked("Vehicle (Mecha)") = OvaRules.Machine)
    & (Linked("Attack") = OvaRules.NoLink), "linked content")
END TestFlags;

(* The Boss Abilities (p. 123): Abilities, found by name, but offered
   only to a list that asks for them, after every other. *)
PROCEDURE TestBoss;
  VAR i, n: INTEGER; ok: BOOLEAN; it: OvaRules.Item;
BEGIN
  n := OvaRules.Count(OvaRules.Ability);
  ok := OvaRules.BossCount() = 4;
  it := OvaRules.GetBoss(0); ok := ok & (it.name = "Health Reserve");
  it := OvaRules.GetBoss(1); ok := ok & (it.name = "Extra Actions");
  it := OvaRules.GetBoss(2); ok := ok & (it.name = "Scale Advantage");
  it := OvaRules.GetBoss(3); ok := ok & (it.name = "Escape Plan");
  Check.Check(ok, "the four Boss Abilities, in the book's order");
  ok := TRUE;
  FOR i := 0 TO 3 DO
    it := OvaRules.GetBoss(i);
    ok := ok & (it.kind = OvaRules.Ability) & (it.page = 123) & (OvaRules.BossOnly IN it.flags)
      & (OvaRules.Find(it.name) = it) & (OvaRules.OfferIndex(it, OvaRules.Ability, FALSE) = -1)
      & (OvaRules.OfferIndex(it, OvaRules.Ability, TRUE) = n + i)
      & (OvaRules.Offered(OvaRules.Ability, n + i, TRUE) = it)
  END;
  Check.Check(ok, "each: an Ability on p. 123, found by name, offered last and only to a Boss's list");
  FOR i := 0 TO n - 1 DO
    it := OvaRules.Get(OvaRules.Ability, i);
    ok := ok & ~(OvaRules.BossOnly IN it.flags) & (OvaRules.OfferIndex(it, OvaRules.Ability, TRUE) = i)
  END;
  Check.Check(ok, "the other Abilities: none is a Boss Ability, their places the same");
  Check.Check((OvaRules.OfferCount(OvaRules.Ability, FALSE) = n) & (OvaRules.OfferCount(OvaRules.Ability, TRUE) = n + 4)
    & (OvaRules.OfferCount(OvaRules.Weakness, TRUE) = OvaRules.Count(OvaRules.Weakness)), "only Abilities offer them")
END TestBoss;

BEGIN
  TestQuickList; TestPages; TestRepeats; TestFind; TestLabels; TestTables; TestFlags; TestBoss;
  Check.Summary
END TestRules.
