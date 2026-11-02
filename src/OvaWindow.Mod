MODULE OvaWindow; (* The main window: its menu bar, the sheet's first two tabs, and the file's characters *)

(* PLAN.md, "The window". One window, narrow enough to sit beside the
   rulebook's viewer, a menu bar, and four tabs, each a column: the
   first two the sheet's right half, "Character" (the names, the
   Abilities and Weaknesses, the totals and warnings, the Combat Notes)
   and "Attacks" (the combat box and the sheet's numbers), with a box
   beside every computed number for its override; the other two the
   sheet's left half, "Background" and "Fluff", OvaBackground's.

   A file holds one character or several (PLAN.md, "Several characters
   in a file"): characters, in the file's order, of which one,
   character, is shown. The Choice at the right of the menu bar, and
   the Character menu, switch between them, add, copy, remove and
   reorder them. Every change marks the file modified, and Save writes
   them all.

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
  OvaBackground, OvaCalc, OvaCharacter, OvaEntities, OvaLinkedDialog, OvaMarkdownTab, OvaPaths, OvaRules, OvaSettings,
  OvaTraitPanel,
  OvaSave, OvaText, OvaViewer, OvaWidgets, Ropes;

CONST
  Width = 640; Height = 800; BarHeight = 25; TabHeight = 25;
  ChoiceW = 250;  (* the characters' Choice, at the menu bar's right *)
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
  AbilityPoints = 11;
  NSheetNumbers = 12;
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
  (* The window, which fits what FLTK doesn't stretch to its new size. *)
  MainWindow = POINTER TO RECORD (Fl.DoubleWindowDesc) END;

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
  sheetTab-, attacksTab-, backgroundTab-, fluffTab-, markdownTab-: Fl.Group;
  newItem-, openItem-, saveItem-, saveAsItem-, quitItem-: INTEGER;
  limitsItem-, rulebookItem-, choosePdfItem-, viewerItem-: INTEGER;
  addCharacterItem-, duplicateItem-, removeCharacterItem-, moveUpItem-, moveDownItem-,
  nextItem-, previousItem-: INTEGER;
  characterChoice-: FlMenus.Choice;  (* the characters, by number and name; current chosen *)

  (* The file's characters, in order, and the one shown,
     characters[current]; the file they came from or were saved to (NIL:
     none), and whether any has changed since. *)
  characters-: OvaCharacter.Characters;
  current-: INTEGER;
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
  fit: Fl.Timer;                       (* fits what doesn't stretch, after the window is resized *)

  (* What would wait for the user; a test sets its own. tell shows a
     message; ask asks whether to save first (SaveFirst, Discard,
     Cancel); choosePath asks for a file to open, or to save to if
     save. *)
  tell*: PROCEDURE (text: Rope);
  ask*: PROCEDURE (question: Rope): INTEGER;
  choosePath*: PROCEDURE (save: BOOLEAN; VAR path: Rope): BOOLEAN;
  (* confirm asks whether to do what question says, as yes, which names
     it, or Cancel. *)
  confirm*: PROCEDURE (question, yes: Rope): BOOLEAN;
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
PROCEDURE^ ShowCharacters;

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

(* Cancel is the default, pushed by Enter. *)
PROCEDURE DialogConfirm(question, yes: Rope): BOOLEAN;
  VAR q, y: OvaText.String;
BEGIN
  q := OvaText.Chars(question); y := OvaText.Chars(yes);
  RETURN FlDialogs.Choice(q^, y^, "Cancel", "") = 0
END DialogConfirm;

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

(* How many characters the file holds. *)
PROCEDURE Count(): INTEGER;
BEGIN RETURN SHORT(LEN(characters^))
END Count;

(* The file's name, path without its directory. *)
PROCEDURE FileName(): Rope;
  VAR slash: LONGINT;
BEGIN
  slash := Ropes.RIndexChar(path, "/", Ropes.Length(path));
  RETURN Ropes.Substring(path, slash + 1, Ropes.Length(path) - slash - 1)
END FileName;

PROCEDURE ShowTitle;
  VAR t: Rope; s: OvaText.String;
BEGIN
  t := R(Title);
  IF path # NIL THEN OvaText.Add(t, " - "); t := Ropes.Cat(t, FileName()) END;
  IF Count() > 1 THEN
    OvaText.Add(t, " ("); t := Ropes.Cat(t, OvaText.Int(current + 1));
    OvaText.Add(t, " of "); t := Ropes.Cat(t, OvaText.Int(Count())); OvaText.Add(t, ")")
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
    | OvaCalc.NotBoss: OvaText.Add(r, ": only a Boss has Boss Abilities (p. 123)")
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
   the character has them, Scaled Cost's points (the Abilities' and the
   net) only under it. A total a limit finds too high is red (p. 21):
   Base Zero's the Character Total, or the net points under Scaled
   Cost; a Power Ceiling's or the starting levels' the Abilities'
   levels, or their points under Scaled Cost. *)
PROCEDURE ShowNumbers;
  VAR i: INTEGER; r: AttackRow; baseZero, spent, scaled: BOOLEAN;
BEGIN
  FOR i := 0 TO NSheetNumbers - 1 DO numbers[i].Display END;
  baseZero := Warned(OvaCalc.BaseZeroBroken);
  spent := Warned(OvaCalc.CeilingBroken) OR Warned(OvaCalc.StartingBroken);
  scaled := character.options.scaledCost;
  Red(numbers[Total], baseZero & ~scaled);
  Red(numbers[Points], baseZero & scaled);
  Red(numbers[AbilityLevels], spent & ~scaled);
  Red(numbers[AbilityPoints], spent & scaled);
  IF character.hasBarrier THEN numbers[Barrier].Show ELSE numbers[Barrier].Hide END;
  IF character.hasIncorporeal THEN numbers[Incorporeal].Show ELSE numbers[Incorporeal].Hide END;
  IF character.hasReserve THEN numbers[Reserve].Show ELSE numbers[Reserve].Hide END;
  IF scaled THEN numbers[AbilityPoints].Show; numbers[Points].Show
  ELSE numbers[AbilityPoints].Hide; numbers[Points].Hide
  END;
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
  ShowNumbers;
  OvaMarkdownTab.Show(character)
END Changed;

(* After a change on the Background tab: text alone, nothing to compute. *)
PROCEDURE BackgroundChanged;
BEGIN modified := TRUE; ShowTitle; OvaMarkdownTab.Show(character)
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
  | Total: n := c.total | AbilityPoints: n := c.abilityPoints | Points: n := c.points
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
  | Total: c.total := n | AbilityPoints: c.abilityPoints := n | Points: c.points := n
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

(* The combat box's rows made again, one for each attack, stretched as
   the box is: FLTK's Scroll moves its children when it is resized, but
   doesn't stretch them. Each row is made at the window's first size,
   then resized, and FLTK stretches what is in it. *)
PROCEDURE ShowRows;
  VAR a: OvaCalc.Attack; r, last: AttackRow; i, x, y, top: INTEGER; b: FlButtons.Button; s: OvaText.String;
    sx, sy: REAL;
BEGIN
  attackBox.Clear;
  rows := NIL; last := NIL;
  sx := attackBox.W() / ColumnW; sy := attackBox.H() / (AttackRows * RowH + 4);
  attackBox.Begin;
  a := character.attacks; top := attackBox.Y() + SHORT(ENTIER(2 * sy + 0.5)); i := 0;
  WHILE a # NIL DO
    y := top + SHORT(ENTIER(i * RowH * sy + 0.5));
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
    r.Resize(attackBox.X() + SHORT(ENTIER(2 * sx + 0.5)), y, SHORT(ENTIER((ColumnW - 20) * sx + 0.5)),
      SHORT(ENTIER(Row * sy + 0.5)));
    r.nextRow := NIL;
    IF last = NIL THEN rows := r ELSE last.nextRow := r END;
    last := r;
    INC(i); a := a.next
  END;
  attackBox.End;
  ShowNumbers;
  attackBox.Redraw
END ShowRows;

(* What FLTK doesn't stretch, fitted to the window's size: the combat
   box's rows, the traits' columns, and the portrait. *)
PROCEDURE FitAction(t: Fl.Timer);
BEGIN
  ShowRows; abilities.Fit; weaknesses.Fit; OvaBackground.Fit
END FitAction;

(* FLTK stretches the window's widgets; the rest is fitted later, by fit,
   when the window has its new size. *)
PROCEDURE (w: MainWindow) Resize*(x, y, width, height: INTEGER);
  VAR sized: BOOLEAN;
BEGIN
  sized := (width # w.W()) OR (height # w.H());
  w.Resize^(x, y, width, height);
  IF sized & (fit # NIL) & ~fit.Pending() THEN Fl.AddTimeout(fit, 0.0D0) END
END Resize;

(* ---- The names and the Combat Notes ---- *)

PROCEDURE TextAction(w: Fl.Widget);
  VAR c: OvaCharacter.Character;
BEGIN
  c := character;
  IF w = nameIn THEN c.name := OvaText.Trim(InputText(nameIn)); ShowCharacters
  ELSIF w = playerIn THEN OvaCharacter.SetText(c.hasPlayer, c.player, OvaText.Trim(InputText(playerIn)))
  ELSIF w = taglineIn THEN OvaCharacter.SetText(c.hasTagline, c.tagline, OvaText.Trim(InputText(taglineIn)))
  ELSIF w = combatNotes THEN OvaCharacter.SetText(c.hasCombatNotes, c.combatNotes, InputText(combatNotes))
  END;
  modified := TRUE; ShowTitle; OvaMarkdownTab.Show(c)
END TextAction;

PROCEDURE TextInput(VAR i: FlInputs.Input; x, y, w: INTEGER; label: ARRAY OF CHAR);
BEGIN
  NEW(i); FlInputs.OpenInput(i, x, y, w, Row, label);
  i.SetWhen(Fl.WhenChanged); i.action := TextAction
END TextInput;

(* ---- The NPC type ---- *)

(* The NPC type chosen: the sheet's kind, so its Health, Endurance and
   TV, and the Abilities offered, follow it (p. 123-124). *)
PROCEDURE NpcTypeAction(w: Fl.Widget);
  VAR i: INTEGER;
BEGIN
  i := npcTypeIn.Value();
  IF i <= 0 THEN OvaCharacter.SetNpcType(character, FALSE, 0)
  ELSE OvaCharacter.SetNpcType(character, TRUE, i - 1)
  END;
  Changed;
  abilities.Refresh(abilities.browser.Value())  (* a Boss's offers the Boss Abilities *)
END NpcTypeAction;

PROCEDURE ShowNpcType;
BEGIN
  IF character.hasNpcType THEN
    IF npcTypeIn.SetValue(character.npcType + 1) THEN END
  ELSIF npcTypeIn.SetValue(0) THEN
  END
END ShowNpcType;

(* ---- The transformed form ---- *)

(* Character > Limits...: OvaSettings, which tells LimitsChanged each
   change. Cancel puts the options back, and the title's mark as it was. *)
PROCEDURE LimitsChanged;
BEGIN
  Changed;
  (* The lists show Scaled Cost's points only under it. *)
  abilities.Refresh(abilities.browser.Value()); weaknesses.Refresh(weaknesses.browser.Value())
END LimitsChanged;

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

(* ---- The file's characters ---- *)

(* Character i's label in the Choice: its number and name, any "&"
   doubled so that FLTK shows it. *)
PROCEDURE CharacterLabel(i: INTEGER): Rope;
  VAR r, name: Rope; k: LONGINT; ch: CHAR;
BEGIN
  r := OvaText.Int(i + 1); OvaText.Add(r, ". ");
  name := characters[i].name;
  IF name = NIL THEN OvaText.Add(r, "(no name)")
  ELSE
    FOR k := 0 TO Ropes.Length(name) - 1 DO
      ch := Ropes.Fetch(name, k);
      IF ch = "&" THEN r := Ropes.AppendChar(r, "&") END;
      r := Ropes.AppendChar(r, ch)
    END
  END;
  RETURN r
END CharacterLabel;

(* Item i of the menu bar active if on. *)
PROCEDURE Activate(i: INTEGER; on: BOOLEAN);
  VAR f: SET;
BEGIN
  f := bar.ItemFlags(i);
  IF on THEN f := f - FlMenus.MenuInactive ELSE f := f + FlMenus.MenuInactive END;
  bar.SetItemFlags(i, f)
END Activate;

(* The Choice lists the characters again, current chosen, and the
   Character menu's items are active where they can do something. *)
PROCEDURE ShowCharacters;
  VAR i, n: INTEGER; s: OvaText.String;
BEGIN
  n := Count();
  characterChoice.Clear;
  FOR i := 0 TO n - 1 DO
    IF characterChoice.Add("-", 0, {}, NIL, {}) >= 0 THEN END;
    s := OvaText.Chars(CharacterLabel(i)); characterChoice.SetItemLabel(i, s^)
  END;
  IF characterChoice.SetValue(current) THEN END;
  Activate(removeCharacterItem, n > 1);
  Activate(moveUpItem, current > 0); Activate(previousItem, current > 0);
  Activate(moveDownItem, current < n - 1); Activate(nextItem, current < n - 1)
END ShowCharacters;

(* Shows character i. *)
PROCEDURE ShowCharacter(i: INTEGER);
BEGIN
  current := i; character := characters[i];
  OvaCharacter.Recompute(character);
  ShowAll
END ShowCharacter;

PROCEDURE CharacterChoiceAction(w: Fl.Widget);
  VAR i: INTEGER;
BEGIN
  i := characterChoice.Value();
  IF (i >= 0) & (i # current) THEN ShowCharacter(i) END
END CharacterChoiceAction;

(* Adds c after the last character, and shows it. *)
PROCEDURE Append(c: OvaCharacter.Character);
  VAR cs: OvaCharacter.Characters; i: INTEGER;
BEGIN
  NEW(cs, LEN(characters^) + 1);
  FOR i := 0 TO Count() - 1 DO cs[i] := characters[i] END;
  cs[Count()] := c;
  characters := cs;
  modified := TRUE;
  ShowCharacter(Count() - 1)
END Append;

(* Character > Add Character: a new character, last. *)
PROCEDURE AddCharacterAction(w: Fl.Widget);
BEGIN Append(OvaCharacter.New())
END AddCharacterAction;

(* Character > Duplicate Character: a copy of the one shown, last. *)
PROCEDURE DuplicateAction(w: Fl.Widget);
  VAR c: OvaCharacter.Character;
BEGIN
  c := OvaSave.Copy(character);
  IF c = NIL THEN tell(R("The character couldn't be copied."))
  ELSE Append(c)
  END
END DuplicateAction;

(* Character > Remove Character...: the one shown, once the user says
   so; not the only one, since a file holds at least one. The one after
   it is shown, or the one before if it was last. *)
PROCEDURE RemoveCharacterAction(w: Fl.Widget);
  VAR cs: OvaCharacter.Characters; i, j: INTEGER; q: Rope;
BEGIN
  IF Count() > 1 THEN
    q := R("Remove ");
    IF character.name # NIL THEN q := Ropes.Cat(q, character.name) ELSE OvaText.Add(q, "this character") END;
    OvaText.Add(q, " from the file?");
    IF confirm(q, R("Remove")) THEN
      NEW(cs, LEN(characters^) - 1); j := 0;
      FOR i := 0 TO Count() - 1 DO
        IF i # current THEN cs[j] := characters[i]; INC(j) END
      END;
      characters := cs;
      modified := TRUE;
      IF current = Count() THEN ShowCharacter(current - 1) ELSE ShowCharacter(current) END
    END
  END
END RemoveCharacterAction;

(* The character shown swapped with the one d after it, and still
   shown. *)
PROCEDURE Move(d: INTEGER);
  VAR c: OvaCharacter.Character;
BEGIN
  IF (current + d >= 0) & (current + d < Count()) THEN
    c := characters[current + d]; characters[current + d] := character; characters[current] := c;
    current := current + d;
    modified := TRUE;
    ShowCharacters; ShowTitle
  END
END Move;

PROCEDURE MoveUpAction(w: Fl.Widget);
BEGIN Move(-1)
END MoveUpAction;

PROCEDURE MoveDownAction(w: Fl.Widget);
BEGIN Move(1)
END MoveDownAction;

PROCEDURE NextAction(w: Fl.Widget);
BEGIN IF current < Count() - 1 THEN ShowCharacter(current + 1) END
END NextAction;

PROCEDURE PreviousAction(w: Fl.Widget);
BEGIN IF current > 0 THEN ShowCharacter(current - 1) END
END PreviousAction;

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
  ShowCharacters;
  ShowTitle;
  OvaMarkdownTab.Show(character)
END ShowAll;

(* ---- Files ---- *)

(* Shows the characters cs, from file p (NIL: none), the first of
   them. *)
PROCEDURE Take(cs: OvaCharacter.Characters; p: Rope);
BEGIN
  characters := cs; current := 0; character := cs[0]; path := p; modified := FALSE;
  OvaCharacter.Recompute(character);
  ShowAll
END Take;

(* Shows the characters cs, just loaded by OvaCharacter.LoadAll from
   the file at p, and says what the file gives that the rules compute
   differently (each is kept as an override): OvaCharacter.notices,
   each naming its character. *)
PROCEDURE Adopt*(cs: OvaCharacter.Characters; p: Rope);
  VAR r: Rope;
BEGIN
  Take(cs, p);
  IF OvaCharacter.notices.n > 0 THEN
    r := R("Numbers the file gives differently from the rules, kept as overrides:");
    r := Ropes.AppendChar(r, 0AX);
    r := Ropes.Cat(r, OvaText.Join(OvaCharacter.notices, 0AX));
    tell(r)
  END
END Adopt;

(* Opens the characters in the file at p; FALSE, said why, if it
   can't. *)
PROCEDURE Load*(p: Rope): BOOLEAN;
  VAR cs: OvaCharacter.Characters; msg: Rope; s: OvaText.String;
BEGIN
  s := OvaText.Chars(p);
  IF ~OvaCharacter.LoadAll(s^, cs, msg) THEN tell(msg); RETURN FALSE END;
  Adopt(cs, p);
  RETURN TRUE
END Load;

(* Saves every character to p; FALSE, said why, if it can't. Each
   portrait's path, relative to the file, is rebased to p's directory
   first (OvaPaths), and put back if the save fails. *)
PROCEDURE SaveTo(p: Rope): BOOLEAN;
  VAR msg, from, to: Rope; s: OvaText.String; old: POINTER TO ARRAY OF Rope; i: INTEGER;
BEGIN
  NEW(old, LEN(characters^));
  IF path # NIL THEN from := OvaPaths.Dir(path) ELSE from := NIL END;
  to := OvaPaths.Dir(p);
  FOR i := 0 TO Count() - 1 DO
    old[i] := characters[i].portrait;
    characters[i].portrait := OvaPaths.Rebase(old[i], from, to)
  END;
  s := OvaText.Chars(p);
  IF ~OvaSave.SaveAll(characters, s^, msg) THEN
    FOR i := 0 TO Count() - 1 DO characters[i].portrait := old[i] END;
    tell(msg); RETURN FALSE
  END;
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

(* Whether the characters may be put away: saved, or the user doesn't
   want them saved. The question names the file, or the character if
   it is the only one and has no file. *)
PROCEDURE MayLeave(): BOOLEAN;
  VAR q: Rope; ok: BOOLEAN;
BEGIN
  ok := ~modified;
  IF ~ok THEN
    q := R("Save the changes to ");
    IF path # NIL THEN q := Ropes.Cat(q, FileName())
    ELSIF Count() > 1 THEN OvaText.Add(q, "the characters")
    ELSIF character.name # NIL THEN q := Ropes.Cat(q, character.name)
    ELSE OvaText.Add(q, "the character")
    END;
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
BEGIN IF MayLeave() THEN Take(OvaCharacter.One(OvaCharacter.New()), NIL) END
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
  FOR i := OvaEntities.Heroic TO OvaEntities.Boss DO
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
  SheetBox(WeaknessLevels, LeftX + 120, y, "Weaknesses");
  SheetBox(Total, LeftX + 240, y, "Character Total");
  SheetBox(AbilityPoints, LeftX + 375, y, "Ability points");
  SheetBox(Points, LeftX + 500, y, "Scaled Cost points");
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
  VAR main: MainWindow;
BEGIN
  NEW(main); window := main; Fl.OpenDoubleWindow(window, Width, Height, Title);
  NEW(bar); FlMenus.OpenMenuBar(bar, 0, 0, Width - ChoiceW, BarHeight, "");
  newItem := bar.Add("&File/&New", ORD("n"), Fl.Command, NewAction, {});
  openItem := bar.Add("&File/&Open...", ORD("o"), Fl.Command, OpenAction, {});
  saveItem := bar.Add("&File/&Save", ORD("s"), Fl.Command, SaveAction, {});
  saveAsItem := bar.Add("&File/Save &As...", ORD("s"), Fl.Command + Fl.Shift, SaveAsAction, FlMenus.MenuDivider);
  quitItem := bar.Add("&File/&Quit", ORD("q"), Fl.Command, Quit, {});
  limitsItem := bar.Add("&Character/&Limits...", ORD("e"), Fl.Command, LimitsAction, {});
  transformedItem := bar.Add("&Character/&Transformed form", ORD("t"), Fl.Command, TransformedAction,
    FlMenus.MenuToggle + FlMenus.MenuDivider);
  addCharacterItem := bar.Add("&Character/&Add Character", 0, {}, AddCharacterAction, {});
  duplicateItem := bar.Add("&Character/&Duplicate Character", 0, {}, DuplicateAction, {});
  removeCharacterItem := bar.Add("&Character/&Remove Character...", 0, {}, RemoveCharacterAction,
    FlMenus.MenuDivider);
  moveUpItem := bar.Add("&Character/Move &Up", 0, {}, MoveUpAction, {});
  moveDownItem := bar.Add("&Character/Move Do&wn", 0, {}, MoveDownAction, FlMenus.MenuDivider);
  nextItem := bar.Add("&Character/&Next Character", Fl.KeyPageDown, Fl.Command, NextAction, {});
  previousItem := bar.Add("&Character/&Previous Character", Fl.KeyPageUp, Fl.Command, PreviousAction, {});
  rulebookItem := bar.Add("&Rulebook/&Open", 0, {}, RulebookAction, FlMenus.MenuDivider);
  choosePdfItem := bar.Add("&Rulebook/&Choose PDF...", 0, {}, ChoosePdfAction, {});
  viewerItem := bar.Add("&Rulebook/&Viewer...", 0, {}, ViewerAction, {});
  NEW(characterChoice); FlMenus.OpenChoice(characterChoice, Width - ChoiceW, 0, ChoiceW, BarHeight, "");
  characterChoice.action := CharacterChoiceAction;
  characterChoice.SetTooltip("The character shown, of the file's");
  NEW(tabs); FlLayout.OpenTabs(tabs, 0, BarHeight, Width, Height - BarHeight, "");
  BuildSheetTab;
  NEW(backgroundTab); NEW(fluffTab);
  OvaBackground.Build(backgroundTab, fluffTab, 0, BarHeight + TabHeight, Width, Height - BarHeight - TabHeight);
  NEW(markdownTab); OvaMarkdownTab.Build(markdownTab, 0, BarHeight + TabHeight, Width, Height - BarHeight - TabHeight);
  (* The tabs stretch with the window, the menu bar only across it; in
     the tabs, the pages do, not the tabs' own bar. Each page stretches
     everything in it. *)
  tabs.SetResizable(sheetTab);
  tabs.End;
  window.SetResizable(tabs);
  window.SizeRange(Width, Height, 0, 0);
  window.End;
  window.action := Quit;
  NEW(rebuild); rebuild.action := RebuildAction;
  NEW(fit); fit.action := FitAction;
  Take(OvaCharacter.One(OvaCharacter.New()), NIL)
END Build;

(* Deletes the window and everything in it, for tests. *)
PROCEDURE Close*;
BEGIN
  IF OvaAttackDialog.dialog # NIL THEN OvaAttackDialog.Cancel END;
  IF OvaLinkedDialog.dialog # NIL THEN OvaLinkedDialog.Close END;
  IF OvaSettings.dialog # NIL THEN OvaSettings.Cancel END;
  IF rebuild.Pending() THEN Fl.RemoveTimeout(rebuild) END;
  IF fit.Pending() THEN Fl.RemoveTimeout(fit) END;
  OvaWidgets.ClosePanel(abilities); OvaWidgets.ClosePanel(weaknesses);
  window.Delete;
  OvaBackground.Close; OvaMarkdownTab.Close;
  window := NIL; bar := NIL; characterChoice := NIL; tabs := NIL; sheetTab := NIL; attacksTab := NIL; backgroundTab := NIL; fluffTab := NIL;
  markdownTab := NIL;
  abilities := NIL; weaknesses := NIL; rows := NIL; attackBox := NIL; warnings := NIL;
  nameIn := NIL; playerIn := NIL; taglineIn := NIL; npcTypeIn := NIL; combatNotes := NIL; abilityEnd := NIL; abilityMods := NIL;
  addAttack := NIL
END Close;

BEGIN
  tell := DialogTell; ask := DialogAsk; confirm := DialogConfirm; choosePath := DialogPath; choosePdf := DialogPdf; askText := DialogText;
  OvaWidgets.openPage := OpenPage; OvaAttackDialog.tell := Tell;
  OvaBackground.tell := Tell; OvaBackground.changed := BackgroundChanged; OvaMarkdownTab.tell := Tell;
  OvaTraitPanel.tell := Tell; OvaLinkedDialog.tell := Tell; OvaLinkedDialog.changed := LinkedChanged;
  OvaSettings.changed := LimitsChanged;
  rulebookOption := NIL; savedRulebook := NIL; preferences := NIL;
  OvaViewer.Default(viewer); viewerOption := FALSE;
  characters := NIL; current := 0; character := NIL; path := NIL; modified := FALSE
END OvaWindow.
