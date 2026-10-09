MODULE Samples; (* A fixture's character as an OvaCalc sheet, for TestCalc *)

(* Reads a YAML file with po_ova_fmt's OvaEntities, as the program will
   (PLAN.md, "Files"), and builds the OvaCalc sheet of its first entity:
   its Abilities (with a Transformation's form, a Magic's spells, a
   Companion's or Vehicle's own sheet), Weaknesses, attacks and options.
   The numbers the file holds are left in the entity, for TestCalc to
   compare with what OvaCalc computes. What the files have no key for
   (an attack made with Telekinesis or in the transformed form, a sheet
   shown transformed) TestCalc sets itself. Phase 3's OvaCharacter will
   do this for the program. *)

IMPORT Fyaml, FyamlStreams, OvaCalc, OvaEntities, OvaRules, OvaText, Ropes;

TYPE
  Entity = OvaEntities.Entity;

(* The first entity of the file at path; NIL if it can't be read, or
   OvaEntities reports a problem with it. *)
PROCEDURE Load*(path: ARRAY OF CHAR): Entity;
  VAR s: FyamlStreams.Stream; d: Fyaml.Document; err: Fyaml.Error; root, item: Fyaml.Node;
    it: Fyaml.ItemIter; e: Entity; msg: Ropes.Rope;
BEGIN
  e := NIL; OvaEntities.ResetErrors;
  s := FyamlStreams.OpenFile(path, err);
  IF s = NIL THEN RETURN NIL END;
  d := s.Next(err);
  IF d # NIL THEN
    root := d.Root();
    IF (root # NIL) & root.IsSequence() THEN
      root.Items(it);
      IF it.Next(item) & ~OvaEntities.Load(item, e, msg) THEN e := NIL END
    END;
    d.Close
  END;
  s.Close;
  IF OvaEntities.errors.n > 0 THEN e := NIL END;
  RETURN e
END Load;

PROCEDURE Find(name: Ropes.Rope): OvaRules.Item;
  VAR c: OvaText.String;
BEGIN c := OvaText.Chars(name); RETURN OvaRules.Find(c^)
END Find;

(* l's Perks or Flaws, added to mods. *)
PROCEDURE Mods(l: OvaEntities.List; VAR mods: OvaCalc.Mod);
  VAR i, times, cost: INTEGER; pf: OvaEntities.PerkFlaw; m: OvaCalc.Mod;
BEGIN
  FOR i := 0 TO l.n - 1 DO
    pf := l.items[i](OvaEntities.PerkFlaw);
    times := 1; IF pf.hasCountsAs THEN times := pf.countsAs END;
    cost := 0; IF pf.hasCost THEN cost := pf.cost END;
    NEW(m); OvaCalc.InitMod(m, Find(pf.name), times, cost); OvaCalc.AddMod(mods, m)
  END
END Mods;

PROCEDURE SubTrait(x: OvaEntities.SubItem; kind: INTEGER): OvaCalc.Trait;
  VAR t: OvaCalc.Trait;
BEGIN
  NEW(t); OvaCalc.InitTrait(t, Find(x.name), kind, x.level);
  Mods(x.perks, t.mods); Mods(x.flaws, t.mods);
  RETURN t
END SubTrait;

PROCEDURE SubTraits(l: OvaEntities.List; kind: INTEGER; VAR list: OvaCalc.Trait);
  VAR i: INTEGER;
BEGIN
  FOR i := 0 TO l.n - 1 DO OvaCalc.AddTrait(list, SubTrait(l.items[i](OvaEntities.SubItem), kind)) END
END SubTraits;

PROCEDURE Attacks(c: OvaEntities.Combat; s: OvaCalc.Sheet);
  VAR i: INTEGER; x: OvaEntities.Attack; a: OvaCalc.Attack;
BEGIN
  FOR i := 0 TO c.attacks.n - 1 DO
    x := c.attacks.items[i](OvaEntities.Attack);
    NEW(a); OvaCalc.InitAttack(a);
    Mods(x.perks, a.mods); Mods(x.flaws, a.mods);
    OvaCalc.AddAttack(s, a)
  END
END Attacks;

(* A Companion's sheet (a Secondary NPC's), or a Vehicle's (a
   character's). *)
PROCEDURE SubSheet(x: OvaEntities.SubEntity): OvaCalc.Sheet;
  VAR s: OvaCalc.Sheet;
BEGIN
  NEW(s);
  IF Ropes.EqualString(x.label, "Companion") THEN OvaCalc.InitSheet(s, OvaCalc.CompanionSheet)
  ELSE OvaCalc.InitSheet(s, OvaCalc.Character)
  END;
  SubTraits(x.abilities, OvaRules.Ability, s.traits);
  SubTraits(x.weaknesses, OvaRules.Weakness, s.traits);
  Attacks(x.combat, s);
  RETURN s
END SubSheet;

(* e's sheet: its Abilities, then its Weaknesses, each in e's order, and
   its attacks in the file's order. *)
PROCEDURE Build*(e: Entity): OvaCalc.Sheet;
  VAR s: OvaCalc.Sheet; t: OvaCalc.Trait; a: OvaEntities.Ability; w: OvaEntities.Weakness;
    sp: OvaEntities.Spell; csp: OvaCalc.Spell; i, j: INTEGER;
BEGIN
  NEW(s); OvaCalc.InitSheet(s, OvaCalc.Character);
  FOR i := 0 TO e.abilities.n - 1 DO
    a := e.abilities.items[i](OvaEntities.Ability);
    t := SubTrait(a, OvaRules.Ability);
    SubTraits(a.subAbilities, OvaRules.Ability, t.form);
    SubTraits(a.subWeaknesses, OvaRules.Weakness, t.form);
    FOR j := 0 TO a.spells.n - 1 DO
      sp := a.spells.items[j](OvaEntities.Spell);
      NEW(csp); OvaCalc.InitSpell(csp, Find(sp.ability), sp.level); OvaCalc.AddSpell(t, csp)
    END;
    IF a.subEntity # NIL THEN t.partner := SubSheet(a.subEntity) END;
    OvaCalc.AddTrait(s.traits, t)
  END;
  FOR i := 0 TO e.weaknesses.n - 1 DO
    w := e.weaknesses.items[i](OvaEntities.Weakness);
    NEW(t); OvaCalc.InitTrait(t, Find(w.name), OvaRules.Weakness, w.level);
    OvaCalc.AddTrait(s.traits, t)
  END;
  Attacks(e.combat, s);
  IF e.hasOptions THEN
    s.options.baseZero := e.options.hasBaseZero; s.options.baseZeroRange := e.options.baseZero;
    s.options.powerCeiling := e.options.hasPowerCeiling; s.options.ceiling := e.options.powerCeiling;
    s.options.scaledCost := e.options.scaledCost;
    s.options.combinedEffectiveness := e.options.combinedEffectiveness
  END;
  RETURN s
END Build;

END Samples.
