MODULE TestLinked; (* OvaLinkedDialog: a Transformation's form, a Magic's spells, a Companion's and a Vehicle's sheets *)

(* Needs a display: run by make test-gui, as TestWindow is. Each kind of
   linked content opened from the window's button, as the user opens
   it; shown with each name's page; edited, live, and checked in the
   model, in the numbers computed from it, and in what is saved; and
   the window's Character > Transformed form. *)

IMPORT Check, Fl, FlBrowsers, FlMenus, OvaAttackDialog, OvaCalc, OvaCharacter, OvaLinkedDialog, OvaRules,
  OvaSave, OvaText, OvaTraitPanel, OvaWidgets, OvaWindow, Out, Ropes;

TYPE Rope = Ropes.Rope;

VAR
  tells: INTEGER;
  c: OvaCharacter.Character;
  t: OvaCharacter.Trait;
  p: OvaCharacter.Character;
  text: Rope;
  s, want: ARRAY 256 OF CHAR;
  label: ARRAY 64 OF CHAR;
  i, n, before: INTEGER;
  ok: BOOLEAN;

PROCEDURE Tell(text: Rope);
  VAR s: OvaText.String;
BEGIN INC(tells); s := OvaText.Chars(text); Out.String("    told: "); Out.String(s^); Out.Ln
END Tell;

PROCEDURE Ask(question: Rope): INTEGER;
BEGIN RETURN OvaWindow.Discard
END Ask;

PROCEDURE NoPage(page: INTEGER);
END NoPage;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE Saved(): Rope;
BEGIN RETURN OvaSave.ToText(OvaWindow.character)
END Saved;

PROCEDURE Has(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.Find(r, s, 0) >= 0
END Has;

PROCEDURE Load(name: ARRAY OF CHAR): BOOLEAN;
  VAR r: Rope;
BEGIN r := R("data/"); OvaText.Add(r, name); RETURN OvaWindow.Load(r)
END Load;

(* The last line of browser b holding text; 0 if none. *)
PROCEDURE LineWith(b: FlBrowsers.Browser; text: ARRAY OF CHAR): INTEGER;
  VAR i: INTEGER; line: ARRAY 256 OF CHAR;
BEGIN
  i := b.Count();
  WHILE i > 0 DO
    b.GetText(i, line);
    IF Ropes.Find(Ropes.FromString(line), text, 0) >= 0 THEN RETURN i END;
    DEC(i)
  END;
  RETURN 0
END LineWith;

(* Selects b's line holding text, as a click does. *)
PROCEDURE Click(b: FlBrowsers.Browser; text: ARRAY OF CHAR);
BEGIN IF b.Select(LineWith(b, text), TRUE) THEN END; b.DoCallback
END Click;

(* Chooses name in p's Choice, as the user does. *)
PROCEDURE Pick(p: OvaWidgets.Panel; name: ARRAY OF CHAR);
  VAR it: OvaRules.Item; i: INTEGER;
BEGIN
  it := OvaRules.Find(name); ASSERT(it # NIL);
  i := 0; WHILE OvaRules.Get(p.kind, i) # it DO INC(i) END;
  IF p.choice.SetValue(i) THEN END;
  p.choice.DoCallback
END Pick;

(* Chooses Ability name in Choice ch, which lists them all. *)
(* Chooses name, an Ability or a Weakness, in a Choice of its kind's
   names. *)
PROCEDURE PickAbility(ch: FlMenus.Choice; name: ARRAY OF CHAR);
  VAR it: OvaRules.Item; i: INTEGER;
BEGIN
  it := OvaRules.Find(name); ASSERT(it # NIL);
  i := 0; WHILE OvaRules.Get(it.kind, i) # it DO INC(i) END;
  IF ch.SetValue(i) THEN END;
  ch.DoCallback
END PickAbility;

PROCEDURE Type(b: OvaWidgets.NumberBox; text: ARRAY OF CHAR);
BEGIN b.entry.SetValue(text); b.entry.DoCallback
END Type;

(* Selects the window's Ability holding name, and opens its linked
   content. *)
PROCEDURE OpenLinked(name: ARRAY OF CHAR);
BEGIN Click(OvaWindow.abilities.browser, name); OvaWindow.abilityLinked.DoCallback
END OpenLinked;

(* Whether panel p lists list's traits of its kind, each with its page. *)
PROCEDURE Listed(p: OvaTraitPanel.TraitPanel; list: OvaCalc.Trait): BOOLEAN;
  VAR n: INTEGER; ok: BOOLEAN; line, pg: ARRAY 256 OF CHAR; x: OvaCharacter.Trait; r: Rope;
BEGIN
  n := 0; ok := TRUE;
  WHILE ok & (list # NIL) DO
    IF list.kind = p.kind THEN
      INC(n); x := list(OvaCharacter.Trait);
      ok := n <= p.browser.Count();
      IF ok THEN
        p.browser.GetText(n, line);
        IF x.level > 0 THEN r := R("+") ELSE r := NIL END;
        OvaText.AddInt(r, x.level); OvaText.Add(r, " "); r := Ropes.Cat(r, x.name);
        IF x.hasDetail THEN OvaText.Add(r, " ("); r := Ropes.Cat(r, x.detail); OvaText.Add(r, ")") END;
        r := Ropes.AppendChar(r, 9X); OvaRules.PageText(x.item, pg); OvaText.Add(r, pg);
        ok := Ropes.EqualString(r, line)
      END
    END;
    list := list.next
  END;
  RETURN ok & (n = p.browser.Count())
END Listed;

(* name's place among the items of its kind. *)
PROCEDURE IndexOf(name: ARRAY OF CHAR): INTEGER;
  VAR it: OvaRules.Item; i: INTEGER;
BEGIN
  it := OvaRules.Find(name); i := 0; WHILE OvaRules.Get(it.kind, i) # it DO INC(i) END;
  RETURN i
END IndexOf;

(* The trait of list named name; NIL if none. *)
PROCEDURE Named(list: OvaCalc.Trait; name: ARRAY OF CHAR): OvaCharacter.Trait;
BEGIN
  WHILE (list # NIL) & ~Ropes.EqualString(list(OvaCharacter.Trait).name, name) DO list := list.next END;
  IF list = NIL THEN RETURN NIL ELSE RETURN list(OvaCharacter.Trait) END
END Named;

PROCEDURE SpellCount(t: OvaCalc.Trait): INTEGER;
  VAR sp: OvaCalc.Spell; n: INTEGER;
BEGIN n := 0; sp := t.spells; WHILE sp # NIL DO INC(n); sp := sp.next END; RETURN n
END SpellCount;

PROCEDURE AttackCount(s: OvaCalc.Sheet): INTEGER;
  VAR a: OvaCalc.Attack; n: INTEGER;
BEGIN n := 0; a := s.attacks; WHILE a # NIL DO INC(n); a := a.next END; RETURN n
END AttackCount;

(* Whether box b shows n: its computed number, and its override or "". *)
PROCEDURE Shows(b: OvaWidgets.NumberBox; VAR n: OvaCalc.Number): BOOLEAN;
  VAR shown, entry, want: ARRAY 32 OF CHAR;
BEGIN
  b.shown.Value(shown); b.entry.Value(entry);
  OvaCalc.ComputedText(n, want);
  IF shown # want THEN RETURN FALSE END;
  IF n.overridden THEN OvaCalc.Text(n, want) ELSE want := "" END;
  RETURN entry = want
END Shows;

PROCEDURE PartnerShown(p: OvaCharacter.Character): BOOLEAN;
BEGIN
  RETURN Shows(OvaLinkedDialog.numbers[0], p.defense) & Shows(OvaLinkedDialog.numbers[1], p.barrier)
    & Shows(OvaLinkedDialog.numbers[2], p.health) & Shows(OvaLinkedDialog.numbers[3], p.endurance)
    & Shows(OvaLinkedDialog.numbers[4], p.reserve) & Shows(OvaLinkedDialog.numbers[5], p.tv)
END PartnerShown;

PROCEDURE Columns(a, b, c: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
  VAR r: Rope; x: OvaText.String;
BEGIN
  r := R(a); r := Ropes.AppendChar(r, 9X); OvaText.Add(r, b);
  r := Ropes.AppendChar(r, 9X); OvaText.Add(r, c);
  x := OvaText.Chars(r); COPY(x^, s)
END Columns;

PROCEDURE Modified(): BOOLEAN;
  VAR s: ARRAY 128 OF CHAR; i: INTEGER;
BEGIN
  OvaWindow.window.GetLabel(s); i := 0; WHILE s[i] # 0X DO INC(i) END;
  RETURN OvaWindow.modified & (i > 2) & (s[i - 1] = "*")
END Modified;

PROCEDURE Info(VAR s: ARRAY OF CHAR);
BEGIN OvaLinkedDialog.info.GetLabel(s)
END Info;

BEGIN
  tells := 0;
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaWindow.ask := Ask; OvaWidgets.openPage := NoPage;
  OvaWindow.window.Show; OvaWindow.window.WaitForExpose; IF Fl.Check() THEN END;

  (* ---- The button ---- *)
  ok := Load("Fukiko.yaml"); c := OvaWindow.character;
  Click(OvaWindow.abilities.browser, "Cute!");
  OvaWindow.abilityLinked.GetLabel(label);
  Check.Check(ok & ~OvaWindow.abilityLinked.Active(), "an Ability with no linked content: the button inactive");
  Click(OvaWindow.abilities.browser, "Transformation");
  OvaWindow.abilityLinked.GetLabel(label);
  Check.Check(OvaWindow.abilityLinked.Active() & (label = "Form..."), "Transformation: Form...");
  Click(OvaWindow.abilities.browser, "Companion");
  OvaWindow.abilityLinked.GetLabel(label);
  Check.Check(label = "Companion...", "Companion: Companion...");

  (* ---- A Transformation's form ---- *)
  t := Named(c.traits, "Transformation");
  OpenLinked("Transformation");
  Check.Check((OvaLinkedDialog.dialog # NIL) & (OvaLinkedDialog.mode = OvaRules.Form), "Form...: the dialog, for the form");
  Check.Check(Listed(OvaLinkedDialog.abilities, t.form) & Listed(OvaLinkedDialog.weaknesses, t.form)
    & (OvaLinkedDialog.abilities.browser.Count() = 4), "the form's Abilities and Weaknesses listed, with pages");
  Info(s);
  Check.Check((s = "The form's Abilities and Weaknesses come to +8 levels; Transformation +4 pays for 8 (p. 63).")
    & (OvaLinkedDialog.info.LabelColor() = Fl.ForegroundColor), "its levels against what Transformation +4 pays for");
  before := c.health.value;
  Pick(OvaLinkedDialog.abilities, "Tough");
  OvaLinkedDialog.abilities.spinner.SetValue(1);
  OvaLinkedDialog.abilities.add.DoCallback;
  Check.Check((Named(t.form, "Tough") # NIL) & Listed(OvaLinkedDialog.abilities, t.form) & Modified(),
    "a form Ability added: in the form, listed, the character modified");
  Check.Check(c.transformed & (c.health.value = before + 10), "Fukiko shown transformed: her HEALTH counts the form's Tough");
  Info(s);
  Check.Check((s = "The form's Abilities and Weaknesses come to +9 levels; Transformation +4 pays for 8 (p. 63).")
    & (OvaLinkedDialog.info.LabelColor() = Fl.Red), "the levels again, over what it pays for: in red");
  Check.Check(Has(Saved(), "- name: Tough"), "saved");
  Click(OvaLinkedDialog.abilities.browser, "Barrier");
  Check.Check(OvaLinkedDialog.mods.Active() & OvaLinkedDialog.end.Active(), "the form's Barrier: its Perks and Flaws, its END");
  OvaLinkedDialog.mods.DoCallback;
  Check.Check(OvaAttackDialog.dialog # NIL, "Perks and Flaws...: the dialog over this one");
  OvaLinkedDialog.close.DoCallback;
  Check.Check(OvaLinkedDialog.dialog # NIL, "Close waits for the dialog above it");
  OvaAttackDialog.Cancel;
  OvaLinkedDialog.close.DoCallback;
  Check.Check(OvaLinkedDialog.dialog = NIL, "Close");

  (* ---- Character > Transformed form ---- *)
  Check.Check(OvaWindow.bar.ItemFlags(OvaWindow.transformedItem) * FlMenus.MenuValue # {},
    "Character > Transformed form: on, as Fukiko's file says");
  OvaWindow.bar.Pick(OvaWindow.transformedItem);
  Check.Check(~c.transformed & (c.health.value = before) & Shows(OvaWindow.numbers[2], c.health)
    & ~Has(Saved(), "transformed: true"),
    "off: the form not counted, in the combat box too, and not saved as shown transformed");
  OvaWindow.bar.Pick(OvaWindow.transformedItem);
  Check.Check(c.transformed & (c.health.value = before + 10) & Shows(OvaWindow.numbers[2], c.health)
    & Has(Saved(), "transformed: true"), "on again");

  (* ---- A Companion's sheet ---- *)
  t := Named(c.traits, "Companion"); p := t.partner(OvaCharacter.Character);
  OpenLinked("Companion");
  OvaLinkedDialog.partnerName.Value(s);
  Check.Check((OvaLinkedDialog.mode = OvaRules.Partner) & (s = "Azyrus") & OvaLinkedDialog.fragment.Value()
    & ~OvaLinkedDialog.combat.Value(), "Companion...: Azyrus, a Fragment, no combat stats");
  Check.Check(Listed(OvaLinkedDialog.abilities, p.traits) & Listed(OvaLinkedDialog.weaknesses, p.traits),
    "its Abilities and Weaknesses, with pages");
  Check.Check(~OvaLinkedDialog.addAttack.Active() & ~OvaLinkedDialog.numbers[2].Active() & PartnerShown(p),
    "no combat stats: its attacks and numbers inactive, but computed: a Companion's 20 less Frail");
  OvaLinkedDialog.partnerName.SetValue("Azyrus II"); OvaLinkedDialog.partnerName.DoCallback;
  Check.Check(Ropes.EqualString(p.name, "Azyrus II") & Has(Saved(), "name: Azyrus II"), "renamed, and saved");
  OvaLinkedDialog.partnerName.SetValue(" "); OvaLinkedDialog.partnerName.DoCallback;
  Check.Check(Ropes.EqualString(p.name, "Companion"), "a blank name: Companion, since the file needs one");
  OvaLinkedDialog.combat.SetValue(TRUE); OvaLinkedDialog.combat.DoCallback;
  Check.Check(p.hasCombat & OvaLinkedDialog.addAttack.Active() & OvaLinkedDialog.numbers[2].Active()
    & ~OvaLinkedDialog.numbers[1].Active() & ~OvaLinkedDialog.numbers[4].Active(),
    "combat stats on: its attacks and numbers, Barrier's and Reserve's not, having none");
  before := p.health.value;
  Pick(OvaLinkedDialog.abilities, "Tough");
  OvaLinkedDialog.abilities.add.DoCallback;
  Check.Check((p.health.value = before + 10) & PartnerShown(p), "a Companion's Tough +1: its HEALTH 10 more, shown");
  Type(OvaLinkedDialog.numbers[2], "35");
  Check.Check(p.health.overridden & (OvaCalc.Value(p.health) = 35) & PartnerShown(p), "its HEALTH overridden");
  text := Saved();
  Check.Check(Has(text, "health: 35") & Has(text, "- health"), "and saved, in its combat block, listed in overrides");
  OvaLinkedDialog.addAttack.DoCallback;
  Check.Check(OvaAttackDialog.dialog # NIL, "Add...: the attack dialog, for the Companion");
  OvaAttackDialog.nameIn.SetValue("Claw");
  OvaAttackDialog.Ok;
  Check.Check((AttackCount(p) = 1) & (OvaLinkedDialog.attacks.Count() = 1) & (AttackCount(c) = 4),
    "OK: the Companion's attack, not Fukiko's");
  OvaLinkedDialog.attacks.GetText(1, s);
  Check.Check(Ropes.Find(R(s), "Claw", 0) = 0, "listed, with its numbers");
  Check.Check(Has(Saved(), "name: Claw"), "and saved");
  IF OvaLinkedDialog.attacks.Select(1, TRUE) THEN END;
  OvaLinkedDialog.removeAttack.DoCallback;
  Check.Check((AttackCount(p) = 0) & ~Has(Saved(), "name: Claw"), "Remove");
  OvaLinkedDialog.close.DoCallback;

  (* ---- A Magic's spells ---- *)
  ok := Load("Auren.yaml"); c := OvaWindow.character;
  t := Named(c.traits, "Magic, Arcane");
  OvaWindow.abilities.browser.GetText(LineWith(OvaWindow.abilities.browser, "Magic, Arcane"), s);
  OpenLinked("Magic, Arcane");
  OvaWindow.abilityLinked.GetLabel(label);
  Check.Check((label = "Spells...") & (OvaLinkedDialog.mode = OvaRules.Spells) & (OvaLinkedDialog.spells.Count() = SpellCount(t))
    & (SpellCount(t) = 6), "Spells...: Auren's six spells");
  OvaLinkedDialog.spells.GetText(1, s); Columns("Mana Shield", "Barrier +2 (p. 51)", "END 10+", want);
  Check.Check(s = want, "each with its Ability's page and its END: Barrier's 10+");
  OvaLinkedDialog.spellAbility.GetLabel(label);
  Check.Check((OvaLinkedDialog.castKind = OvaRules.Ability) & (label = "Ability")
    & (OvaLinkedDialog.spellLevel.Minimum() = 1) & (OvaLinkedDialog.spellLevel.Maximum() = 5),
    "Arcane's spells: Abilities, +1 to +5");
  n := SpellCount(t);
  OvaLinkedDialog.spellName.SetValue("Glow"); PickAbility(OvaLinkedDialog.spellAbility, "Healer");
  Check.Check(OvaLinkedDialog.spellHelp.page = 54, "the Ability chosen: ? at its page");
  OvaLinkedDialog.spellLevel.SetValue(1);
  OvaLinkedDialog.addSpell.DoCallback;
  i := OvaLinkedDialog.spells.Value();
  IF i > 0 THEN OvaLinkedDialog.spells.GetText(i, s) ELSE s[0] := 0X END;
  Columns("Glow", "Healer +1 (p. 54)", "END 5", want);
  Check.Check((SpellCount(t) = n + 1) & (i = n + 1) & (s = want),
    "Add: last, selected, its END by Magic +3 and its level 1: 5 (p. 58)");
  Check.Check(Has(Saved(), "name: Glow") & Has(Saved(), "ability: Healer") & Modified(), "saved");
  OvaLinkedDialog.spellLevel.SetValue(2);
  OvaLinkedDialog.changeSpell.DoCallback;
  OvaLinkedDialog.spells.GetText(n + 1, s); Columns("Glow", "Healer +2 (p. 54)", "END 10", want);
  Check.Check(s = want, "Change: level 2, END 10");
  Type(OvaLinkedDialog.spellEnd, "15");
  OvaLinkedDialog.spells.GetText(n + 1, s); Columns("Glow", "Healer +2 (p. 54)", "END 15", want);
  Check.Check((s = want) & OvaLinkedDialog.spellEnd.Active(), "its END overridden: 15, listed");
  tells := 0;
  OvaLinkedDialog.spellName.SetValue(" ");
  OvaLinkedDialog.addSpell.DoCallback;
  Check.Check((tells = 1) & (SpellCount(t) = n + 1), "a spell with no name: said so, not added");
  IF OvaLinkedDialog.spells.Select(n + 1, TRUE) THEN END; OvaLinkedDialog.spells.DoCallback;
  OvaLinkedDialog.spellName.Value(s);
  Check.Check(s = "Glow", "a spell selected: its name, Ability and level to edit");
  OvaLinkedDialog.removeSpell.DoCallback;
  Check.Check((SpellCount(t) = n) & ~Has(Saved(), "name: Glow") & (OvaLinkedDialog.spells.Count() = n), "Remove");
  OvaLinkedDialog.close.DoCallback;

  (* A change to an Ability of another kind drops what the file couldn't
     hold. *)
  Click(OvaWindow.abilities.browser, "Magic, Arcane");
  Pick(OvaWindow.abilities, "Magic, Witchcraft"); OvaWindow.abilities.change.DoCallback;
  Check.Check(SpellCount(t) = n, "Magic, Arcane to Magic, Witchcraft: the spells kept");
  Pick(OvaWindow.abilities, "Flight"); OvaWindow.abilities.change.DoCallback;
  Check.Check((t.spells = NIL) & ~Has(Saved(), "spells:"), "to Flight: the spells dropped");

  (* ---- Witchcraft's curses: Weaknesses (p. 58) ---- *)
  ok := Load("Cora.yaml"); c := OvaWindow.character;
  t := Named(c.traits, "Magic, Witchcraft");
  OpenLinked("Magic, Witchcraft");
  OvaLinkedDialog.spellAbility.GetLabel(label);
  Check.Check(ok & (OvaLinkedDialog.castKind = OvaRules.Weakness) & (label = "Weakness")
    & (OvaLinkedDialog.spellLevel.Minimum() = -3) & (OvaLinkedDialog.spellLevel.Maximum() = -1)
    & (OvaLinkedDialog.spellLevel.Value() = -1) & (OvaLinkedDialog.spells.Count() = 0),
    "Cora's Witchcraft: its spells are Weaknesses, -1 to -3, none yet");
  OvaLinkedDialog.spellName.SetValue("Hex"); PickAbility(OvaLinkedDialog.spellAbility, "Frail");
  Check.Check(OvaLinkedDialog.spellHelp.page = 71, "the Weakness chosen: ? at its page, Frail's 71");
  OvaLinkedDialog.spellLevel.SetValue(-2);
  OvaLinkedDialog.addSpell.DoCallback;
  OvaLinkedDialog.spells.GetText(1, s); Columns("Hex", "Frail -2 (p. 71)", "END 20", want);
  Check.Check((SpellCount(t) = 1) & (s = want), "Add: Frail -2, its END by Witchcraft +2 and its size 2: 20");
  Check.Check(Has(Saved(), "ability: Frail") & Has(Saved(), "level: -2"), "saved");
  tells := 0;
  OvaLinkedDialog.spellName.SetValue(" ");
  OvaLinkedDialog.addSpell.DoCallback;
  Check.Check((tells = 1) & (SpellCount(t) = 1), "a curse with no name: said so, not added");
  OvaLinkedDialog.close.DoCallback;
  OpenLinked("Magic, Witchcraft");
  IF OvaLinkedDialog.spells.Select(1, TRUE) THEN END; OvaLinkedDialog.spells.DoCallback;
  OvaLinkedDialog.spellName.Value(s);
  Check.Check((s = "Hex") & (OvaLinkedDialog.spellAbility.Value() = 0 + IndexOf("Frail"))
    & (OvaLinkedDialog.spellLevel.Value() = -2), "opened again and selected: its name, Weakness and level");
  OvaLinkedDialog.close.DoCallback;

  (* ---- A new Companion, and a Vehicle ---- *)
  OvaWindow.bar.Pick(OvaWindow.newItem); c := OvaWindow.character;
  Pick(OvaWindow.abilities, "Companion");
  OvaWindow.abilities.text.SetValue("Rex");
  OvaWindow.abilities.add.DoCallback;
  t := Named(c.traits, "Companion");
  Check.Check((t # NIL) & (t.partner = NIL), "a Companion added: no sheet yet");
  OvaWindow.abilityLinked.DoCallback;
  OvaLinkedDialog.partnerName.Value(s);
  Check.Check((t.partner # NIL) & (t.partner.kind = OvaCalc.CompanionSheet) & (s = "Rex") & OvaLinkedDialog.combat.Value(),
    "Companion...: its sheet made, a Companion's, named its detail, with combat stats");
  p := t.partner(OvaCharacter.Character);
  Check.Check((p.health.value = 20) & (p.endurance.value = 20) & PartnerShown(p), "a Companion's 20 and 20 (p. 52)");
  Check.Check(Has(Saved(), "companion:") & Has(Saved(), "name: Rex"), "saved as companion:");
  OvaLinkedDialog.close.DoCallback;
  Pick(OvaWindow.abilities, "Vehicle (Mecha)");
  OvaWindow.abilities.text.SetValue("");
  OvaWindow.abilities.add.DoCallback;
  OpenLinked("Vehicle (Mecha)");
  t := Named(c.traits, "Vehicle (Mecha)");
  OvaLinkedDialog.partnerName.Value(s);
  Check.Check((t.partner # NIL) & (t.partner.kind = OvaCalc.Character) & (OvaLinkedDialog.mode = OvaRules.Machine)
    & (s = "Vehicle") & Has(Saved(), "vehicle:") & Has(Saved(), "name: Vehicle"),
    "a Vehicle with no detail: a character's sheet, named Vehicle, saved as vehicle:");
  OvaLinkedDialog.close.DoCallback;
  ok := Load("Vehicle.yaml"); c := OvaWindow.character;
  OpenLinked("Vehicle");
  OvaWindow.abilityLinked.GetLabel(label);
  OvaLinkedDialog.partnerName.Value(s);
  Check.Check((label = "Vehicle...") & (OvaLinkedDialog.mode = OvaRules.Machine) & (s = "Thunderhawk")
    & (OvaLinkedDialog.attacks.Count() = 1), "Vehicle...: Thunderhawk's sheet, its attack");
  t := Named(c.traits, "Vehicle"); p := t.partner(OvaCharacter.Character);
  Check.Check(PartnerShown(p) & (p.endurance.value = 40), "its numbers: a character's 40 (p. 64)");
  OvaLinkedDialog.close.DoCallback;

  OvaWindow.Close;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestLinked.
