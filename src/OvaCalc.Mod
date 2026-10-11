MODULE OvaCalc; (* The numbers on the sheet, computed from the character *)

(* PLAN.md, "The rules the program computes" and "Limiting the
   character": each attack's ROLL, DX and END; the END of an Ability
   with Perks and Flaws or Endurance Use, and of each spell; DEFENSE,
   Barrier's and Incorporeal Form's alternate Defenses; HEALTH,
   ENDURANCE, Endurance Reserve and TV; the running totals; and the warnings of broken limits.

   A character is given as a Sheet of Traits (its Abilities and
   Weaknesses) and Attacks, each Attack and Trait with its Perks and
   Flaws (Mods). The model (OvaCharacter, Phase 3) extends these types
   with what OvaCalc doesn't need (names, details, text), so they are
   allocated by the client and set up with Init and Add, never here.

   Every computed number is a Number, which also holds the user's
   override (PLAN.md, "Overriding a computed number"). Compute reads the
   overrides of the numbers others are computed from (an attack's ROLL
   and DX, Defense, the totals) so that an override counts downstream,
   and sets every computed value; the overrides it leaves alone.

   Imports nothing of the window or the files, so its tests need no
   display. *)

IMPORT OvaRules;

CONST
  (* Sheet kinds: where Health and Endurance start, and TV's last step *)
  Character* = 0;       (* 40 and 40 (p. 19); a Vehicle's too (p. 64) *)
  CompanionSheet* = 1;  (* 20 and 20 (p. 52); TV 4 less, at least 1, a Secondary NPC's (p. 123-124) *)
  MinionSheet* = 2;     (* 10 and 10 (p. 58) *)
  ExtraSheet* = 3;      (* 10 and 10 (p. 123); TV always 1, an Extra's (p. 124) *)

  (* Warning codes. Each names what it is about in its trait, attack,
     mod or spell; NIL for the sheet as a whole. *)
  UnknownItem* = 0;     (* trait or mod: a name OvaRules doesn't have *)
  LevelRange* = 1;      (* trait: an Ability not +1 to +5, a Weakness not -1 to -3 (p. 18) *)
  TooOften* = 2;        (* mod: taken more times than its text allows (p. 83) *)
  CostRange* = 3;       (* mod: a chosen cost outside its range, or not in steps of 5 (p. 87-88) *)
  NoDamageIneffective* = 4;  (* attack: No Damage with Ineffective (p. 88) *)
  RedirectableAlone* = 5;    (* attack: Redirectable without Ranged (p. 86) *)
  SpellRange* = 6;      (* spell: its Magic's level not 1 to 5, or its own not 1 to 5 or -1 to -3: no cost (p. 58) *)
  TableRange* = 7;      (* Tough, Vigorous or Endurance Reserve past +5 in all: counted as +5 *)
  BaseZeroBroken* = 8;  (* the Character Total (or points) beyond Base Zero's range (p. 21) *)
  StartingBroken* = 9;  (* Abilities beyond the starting levels and the Weaknesses' (p. 21) *)
  CeilingBroken* = 10;  (* Abilities beyond the Power Ceiling (p. 21) *)
  OverFive* = 11;       (* attack, or NIL for Defense: Abilities give a roll more than +5 (p. 21) *)

  CombinedLimit = 5;    (* Combined Effectiveness: at most +5 to a roll *)
  CharacterBase = 40; CompanionBase = 20; MinionBase = 10;
  CompanionTV = 4;      (* taken off a Secondary NPC's TV *)
  MaxLevel = 5; MinWeakness = -3;
  CostStep = 5;

TYPE
  (* A number on the sheet: the computed value, and the override the
     user typed, if any. A DX can be 1/2 (half, value 0) and a spell's
     END "10+" (plus). An override is the same three. *)
  Number* = RECORD
    value-: INTEGER; half-, plus-: BOOLEAN;
    overridden-: BOOLEAN;
    ovValue-: INTEGER; ovHalf-, ovPlus-: BOOLEAN
  END;

  Sheet* = POINTER TO SheetDesc;

  (* A Perk or Flaw taken, by an attack or an Ability. cost is each
     time's cost where the user sets it: a RangeCost's or UserCost's,
     or an item the tables don't have (from the file); else ignored. *)
  Mod* = POINTER TO ModDesc;
  ModDesc* = RECORD
    next*: Mod;
    item*: OvaRules.Item;  (* NIL: a name OvaRules doesn't have *)
    times*: INTEGER;       (* >= 1; ova_fmt's counts-as *)
    cost*: INTEGER
  END;

  (* A Magic Ability's spell, mimicking item at level. *)
  Spell* = POINTER TO SpellDesc;
  SpellDesc* = RECORD
    next*: Spell;
    item*: OvaRules.Item;
    level*: INTEGER;
    end*: Number
  END;

  (* An Ability or Weakness, at its signed level. *)
  Trait* = POINTER TO TraitDesc;
  TraitDesc* = RECORD
    next*: Trait;
    item*: OvaRules.Item;  (* NIL: a name OvaRules doesn't have *)
    kind*: INTEGER;        (* OvaRules.Ability or Weakness, with or without item *)
    level*: INTEGER;
    halfTV*: BOOLEAN;      (* marked: half its level counts toward TV (p. 124) *)
    mods*: Mod;            (* its Perks and Flaws (p. 83) *)
    use*: INTEGER;         (* the level, -1 to -3, of an Endurance Use tied to it; 0 if none *)
    form*: Trait;          (* a Transformation's form: counted when transformed (p. 63) *)
    spells*: Spell;        (* a Magic Ability's *)
    partner*: Sheet;       (* a Companion's or Vehicle's own sheet *)
    hasEnd-: BOOLEAN;      (* it has Perks, Flaws or Endurance Use: end is its cost *)
    end*: Number
  END;

  Attack* = POINTER TO AttackDesc;
  AttackDesc* = RECORD
    next*: Attack;
    mods*: Mod;
    telekinetic*: BOOLEAN; (* made with Telekinesis, which adds to its DX (p. 62) *)
    transformed*: BOOLEAN; (* made in the transformed form, as Miho's Mode SP *)
    use*: INTEGER;         (* an Endurance Use tied to it, as a Trait's *)
    roll*, dx*, end*: Number;
    (* What TV takes of it (PLAN.md, "The combat box"): its ROLL and DX
       in effect, less what Accurate, Inaccurate, Effective and
       Ineffective add; 1/2 and No Damage count as 0. inTV is FALSE for
       an attack made in a form the sheet isn't shown in. *)
    inTV-: BOOLEAN;
    tvRoll-, tvDX-: INTEGER
  END;

  (* The limits the user turned on (p. 21; ova_fmt's options:). *)
  Options* = RECORD
    baseZero*: BOOLEAN; baseZeroRange*: INTEGER;
    powerCeiling*: BOOLEAN; ceiling*: INTEGER;
    startingLevels*: BOOLEAN; starting*: INTEGER;
    scaledCost*, halfCostKnowledge*, combinedEffectiveness*: BOOLEAN
  END;

  Warning* = POINTER TO WarningDesc;
  WarningDesc* = RECORD
    next-: Warning;
    code-: INTEGER;
    trait-: Trait; attack-: Attack; mod-: Mod; spell-: Spell
  END;

  SheetDesc* = RECORD
    kind*: INTEGER;
    traits*: Trait;        (* in the order added *)
    attacks*: Attack;
    transformed*: BOOLEAN; (* shown in the transformed form, as Fukiko's sheet is *)
    options*: Options;
    defense*, barrier*, incorporeal*, health*, endurance*, reserve*, tv*: Number;
    hasBarrier-, hasIncorporeal-, hasReserve-: BOOLEAN;
    (* The running totals: levels (Knowledge and Ineptitude halved if
       the options say so), the Character Total, and Scaled Cost's
       points: the Abilities', and the Abilities' less the Weaknesses'. *)
    abilityLevels*, weaknessLevels*, total*, abilityPoints*, points*: Number;
    weaknessPoints-: INTEGER;  (* >= 0 *)
    warnings-: Warning     (* from the last Compute, in the order found *)
  END;

VAR
  redirectable: OvaRules.Item;

(* ---- Numbers ---- *)

PROCEDURE SetComputed(VAR n: Number; value: INTEGER; half, plus: BOOLEAN);
BEGIN n.value := value; n.half := half; n.plus := plus
END SetComputed;

PROCEDURE Set(VAR n: Number; value: INTEGER);
BEGIN SetComputed(n, value, FALSE, FALSE)
END Set;

(* Overrides n with value (1/2 if half, value+ if plus). *)
PROCEDURE Override*(VAR n: Number; value: INTEGER; half, plus: BOOLEAN);
BEGIN
  n.overridden := TRUE;
  IF half THEN n.ovValue := 0 ELSE n.ovValue := value END;
  n.ovHalf := half; n.ovPlus := plus
END Override;

(* Back to the computed value. *)
PROCEDURE Clear*(VAR n: Number);
BEGIN n.overridden := FALSE; n.ovValue := 0; n.ovHalf := FALSE; n.ovPlus := FALSE
END Clear;

(* The value in effect: the override if there is one; 1/2 is 0. *)
PROCEDURE Value*(VAR n: Number): INTEGER;
BEGIN IF n.overridden THEN RETURN n.ovValue ELSE RETURN n.value END
END Value;

PROCEDURE Half*(VAR n: Number): BOOLEAN;
BEGIN IF n.overridden THEN RETURN n.ovHalf ELSE RETURN n.half END
END Half;

PROCEDURE Plus*(VAR n: Number): BOOLEAN;
BEGIN IF n.overridden THEN RETURN n.ovPlus ELSE RETURN n.plus END
END Plus;

PROCEDURE AppendChar(c: CHAR; VAR s: ARRAY OF CHAR);
  VAR i: INTEGER;
BEGIN
  i := 0; WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END;
  IF i < LEN(s) - 1 THEN s[i] := c; s[i + 1] := 0X END
END AppendChar;

(* n in decimal, appended to s. *)
PROCEDURE AppendInt(n: INTEGER; VAR s: ARRAY OF CHAR);
  VAR d: ARRAY 12 OF CHAR; i: INTEGER;
BEGIN
  IF n < 0 THEN AppendChar("-", s); n := -n END;
  i := 0; REPEAT d[i] := CHR(ORD("0") + n MOD 10); n := n DIV 10; INC(i) UNTIL n = 0;
  WHILE i > 0 DO DEC(i); AppendChar(d[i], s) END
END AppendInt;

PROCEDURE Format(value: INTEGER; half, plus: BOOLEAN; VAR s: ARRAY OF CHAR);
BEGIN
  s[0] := 0X;
  IF half THEN COPY("1/2", s) ELSE AppendInt(value, s) END;
  IF plus THEN AppendChar("+", s) END
END Format;

(* The number in effect as the sheet writes it: "4", "1/2", "10+". *)
PROCEDURE Text*(VAR n: Number; VAR s: ARRAY OF CHAR);
BEGIN Format(Value(n), Half(n), Plus(n), s)
END Text;

(* The computed number, whatever the override. *)
PROCEDURE ComputedText*(VAR n: Number; VAR s: ARRAY OF CHAR);
BEGIN Format(n.value, n.half, n.plus, s)
END ComputedText;

(* Sets n's override from what the user typed in its box: blank clears
   it; else an integer, "1/2" if allowHalf (a DX), or an integer and
   "+" if allowPlus (an END). FALSE, n unchanged, for anything else. *)
PROCEDURE Parse*(s: ARRAY OF CHAR; allowHalf, allowPlus: BOOLEAN; VAR n: Number): BOOLEAN;
  VAR i, j, v, digits: INTEGER; neg, plus: BOOLEAN;
BEGIN
  i := 0; WHILE (i < LEN(s)) & ((s[i] = " ") OR (s[i] = 9X)) DO INC(i) END;
  j := i; WHILE (j < LEN(s)) & (s[j] # 0X) DO INC(j) END;
  WHILE (j > i) & ((s[j - 1] = " ") OR (s[j - 1] = 9X)) DO DEC(j) END;
  IF j = i THEN Clear(n); RETURN TRUE END;
  IF allowHalf & (j - i = 3) & (s[i] = "1") & (s[i + 1] = "/") & (s[i + 2] = "2") THEN
    Override(n, 0, TRUE, FALSE); RETURN TRUE
  END;
  plus := FALSE;
  IF allowPlus & (s[j - 1] = "+") THEN plus := TRUE; DEC(j) END;
  neg := FALSE;
  IF (i < j) & (s[i] = "-") THEN neg := TRUE; INC(i) END;
  v := 0; digits := 0;
  WHILE (i < j) & (s[i] >= "0") & (s[i] <= "9") & (digits < 6) DO
    v := 10 * v + ORD(s[i]) - ORD("0"); INC(i); INC(digits)
  END;
  IF (digits = 0) OR (i < j) THEN RETURN FALSE END;
  IF neg THEN v := -v END;
  Override(n, v, FALSE, plus);
  RETURN TRUE
END Parse;

PROCEDURE InitNumber(VAR n: Number);
BEGIN SetComputed(n, 0, FALSE, FALSE); Clear(n)
END InitNumber;

(* ---- Building a sheet ---- *)

PROCEDURE InitSheet*(s: Sheet; kind: INTEGER);
BEGIN
  s.kind := kind; s.traits := NIL; s.attacks := NIL; s.transformed := FALSE;
  s.options.baseZero := FALSE; s.options.baseZeroRange := 0;
  s.options.powerCeiling := FALSE; s.options.ceiling := 0;
  s.options.startingLevels := FALSE; s.options.starting := 0;
  s.options.scaledCost := FALSE; s.options.halfCostKnowledge := FALSE;
  s.options.combinedEffectiveness := FALSE;
  InitNumber(s.defense); InitNumber(s.barrier); InitNumber(s.incorporeal); InitNumber(s.health);
  InitNumber(s.endurance); InitNumber(s.reserve); InitNumber(s.tv);
  s.hasBarrier := FALSE; s.hasIncorporeal := FALSE; s.hasReserve := FALSE;
  InitNumber(s.abilityLevels); InitNumber(s.weaknessLevels); InitNumber(s.total); InitNumber(s.abilityPoints);
  InitNumber(s.points); s.weaknessPoints := 0;
  s.warnings := NIL
END InitSheet;

(* item may be NIL, for a name OvaRules doesn't have; kind then says
   which it is. A Healer or Magic Ability starts marked for TV. *)
PROCEDURE InitTrait*(t: Trait; item: OvaRules.Item; kind, level: INTEGER);
BEGIN
  t.next := NIL; t.item := item; t.kind := kind; t.level := level;
  t.halfTV := (item # NIL) & (OvaRules.HalfTV IN item.flags);
  t.mods := NIL; t.use := 0; t.form := NIL; t.spells := NIL; t.partner := NIL;
  t.hasEnd := FALSE; InitNumber(t.end)
END InitTrait;

(* cost is each time's, used where the user sets it (Mod). *)
PROCEDURE InitMod*(m: Mod; item: OvaRules.Item; times, cost: INTEGER);
BEGIN m.next := NIL; m.item := item; m.times := times; m.cost := cost
END InitMod;

PROCEDURE InitSpell*(sp: Spell; item: OvaRules.Item; level: INTEGER);
BEGIN sp.next := NIL; sp.item := item; sp.level := level; InitNumber(sp.end)
END InitSpell;

PROCEDURE InitAttack*(a: Attack);
BEGIN
  a.next := NIL; a.mods := NIL; a.telekinetic := FALSE; a.transformed := FALSE; a.use := 0;
  InitNumber(a.roll); InitNumber(a.dx); InitNumber(a.end);
  a.inTV := FALSE; a.tvRoll := 0; a.tvDX := 0
END InitAttack;

(* Each Add appends, keeping the order the items were added in. *)
PROCEDURE AddTrait*(VAR list: Trait; t: Trait);
  VAR p: Trait;
BEGIN
  t.next := NIL;
  IF list = NIL THEN list := t ELSE p := list; WHILE p.next # NIL DO p := p.next END; p.next := t END
END AddTrait;

PROCEDURE AddMod*(VAR list: Mod; m: Mod);
  VAR p: Mod;
BEGIN
  m.next := NIL;
  IF list = NIL THEN list := m ELSE p := list; WHILE p.next # NIL DO p := p.next END; p.next := m END
END AddMod;

PROCEDURE AddSpell*(t: Trait; sp: Spell);
  VAR p: Spell;
BEGIN
  sp.next := NIL;
  IF t.spells = NIL THEN t.spells := sp ELSE p := t.spells; WHILE p.next # NIL DO p := p.next END; p.next := sp END
END AddSpell;

PROCEDURE AddAttack*(s: Sheet; a: Attack);
  VAR p: Attack;
BEGIN
  a.next := NIL;
  IF s.attacks = NIL THEN s.attacks := a ELSE p := s.attacks; WHILE p.next # NIL DO p := p.next END; p.next := a END
END AddAttack;

(* ---- Warnings ---- *)

PROCEDURE Warn(s: Sheet; code: INTEGER; t: Trait; a: Attack; m: Mod; sp: Spell);
  VAR w, p: Warning;
BEGIN
  NEW(w); w.next := NIL; w.code := code; w.trait := t; w.attack := a; w.mod := m; w.spell := sp;
  IF s.warnings = NIL THEN s.warnings := w ELSE p := s.warnings; WHILE p.next # NIL DO p := p.next END; p.next := w END
END Warn;

(* ---- Traits ---- *)

PROCEDURE Has(t: Trait; flag: INTEGER): BOOLEAN;
BEGIN RETURN (t.item # NIL) & (flag IN t.item.flags)
END Has;

(* The signed levels of s's Traits that have flag, with their forms'
   when form (a Transformation's form adds to the same Abilities). *)
PROCEDURE Sum(s: Sheet; flag: INTEGER; form: BOOLEAN): INTEGER;
  VAR t, f: Trait; n: INTEGER;
BEGIN
  n := 0; t := s.traits;
  WHILE t # NIL DO
    IF Has(t, flag) THEN INC(n, t.level) END;
    IF form THEN
      f := t.form;
      WHILE f # NIL DO IF Has(f, flag) THEN INC(n, f.level) END; f := f.next END
    END;
    t := t.next
  END;
  RETURN n
END Sum;

(* TRUE if s has a Trait with flag (in its form too, when form). *)
PROCEDURE Present(s: Sheet; flag: INTEGER; form: BOOLEAN): BOOLEAN;
  VAR t, f: Trait;
BEGIN
  t := s.traits;
  WHILE t # NIL DO
    IF Has(t, flag) THEN RETURN TRUE END;
    IF form THEN
      f := t.form;
      WHILE f # NIL DO IF Has(f, flag) THEN RETURN TRUE END; f := f.next END
    END;
    t := t.next
  END;
  RETURN FALSE
END Present;

(* A table's level, 0 to +5; one past it is counted as +5, with a
   warning (two Tough Abilities, or the form's added to the base's). *)
PROCEDURE TableLevel(s: Sheet; level: INTEGER): INTEGER;
BEGIN
  IF level > MaxLevel THEN Warn(s, TableRange, NIL, NIL, NIL, NIL); RETURN MaxLevel
  ELSIF level < 0 THEN Warn(s, TableRange, NIL, NIL, NIL, NIL); RETURN 0
  ELSE RETURN level
  END
END TableLevel;

(* ---- Perks and Flaws ---- *)

PROCEDURE ModHas(list: Mod; flag: INTEGER): BOOLEAN;
BEGIN
  WHILE (list # NIL) & ~((list.item # NIL) & (flag IN list.item.flags)) DO list := list.next END;
  RETURN list # NIL
END ModHas;

(* TRUE if list has a Mod of kind (OvaRules.Perk or Flaw) with flag. *)
PROCEDURE KindHas(list: Mod; kind, flag: INTEGER): BOOLEAN;
BEGIN
  WHILE (list # NIL) & ~((list.item # NIL) & (list.item.kind = kind) & (flag IN list.item.flags)) DO
    list := list.next
  END;
  RETURN list # NIL
END KindHas;

PROCEDURE ModHasItem(list: Mod; it: OvaRules.Item): BOOLEAN;
BEGIN
  WHILE (list # NIL) & (list.item # it) DO list := list.next END;
  RETURN list # NIL
END ModHasItem;

(* The times the Perks with flag are taken, less the times the Flaws
   with it are: Accurate x2 and Inaccurate x3 make -1. *)
PROCEDURE Net(list: Mod; flag: INTEGER): INTEGER;
  VAR n: INTEGER;
BEGIN
  n := 0;
  WHILE list # NIL DO
    IF (list.item # NIL) & (flag IN list.item.flags) THEN
      IF list.item.kind = OvaRules.Perk THEN INC(n, list.times) ELSE DEC(n, list.times) END
    END;
    list := list.next
  END;
  RETURN n
END Net;

PROCEDURE ModCost(m: Mod): INTEGER;
BEGIN
  IF (m.item # NIL) & (m.item.costKind = OvaRules.FixedCost) THEN RETURN m.item.cost * m.times
  ELSE RETURN m.cost * m.times
  END
END ModCost;

(* What Endurance Use at level adds (p. 70); none outside -1 to -3. *)
PROCEDURE UseCost(level: INTEGER): INTEGER;
BEGIN
  IF (level < 0) & (level >= MinWeakness) THEN RETURN OvaRules.EnduranceUseCost(level) ELSE RETURN 0 END
END UseCost;

(* An attack's or Ability's Endurance cost (p. 83, 70): its Perks', its
   Endurance Use's, less its Flaws', never below 0. *)
PROCEDURE EndCost(list: Mod; use: INTEGER): INTEGER;
  VAR n: INTEGER;
BEGIN
  n := UseCost(use);
  WHILE list # NIL DO INC(n, ModCost(list)); list := list.next END;
  IF n < 0 THEN n := 0 END;
  RETURN n
END EndCost;

(* The warnings of each Mod: unknown, taken too often, a cost out of
   its range. t or a is the owner. *)
PROCEDURE CheckMods(s: Sheet; list: Mod; t: Trait; a: Attack);
  VAR it: OvaRules.Item;
BEGIN
  WHILE list # NIL DO
    it := list.item;
    IF it = NIL THEN Warn(s, UnknownItem, t, a, list, NIL)
    ELSE
      IF (list.times < 1) OR (list.times > it.maxTimes) THEN Warn(s, TooOften, t, a, list, NIL) END;
      IF (it.costKind = OvaRules.RangeCost)
         & ((list.cost < it.minCost) OR (list.cost > it.maxCost) OR (list.cost MOD CostStep # 0)) THEN
        Warn(s, CostRange, t, a, list, NIL)
      END
    END;
    list := list.next
  END
END CheckMods;

(* ---- The combat box (p. 105-107) ---- *)

PROCEDURE ComputeAttack(s: Sheet; a: Attack);
  VAR form: BOOLEAN; roll, dx, netRoll, netDX: INTEGER;
BEGIN
  form := s.transformed OR a.transformed;
  (* ROLL: 2 + Agile - Clumsy, or Iron-Willed - Weak-Willed for a Will
     Attack, + Combat Expert, + Accurate - Inaccurate. *)
  IF ModHas(a.mods, OvaRules.WillAttack) THEN roll := 2 + Sum(s, OvaRules.Will, form)
  ELSE roll := 2 + Sum(s, OvaRules.Agility, form)
  END;
  INC(roll, Sum(s, OvaRules.CombatSkill, form));
  IF s.options.combinedEffectiveness & (roll - 2 > CombinedLimit) THEN Warn(s, OverFive, NIL, a, NIL, NIL) END;
  netRoll := Net(a.mods, OvaRules.RollEach);
  Set(a.roll, roll + netRoll);
  (* DX: 1 + Attack + Strong - Weak (not if Ranged, unless
     Strength-Powered) + Telekinesis if made with it + Effective -
     Ineffective; 0 for No Damage, else 1/2 at 0 or less. *)
  dx := 1 + Sum(s, OvaRules.Damage, form);
  IF ~ModHas(a.mods, OvaRules.RangedAttack) OR ModHas(a.mods, OvaRules.StrengthRanged) THEN
    INC(dx, Sum(s, OvaRules.Strength, form))
  END;
  IF a.telekinetic THEN INC(dx, Sum(s, OvaRules.Telekinetic, form)) END;
  netDX := Net(a.mods, OvaRules.DamageEach);
  IF ModHas(a.mods, OvaRules.NoDamageDone) THEN Set(a.dx, 0)
  ELSIF dx + netDX <= 0 THEN SetComputed(a.dx, 0, TRUE, FALSE)
  ELSE Set(a.dx, dx + netDX)
  END;
  Set(a.end, EndCost(a.mods, a.use));
  (* What TV takes: the numbers in effect, overrides included, less what
     the Perks and Flaws added each time. *)
  a.inTV := ~a.transformed OR s.transformed;
  a.tvRoll := Value(a.roll) - netRoll;
  IF ~a.dx.overridden THEN a.tvDX := dx
  ELSIF a.dx.ovHalf THEN a.tvDX := 0
  ELSE a.tvDX := a.dx.ovValue - netDX
  END;
  IF a.tvDX < 0 THEN a.tvDX := 0 END;
  CheckMods(s, a.mods, NIL, a);
  IF ModHas(a.mods, OvaRules.NoDamageDone) & KindHas(a.mods, OvaRules.Flaw, OvaRules.DamageEach) THEN
    Warn(s, NoDamageIneffective, NIL, a, NIL, NIL)
  END;
  IF (redirectable # NIL) & ModHasItem(a.mods, redirectable)
     & ~ModHas(a.mods, OvaRules.RangedAttack) & ~ModHas(a.mods, OvaRules.StrengthRanged) THEN
    Warn(s, RedirectableAlone, NIL, a, NIL, NIL)
  END
END ComputeAttack;

(* An Ability's or Weakness's own warnings and END, and its spells'
   costs (p. 58): by the Magic's level and the spell's, "+" for an
   Ability that spends Endurance of its own (Barrier). A spell at -1 to
   -3 casts a Weakness, as Witchcraft's do, at the same costs (p. 58):
   by its size, as Acacia's curses cost (p. 134). *)
PROCEDURE ComputeTrait(s: Sheet; t: Trait);
  VAR sp: Spell; size: INTEGER;
BEGIN
  IF t.item = NIL THEN Warn(s, UnknownItem, t, NIL, NIL, NIL) END;
  IF (t.kind = OvaRules.Ability) & ((t.level < 1) OR (t.level > MaxLevel))
     OR (t.kind = OvaRules.Weakness) & ((t.level > -1) OR (t.level < MinWeakness)) THEN
    Warn(s, LevelRange, t, NIL, NIL, NIL)
  END;
  t.hasEnd := (t.mods # NIL) OR (t.use # 0);
  IF t.hasEnd THEN Set(t.end, EndCost(t.mods, t.use)) ELSE Set(t.end, 0) END;
  CheckMods(s, t.mods, t, NIL);
  sp := t.spells;
  WHILE sp # NIL DO
    size := ABS(sp.level);
    IF (t.level >= 1) & (t.level <= MaxLevel)
       & ((sp.level >= 1) & (sp.level <= MaxLevel) OR (sp.level <= -1) & (sp.level >= MinWeakness)) THEN
      SetComputed(sp.end, OvaRules.SpellCost(t.level, size), FALSE,
        (sp.item # NIL) & (OvaRules.OwnCost IN sp.item.flags))
    ELSE
      Set(sp.end, 0); Warn(s, SpellRange, t, NIL, NIL, sp)
    END;
    sp := sp.next
  END
END ComputeTrait;

(* An alternate Defense Roll, 2 + the levels of what has flag (p. 51,
   55), into n; has, whether the character has one. *)
PROCEDURE ComputeAlternate(s: Sheet; flag: INTEGER; VAR n: Number; VAR has: BOOLEAN);
  VAR form: BOOLEAN; d: INTEGER;
BEGIN
  form := s.transformed;
  has := Present(s, flag, form);
  IF has THEN
    d := 2 + Sum(s, flag, form);
    Set(n, d);
    IF s.options.combinedEffectiveness & (d - 2 > CombinedLimit) THEN Warn(s, OverFive, NIL, NIL, NIL, NIL) END
  ELSE Set(n, 0)
  END
END ComputeAlternate;

(* Defense (p. 105), and Barrier's (p. 51) and Incorporeal Form's (p.
   55). *)
PROCEDURE ComputeDefense(s: Sheet);
  VAR d: INTEGER;
BEGIN
  d := 2 + Sum(s, OvaRules.DefenseRoll, s.transformed);
  Set(s.defense, d);
  IF s.options.combinedEffectiveness & (d - 2 > CombinedLimit) THEN Warn(s, OverFive, NIL, NIL, NIL, NIL) END;
  ComputeAlternate(s, OvaRules.SecondDefense, s.barrier, s.hasBarrier);
  ComputeAlternate(s, OvaRules.ThirdDefense, s.incorporeal, s.hasIncorporeal)
END ComputeDefense;

(* Health and Endurance (p. 107): from the sheet's base, + the Tough and
   Vigorous table (p. 63, 65), - 10 a level of Frail and Languid (p.
   71, 73); and Endurance Reserve's separate store (p. 53). *)
PROCEDURE ComputeHealth(s: Sheet);
  VAR form: BOOLEAN; base: INTEGER;
BEGIN
  form := s.transformed;
  CASE s.kind OF
    Character: base := CharacterBase
  | CompanionSheet: base := CompanionBase
  | MinionSheet, ExtraSheet: base := MinionBase
  END;
  Set(s.health, base + OvaRules.ToughBonus(TableLevel(s, Sum(s, OvaRules.HealthTable, form)))
    + 10 * Sum(s, OvaRules.HealthTens, form));
  Set(s.endurance, base + OvaRules.ToughBonus(TableLevel(s, Sum(s, OvaRules.EnduranceTable, form)))
    + 10 * Sum(s, OvaRules.EnduranceTens, form));
  s.hasReserve := Present(s, OvaRules.Reserve, form);
  IF s.hasReserve THEN Set(s.reserve, OvaRules.ReserveBonus(TableLevel(s, Sum(s, OvaRules.Reserve, form))))
  ELSE Set(s.reserve, 0)
  END
END ComputeHealth;

(* Half of a marked Ability's level, rounded up (p. 124). *)
PROCEDURE HalfTVLevel(t: Trait): INTEGER;
BEGIN
  IF t.halfTV & (t.kind = OvaRules.Ability) & (t.level > 0) & ~Has(t, OvaRules.NoTV) THEN
    RETURN (t.level + 1) DIV 2
  ELSE RETURN 0
  END
END HalfTVLevel;

(* TV (p. 124): the best ROLL, Defense and DX, without the Perks and
   Flaws that add to them each time (Attack.tvRoll, tvDX), + Armored +
   the signed levels that change Health and Endurance + half of each
   marked Ability's; a Companion's 4 less, at least 1. With no attack,
   the plain one: 2 + Agile + Combat Expert - Clumsy, 1 + Attack +
   Strong - Weak. *)
PROCEDURE ComputeTV(s: Sheet);
  VAR form, any: BOOLEAN; a: Attack; t, f: Trait; roll, dx, def, tv: INTEGER;
BEGIN
  form := s.transformed;
  any := FALSE; roll := 0; dx := 0; a := s.attacks;
  WHILE a # NIL DO
    IF a.inTV THEN
      IF ~any OR (a.tvRoll > roll) THEN roll := a.tvRoll END;
      IF ~any OR (a.tvDX > dx) THEN dx := a.tvDX END;
      any := TRUE
    END;
    a := a.next
  END;
  IF ~any THEN
    roll := 2 + Sum(s, OvaRules.Agility, form) + Sum(s, OvaRules.CombatSkill, form);
    dx := 1 + Sum(s, OvaRules.Damage, form) + Sum(s, OvaRules.Strength, form);
    IF dx < 0 THEN dx := 0 END
  END;
  def := Value(s.defense);
  IF s.hasBarrier & (Value(s.barrier) > def) THEN def := Value(s.barrier) END;
  IF s.hasIncorporeal & (Value(s.incorporeal) > def) THEN def := Value(s.incorporeal) END;
  tv := roll + def + dx + Sum(s, OvaRules.Armor, form)
    + Sum(s, OvaRules.HealthTable, form) + Sum(s, OvaRules.HealthTens, form)
    + Sum(s, OvaRules.EnduranceTable, form) + Sum(s, OvaRules.EnduranceTens, form);
  t := s.traits;
  WHILE t # NIL DO
    INC(tv, HalfTVLevel(t));
    IF form THEN f := t.form; WHILE f # NIL DO INC(tv, HalfTVLevel(f)); f := f.next END END;
    t := t.next
  END;
  IF s.kind = CompanionSheet THEN
    DEC(tv, CompanionTV);
    IF tv < 1 THEN tv := 1 END
  ELSIF s.kind = ExtraSheet THEN tv := 1
  END;
  Set(s.tv, tv)
END ComputeTV;

(* ---- The totals and the limits (p. 21) ---- *)

(* Scaled Cost's points for a level's size (p. 21): 1, 2, 4, 8, 15. *)
PROCEDURE Scaled(size: INTEGER): INTEGER;
BEGIN
  IF size <= 0 THEN RETURN 0
  ELSIF size >= MaxLevel THEN RETURN 15
  ELSE RETURN SHORT(ASH(1, size - 1))
  END
END Scaled;

(* n halved, rounded away from 0: Knowledge 3 counts 2, Ineptitude -3
   counts -2 (p. 57, "round up"). *)
PROCEDURE HalfUp(n: INTEGER): INTEGER;
BEGIN IF n >= 0 THEN RETURN (n + 1) DIV 2 ELSE RETURN -((1 - n) DIV 2) END
END HalfUp;

(* The totals of the character's own Traits (not a form's, which
   Transformation's level pays for, p. 63), then the limits on them. *)
PROCEDURE ComputeTotals(s: Sheet);
  VAR t: Trait; half: BOOLEAN; lv, pts, abilities, abilityPoints, weaknesses, spent, measure: INTEGER;
BEGIN
  half := s.options.halfCostKnowledge & (s.options.baseZero OR s.options.powerCeiling OR s.options.scaledCost);
  abilities := 0; abilityPoints := 0; weaknesses := 0; s.weaknessPoints := 0;
  t := s.traits;
  WHILE t # NIL DO
    lv := t.level; pts := Scaled(ABS(lv));
    IF half & Has(t, OvaRules.HalfCost) THEN lv := HalfUp(lv); pts := HalfUp(pts) END;
    IF t.kind = OvaRules.Ability THEN INC(abilities, lv); INC(abilityPoints, pts)
    ELSE INC(weaknesses, lv); INC(s.weaknessPoints, pts)
    END;
    t := t.next
  END;
  Set(s.abilityLevels, abilities); Set(s.weaknessLevels, weaknesses);
  Set(s.total, Value(s.abilityLevels) + Value(s.weaknessLevels));
  Set(s.abilityPoints, abilityPoints);
  Set(s.points, Value(s.abilityPoints) - s.weaknessPoints);
  IF s.options.scaledCost THEN measure := Value(s.points); spent := Value(s.abilityPoints)
  ELSE measure := Value(s.total); spent := Value(s.abilityLevels)
  END;
  IF s.options.baseZero & (ABS(measure) > s.options.baseZeroRange) THEN
    Warn(s, BaseZeroBroken, NIL, NIL, NIL, NIL)
  END;
  IF s.options.powerCeiling & (spent > s.options.ceiling) THEN Warn(s, CeilingBroken, NIL, NIL, NIL, NIL) END;
  IF s.options.startingLevels THEN
    IF s.options.scaledCost THEN measure := s.weaknessPoints ELSE measure := -Value(s.weaknessLevels) END;
    IF spent > s.options.starting + measure THEN Warn(s, StartingBroken, NIL, NIL, NIL, NIL) END
  END
END ComputeTotals;

(* Every number of s and of its partners' sheets, and their warnings. *)
PROCEDURE Compute*(s: Sheet);
  VAR t, f: Trait; a: Attack;
BEGIN
  s.warnings := NIL;
  t := s.traits;
  WHILE t # NIL DO
    ComputeTrait(s, t);
    f := t.form; WHILE f # NIL DO ComputeTrait(s, f); f := f.next END;
    IF t.partner # NIL THEN Compute(t.partner) END;
    t := t.next
  END;
  ComputeTotals(s);
  a := s.attacks; WHILE a # NIL DO ComputeAttack(s, a); a := a.next END;
  ComputeDefense(s);
  ComputeHealth(s);
  ComputeTV(s)
END Compute;

BEGIN
  redirectable := OvaRules.Find("Redirectable")
END OvaCalc.
