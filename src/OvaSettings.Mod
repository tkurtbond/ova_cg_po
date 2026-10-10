MODULE OvaSettings; (* Character > Limits...: the rules that limit a character, saved in its options *)

(* PLAN.md, "Limiting the character (p. 21)": Base Zero, a Power
   Ceiling, starting levels, Scaled Cost, Knowledge and Ineptitude at
   half cost, Combined Effectiveness, each turned on here and saved in
   the character's options: block. OvaCalc applies them; this dialog
   only sets them.

   It edits the character as the user works, as the attack dialog does,
   so the totals and warnings behind it follow each change (changed,
   the window's); Cancel puts back the options there were. It is modal
   but doesn't wait: OK and Cancel call done.

   A number turned off keeps what it was, so turning it on again brings
   it back; one never set starts at p. 21's example: Base Zero's 5, 5
   starting levels and a Power Ceiling of 15. *)

IMPORT Fl, FlButtons, FlValuators, OvaCalc, OvaCharacter, OvaWidgets;

CONST
  Width = 560; Height = 300; Row = 25;
  BaseZeroDefault = 5; CeilingDefault = 15; StartingDefault = 5;
  LimitsPage = 21; HalfCostPage = 57;

VAR
  dialog-: Fl.DoubleWindow;  (* NIL when not open *)
  baseZero-, powerCeiling-, startingLevels-, scaledCost-, halfCost-, combined-: FlButtons.CheckButton;
  baseZeroRange-, ceiling-, starting-: FlValuators.Spinner;
  ok-, cancel-: FlButtons.Button;

  (* After each change: the window's, which recomputes and shows. *)
  changed*: PROCEDURE;

  character: OvaCharacter.Character;
  old: OvaCalc.Options;  (* as they were, for Cancel *)
  oldHas: BOOLEAN;
  done: PROCEDURE (ok: BOOLEAN);

(* Whether a and b are the same limits: a rule's number counts only
   while the rule is on, since only then is it used or saved. *)
PROCEDURE Same(VAR a, b: OvaCalc.Options): BOOLEAN;
BEGIN
  RETURN (a.baseZero = b.baseZero) & (~a.baseZero OR (a.baseZeroRange = b.baseZeroRange))
    & (a.powerCeiling = b.powerCeiling) & (~a.powerCeiling OR (a.ceiling = b.ceiling))
    & (a.startingLevels = b.startingLevels) & (~a.startingLevels OR (a.starting = b.starting))
    & (a.scaledCost = b.scaledCost) & (a.halfCostKnowledge = b.halfCostKnowledge)
    & (a.combinedEffectiveness = b.combinedEffectiveness)
END Same;

(* The spinners active only with their rule, half cost only with one of
   the rules it applies under (p. 57). *)
PROCEDURE ShowActive;
BEGIN
  IF baseZero.Value() THEN baseZeroRange.Activate ELSE baseZeroRange.Deactivate END;
  IF powerCeiling.Value() THEN ceiling.Activate ELSE ceiling.Deactivate END;
  IF startingLevels.Value() THEN starting.Activate ELSE starting.Deactivate END;
  IF baseZero.Value() OR powerCeiling.Value() OR scaledCost.Value() THEN halfCost.Activate
  ELSE halfCost.Deactivate
  END
END ShowActive;

(* The character's options set from the dialog. The block is saved
   while any rule is on, or if the file had one and nothing changed. *)
PROCEDURE Take;
  VAR o: OvaCalc.Options;
BEGIN
  o.baseZero := baseZero.Value(); o.baseZeroRange := SHORT(ENTIER(baseZeroRange.Value()));
  o.powerCeiling := powerCeiling.Value(); o.ceiling := SHORT(ENTIER(ceiling.Value()));
  o.startingLevels := startingLevels.Value(); o.starting := SHORT(ENTIER(starting.Value()));
  o.scaledCost := scaledCost.Value(); o.halfCostKnowledge := halfCost.Value();
  o.combinedEffectiveness := combined.Value();
  IF Same(o, character.options) THEN RETURN END;
  character.options := o;
  character.hasOptions := o.baseZero OR o.powerCeiling OR o.startingLevels OR o.scaledCost
    OR o.halfCostKnowledge OR o.combinedEffectiveness OR oldHas & Same(o, old);
  IF changed # NIL THEN changed END
END Take;

PROCEDURE ChangeAction(w: Fl.Widget);
BEGIN ShowActive; Take
END ChangeAction;

PROCEDURE Finish(accepted: BOOLEAN);
  VAR d: PROCEDURE (ok: BOOLEAN);
BEGIN
  dialog.Hide; dialog.Delete;
  dialog := NIL; baseZero := NIL; powerCeiling := NIL; startingLevels := NIL; scaledCost := NIL;
  halfCost := NIL; combined := NIL; baseZeroRange := NIL; ceiling := NIL; starting := NIL;
  ok := NIL; cancel := NIL; character := NIL;
  d := done; done := NIL;
  IF d # NIL THEN d(accepted) END
END Finish;

PROCEDURE OkAction(w: Fl.Widget);
BEGIN Finish(TRUE)
END OkAction;

PROCEDURE CancelAction(w: Fl.Widget);
BEGIN
  IF ~Same(character.options, old) OR (character.hasOptions # oldHas) THEN
    character.options := old; character.hasOptions := oldHas;
    IF changed # NIL THEN changed END
  END;
  Finish(FALSE)
END CancelAction;

PROCEDURE Check(VAR b: FlButtons.CheckButton; y: INTEGER; label: ARRAY OF CHAR; on: BOOLEAN);
BEGIN
  NEW(b); FlButtons.OpenCheckButton(b, 10, y, 330, Row, label);
  b.SetValue(on); b.action := ChangeAction
END Check;

(* A spinner from low to high showing value, or default if the rule is off. *)
PROCEDURE Spinner(VAR s: FlValuators.Spinner; y: INTEGER; label: ARRAY OF CHAR; low, high: INTEGER;
    on: BOOLEAN; value, default: INTEGER);
BEGIN
  NEW(s); FlValuators.OpenSpinner(s, 440, y, 70, Row, label);
  s.SetBounds(low, high);
  IF on THEN s.SetValue(value) ELSE s.SetValue(default) END;
  s.action := ChangeAction
END Spinner;

PROCEDURE Help(y, page: INTEGER);
  VAR h: OvaWidgets.HelpButton;
BEGIN NEW(h); OvaWidgets.OpenHelpButton(h, Width - 35, y, page)
END Help;

(* Edits c's limits; done is called on OK (ok) or Cancel. *)
PROCEDURE Edit*(c: OvaCharacter.Character; d: PROCEDURE (ok: BOOLEAN));
  VAR o: OvaCalc.Options; y: INTEGER; r: FlButtons.ReturnButton;
BEGIN
  ASSERT(dialog = NIL);
  character := c; done := d; old := c.options; oldHas := c.hasOptions; o := c.options;
  NEW(dialog); Fl.OpenDoubleWindow(dialog, Width, Height, "Limits");
  y := 10;
  Check(baseZero, y, "Base Zero: the Character Total within", o.baseZero);
  Spinner(baseZeroRange, y, "+/-", 0, 99, o.baseZero, o.baseZeroRange, BaseZeroDefault);
  Help(y, LimitsPage);
  y := y + Row + 10;
  Check(startingLevels, y, "Starting levels, plus the Weaknesses'", o.startingLevels);
  Spinner(starting, y, "levels", 0, 999, o.startingLevels, o.starting, StartingDefault);
  Help(y, LimitsPage);
  y := y + Row + 10;
  Check(powerCeiling, y, "Power Ceiling: the Abilities at most", o.powerCeiling);
  Spinner(ceiling, y, "levels", 1, 999, o.powerCeiling, o.ceiling, CeilingDefault);
  Help(y, LimitsPage);
  y := y + Row + 10;
  Check(scaledCost, y, "Scaled Cost: +1 to +5 cost 1, 2, 4, 8, 15", o.scaledCost);
  Help(y, LimitsPage);
  y := y + Row + 10;
  Check(halfCost, y, "Knowledge and Ineptitude at half cost", o.halfCostKnowledge);
  Help(y, HalfCostPage);
  y := y + Row + 10;
  Check(combined, y, "Combined Effectiveness: at most +5 to a roll", o.combinedEffectiveness);
  Help(y, LimitsPage);
  NEW(r); FlButtons.OpenReturnButton(r, Width - 190, Height - 35, 85, Row, "OK"); r.action := OkAction; ok := r;
  NEW(cancel); FlButtons.OpenButton(cancel, Width - 95, Height - 35, 85, Row, "Cancel");
  cancel.action := CancelAction;
  dialog.End;
  dialog.action := CancelAction;  (* the close button *)
  dialog.SetModal;
  ShowActive;
  dialog.Show
END Edit;

(* For tests: Cancel, as if pushed. *)
PROCEDURE Cancel*;
BEGIN CancelAction(cancel)
END Cancel;

BEGIN
  dialog := NIL; changed := NIL; done := NIL; character := NIL
END OvaSettings.
