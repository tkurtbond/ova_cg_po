MODULE TestCalc; (* OvaCalc: the sample characters, and a case for each rule *)

(* The oracle is the book's sample characters (PLAN.md, "Testing"):
   each of the twelve in test/data/ (ova_fmt's test-data/, pp. 23-47) is
   built into a sheet (OvaCharacter.Build) and every number its file holds is
   compared with OvaCalc's: each attack's ROLL, DX and END, Defense
   (and Barrier's), Health, Endurance, TV, each Ability's END and
   each spell's, and the same for a Companion with combat stats. The two
   rulings the rules don't reproduce (PLAN.md, "Sample characters the
   rules don't reproduce") are checked as overrides: the computed number
   first, then the book's as an override, and what follows from it.

   Then a hand-made case for each Perk and Flaw that changes ROLL or DX,
   the floor at 0, 1/2 DX, Endurance Use, spells, Defense, Health and
   Endurance, TV, each limit and warning, and overrides counting
   downstream. Needs no display. *)

IMPORT Check, OvaCalc, OvaCharacter, OvaEntities, OvaRules, OvaText, Out, Ropes, Strings;

CONST
  DataDir = "data/";

VAR
  label: ARRAY 256 OF CHAR;
  sample: ARRAY 32 OF CHAR;  (* the sample being checked, for labels *)

(* ---- Labels ---- *)

(* label := sample ": " what *)
PROCEDURE L(what: ARRAY OF CHAR);
BEGIN COPY(sample, label); Strings.Append(": ", label); Strings.Append(what, label)
END L;

PROCEDURE LR(r: Ropes.Rope; what: ARRAY OF CHAR);
  VAR c: OvaText.String;
BEGIN
  c := OvaText.Chars(r);
  COPY(sample, label); Strings.Append(": ", label); Strings.Append(c^, label);
  Strings.Append(" ", label); Strings.Append(what, label)
END LR;

PROCEDURE AppendInt(n: INTEGER; VAR s: ARRAY OF CHAR);
  VAR d: ARRAY 12 OF CHAR; i: INTEGER; c: ARRAY 2 OF CHAR;
BEGIN
  IF n < 0 THEN Strings.Append("-", s); n := -n END;
  i := 0; REPEAT d[i] := CHR(ORD("0") + n MOD 10); n := n DIV 10; INC(i) UNTIL n = 0;
  c[1] := 0X;
  WHILE i > 0 DO DEC(i); c[0] := d[i]; Strings.Append(c, s) END
END AppendInt;

(* Checks n's text in effect against want, the label saying both. *)
PROCEDURE CheckText(VAR n: OvaCalc.Number; want: ARRAY OF CHAR);
  VAR got: ARRAY 16 OF CHAR;
BEGIN
  OvaCalc.Text(n, got);
  Strings.Append(" ", label); Strings.Append(want, label);
  IF got # want THEN Strings.Append(" (got ", label); Strings.Append(got, label); Strings.Append(")", label) END;
  Check.Check(got = want, label)
END CheckText;

PROCEDURE CheckRope(VAR n: OvaCalc.Number; want: Ropes.Rope);
  VAR c: OvaText.String;
BEGIN c := OvaText.Chars(want); CheckText(n, c^)
END CheckRope;

PROCEDURE CheckInt(VAR n: OvaCalc.Number; want: INTEGER);
  VAR w: ARRAY 16 OF CHAR;
BEGIN w := ""; AppendInt(want, w); CheckText(n, w)
END CheckInt;

(* Checks a plain integer, got, against want. *)
PROCEDURE Is(got, want: INTEGER);
BEGIN
  Strings.Append(" ", label); AppendInt(want, label);
  IF got # want THEN Strings.Append(" (got ", label); AppendInt(got, label); Strings.Append(")", label) END;
  Check.Check(got = want, label)
END Is;

(* ---- Warnings ---- *)

PROCEDURE Warnings(s: OvaCalc.Sheet): INTEGER;
  VAR w: OvaCalc.Warning; n: INTEGER;
BEGIN
  n := 0; w := s.warnings; WHILE w # NIL DO INC(n); w := w.next END;
  RETURN n
END Warnings;

(* TRUE if s has a warning of code about attack a (NIL: about none). *)
PROCEDURE Warned(s: OvaCalc.Sheet; code: INTEGER; a: OvaCalc.Attack): BOOLEAN;
  VAR w: OvaCalc.Warning;
BEGIN
  w := s.warnings;
  WHILE (w # NIL) & ~((w.code = code) & (w.attack = a)) DO w := w.next END;
  RETURN w # NIL
END Warned;

PROCEDURE WarnedAny(s: OvaCalc.Sheet; code: INTEGER): BOOLEAN;
  VAR w: OvaCalc.Warning;
BEGIN
  w := s.warnings; WHILE (w # NIL) & (w.code # code) DO w := w.next END;
  RETURN w # NIL
END WarnedAny;

(* ---- The sample characters ---- *)

(* The i'th attack of s. *)
PROCEDURE NthAttack(s: OvaCalc.Sheet; i: INTEGER): OvaCalc.Attack;
  VAR a: OvaCalc.Attack;
BEGIN
  a := s.attacks; WHILE (a # NIL) & (i > 0) DO a := a.next; DEC(i) END;
  RETURN a
END NthAttack;

(* The index of e's attack named name; -1 if none. *)
PROCEDURE AttackIndex(c: OvaEntities.Combat; name: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < c.attacks.n) & ~Ropes.EqualString(c.attacks.items[i](OvaEntities.Attack).name, name) DO INC(i) END;
  IF i = c.attacks.n THEN i := -1 END;
  RETURN i
END AttackIndex;

(* The numbers of a combat: block against s's. *)
PROCEDURE CheckCombat(c: OvaEntities.Combat; s: OvaCalc.Sheet);
  VAR i: INTEGER; x: OvaEntities.Attack; a: OvaCalc.Attack; def: ARRAY 16 OF CHAR; got: ARRAY 8 OF CHAR;
    cs: OvaText.String;
BEGIN
  a := s.attacks;
  FOR i := 0 TO c.attacks.n - 1 DO
    x := c.attacks.items[i](OvaEntities.Attack);
    LR(x.name, "ROLL"); CheckInt(a.roll, x.roll);
    LR(x.name, "DX"); CheckRope(a.dx, x.dx);
    LR(x.name, "END"); CheckInt(a.end, x.endurance);
    a := a.next
  END;
  OvaCalc.Text(s.defense, def);
  IF s.hasBarrier THEN OvaCalc.Text(s.barrier, got); Strings.Append("/", def); Strings.Append(got, def) END;
  L("DEFENSE "); cs := OvaText.Chars(c.defense); Strings.Append(cs^, label);
  IF ~Ropes.EqualString(c.defense, def) THEN
    Strings.Append(" (got ", label); Strings.Append(def, label); Strings.Append(")", label)
  END;
  Check.Check(Ropes.EqualString(c.defense, def), label);
  L("HEALTH"); CheckInt(s.health, c.health);
  L("ENDURANCE"); CheckInt(s.endurance, c.endurance);
  IF c.hasThreatValue THEN L("TV"); CheckInt(s.tv, c.threatValue) END
END CheckCombat;

(* An Ability's END, where the file gives one. *)
PROCEDURE CheckSubItems(l: OvaEntities.List; t: OvaCalc.Trait);
  VAR i: INTEGER; x: OvaEntities.SubItem;
BEGIN
  FOR i := 0 TO l.n - 1 DO
    x := l.items[i](OvaEntities.SubItem);
    IF x.hasEndurance THEN
      LR(x.name, "has an END"); Check.Check(t.hasEnd, label);
      LR(x.name, "END"); CheckInt(t.end, x.endurance)
    END;
    t := t.next
  END
END CheckSubItems;

(* Every number e's file holds against s's. *)
PROCEDURE CheckEntity(e: OvaEntities.Entity; s: OvaCalc.Sheet);
  VAR i, j: INTEGER; a: OvaEntities.Ability; t: OvaCalc.Trait; sp: OvaCalc.Spell; x: OvaEntities.Spell;
    keep: ARRAY 32 OF CHAR; c: OvaText.String;
BEGIN
  t := s.traits;
  FOR i := 0 TO e.abilities.n - 1 DO
    a := e.abilities.items[i](OvaEntities.Ability);
    IF a.hasEndurance THEN LR(a.name, "END"); CheckInt(t.end, a.endurance) END;
    CheckSubItems(a.subAbilities, t.form);
    sp := t.spells;
    FOR j := 0 TO a.spells.n - 1 DO
      x := a.spells.items[j](OvaEntities.Spell);
      LR(x.name, "spell END"); CheckRope(sp.end, x.endurance);
      sp := sp.next
    END;
    IF (a.subEntity # NIL) & a.subEntity.combat.hasCombat THEN
      COPY(sample, keep); c := OvaText.Chars(a.subEntity.name); COPY(c^, sample);
      CheckCombat(a.subEntity.combat, t.partner);
      L("no warnings"); Check.Check(t.partner.warnings = NIL, label);
      COPY(keep, sample)
    END;
    t := t.next
  END;
  CheckCombat(e.combat, s);
  L("no warnings"); Check.Check(Warnings(s) = 0, label)
END CheckEntity;

PROCEDURE Sample(name: ARRAY OF CHAR);
  VAR path: ARRAY 64 OF CHAR; e: OvaEntities.Entity; s: OvaCalc.Sheet; a: OvaCalc.Attack; i, n: INTEGER;
    msg: Ropes.Rope; ok: BOOLEAN;
BEGIN
  COPY(name, sample);
  path := DataDir; Strings.Append(name, path); Strings.Append(".yaml", path);
  L("loaded"); Check.Check(OvaCharacter.ReadEntity(path, e, n, msg) & (n = 1), label);
  IF e = NIL THEN RETURN END;
  s := OvaCharacter.Build(e);
  (* The Phase 3a keys the samples carry, as Build reads them; and the
     book's two rulings, which Build leaves to Load's overrides. *)
  IF name = "Ai" THEN
    a := s.attacks; ok := a # NIL;
    WHILE a # NIL DO ok := ok & a.telekinetic & ~a.transformed; a := a.next END;
    L("both attacks made with Telekinesis"); Check.Check(ok, label)
  ELSIF name = "Fukiko" THEN L("the sheet shown transformed"); Check.Check(s.transformed, label)
  ELSIF name = "Miho" THEN
    i := AttackIndex(e.combat, "Mode SP: Miho Ray");
    L("has Mode SP"); Check.Check(i >= 0, label);
    IF i >= 0 THEN a := NthAttack(s, i); L("Mode SP made transformed"); Check.Check(a.transformed, label) END;
    L("the sheet not transformed"); Check.Check(~s.transformed, label)
  ELSIF name = "Braun" THEN
    (* The rule: 2 - Clumsy 2 = 0, TV 0 + 2 + 0 = 2; the book's -2 as
       an override makes TV 0. *)
    OvaCalc.Compute(s);
    L("First Day of Sale Shove! computed ROLL"); CheckInt(s.attacks.roll, 0);
    L("computed TV"); CheckInt(s.tv, 2);
    OvaCalc.Override(s.attacks.roll, -2, FALSE, FALSE)
  ELSIF name = "Natsuki" THEN
    i := AttackIndex(e.combat, "Stiletto Kick");
    L("has Stiletto Kick"); Check.Check(i >= 0, label);
    IF i >= 0 THEN
      a := NthAttack(s, i);
      OvaCalc.Compute(s);
      L("Stiletto Kick computed DX"); CheckInt(a.dx, 6);
      OvaCalc.Override(a.dx, 3, FALSE, FALSE)
    END
  END;
  OvaCalc.Compute(s);
  CheckEntity(e, s)
END Sample;

PROCEDURE Samples12;
BEGIN
  Sample("Ai"); Sample("Auren"); Sample("Braun"); Sample("Cora"); Sample("Daisuke"); Sample("Fukiko");
  Sample("Karis"); Sample("Miho"); Sample("Natsuki"); Sample("Raine"); Sample("Shou"); Sample("Yuu")
END Samples12;

(* ---- Hand-made sheets ---- *)

PROCEDURE NewSheet(kind: INTEGER): OvaCalc.Sheet;
  VAR s: OvaCalc.Sheet;
BEGIN NEW(s); OvaCalc.InitSheet(s, kind); RETURN s
END NewSheet;

PROCEDURE Item(name: ARRAY OF CHAR): OvaRules.Item;
  VAR it: OvaRules.Item;
BEGIN it := OvaRules.Find(name); ASSERT(it # NIL); RETURN it
END Item;

(* name at level, added to list (a sheet's traits or a form). *)
PROCEDURE T(VAR list: OvaCalc.Trait; name: ARRAY OF CHAR; level: INTEGER): OvaCalc.Trait;
  VAR t: OvaCalc.Trait; it: OvaRules.Item;
BEGIN
  it := Item(name);
  NEW(t); OvaCalc.InitTrait(t, it, it.kind, level); OvaCalc.AddTrait(list, t);
  RETURN t
END T;

PROCEDURE Add(VAR list: OvaCalc.Trait; name: ARRAY OF CHAR; level: INTEGER);
  VAR t: OvaCalc.Trait;
BEGIN t := T(list, name, level)
END Add;

(* name taken times, at cost each time where the user sets it. *)
PROCEDURE M(VAR mods: OvaCalc.Mod; name: ARRAY OF CHAR; times, cost: INTEGER);
  VAR m: OvaCalc.Mod;
BEGIN NEW(m); OvaCalc.InitMod(m, Item(name), times, cost); OvaCalc.AddMod(mods, m)
END M;

PROCEDURE NewAttack(s: OvaCalc.Sheet): OvaCalc.Attack;
  VAR a: OvaCalc.Attack;
BEGIN NEW(a); OvaCalc.InitAttack(a); OvaCalc.AddAttack(s, a); RETURN a
END NewAttack;

(* No Abilities: the plain attack, the starting numbers. *)
PROCEDURE Plain;
  VAR s: OvaCalc.Sheet; a: OvaCalc.Attack;
BEGIN
  sample := "plain";
  s := NewSheet(OvaCalc.Character); OvaCalc.Compute(s);
  L("no attack: TV 2 + 2 + 1"); CheckInt(s.tv, 5);
  a := NewAttack(s); OvaCalc.Compute(s);
  L("ROLL"); CheckInt(a.roll, 2); L("DX"); CheckInt(a.dx, 1); L("END"); CheckInt(a.end, 0);
  L("DEFENSE"); CheckInt(s.defense, 2); L("no Barrier"); Check.Check(~s.hasBarrier, label);
  L("HEALTH"); CheckInt(s.health, 40); L("ENDURANCE"); CheckInt(s.endurance, 40);
  L("no Reserve"); Check.Check(~s.hasReserve, label);
  L("TV"); CheckInt(s.tv, 5)
END Plain;

(* ROLL: Agile, Clumsy, Combat Expert; Accurate and Inaccurate each time;
   a Will Attack's Iron-Willed and Weak-Willed. Attack and Strong don't
   add. *)
PROCEDURE Rolls;
  VAR s: OvaCalc.Sheet; plain, acc, inacc, both, will: OvaCalc.Attack;
BEGIN
  sample := "rolls";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 3); Add(s.traits, "Combat Expert", 2); Add(s.traits, "Clumsy", -1);
  Add(s.traits, "Iron-Willed", 1); Add(s.traits, "Attack", 4); Add(s.traits, "Strong", 2);
  plain := NewAttack(s);
  acc := NewAttack(s); M(acc.mods, "Accurate", 2, 0);
  inacc := NewAttack(s); M(inacc.mods, "Inaccurate", 3, 0);
  both := NewAttack(s); M(both.mods, "Accurate", 2, 0); M(both.mods, "Inaccurate", 3, 0);
  will := NewAttack(s); M(will.mods, "Will Attack", 1, 0);
  OvaCalc.Compute(s);
  L("2 + Agile 3 + Combat Expert 2 - Clumsy 1"); CheckInt(plain.roll, 6);
  L("Accurate x2"); CheckInt(acc.roll, 8);
  L("Accurate x2 END"); CheckInt(acc.end, 10);
  L("Inaccurate x3"); CheckInt(inacc.roll, 3);
  L("Inaccurate x3 END, floored"); CheckInt(inacc.end, 0);
  L("Accurate x2, Inaccurate x3"); CheckInt(both.roll, 5);
  L("Accurate x2, Inaccurate x3 END, floored"); CheckInt(both.end, 0);
  L("Will Attack: 2 + Iron-Willed 1 + Combat Expert 2"); CheckInt(will.roll, 5);
  L("Will Attack END"); CheckInt(will.end, 0);
  L("TV's roll leaves out Accurate"); Is(acc.tvRoll, 6);
  L("TV's roll leaves out Inaccurate"); Is(inacc.tvRoll, 6);
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 2); Add(s.traits, "Weak-Willed", -2);
  will := NewAttack(s); M(will.mods, "Will Attack", 1, 0);
  OvaCalc.Compute(s);
  L("Will Attack: 2 - Weak-Willed 2, Agile not counted"); CheckInt(will.roll, 0)
END Rolls;

(* DX: Attack, Strong, Weak; Ranged and Ranged, Strength-Powered;
   Telekinesis; Effective and Ineffective; No Damage; 1/2. *)
PROCEDURE Damage;
  VAR s: OvaCalc.Sheet; melee, ranged, strRanged, both, eff, ineff, half, none, tk, plainTk: OvaCalc.Attack;
BEGIN
  sample := "DX";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Attack", 2); Add(s.traits, "Strong", 3); Add(s.traits, "Agile", 2);
  melee := NewAttack(s);
  ranged := NewAttack(s); M(ranged.mods, "Ranged", 1, 0);
  strRanged := NewAttack(s); M(strRanged.mods, "Ranged, Strength-Powered", 1, 0);
  both := NewAttack(s); M(both.mods, "Ranged", 1, 0); M(both.mods, "Ranged, Strength-Powered", 1, 0);
  eff := NewAttack(s); M(eff.mods, "Effective", 2, 0);
  ineff := NewAttack(s); M(ineff.mods, "Ineffective", 3, 0);
  half := NewAttack(s); M(half.mods, "Ineffective", 6, 0);
  none := NewAttack(s); M(none.mods, "Area Effect", 2, 0); M(none.mods, "No Damage", 1, 0);
  OvaCalc.Compute(s);
  L("1 + Attack 2 + Strong 3"); CheckInt(melee.dx, 6);
  L("Ranged drops Strong"); CheckInt(ranged.dx, 3);
  L("Ranged END"); CheckInt(ranged.end, 0);
  L("Ranged, Strength-Powered keeps Strong"); CheckInt(strRanged.dx, 6);
  L("Ranged, Strength-Powered END"); CheckInt(strRanged.end, 5);
  L("Ranged with Ranged, Strength-Powered keeps Strong"); CheckInt(both.dx, 6);
  L("Effective x2"); CheckInt(eff.dx, 8);
  L("Effective x2 END"); CheckInt(eff.end, 10);
  L("Ineffective x3"); CheckInt(ineff.dx, 3);
  L("Ineffective x6: 0 is 1/2"); CheckText(half.dx, "1/2");
  L("1/2 is half"); Check.Check(OvaCalc.Half(half.dx) & (OvaCalc.Value(half.dx) = 0), label);
  L("No Damage: 0, not 1/2"); CheckInt(none.dx, 0);
  L("No Damage, Area Effect x2 END"); CheckInt(none.end, 0);
  L("TV's DX leaves out Effective"); Is(eff.tvDX, 6);
  L("TV's DX leaves out Ineffective"); Is(half.tvDX, 6);
  L("TV's DX leaves out No Damage"); Is(none.tvDX, 6);
  L("TV: roll 4 + Defense 2 + DX 6"); CheckInt(s.tv, 12);

  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Attack", 1); Add(s.traits, "Weak", -2); Add(s.traits, "Telekinesis", 3);
  melee := NewAttack(s);
  ranged := NewAttack(s); M(ranged.mods, "Ranged", 1, 0);
  tk := NewAttack(s); M(tk.mods, "Ranged", 1, 0); tk.telekinetic := TRUE;
  plainTk := NewAttack(s); plainTk.telekinetic := TRUE;
  OvaCalc.Compute(s);
  L("1 + Attack 1 - Weak 2: 0 is 1/2"); CheckText(melee.dx, "1/2");
  L("TV's DX of a 1/2 is 0"); Is(melee.tvDX, 0);
  L("Ranged drops Weak"); CheckInt(ranged.dx, 2);
  L("made with Telekinesis 3, Ranged"); CheckInt(tk.dx, 5);
  L("made with Telekinesis 3, not Ranged"); CheckInt(plainTk.dx, 3);
  L("TV's DX keeps Telekinesis"); Is(tk.tvDX, 5)
END Damage;

(* END: Endurance Use, on an attack and on an Ability; the floor; a
   chosen cost; Unique Perk. *)
PROCEDURE Endurance;
  VAR s: OvaCalc.Sheet; a, b, c, d: OvaCalc.Attack; barrier, flight, plain: OvaCalc.Trait;
BEGIN
  sample := "END";
  s := NewSheet(OvaCalc.Character);
  a := NewAttack(s); a.use := -2; M(a.mods, "Accurate", 1, 0);
  b := NewAttack(s); b.use := -1; M(b.mods, "Effective", 2, 0); M(b.mods, "Weapon", 1, 0);
  c := NewAttack(s); M(c.mods, "Requirement", 1, -15); M(c.mods, "Area Effect", 1, 0); M(c.mods, "Cancel", 1, -5);
  d := NewAttack(s); M(d.mods, "Unique Perk", 1, 15); M(d.mods, "Ammunition", 3, 0);
  barrier := T(s.traits, "Barrier", 3); barrier.use := -1; M(barrier.mods, "Elaborate Gestures", 1, 0);
  flight := T(s.traits, "Flight", 2); flight.use := -3;
  plain := T(s.traits, "Smart", 2);
  OvaCalc.Compute(s);
  L("Endurance Use -2 + Accurate"); CheckInt(a.end, 15);
  L("Endurance Use -1 + Effective x2 - Weapon"); CheckInt(b.end, 10);
  L("Area Effect - Requirement 15 - Cancel 5, floored"); CheckInt(c.end, 0);
  L("Unique Perk 15 - Ammunition x3"); CheckInt(d.end, 0);
  L("Barrier with Endurance Use -1 has an END"); Check.Check(barrier.hasEnd, label);
  L("Barrier: Endurance Use -1 - Elaborate Gestures"); CheckInt(barrier.end, 0);
  L("Flight: Endurance Use -3"); CheckInt(flight.end, 20);
  L("Smart has no END"); Check.Check(~plain.hasEnd, label);
  L("no warnings"); Is(Warnings(s), 0)
END Endurance;

(* Spells (p. 58): the table's corners and middle, "+" for Barrier, a
   level out of the table. *)
PROCEDURE Spells;
  VAR s: OvaCalc.Sheet; magic, low: OvaCalc.Trait; a, b, c, d, e: OvaCalc.Spell;

  PROCEDURE Sp(t: OvaCalc.Trait; name: ARRAY OF CHAR; level: INTEGER): OvaCalc.Spell;
    VAR sp: OvaCalc.Spell;
  BEGIN NEW(sp); OvaCalc.InitSpell(sp, Item(name), level); OvaCalc.AddSpell(t, sp); RETURN sp
  END Sp;

BEGIN
  sample := "spells";
  s := NewSheet(OvaCalc.Character);
  magic := T(s.traits, "Magic, Arcane", 3);
  a := Sp(magic, "Barrier", 2); b := Sp(magic, "Flight", 2); c := Sp(magic, "Quick", 6);
  low := T(s.traits, "Magic, Witchcraft", 1);
  d := Sp(low, "Strong", 5); e := Sp(low, "Flight", 1);
  OvaCalc.Compute(s);
  L("Magic 3, Barrier 2"); CheckText(a.end, "10+");
  L("Magic 3, Flight 2"); CheckText(b.end, "10");
  L("Magic 1, Strong 5"); CheckInt(d.end, 60);
  L("Magic 1, Flight 1"); CheckInt(e.end, 20);
  L("Quick 6 is out of the table"); Check.Check(WarnedAny(s, OvaCalc.SpellRange), label);
  L("one warning"); Is(Warnings(s), 1);
  magic.level := 5; c.level := 1; OvaCalc.Compute(s);
  L("Magic 5, Quick 1"); CheckInt(c.end, 0);
  L("Magic 5, Barrier 2"); CheckText(a.end, "2+")
END Spells;

(* Defense, Barrier, Health, Endurance, Endurance Reserve, by sheet kind. *)
PROCEDURE Stats;
  VAR s: OvaCalc.Sheet;
BEGIN
  sample := "stats";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Evasive", 2); Add(s.traits, "Quick", 3); Add(s.traits, "Slow", -1);
  Add(s.traits, "Barrier", 4);
  Add(s.traits, "Tough", 5); Add(s.traits, "Frail", -2);
  Add(s.traits, "Vigorous", 3); Add(s.traits, "Languid", -1);
  Add(s.traits, "Endurance Reserve", 2);
  OvaCalc.Compute(s);
  L("DEFENSE 2 + Evasive 2 + Quick 3 - Slow 1"); CheckInt(s.defense, 6);
  L("Barrier"); Check.Check(s.hasBarrier, label);
  L("Barrier's Defense 2 + 4"); CheckInt(s.barrier, 6);
  L("HEALTH 40 + Tough 5's 60 - Frail 2's 20"); CheckInt(s.health, 80);
  L("ENDURANCE 40 + Vigorous 3's 30 - Languid 1's 10"); CheckInt(s.endurance, 60);
  L("Reserve"); Check.Check(s.hasReserve, label);
  L("Endurance Reserve 2"); CheckInt(s.reserve, 40);

  s := NewSheet(OvaCalc.CompanionSheet); Add(s.traits, "Tough", 1); OvaCalc.Compute(s);
  L("a Companion's HEALTH 20 + Tough 1"); CheckInt(s.health, 30);
  L("a Companion's ENDURANCE"); CheckInt(s.endurance, 20);
  L("a Companion's TV 2 + 2 + 1 + Tough 1 - 4, at least 1"); CheckInt(s.tv, 2);
  Add(s.traits, "Frail", -3); OvaCalc.Compute(s);
  L("a Companion's TV, at least 1"); CheckInt(s.tv, 1);
  s := NewSheet(OvaCalc.MinionSheet); OvaCalc.Compute(s);
  L("Minions' HEALTH"); CheckInt(s.health, 10); L("Minions' ENDURANCE"); CheckInt(s.endurance, 10)
END Stats;

(* TV (p. 124): Armored, the signed Health and Endurance levels, the
   marked Abilities' halves; Companion never counted. *)
PROCEDURE ThreatValue;
  VAR s: OvaCalc.Sheet; healer, companion, smart: OvaCalc.Trait;
BEGIN
  sample := "TV";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Armored", 2); Add(s.traits, "Tough", 1); Add(s.traits, "Languid", -1);
  healer := T(s.traits, "Healer", 3); Add(s.traits, "Magic, Arcane", 1);
  companion := T(s.traits, "Companion", 3); smart := T(s.traits, "Smart", 3);
  OvaCalc.Compute(s);
  L("Healer starts marked"); Check.Check(healer.halfTV, label);
  L("Companion doesn't"); Check.Check(~companion.halfTV, label);
  L("5 + Armored 2 + Tough 1 - Languid 1 + Healer 3/2 + Magic 1/2"); CheckInt(s.tv, 10);
  companion.halfTV := TRUE; OvaCalc.Compute(s);
  L("a marked Companion still doesn't count"); CheckInt(s.tv, 10);
  healer.halfTV := FALSE; smart.halfTV := TRUE; OvaCalc.Compute(s);
  L("Healer unmarked, Smart 3 marked"); CheckInt(s.tv, 10);
  smart.halfTV := FALSE; OvaCalc.Compute(s);
  L("neither"); CheckInt(s.tv, 8)
END ThreatValue;

(* Transformation (p. 63): the form counts when the sheet is shown
   transformed, or for an attack made in it, which TV then leaves out. *)
PROCEDURE Transformation;
  VAR s: OvaCalc.Sheet; t: OvaCalc.Trait; base, formed: OvaCalc.Attack;
BEGIN
  sample := "Transformation";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 1); Add(s.traits, "Tough", 4);
  t := T(s.traits, "Transformation", 2);
  Add(t.form, "Combat Expert", 2); Add(t.form, "Barrier", 1); Add(t.form, "Tough", 3);
  base := NewAttack(s); formed := NewAttack(s); formed.transformed := TRUE;
  OvaCalc.Compute(s);
  L("ROLL 2 + Agile 1"); CheckInt(base.roll, 3);
  L("made transformed, + Combat Expert 2"); CheckInt(formed.roll, 5);
  L("no Barrier untransformed"); Check.Check(~s.hasBarrier, label);
  L("HEALTH: Tough 4"); CheckInt(s.health, 80);
  L("TV leaves out the transformed attack: 3 + 2 + 1 + Tough 4"); CheckInt(s.tv, 10);
  L("no warnings"); Is(Warnings(s), 0);
  L("the form's levels aren't in the totals"); CheckInt(s.abilityLevels, 7);
  s.transformed := TRUE; OvaCalc.Compute(s);
  L("transformed: ROLL"); CheckInt(base.roll, 5);
  L("transformed: Barrier"); Check.Check(s.hasBarrier, label);
  L("transformed: Tough 4 + 3 counted as 5"); CheckInt(s.health, 100);
  L("transformed: Tough past 5 warned of"); Check.Check(WarnedAny(s, OvaCalc.TableRange), label);
  L("transformed: TV 5 + Barrier 3 + 1 + Tough 7"); CheckInt(s.tv, 16)
END Transformation;

(* Overrides, and what is computed from them. *)
PROCEDURE Overrides;
  VAR s: OvaCalc.Sheet; a, b: OvaCalc.Attack; n: OvaCalc.Number; txt: ARRAY 16 OF CHAR;
BEGIN
  sample := "overrides";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Attack", 2); Add(s.traits, "Evasive", 1); Add(s.traits, "Barrier", 1);
  a := NewAttack(s); M(a.mods, "Accurate", 2, 0); M(a.mods, "Effective", 1, 0);
  b := NewAttack(s);
  OvaCalc.Compute(s);
  L("TV 2 + Defense 3 + DX 3"); CheckInt(s.tv, 8);
  OvaCalc.Override(a.roll, 10, FALSE, FALSE); OvaCalc.Compute(s);
  L("ROLL overridden"); CheckInt(a.roll, 10);
  L("still computed"); OvaCalc.ComputedText(a.roll, txt); Check.Check(txt = "4", label);
  L("TV: overridden ROLL 10 less Accurate x2"); CheckInt(s.tv, 14);
  OvaCalc.Override(a.dx, 0, TRUE, FALSE); OvaCalc.Override(b.dx, 1, FALSE, FALSE); OvaCalc.Compute(s);
  L("DX overridden 1/2"); CheckText(a.dx, "1/2");
  L("TV: DX 1/2 and 1"); CheckInt(s.tv, 12);
  OvaCalc.Override(b.dx, 7, FALSE, FALSE); OvaCalc.Compute(s);
  L("TV: DX overridden 7"); CheckInt(s.tv, 18);
  OvaCalc.Override(s.barrier, 6, FALSE, FALSE); OvaCalc.Compute(s);
  L("TV: Barrier's Defense overridden 6"); CheckInt(s.tv, 21);
  OvaCalc.Override(s.defense, 9, FALSE, FALSE); OvaCalc.Compute(s);
  L("TV: Defense overridden 9"); CheckInt(s.tv, 24);
  OvaCalc.Override(s.tv, 1, FALSE, FALSE); OvaCalc.Compute(s);
  L("TV overridden"); CheckInt(s.tv, 1);
  OvaCalc.Clear(s.tv); OvaCalc.Clear(s.defense); OvaCalc.Clear(s.barrier);
  OvaCalc.Clear(a.roll); OvaCalc.Clear(a.dx); OvaCalc.Clear(b.dx); OvaCalc.Compute(s);
  L("all cleared"); CheckInt(s.tv, 8);
  OvaCalc.Override(s.abilityLevels, 10, FALSE, FALSE); OvaCalc.Compute(s);
  L("Character Total from the overridden Abilities' 10"); CheckInt(s.total, 10);
  s.options.baseZero := TRUE; s.options.baseZeroRange := 5; OvaCalc.Compute(s);
  L("and Base Zero checks it"); Check.Check(WarnedAny(s, OvaCalc.BaseZeroBroken), label);
  OvaCalc.Clear(s.abilityLevels); OvaCalc.Compute(s);
  L("cleared: Base Zero kept"); Check.Check(~WarnedAny(s, OvaCalc.BaseZeroBroken), label);

  sample := "Parse";
  OvaCalc.InitAttack(a); n := a.roll;
  L("12"); Check.Check(OvaCalc.Parse("12", FALSE, FALSE, n) & n.overridden & (OvaCalc.Value(n) = 12), label);
  L("' -2 '"); Check.Check(OvaCalc.Parse(" -2 ", FALSE, FALSE, n) & (OvaCalc.Value(n) = -2), label);
  L("blank clears"); Check.Check(OvaCalc.Parse("  ", FALSE, FALSE, n) & ~n.overridden, label);
  L("1/2 for a DX"); Check.Check(OvaCalc.Parse("1/2", TRUE, FALSE, n) & OvaCalc.Half(n), label);
  L("1/2 only for a DX"); Check.Check(~OvaCalc.Parse("1/2", FALSE, TRUE, n) & OvaCalc.Half(n), label);
  L("10+ for an END"); Check.Check(OvaCalc.Parse("10+", FALSE, TRUE, n) & OvaCalc.Plus(n), label);
  OvaCalc.Text(n, txt); L("10+ written back"); Check.Check(txt = "10+", label);
  L("10+ only for an END"); Check.Check(~OvaCalc.Parse("10+", TRUE, FALSE, n), label);
  L("x refused"); Check.Check(~OvaCalc.Parse("x", TRUE, TRUE, n), label);
  L("+ refused"); Check.Check(~OvaCalc.Parse("+", TRUE, TRUE, n), label);
  L("- refused"); Check.Check(~OvaCalc.Parse("-", TRUE, TRUE, n), label);
  L("4 5 refused"); Check.Check(~OvaCalc.Parse("4 5", TRUE, TRUE, n), label)
END Overrides;

(* The limits (p. 21) and the totals they check. *)
PROCEDURE Limits;
  VAR s: OvaCalc.Sheet; know, inept: OvaCalc.Trait; a, b: OvaCalc.Attack;
BEGIN
  sample := "limits";
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 4); Add(s.traits, "Smart", 4); Add(s.traits, "Weak", -1);
  OvaCalc.Compute(s);
  L("Abilities"); CheckInt(s.abilityLevels, 8); L("Weaknesses"); CheckInt(s.weaknessLevels, -1);
  L("Character Total"); CheckInt(s.total, 7);
  L("Scaled Cost points 8 + 8 - 1"); CheckInt(s.points, 15);
  L("no limits, no warnings"); Is(Warnings(s), 0);
  s.options.baseZero := TRUE; s.options.baseZeroRange := 5; OvaCalc.Compute(s);
  L("Base Zero: 7 is past 5"); Check.Check(WarnedAny(s, OvaCalc.BaseZeroBroken), label);
  Add(s.traits, "Poor", -2); OvaCalc.Compute(s);
  L("Base Zero: 5 isn't"); Check.Check(~WarnedAny(s, OvaCalc.BaseZeroBroken), label);
  s.options.scaledCost := TRUE; OvaCalc.Compute(s);
  L("Scaled Cost points 16 - 1 - 2"); CheckInt(s.points, 13);
  L("Base Zero on Scaled Cost's points: 13 is past 5"); Check.Check(WarnedAny(s, OvaCalc.BaseZeroBroken), label);

  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 5); Add(s.traits, "Smart", 5); Add(s.traits, "Quick", 5);
  Add(s.traits, "Poor", -3); Add(s.traits, "Rude", -3); Add(s.traits, "Shy", -3); Add(s.traits, "Mute", -1);
  s.options.powerCeiling := TRUE; s.options.ceiling := 15;
  s.options.startingLevels := TRUE; s.options.starting := 5;
  OvaCalc.Compute(s);
  L("Power Ceiling 15, 15 levels"); Check.Check(~WarnedAny(s, OvaCalc.CeilingBroken), label);
  L("starting 5 + Weaknesses 10"); Check.Check(~WarnedAny(s, OvaCalc.StartingBroken), label);
  know := T(s.traits, "Knowledge", 1); OvaCalc.Compute(s);
  L("Power Ceiling 15, 16 levels"); Check.Check(WarnedAny(s, OvaCalc.CeilingBroken), label);
  L("starting 5 + Weaknesses 10, 16 levels"); Check.Check(WarnedAny(s, OvaCalc.StartingBroken), label);
  s.options.halfCostKnowledge := TRUE; know.level := 2; OvaCalc.Compute(s);
  L("Knowledge 2 at half cost"); CheckInt(s.abilityLevels, 16);
  know.level := 3; inept := T(s.traits, "Ineptitude", -3); OvaCalc.Compute(s);
  L("Knowledge 3 at half cost, rounded up"); CheckInt(s.abilityLevels, 17);
  L("Ineptitude -3 at half cost, rounded up"); CheckInt(s.weaknessLevels, -12);
  s.options.scaledCost := TRUE; know.level := 5; OvaCalc.Compute(s);
  L("Scaled Cost: Knowledge 5 at half cost, 8"); Is(s.abilityPoints, 53);
  L("Scaled Cost: Ineptitude -3 at half cost, 2"); Is(s.weaknessPoints, 15);
  L("Power Ceiling on Scaled Cost's points"); Check.Check(WarnedAny(s, OvaCalc.CeilingBroken), label);
  s.options.powerCeiling := FALSE; s.options.startingLevels := FALSE; s.options.scaledCost := FALSE;
  OvaCalc.Compute(s);
  L("no limit, no half cost"); CheckInt(s.abilityLevels, 20);
  L("no limit, no warnings"); Is(Warnings(s), 0);

  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 4); Add(s.traits, "Combat Expert", 2);
  Add(s.traits, "Evasive", 3); Add(s.traits, "Quick", 2);
  a := NewAttack(s);
  OvaCalc.Compute(s);
  L("Combined Effectiveness off"); Is(Warnings(s), 0);
  s.options.combinedEffectiveness := TRUE; OvaCalc.Compute(s);
  L("Combined Effectiveness: ROLL +6"); Check.Check(Warned(s, OvaCalc.OverFive, a), label);
  L("Combined Effectiveness: Defense +5 is all right"); Check.Check(~Warned(s, OvaCalc.OverFive, NIL), label);
  Add(s.traits, "Quick", 1); OvaCalc.Compute(s);
  L("Combined Effectiveness: Defense +6"); Check.Check(Warned(s, OvaCalc.OverFive, NIL), label);

  sample := "warnings";
  s := NewSheet(OvaCalc.Character);
  a := NewAttack(s); M(a.mods, "Paralyzing", 2, 0); M(a.mods, "Requirement", 1, -10); M(a.mods, "Cancel", 1, 0);
  M(a.mods, "Redirectable", 1, 0); M(a.mods, "Ranged", 1, 0); M(a.mods, "No Damage", 1, 0);
  M(a.mods, "Effective", 1, 0);
  OvaCalc.Compute(s);
  L("within the limits"); Is(Warnings(s), 0);
  b := NewAttack(s); M(b.mods, "Paralyzing", 3, 0); M(b.mods, "Requirement", 1, -25);
  M(b.mods, "Cancel", 1, -7); M(b.mods, "Redirectable", 1, 0); M(b.mods, "No Damage", 1, 0);
  M(b.mods, "Ineffective", 1, 0); M(b.mods, "Ammunition", 4, 0);
  OvaCalc.Compute(s);
  L("Paralyzing x3, Ammunition x4"); Check.Check(Warned(s, OvaCalc.TooOften, b), label);
  L("Requirement -25, Cancel -7"); Check.Check(Warned(s, OvaCalc.CostRange, b), label);
  L("Redirectable not Ranged"); Check.Check(Warned(s, OvaCalc.RedirectableAlone, b), label);
  L("No Damage with Ineffective"); Check.Check(Warned(s, OvaCalc.NoDamageIneffective, b), label);
  L("six warnings"); Is(Warnings(s), 6);
  s := NewSheet(OvaCalc.Character);
  Add(s.traits, "Agile", 6); Add(s.traits, "Weak", 0); Add(s.traits, "Poor", -4);
  NEW(know); OvaCalc.InitTrait(know, NIL, OvaRules.Ability, 2); OvaCalc.AddTrait(s.traits, know);
  OvaCalc.Compute(s);
  L("an unknown Ability"); Check.Check(WarnedAny(s, OvaCalc.UnknownItem), label);
  L("an unknown Ability counts in the totals"); CheckInt(s.abilityLevels, 8);
  L("Agile 6, Weak 0, Poor -4"); Is(Warnings(s), 4)
END Limits;

BEGIN
  Samples12;
  Plain; Rolls; Damage; Endurance; Spells; Stats; ThreatValue; Transformation; Overrides; Limits;
  Check.Summary
END TestCalc.
