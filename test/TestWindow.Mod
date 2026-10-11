MODULE TestWindow; (* OvaWindow: the first tab, driven as a user would, and its files *)

(* Needs a display: run by make test-gui, under make test-headless or
   make test-sway (AGENTS.md: never on the desktop). Widgets are driven
   directly, as pofltk's tests do: a value set, then DoCallback; a menu
   item picked. What would wait for the user (a message, a question, a
   file chooser, the rulebook) is answered by the procedures here.

   PLAN.md, Phase 5: the model, the numbers shown, and the page beside
   every name shown; an override changes what is shown, saved, and
   computed from it, and clearing it undoes that. *)

IMPORT Check, Fl, FlBrowsers, OvaAttackDialog, OvaCalc, OvaCharacter, OvaEntities, OvaRules, OvaSave, OvaText,
  OvaTraitPanel,
  OvaWidgets, OvaWindow,
  Out, Ropes;

CONST SavePath = "../obj/window.yaml";

TYPE Rope = Ropes.Rope;

VAR
  tells: INTEGER;           (* how many messages were shown *)
  answer, asked: INTEGER;   (* what ask answers, and how often it was asked *)
  chosen: Rope;             (* what choosePath answers; NIL: cancelled *)
  page: INTEGER;            (* the last page openPage was asked for *)
  c: OvaCharacter.Character;
  t: OvaCharacter.Trait;
  r: OvaWindow.AttackRow;
  a: OvaCalc.Attack;
  text: Rope;
  s, want: ARRAY 256 OF CHAR;
  i, n, before: INTEGER;
  ok: BOOLEAN;

(* ---- What would wait for the user ---- *)

PROCEDURE Tell(text: Rope);
  VAR s: OvaText.String;
BEGIN INC(tells); s := OvaText.Chars(text); Out.String("    told: "); Out.String(s^); Out.Ln
END Tell;

PROCEDURE Ask(question: Rope): INTEGER;
BEGIN INC(asked); RETURN answer
END Ask;

PROCEDURE ChoosePath(save: BOOLEAN; VAR p: Rope): BOOLEAN;
BEGIN p := chosen; RETURN chosen # NIL
END ChoosePath;

PROCEDURE OpenPage(p: INTEGER);
BEGIN page := p
END OpenPage;

(* ---- Driving and looking ---- *)

PROCEDURE ShowIt;
BEGIN
  OvaWindow.window.Show;
  OvaWindow.window.WaitForExpose;
  IF Fl.Check() THEN END
END ShowIt;

(* Lets FLTK run what it put off: timers. *)
PROCEDURE Settle;
  VAR i: INTEGER;
BEGIN FOR i := 1 TO 5 DO Fl.Wait(0.01D0) END
END Settle;

(* a, b and c joined by tabs, as a browser's columns; c "" for two. *)
PROCEDURE Columns(a, b, c: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
  VAR r: Rope; x: OvaText.String;
BEGIN
  r := Ropes.FromString(a); r := Ropes.AppendChar(r, 9X); OvaText.Add(r, b);
  IF c # "" THEN r := Ropes.AppendChar(r, 9X); OvaText.Add(r, c) END;
  x := OvaText.Chars(r); COPY(x^, s)
END Columns;

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

(* Whether every number box of the sheet and the combat box shows the
   model's number. *)
PROCEDURE AllShown(): BOOLEAN;
  VAR c: OvaCharacter.Character; ok: BOOLEAN; r: OvaWindow.AttackRow;
BEGIN
  c := OvaWindow.character;
  ok := Shows(OvaWindow.numbers[0], c.defense) & Shows(OvaWindow.numbers[1], c.barrier)
    & Shows(OvaWindow.numbers[2], c.health) & Shows(OvaWindow.numbers[3], c.endurance)
    & Shows(OvaWindow.numbers[4], c.reserve) & Shows(OvaWindow.numbers[5], c.tv)
    & Shows(OvaWindow.numbers[6], c.abilityLevels) & Shows(OvaWindow.numbers[7], c.weaknessLevels)
    & Shows(OvaWindow.numbers[8], c.total) & Shows(OvaWindow.numbers[9], c.points);
  r := OvaWindow.rows;
  WHILE ok & (r # NIL) DO
    ok := Shows(r.roll, r.attack.roll) & Shows(r.dx, r.attack.dx) & Shows(r.end, r.attack.end);
    r := r.nextRow
  END;
  RETURN ok
END AllShown;

(* Whether p's browser has a line for each trait of its kind, in the
   model's order: "+2 Flight (on a broom)", a tab, and its page. *)
PROCEDURE ListShown(p: OvaTraitPanel.TraitPanel): BOOLEAN;
  VAR l: OvaCalc.Trait; x: OvaCharacter.Trait; r: Rope; line, pg: ARRAY 256 OF CHAR; n: INTEGER; ok: BOOLEAN;
BEGIN
  ok := TRUE; n := 0; l := OvaWindow.character.traits;
  WHILE ok & (l # NIL) DO
    IF l.kind = p.kind THEN
      INC(n); x := l(OvaCharacter.Trait);
      IF n > p.browser.Count() THEN ok := FALSE
      ELSE
        p.browser.GetText(n, line);
        IF x.level > 0 THEN r := Ropes.FromString("+") ELSE r := NIL END;
        OvaText.AddInt(r, x.level); OvaText.Add(r, " "); r := Ropes.Cat(r, x.name);
        IF x.hasDetail THEN OvaText.Add(r, " ("); r := Ropes.Cat(r, x.detail); OvaText.Add(r, ")") END;
        r := Ropes.AppendChar(r, 9X);
        OvaRules.PageText(x.item, pg); OvaText.Add(r, pg);
        ok := Ropes.EqualString(r, line);
        IF ~ok THEN Out.String("    line "); Out.Int(n, 0); Out.String(": "); Out.String(line); Out.Ln END
      END
    END;
    l := l.next
  END;
  RETURN ok & (n = p.browser.Count())
END ListShown;

(* Whether every name in p's Choice is its item's label, with its page. *)
PROCEDURE ChoiceLabelled(p: OvaWidgets.Panel): BOOLEAN;
  VAR i: INTEGER; label, want: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  ok := TRUE;
  FOR i := 0 TO OvaRules.Count(p.kind) - 1 DO
    p.choice.ItemLabel(i, label); OvaRules.Label(OvaRules.Get(p.kind, i), want);
    ok := ok & (label = want)
  END;
  RETURN ok
END ChoiceLabelled;

(* Types text into box b and leaves it. *)
PROCEDURE Type(b: OvaWidgets.NumberBox; text: ARRAY OF CHAR);
BEGIN b.entry.SetValue(text); b.entry.DoCallback
END Type;

(* Chooses name in p's Choice, as the user does. *)
PROCEDURE Pick(p: OvaWidgets.Panel; name: ARRAY OF CHAR);
  VAR it: OvaRules.Item; i: INTEGER;
BEGIN
  it := OvaRules.Find(name); ASSERT(it # NIL);
  i := 0; WHILE OvaRules.Get(p.kind, i) # it DO INC(i) END;
  IF p.choice.SetValue(i) THEN END;
  p.choice.DoCallback
END Pick;

(* Selects p's line, as a click does. *)
PROCEDURE SelectLine(p: OvaWidgets.Panel; line: INTEGER);
BEGIN IF p.browser.Select(line, TRUE) THEN END; p.browser.DoCallback
END SelectLine;

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

PROCEDURE Selected(p: OvaWidgets.Panel; VAR s: ARRAY OF CHAR);
BEGIN IF p.browser.Value() > 0 THEN p.browser.GetText(p.browser.Value(), s) ELSE s[0] := 0X END
END Selected;

(* The trait named name; NIL if none. *)
PROCEDURE TraitNamed(name: ARRAY OF CHAR): OvaCharacter.Trait;
  VAR l: OvaCalc.Trait;
BEGIN
  l := OvaWindow.character.traits;
  WHILE (l # NIL) & ~Ropes.EqualString(l(OvaCharacter.Trait).name, name) DO l := l.next END;
  IF l = NIL THEN RETURN NIL ELSE RETURN l(OvaCharacter.Trait) END
END TraitNamed;

PROCEDURE Saved(): Rope;
BEGIN RETURN OvaSave.ToText(OvaWindow.character)
END Saved;

PROCEDURE Has(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.Find(r, s, 0) >= 0
END Has;

PROCEDURE Title(VAR s: ARRAY OF CHAR);
BEGIN OvaWindow.window.GetLabel(s)
END Title;

PROCEDURE RowCount(): INTEGER;
  VAR r: OvaWindow.AttackRow; n: INTEGER;
BEGIN
  n := 0; r := OvaWindow.rows; WHILE r # NIL DO INC(n); r := r.nextRow END;
  RETURN n
END RowCount;

PROCEDURE LastRow(): OvaWindow.AttackRow;
  VAR r: OvaWindow.AttackRow;
BEGIN
  r := OvaWindow.rows; WHILE (r # NIL) & (r.nextRow # NIL) DO r := r.nextRow END;
  RETURN r
END LastRow;

PROCEDURE Load(name: ARRAY OF CHAR): BOOLEAN;
  VAR r: Rope;
BEGIN r := Ropes.FromString("data/"); OvaText.Add(r, name); RETURN OvaWindow.Load(r)
END Load;

BEGIN
  tells := 0; asked := 0; answer := OvaWindow.Cancel; chosen := NIL; page := 0;
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaWindow.ask := Ask; OvaWindow.choosePath := ChoosePath;
  OvaWidgets.openPage := OpenPage;

  (* ---- The frame ---- *)
  Check.Check(OvaWindow.window.IsOpen() & ~OvaWindow.window.Shown(), "the window opens, not shown until asked");
  i := OvaWindow.bar.FindIndex("&File/&Quit");
  Check.Check((i >= 0) & (i = OvaWindow.quitItem), "the menu bar has File > Quit");
  Check.Check((OvaWindow.bar.FindIndex("&File/&New") = OvaWindow.newItem)
    & (OvaWindow.bar.FindIndex("&File/&Open...") = OvaWindow.openItem)
    & (OvaWindow.bar.FindIndex("&File/&Save") = OvaWindow.saveItem)
    & (OvaWindow.bar.FindIndex("&File/Save &As...") = OvaWindow.saveAsItem)
    & (OvaWindow.bar.FindIndex("&Rulebook/&Open") = OvaWindow.rulebookItem),
    "and New, Open, Save, Save As, and Rulebook > Open");
  Check.Check(OvaWindow.tabs.Value() = OvaWindow.sheetTab, "the Character tab is shown first");
  Check.Check(ChoiceLabelled(OvaWindow.abilities) & ChoiceLabelled(OvaWindow.weaknesses),
    "every name in the Choices has its page: Attack (p. 50)");
  OvaWindow.bar.Pick(OvaWindow.rulebookItem);
  Check.Check(page = 1, "Rulebook > Open opens it at page 1");
  ShowIt;

  (* ---- A character loaded ---- *)
  ok := Load("Ai.yaml");
  Check.Check(ok & (tells = 0), "Ai.yaml loads, with nothing to say");
  OvaWindow.nameIn.Value(s);
  Check.Check(s = "Ai", "the name is shown");
  Title(s);
  Check.Check(s = "OVA Character Generator - Ai.yaml", "the title is the file's name");
  Check.Check(ListShown(OvaWindow.abilities) & ListShown(OvaWindow.weaknesses),
    "every Ability and Weakness is listed with its page");
  Check.Check(AllShown(), "every number shown is the model's");
  Check.Check(OvaWindow.numbers[1].Visible() & ~OvaWindow.numbers[4].Visible() & ~OvaWindow.numbers[9].Visible(),
    "Barrier DEFENSE shown, for Barrier; the Reserve and the Scaled Cost points not");
  Check.Check(RowCount() = 2, "a row in the combat box for each attack");
  r := OvaWindow.rows; r.name.Value(s);
  Check.Check(s = "Telekinetic Push", "the first is Telekinetic Push");

  (* ---- Overrides ---- *)
  c := OvaWindow.character;
  n := c.health.value;
  Check.Check(~c.health.overridden & ~Has(Saved(), "overrides"), "Ai has no overrides");
  Type(OvaWindow.numbers[2], "55");
  Check.Check(c.health.overridden & (OvaCalc.Value(c.health) = 55) & (c.health.value = n),
    "an override: HEALTH 55, the computed number kept");
  Check.Check(AllShown(), "and shown, beside the computed number");
  Check.Check(OvaWindow.modified, "a change marks the character modified");
  Title(s);
  Check.Check(s = "OVA Character Generator - Ai.yaml *", "and the title says so");
  Check.Check(Has(Saved(), "health: 55") & Has(Saved(), "overrides"), "saved: health 55, in overrides");
  Type(OvaWindow.numbers[2], "");
  Check.Check(~c.health.overridden & (OvaCalc.Value(c.health) = n) & AllShown(),
    "an empty box: the computed number again");
  Check.Check(~Has(Saved(), "overrides"), "and no override saved");
  Type(OvaWindow.numbers[2], "55");
  tells := 0;
  Type(OvaWindow.numbers[2], "lots");
  Check.Check((tells = 1) & ~c.health.overridden & AllShown(), "text that isn't a number: said so, and the box emptied");
  Type(r.dx, "1/2");
  Check.Check(r.attack.dx.overridden & OvaCalc.Half(r.attack.dx) & AllShown(), "a DX may be 1/2");
  tells := 0;
  Type(OvaWindow.numbers[2], "1/2");
  Check.Check((tells = 1) & ~c.health.overridden, "HEALTH may not");
  Type(r.dx, "");

  (* An override counts in what is computed from it: Braun's TV comes
     from his ROLL, overridden to -2. *)
  ok := Load("Braun.yaml");
  c := OvaWindow.character; r := OvaWindow.rows;
  Check.Check(ok & r.attack.roll.overridden & (OvaCalc.Value(r.attack.roll) = -2) & (OvaCalc.Value(c.tv) = 0),
    "Braun: ROLL -2, overridden, and TV 0");
  Type(r.roll, "");
  Check.Check(~r.attack.roll.overridden & (OvaCalc.Value(c.tv) # 0) & AllShown(),
    "ROLL's override cleared: TV computed from the rules' ROLL");
  Type(r.roll, "-2");
  Check.Check((OvaCalc.Value(c.tv) = 0) & AllShown(), "and set again: TV 0 again");

  (* A name the rulebook's lists don't have: "p. ?", and a warning that
     says so. *)
  t := OvaCharacter.NewTrait(NIL, OvaRules.Ability, 1, Ropes.FromString("Magic, Testing"), NIL);
  OvaCharacter.InsertTrait(c.traits, t);
  OvaWindow.Adopt(c, NIL);
  i := LineWith(OvaWindow.abilities.browser, "Magic, Testing");
  IF i > 0 THEN OvaWindow.abilities.browser.GetText(i, s) ELSE s[0] := 0X END;
  Columns("+1 Magic, Testing", "p. ?", "", want);
  Check.Check((s = want) & ListShown(OvaWindow.abilities), "an unknown name: listed with p. ?");
  i := LineWith(OvaWindow.warnings, "Magic, Testing");
  IF i > 0 THEN OvaWindow.warnings.GetText(i, s) ELSE s[0] := 0X END;
  Check.Check(s = "Magic, Testing (p. ?) isn't in the rulebook's lists", "and a warning, with p. ?");

  (* ---- Abilities and Weaknesses ---- *)
  ok := Load("Ai.yaml"); c := OvaWindow.character;
  before := c.abilityLevels.value;
  Pick(OvaWindow.abilities, "Flight");
  Check.Check(OvaWindow.abilities.help.page = 54, "choosing Flight turns ? to its page, 54");
  OvaWindow.abilities.help.DoCallback;
  Check.Check(page = 54, "and ? opens the rulebook there");
  OvaWindow.abilities.spinner.SetValue(2);
  OvaWindow.abilities.text.SetValue("on a broom");
  OvaWindow.abilities.add.DoCallback;
  Selected(OvaWindow.abilities, s); Columns("+2 Flight (on a broom)", "p. 54", "", want);
  Check.Check(s = want, "Add: its line selected, with its page");
  Check.Check((c.abilityLevels.value = before + 2) & AllShown(), "and counted: the Abilities' levels +2");
  Check.Check(ListShown(OvaWindow.abilities), "the list in the model's order");
  OvaWindow.abilities.spinner.SetValue(4);
  OvaWindow.abilities.change.DoCallback;
  Selected(OvaWindow.abilities, s); Columns("+4 Flight (on a broom)", "p. 54", "", want);
  Check.Check((s = want) & (c.abilityLevels.value = before + 4) & ListShown(OvaWindow.abilities), "Change: Flight +4");
  OvaWindow.abilities.remove.DoCallback;
  Check.Check((c.abilityLevels.value = before) & ListShown(OvaWindow.abilities)
    & (OvaWindow.abilities.browser.Value() = 0) & (TraitNamed("Flight") = NIL), "Remove");
  n := OvaWindow.abilities.browser.Count();
  OvaWindow.abilities.remove.DoCallback;
  Check.Check(OvaWindow.abilities.browser.Count() = n, "Remove with nothing selected removes nothing");

  Pick(OvaWindow.weaknesses, "Endurance Use");
  OvaWindow.weaknesses.spinner.SetValue(-2);
  OvaWindow.weaknesses.text.SetValue("Telekinesis");
  OvaWindow.weaknesses.add.DoCallback;
  Selected(OvaWindow.weaknesses, s); Columns("-2 Endurance Use (Telekinesis)", "p. 70", "", want);
  Check.Check((s = want) & ListShown(OvaWindow.weaknesses), "a Weakness added: Endurance Use -2 on Telekinesis");
  t := TraitNamed("Telekinesis");
  SelectLine(OvaWindow.abilities, LineWith(OvaWindow.abilities.browser, "Telekinesis"));
  OvaWindow.abilityEnd.shown.Value(s);
  Check.Check((s = "10") & OvaWindow.abilityEnd.Active() & Shows(OvaWindow.abilityEnd, t.end),
    "Telekinesis selected: its END, 10, shown, with its box");
  Check.Check(OvaWindow.abilities.help.page = 62, "and ? at its page, 62");
  Type(OvaWindow.abilityEnd, "15");
  Check.Check(t.end.overridden & (OvaCalc.Value(t.end) = 15) & Shows(OvaWindow.abilityEnd, t.end),
    "its END overridden");
  Type(OvaWindow.abilityEnd, "");

  (* ---- An Ability's Perks and Flaws ---- *)
  OvaWindow.abilityMods.DoCallback;
  Check.Check(OvaAttackDialog.dialog # NIL, "Perks and Flaws... opens the dialog");
  Check.Check(ChoiceLabelled(OvaAttackDialog.perks) & ChoiceLabelled(OvaAttackDialog.flaws),
    "every Perk and Flaw in its Choice has its page");
  Pick(OvaAttackDialog.perks, "Area Effect");
  OvaAttackDialog.perks.add.DoCallback;
  n := OvaCalc.Value(t.end);
  Check.Check((t.mods # NIL) & (n > 10) & Shows(OvaAttackDialog.end, t.end),
    "a Perk: the Ability's END goes up, shown in the dialog");
  OvaAttackDialog.Cancel;
  Check.Check((OvaAttackDialog.dialog = NIL) & (t.mods = NIL) & (OvaCalc.Value(t.end) = 10)
    & Shows(OvaWindow.abilityEnd, t.end), "Cancel: the Perk taken out again");
  OvaWindow.abilityMods.DoCallback;
  Pick(OvaAttackDialog.perks, "Area Effect");
  OvaAttackDialog.perks.add.DoCallback;
  OvaAttackDialog.Ok;
  Check.Check((OvaAttackDialog.dialog = NIL) & (OvaCalc.Value(t.end) = n) & Shows(OvaWindow.abilityEnd, t.end)
    & AllShown(), "OK: kept, and shown in the window");

  (* ---- Attacks ---- *)
  n := RowCount();
  OvaWindow.addAttack.DoCallback;
  Check.Check(OvaAttackDialog.dialog # NIL, "Add attack... opens the dialog");
  OvaAttackDialog.nameIn.SetValue("Wind Lance");
  Pick(OvaAttackDialog.perks, "Accurate");
  OvaAttackDialog.perks.spinner.SetValue(2);
  OvaAttackDialog.perks.add.DoCallback;
  Selected(OvaAttackDialog.perks, s); Columns("Accurate x2", "+10", "p. 83", want);
  Check.Check(s = want, "a Perk listed: its count, cost and page");
  Pick(OvaAttackDialog.flaws, "Cancel");
  OvaAttackDialog.flaws.text.Value(s);
  Check.Check(s = "-20", "Cancel's cost offered: its least, -20");
  OvaAttackDialog.flaws.text.SetValue("-15");
  OvaAttackDialog.flaws.add.DoCallback;
  Selected(OvaAttackDialog.flaws, s); Columns("Cancel", "-15", "p. 87", want);
  Check.Check(s = want, "a Flaw listed, with the cost chosen");
  a := c.attacks; WHILE a.next # NIL DO a := a.next END;  (* its row comes with OK *)
  Check.Check(Shows(OvaAttackDialog.roll, a.roll) & Shows(OvaAttackDialog.end, a.end),
    "the dialog's numbers are the attack's, as it changes");
  tells := 0;
  OvaAttackDialog.flaws.text.SetValue("a lot");
  OvaAttackDialog.flaws.change.DoCallback;
  Check.Check(tells = 1, "a cost that isn't a number: said so");
  OvaAttackDialog.Ok;
  Check.Check(RowCount() = n + 1, "OK: a row for the new attack");
  r := LastRow(); r.name.Value(s);
  Check.Check((s = "Wind Lance") & AllShown(), "its name and numbers");
  text := Saved();
  Check.Check(Has(text, "Wind Lance") & Has(text, "counts-as: 2") & Has(text, "cost: -15"),
    "saved with its Perks and Flaws");
  r.edit.DoCallback;
  SelectLine(OvaAttackDialog.perks, 1);
  OvaAttackDialog.perks.remove.DoCallback;
  Check.Check((OvaAttackDialog.perks.browser.Count() = 0) & ~Has(Saved(), "counts-as: 2"), "Edit: a Perk removed");
  OvaAttackDialog.Cancel;
  Check.Check(Ropes.Equal(Saved(), text) & (RowCount() = n + 1) & AllShown(), "Cancel: the attack as it was");
  OvaWindow.addAttack.DoCallback;
  OvaAttackDialog.Cancel;
  Check.Check((RowCount() = n + 1) & Ropes.Equal(Saved(), text), "Cancel on a new attack: no attack added");
  OvaWindow.addAttack.DoCallback;
  OvaAttackDialog.nameIn.SetValue(" ");
  tells := 0;
  OvaAttackDialog.Ok;
  Check.Check((tells = 1) & (OvaAttackDialog.dialog # NIL), "OK with no name: said so, and the dialog stays");
  OvaAttackDialog.Cancel;
  r := LastRow(); r.remove.DoCallback;
  Settle;
  Check.Check((RowCount() = n) & ~Has(Saved(), "Wind Lance") & AllShown(), "Remove: the row and the attack gone");

  (* ---- Names and notes ---- *)
  OvaWindow.playerIn.SetValue("Sam"); OvaWindow.playerIn.DoCallback;
  OvaWindow.combatNotes.SetValue("Down to 10 HEALTH."); OvaWindow.combatNotes.DoCallback;
  Check.Check(Has(Saved(), "player: Sam") & Has(Saved(), "Down to 10 HEALTH."), "the player and Combat Notes saved");

  (* ---- The NPC type (p. 123-124) ---- *)
  c := OvaWindow.character;
  OvaWindow.npcTypeIn.ItemLabel(0, s); OvaWindow.npcTypeIn.ItemLabel(2, want);
  Check.Check((OvaWindow.npcTypeIn.Value() = 0) & (s = "none") & (want = "Secondary (p. 123)"),
    "the NPC type: none, each type with its page");
  OvaWindow.npcTypeIn.Pick(1 + OvaEntities.Secondary);
  Check.Check(c.hasNpcType & (c.npcType = OvaEntities.Secondary) & (c.kind = OvaCalc.CompanionSheet)
    & (OvaCalc.Value(c.health) < 40) & AllShown() & Has(Saved(), "npc-type: Secondary"),
    "Secondary chosen: a Companion's sheet, shown, and saved");
  OvaWindow.npcTypeIn.Pick(1 + OvaEntities.Extra);
  Check.Check((c.kind = OvaCalc.ExtraSheet) & (OvaCalc.Value(c.tv) = 1) & AllShown() & Has(Saved(), "npc-type: Extra"),
    "Extra chosen: TV 1");
  OvaWindow.npcTypeIn.Pick(0);
  Check.Check(~c.hasNpcType & (c.kind = OvaCalc.Character) & AllShown() & ~Has(Saved(), "npc-type"),
    "none chosen: a character's sheet, no npc-type saved");

  (* ---- Files ---- *)
  chosen := Ropes.FromString(SavePath);
  OvaWindow.bar.Pick(OvaWindow.saveAsItem);
  Title(s);
  Check.Check(~OvaWindow.modified & (s = "OVA Character Generator - window.yaml"), "Save As: saved, the title its name");
  c := OvaWindow.character; tells := 0;
  ok := OvaWindow.Load(chosen);
  Check.Check(ok & (tells = 0) & (OvaWindow.character # c) & Ropes.Equal(OvaSave.ToText(c), Saved()),
    "loaded again: the same, with nothing to say");
  asked := 0;
  OvaWindow.bar.Pick(OvaWindow.newItem);
  Check.Check((asked = 0) & (OvaWindow.character.name = NIL) & (OvaWindow.abilities.browser.Count() = 0)
    & (RowCount() = 0) & AllShown(), "New: nothing unsaved, nothing asked, an empty sheet");
  OvaWindow.nameIn.SetValue("Someone"); OvaWindow.nameIn.DoCallback;
  Check.Check(Ropes.EqualString(OvaWindow.character.name, "Someone") & OvaWindow.modified, "a name typed");
  answer := OvaWindow.Cancel;
  OvaWindow.bar.Pick(OvaWindow.newItem);
  Check.Check((asked = 1) & Ropes.EqualString(OvaWindow.character.name, "Someone"),
    "New with changes: asked; Cancel keeps them");
  OvaWindow.bar.Pick(OvaWindow.quitItem);
  Check.Check((asked = 2) & OvaWindow.window.Shown(), "Quit with changes: asked; Cancel stays");
  answer := OvaWindow.Discard;
  OvaWindow.bar.Pick(OvaWindow.quitItem);
  IF Fl.Check() THEN END;
  Check.Check((asked = 3) & ~OvaWindow.window.Shown(), "Don't save: the window goes, which ends Fl.Run");
  ShowIt;
  OvaWindow.window.DoCallback;  (* what the window's close button does *)
  IF Fl.Check() THEN END;
  Check.Check((asked = 4) & ~OvaWindow.window.Shown(), "the close button asks too");

  (* ---- A Sample NPC loaded ---- *)
  tells := 0;
  ok := Load("Jiro.yaml");
  Check.Check(ok & (tells = 0) & (OvaWindow.npcTypeIn.Value() = 1 + OvaEntities.Secondary) & AllShown(),
    "Jiro.yaml: his type shown, and his numbers the rules' for it, so nothing to say");

  OvaWindow.Close;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestWindow.
