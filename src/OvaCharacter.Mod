MODULE OvaCharacter; (* The character being built: OvaCalc's sheet, with its names and text *)

(* PLAN.md, "Files" and "Modules". A Character is an OvaCalc.Sheet, its
   Traits, Mods, Attacks and Spells extended with what OvaCalc doesn't
   need: names, details, notes, descriptions, the background and the
   fluff, and the flags saying which optional keys a file had, so that
   a file loaded and saved formats the same in ova_fmt.

   A file is read by OvaEntities, po_ova_fmt's loader (copied), so the
   generator reads exactly what po_ova_fmt reads, and then built into a
   Character. A number the file's overrides: key lists is an override.
   Every other number the file holds is compared with the one OvaCalc
   computes; one that differs is kept as an override too, with a
   notice saying so: the file is the user's (a GM's ruling, a hand
   edit, or a case the rules here don't cover), and nothing in it is
   lost.

   Imports nothing of the window, so its tests need no display. *)

IMPORT Fyaml, FyamlStreams, OvaCalc, OvaEntities, OvaRules, OvaText, Ropes;

CONST
  NFluff* = OvaEntities.NFluff;
  (* The Defense values, in the order a combat: block's defense holds
     them (BestDefense) *)
  DefenseSlot* = 0; BarrierSlot* = 1; IncorporealSlot* = 2;

TYPE
  Rope = Ropes.Rope;

  Note* = POINTER TO NoteDesc;
  NoteDesc* = RECORD
    next*: Note;
    header*, text*: Rope
  END;

  Character* = POINTER TO CharacterDesc;
  CharacterDesc* = RECORD (OvaCalc.SheetDesc)
    label*: Rope;  (* a partner's sheet: "Companion" or "Vehicle"; NIL for the character *)
    name*: Rope;
    hasPlayer*, hasPortrait*: BOOLEAN;
    player*, portrait*: Rope;  (* portrait: the image's path, relative to the file *)
    hasTagline*, hasSummary*, hasBackground*, hasAppearance*, hasPersonality*, hasCharacterHooks*,
    hasOtherNotes*: BOOLEAN;
    tagline*, summary*, background*, appearance*, personality*, characterHooks*, otherNotes*: Rope;
    (* npc-type: OvaEntities.Heroic, Secondary or Extra; it sets the
       sheet's kind (SetNpcType). *)
    hasNpcType-: BOOLEAN; npcType-: INTEGER;
    notes*: Note;
    hasFluff*: BOOLEAN;
    hasFluffField*: ARRAY NFluff OF BOOLEAN;
    fluff*: ARRAY NFluff OF Rope;
    hasOptions*: BOOLEAN;  (* an options: block, even an empty one *)
    isFragment*: BOOLEAN;  (* an NPC Fragment, or a simple Companion *)
    hasCombat*: BOOLEAN;   (* a combat: block: a Fragment or Companion may have none *)
    hasThreatValue*: BOOLEAN;
    (* The file gave one Defense though Barrier or Incorporeal Form gives
       another, as the book's Sample NPCs have it: the best, saved so,
       the others left out (SingleDefense). singleSlot, the slot it was
       read into, BestDefense's then. *)
    omitAlternates*: BOOLEAN; singleSlot: INTEGER;
    hasCombatNotes*: BOOLEAN; combatNotes*: Rope
  END;

  (* An Ability or Weakness. *)
  Trait* = POINTER TO TraitDesc;
  TraitDesc* = RECORD (OvaCalc.TraitDesc)
    name*: Rope;
    hasDetail*: BOOLEAN; detail*: Rope;
    hasNote*: BOOLEAN; note*: Rope;
    hasHalfTV*: BOOLEAN    (* halfTV is written: threat-value-half; else the rules' *)
  END;

  (* A Perk or Flaw. *)
  Mod* = POINTER TO ModDesc;
  ModDesc* = RECORD (OvaCalc.ModDesc)
    name*: Rope;
    hasDetail*: BOOLEAN; detail*: Rope;
    isFlaw*: BOOLEAN;   (* which list it is in, whether or not OvaRules has it *)
    hasCost*: BOOLEAN   (* its cost is written: chosen (Cancel, Requirement, Unique), or the file's *)
  END;

  Attack* = POINTER TO AttackDesc;
  AttackDesc* = RECORD (OvaCalc.AttackDesc)
    name*: Rope;
    hasAffinity*: BOOLEAN; affinity*: Rope;
    hasDescription*: BOOLEAN; description*: Rope
  END;

  (* A file's characters, in its order; and its entities. *)
  Characters* = POINTER TO ARRAY OF Character;
  Entities* = POINTER TO ARRAY OF OvaEntities.Entity;

  Spell* = POINTER TO SpellDesc;
  SpellDesc* = RECORD (OvaCalc.SpellDesc)
    name*, ability*: Rope
  END;

VAR
  (* What the last Load found to say about the file: each number kept
     as an override. *)
  notices-: OvaText.List;

(* ---- Endurance Use ---- *)

(* Whether name, or name and detail as "Name (detail)", is target,
   ignoring case. *)
PROCEDURE Names(name, detail, target: Rope): BOOLEAN;
  VAR full: Rope;
BEGIN
  target := OvaText.FoldCI(OvaText.Trim(target));
  full := name;
  IF detail # NIL THEN OvaText.Add(full, " ("); full := Ropes.Cat(full, detail); OvaText.Add(full, ")") END;
  RETURN (target # NIL) & (Ropes.Equal(OvaText.FoldCI(name), target) OR Ropes.Equal(OvaText.FoldCI(full), target))
END Names;

(* Ties each Endurance Use in list to the Ability in list, or else the
   attack of s, that its detail names (PLAN.md, "Changes to ova_fmt":
   it needs no key of its own), setting their use; one naming nothing
   ties to nothing. *)
PROCEDURE LinkList(list: OvaCalc.Trait; s: OvaCalc.Sheet);
  VAR w, t: OvaCalc.Trait; a: OvaCalc.Attack; found: BOOLEAN;
BEGIN
  w := list;
  WHILE w # NIL DO
    IF (w.kind = OvaRules.Weakness) & (w.item # NIL) & (OvaRules.CostUp IN w.item.flags) & w(Trait).hasDetail THEN
      found := FALSE; t := list;
      WHILE ~found & (t # NIL) DO
        IF (t.kind = OvaRules.Ability) & Names(t(Trait).name, t(Trait).detail, w(Trait).detail) THEN
          t.use := w.level; found := TRUE
        END;
        t := t.next
      END;
      a := s.attacks;
      WHILE ~found & (a # NIL) DO
        IF Names(a(Attack).name, NIL, w(Trait).detail) THEN a.use := w.level; found := TRUE END;
        a := a.next
      END
    END;
    w := w.next
  END
END LinkList;

PROCEDURE ClearUse(list: OvaCalc.Trait);
BEGIN WHILE list # NIL DO list.use := 0; list := list.next END
END ClearUse;

(* Every Endurance Use of s, its Transformations' forms and its
   partners, tied to what it names. *)
PROCEDURE Link(s: OvaCalc.Sheet);
  VAR t: OvaCalc.Trait; a: OvaCalc.Attack;
BEGIN
  ClearUse(s.traits);
  a := s.attacks; WHILE a # NIL DO a.use := 0; a := a.next END;
  t := s.traits;
  WHILE t # NIL DO
    ClearUse(t.form);
    t := t.next
  END;
  LinkList(s.traits, s);
  t := s.traits;
  WHILE t # NIL DO
    LinkList(t.form, s);
    IF t.partner # NIL THEN Link(t.partner) END;
    t := t.next
  END
END Link;

(* Every number of c computed again, after a change: what OvaCalc.Compute
   does, with each Endurance Use tied first. *)
PROCEDURE Recompute*(c: Character);
BEGIN Link(c); OvaCalc.Compute(c)
END Recompute;

(* ---- Building from what OvaEntities read ---- *)

PROCEDURE Find(name: Rope): OvaRules.Item;
  VAR c: OvaText.String;
BEGIN c := OvaText.Chars(name); RETURN OvaRules.Find(c^)
END Find;

PROCEDURE InitCharacter(c: Character; kind: INTEGER);
  VAR i: INTEGER;
BEGIN
  OvaCalc.InitSheet(c, kind);
  c.label := NIL; c.name := NIL;
  c.hasPlayer := FALSE; c.hasPortrait := FALSE; c.player := NIL; c.portrait := NIL;
  c.hasTagline := FALSE; c.hasSummary := FALSE; c.hasBackground := FALSE; c.hasAppearance := FALSE;
  c.hasPersonality := FALSE; c.hasCharacterHooks := FALSE; c.hasOtherNotes := FALSE;
  c.tagline := NIL; c.summary := NIL; c.background := NIL; c.appearance := NIL;
  c.personality := NIL; c.characterHooks := NIL; c.otherNotes := NIL;
  c.hasNpcType := FALSE; c.npcType := OvaEntities.Heroic;
  c.notes := NIL;
  c.hasFluff := FALSE;
  FOR i := 0 TO NFluff - 1 DO c.hasFluffField[i] := FALSE; c.fluff[i] := NIL END;
  c.hasOptions := FALSE; c.isFragment := FALSE;
  c.hasCombat := TRUE; c.hasThreatValue := TRUE; c.omitAlternates := FALSE; c.singleSlot := DefenseSlot;
  c.hasCombatNotes := FALSE; c.combatNotes := NIL
END InitCharacter;

(* The sheet kind of an NPC type (p. 123-124): a Heroic NPC's is a
   character's, a Secondary's a Companion's, an Extra's its own; no type
   is a character's. *)
PROCEDURE KindOf(has: BOOLEAN; npcType: INTEGER): INTEGER;
BEGIN
  IF ~has OR (npcType = OvaEntities.Heroic) THEN RETURN OvaCalc.Character
  ELSIF npcType = OvaEntities.Secondary THEN RETURN OvaCalc.CompanionSheet
  ELSE RETURN OvaCalc.ExtraSheet
  END
END KindOf;

(* Sets c's NPC type (has FALSE: none), and so its sheet's kind: Recompute
   after. *)
PROCEDURE SetNpcType*(c: Character; has: BOOLEAN; npcType: INTEGER);
BEGIN
  ASSERT(~has OR (npcType >= OvaEntities.Heroic) & (npcType <= OvaEntities.Extra));
  c.hasNpcType := has;
  IF has THEN c.npcType := npcType ELSE c.npcType := OvaEntities.Heroic END;
  c.kind := KindOf(has, npcType)
END SetNpcType;

(* A new, empty character. *)
PROCEDURE New*(): Character;
  VAR c: Character;
BEGIN NEW(c); InitCharacter(c, OvaCalc.Character); RETURN c
END New;

(* l's Perks (isFlaw FALSE) or Flaws, added to mods. *)
PROCEDURE Mods(l: OvaEntities.List; isFlaw: BOOLEAN; VAR mods: OvaCalc.Mod);
  VAR i, times, cost: INTEGER; pf: OvaEntities.PerkFlaw; m: Mod;
BEGIN
  FOR i := 0 TO l.n - 1 DO
    pf := l.items[i](OvaEntities.PerkFlaw);
    times := 1; IF pf.hasCountsAs THEN times := pf.countsAs END;
    cost := 0; IF pf.hasCost THEN cost := pf.cost END;
    NEW(m); OvaCalc.InitMod(m, Find(pf.name), times, cost);
    m.name := pf.name; m.hasDetail := pf.hasDetail; m.detail := pf.detail;
    m.isFlaw := isFlaw; m.hasCost := pf.hasCost;
    OvaCalc.AddMod(mods, m)
  END
END Mods;

PROCEDURE SubTrait(x: OvaEntities.SubItem; kind: INTEGER): Trait;
  VAR t: Trait;
BEGIN
  NEW(t); OvaCalc.InitTrait(t, Find(x.name), kind, x.level);
  t.name := x.name; t.hasDetail := x.hasDetail; t.detail := x.detail;
  t.hasNote := x.hasNote; t.note := x.note;
  t.hasHalfTV := x.hasThreatValueHalf;
  IF x.hasThreatValueHalf THEN t.halfTV := x.threatValueHalf END;
  Mods(x.perks, FALSE, t.mods); Mods(x.flaws, TRUE, t.mods);
  RETURN t
END SubTrait;

PROCEDURE SubTraits(l: OvaEntities.List; kind: INTEGER; VAR list: OvaCalc.Trait);
  VAR i: INTEGER;
BEGIN
  FOR i := 0 TO l.n - 1 DO OvaCalc.AddTrait(list, SubTrait(l.items[i](OvaEntities.SubItem), kind)) END
END SubTraits;

PROCEDURE Attacks(x: OvaEntities.Combat; c: Character);
  VAR i: INTEGER; y: OvaEntities.Attack; a: Attack;
BEGIN
  c.hasCombat := x.hasCombat; c.hasThreatValue := x.hasThreatValue;
  c.hasCombatNotes := x.hasNotes; c.combatNotes := x.notes;
  c.transformed := x.transformed;
  FOR i := 0 TO x.attacks.n - 1 DO
    y := x.attacks.items[i](OvaEntities.Attack);
    NEW(a); OvaCalc.InitAttack(a);
    a.name := y.name; a.hasAffinity := y.hasAffinity; a.affinity := y.affinity;
    a.hasDescription := y.hasDescription; a.description := y.description;
    a.telekinetic := y.telekinesis; a.transformed := y.transformed;
    Mods(y.perks, FALSE, a.mods); Mods(y.flaws, TRUE, a.mods);
    OvaCalc.AddAttack(c, a)
  END
END Attacks;

(* A Companion's sheet (a Secondary NPC's), or a Vehicle's (a
   character's). *)
PROCEDURE Partner(x: OvaEntities.SubEntity): Character;
  VAR c: Character;
BEGIN
  NEW(c);
  IF Ropes.EqualString(x.label, "Companion") THEN InitCharacter(c, OvaCalc.CompanionSheet)
  ELSE InitCharacter(c, OvaCalc.Character)
  END;
  c.label := x.label; c.name := x.name; c.isFragment := x.isFragment;
  SubTraits(x.abilities, OvaRules.Ability, c.traits);
  SubTraits(x.weaknesses, OvaRules.Weakness, c.traits);
  Attacks(x.combat, c);
  RETURN c
END Partner;

(* e's character, every number computed, none overridden: its
   Abilities, then its Weaknesses, each in e's (sorted) order, its
   attacks in the file's. *)
PROCEDURE Build*(e: OvaEntities.Entity): Character;
  VAR c: Character; t: Trait; a: OvaEntities.Ability; w: OvaEntities.Weakness; sp: OvaEntities.Spell;
    s: Spell; n, last: Note; x: OvaEntities.Note; i, j: INTEGER;
BEGIN
  c := New();
  c.name := e.name;
  c.hasPlayer := e.hasPlayer; c.player := e.player;
  c.hasPortrait := e.hasPortrait; c.portrait := e.portrait;
  c.hasTagline := e.hasTagline; c.tagline := e.tagline;
  c.hasSummary := e.hasSummary; c.summary := e.summary;
  c.hasBackground := e.hasBackground; c.background := e.background;
  c.hasAppearance := e.hasAppearance; c.appearance := e.appearance;
  c.hasPersonality := e.hasPersonality; c.personality := e.personality;
  c.hasCharacterHooks := e.hasCharacterHooks; c.characterHooks := e.characterHooks;
  SetNpcType(c, e.hasNpcType, e.npcType);
  c.hasOtherNotes := e.hasOtherNotes; c.otherNotes := e.otherNotes;
  c.isFragment := e.isFragment;
  FOR i := 0 TO e.abilities.n - 1 DO
    a := e.abilities.items[i](OvaEntities.Ability);
    t := SubTrait(a, OvaRules.Ability);
    SubTraits(a.subAbilities, OvaRules.Ability, t.form);
    SubTraits(a.subWeaknesses, OvaRules.Weakness, t.form);
    FOR j := 0 TO a.spells.n - 1 DO
      sp := a.spells.items[j](OvaEntities.Spell);
      NEW(s); OvaCalc.InitSpell(s, Find(sp.ability), sp.level);
      s.name := sp.name; s.ability := sp.ability;
      OvaCalc.AddSpell(t, s)
    END;
    IF a.subEntity # NIL THEN t.partner := Partner(a.subEntity) END;
    OvaCalc.AddTrait(c.traits, t)
  END;
  FOR i := 0 TO e.weaknesses.n - 1 DO
    w := e.weaknesses.items[i](OvaEntities.Weakness);
    NEW(t); OvaCalc.InitTrait(t, Find(w.name), OvaRules.Weakness, w.level);
    t.name := w.name; t.hasDetail := w.hasDetail; t.detail := w.detail; t.hasNote := FALSE; t.note := NIL;
    t.hasHalfTV := FALSE;
    OvaCalc.AddTrait(c.traits, t)
  END;
  Attacks(e.combat, c);
  last := NIL;
  FOR i := 0 TO e.notes.n - 1 DO
    x := e.notes.items[i](OvaEntities.Note);
    NEW(n); n.next := NIL; n.header := x.header; n.text := x.text;
    IF last = NIL THEN c.notes := n ELSE last.next := n END;
    last := n
  END;
  c.hasFluff := e.hasFluff;
  FOR i := 0 TO NFluff - 1 DO c.hasFluffField[i] := e.hasFluffField[i]; c.fluff[i] := e.fluff[i] END;
  c.hasOptions := e.hasOptions;
  IF e.hasOptions THEN
    c.options.baseZero := e.options.hasBaseZero; c.options.baseZeroRange := e.options.baseZero;
    c.options.powerCeiling := e.options.hasPowerCeiling; c.options.ceiling := e.options.powerCeiling;
    c.options.startingLevels := e.options.hasStartingLevels; c.options.starting := e.options.startingLevels;
    c.options.scaledCost := e.options.scaledCost;
    c.options.halfCostKnowledge := e.options.halfCostKnowledge;
    c.options.combinedEffectiveness := e.options.combinedEffectiveness
  END;
  Recompute(c);
  RETURN c
END Build;

(* ---- The file's numbers ---- *)

(* Notes that where's what is file in the file and computed by the
   rules, kept as an override. *)
PROCEDURE Notice(where: Rope; what: ARRAY OF CHAR; file, computed: ARRAY OF CHAR);
  VAR r: Rope;
BEGIN
  r := where; OvaText.Add(r, ": "); OvaText.Add(r, what); OvaText.Add(r, " is ");
  OvaText.Add(r, file); OvaText.Add(r, " in the file, ");
  OvaText.Add(r, computed); OvaText.Add(r, " by the rules: kept as an override");
  OvaText.Append(notices, r)
END Notice;

(* c's best Defense value, its slot: the Defense, or an alternate c has
   that is higher than those before it. *)
PROCEDURE BestDefense*(c: Character): INTEGER;
  VAR best, value: INTEGER;
BEGIN
  best := DefenseSlot; value := OvaCalc.Value(c.defense);
  IF c.hasBarrier & (OvaCalc.Value(c.barrier) > value) THEN
    best := BarrierSlot; value := OvaCalc.Value(c.barrier)
  END;
  IF c.hasIncorporeal & (OvaCalc.Value(c.incorporeal) > value) THEN best := IncorporealSlot END;
  RETURN best
END BestDefense;

(* Whether c's defense is saved as one value, and which, slot: the file
   gave one (omitAlternates), and the only value overridden, if any, is
   the one it was read into. It is saved, or else the best. *)
PROCEDURE SingleDefense*(c: Character; VAR slot: INTEGER): BOOLEAN;
  VAR n: INTEGER;
BEGIN
  n := 0; slot := BestDefense(c);
  IF c.defense.overridden THEN INC(n); slot := DefenseSlot END;
  IF c.barrier.overridden THEN INC(n); slot := BarrierSlot END;
  IF c.incorporeal.overridden THEN INC(n); slot := IncorporealSlot END;
  RETURN c.omitAlternates & ((n = 0) OR (n = 1) & (slot = c.singleSlot))
END SingleDefense;

(* The file's text for n: n's override if listed (the mapping's
   overrides: names it), or if it differs from the computed number,
   with a notice. Text that isn't a number for n is noted and dropped,
   the computed number kept. *)
PROCEDURE Adopt(VAR n: OvaCalc.Number; file: Rope; allowHalf, allowPlus, listed: BOOLEAN; where: Rope;
                what: ARRAY OF CHAR);
  VAR f: OvaText.String; computed, got: ARRAY 32 OF CHAR; t: OvaCalc.Number; r: Rope;
BEGIN
  f := OvaText.Chars(file);
  OvaCalc.ComputedText(n, computed);
  t := n; OvaCalc.Clear(t);
  IF ~OvaCalc.Parse(f^, allowHalf, allowPlus, t) OR ~t.overridden THEN
    r := where; OvaText.Add(r, ": "); OvaText.Add(r, what); OvaText.Add(r, " is ");
    OvaText.Add(r, f^); OvaText.Add(r, " in the file, not a number: ");
    OvaText.Add(r, computed); OvaText.Add(r, " by the rules is used");
    OvaText.Append(notices, r)
  ELSE
    OvaCalc.Text(t, got);
    IF listed THEN n := t
    ELSIF got # computed THEN n := t; Notice(where, what, got, computed)
    END
  END
END Adopt;

PROCEDURE AdoptInt(VAR n: OvaCalc.Number; i: INTEGER; listed: BOOLEAN; where: Rope; what: ARRAY OF CHAR);
BEGIN Adopt(n, OvaText.Int(i), FALSE, FALSE, listed, where, what)
END AdoptInt;

(* where, ": ", and name. *)
PROCEDURE Within(where, name: Rope): Rope;
  VAR r: Rope;
BEGIN r := where; OvaText.Add(r, ": "); RETURN Ropes.Cat(r, name)
END Within;

(* The file's value v for Defense slot slot of c. *)
PROCEDURE AdoptDefense(c: Character; slot: INTEGER; v: Rope; listed: BOOLEAN; where: Rope);
BEGIN
  CASE slot OF
    DefenseSlot: Adopt(c.defense, v, FALSE, FALSE, listed, where, "DEFENSE")
  | BarrierSlot: Adopt(c.barrier, v, FALSE, FALSE, listed, where, "Barrier's DEFENSE")
  | IncorporealSlot: Adopt(c.incorporeal, v, FALSE, FALSE, listed, where, "Incorporeal Form's DEFENSE")
  END
END AdoptDefense;

(* The Defense values of x's defense: one is the best of c's, two its
   Defense and its first alternate, three its Defense, Barrier's and
   Incorporeal Form's (ova_fmt allows no more). *)
PROCEDURE AdoptDefenses(x: OvaEntities.Combat; c: Character; where: Rope);
  VAR v: ARRAY 3 OF Rope; n: INTEGER; from, slash: LONGINT; second: INTEGER;
BEGIN
  n := 0; from := 0; slash := Ropes.IndexChar(x.defense, "/", 0);
  WHILE (slash >= 0) & (n < 2) DO
    v[n] := Ropes.Substring(x.defense, from, slash - from); INC(n);
    from := slash + 1; slash := Ropes.IndexChar(x.defense, "/", from)
  END;
  v[n] := Ropes.Substring(x.defense, from, Ropes.Length(x.defense) - from); INC(n);
  IF n = 1 THEN
    c.omitAlternates := c.hasBarrier OR c.hasIncorporeal;
    c.singleSlot := BestDefense(c);
    AdoptDefense(c, c.singleSlot, v[0], OvaEntities.OvDefense IN x.overrides, where)
  ELSE
    AdoptDefense(c, DefenseSlot, v[0], OvaEntities.OvDefense IN x.overrides, where);
    IF n = 3 THEN
      AdoptDefense(c, BarrierSlot, v[1], OvaEntities.OvDefense2 IN x.overrides, where);
      AdoptDefense(c, IncorporealSlot, v[2], OvaEntities.OvDefense3 IN x.overrides, where)
    ELSE
      IF ~c.hasBarrier & c.hasIncorporeal THEN second := IncorporealSlot ELSE second := BarrierSlot END;
      AdoptDefense(c, second, v[1], OvaEntities.OvDefense2 IN x.overrides, where)
    END
  END
END AdoptDefenses;

(* The numbers of a combat: block but TV. *)
PROCEDURE AdoptCombat(x: OvaEntities.Combat; c: Character; where: Rope);
  VAR i: INTEGER; y: OvaEntities.Attack; a: OvaCalc.Attack; at: Rope;
BEGIN
  IF ~x.hasCombat THEN RETURN END;
  a := c.attacks;
  FOR i := 0 TO x.attacks.n - 1 DO
    y := x.attacks.items[i](OvaEntities.Attack);
    at := Within(where, y.name);
    AdoptInt(a.roll, y.roll, OvaEntities.OvRoll IN y.overrides, at, "ROLL");
    Adopt(a.dx, y.dx, TRUE, FALSE, OvaEntities.OvDx IN y.overrides, at, "DX");
    AdoptInt(a.end, y.endurance, OvaEntities.OvEndurance IN y.overrides, at, "END");
    a := a.next
  END;
  AdoptDefenses(x, c, where);
  AdoptInt(c.health, x.health, OvaEntities.OvHealth IN x.overrides, where, "HEALTH");
  AdoptInt(c.endurance, x.endurance, OvaEntities.OvEndurance IN x.overrides, where, "ENDURANCE")
END AdoptCombat;

PROCEDURE AdoptSubItems(l: OvaEntities.List; t: OvaCalc.Trait; where: Rope);
  VAR i: INTEGER; x: OvaEntities.SubItem;
BEGIN
  FOR i := 0 TO l.n - 1 DO
    x := l.items[i](OvaEntities.SubItem);
    IF x.hasEndurance THEN
      AdoptInt(t.end, x.endurance, OvaEntities.OvEndurance IN x.overrides, Within(where, x.name), "END")
    END;
    t := t.next
  END
END AdoptSubItems;

(* Every number but TV, which is computed from them, and then TV. *)
PROCEDURE AdoptNumbers(e: OvaEntities.Entity; c: Character);
  VAR i, j: INTEGER; a: OvaEntities.Ability; t: OvaCalc.Trait; sp: OvaCalc.Spell; x: OvaEntities.Spell;
    p: Character;
BEGIN
  t := c.traits;
  FOR i := 0 TO e.abilities.n - 1 DO
    a := e.abilities.items[i](OvaEntities.Ability);
    IF a.hasEndurance THEN
      AdoptInt(t.end, a.endurance, OvaEntities.OvEndurance IN a.overrides, Within(c.name, a.name), "END")
    END;
    AdoptSubItems(a.subAbilities, t.form, Within(c.name, a.name));
    sp := t.spells;
    FOR j := 0 TO a.spells.n - 1 DO
      x := a.spells.items[j](OvaEntities.Spell);
      Adopt(sp.end, x.endurance, FALSE, TRUE, OvaEntities.OvEndurance IN x.overrides, Within(c.name, x.name), "END");
      sp := sp.next
    END;
    IF a.subEntity # NIL THEN
      p := t.partner(Character);
      AdoptSubItems(a.subEntity.abilities, p.traits, p.name);
      AdoptCombat(a.subEntity.combat, p, p.name)
    END;
    t := t.next
  END;
  AdoptCombat(e.combat, c, c.name);
  Recompute(c);
  t := c.traits;
  FOR i := 0 TO e.abilities.n - 1 DO
    a := e.abilities.items[i](OvaEntities.Ability);
    IF (a.subEntity # NIL) & a.subEntity.combat.hasCombat & a.subEntity.combat.hasThreatValue THEN
      p := t.partner(Character);
      AdoptInt(p.tv, a.subEntity.combat.threatValue, OvaEntities.OvThreatValue IN a.subEntity.combat.overrides,
        p.name, "TV")
    END;
    t := t.next
  END;
  IF e.combat.hasCombat & e.combat.hasThreatValue THEN
    AdoptInt(c.tv, e.combat.threatValue, OvaEntities.OvThreatValue IN e.combat.overrides, c.name, "TV")
  END;
  Recompute(c)
END AdoptNumbers;

(* ---- Files ---- *)

PROCEDURE YamlMessage(err: Fyaml.Error): Rope;
BEGIN RETURN OvaText.Trim(Ropes.FromString(err.msg^))
END YamlMessage;

(* Adds e to the n entities in es, growing es. *)
PROCEDURE KeepEntity(VAR es: Entities; VAR n: INTEGER; e: OvaEntities.Entity);
  VAR t: Entities; i: INTEGER;
BEGIN
  IF es = NIL THEN NEW(es, 4)
  ELSIF n = LEN(es^) THEN
    NEW(t, 2 * n);
    FOR i := 0 TO n - 1 DO t[i] := es[i] END;
    es := t
  END;
  es[n] := e; INC(n)
END KeepEntity;

(* Every entity of the file at path, of every document in it, in order,
   read as po_ova_fmt reads them: es[0 .. n-1]. FALSE, with msg, if it
   can't be read, or OvaEntities finds a problem in any of them. *)
PROCEDURE ReadEntities*(path: ARRAY OF CHAR; VAR es: Entities; VAR n: INTEGER; VAR msg: Rope): BOOLEAN;
  VAR s: FyamlStreams.Stream; d: Fyaml.Document; err: Fyaml.Error; root, item: Fyaml.Node;
    it: Fyaml.ItemIter; e: OvaEntities.Entity; ok: BOOLEAN; l: OvaText.List; i: INTEGER;
    le: OvaEntities.LoadError; r: Rope;
BEGIN
  es := NIL; n := 0; msg := NIL;
  OvaEntities.ResetErrors;
  s := FyamlStreams.OpenFile(path, err);
  IF s = NIL THEN msg := YamlMessage(err); RETURN FALSE END;
  ok := TRUE;
  d := s.Next(err);
  WHILE ok & (d # NIL) DO
    root := d.Root();
    IF (root = NIL) OR ~root.IsSequence() THEN
      msg := Ropes.FromString("expected a top-level YAML sequence of entities in "); OvaText.Add(msg, path);
      ok := FALSE
    ELSE
      root.Items(it);
      WHILE ok & it.Next(item) DO
        IF OvaEntities.Load(item, e, msg) THEN KeepEntity(es, n, e) ELSE ok := FALSE END
      END
    END;
    d.Close;
    IF ok THEN d := s.Next(err) END
  END;
  s.Close;
  IF ok & (err # NIL) THEN msg := YamlMessage(err); ok := FALSE END;
  IF ok & (OvaEntities.errors.n > 0) THEN
    OvaText.Clear(l);
    FOR i := 0 TO OvaEntities.errors.n - 1 DO
      le := OvaEntities.errors.items[i](OvaEntities.LoadError);
      r := le.path; OvaText.Add(r, ": "); r := Ropes.Cat(r, le.message);
      OvaText.Append(l, r)
    END;
    msg := OvaText.Join(l, 0AX); ok := FALSE
  END;
  IF ~ok THEN es := NIL; n := 0 END;
  RETURN ok
END ReadEntities;

(* The first entity of the file at path, and n, how many it holds;
   as ReadEntities. *)
PROCEDURE ReadEntity*(path: ARRAY OF CHAR; VAR first: OvaEntities.Entity; VAR n: INTEGER; VAR msg: Rope): BOOLEAN;
  VAR es: Entities; ok: BOOLEAN;
BEGIN
  ok := ReadEntities(path, es, n, msg);
  IF ok & (n > 0) THEN first := es[0] ELSE first := NIL END;
  RETURN ok
END ReadEntity;

(* The character of entity e, its numbers e's: each its mapping's
   overrides: lists is an override, and each other that differs from
   the rules' is kept as one too, added to notices. *)
PROCEDURE FromEntity*(e: OvaEntities.Entity): Character;
  VAR c: Character;
BEGIN
  c := Build(e);
  AdoptNumbers(e, c);
  RETURN c
END FromEntity;

(* c alone, as a file's characters. *)
PROCEDURE One*(c: Character): Characters;
  VAR cs: Characters;
BEGIN NEW(cs, 1); cs[0] := c; RETURN cs
END One;

(* Every character in the file at path, in order, as FromEntity builds
   them, with notices for all of them (each names its character).
   FALSE, with msg, if the file can't be read, OvaEntities finds a
   problem, or it holds none. *)
PROCEDURE LoadAll*(path: ARRAY OF CHAR; VAR cs: Characters; VAR msg: Rope): BOOLEAN;
  VAR es: Entities; n, i: INTEGER;
BEGIN
  cs := NIL; OvaText.Clear(notices);
  IF ~ReadEntities(path, es, n, msg) THEN RETURN FALSE END;
  IF n = 0 THEN
    msg := Ropes.FromString(path); OvaText.Add(msg, " holds no characters");
    RETURN FALSE
  END;
  NEW(cs, n);
  FOR i := 0 TO n - 1 DO cs[i] := FromEntity(es[i]) END;
  RETURN TRUE
END LoadAll;

(* The one character in the file at path, as LoadAll; FALSE, with msg,
   as LoadAll, or if the file holds more than one. *)
PROCEDURE Load*(path: ARRAY OF CHAR; VAR c: Character; VAR msg: Rope): BOOLEAN;
  VAR cs: Characters;
BEGIN
  c := NIL;
  IF ~LoadAll(path, cs, msg) THEN RETURN FALSE END;
  IF LEN(cs^) # 1 THEN
    msg := Ropes.FromString(path); OvaText.Add(msg, " holds ");
    msg := Ropes.Cat(msg, OvaText.Int(SHORT(LEN(cs^))));
    OvaText.Add(msg, " characters, not one");
    RETURN FALSE
  END;
  c := cs[0];
  RETURN TRUE
END Load;

(* ---- Editing (the window's) ----

   Every change the window makes goes through these, then Recompute.
   Traits and Mods are kept in the order the file's loader sorts them
   (OvaEntities.SortByName: by name, then detail, ignoring case), so
   the window lists them as ova_fmt prints them; attacks keep the order
   they were added in, as a file's do. *)

(* Whether a comes before b: by name, then detail, folded. *)
PROCEDURE Before(an, ad, bn, bd: Rope): BOOLEAN;
  VAR c: INTEGER;
BEGIN
  c := Ropes.Compare(OvaText.FoldCI(an), OvaText.FoldCI(bn));
  IF c = 0 THEN c := Ropes.Compare(OvaText.FoldCI(ad), OvaText.FoldCI(bd)) END;
  RETURN c < 0
END Before;

(* A new Ability or Weakness (kind), named for it, or name if it is
   NIL (a name the tables don't have); detail NIL for none. *)
PROCEDURE NewTrait*(it: OvaRules.Item; kind, level: INTEGER; name, detail: Rope): Trait;
  VAR t: Trait;
BEGIN
  NEW(t); OvaCalc.InitTrait(t, it, kind, level);
  IF it # NIL THEN t.name := Ropes.FromString(it.name) ELSE t.name := name END;
  t.hasDetail := detail # NIL; t.detail := detail;
  t.hasNote := FALSE; t.note := NIL; t.hasHalfTV := FALSE;
  RETURN t
END NewTrait;

(* Puts t into list in its place: Abilities before Weaknesses, each
   sorted. *)
PROCEDURE InsertTrait*(VAR list: OvaCalc.Trait; t: Trait);
  VAR p, prev: OvaCalc.Trait;
BEGIN
  prev := NIL; p := list;
  WHILE (p # NIL) & ((p.kind < t.kind)
      OR (p.kind = t.kind) & ~Before(t.name, t.detail, p(Trait).name, p(Trait).detail)) DO
    prev := p; p := p.next
  END;
  t.next := p;
  IF prev = NIL THEN list := t ELSE prev.next := t END
END InsertTrait;

(* Takes t out of list; nothing if it isn't there. *)
PROCEDURE RemoveTrait*(VAR list: OvaCalc.Trait; t: OvaCalc.Trait);
  VAR p: OvaCalc.Trait;
BEGIN
  IF list = t THEN list := t.next
  ELSE
    p := list;
    WHILE (p # NIL) & (p.next # t) DO p := p.next END;
    IF p # NIL THEN p.next := t.next END
  END;
  t.next := NIL
END RemoveTrait;

(* What linked content an item has: OvaRules.NoLink for none, or NIL. *)
PROCEDURE Linked(it: OvaRules.Item): INTEGER;
BEGIN IF it = NIL THEN RETURN OvaRules.NoLink ELSE RETURN it.linked END
END Linked;

(* Changes t to item it at level with detail, and moves it to its new
   place in list. Its Perks and Flaws stay; its linked content stays
   if it keeps the same kind (Magic, Arcane to Magic, Witchcraft keeps
   the spells), and is dropped if not, as the file couldn't hold it. *)
PROCEDURE ChangeTrait*(VAR list: OvaCalc.Trait; t: Trait; it: OvaRules.Item; level: INTEGER; detail: Rope);
BEGIN
  RemoveTrait(list, t);
  IF Linked(it) # Linked(t.item) THEN t.form := NIL; t.spells := NIL; t.partner := NIL END;
  IF it # t.item THEN
    t.item := it;
    IF it # NIL THEN t.name := Ropes.FromString(it.name) END;
    t.hasHalfTV := FALSE; t.halfTV := (it # NIL) & (OvaRules.HalfTV IN it.flags)
  END;
  t.level := level; t.hasDetail := detail # NIL; t.detail := detail;
  InsertTrait(list, t)
END ChangeTrait;

(* A new sheet for t, a Companion (a Secondary NPC's sheet, p. 52) or a
   Vehicle (a character's, p. 64): named t's detail, or what it is;
   with a combat block, not a Fragment. *)
PROCEDURE NewPartner*(t: Trait): Character;
  VAR c: Character;
BEGIN
  ASSERT((t.item # NIL) & ((t.item.linked = OvaRules.Partner) OR (t.item.linked = OvaRules.Machine)));
  NEW(c);
  IF t.item.linked = OvaRules.Partner THEN
    InitCharacter(c, OvaCalc.CompanionSheet); c.label := Ropes.FromString("Companion")
  ELSE
    InitCharacter(c, OvaCalc.Character); c.label := Ropes.FromString("Vehicle")
  END;
  IF t.hasDetail THEN c.name := t.detail ELSE c.name := c.label END;
  RETURN c
END NewPartner;

(* A new spell named name, mimicking ability (the Ability's name; it,
   OvaRules', or NIL) at level. *)
PROCEDURE NewSpell*(name, ability: Rope; it: OvaRules.Item; level: INTEGER): Spell;
  VAR sp: Spell;
BEGIN
  NEW(sp); OvaCalc.InitSpell(sp, it, level); sp.name := name; sp.ability := ability;
  RETURN sp
END NewSpell;

PROCEDURE RemoveSpell*(t: OvaCalc.Trait; sp: OvaCalc.Spell);
  VAR p: OvaCalc.Spell;
BEGIN
  IF t.spells = sp THEN t.spells := sp.next
  ELSE
    p := t.spells;
    WHILE (p # NIL) & (p.next # sp) DO p := p.next END;
    IF p # NIL THEN p.next := sp.next END
  END;
  sp.next := NIL
END RemoveSpell;

(* A new attack named name, with no Perks or Flaws. *)
PROCEDURE NewAttack*(name: Rope): Attack;
  VAR a: Attack;
BEGIN
  NEW(a); OvaCalc.InitAttack(a);
  a.name := name; a.hasAffinity := FALSE; a.affinity := NIL;
  a.hasDescription := FALSE; a.description := NIL;
  RETURN a
END NewAttack;

PROCEDURE RemoveAttack*(c: Character; a: OvaCalc.Attack);
  VAR p: OvaCalc.Attack;
BEGIN
  IF c.attacks = a THEN c.attacks := a.next
  ELSE
    p := c.attacks;
    WHILE (p # NIL) & (p.next # a) DO p := p.next END;
    IF p # NIL THEN p.next := a.next END
  END;
  a.next := NIL
END RemoveAttack;

(* A new Perk, or Flaw if isFlaw, taken times times at cost each (a
   RangeCost's or UserCost's; else ignored). *)
PROCEDURE NewMod*(it: OvaRules.Item; isFlaw: BOOLEAN; times, cost: INTEGER): Mod;
  VAR m: Mod;
BEGIN
  NEW(m); OvaCalc.InitMod(m, it, times, cost);
  m.name := Ropes.FromString(it.name); m.hasDetail := FALSE; m.detail := NIL;
  m.isFlaw := isFlaw;
  m.hasCost := it.costKind # OvaRules.FixedCost;
  RETURN m
END NewMod;

(* Puts m into list in its place: Perks before Flaws, each sorted. *)
PROCEDURE InsertMod*(VAR list: OvaCalc.Mod; m: Mod);
  VAR p, prev: OvaCalc.Mod;
BEGIN
  prev := NIL; p := list;
  WHILE (p # NIL) & (~p(Mod).isFlaw & m.isFlaw
      OR (p(Mod).isFlaw = m.isFlaw) & ~Before(m.name, m.detail, p(Mod).name, p(Mod).detail)) DO
    prev := p; p := p.next
  END;
  m.next := p;
  IF prev = NIL THEN list := m ELSE prev.next := m END
END InsertMod;

PROCEDURE RemoveMod*(VAR list: OvaCalc.Mod; m: OvaCalc.Mod);
  VAR p: OvaCalc.Mod;
BEGIN
  IF list = m THEN list := m.next
  ELSE
    p := list;
    WHILE (p # NIL) & (p.next # m) DO p := p.next END;
    IF p # NIL THEN p.next := m.next END
  END;
  m.next := NIL
END RemoveMod;

(* A copy of list, each Mod copied: what a dialog puts back on
   Cancel. *)
PROCEDURE CopyMods*(list: OvaCalc.Mod): OvaCalc.Mod;
  VAR first, last: OvaCalc.Mod; m: Mod;
BEGIN
  first := NIL; last := NIL;
  WHILE list # NIL DO
    NEW(m); m^ := list(Mod)^; m.next := NIL;
    IF last = NIL THEN first := m ELSE last.next := m END;
    last := m; list := list.next
  END;
  RETURN first
END CopyMods;

(* Sets a text field and its flag: r NIL (empty) is none. *)
PROCEDURE SetText*(VAR has: BOOLEAN; VAR field: Rope; r: Rope);
BEGIN field := r; has := r # NIL
END SetText;

BEGIN
  OvaText.Clear(notices)
END OvaCharacter.
