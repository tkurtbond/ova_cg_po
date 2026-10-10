MODULE OvaWidgets; (* What the window and its dialogs share: the number boxes and the ? buttons *)

(* PLAN.md, "Overriding a computed number": beside every number the
   program computes is an empty entry box. A NumberBox is both: the
   computed number, shown read-only, and the box, whose text is the
   override in effect ("" for none). Where its number lives is its
   Target, which the window extends for each kind of number (an
   attack's ROLL, the sheet's HEALTH, ...), so the box reads and sets
   the model, never a copy.

   A HelpButton, "?", opens the rulebook at a page (PLAN.md, "Page
   numbers beside names"), through openPage, which the window sets.

   A Panel is a list and its editor, the shape PLAN.md gives the
   Abilities and Weaknesses and the attack dialog's Perks and Flaws: a
   browser of lines, under it a Choice of every name of one kind
   (OvaRules.Label: "Attack (p. 50)"), a Spinner, a text field, and
   Add, Change, Remove and ? buttons. What the lines are, and what the
   buttons do to the model, are its extension's (its methods). *)

IMPORT Fl, FlBrowsers, FlButtons, FlInputs, FlMenus, FlValuators, OvaCalc, OvaRules;

CONST
  (* A NumberBox's size: the computed number, then the box. *)
  ShownWidth = 40; EntryWidth = 45; Gap = 2;
  Width* = ShownWidth + Gap + EntryWidth;
  Height* = 25;
  Tooltip = "empty: use the computed value";

TYPE
  (* Where a NumberBox's number lives. *)
  Target* = POINTER TO TargetDesc;
  TargetDesc* = RECORD END;

  NumberBox* = POINTER TO NumberBoxDesc;

  Entry = POINTER TO EntryDesc;
  EntryDesc = RECORD (FlInputs.InputDesc)
    box: NumberBox
  END;

  NumberBoxDesc* = RECORD (Fl.GroupDesc)
    shown-: FlInputs.Output;  (* the computed number *)
    entry-: FlInputs.Input;   (* the override: "" for none *)
    target*: Target;
    allowHalf*, allowPlus*: BOOLEAN;  (* a DX's 1/2, an END's 10+ *)
    (* After the user leaves the box: the override set from its text,
       or (ok FALSE) the text refused, and the box emptied. *)
    changed*: PROCEDURE (b: NumberBox; ok: BOOLEAN)
  END;

  HelpButton* = POINTER TO HelpButtonDesc;
  HelpButtonDesc* = RECORD (FlButtons.ButtonDesc)
    page*: INTEGER  (* the printed page; 0: nothing to show *)
  END;

  Panel* = POINTER TO PanelDesc;
  PanelDesc* = RECORD
    kind-: INTEGER;  (* the Choice's: OvaRules.Ability, Weakness, Perk or Flaw *)
    browser-: FlBrowsers.HoldBrowser;
    choice-: FlMenus.Choice;
    spinner-: FlValuators.Spinner;
    text-: FlInputs.Input;
    add-, change-, remove-: FlButtons.Button;
    help-: HelpButton;
    bottom-: INTEGER;  (* the y under the panel's last row *)
    next: Panel        (* the open panels *)
  END;

VAR
  panels: Panel;  (* every panel opened: the callbacks' way back to it *)

  (* What a HelpButton does with its page: the window's, which opens
     the rulebook there. *)
  openPage*: PROCEDURE (page: INTEGER);

(* ---- Targets ---- *)

(* The number, in n. *)
PROCEDURE (t: Target) Get*(VAR n: OvaCalc.Number);
BEGIN HALT(99)
END Get;

(* Sets the number to n. *)
PROCEDURE (t: Target) Put*(VAR n: OvaCalc.Number);
BEGIN HALT(99)
END Put;

(* ---- NumberBox ---- *)

(* Shows the target's number: computed, and its override. *)
PROCEDURE (b: NumberBox) Display*;
  VAR n: OvaCalc.Number; s: ARRAY 32 OF CHAR;
BEGIN
  IF b.target # NIL THEN
    b.target.Get(n);
    OvaCalc.ComputedText(n, s); b.shown.SetValue(s);
    IF n.overridden THEN OvaCalc.Text(n, s) ELSE s := "" END;
    b.entry.SetValue(s)
  ELSE
    b.shown.SetValue(""); b.entry.SetValue("")
  END
END Display;

(* The box's text read into its target's override (an empty box clears
   it); text that isn't a number for it is refused, and the override
   cleared. *)
PROCEDURE (b: NumberBox) Take*;
  VAR n: OvaCalc.Number; s: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  IF b.target = NIL THEN RETURN END;
  b.target.Get(n);
  b.entry.Value(s);
  ok := OvaCalc.Parse(s, b.allowHalf, b.allowPlus, n);
  IF ~ok THEN OvaCalc.Clear(n) END;
  b.target.Put(n);
  b.Display;
  IF b.changed # NIL THEN b.changed(b, ok) END
END Take;

PROCEDURE (e: Entry) Callback*;
BEGIN e.box.Take
END Callback;

(* Opens a NumberBox at x, y, Width by Height, labelled above. *)
PROCEDURE OpenNumberBox*(b: NumberBox; x, y: INTEGER; label-: ARRAY OF CHAR);
  VAR e: Entry; o: FlInputs.Output;
BEGIN
  Fl.OpenGroup(b, x, y, Width, Height, label);
  b.SetAlign(Fl.AlignTop);
  NEW(o); FlInputs.OpenOutput(o, x, y, ShownWidth, Height, "");
  o.SetTooltip("computed");
  NEW(e); FlInputs.OpenInput(e, x + ShownWidth + Gap, y, EntryWidth, Height, "");
  e.box := b; e.SetTooltip(Tooltip);
  e.SetWhen(Fl.WhenRelease + Fl.WhenEnterKey);
  b.End;
  b.shown := o; b.entry := e;
  b.target := NIL; b.allowHalf := FALSE; b.allowPlus := FALSE; b.changed := NIL
END OpenNumberBox;

(* ---- HelpButton ---- *)

PROCEDURE (b: HelpButton) Callback*;
BEGIN
  IF (b.page > 0) & (openPage # NIL) THEN openPage(b.page) END
END Callback;

(* Opens a "?" button, 25 by 25, showing page (0: none yet). *)
PROCEDURE OpenHelpButton*(b: HelpButton; x, y, page: INTEGER);
BEGIN
  FlButtons.OpenButton(b, x, y, 25, 25, "?");
  b.page := page;
  b.SetTooltip("open the rulebook at this page")
END OpenHelpButton;

(* ---- Panel ---- *)

(* The extension's: fills the browser from the model, lines in the
   model's order. *)
PROCEDURE (p: Panel) Fill*;
BEGIN HALT(99)
END Fill;

(* The extension's: the controls set from the browser's line (1 is the
   first), the one the user selected. *)
PROCEDURE (p: Panel) Load*(line: INTEGER);
BEGIN HALT(99)
END Load;

(* The extension's: what Add, Change and Remove do to the model, from
   the controls; Change and Remove on the selected line. Add and Change
   return the line the item will be on once Fill runs again (a change
   can move it), or 0 if they changed nothing; Remove whether it
   removed it. Each leaves the model recomputed. *)
PROCEDURE (p: Panel) Add*(): INTEGER;
BEGIN HALT(99)
END Add;

PROCEDURE (p: Panel) Change*(line: INTEGER): INTEGER;
BEGIN HALT(99)
END Change;

PROCEDURE (p: Panel) Remove*(line: INTEGER): BOOLEAN;
BEGIN HALT(99)
END Remove;

(* The name chosen; NIL for none. *)
PROCEDURE (p: Panel) Item*(): OvaRules.Item;
  VAR i: INTEGER;
BEGIN
  i := p.choice.Value();
  IF (i >= 0) & (i < OvaRules.Count(p.kind)) THEN RETURN OvaRules.Get(p.kind, i) ELSE RETURN NIL END
END Item;

(* After the Choice changes: the ? button turns to the chosen name's
   page; an extension sets the Spinner's bounds and the text field
   too. *)
PROCEDURE (p: Panel) Chosen*;
  VAR it: OvaRules.Item;
BEGIN
  it := p.Item();
  IF it # NIL THEN p.help.page := it.page ELSE p.help.page := 0 END
END Chosen;

(* What happens after a change the panel made: the window's or dialog's
   refresh. *)
PROCEDURE (p: Panel) Changed*;
BEGIN
END Changed;

(* Chooses it in the Choice (none for NIL, an item not of the panel's
   kind), and sets the ? button. *)
PROCEDURE (p: Panel) Choose*(it: OvaRules.Item);
  VAR i, n: INTEGER;
BEGIN
  n := -1;
  IF (it # NIL) & (it.kind = p.kind) THEN
    i := 0; WHILE OvaRules.Get(p.kind, i) # it DO INC(i) END;
    n := i
  END;
  IF p.choice.SetValue(n) THEN END;
  p.Chosen
END Choose;

(* The browser filled again, its line line selected (0: none) and the
   controls loaded from it. *)
PROCEDURE (p: Panel) Refresh*(line: INTEGER);
BEGIN
  p.browser.Clear;
  p.Fill;
  IF (line > 0) & (line <= p.browser.Count()) THEN
    IF p.browser.Select(line, TRUE) THEN END;
    p.Load(line)
  END
END Refresh;

PROCEDURE PanelOf(w: Fl.Widget): Panel;
  VAR p: Panel;
BEGIN
  p := panels;
  WHILE (p # NIL) & (w # p.browser) & (w # p.choice) & (w # p.add) & (w # p.change) & (w # p.remove) DO
    p := p.next
  END;
  RETURN p
END PanelOf;

PROCEDURE BrowserAction(w: Fl.Widget);
  VAR p: Panel;
BEGIN
  p := PanelOf(w);
  IF (p # NIL) & (p.browser.Value() > 0) THEN p.Load(p.browser.Value()) END
END BrowserAction;

PROCEDURE ChoiceAction(w: Fl.Widget);
  VAR p: Panel;
BEGIN p := PanelOf(w); IF p # NIL THEN p.Chosen END
END ChoiceAction;

(* Add and Change leave their item's line selected; Remove, none.
   Change and Remove need a line selected. *)
PROCEDURE ButtonAction(w: Fl.Widget);
  VAR p: Panel; line: INTEGER; done: BOOLEAN;
BEGIN
  p := PanelOf(w);
  IF p = NIL THEN RETURN END;
  line := p.browser.Value();
  IF w = p.add THEN line := p.Add(); done := line > 0
  ELSIF line = 0 THEN done := FALSE
  ELSIF w = p.change THEN line := p.Change(line); done := line > 0
  ELSE done := p.Remove(line); line := 0
  END;
  IF done THEN
    p.Refresh(line);
    p.Changed
  END
END ButtonAction;

(* Opens p at x, y, w wide, its browser h high, its Choice of kind's
   names, its Spinner labelled spinLabel, its text field textLabel. *)
PROCEDURE OpenPanel*(p: Panel; x, y, w, h, kind: INTEGER; title-, spinLabel-, textLabel-: ARRAY OF CHAR);
  CONST Row = 25; Gap = 5; LabelW = 50;
  VAR i, yy: INTEGER; label: ARRAY 64 OF CHAR; b: FlButtons.Button; widths: ARRAY 2 OF INTEGER;
BEGIN
  p.kind := kind;
  NEW(p.browser); FlBrowsers.OpenHoldBrowser(p.browser, x, y + 20, w, h - 20, title);
  p.browser.SetAlign(Fl.AlignTopLeft);
  p.browser.SetFormatChar(0X);  (* names are text, never format codes *)
  widths[0] := w - 70; widths[1] := 0;
  p.browser.SetColumnWidths(widths, 2);
  p.browser.action := BrowserAction;
  yy := y + h + Gap;
  NEW(p.choice); FlMenus.OpenChoice(p.choice, x, yy, w - 30, Row, "");
  FOR i := 0 TO OvaRules.Count(kind) - 1 DO
    OvaRules.Label(OvaRules.Get(kind, i), label);
    IF p.choice.Add(label, 0, {}, NIL, {}) >= 0 THEN END
  END;
  p.choice.action := ChoiceAction;
  NEW(p.help); OpenHelpButton(p.help, x + w - 25, yy, 0);
  yy := yy + Row + Gap;
  NEW(p.spinner); FlValuators.OpenSpinner(p.spinner, x + LabelW, yy, 60, Row, spinLabel);
  NEW(p.text); FlInputs.OpenInput(p.text, x + LabelW + 60 + LabelW, yy, w - 2 * LabelW - 60, Row, textLabel);
  yy := yy + Row + Gap;
  NEW(b); FlButtons.OpenButton(b, x, yy, 70, Row, "Add"); b.action := ButtonAction; p.add := b;
  NEW(b); FlButtons.OpenButton(b, x + 75, yy, 70, Row, "Change"); b.action := ButtonAction; p.change := b;
  NEW(b); FlButtons.OpenButton(b, x + 150, yy, 70, Row, "Remove"); b.action := ButtonAction; p.remove := b;
  p.bottom := yy + Row;
  p.next := panels; panels := p
END OpenPanel;

(* Forgets p, whose widgets were deleted (with their window). *)
PROCEDURE ClosePanel*(p: Panel);
  VAR q: Panel;
BEGIN
  IF panels = p THEN panels := p.next
  ELSE
    q := panels;
    WHILE (q # NIL) & (q.next # p) DO q := q.next END;
    IF q # NIL THEN q.next := p.next END
  END;
  p.next := NIL
END ClosePanel;

BEGIN
  openPage := NIL; panels := NIL
END OvaWidgets.
