MODULE OvaLinkedDialog; (* An Ability's linked content: a Transformation's form, a Magic's spells, a Companion or Vehicle *)

(* PLAN.md, "The window": an Ability with linked content has a button
   that opens this dialog, in one of three shapes (OvaRules.Item.linked):

   - Form, a Transformation's (p. 63): the form's Abilities and
     Weaknesses, worth 2 levels a level of Transformation, each line
     with its page; the selected Ability's Perks and Flaws and END.
   - Spells, a Magic's (p. 57-58): each spell's name, the Ability it
     mimics, its level, and its END, computed from the Magic's level and
     its own, with an override box. Witchcraft's spells are curses: the
     Weakness each casts, at -1 to -3 (p. 58; OvaRules.CastsWeaknesses).
   - A partner's sheet, a Companion's (p. 52) or a Vehicle's (p. 64):
     its name, whether it is a Fragment, whether it has combat stats,
     its Abilities and Weaknesses, its attacks (edited in the attack
     dialog) and its numbers, each with its override box.

   It edits the model as the user works, as the window's first tab
   does, and has Close, no Cancel: a change is in the character at
   once, and changed (the window's) recomputes it and shows it. It is
   modal but doesn't wait: Edit shows it, and Close calls done. *)

IMPORT Fl, FlBrowsers, FlButtons, FlInputs, FlMenus, FlValuators, OvaAttackDialog, OvaCalc, OvaCharacter,
  OvaRules, OvaText, OvaTraitPanel, OvaWidgets, Ropes;

CONST
  Width = 760; Row = 25;
  (* The dialog's height in each shape. *)
  FormH = 450; SpellsH = 500; PartnerH = 640;
  (* SheetNum.which: a partner's numbers *)
  Defense = 0; Barrier = 1; Health = 2; Endurance = 3; Reserve = 4; TV = 5; Incorporeal = 6;
  NNumbers = 7;

TYPE
  Rope = Ropes.Rope;
  SheetNum = POINTER TO RECORD (OvaWidgets.TargetDesc) which: INTEGER END;
  TraitEnd = POINTER TO RECORD (OvaWidgets.TargetDesc) trait: OvaCalc.Trait END;
  SpellEnd = POINTER TO RECORD (OvaWidgets.TargetDesc) spell: OvaCalc.Spell END;

VAR
  dialog-: Fl.DoubleWindow;  (* NIL when closed *)
  mode-: INTEGER;            (* OvaRules.Form, Spells, Partner or Machine *)
  info-: Fl.Box;             (* what the dialog edits, and the form's levels *)
  close-: FlButtons.Button;

  (* A form's, or a partner's: *)
  abilities-, weaknesses-: OvaTraitPanel.TraitPanel;
  mods-: FlButtons.Button;   (* the selected Ability's Perks and Flaws *)
  end-: OvaWidgets.NumberBox;  (* its END *)

  (* A Magic's: *)
  spells-: FlBrowsers.HoldBrowser;
  spellName-: FlInputs.Input;
  spellAbility-: FlMenus.Choice;
  spellLevel-: FlValuators.Spinner;
  spellHelp-: OvaWidgets.HelpButton;
  addSpell-, changeSpell-, removeSpell-: FlButtons.Button;
  spellEnd-: OvaWidgets.NumberBox;
  castKind-: INTEGER;        (* what the spells mimic: OvaRules.Ability, or Weakness for Witchcraft *)

  (* A partner's: *)
  partnerName-: FlInputs.Input;
  fragment-, combat-: FlButtons.CheckButton;
  attacks-: FlBrowsers.HoldBrowser;
  addAttack-, editAttack-, removeAttack-: FlButtons.Button;
  numbers-: ARRAY NNumbers OF OvaWidgets.NumberBox;

  character: OvaCharacter.Character;  (* the window's, recomputed after a change *)
  trait: OvaCharacter.Trait;           (* the Ability whose content this is *)
  partner: OvaCharacter.Character;     (* its partner's sheet, in Partner and Machine *)
  done: PROCEDURE;

  (* Set by the window: recomputes the character and shows it, after
     every change made here. *)
  changed*: PROCEDURE;
  tell*: PROCEDURE (text: Rope);

PROCEDURE^ ShowAll;

(* ---- Text ---- *)

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE InputText(i: FlInputs.Input): Rope;
  VAR s: Fl.String;
BEGIN s := i.Text(); RETURN OvaText.Trim(Ropes.FromString(s^))
END InputText;

PROCEDURE SetInput(i: FlInputs.Input; r: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(r); i.SetValue(s^)
END SetInput;

(* After a change here: the character recomputed and shown, here and in
   the window. *)
PROCEDURE Changed;
BEGIN
  IF changed # NIL THEN changed ELSE OvaCharacter.Recompute(character) END;
  ShowAll
END Changed;

(* ---- Numbers ---- *)

PROCEDURE (t: SheetNum) Get*(VAR n: OvaCalc.Number);
BEGIN
  CASE t.which OF
    Defense: n := partner.defense | Barrier: n := partner.barrier | Incorporeal: n := partner.incorporeal
  | Health: n := partner.health
  | Endurance: n := partner.endurance | Reserve: n := partner.reserve | TV: n := partner.tv
  END
END Get;

PROCEDURE (t: SheetNum) Put*(VAR n: OvaCalc.Number);
BEGIN
  CASE t.which OF
    Defense: partner.defense := n | Barrier: partner.barrier := n | Incorporeal: partner.incorporeal := n
  | Health: partner.health := n
  | Endurance: partner.endurance := n | Reserve: partner.reserve := n | TV: partner.tv := n
  END
END Put;

PROCEDURE (t: TraitEnd) Get*(VAR n: OvaCalc.Number);
BEGIN n := t.trait.end
END Get;

PROCEDURE (t: TraitEnd) Put*(VAR n: OvaCalc.Number);
BEGIN t.trait.end := n
END Put;

PROCEDURE (t: SpellEnd) Get*(VAR n: OvaCalc.Number);
BEGIN n := t.spell.end
END Get;

PROCEDURE (t: SpellEnd) Put*(VAR n: OvaCalc.Number);
BEGIN t.spell.end := n
END Put;

PROCEDURE NumberChanged(b: OvaWidgets.NumberBox; ok: BOOLEAN);
  VAR label: ARRAY 32 OF CHAR; msg: Rope;
BEGIN
  IF ~ok THEN
    b.GetLabel(label);
    msg := R("Not a number for "); OvaText.Add(msg, label);
    OvaText.Add(msg, ". The computed number is used.");
    tell(msg)
  END;
  Changed
END NumberChanged;

PROCEDURE NumberBox(VAR b: OvaWidgets.NumberBox; t: OvaWidgets.Target; x, y: INTEGER; label: ARRAY OF CHAR);
BEGIN
  NEW(b); OvaWidgets.OpenNumberBox(b, x, y, label);
  b.target := t; b.changed := NumberChanged
END NumberBox;

(* ---- Abilities and Weaknesses: a form's or a partner's ---- *)

(* The selected Ability's END and Perks and Flaws. *)
PROCEDURE ShowAbility(t: OvaCharacter.Trait);
  VAR e: TraitEnd;
BEGIN
  IF t = NIL THEN end.target := NIL; end.Deactivate; mods.Deactivate
  ELSE
    NEW(e); e.trait := t; end.target := e;
    IF t.hasEnd THEN end.Activate ELSE end.Deactivate END;
    mods.Activate
  END;
  end.Display
END ShowAbility;

PROCEDURE AbilitySelected(p: OvaTraitPanel.TraitPanel; t: OvaCharacter.Trait);
BEGIN ShowAbility(t)
END AbilitySelected;

PROCEDURE PanelChanged(p: OvaTraitPanel.TraitPanel);
BEGIN Changed
END PanelChanged;

PROCEDURE ModsDone(changed: BOOLEAN);
BEGIN
  IF changed THEN Changed END;
  abilities.Refresh(abilities.browser.Value())
END ModsDone;

PROCEDURE ModsAction(w: Fl.Widget);
  VAR t: OvaCharacter.Trait;
BEGIN
  t := abilities.Selected();
  IF t # NIL THEN
    IF partner # NIL THEN OvaAttackDialog.EditMods(partner, t, ModsDone)
    ELSE OvaAttackDialog.EditMods(character, t, ModsDone)
    END
  END
END ModsAction;

(* The two panels at y, each browser h high, and the Ability's controls
   under them. *)
PROCEDURE Panels(y, h: INTEGER);
  VAR yy: INTEGER;
BEGIN
  NEW(abilities); OvaTraitPanel.Open(abilities, 10, y, 365, h, OvaRules.Ability, "Abilities");
  abilities.selected := AbilitySelected; abilities.changed := PanelChanged;
  NEW(weaknesses); OvaTraitPanel.Open(weaknesses, 385, y, 365, h, OvaRules.Weakness, "Weaknesses");
  weaknesses.changed := PanelChanged;
  yy := abilities.bottom + 5;
  NEW(mods); FlButtons.OpenButton(mods, 10, yy, 140, Row, "Perks and Flaws..."); mods.action := ModsAction;
  NEW(end); OvaWidgets.OpenNumberBox(end, 200, yy, "END");
  end.SetAlign(Fl.AlignLeft); end.changed := NumberChanged
END Panels;

(* The form's levels, against what the Transformation pays for: 2 a
   level (p. 63). *)
PROCEDURE ShowFormLevels;
  VAR f: OvaCalc.Trait; n: INTEGER; r: Rope; s: OvaText.String;
BEGIN
  n := 0; f := trait.form; WHILE f # NIL DO INC(n, f.level); f := f.next END;
  r := R("The form's Abilities and Weaknesses come to ");
  IF n > 0 THEN OvaText.Add(r, "+") END;
  OvaText.AddInt(r, n); OvaText.Add(r, " levels; Transformation +");
  OvaText.AddInt(r, trait.level); OvaText.Add(r, " pays for "); OvaText.AddInt(r, 2 * trait.level);
  OvaText.Add(r, " (p. 63).");
  s := OvaText.Chars(r); info.SetLabel(s^);
  IF n > 2 * trait.level THEN info.SetLabelColor(Fl.Red) ELSE info.SetLabelColor(Fl.ForegroundColor) END;
  info.Redraw
END ShowFormLevels;

(* ---- Spells ---- *)

(* The spell on line line (from 1); NIL for none. *)
PROCEDURE SpellAt(line: INTEGER): OvaCharacter.Spell;
  VAR sp: OvaCalc.Spell;
BEGIN
  IF line < 1 THEN RETURN NIL END;
  sp := trait.spells;
  WHILE (sp # NIL) & (line > 1) DO sp := sp.next; DEC(line) END;
  IF sp = NIL THEN RETURN NIL ELSE RETURN sp(OvaCharacter.Spell) END
END SpellAt;

(* The spells listed again, line line selected (0: none), and its END. *)
PROCEDURE ShowSpells(line: INTEGER);
  VAR sp: OvaCalc.Spell; x: OvaCharacter.Spell; r: Rope; s: OvaText.String; label, e: ARRAY 64 OF CHAR;
    t: SpellEnd;
BEGIN
  spells.Clear;
  sp := trait.spells;
  WHILE sp # NIL DO
    x := sp(OvaCharacter.Spell);
    r := x.name; r := Ropes.AppendChar(r, 9X);
    r := Ropes.Cat(r, x.ability); OvaText.Add(r, " ");
    IF x.level > 0 THEN OvaText.Add(r, "+") END;
    OvaText.AddInt(r, x.level);
    OvaRules.PageText(x.item, label); OvaText.Add(r, " ("); OvaText.Add(r, label); OvaText.Add(r, ")");
    r := Ropes.AppendChar(r, 9X);
    OvaCalc.Text(x.end, e); OvaText.Add(r, "END "); OvaText.Add(r, e);
    s := OvaText.Chars(r); spells.Add(s^);
    sp := sp.next
  END;
  x := SpellAt(line);
  IF x # NIL THEN
    spells.SetSelected(line, TRUE);
    NEW(t); t.spell := x; spellEnd.target := t; spellEnd.Activate
  ELSE
    spellEnd.target := NIL; spellEnd.Deactivate
  END;
  spellEnd.Display
END ShowSpells;

(* The Ability (or Weakness) chosen; NIL for none. *)
PROCEDURE SpellItem(): OvaRules.Item;
  VAR i: INTEGER;
BEGIN
  i := spellAbility.Value();
  IF (i >= 0) & (i < OvaRules.Count(castKind)) THEN RETURN OvaRules.Get(castKind, i)
  ELSE RETURN NIL
  END
END SpellItem;

(* Chooses it in the Choice; none for NIL, or an item it doesn't offer
   (a spell the Magic can't cast, from a file). *)
PROCEDURE ChooseSpellItem(it: OvaRules.Item);
  VAR n: INTEGER;
BEGIN
  n := -1;
  IF it # NIL THEN n := OvaRules.OfferIndex(it, castKind, FALSE) END;
  spellAbility.Choose(n);
  IF it # NIL THEN spellHelp.page := it.page ELSE spellHelp.page := 0 END
END ChooseSpellItem;

PROCEDURE SpellAbilityAction(w: Fl.Widget);
BEGIN ChooseSpellItem(SpellItem())
END SpellAbilityAction;

PROCEDURE SpellsAction(w: Fl.Widget);
  VAR x: OvaCharacter.Spell;
BEGIN
  x := SpellAt(spells.Value());
  IF x # NIL THEN
    SetInput(spellName, x.name); ChooseSpellItem(x.item); spellLevel.SetValue(x.level);
    ShowSpells(spells.Value())
  END
END SpellsAction;

(* Add puts the spell last; Change and Remove need one selected. A spell
   needs a name and an Ability (a Weakness, Witchcraft's); one changed
   keeps one the Choice doesn't have if none is chosen. *)
PROCEDURE SpellButtonAction(w: Fl.Widget);
  VAR line: INTEGER; name: Rope; it: OvaRules.Item; x, sp: OvaCharacter.Spell; p: OvaCalc.Spell;
BEGIN
  line := spells.Value(); x := SpellAt(line);
  name := InputText(spellName); it := SpellItem();
  IF w = removeSpell THEN
    IF x = NIL THEN RETURN END;
    OvaCharacter.RemoveSpell(trait, x); line := 0
  ELSIF (name = NIL) OR (it = NIL) & ((w = addSpell) OR (x = NIL) OR (x.item # NIL)) THEN
    IF castKind = OvaRules.Weakness THEN tell(R("A curse needs a name and the Weakness it casts."))
    ELSE tell(R("A spell needs a name and the Ability it mimics."))
    END;
    RETURN
  ELSIF w = addSpell THEN
    sp := OvaCharacter.NewSpell(name, R(it.name), it, SHORT(ENTIER(spellLevel.Value())));
    OvaCalc.AddSpell(trait, sp);
    line := 1; p := trait.spells; WHILE p # sp DO INC(line); p := p.next END
  ELSIF x = NIL THEN RETURN
  ELSE
    x.name := name;
    IF it # NIL THEN x.item := it; x.ability := R(it.name) END;
    x.level := SHORT(ENTIER(spellLevel.Value()))
  END;
  Changed;
  ShowSpells(line)
END SpellButtonAction;

(* ---- A partner's sheet ---- *)

PROCEDURE PartnerTextAction(w: Fl.Widget);
  VAR name: Rope;
BEGIN
  IF w = partnerName THEN
    name := InputText(partnerName);
    IF name = NIL THEN name := partner.label END;  (* the file needs one *)
    partner.name := name
  ELSIF w = fragment THEN partner.isFragment := fragment.Value()
  ELSIF w = combat THEN partner.hasCombat := combat.Value()
  END;
  Changed
END PartnerTextAction;

(* The attack on line line (from 1); NIL for none. *)
PROCEDURE AttackAt(line: INTEGER): OvaCharacter.Attack;
  VAR a: OvaCalc.Attack;
BEGIN
  IF line < 1 THEN RETURN NIL END;
  a := partner.attacks;
  WHILE (a # NIL) & (line > 1) DO a := a.next; DEC(line) END;
  IF a = NIL THEN RETURN NIL ELSE RETURN a(OvaCharacter.Attack) END
END AttackAt;

PROCEDURE ShowAttacks(line: INTEGER);
  VAR a: OvaCalc.Attack; r: Rope; s: OvaText.String; n: ARRAY 32 OF CHAR;
BEGIN
  attacks.Clear;
  a := partner.attacks;
  WHILE a # NIL DO
    r := a(OvaCharacter.Attack).name;
    r := Ropes.AppendChar(r, 9X); OvaCalc.Text(a.roll, n); OvaText.Add(r, "ROLL "); OvaText.Add(r, n);
    r := Ropes.AppendChar(r, 9X); OvaCalc.Text(a.dx, n); OvaText.Add(r, "DX "); OvaText.Add(r, n);
    r := Ropes.AppendChar(r, 9X); OvaCalc.Text(a.end, n); OvaText.Add(r, "END "); OvaText.Add(r, n);
    s := OvaText.Chars(r); attacks.Add(s^);
    a := a.next
  END;
  IF (line > 0) & (line <= attacks.Count()) THEN attacks.SetSelected(line, TRUE) END
END ShowAttacks;

PROCEDURE AttackDone(changed: BOOLEAN);
BEGIN Changed
END AttackDone;

PROCEDURE AttackButtonAction(w: Fl.Widget);
  VAR a: OvaCharacter.Attack;
BEGIN
  IF w = addAttack THEN
    a := OvaCharacter.NewAttack(R("New attack"));
    OvaCalc.AddAttack(partner, a);
    OvaCharacter.Recompute(character);
    OvaAttackDialog.EditAttack(partner, a, TRUE, AttackDone)
  ELSE
    a := AttackAt(attacks.Value());
    IF a = NIL THEN RETURN END;
    IF w = editAttack THEN OvaAttackDialog.EditAttack(partner, a, FALSE, AttackDone)
    ELSE OvaCharacter.RemoveAttack(partner, a); Changed
    END
  END
END AttackButtonAction;

(* ---- Everything shown ---- *)

PROCEDURE ShowAll;
  VAR i, line: INTEGER;
BEGIN
  IF dialog = NIL THEN RETURN END;
  CASE mode OF
    OvaRules.Form:
      ShowFormLevels; end.Display
  | OvaRules.Spells:
      ShowSpells(spells.Value())
  | OvaRules.Partner, OvaRules.Machine:
      end.Display;
      line := attacks.Value(); ShowAttacks(line);
      FOR i := 0 TO NNumbers - 1 DO numbers[i].Display END;
      (* With no combat stats, nothing of combat is saved: all of it
         inactive. Barrier's and Incorporeal Form's Defense and the
         Reserve only with them. *)
      IF partner.hasCombat THEN
        attacks.Activate; addAttack.Activate; editAttack.Activate; removeAttack.Activate;
        FOR i := 0 TO NNumbers - 1 DO numbers[i].Activate END;
        IF ~partner.hasBarrier THEN numbers[Barrier].Deactivate END;
        IF ~partner.hasIncorporeal THEN numbers[Incorporeal].Deactivate END;
        IF ~partner.hasReserve THEN numbers[Reserve].Deactivate END
      ELSE
        attacks.Deactivate; addAttack.Deactivate; editAttack.Deactivate; removeAttack.Deactivate;
        FOR i := 0 TO NNumbers - 1 DO numbers[i].Deactivate END
      END
  END
END ShowAll;

(* ---- Opening and closing ---- *)

PROCEDURE Finish;
  VAR d: PROCEDURE;
BEGIN
  IF abilities # NIL THEN OvaWidgets.ClosePanel(abilities); OvaWidgets.ClosePanel(weaknesses) END;
  dialog.Hide; dialog.Delete;
  dialog := NIL; abilities := NIL; weaknesses := NIL; mods := NIL; end := NIL; info := NIL; close := NIL;
  spells := NIL; spellName := NIL; spellAbility := NIL; spellLevel := NIL; spellHelp := NIL;
  addSpell := NIL; changeSpell := NIL; removeSpell := NIL; spellEnd := NIL;
  partnerName := NIL; fragment := NIL; combat := NIL; attacks := NIL;
  addAttack := NIL; editAttack := NIL; removeAttack := NIL;
  character := NIL; trait := NIL; partner := NIL;
  d := done; done := NIL;
  IF d # NIL THEN d END
END Finish;

PROCEDURE CloseAction(w: Fl.Widget);
BEGIN
  IF OvaAttackDialog.dialog # NIL THEN RETURN END;  (* it is above this one: it closes first *)
  Finish
END CloseAction;

PROCEDURE BuildForm;
BEGIN
  Panels(40, 300);
  abilities.Show(character, trait, character); weaknesses.Show(character, trait, character)
END BuildForm;

PROCEDURE BuildSpells;
  VAR i, y: INTEGER; label: ARRAY 64 OF CHAR; widths: ARRAY 3 OF INTEGER; b: FlButtons.Button;
BEGIN
  NEW(spells); FlBrowsers.OpenHoldBrowser(spells, 10, 60, Width - 20, 300, "Spells");
  spells.SetAlign(Fl.AlignTopLeft); spells.SetFormatChar(0X); spells.action := SpellsAction;
  widths[0] := 260; widths[1] := 320; widths[2] := 0; spells.SetColumnWidths(widths, 3);
  y := 370;
  NEW(spellName); FlInputs.OpenInput(spellName, 70, y, 250, Row, "Name");
  IF OvaRules.CastsWeaknesses IN trait.item.flags THEN castKind := OvaRules.Weakness
  ELSE castKind := OvaRules.Ability
  END;
  NEW(spellAbility);
  IF castKind = OvaRules.Weakness THEN FlMenus.OpenChoice(spellAbility, 400, y, 290, Row, "Weakness")
  ELSE FlMenus.OpenChoice(spellAbility, 400, y, 290, Row, "Ability")
  END;
  FOR i := 0 TO OvaRules.Count(castKind) - 1 DO
    OvaRules.Label(OvaRules.Get(castKind, i), label);
    spellAbility.AddText(label, NIL, {})
  END;
  spellAbility.action := SpellAbilityAction;
  NEW(spellHelp); OvaWidgets.OpenHelpButton(spellHelp, 695, y, 0);
  y := y + Row + 5;
  NEW(spellLevel); FlValuators.OpenSpinner(spellLevel, 70, y, 60, Row, "level");
  IF castKind = OvaRules.Weakness THEN spellLevel.SetBounds(-3, -1); spellLevel.SetValue(-1)
  ELSE spellLevel.SetBounds(1, 5); spellLevel.SetValue(1)
  END;
  NEW(spellEnd); OvaWidgets.OpenNumberBox(spellEnd, 200, y, "END");
  spellEnd.SetAlign(Fl.AlignLeft); spellEnd.allowPlus := TRUE; spellEnd.changed := NumberChanged;
  y := y + Row + 5;
  NEW(b); FlButtons.OpenButton(b, 10, y, 70, Row, "Add"); b.action := SpellButtonAction; addSpell := b;
  NEW(b); FlButtons.OpenButton(b, 85, y, 70, Row, "Change"); b.action := SpellButtonAction; changeSpell := b;
  NEW(b); FlButtons.OpenButton(b, 160, y, 70, Row, "Remove"); b.action := SpellButtonAction; removeSpell := b;
  ShowSpells(0)
END BuildSpells;

PROCEDURE BuildPartner;
  VAR y: INTEGER; t: SheetNum; widths: ARRAY 4 OF INTEGER; b: FlButtons.Button;
BEGIN
  NEW(partnerName); FlInputs.OpenInput(partnerName, 60, 40, 250, Row, "Name");
  partnerName.SetWhen(Fl.WhenChanged); partnerName.action := PartnerTextAction;
  SetInput(partnerName, partner.name);
  NEW(fragment); FlButtons.OpenCheckButton(fragment, 330, 40, 200, Row, "a Fragment");
  fragment.SetValue(partner.isFragment); fragment.action := PartnerTextAction;
  NEW(combat); FlButtons.OpenCheckButton(combat, 540, 40, 200, Row, "combat stats");
  combat.SetValue(partner.hasCombat); combat.action := PartnerTextAction;
  Panels(70, 170);
  abilities.Show(partner, NIL, character); weaknesses.Show(partner, NIL, character);
  y := mods.Y() + Row + 10;
  NEW(attacks); FlBrowsers.OpenHoldBrowser(attacks, 10, y + 20, Width - 20, 100, "Attacks");
  attacks.SetAlign(Fl.AlignTopLeft); attacks.SetFormatChar(0X);
  widths[0] := 300; widths[1] := 100; widths[2] := 100; widths[3] := 0; attacks.SetColumnWidths(widths, 4);
  y := y + 125;
  NEW(b); FlButtons.OpenButton(b, 10, y, 70, Row, "Add..."); b.action := AttackButtonAction; addAttack := b;
  NEW(b); FlButtons.OpenButton(b, 85, y, 70, Row, "Edit..."); b.action := AttackButtonAction; editAttack := b;
  NEW(b); FlButtons.OpenButton(b, 160, y, 70, Row, "Remove"); b.action := AttackButtonAction; removeAttack := b;
  y := y + Row + 25;
  NEW(t); t.which := Defense; NumberBox(numbers[Defense], t, 10, y, "DEFENSE");
  NEW(t); t.which := Barrier; NumberBox(numbers[Barrier], t, 130, y, "Barrier DEFENSE");
  NEW(t); t.which := Incorporeal; NumberBox(numbers[Incorporeal], t, 130, y + 50, "Incorporeal DEFENSE");
  NEW(t); t.which := Health; NumberBox(numbers[Health], t, 250, y, "HEALTH");
  NEW(t); t.which := Endurance; NumberBox(numbers[Endurance], t, 370, y, "ENDURANCE");
  NEW(t); t.which := Reserve; NumberBox(numbers[Reserve], t, 490, y, "Reserve");
  NEW(t); t.which := TV; NumberBox(numbers[TV], t, 610, y, "TV");
  ShowAttacks(0)
END BuildPartner;

(* Edits t's linked content, t an Ability of c (or of its form, or its
   partner's) with some (t.item.linked # NoLink). A Companion or
   Vehicle gets its sheet now if it has none. done is called on Close. *)
PROCEDURE Edit*(c: OvaCharacter.Character; t: OvaCharacter.Trait; d: PROCEDURE);
  VAR title: ARRAY 64 OF CHAR; r: Rope; s: OvaText.String; h: INTEGER;
BEGIN
  ASSERT((dialog = NIL) & (t.item # NIL) & (t.item.linked # OvaRules.NoLink));
  character := c; trait := t; done := d; mode := t.item.linked; partner := NIL;
  IF (mode = OvaRules.Partner) OR (mode = OvaRules.Machine) THEN
    IF t.partner = NIL THEN t.partner := OvaCharacter.NewPartner(t); IF changed # NIL THEN changed END END;
    partner := t.partner(OvaCharacter.Character)
  END;
  OvaRules.Label(t.item, title);
  CASE mode OF OvaRules.Form: h := FormH | OvaRules.Spells: h := SpellsH ELSE h := PartnerH END;
  NEW(dialog); Fl.OpenDoubleWindow(dialog, Width, h, title);
  NEW(info); Fl.OpenBox(info, 10, 5, Width - 20, Row, "");
  info.SetAlign(Fl.AlignLeft + Fl.AlignInside);
  CASE mode OF
    OvaRules.Form: BuildForm
  | OvaRules.Spells:
      r := R("Magic +"); OvaText.AddInt(r, t.level);
      IF OvaRules.CastsWeaknesses IN t.item.flags THEN
        OvaText.Add(r, ": a curse casts a Weakness; its END is by the Magic's level and the Weakness's size (p. 58).")
      ELSE
        OvaText.Add(r, ": a spell's END is by the Magic's level and its own (p. 58), more for Barrier.")
      END;
      s := OvaText.Chars(r); info.SetLabel(s^);
      BuildSpells
  | OvaRules.Partner, OvaRules.Machine:
      IF mode = OvaRules.Partner THEN info.SetLabel("A Companion's sheet: a Secondary NPC's (p. 52, 123).")
      ELSE info.SetLabel("A Vehicle's sheet (p. 64).")
      END;
      BuildPartner
  END;
  NEW(close); FlButtons.OpenButton(close, Width - 95, h - 35, 85, Row, "Close"); close.action := CloseAction;
  dialog.End;
  dialog.action := CloseAction;  (* the close button *)
  dialog.SetModal;
  ShowAll;
  dialog.Show
END Edit;

(* For tests: Close, as if pushed. *)
PROCEDURE Close*;
BEGIN Finish
END Close;

BEGIN
  dialog := NIL; done := NIL; changed := NIL; tell := NIL; castKind := OvaRules.Ability;
  abilities := NIL; weaknesses := NIL
END OvaLinkedDialog.
