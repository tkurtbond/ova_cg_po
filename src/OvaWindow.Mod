MODULE OvaWindow; (* The main window: its menu bar, the sheet's first two tabs, and the file *)

(* PLAN.md, "The window". One window, narrow enough to sit beside the
   rulebook's viewer, a menu bar, and four tabs, each a column: the
   first two the sheet's right half, "Character" (the names, the
   Abilities and Weaknesses, the totals and warnings, the Combat Notes)
   and "Attacks" (the combat box and the sheet's numbers), with a box
   beside every computed number for its override; the other two the
   sheet's left half, "Background" and "Fluff", OvaBackground's.

   The character is OvaCharacter's, in a module variable: every change
   a widget makes goes into it, then OvaCharacter.Recompute, then the
   window shows it again, so no widget holds the only copy of anything.
   Every widget, and every record a callback reaches, is kept in module
   variables, so poc's collector sees them (it can't see FLTK's
   pointers).

   What would wait for the user -- a message, a question, a file
   chooser, the rulebook's viewer -- goes through a procedure variable
   (tell, ask, choosePath, choosePdf, askText, and OvaWidgets.openPage),
   so a test can answer it.

   The rulebook's path and the viewer the user chooses are kept in the
   preferences (UsePreferences), between runs. *)

IMPORT Fl, FlButtons, FlBrowsers, FlDialogs, FlInputs, FlLayout, FlMenus, FlPreferences, OvaAttackDialog,
  OvaBackground, OvaCalc, OvaCharacter, OvaEntities, OvaLinkedDialog, OvaPaths, OvaRules, OvaSettings, OvaTraitPanel,
  OvaSave, OvaText, OvaViewer, OvaWidgets, Ropes;

CONST
  Width = 640; Height = 800; BarHeight = 25; TabHeight = 25;
  Title = "OVA Character Generator";
  Row = 25;
  (* Each tab's one column. *)
  LeftX = 10; ColumnW = 620;
  Top = BarHeight + TabHeight + 10;
  (* The combat box: rows shown before it scrolls, each Row + 5 high;
     an attack's name's width. *)
  AttackRows = 17; RowH = 30; NameW = 180;

  (* SheetNumber.which *)
  Defense = 0; Barrier = 1; Health = 2; Endurance = 3; Reserve = 4; TV = 5;
  AbilityLevels = 6; WeaknessLevels = 7; Total = 8; Points = 9; Incorporeal = 10;
  NSheetNumbers = 11;
  (* AttackNumber.which *)
  Roll = 0; DX = 1; End = 2;

  (* ask's answers *)
  SaveFirst* = 0; Discard* = 1; Cancel* = 2;

TYPE
  Rope = Ropes.Rope;

  (* One of the sheet's numbers. *)
  SheetNumber = POINTER TO RECORD (OvaWidgets.TargetDesc) which: INTEGER END;
  (* An attack's ROLL, DX or END. *)
  AttackNumber = POINTER TO RECORD (OvaWidgets.TargetDesc) attack: OvaCalc.Attack; which: INTEGER END;
  (* An Ability's END. *)
  TraitEnd = POINTER TO RECORD (OvaWidgets.TargetDesc) trait: OvaCalc.Trait END;

  (* One attack's row in the combat box. *)
  AttackRow* = POINTER TO AttackRowDesc;
  AttackRowDesc* = RECORD (Fl.GroupDesc)
    attack-: OvaCharacter.Attack;
    name-: FlInputs.Output;
    roll-, dx-, end-: OvaWidgets.NumberBox;
    edit-, remove-: FlButtons.Button;
    nextRow-: AttackRow
  END;

VAR
  window-: Fl.DoubleWindow;
  bar-: FlMenus.MenuBar;
  tabs-: FlLayout.Tabs;
  sheetTab-, attacksTab-, backgroundTab-, fluffTab-: Fl.Group;
  newItem-, openItem-, saveItem-, saveAsItem-, quitItem-: INTEGER;
  limitsItem-, rulebookItem-, choosePdfItem-, viewerItem-: INTEGER;

  (* The character, the file it came from or was saved to (NIL: none),
     and whether it has changed since. *)
  character-: OvaCharacter.Character;
  path-: Rope;
  modified-: BOOLEAN;

  nameIn-, playerIn-, taglineIn-: FlInputs.Input;
  (* The NPC type: item 0 none, then OvaEntities.Heroic, Secondary,
     Extra, each at its constant + 1. *)
  npcTypeIn-: FlMenus.Choice;
  abilities-, weaknesses-: OvaTraitPanel.TraitPanel;
  abilityEnd-: OvaWidgets.NumberBox;   (* the chosen Ability's END *)
  abilityMods-: FlButtons.Button;      (* its Perks and Flaws *)
  abilityLinked-: FlButtons.Button;    (* its linked content: "Spells...", "Form...", ... *)
  transformedItem-: INTEGER;           (* Character > Transformed form *)
  numbers-: ARRAY NSheetNumbers OF OvaWidgets.NumberBox;  (* the sheet's, by SheetNumber.which *)
  warnings-: FlBrowsers.Browser;
  combatNotes-: FlInputs.MultilineInput;
  attackBox-: FlLayout.Scroll;
  rows-: AttackRow;                    (* the combat box's, in order *)
  addAttack-: FlButtons.Button;
  rebuild: Fl.Timer;                   (* rebuilds the rows, after a row's Remove *)

  (* What would wait for the user; a test sets its own. tell shows a
     message; ask asks whether to save first (SaveFirst, Discard,
     Cancel); choosePath asks for a file to open, or to save to if
     save. *)
  tell*: PROCEDURE (text: Rope);
  ask*: PROCEDURE (question: Rope): INTEGER;
  choosePath*: PROCEDURE (save: BOOLEAN; VAR path: Rope): BOOLEAN;
  (* choosePdf asks for the rulebook's PDF; askText for a line of text,
     showing text as it is. *)
  choosePdf*: PROCEDURE (VAR path: Rope): BOOLEAN;
  askText*: PROCEDURE (prompt: Rope; VAR text: Rope): BOOLEAN;

  (* The rulebook: --rulebook's path, or the one chosen this run (NIL:
     none), and the one saved in the preferences (NIL: none). *)
  rulebookOption*: Rope;
  savedRulebook-: Rope;
  (* The viewer, and whether --viewer chose it, so the preferences'
     doesn't replace it. *)
  viewer*: OvaViewer.Viewer;
  viewerOption*: BOOLEAN;
  (* Where the rulebook and viewer are kept (NIL: nowhere). *)
  preferences-: FlPreferences.Preferences;
  wasModified: BOOLEAN;  (* modified, when Limits... opened *)

PROCEDURE^ ShowAll;
PROCEDURE^ ShowRows;

(* ---- Text ---- *)

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

(* What input i holds; NIL if empty. *)
PROCEDURE InputText(i: FlInputs.Input): Rope;
  VAR s: OvaText.String;
BEGIN
  NEW(s, i.Length() + 1); i.Value(s^);
  RETURN Ropes.FromString(s^)
END InputText;

PROCEDURE SetInput(i: FlInputs.Input; r: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(r); i.SetValue(s^)
END SetInput;

(* "Attack (p. 50)", or the name and "(p. ?)" for one the tables don't
   have. *)
PROCEDURE LabelOf(it: OvaRules.Item; name: Rope): Rope;
  VAR s: ARRAY 64 OF CHAR; r: Rope; p: ARRAY 16 OF CHAR;
BEGIN
  IF it # NIL THEN OvaRules.Label(it, s); r := R(s)
  ELSE r := name; OvaRules.PageText(NIL, p); OvaText.Add(r, " ("); OvaText.Add(r, p); OvaText.Add(r, ")")
  END;
  RETURN r
END LabelOf;

(* ---- What would wait for the user ---- *)

PROCEDURE DialogTell(text: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(text); FlDialogs.Message(s^)
END DialogTell;

PROCEDURE DialogAsk(question: Rope): INTEGER;
  VAR s: OvaText.String; r: INTEGER;
BEGIN
  s := OvaText.Chars(question);
  r := FlDialogs.Choice(s^, "Save", "Don't save", "Cancel");
  IF (r < 0) OR (r > 2) THEN r := Cancel END;
  RETURN r
END DialogAsk;

PROCEDURE DialogPath(save: BOOLEAN; VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; name: ARRAY 4096 OF CHAR; filter: ARRAY 32 OF CHAR; ok: BOOLEAN;
BEGIN
  NEW(c);
  IF save THEN
    FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseSaveFile);
    c.SetTitle("Save the character as"); c.SetOptions(FlDialogs.SaveAsConfirm)
  ELSE
    FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseFile);
    c.SetTitle("Open a character")
  END;
  filter := "YAML *.{yaml,yml}"; filter[4] := 9X;  (* FLTK's "name<tab>pattern" *)
  c.SetFilter(filter);
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN c.FileName(0, name); p := Ropes.FromString(name); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogPath;

PROCEDURE DialogPdf(VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; name: ARRAY 4096 OF CHAR; filter: ARRAY 16 OF CHAR; ok: BOOLEAN;
BEGIN
  NEW(c); FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseFile);
  c.SetTitle("The rulebook's PDF");
  filter := "PDF *.pdf"; filter[3] := 9X;  (* FLTK's "name<tab>pattern" *)
  c.SetFilter(filter);
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN c.FileName(0, name); p := Ropes.FromString(name); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogPdf;

PROCEDURE DialogText(prompt: Rope; VAR text: Rope): BOOLEAN;
  VAR s: OvaText.String; value: ARRAY 4096 OF CHAR; ok: BOOLEAN;
BEGIN
  s := OvaText.Chars(text); COPY(s^, value);
  s := OvaText.Chars(prompt);
  ok := FlDialogs.Input(s^, value);
  IF ok THEN text := Ropes.FromString(value) END;
  RETURN ok
END DialogText;

(* tell as it is now: the dialog's, which a test may have replaced. *)
PROCEDURE Tell(text: Rope);
BEGIN tell(text)
END Tell;

(* ---- The rulebook ---- *)

(* Keeps text under name in the preferences, written at once. *)
PROCEDURE Keep(name: ARRAY OF CHAR; text: Rope);
  VAR s: OvaText.String;
BEGIN
  IF preferences # NIL THEN
    s := OvaText.Chars(text); preferences.SetText(name, s^);
    IF ~preferences.Flush() THEN tell(R("The preferences couldn't be written.")) END
  END
END Keep;

(* What the preferences hold under name; NIL for nothing. *)
PROCEDURE Kept(name: ARRAY OF CHAR): Rope;
  VAR s: OvaText.String;
BEGIN
  NEW(s, preferences.TextLength(name) + 1); preferences.GetText(name, "", s^);
  RETURN OvaText.Trim(Ropes.FromString(s^))
END Kept;

(* Takes the rulebook's path and the viewer from p (NIL: none), where
   the ones the user chooses are kept; --viewer's wins over the one kept,
   and --rulebook's and OVA_RULEBOOK's over the path kept
   (OvaViewer.FindRulebook). A viewer kept that isn't one is ignored. *)
PROCEDURE UsePreferences*(p: FlPreferences.Preferences);
  VAR v: OvaViewer.Viewer;
BEGIN
  preferences := p; savedRulebook := NIL;
  IF p # NIL THEN
    savedRulebook := Kept("rulebook");
    IF ~viewerOption & OvaViewer.Parse(Kept("viewer"), v) THEN viewer := v END
  END
END UsePreferences;

(* Asks for the rulebook's PDF, uses it from now on, and keeps it. *)
PROCEDURE ChooseRulebook(): BOOLEAN;
  VAR p: Rope;
BEGIN
  IF ~choosePdf(p) THEN RETURN FALSE END;
  p := OvaPaths.Absolute(p, NIL);
  rulebookOption := p; savedRulebook := p; Keep("rulebook", p);
  RETURN TRUE
END ChooseRulebook;

(* Opens the rulebook at printed page page. If it isn't found, asks for
   it once; if not given, says why. *)
PROCEDURE OpenPage(page: INTEGER);
  VAR pdf, msg: Rope;
BEGIN
  IF ~OvaViewer.FindRulebook(rulebookOption, savedRulebook, pdf) THEN
    IF ~ChooseRulebook() OR ~OvaViewer.FindRulebook(rulebookOption, savedRulebook, pdf) THEN
      msg := R("The rulebook isn't at "); msg := Ropes.Cat(msg, pdf);
      OvaText.Add(msg, ": choose it with Rulebook > Choose PDF..., or give it with --rulebook or OVA_RULEBOOK.");
      tell(msg);
      RETURN
    END
  END;
  IF OvaViewer.Open(viewer, pdf, page, msg) THEN END;
  IF msg # NIL THEN tell(msg) END
END OpenPage;

PROCEDURE RulebookAction(w: Fl.Widget);
BEGIN OvaWidgets.openPage(1)
END RulebookAction;

PROCEDURE ChoosePdfAction(w: Fl.Widget);
BEGIN IF ChooseRulebook() THEN END
END ChoosePdfAction;

(* Rulebook > Viewer...: a viewer's name or a command, kept. *)
PROCEDURE ViewerAction(w: Fl.Widget);
  VAR text, msg: Rope; v: OvaViewer.Viewer;
BEGIN
  text := OvaViewer.Name(viewer);
  IF askText(R("Viewer: okular, evince, mupdf, xdg-open, or a command (%f the PDF, %p its page, %l the printed page)"),
      text) THEN
    IF OvaViewer.Parse(text, v) THEN
      viewer := v; Keep("viewer", OvaViewer.Name(v))
    ELSE
      msg := R("Not a viewer: "); msg := Ropes.Cat(msg, text);
      OvaText.Add(msg, ". Give okular, evince, mupdf, xdg-open, or a command with %f for the PDF.");
      tell(msg)
    END
  END
END ViewerAction;

(* ---- Title and changes ---- *)

PROCEDURE ShowTitle;
  VAR t: Rope; s: OvaText.String; slash: LONGINT;
BEGIN
  t := R(Title);
  IF path # NIL THEN
    OvaText.Add(t, " - ");
    slash := Ropes.RIndexChar(path, "/", Ropes.Length(path));
    t := Ropes.Cat(t, Ropes.Substring(path, slash + 1, Ropes.Length(path) - slash - 1))
  END;
  IF modified THEN OvaText.Add(t, " *") END;
  s := OvaText.Chars(t); window.SetLabel(s^)
END ShowTitle;

PROCEDURE ShowWarnings;
  VAR w: OvaCalc.Warning; r: Rope; s: OvaText.String;
    t: OvaCharacter.Trait; a: OvaCharacter.Attack; m: OvaCharacter.Mod;
BEGIN
  warnings.Clear;
  w := character.warnings;
  WHILE w # NIL DO
    r := NIL;
    IF w.attack # NIL THEN a := w.attack(OvaCharacter.Attack); r := a.name; OvaText.Add(r, ": ") END;
    IF w.trait # NIL THEN t := w.trait(OvaCharacter.Trait); r := Ropes.Cat(r, LabelOf(t.item, t.name)) END;
    IF w.mod # NIL THEN
      m := w.mod(OvaCharacter.Mod);
      IF w.trait # NIL THEN OvaText.Add(r, ": ") END;
      r := Ropes.Cat(r, LabelOf(m.item, m.name))
    END;
    CASE w.code OF
      OvaCalc.UnknownItem: OvaText.Add(r, " isn't in the rulebook's lists")
    | OvaCalc.LevelRange:
        IF t.kind = OvaRules.Ability THEN OvaText.Add(r, ": an Ability is +1 to +5 (p. 18)")
        ELSE OvaText.Add(r, ": a Weakness is -1 to -3 (p. 18)")
        END
    | OvaCalc.TooOften: OvaText.Add(r, " is taken more often than it may be (p. 83)")
    | OvaCalc.CostRange: OvaText.Add(r, "'s cost is outside its range, or not in steps of 5 (p. 87)")
    | OvaCalc.NoDamageIneffective: OvaText.Add(r, "No Damage with Ineffective (p. 88)")
    | OvaCalc.RedirectableAlone: OvaText.Add(r, "Redirectable without Ranged (p. 86)")
    | OvaCalc.SpellRange: OvaText.Add(r, ": a spell's level isn't 1 to 5 (or -1 to -3, a Weakness), or its Magic's isn't 1 to 5: no cost (p. 58)")
    | OvaCalc.TableRange: OvaText.Add(r, "Tough, Vigorous or Endurance Reserve past +5, counted as +5")
    | OvaCalc.BaseZeroBroken: OvaText.Add(r, "The Character Total is beyond Base Zero's range (p. 21)")
    | OvaCalc.StartingBroken: OvaText.Add(r, "The Abilities are beyond the starting levels and the Weaknesses (p. 21)")
    | OvaCalc.CeilingBroken: OvaText.Add(r, "The Abilities are beyond the Power Ceiling (p. 21)")
    | OvaCalc.OverFive:
        IF w.attack = NIL THEN OvaText.Add(r, "DEFENSE: ") END;
        OvaText.Add(r, "Abilities give the roll more than +5 (p. 21)")
    END;
    s := OvaText.Chars(r); warnings.Add(s^);
    w := w.next
  END
END ShowWarnings;

(* Whether a warning has code. *)
PROCEDURE Warned(code: INTEGER): BOOLEAN;
  VAR w: OvaCalc.Warning;
BEGIN
  w := character.warnings;
  WHILE (w # NIL) & (w.code # code) DO w := w.next END;
  RETURN w # NIL
END Warned;

PROCEDURE Red(b: OvaWidgets.NumberBox; on: BOOLEAN);
BEGIN
  IF on THEN b.shown.SetTextColor(Fl.Red) ELSE b.shown.SetTextColor(Fl.ForegroundColor) END;
  b.shown.Redraw
END Red;

(* Every number box shown again: Barrier's, Incorporeal Form's and the
   Reserve's only when
   the character has them, Scaled Cost's points only under it. A total
   a limit finds too high is red (p. 21): Base Zero's the Character
   Total, or the points under Scaled Cost; a Power Ceiling's or the
   starting levels' the Abilities'. *)
PROCEDURE ShowNumbers;
  VAR i: INTEGER; r: AttackRow; baseZero: BOOLEAN;
BEGIN
  FOR i := 0 TO NSheetNumbers - 1 DO numbers[i].Display END;
  baseZero := Warned(OvaCalc.BaseZeroBroken);
  Red(numbers[Total], baseZero & ~character.options.scaledCost);
  Red(numbers[Points], baseZero & character.options.scaledCost);
  Red(numbers[AbilityLevels], Warned(OvaCalc.CeilingBroken) OR Warned(OvaCalc.StartingBroken));
  IF character.hasBarrier THEN numbers[Barrier].Show ELSE numbers[Barrier].Hide END;
  IF character.hasIncorporeal THEN numbers[Incorporeal].Show ELSE numbers[Incorporeal].Hide END;
  IF character.hasReserve THEN numbers[Reserve].Show ELSE numbers[Reserve].Hide END;
  IF character.options.scaledCost THEN numbers[Points].Show ELSE numbers[Points].Hide END;
  r := rows;
  WHILE r # NIL DO r.roll.Display; r.dx.Display; r.end.Display; r := r.nextRow END;
  abilityEnd.Display;
  ShowWarnings
END ShowNumbers;

(* After any change to the character: computed again and shown. *)
PROCEDURE Changed;
BEGIN
  OvaCharacter.Recompute(character);
  modified := TRUE;
  ShowTitle;
  ShowNumbers
END Changed;

(* After a change on the Background tab: text alone, nothing to compute. *)
PROCEDURE BackgroundChanged;
BEGIN modified := TRUE; ShowTitle
END BackgroundChanged;

(* ---- Numbers ---- *)

PROCEDURE (t: SheetNumber) Get*(VAR n: OvaCalc.Number);
  VAR c: OvaCharacter.Character;
BEGIN
  c := character;
  CASE t.which OF
    Defense: n := c.defense | Barrier: n := c.barrier | Incorporeal: n := c.incorporeal
  | Health: n := c.health
  | Endurance: n := c.endurance | Reserve: n := c.reserve | TV: n := c.tv
  | AbilityLevels: n := c.abilityLevels | WeaknessLevels: n := c.weaknessLevels
  | Total: n := c.total | Points: n := c.points
  END
END Get;

PROCEDURE (t: SheetNumber) Put*(VAR n: OvaCalc.Number);
  VAR c: OvaCharacter.Character;
BEGIN
  c := character;
  CASE t.which OF
    Defense: c.defense := n | Barrier: c.barrier := n | Incorporeal: c.incorporeal := n
  | Health: c.health := n
  | Endurance: c.endurance := n | Reserve: c.reserve := n | TV: c.tv := n
  | AbilityLevels: c.abilityLevels := n | WeaknessLevels: c.weaknessLevels := n
  | Total: c.total := n | Points: c.points := n
  END
END Put;

PROCEDURE (t: AttackNumber) Get*(VAR n: OvaCalc.Number);
BEGIN
  CASE t.which OF Roll: n := t.attack.roll | DX: n := t.attack.dx | End: n := t.attack.end END
END Get;

PROCEDURE (t: AttackNumber) Put*(VAR n: OvaCalc.Number);
BEGIN
  CASE t.which OF Roll: t.attack.roll := n | DX: t.attack.dx := n | End: t.attack.end := n END
END Put;

PROCEDURE (t: TraitEnd) Get*(VAR n: OvaCalc.Number);
BEGIN n := t.trait.end
END Get;

PROCEDURE (t: TraitEnd) Put*(VAR n: OvaCalc.Number);
BEGIN t.trait.end := n
END Put;

(* A number box's text taken; refused text is said so. *)
PROCEDURE NumberChanged(b: OvaWidgets.NumberBox; ok: BOOLEAN);
  VAR label: ARRAY 64 OF CHAR; msg: Rope;
BEGIN
  IF ~ok THEN
    b.GetLabel(label);
    msg := R("Not a number");
    IF label # "" THEN OvaText.Add(msg, " for "); OvaText.Add(msg, label) END;
    OvaText.Add(msg, ": a whole number");
    IF b.allowHalf THEN OvaText.Add(msg, ", or 1/2") END;
    IF b.allowPlus THEN OvaText.Add(msg, ", which may end in +") END;
    OvaText.Add(msg, ". The computed number is used.");
    tell(msg)
  END;
  Changed
END NumberChanged;

PROCEDURE SheetBox(which, x, y: INTEGER; label: ARRAY OF CHAR);
  VAR t: SheetNumber; b: OvaWidgets.NumberBox;
BEGIN
  NEW(b); OvaWidgets.OpenNumberBox(b, x, y, label);
  NEW(t); t.which := which; b.target := t;
  b.changed := NumberChanged;
  numbers[which] := b
END SheetBox;

(* ---- Abilities and Weaknesses ---- *)

(* The selected Ability's END, Perks and Flaws, and linked content: the
   box and buttons work only for one with them. *)
PROCEDURE ShowAbility(t: OvaCharacter.Trait);
  VAR e: TraitEnd; linked: INTEGER;
BEGIN
  linked := OvaRules.NoLink;
  IF t = NIL THEN
    abilityEnd.target := NIL; abilityEnd.Deactivate; abilityMods.Deactivate
  ELSE
    NEW(e); e.trait := t; abilityEnd.target := e;
    IF t.hasEnd THEN abilityEnd.Activate ELSE abilityEnd.Deactivate END;
    abilityMods.Activate;
    IF t.item # NIL THEN linked := t.item.linked END
  END;
  CASE linked OF
    OvaRules.NoLink: abilityLinked.SetLabel("Linked...")
  | OvaRules.Spells: abilityLinked.SetLabel("Spells...")
  | OvaRules.Form: abilityLinked.SetLabel("Form...")
  | OvaRules.Partner: abilityLinked.SetLabel("Companion...")
  | OvaRules.Machine: abilityLinked.SetLabel("Vehicle...")
  END;
  IF linked = OvaRules.NoLink THEN abilityLinked.Deactivate ELSE abilityLinked.Activate END;
  abilityEnd.Display
END ShowAbility;

PROCEDURE AbilitySelected(p: OvaTraitPanel.TraitPanel; t: OvaCharacter.Trait);
BEGIN ShowAbility(t)
END AbilitySelected;

PROCEDURE PanelChanged(p: OvaTraitPanel.TraitPanel);
BEGIN Changed
END PanelChanged;

PROCEDURE OpenTraitPanel(VAR p: OvaTraitPanel.TraitPanel; x, kind: INTEGER; title: ARRAY OF CHAR);
BEGIN
  NEW(p); OvaTraitPanel.Open(p, x, Top + 65, 305, 220, kind, title);
  p.changed := PanelChanged;
  IF kind = OvaRules.Ability THEN p.selected := AbilitySelected END
END OpenTraitPanel;

PROCEDURE ModsDone(changed: BOOLEAN);
BEGIN
  IF changed THEN Changed END;
  abilities.Refresh(abilities.browser.Value())
END ModsDone;

PROCEDURE ModsAction(w: Fl.Widget);
  VAR t: OvaCharacter.Trait;
BEGIN
  t := abilities.Selected();
  IF t # NIL THEN OvaAttackDialog.EditMods(character, t, ModsDone) END
END ModsAction;

(* After the linked dialog: what it changed is in the character already. *)
PROCEDURE LinkedDone;
BEGIN abilities.Refresh(abilities.browser.Value())
END LinkedDone;

PROCEDURE LinkedChanged;
BEGIN Changed
END LinkedChanged;

PROCEDURE LinkedAction(w: Fl.Widget);
  VAR t: OvaCharacter.Trait;
BEGIN
  t := abilities.Selected();
  IF (t # NIL) & (t.item # NIL) & (t.item.linked # OvaRules.NoLink) THEN
    OvaLinkedDialog.Edit(character, t, LinkedDone)
  END
END LinkedAction;

(* ---- The combat box ---- *)

PROCEDURE AttackDone(changed: BOOLEAN);
BEGIN
  IF changed THEN Changed END;
  ShowRows
END AttackDone;

PROCEDURE RowOf(w: Fl.Widget): AttackRow;
  VAR r: AttackRow;
BEGIN
  r := rows;
  WHILE (r # NIL) & (w # r.edit) & (w # r.remove) DO r := r.nextRow END;
  RETURN r
END RowOf;

PROCEDURE EditAction(w: Fl.Widget);
  VAR r: AttackRow;
BEGIN
  r := RowOf(w);
  IF r # NIL THEN OvaAttackDialog.EditAttack(character, r.attack, FALSE, AttackDone) END
END EditAction;

(* The row is rebuilt later, by rebuild: FLTK can't delete the button
   whose callback is running. *)
PROCEDURE RemoveAction(w: Fl.Widget);
  VAR r: AttackRow;
BEGIN
  r := RowOf(w);
  IF r # NIL THEN
    OvaCharacter.RemoveAttack(character, r.attack);
    Changed;
    Fl.AddTimeout(rebuild, 0.0D0)
  END
END RemoveAction;

PROCEDURE RebuildAction(t: Fl.Timer);
BEGIN ShowRows
END RebuildAction;

PROCEDURE AddAttackAction(w: Fl.Widget);
  VAR a: OvaCharacter.Attack;
BEGIN
  a := OvaCharacter.NewAttack(R("New attack"));
  OvaCalc.AddAttack(character, a);
  OvaCharacter.Recompute(character);
  OvaAttackDialog.EditAttack(character, a, TRUE, AttackDone)
END AddAttackAction;

PROCEDURE AttackBox(VAR b: OvaWidgets.NumberBox; a: OvaCalc.Attack; which, x, y: INTEGER);
  VAR t: AttackNumber;
BEGIN
  NEW(b); OvaWidgets.OpenNumberBox(b, x, y, "");
  NEW(t); t.attack := a; t.which := which; b.target := t;
  b.changed := NumberChanged
END AttackBox;

(* The combat box's rows made again, one for each attack. *)
PROCEDURE ShowRows;
  VAR a: OvaCalc.Attack; r, last: AttackRow; x, y: INTEGER; b: FlButtons.Button; s: OvaText.String;
BEGIN
  attackBox.Clear;
  rows := NIL; last := NIL;
  attackBox.Begin;
  a := character.attacks; y := attackBox.Y() + 2;
  WHILE a # NIL DO
    NEW(r); Fl.OpenGroup(r, attackBox.X() + 2, y, ColumnW - 20, Row, "");
    r.attack := a(OvaCharacter.Attack);
    x := attackBox.X() + 2;
    NEW(r.name); FlInputs.OpenOutput(r.name, x, y, NameW, Row, "");
    s := OvaText.Chars(r.attack.name); r.name.SetValue(s^);
    x := x + NameW + 8;
    AttackBox(r.roll, a, Roll, x, y); x := x + OvaWidgets.Width + 8;
    AttackBox(r.dx, a, DX, x, y); r.dx.allowHalf := TRUE; x := x + OvaWidgets.Width + 8;
    AttackBox(r.end, a, End, x, y); x := x + OvaWidgets.Width + 8;
    NEW(b); FlButtons.OpenButton(b, x, y, 50, Row, "Edit"); b.action := EditAction; r.edit := b;
    NEW(b); FlButtons.OpenButton(b, x + 55, y, 65, Row, "Remove"); b.action := RemoveAction; r.remove := b;
    r.End;
    r.nextRow := NIL;
    IF last = NIL THEN rows := r ELSE last.nextRow := r END;
    last := r;
    y := y + RowH; a := a.next
  END;
  attackBox.End;
  ShowNumbers;
  attackBox.Redraw
END ShowRows;

(* ---- The names and the Combat Notes ---- *)

PROCEDURE TextAction(w: Fl.Widget);
  VAR c: OvaCharacter.Character;
BEGIN
  c := character;
  IF w = nameIn THEN c.name := OvaText.Trim(InputText(nameIn))
  ELSIF w = playerIn THEN OvaCharacter.SetText(c.hasPlayer, c.player, OvaText.Trim(InputText(playerIn)))
  ELSIF w = taglineIn THEN OvaCharacter.SetText(c.hasTagline, c.tagline, OvaText.Trim(InputText(taglineIn)))
  ELSIF w = combatNotes THEN OvaCharacter.SetText(c.hasCombatNotes, c.combatNotes, InputText(combatNotes))
  END;
  modified := TRUE; ShowTitle
END TextAction;

PROCEDURE TextInput(VAR i: FlInputs.Input; x, y, w: INTEGER; label: ARRAY OF CHAR);
BEGIN
  NEW(i); FlInputs.OpenInput(i, x, y, w, Row, label);
  i.SetWhen(Fl.WhenChanged); i.action := TextAction
END TextInput;

(* ---- The NPC type ---- *)

(* The NPC type chosen: the sheet's kind, so its Health, Endurance and
   TV, follow it (p. 123-124). *)
PROCEDURE NpcTypeAction(w: Fl.Widget);
  VAR i: INTEGER;
BEGIN
  i := npcTypeIn.Value();
  IF i <= 0 THEN OvaCharacter.SetNpcType(character, FALSE, 0)
  ELSE OvaCharacter.SetNpcType(character, TRUE, i - 1)
  END;
  Changed
END NpcTypeAction;

PROCEDURE ShowNpcType;
BEGIN
  IF character.hasNpcType THEN
    IF npcTypeIn.SetValue(character.npcType + 1) THEN END
  ELSIF npcTypeIn.SetValue(0) THEN
  END
END ShowNpcType;

(* ---- The transformed form ---- *)

(* Character > Limits...: OvaSettings, which tells Changed each change.
   Cancel puts the options back, and the title's mark as it was. *)
PROCEDURE LimitsDone(ok: BOOLEAN);
BEGIN
  IF ~ok THEN modified := wasModified; ShowTitle END
END LimitsDone;

PROCEDURE LimitsAction(w: Fl.Widget);
BEGIN
  IF OvaSettings.dialog = NIL THEN wasModified := modified; OvaSettings.Edit(character, LimitsDone) END
END LimitsAction;

(* Character > Transformed form: the sheet shown, and computed, in the
   Transformation's form (p. 63), as Fukiko's is; the combat key
   transformed. *)
PROCEDURE TransformedAction(w: Fl.Widget);
BEGIN
  character.transformed := bar.ItemFlags(transformedItem) * FlMenus.MenuValue # {};
  Changed
END TransformedAction;

(* The menu's toggle set from the character. *)
PROCEDURE ShowTransformed;
  VAR f: SET;
BEGIN
  f := bar.ItemFlags(transformedItem);
  IF character.transformed THEN f := f + FlMenus.MenuValue ELSE f := f - FlMenus.MenuValue END;
  bar.SetItemFlags(transformedItem, f)
END ShowTransformed;

(* ---- Everything shown ---- *)

PROCEDURE ShowAll;
BEGIN
  SetInput(nameIn, character.name); SetInput(playerIn, character.player);
  SetInput(taglineIn, character.tagline); SetInput(combatNotes, character.combatNotes);
  ShowNpcType;
  abilities.Show(character, NIL, character); weaknesses.Show(character, NIL, character);
  ShowTransformed;
  ShowRows;
  IF path # NIL THEN OvaBackground.Show(character, OvaPaths.Dir(path)) ELSE OvaBackground.Show(character, NIL) END;
  ShowTitle
END ShowAll;

(* ---- Files ---- *)

(* Shows c, from file p (NIL: none). *)
PROCEDURE Take(c: OvaCharacter.Character; p: Rope);
BEGIN
  character := c; path := p; modified := FALSE;
  OvaCharacter.Recompute(character);
  ShowAll
END Take;

(* Shows c, just loaded by OvaCharacter.Load from the file at p, and
   says what the file gives that the rules compute differently (each is
   kept as an override): OvaCharacter.notices. *)
PROCEDURE Adopt*(c: OvaCharacter.Character; p: Rope);
  VAR r: Rope;
BEGIN
  Take(c, p);
  IF OvaCharacter.notices.n > 0 THEN
    r := R("Numbers the file gives differently from the rules, kept as overrides:");
    r := Ropes.AppendChar(r, 0AX);
    r := Ropes.Cat(r, OvaText.Join(OvaCharacter.notices, 0AX));
    tell(r)
  END
END Adopt;

(* Opens the character in the file at p; FALSE, said why, if it
   can't. *)
PROCEDURE Load*(p: Rope): BOOLEAN;
  VAR c: OvaCharacter.Character; msg: Rope; s: OvaText.String;
BEGIN
  s := OvaText.Chars(p);
  IF ~OvaCharacter.Load(s^, c, msg) THEN tell(msg); RETURN FALSE END;
  Adopt(c, p);
  RETURN TRUE
END Load;

(* Saves to p; FALSE, said why, if it can't. The portrait's path,
   relative to the file, is rebased to p's directory first (OvaPaths),
   and put back if the save fails. *)
PROCEDURE SaveTo(p: Rope): BOOLEAN;
  VAR msg, old, from, to: Rope; s: OvaText.String;
BEGIN
  old := character.portrait;
  IF path # NIL THEN from := OvaPaths.Dir(path) ELSE from := NIL END;
  to := OvaPaths.Dir(p);
  character.portrait := OvaPaths.Rebase(old, from, to);
  s := OvaText.Chars(p);
  IF ~OvaSave.Save(character, s^, msg) THEN character.portrait := old; tell(msg); RETURN FALSE END;
  path := p; modified := FALSE; ShowTitle;
  OvaBackground.SetDir(to);
  RETURN TRUE
END SaveTo;

PROCEDURE SaveAs(): BOOLEAN;
  VAR p: Rope;
BEGIN RETURN choosePath(TRUE, p) & SaveTo(p)
END SaveAs;

PROCEDURE Save(): BOOLEAN;
BEGIN
  IF path = NIL THEN RETURN SaveAs() ELSE RETURN SaveTo(path) END
END Save;

(* Whether the character may be put away: saved, or the user doesn't
   want it saved. *)
PROCEDURE MayLeave(): BOOLEAN;
  VAR q: Rope; ok: BOOLEAN;
BEGIN
  ok := ~modified;
  IF ~ok THEN
    q := R("Save the changes to ");
    IF character.name # NIL THEN q := Ropes.Cat(q, character.name) ELSE OvaText.Add(q, "the character") END;
    OvaText.Add(q, " first?");
    CASE ask(q) OF
      SaveFirst: ok := Save()
    | Discard: ok := TRUE
    | Cancel: ok := FALSE
    END
  END;
  RETURN ok
END MayLeave;

PROCEDURE NewAction(w: Fl.Widget);
BEGIN IF MayLeave() THEN Take(OvaCharacter.New(), NIL) END
END NewAction;

PROCEDURE OpenAction(w: Fl.Widget);
  VAR p: Rope;
BEGIN
  IF MayLeave() & choosePath(FALSE, p) THEN IF Load(p) THEN END END
END OpenAction;

PROCEDURE SaveAction(w: Fl.Widget);
BEGIN IF Save() THEN END
END SaveAction;

PROCEDURE SaveAsAction(w: Fl.Widget);
BEGIN IF SaveAs() THEN END
END SaveAsAction;

(* File > Quit, and the window's close button: hide the window, which
   ends Fl.Run, once the changes are saved or let go. *)
PROCEDURE Quit*(w: Fl.Widget);
BEGIN IF MayLeave() THEN window.Hide END
END Quit;

(* ---- Building ---- *)

PROCEDURE Label(x, y, w: INTEGER; text: ARRAY OF CHAR);
  VAR b: Fl.Box;
BEGIN
  NEW(b); Fl.OpenBox(b, x, y, w, Row, text);
  b.SetAlign(Fl.AlignLeft + Fl.AlignInside); b.SetLabelFont(Fl.Bold)
END Label;

PROCEDURE BuildSheetTab;
  VAR y, x, i: INTEGER; b: Fl.Box; label: ARRAY 64 OF CHAR; name: OvaText.String;
BEGIN
  NEW(sheetTab); Fl.OpenGroup(sheetTab, 0, BarHeight + TabHeight, Width, Height - BarHeight - TabHeight, "Character");
  (* The left column: names, Abilities, Weaknesses, totals, warnings,
     Combat Notes. *)
  TextInput(nameIn, LeftX + 110, Top, 250, "Character Name");
  TextInput(playerIn, LeftX + 460, Top, 160, "Player Name");
  TextInput(taglineIn, LeftX + 110, Top + 30, 290, "Tagline");
  NEW(npcTypeIn); FlMenus.OpenChoice(npcTypeIn, LeftX + 470, Top + 30, 150, Row, "NPC Type");
  IF npcTypeIn.Add("none", 0, {}, NIL, {}) >= 0 THEN END;
  FOR i := OvaEntities.Heroic TO OvaEntities.Extra DO
    name := OvaText.Chars(OvaEntities.NpcTypeName(i));
    OvaRules.PageLabel(name^, OvaRules.NpcTypesPage, label);
    IF npcTypeIn.Add(label, 0, {}, NIL, {}) >= 0 THEN END
  END;
  npcTypeIn.action := NpcTypeAction;
  OpenTraitPanel(abilities, LeftX, OvaRules.Ability, "Abilities");
  OpenTraitPanel(weaknesses, LeftX + 315, OvaRules.Weakness, "Weaknesses");
  y := abilities.bottom + 5;
  NEW(abilityMods); FlButtons.OpenButton(abilityMods, LeftX, y, 140, Row, "Perks and Flaws...");
  abilityMods.action := ModsAction;
  NEW(abilityLinked); FlButtons.OpenButton(abilityLinked, LeftX + 305 + 10, y, 140, Row, "Linked...");
  abilityLinked.action := LinkedAction;
  NEW(abilityEnd); OvaWidgets.OpenNumberBox(abilityEnd, LeftX + 190, y, "END");
  abilityEnd.SetAlign(Fl.AlignLeft); abilityEnd.allowPlus := FALSE; abilityEnd.changed := NumberChanged;
  y := y + Row + 25;
  SheetBox(AbilityLevels, LeftX, y, "Abilities");
  SheetBox(WeaknessLevels, LeftX + 150, y, "Weaknesses");
  SheetBox(Total, LeftX + 300, y, "Character Total");
  SheetBox(Points, LeftX + 450, y, "Scaled Cost points");
  y := y + Row + 25;
  NEW(warnings); FlBrowsers.OpenBrowser(warnings, LeftX, y, ColumnW, 85, "Warnings");
  warnings.SetAlign(Fl.AlignTopLeft); warnings.SetFormatChar(0X);
  y := y + 85 + 20;
  NEW(combatNotes); FlInputs.OpenMultilineInput(combatNotes, LeftX, y, ColumnW, Height - y - 10, "Combat Notes");
  combatNotes.SetAlign(Fl.AlignTopLeft); combatNotes.SetWhen(Fl.WhenChanged); combatNotes.action := TextAction;
  combatNotes.SetWrap(TRUE);

  sheetTab.End;

  (* The second tab: the combat box and the sheet's numbers. *)
  NEW(attacksTab); Fl.OpenGroup(attacksTab, 0, BarHeight + TabHeight, Width, Height - BarHeight - TabHeight, "Attacks");
  Label(LeftX, Top, 200, "Attacks");
  x := LeftX + 2 + NameW + 8; y := Top + 25;
  NEW(b); Fl.OpenBox(b, LeftX + 2, y, NameW, Row, "Name"); b.SetAlign(Fl.AlignLeft + Fl.AlignInside);
  NEW(b); Fl.OpenBox(b, x, y, OvaWidgets.Width, Row, "ROLL");
  NEW(b); Fl.OpenBox(b, x + OvaWidgets.Width + 8, y, OvaWidgets.Width, Row, "DX");
  NEW(b); Fl.OpenBox(b, x + 2 * (OvaWidgets.Width + 8), y, OvaWidgets.Width, Row, "END");
  y := y + Row;
  NEW(attackBox); FlLayout.OpenScroll(attackBox, LeftX, y, ColumnW, AttackRows * RowH + 4, "");
  attackBox.SetKind(FlLayout.ScrollVertical); attackBox.SetBoxType(Fl.DownBox);
  attackBox.End;
  y := y + AttackRows * RowH + 10;
  NEW(addAttack); FlButtons.OpenButton(addAttack, LeftX, y, 120, Row, "Add attack...");
  addAttack.action := AddAttackAction;
  y := y + Row + 30;
  SheetBox(Defense, LeftX, y, "DEFENSE");
  SheetBox(Barrier, LeftX + 100, y, "Barrier DEFENSE");
  SheetBox(Incorporeal, LeftX + 100, y + 50, "Incorporeal DEFENSE");
  SheetBox(Health, LeftX + 220, y, "HEALTH");
  SheetBox(Endurance, LeftX + 320, y, "ENDURANCE");
  SheetBox(Reserve, LeftX + 420, y, "Reserve");
  SheetBox(TV, LeftX + 520, y, "TV");
  attacksTab.End
END BuildSheetTab;

(* Opens the window, not yet shown, with a new character. *)
PROCEDURE Build*;
BEGIN
  NEW(window); Fl.OpenDoubleWindow(window, Width, Height, Title);
  NEW(bar); FlMenus.OpenMenuBar(bar, 0, 0, Width, BarHeight, "");
  newItem := bar.Add("&File/&New", ORD("n"), Fl.Command, NewAction, {});
  openItem := bar.Add("&File/&Open...", ORD("o"), Fl.Command, OpenAction, {});
  saveItem := bar.Add("&File/&Save", ORD("s"), Fl.Command, SaveAction, {});
  saveAsItem := bar.Add("&File/Save &As...", ORD("s"), Fl.Command + Fl.Shift, SaveAsAction, FlMenus.MenuDivider);
  quitItem := bar.Add("&File/&Quit", ORD("q"), Fl.Command, Quit, {});
  limitsItem := bar.Add("&Character/&Limits...", ORD("e"), Fl.Command, LimitsAction, {});
  transformedItem := bar.Add("&Character/&Transformed form", ORD("t"), Fl.Command, TransformedAction,
    FlMenus.MenuToggle);
  rulebookItem := bar.Add("&Rulebook/&Open", 0, {}, RulebookAction, FlMenus.MenuDivider);
  choosePdfItem := bar.Add("&Rulebook/&Choose PDF...", 0, {}, ChoosePdfAction, {});
  viewerItem := bar.Add("&Rulebook/&Viewer...", 0, {}, ViewerAction, {});
  NEW(tabs); FlLayout.OpenTabs(tabs, 0, BarHeight, Width, Height - BarHeight, "");
  BuildSheetTab;
  NEW(backgroundTab); NEW(fluffTab);
  OvaBackground.Build(backgroundTab, fluffTab, 0, BarHeight + TabHeight, Width, Height - BarHeight - TabHeight);
  tabs.End;
  window.End;
  window.action := Quit;
  NEW(rebuild); rebuild.action := RebuildAction;
  Take(OvaCharacter.New(), NIL)
END Build;

(* Deletes the window and everything in it, for tests. *)
PROCEDURE Close*;
BEGIN
  IF OvaAttackDialog.dialog # NIL THEN OvaAttackDialog.Cancel END;
  IF OvaLinkedDialog.dialog # NIL THEN OvaLinkedDialog.Close END;
  IF OvaSettings.dialog # NIL THEN OvaSettings.Cancel END;
  IF rebuild.Pending() THEN Fl.RemoveTimeout(rebuild) END;
  OvaWidgets.ClosePanel(abilities); OvaWidgets.ClosePanel(weaknesses);
  window.Delete;
  OvaBackground.Close;
  window := NIL; bar := NIL; tabs := NIL; sheetTab := NIL; attacksTab := NIL; backgroundTab := NIL; fluffTab := NIL;
  abilities := NIL; weaknesses := NIL; rows := NIL; attackBox := NIL; warnings := NIL;
  nameIn := NIL; playerIn := NIL; taglineIn := NIL; npcTypeIn := NIL; combatNotes := NIL; abilityEnd := NIL; abilityMods := NIL;
  addAttack := NIL
END Close;

BEGIN
  tell := DialogTell; ask := DialogAsk; choosePath := DialogPath; choosePdf := DialogPdf; askText := DialogText;
  OvaWidgets.openPage := OpenPage; OvaAttackDialog.tell := Tell;
  OvaBackground.tell := Tell; OvaBackground.changed := BackgroundChanged;
  OvaTraitPanel.tell := Tell; OvaLinkedDialog.tell := Tell; OvaLinkedDialog.changed := LinkedChanged;
  OvaSettings.changed := Changed;
  rulebookOption := NIL; savedRulebook := NIL; preferences := NIL;
  OvaViewer.Default(viewer); viewerOption := FALSE;
  character := NIL; path := NIL; modified := FALSE
END OvaWindow.
