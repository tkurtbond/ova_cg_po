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
    hasTagline*, hasSummary*, hasBackground*, hasAppearance*, hasPersonality*, hasOtherNotes*: BOOLEAN;
    tagline*, summary*, background*, appearance*, personality*, otherNotes*: Rope;
    notes*: Note;
    hasFluff*: BOOLEAN;
    hasFluffField*: ARRAY NFluff OF BOOLEAN;
    fluff*: ARRAY NFluff OF Rope;
    hasOptions*: BOOLEAN;  (* an options: block, even an empty one *)
    isFragment*: BOOLEAN;  (* an NPC Fragment, or a simple Companion *)
    hasCombat*: BOOLEAN;   (* a combat: block: a Fragment or Companion may have none *)
    hasThreatValue*: BOOLEAN;
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

  Spell* = POINTER TO SpellDesc;
  SpellDesc* = RECORD (OvaCalc.SpellDesc)
    name*, ability*: Rope
  END;

VAR
  (* What the last Load found to say about the file: each number kept
     as an override. *)
  notices-: OvaText.List;

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
  c.hasPersonality := FALSE; c.hasOtherNotes := FALSE;
  c.tagline := NIL; c.summary := NIL; c.background := NIL; c.appearance := NIL;
  c.personality := NIL; c.otherNotes := NIL;
  c.notes := NIL;
  c.hasFluff := FALSE;
  FOR i := 0 TO NFluff - 1 DO c.hasFluffField[i] := FALSE; c.fluff[i] := NIL END;
  c.hasOptions := FALSE; c.isFragment := FALSE;
  c.hasCombat := TRUE; c.hasThreatValue := TRUE;
  c.hasCombatNotes := FALSE; c.combatNotes := NIL
END InitCharacter;

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
  OvaCalc.Compute(c);
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

(* The numbers of a combat: block but TV. *)
PROCEDURE AdoptCombat(x: OvaEntities.Combat; c: Character; where: Rope);
  VAR i: INTEGER; y: OvaEntities.Attack; a: OvaCalc.Attack; at: Rope; slash: LONGINT;
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
  slash := Ropes.IndexChar(x.defense, "/", 0);
  IF slash < 0 THEN Adopt(c.defense, x.defense, FALSE, FALSE, OvaEntities.OvDefense IN x.overrides, where, "DEFENSE")
  ELSE
    Adopt(c.defense, Ropes.Substring(x.defense, 0, slash), FALSE, FALSE,
      OvaEntities.OvDefense IN x.overrides, where, "DEFENSE");
    Adopt(c.barrier, Ropes.Substring(x.defense, slash + 1, Ropes.Length(x.defense) - slash - 1),
      FALSE, FALSE, OvaEntities.OvBarrier IN x.overrides, where, "Barrier's DEFENSE")
  END;
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
  OvaCalc.Compute(c);
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
  OvaCalc.Compute(c)
END AdoptNumbers;

(* ---- Files ---- *)

PROCEDURE YamlMessage(err: Fyaml.Error): Rope;
BEGIN RETURN OvaText.Trim(Ropes.FromString(err.msg^))
END YamlMessage;

(* The first entity of the file at path, read as po_ova_fmt reads it,
   and n, how many the file holds. FALSE, with msg, if it can't be
   read, or OvaEntities finds a problem in any of them. *)
PROCEDURE ReadEntity*(path: ARRAY OF CHAR; VAR first: OvaEntities.Entity; VAR n: INTEGER; VAR msg: Rope): BOOLEAN;
  VAR s: FyamlStreams.Stream; d: Fyaml.Document; err: Fyaml.Error; root, item: Fyaml.Node;
    it: Fyaml.ItemIter; e: OvaEntities.Entity; ok: BOOLEAN; l: OvaText.List; i: INTEGER;
    le: OvaEntities.LoadError; r: Rope;
BEGIN
  first := NIL; n := 0; msg := NIL;
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
        IF OvaEntities.Load(item, e, msg) THEN
          IF n = 0 THEN first := e END;
          INC(n)
        ELSE ok := FALSE
        END
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
  IF ~ok THEN first := NIL END;
  RETURN ok
END ReadEntity;

(* The character in the file at path, its numbers the file's: each its
   mapping's overrides: lists is an override, and each other that
   differs from the rules' is kept as one too, in notices. FALSE,
   with msg, if the file can't be read, OvaEntities finds a problem, or
   it doesn't hold exactly one character (the generator edits one at a
   time). *)
PROCEDURE Load*(path: ARRAY OF CHAR; VAR c: Character; VAR msg: Rope): BOOLEAN;
  VAR e: OvaEntities.Entity; n: INTEGER;
BEGIN
  c := NIL; OvaText.Clear(notices);
  IF ~ReadEntity(path, e, n, msg) THEN RETURN FALSE END;
  IF n # 1 THEN
    msg := Ropes.FromString(path); OvaText.Add(msg, " holds ");
    msg := Ropes.Cat(msg, OvaText.Int(n));
    OvaText.Add(msg, " characters: the generator edits one at a time");
    RETURN FALSE
  END;
  c := Build(e);
  AdoptNumbers(e, c);
  RETURN TRUE
END Load;

BEGIN
  OvaText.Clear(notices)
END OvaCharacter.
