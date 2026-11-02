MODULE TestWindow; (* OvaWindow: the first tab, driven as a user would, and its files *)

(* Needs a display: run by make test-gui, under make test-headless or
   make test-sway (AGENTS.md: never on the desktop). Widgets are driven
   directly, as pofltk's tests do: a value set, then DoCallback; a menu
   item picked. What would wait for the user (a message, a question, a
   file chooser, the rulebook) is answered by the procedures here.

   PLAN.md, Phase 5: the model, the numbers shown, and the page beside
   every name shown; an override changes what is shown, saved, and
   computed from it, and clearing it undoes that. *)

IMPORT Check, Fl, FlBrowsers, FlMenus, OvaAttackDialog, OvaBackground, OvaCalc, OvaCharacter, OvaEntities, OvaRules, OvaSave, OvaText,
  OvaTraitPanel,
  OvaWidgets, OvaWindow,
  Out, Ropes;

CONST SavePath = "../obj/window.yaml";

TYPE Rope = Ropes.Rope;

VAR
  tells: INTEGER;           (* how many messages were shown *)
  answer, asked: INTEGER;   (* what ask answers, and how often it was asked *)
  question: Rope;           (* what ask asked last *)
  yes: BOOLEAN;             (* what confirm answers, *)
  confirmed: INTEGER;       (* and how often it was asked *)
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

PROCEDURE Ask(q: Rope): INTEGER;
BEGIN INC(asked); question := q; RETURN answer
END Ask;

PROCEDURE Confirm(q, button: Rope): BOOLEAN;
BEGIN INC(confirmed); question := q; RETURN yes
END Confirm;

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
    & Shows(OvaWindow.numbers[8], c.total) & Shows(OvaWindow.numbers[9], c.points)
    & Shows(OvaWindow.numbers[10], c.incorporeal) & Shows(OvaWindow.numbers[11], c.abilityPoints);
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
        IF p.ShowsPoints() THEN
          OvaText.AddInt(r, x.points);
          IF x.points = 1 THEN OvaText.Add(r, " pt") ELSE OvaText.Add(r, " pts") END;
          r := Ropes.AppendChar(r, 9X)
        END;
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

PROCEDURE NotBossWarned(c: OvaCharacter.Character): BOOLEAN;
  VAR w: OvaCalc.Warning;
BEGIN
  w := c.warnings; WHILE (w # NIL) & (w.code # OvaCalc.NotBoss) DO w := w.next END;
  RETURN w # NIL
END NotBossWarned;

(* The Boss Abilities in the Abilities' Choice: there for a Boss alone,
   after a divider. Leaves the type none and no Boss Ability. *)
PROCEDURE BossAbilities;
  VAR p: OvaTraitPanel.TraitPanel; c: OvaCharacter.Character; n, tv, total, lines: INTEGER;
    label, last: ARRAY 64 OF CHAR; it: OvaRules.Item;
BEGIN
  p := OvaWindow.abilities; c := OvaWindow.character;
  n := OvaRules.Count(OvaRules.Ability); lines := p.browser.Count();
  Check.Check(~p.withBoss & (p.choice.Length() = n + 1) & (FlMenus.MenuDivider * p.choice.ItemFlags(n - 1) = {}),
    "no type: the Abilities alone, no divider");
  OvaWindow.npcTypeIn.ItemLabel(1 + OvaEntities.Boss, label);
  OvaWindow.npcTypeIn.Pick(1 + OvaEntities.Boss);
  Check.Check((label = "Boss (p. 123)") & (c.kind = OvaCalc.BossSheet) & AllShown() & Has(Saved(), "npc-type: Boss"),
    "Boss chosen: its own sheet, shown, and saved");
  p.choice.ItemLabel(n, label); p.choice.ItemLabel(n + 3, last);
  Check.Check(p.withBoss & (p.choice.Length() = n + 5) & ChoiceLabelled(p)
    & (label = "Health Reserve (p. 123)") & (last = "Escape Plan (p. 123)"),
    "a Boss: the Boss Abilities after the others, each with its page");
  Check.Check((FlMenus.MenuDivider * p.choice.ItemFlags(n - 1) # {}) & (FlMenus.MenuDivider * p.choice.ItemFlags(n - 2) = {})
    & (FlMenus.MenuDivider * p.choice.ItemFlags(n) = {}), "the divider, under the last of the others");
  Check.Check(~OvaWindow.weaknesses.withBoss & (OvaWindow.weaknesses.choice.Length() = OvaRules.Count(OvaRules.Weakness) + 1),
    "the Weaknesses offer nothing new");
  tv := OvaCalc.Value(c.tv); total := OvaCalc.Value(c.abilityLevels);
  IF p.choice.SetValue(n + 2) THEN END; p.choice.DoCallback;
  it := p.Item();
  Check.Check((it # NIL) & (it.name = "Scale Advantage") & (p.help.page = 123) & ~p.spinner.Active()
    & (p.spinner.Value() = 1), "a Boss Ability chosen: its page, the level 1 and off");
  p.text.SetValue("Attack"); p.add.DoCallback; Settle;
  Check.Check((p.browser.Count() = lines + 1) & (OvaCalc.Value(c.tv) = tv + 5) & (OvaCalc.Value(c.abilityLevels) = total)
    & Has(Saved(), "Scale Advantage") & ListShown(p) & AllShown(), "added: 5 TV, no levels, saved, shown");
  Pick(p, "Attack");
  Check.Check(p.spinner.Active(), "another name: the level on again");
  SelectLine(p, LineWith(p.browser, "Scale Advantage"));
  OvaWindow.npcTypeIn.Pick(0);
  Check.Check(~p.withBoss & (p.choice.Length() = n + 1) & (FlMenus.MenuDivider * p.choice.ItemFlags(n - 1) = {})
    & NotBossWarned(c) & Has(Saved(), "Scale Advantage") & (LineWith(OvaWindow.warnings, "p. 123") > 0),
    "no longer a Boss: not offered, kept, and warned of");
  SelectLine(p, LineWith(p.browser, "Scale Advantage"));
  Check.Check((p.choice.Value() = -1) & (p.Item() = NIL) & p.spinner.Active(), "its line selected: nothing chosen, and nothing fails");
  p.remove.DoCallback; Settle;
  Check.Check((p.browser.Count() = lines) & ~NotBossWarned(c) & ~Has(Saved(), "Scale Advantage")
    & (LineWith(OvaWindow.warnings, "p. 123") = 0), "removed: the warning gone")
END BossAbilities;

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

(* Whether the Choice of characters lists labels, "|" between them,
   and shows the one shown. *)
PROCEDURE Listed(labels: ARRAY OF CHAR): BOOLEAN;
  VAR i: INTEGER; r: Rope; l: ARRAY 128 OF CHAR;
BEGIN
  r := NIL;
  FOR i := 0 TO SHORT(LEN(OvaWindow.characters^)) - 1 DO
    IF i > 0 THEN OvaText.Add(r, "|") END;
    OvaWindow.characterChoice.ItemLabel(i, l); OvaText.Add(r, l)
  END;
  RETURN Ropes.EqualString(r, labels) & (OvaWindow.characterChoice.Value() = OvaWindow.current)
    & (OvaWindow.character = OvaWindow.characters[OvaWindow.current])
END Listed;

(* Whether item i of the menu bar is active. *)
PROCEDURE Active(i: INTEGER): BOOLEAN;
BEGIN RETURN OvaWindow.bar.ItemFlags(i) * FlMenus.MenuInactive = {}
END Active;

(* Whether the window shows the character shown: its name, and every
   number. *)
PROCEDURE ShownNow(name: ARRAY OF CHAR): BOOLEAN;
  VAR v: ARRAY 128 OF CHAR;
BEGIN
  OvaWindow.nameIn.Value(v);
  RETURN (v = name) & AllShown()
END ShownNow;

PROCEDURE Load(name: ARRAY OF CHAR): BOOLEAN;
  VAR r: Rope;
BEGIN r := Ropes.FromString("data/"); OvaText.Add(r, name); RETURN OvaWindow.Load(r)
END Load;

BEGIN
  tells := 0; asked := 0; answer := OvaWindow.Cancel; chosen := NIL; page := 0;
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaWindow.ask := Ask; OvaWindow.choosePath := ChoosePath;
  OvaWindow.confirm := Confirm; yes := FALSE; confirmed := 0; question := NIL;
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
  Check.Check((OvaWindow.window.W() = 640) & (OvaWindow.tabs.Children() = 5)
    & (OvaWindow.tabs.Find(OvaWindow.sheetTab) = 0) & (OvaWindow.tabs.Find(OvaWindow.attacksTab) = 1)
    & (OvaWindow.tabs.Find(OvaWindow.backgroundTab) = 2) & (OvaWindow.tabs.Find(OvaWindow.fluffTab) = 3)
    & (OvaWindow.tabs.Find(OvaWindow.markdownTab) = 4),
    "640 wide, beside the viewer: Character, Attacks, Background, Fluff and Markdown, in that order");
  Check.Check((OvaWindow.attacksTab.Find(OvaWindow.addAttack) >= 0) & (OvaWindow.sheetTab.Find(OvaWindow.addAttack) < 0)
    & (OvaWindow.fluffTab.Find(OvaBackground.portrait) >= 0) & (OvaWindow.backgroundTab.Find(OvaBackground.portrait) < 0),
    "the attacks on the Attacks tab, the portrait on the Fluff tab");
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
  Check.Check(OvaWindow.numbers[1].Visible() & ~OvaWindow.numbers[4].Visible() & ~OvaWindow.numbers[9].Visible()
    & ~OvaWindow.numbers[10].Visible() & ~OvaWindow.numbers[11].Visible(),
    "Barrier DEFENSE shown, for Barrier; the Reserve, the Scaled Cost points and Incorporeal DEFENSE not");
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
  OvaWindow.Adopt(OvaCharacter.One(c), NIL);
  i := LineWith(OvaWindow.abilities.browser, "Magic, Testing");
  IF i > 0 THEN OvaWindow.abilities.browser.GetText(i, s) ELSE s[0] := 0X END;
  Columns("+1 Magic, Testing", "p. ?", "", want);
  Check.Check((s = want) & ListShown(OvaWindow.abilities), "an unknown name: listed with p. ?");
  i := LineWith(OvaWindow.warnings, "Magic, Testing");
  IF i > 0 THEN OvaWindow.warnings.GetText(i, s) ELSE s[0] := 0X END;
  Check.Check(s = "Magic, Testing (p. ?) isn't in the rulebook's lists", "and a warning, with p. ?");

  tells := 0; ok := Load("Wisp.yaml");
  Check.Check(ok & (tells = 0) & OvaWindow.numbers[10].Visible() & ~OvaWindow.numbers[1].Visible() & AllShown(),
    "Wisp.yaml: Incorporeal DEFENSE shown, its 6, and Barrier DEFENSE not");

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
  BossAbilities;

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

  (* ---- Several characters in a file ---- *)
  tells := 0;
  ok := Load("Acacia.yaml"); Title(s);
  Check.Check(ok & (tells = 1) & (LEN(OvaWindow.characters^) = 3) & (OvaWindow.current = 0)
    & (s = "OVA Character Generator - Acacia.yaml (1 of 3)") & ShownNow("Acacia"),
    "Acacia.yaml: her and her demons, the first shown, the title saying which of how many");
  Check.Check(Listed("1. Acacia|2. Sazza and Fraz|3. High Fructo Cezar"),
    "the Choice beside the menus lists them, by number and name, the first chosen");
  Check.Check(~Active(OvaWindow.previousItem) & ~Active(OvaWindow.moveUpItem) & Active(OvaWindow.nextItem)
    & Active(OvaWindow.moveDownItem) & Active(OvaWindow.removeCharacterItem),
    "Previous and Move Up inactive at the first; Next, Move Down and Remove active");
  OvaWindow.characterChoice.Pick(2); Title(s);
  Check.Check((OvaWindow.current = 2) & ShownNow("High Fructo Cezar") & ~OvaWindow.modified
    & (s = "OVA Character Generator - Acacia.yaml (3 of 3)") & ~Active(OvaWindow.nextItem)
    & ~Active(OvaWindow.moveDownItem) & Active(OvaWindow.previousItem),
    "the third chosen: shown, nothing changed, Next and Move Down inactive at the last");
  OvaWindow.bar.Pick(OvaWindow.previousItem);
  Check.Check((OvaWindow.current = 1) & ShownNow("Sazza and Fraz") & Listed("1. Acacia|2. Sazza and Fraz|3. High Fructo Cezar"),
    "Character > Previous Character: the second");
  OvaWindow.bar.Pick(OvaWindow.nextItem);
  Check.Check((OvaWindow.current = 2) & ShownNow("High Fructo Cezar"), "Next Character: the third again");
  OvaWindow.nameIn.SetValue("Cezar"); OvaWindow.nameIn.DoCallback; Title(s);
  Check.Check(Listed("1. Acacia|2. Sazza and Fraz|3. Cezar") & OvaWindow.modified
    & (s = "OVA Character Generator - Acacia.yaml (3 of 3) *"), "renamed: the Choice follows, the file modified");

  OvaWindow.bar.Pick(OvaWindow.addCharacterItem);
  Check.Check((LEN(OvaWindow.characters^) = 4) & (OvaWindow.current = 3) & ShownNow("")
    & (OvaWindow.abilities.browser.Count() = 0) & (RowCount() = 0)
    & Listed("1. Acacia|2. Sazza and Fraz|3. Cezar|4. (no name)"),
    "Character > Add Character: a new one, last, shown");
  OvaWindow.nameIn.SetValue("Imp & Co"); OvaWindow.nameIn.DoCallback;
  Check.Check(Listed("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Imp && Co"), "an & in a name doubled, so FLTK shows it");

  OvaWindow.characterChoice.Pick(0);
  OvaWindow.bar.Pick(OvaWindow.duplicateItem);
  c := OvaWindow.character;
  Check.Check((LEN(OvaWindow.characters^) = 5) & (OvaWindow.current = 4) & ShownNow("Acacia")
    & (c # OvaWindow.characters[0]) & Ropes.Equal(OvaSave.ToText(c), OvaSave.ToText(OvaWindow.characters[0])),
    "Duplicate Character: a copy of Acacia, last, shown, the same when saved");
  Type(OvaWindow.numbers[2], "55");
  Check.Check(c.health.overridden & ~OvaWindow.characters[0].health.overridden,
    "the copy's HEALTH overridden, the first's not: they share nothing");
  OvaWindow.bar.Pick(OvaWindow.moveUpItem); Title(s);
  Check.Check((OvaWindow.current = 3) & (OvaWindow.characters[3] = c) & (s = "OVA Character Generator - Acacia.yaml (4 of 5) *")
    & Listed("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Acacia|5. Imp && Co") & ShownNow("Acacia"),
    "Move Up: the copy fourth, still shown");
  OvaWindow.bar.Pick(OvaWindow.moveDownItem);
  Check.Check((OvaWindow.current = 4) & (OvaWindow.characters[4] = c)
    & Listed("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Imp && Co|5. Acacia"), "Move Down: last again");

  confirmed := 0; yes := FALSE;
  OvaWindow.bar.Pick(OvaWindow.removeCharacterItem);
  Check.Check((confirmed = 1) & Ropes.EqualString(question, "Remove Acacia from the file?")
    & (LEN(OvaWindow.characters^) = 5), "Remove Character...: asked first; Cancel removes nothing");
  yes := TRUE;
  OvaWindow.bar.Pick(OvaWindow.removeCharacterItem);
  Check.Check((LEN(OvaWindow.characters^) = 4) & (OvaWindow.current = 3) & ShownNow("Imp & Co")
    & Listed("1. Acacia|2. Sazza and Fraz|3. Cezar|4. Imp && Co"), "removed, the last: the one before it shown");
  OvaWindow.characterChoice.Pick(1);
  OvaWindow.bar.Pick(OvaWindow.removeCharacterItem);
  Check.Check((OvaWindow.current = 1) & ShownNow("Cezar") & Listed("1. Acacia|2. Cezar|3. Imp && Co"),
    "removed from the middle: the one after it shown");

  (* Saved: every character, in order; each portrait rebased. *)
  OvaCharacter.SetText(OvaWindow.characters[2].hasPortrait, OvaWindow.characters[2].portrait,
    Ropes.FromString("images/imp.png"));
  chosen := Ropes.FromString("../obj/several.yaml");
  OvaWindow.bar.Pick(OvaWindow.saveAsItem); Title(s);
  Check.Check(~OvaWindow.modified & (s = "OVA Character Generator - several.yaml (2 of 3)")
    & Ropes.EqualString(OvaWindow.characters[2].portrait, "../test/data/images/imp.png"),
    "Save As: saved, and a portrait not shown rebased too");
  text := OvaSave.AllToText(OvaWindow.characters);
  tells := 0;
  ok := Load("../../obj/several.yaml"); Title(s);
  Check.Check(ok & (tells = 0) & (s = "OVA Character Generator - several.yaml (1 of 3)")
    & Listed("1. Acacia|2. Cezar|3. Imp && Co") & Ropes.Equal(OvaSave.AllToText(OvaWindow.characters), text),
    "loaded again: all three, in order, the same, with nothing to say");
  OvaWindow.nameIn.SetValue("Acacia II"); OvaWindow.nameIn.DoCallback;
  answer := OvaWindow.Cancel; asked := 0;
  OvaWindow.bar.Pick(OvaWindow.newItem);
  Check.Check((asked = 1) & Ropes.EqualString(question, "Save the changes to several.yaml first?"),
    "New with changes: the question names the file");
  yes := TRUE;
  OvaWindow.bar.Pick(OvaWindow.removeCharacterItem); OvaWindow.bar.Pick(OvaWindow.removeCharacterItem);
  Title(s);
  Check.Check((LEN(OvaWindow.characters^) = 1) & ~Active(OvaWindow.removeCharacterItem)
    & (s = "OVA Character Generator - several.yaml *") & Listed("1. Imp && Co"),
    "down to one: Remove inactive, and the title without a count");
  confirmed := 0;
  OvaWindow.bar.Pick(OvaWindow.removeCharacterItem);
  Check.Check((confirmed = 0) & (LEN(OvaWindow.characters^) = 1), "and Remove does nothing: a file holds at least one");
  answer := OvaWindow.Discard;
  OvaWindow.bar.Pick(OvaWindow.newItem);
  Check.Check((LEN(OvaWindow.characters^) = 1) & Listed("1. (no name)"), "New: one new character");

  OvaWindow.Close;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestWindow.
