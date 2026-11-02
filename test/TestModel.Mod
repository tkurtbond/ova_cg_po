MODULE TestModel; (* OvaCharacter's editing: what the window changes, and Endurance Use *)

(* PLAN.md, "The window": every change the window makes goes through
   OvaCharacter and then Recompute. Here those procedures alone: the
   order traits and mods are kept in, removing and changing them,
   copying a list of mods, and each Endurance Use tied to the Ability
   or attack its detail names, which counts in that one's END, and
   survives a save and a load with no notice; the NPC type, which sets
   the sheet's kind; an Ability's END of 0, not written unless
   overridden. Needs no display. *)

IMPORT Check, OvaCalc, OvaCharacter, OvaEntities, OvaRules, OvaSave, OvaText, Out, Ropes;

CONST Saved = "../obj/files/model.yaml";

TYPE Rope = Ropes.Rope;

VAR
  c, c2: OvaCharacter.Character;
  t, tk, fl, use: OvaCharacter.Trait;
  a: OvaCharacter.Attack;
  m, perk, flaw, cancel: OvaCharacter.Mod;
  mods, copy: OvaCalc.Mod;
  msg: Rope;
  ok: BOOLEAN;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE Item(name: ARRAY OF CHAR): OvaRules.Item;
  VAR it: OvaRules.Item;
BEGIN it := OvaRules.Find(name); ASSERT(it # NIL); RETURN it
END Item;

(* The traits' names and details, in order: "Flight; Telekinesis; Endurance Use (Gust)". *)
PROCEDURE Traits(list: OvaCalc.Trait): Rope;
  VAR r: Rope; t: OvaCharacter.Trait;
BEGIN
  r := NIL;
  WHILE list # NIL DO
    t := list(OvaCharacter.Trait);
    IF r # NIL THEN OvaText.Add(r, "; ") END;
    r := Ropes.Cat(r, t.name);
    IF t.hasDetail THEN OvaText.Add(r, " ("); r := Ropes.Cat(r, t.detail); OvaText.Add(r, ")") END;
    list := list.next
  END;
  RETURN r
END Traits;

PROCEDURE Mods(list: OvaCalc.Mod): Rope;
  VAR r: Rope;
BEGIN
  r := NIL;
  WHILE list # NIL DO
    IF r # NIL THEN OvaText.Add(r, "; ") END;
    r := Ropes.Cat(r, list(OvaCharacter.Mod).name);
    list := list.next
  END;
  RETURN r
END Mods;

PROCEDURE Has(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN (r # NIL) & (Ropes.Find(r, s, 0) >= 0)
END Has;

PROCEDURE Is(r: Rope; s: ARRAY OF CHAR; label: ARRAY OF CHAR);
  VAR x: OvaText.String;
BEGIN
  Check.Check(Ropes.EqualString(r, s), label);
  IF ~Ropes.EqualString(r, s) THEN x := OvaText.Chars(r); Out.String("    got: "); Out.String(x^); Out.Ln END
END Is;

BEGIN
  (* ---- Traits: in the loader's order ---- *)
  c := OvaCharacter.New(); c.name := R("Model");
  use := OvaCharacter.NewTrait(Item("Endurance Use"), OvaRules.Weakness, -2, NIL, R("telekinesis"));
  OvaCharacter.InsertTrait(c.traits, use);
  tk := OvaCharacter.NewTrait(Item("Telekinesis"), OvaRules.Ability, 2, NIL, NIL);
  OvaCharacter.InsertTrait(c.traits, tk);
  fl := OvaCharacter.NewTrait(Item("Flight"), OvaRules.Ability, 1, NIL, NIL);
  OvaCharacter.InsertTrait(c.traits, fl);
  t := OvaCharacter.NewTrait(NIL, OvaRules.Ability, 1, R("Zany Gadgets"), R("b"));
  OvaCharacter.InsertTrait(c.traits, t);
  t := OvaCharacter.NewTrait(NIL, OvaRules.Ability, 1, R("zany gadgets"), R("A"));
  OvaCharacter.InsertTrait(c.traits, t);
  Is(Traits(c.traits), "Flight; Telekinesis; zany gadgets (A); Zany Gadgets (b); Endurance Use (telekinesis)",
    "InsertTrait: Abilities before Weaknesses, each by name, then detail, ignoring case");
  OvaCharacter.RemoveTrait(c.traits, t);
  Is(Traits(c.traits), "Flight; Telekinesis; Zany Gadgets (b); Endurance Use (telekinesis)", "RemoveTrait");
  OvaCharacter.ChangeTrait(c.traits, fl, Item("Telekinesis"), 3, R("small things"));
  Is(Traits(c.traits), "Telekinesis; Telekinesis (small things); Zany Gadgets (b); Endurance Use (telekinesis)",
    "ChangeTrait: renamed and moved to its new place");
  Check.Check((fl.item = Item("Telekinesis")) & (fl.level = 3), "ChangeTrait: the item and level");
  OvaCharacter.ChangeTrait(c.traits, fl, Item("Flight"), 1, NIL);
  Check.Check(~fl.hasDetail & (fl.detail = NIL), "ChangeTrait: a detail removed");

  (* ---- Endurance Use ---- *)
  OvaCharacter.Recompute(c);
  Check.Check(tk.hasEnd & (OvaCalc.Value(tk.end) = 10), "Endurance Use -2 ties to the Ability its detail names: END 10");
  Check.Check(~fl.hasEnd, "and to no other");
  OvaCharacter.ChangeTrait(c.traits, use, use.item, -1, R("Telekinesis (x)"));
  OvaCharacter.Recompute(c);
  Check.Check(~tk.hasEnd, "a detail naming nothing ties to nothing");
  OvaCharacter.ChangeTrait(c.traits, tk, tk.item, 2, R("x"));
  OvaCharacter.Recompute(c);
  Check.Check(tk.hasEnd & (OvaCalc.Value(tk.end) = 5), "a detail naming an Ability and its detail: Endurance Use -1, END 5");
  a := OvaCharacter.NewAttack(R("Gust"));
  OvaCalc.AddAttack(c, a);
  perk := OvaCharacter.NewMod(Item("Accurate"), FALSE, 1, 0);
  OvaCharacter.InsertMod(a.mods, perk);
  OvaCharacter.ChangeTrait(c.traits, use, use.item, -1, R("gust"));
  OvaCharacter.Recompute(c);
  Check.Check(~tk.hasEnd & (OvaCalc.Value(a.end) = 10), "else the attack it names: Accurate's 5 and Endurance Use's 5");
  OvaCharacter.ChangeTrait(c.traits, use, use.item, -1, R("telekinesis (x)"));

  (* ---- Saved and loaded ---- *)
  OvaCharacter.Recompute(c);
  ok := OvaSave.Save(c, Saved, msg);
  Check.Check(ok, "saved");
  ok := OvaCharacter.Load(Saved, c2, msg);
  Check.Check(ok & (OvaCharacter.notices.n = 0), "loaded again with no notices: the END it wrote is the rules'");
  Check.Check(ok & Ropes.Equal(OvaSave.ToText(c2), OvaSave.ToText(c)), "and it saves the same");

  (* ---- Mods ---- *)
  mods := NIL;
  flaw := OvaCharacter.NewMod(Item("Requirement"), TRUE, 1, -10);
  OvaCharacter.InsertMod(mods, flaw);
  perk := OvaCharacter.NewMod(Item("Ranged"), FALSE, 1, 0);
  OvaCharacter.InsertMod(mods, perk);
  cancel := OvaCharacter.NewMod(Item("Cancel"), TRUE, 1, -15);
  OvaCharacter.InsertMod(mods, cancel);
  m := OvaCharacter.NewMod(Item("Accurate"), FALSE, 2, 0);
  OvaCharacter.InsertMod(mods, m);
  Is(Mods(mods), "Accurate; Ranged; Cancel; Requirement", "InsertMod: Perks before Flaws, each by name");
  Check.Check(cancel.hasCost & (cancel.cost = -15) & ~m.hasCost, "NewMod: a chosen cost is written, a fixed one isn't");
  copy := OvaCharacter.CopyMods(mods);
  OvaCharacter.RemoveMod(mods, perk);
  m.times := 3;
  Is(Mods(mods), "Accurate; Cancel; Requirement", "RemoveMod");
  Is(Mods(copy), "Accurate; Ranged; Cancel; Requirement", "CopyMods: a copy the list's changes don't reach");
  Check.Check((copy # m) & (copy.times = 2), "CopyMods: each mod copied");

  (* ---- The NPC type (p. 123-124) ---- *)
  c := OvaCharacter.New(); c.name := R("Typed");
  OvaCharacter.InsertTrait(c.traits, OvaCharacter.NewTrait(Item("Tough"), OvaRules.Ability, 1, NIL, NIL));
  OvaCharacter.Recompute(c);
  Check.Check(~c.hasNpcType & (c.kind = OvaCalc.Character) & (OvaCalc.Value(c.health) = 50),
    "no NPC type: a character's sheet, HEALTH 40 + Tough 1");
  OvaCharacter.SetNpcType(c, TRUE, OvaEntities.Secondary); OvaCharacter.Recompute(c);
  Check.Check((c.kind = OvaCalc.CompanionSheet) & (OvaCalc.Value(c.health) = 30) & (OvaCalc.Value(c.endurance) = 20),
    "Secondary: a Companion's sheet, HEALTH 20 + Tough 1, ENDURANCE 20");
  OvaCharacter.SetNpcType(c, TRUE, OvaEntities.Extra); OvaCharacter.Recompute(c);
  Check.Check((c.kind = OvaCalc.ExtraSheet) & (OvaCalc.Value(c.health) = 20) & (OvaCalc.Value(c.tv) = 1),
    "Extra: HEALTH 10 + Tough 1, TV 1");
  OvaCharacter.SetNpcType(c, TRUE, OvaEntities.Boss); OvaCharacter.Recompute(c);
  Check.Check((c.kind = OvaCalc.BossSheet) & (OvaCalc.Value(c.health) = 50) & (OvaCalc.Value(c.endurance) = 40)
    & Has(OvaSave.ToText(c), "npc-type: Boss"), "Boss: HEALTH 40 + Tough 1, ENDURANCE 40, saved");
  ok := OvaSave.Save(c, Saved, msg) & OvaCharacter.Load(Saved, c2, msg);
  Check.Check(ok & (OvaCharacter.notices.n = 0) & c2.hasNpcType & (c2.npcType = OvaEntities.Boss)
    & (c2.kind = OvaCalc.BossSheet), "loaded again: a Boss's sheet; no notices");
  OvaCharacter.SetNpcType(c, TRUE, OvaEntities.Heroic); OvaCharacter.Recompute(c);
  Check.Check((c.kind = OvaCalc.Character) & (OvaCalc.Value(c.health) = 50), "Heroic: a character's sheet");
  OvaCharacter.SetNpcType(c, TRUE, OvaEntities.Secondary);
  c.hasCharacterHooks := TRUE; c.characterHooks := R("Hooks.");
  OvaCharacter.Recompute(c);
  Check.Check(Has(OvaSave.ToText(c), "npc-type: Secondary") & Has(OvaSave.ToText(c), "character-hooks: Hooks."),
    "the type and the hooks saved");
  ok := OvaSave.Save(c, Saved, msg) & OvaCharacter.Load(Saved, c2, msg);
  Check.Check(ok & (OvaCharacter.notices.n = 0) & c2.hasNpcType & (c2.npcType = OvaEntities.Secondary)
    & (c2.kind = OvaCalc.CompanionSheet) & Ropes.EqualString(c2.characterHooks, "Hooks."),
    "loaded again: the type, so the sheet's kind, and the hooks; no notices");
  OvaCharacter.SetNpcType(c, FALSE, 0); OvaCharacter.Recompute(c);
  Check.Check(~c.hasNpcType & (c.kind = OvaCalc.Character) & ~Has(OvaSave.ToText(c), "npc-type"),
    "the type taken off: a character's sheet, nothing saved");

  (* ---- An Ability's END of 0 ---- *)
  c := OvaCharacter.New(); c.name := R("Free"); c.hasCombat := FALSE;
  t := OvaCharacter.NewTrait(Item("Attack"), OvaRules.Ability, 3, NIL, NIL);
  OvaCharacter.InsertMod(t.mods, OvaCharacter.NewMod(Item("Armor Piercing"), FALSE, 1, 0));
  OvaCharacter.InsertMod(t.mods, OvaCharacter.NewMod(Item("Ranged"), FALSE, 1, 0));
  OvaCharacter.InsertMod(t.mods, OvaCharacter.NewMod(Item("Ineffective"), TRUE, 1, 0));
  OvaCharacter.InsertMod(t.mods, OvaCharacter.NewMod(Item("Weapon"), TRUE, 1, 0));
  OvaCharacter.InsertTrait(c.traits, t);
  OvaCharacter.Recompute(c);
  Check.Check(t.hasEnd & (OvaCalc.Value(t.end) = 0), "Perks and Flaws costing nothing: END 0");
  Check.Check(~Has(OvaSave.ToText(c), "endurance"), "an END of 0 isn't written");
  OvaCalc.Override(t.end, 0, FALSE, FALSE);
  Check.Check(Has(OvaSave.ToText(c), "endurance: 0"), "unless it is an override");
  OvaCalc.Clear(t.end); OvaCalc.Override(t.end, 5, FALSE, FALSE);
  Check.Check(Has(OvaSave.ToText(c), "endurance: 5"), "an override of 5 is");

  Check.Summary
END TestModel.
