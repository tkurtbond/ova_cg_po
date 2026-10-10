MODULE OvaAttackDialog; (* The attack dialog, and the Perks and Flaws editor of an Ability *)

(* PLAN.md, "The window": an attack's name, description and affinity,
   whether it is made with Telekinesis or in the transformed form, its
   Perks and its Flaws, each a list with a name, a count (where it can
   be taken more than once) and a cost (where the user chooses one:
   Cancel, Requirement, Unique), and its ROLL, DX and END, computed as
   the Perks and Flaws change, each with its override box. An Ability
   with Perks and Flaws is edited by the same dialog, without the
   attack's fields: its END alone.

   The dialog changes the model as the user works, so the numbers it
   shows are OvaCalc's; Cancel puts back what was there when it opened
   (a new attack, the window added, it takes out again). It doesn't
   wait: Open shows it, and OK or Cancel calls done. *)

IMPORT Fl, FlButtons, FlInputs, OvaCalc, OvaCharacter, OvaRules, OvaText, OvaWidgets, Ropes;

CONST
  Width = 700; Height = 550; Row = 25;
  MaxTimes = 10;  (* the count's bound for an item taken as often as wanted *)
  (* Number.which *)
  Roll = 0; DX = 1; End = 2;

TYPE
  Rope = Ropes.Rope;
  ModArray = POINTER TO ARRAY OF OvaCharacter.Mod;

  (* The Perks' or the Flaws' list and editor. *)
  ModPanel = POINTER TO RECORD (OvaWidgets.PanelDesc)
    isFlaw: BOOLEAN;
    shown: ModArray;  (* shown[i]: line i + 1's *)
    n: INTEGER
  END;

  (* The attack's ROLL, DX or END, or the Ability's END. *)
  Number = POINTER TO RECORD (OvaWidgets.TargetDesc) which: INTEGER END;

VAR
  dialog-: Fl.DoubleWindow;  (* NIL when closed *)
  nameIn-, affinityIn-: FlInputs.Input;
  descriptionIn-: FlInputs.MultilineInput;
  telekinetic-, transformed-: FlButtons.CheckButton;
  perks-, flaws-: ModPanel;
  roll-, dx-, end-: OvaWidgets.NumberBox;
  ok-, cancel-: FlButtons.Button;

  character: OvaCharacter.Character;
  attack: OvaCharacter.Attack;  (* what is edited: an attack, *)
  trait: OvaCharacter.Trait;    (* or an Ability's Perks and Flaws *)
  isNew: BOOLEAN;
  savedAttack: OvaCharacter.AttackDesc;
  savedEnd: OvaCalc.Number;
  savedMods: OvaCalc.Mod;
  done: PROCEDURE (changed: BOOLEAN);

  (* Shows a message: the window's. *)
  tell*: PROCEDURE (text: Rope);

(* The list edited. *)
PROCEDURE Mods(): OvaCalc.Mod;
BEGIN IF attack # NIL THEN RETURN attack.mods ELSE RETURN trait.mods END
END Mods;

PROCEDURE SetMods(list: OvaCalc.Mod);
BEGIN IF attack # NIL THEN attack.mods := list ELSE trait.mods := list END
END SetMods;

PROCEDURE ShowNumbers;
BEGIN
  IF attack # NIL THEN roll.Display; dx.Display END;
  end.Display
END ShowNumbers;

PROCEDURE Recompute;
BEGIN OvaCharacter.Recompute(character); ShowNumbers
END Recompute;

(* ---- Numbers ---- *)

PROCEDURE (t: Number) Get*(VAR n: OvaCalc.Number);
BEGIN
  IF attack = NIL THEN n := trait.end
  ELSE CASE t.which OF Roll: n := attack.roll | DX: n := attack.dx | End: n := attack.end END
  END
END Get;

PROCEDURE (t: Number) Put*(VAR n: OvaCalc.Number);
BEGIN
  IF attack = NIL THEN trait.end := n
  ELSE CASE t.which OF Roll: attack.roll := n | DX: attack.dx := n | End: attack.end := n END
  END
END Put;

PROCEDURE NumberChanged(b: OvaWidgets.NumberBox; ok: BOOLEAN);
  VAR label: ARRAY 16 OF CHAR; msg: Rope;
BEGIN
  IF ~ok THEN
    b.GetLabel(label);
    msg := Ropes.FromString("Not a number for "); OvaText.Add(msg, label);
    OvaText.Add(msg, ". The computed number is used.");
    tell(msg)
  END;
  Recompute
END NumberChanged;

PROCEDURE NumberBox(VAR b: OvaWidgets.NumberBox; which, x, y: INTEGER; label: ARRAY OF CHAR);
  VAR t: Number;
BEGIN
  NEW(b); OvaWidgets.OpenNumberBox(b, x, y, label);
  NEW(t); t.which := which; b.target := t;
  b.changed := NumberChanged
END NumberBox;

(* ---- The Perks and Flaws ---- *)

(* The cost m adds: its own, or its item's, each time. *)
PROCEDURE Cost(m: OvaCharacter.Mod): INTEGER;
BEGIN
  IF (m.item = NIL) OR (m.item.costKind # OvaRules.FixedCost) THEN RETURN m.times * m.cost
  ELSE RETURN m.times * m.item.cost
  END
END Cost;

PROCEDURE (p: ModPanel) Fill*;
  VAR m: OvaCalc.Mod; line: Rope; s: OvaText.String; page: ARRAY 16 OF CHAR; c: INTEGER;
BEGIN
  p.n := 0; m := Mods();
  WHILE m # NIL DO
    IF m(OvaCharacter.Mod).isFlaw = p.isFlaw THEN INC(p.n) END;
    m := m.next
  END;
  NEW(p.shown, p.n + 1);
  p.n := 0; m := Mods();
  WHILE m # NIL DO
    IF m(OvaCharacter.Mod).isFlaw = p.isFlaw THEN
      p.shown[p.n] := m(OvaCharacter.Mod); INC(p.n);
      line := m(OvaCharacter.Mod).name;
      IF m(OvaCharacter.Mod).hasDetail THEN
        OvaText.Add(line, " ("); line := Ropes.Cat(line, m(OvaCharacter.Mod).detail); OvaText.Add(line, ")")
      END;
      IF m.times # 1 THEN OvaText.Add(line, " x"); OvaText.AddInt(line, m.times) END;
      line := Ropes.AppendChar(line, 9X);
      c := Cost(m(OvaCharacter.Mod));
      IF c > 0 THEN line := Ropes.AppendChar(line, "+") END;
      OvaText.AddInt(line, c);
      line := Ropes.AppendChar(line, 9X);
      OvaRules.PageText(m.item, page); OvaText.Add(line, page);
      s := OvaText.Chars(line); p.browser.Add(s^)
    END;
    m := m.next
  END
END Fill;

(* The line m is on. *)
PROCEDURE (p: ModPanel) LineOf(m: OvaCharacter.Mod): INTEGER;
  VAR i: INTEGER; l: OvaCalc.Mod;
BEGIN
  i := 0; l := Mods();
  WHILE (l # NIL) & (l # m) DO
    IF l(OvaCharacter.Mod).isFlaw = p.isFlaw THEN INC(i) END;
    l := l.next
  END;
  RETURN i + 1
END LineOf;

(* The count's bounds and the cost's field, for the item chosen. *)
PROCEDURE (p: ModPanel) Chosen*;
  VAR it: OvaRules.Item; max: INTEGER; s: ARRAY 16 OF CHAR;
BEGIN
  p.Chosen^;
  it := p.Item();
  IF it = NIL THEN RETURN END;
  max := it.maxTimes; IF max > MaxTimes THEN max := MaxTimes END;
  p.spinner.SetBounds(1, max);
  IF p.spinner.Value() > max THEN p.spinner.SetValue(max) END;
  IF max > 1 THEN p.spinner.Activate ELSE p.spinner.SetValue(1); p.spinner.Deactivate END;
  IF it.costKind = OvaRules.FixedCost THEN
    p.text.SetValue(""); p.text.Deactivate
  ELSE
    p.text.Activate;
    IF it.costKind = OvaRules.RangeCost THEN
      s := ""; p.text.Value(s);
      IF s = "" THEN p.text.SetIntValue(it.minCost) END
    END
  END
END Chosen;

PROCEDURE (p: ModPanel) Load*(line: INTEGER);
  VAR m: OvaCharacter.Mod;
BEGIN
  m := p.shown[line - 1];
  p.Choose(m.item);
  p.spinner.SetValue(m.times);
  IF (m.item = NIL) OR (m.item.costKind # OvaRules.FixedCost) THEN p.text.SetIntValue(m.cost)
  ELSE p.text.SetValue("")
  END
END Load;

(* The controls' count and cost; FALSE, said why, if the cost isn't an
   integer where one is needed. *)
PROCEDURE (p: ModPanel) Read(it: OvaRules.Item; VAR times, cost: INTEGER): BOOLEAN;
  VAR s: ARRAY 32 OF CHAR; n: OvaCalc.Number; ok: BOOLEAN;
BEGIN
  times := SHORT(ENTIER(p.spinner.Value())); cost := 0; ok := TRUE;
  IF it.costKind # OvaRules.FixedCost THEN
    p.text.Value(s);
    OvaCalc.Clear(n);
    ok := OvaCalc.Parse(s, FALSE, FALSE, n) & n.overridden;
    IF ok THEN cost := OvaCalc.Value(n)
    ELSE tell(Ropes.FromString("The cost must be a whole number, such as -10."))
    END
  END;
  RETURN ok
END Read;

PROCEDURE (p: ModPanel) Add*(): INTEGER;
  VAR it: OvaRules.Item; times, cost: INTEGER; m: OvaCharacter.Mod; list: OvaCalc.Mod;
BEGIN
  it := p.Item();
  IF it = NIL THEN tell(Ropes.FromString("Choose a name first.")); RETURN 0 END;
  IF ~p.Read(it, times, cost) THEN RETURN 0 END;
  m := OvaCharacter.NewMod(it, p.isFlaw, times, cost);
  list := Mods(); OvaCharacter.InsertMod(list, m); SetMods(list);
  Recompute;
  RETURN p.LineOf(m)
END Add;

PROCEDURE (p: ModPanel) Change*(line: INTEGER): INTEGER;
  VAR it: OvaRules.Item; times, cost: INTEGER; m: OvaCharacter.Mod; list: OvaCalc.Mod;
BEGIN
  m := p.shown[line - 1];
  it := p.Item();
  IF it = NIL THEN it := m.item END;
  IF it = NIL THEN RETURN 0 END;  (* a name the tables don't have: only Remove *)
  IF ~p.Read(it, times, cost) THEN RETURN 0 END;
  list := Mods(); OvaCharacter.RemoveMod(list, m);
  IF it # m.item THEN m.item := it; m.name := Ropes.FromString(it.name); m.hasDetail := FALSE; m.detail := NIL END;
  m.times := times; m.cost := cost; m.hasCost := it.costKind # OvaRules.FixedCost;
  OvaCharacter.InsertMod(list, m); SetMods(list);
  Recompute;
  RETURN p.LineOf(m)
END Change;

PROCEDURE (p: ModPanel) Remove*(line: INTEGER): BOOLEAN;
  VAR list: OvaCalc.Mod;
BEGIN
  list := Mods(); OvaCharacter.RemoveMod(list, p.shown[line - 1]); SetMods(list);
  Recompute;
  RETURN TRUE
END Remove;

PROCEDURE Panel(VAR p: ModPanel; x, y: INTEGER; isFlaw: BOOLEAN);
  VAR widths: ARRAY 3 OF INTEGER; kind: INTEGER;
BEGIN
  NEW(p); p.isFlaw := isFlaw; p.n := 0; NEW(p.shown, 1);
  IF isFlaw THEN kind := OvaRules.Flaw ELSE kind := OvaRules.Perk END;
  IF isFlaw THEN OvaWidgets.OpenPanel(p, x, y, 335, 200, kind, "Flaws", "times", "cost")
  ELSE OvaWidgets.OpenPanel(p, x, y, 335, 200, kind, "Perks", "times", "cost")
  END;
  widths[0] := 335 - 110; widths[1] := 50; widths[2] := 0;
  p.browser.SetColumnWidths(widths, 3);
  p.spinner.SetBounds(1, 1); p.spinner.SetValue(1);
  p.Refresh(0)
END Panel;

(* ---- Opening and closing ---- *)

PROCEDURE Finish(changed: BOOLEAN);
  VAR d: PROCEDURE (changed: BOOLEAN);
BEGIN
  OvaWidgets.ClosePanel(perks); OvaWidgets.ClosePanel(flaws);
  dialog.Hide; dialog.Delete;
  dialog := NIL; perks := NIL; flaws := NIL;
  d := done; done := NIL;
  character := NIL; attack := NIL; trait := NIL; savedMods := NIL;
  IF d # NIL THEN d(changed) END
END Finish;

PROCEDURE OkAction(w: Fl.Widget);
  VAR name: Rope; s: OvaText.String;
BEGIN
  IF attack # NIL THEN
    NEW(s, nameIn.Length() + 1); nameIn.Value(s^); name := OvaText.Trim(Ropes.FromString(s^));
    IF name = NIL THEN tell(Ropes.FromString("The attack needs a name.")); RETURN END;
    attack.name := name;
    NEW(s, affinityIn.Length() + 1); affinityIn.Value(s^);
    OvaCharacter.SetText(attack.hasAffinity, attack.affinity, OvaText.Trim(Ropes.FromString(s^)));
    NEW(s, descriptionIn.Length() + 1); descriptionIn.Value(s^);
    OvaCharacter.SetText(attack.hasDescription, attack.description, Ropes.FromString(s^));
    attack.telekinetic := telekinetic.Value(); attack.transformed := transformed.Value()
  END;
  OvaCharacter.Recompute(character);
  Finish(TRUE)
END OkAction;

(* Everything put back as it was. *)
PROCEDURE CancelAction(w: Fl.Widget);
  VAR next: OvaCalc.Attack;
BEGIN
  IF attack # NIL THEN
    IF isNew THEN OvaCharacter.RemoveAttack(character, attack)
    ELSE next := attack.next; attack^ := savedAttack; attack.next := next; attack.mods := savedMods
    END
  ELSE trait.mods := savedMods; trait.end := savedEnd
  END;
  OvaCharacter.Recompute(character);
  Finish(FALSE)
END CancelAction;

PROCEDURE SetText(i: FlInputs.Input; r: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(r); i.SetValue(s^)
END SetText;

PROCEDURE FlagAction(w: Fl.Widget);
BEGIN
  attack.telekinetic := telekinetic.Value(); attack.transformed := transformed.Value();
  Recompute
END FlagAction;

PROCEDURE Build(title: ARRAY OF CHAR);
  VAR b: FlButtons.Button; y: INTEGER;
BEGIN
  NEW(dialog); Fl.OpenDoubleWindow(dialog, Width, Height, title);
  NEW(nameIn); FlInputs.OpenInput(nameIn, 100, 10, 300, Row, "Name");
  NEW(affinityIn); FlInputs.OpenInput(affinityIn, 100, 40, 300, Row, "Affinity");
  NEW(telekinetic); FlButtons.OpenCheckButton(telekinetic, 420, 10, 260, Row, "made with Telekinesis");
  telekinetic.action := FlagAction;
  NEW(transformed); FlButtons.OpenCheckButton(transformed, 420, 40, 260, Row, "made in the transformed form");
  transformed.action := FlagAction;
  NEW(descriptionIn); FlInputs.OpenMultilineInput(descriptionIn, 100, 70, 590, 60, "Description");
  Panel(perks, 10, 140, FALSE);
  Panel(flaws, 355, 140, TRUE);
  y := perks.bottom + 30;
  NumberBox(roll, Roll, 10, y, "ROLL");
  NumberBox(dx, DX, 110, y, "DX"); dx.allowHalf := TRUE;
  NumberBox(end, End, 210, y, "END");
  NEW(b); FlButtons.OpenButton(b, Width - 190, Height - 35, 85, Row, "OK"); b.action := OkAction; ok := b;
  NEW(b); FlButtons.OpenButton(b, Width - 95, Height - 35, 85, Row, "Cancel"); b.action := CancelAction; cancel := b;
  dialog.End;
  dialog.action := CancelAction;  (* the close button *)
  dialog.SetModal
END Build;

(* Edits a, an attack of c; isNew if the window has just added it, so
   that Cancel takes it out again. done is called after OK or Cancel,
   changed TRUE for OK. *)
PROCEDURE EditAttack*(c: OvaCharacter.Character; a: OvaCharacter.Attack; new: BOOLEAN;
                      d: PROCEDURE (changed: BOOLEAN));
BEGIN
  ASSERT(dialog = NIL);
  character := c; attack := a; trait := NIL; isNew := new; done := d;
  savedAttack := a^; savedMods := OvaCharacter.CopyMods(a.mods);
  Build("Attack");
  SetText(nameIn, a.name); SetText(affinityIn, a.affinity); SetText(descriptionIn, a.description);
  telekinetic.SetValue(a.telekinetic); transformed.SetValue(a.transformed);
  perks.Refresh(0); flaws.Refresh(0);
  OvaCharacter.Recompute(character);
  ShowNumbers;
  dialog.Show
END EditAttack;

(* Edits t's Perks and Flaws, and its END: an Ability of c. *)
PROCEDURE EditMods*(c: OvaCharacter.Character; t: OvaCharacter.Trait; d: PROCEDURE (changed: BOOLEAN));
  VAR title: ARRAY 64 OF CHAR;
BEGIN
  ASSERT(dialog = NIL);
  character := c; attack := NIL; trait := t; isNew := FALSE; done := d;
  savedEnd := t.end; savedMods := OvaCharacter.CopyMods(t.mods);
  IF t.item # NIL THEN OvaRules.Label(t.item, title) ELSE title := "an Ability" END;
  Build(title);
  nameIn.Hide; affinityIn.Hide; descriptionIn.Hide; telekinetic.Hide; transformed.Hide;
  roll.Hide; dx.Hide;
  perks.Refresh(0); flaws.Refresh(0);
  OvaCharacter.Recompute(character);
  ShowNumbers;
  dialog.Show
END EditMods;

(* For tests: OK and Cancel, as if pushed. *)
PROCEDURE Ok*;
BEGIN OkAction(ok)
END Ok;

PROCEDURE Cancel*;
BEGIN CancelAction(cancel)
END Cancel;

BEGIN
  dialog := NIL; done := NIL; tell := NIL
END OvaAttackDialog.
