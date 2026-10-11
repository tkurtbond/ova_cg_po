MODULE OvaTraitPanel; (* A list of Abilities or Weaknesses and its editor: a character's, a form's, a partner's *)

(* PLAN.md, "The window": the Abilities and the Weaknesses are each a
   browser of lines ("+3 Attack (Kaze Satsujinsha)", a tab, "p. 50";
   under Scaled Cost, its points between: "+3 Attack", "4 pts", "p. 50")
   with OvaWidgets.Panel's controls. The same panel edits the
   character's own (OvaWindow), a Transformation's form, and a
   Companion's or Vehicle's (OvaLinkedDialog): its list is a sheet's
   traits, or, given an owner, the owner's form.

   After each change the panel recomputes top, the character the list
   belongs to, so what is shown is OvaCalc's; then calls changed, the
   window's or the dialog's. selected tells which trait the user
   chose (NIL after Remove), for the controls that act on one. *)

IMPORT OvaCalc, OvaCharacter, OvaRules, OvaText, OvaWidgets, Ropes;

CONST
  (* Under Scaled Cost, the browser's columns: the points', and at
     least this much for the page's. *)
  PointsW = 45; PageW = 60;

TYPE
  Rope = Ropes.Rope;
  Traits = POINTER TO ARRAY OF OvaCharacter.Trait;

  TraitPanel* = POINTER TO TraitPanelDesc;
  TraitPanelDesc* = RECORD (OvaWidgets.PanelDesc)
    sheet-: OvaCalc.Sheet;   (* whose traits are listed, *)
    owner-: OvaCalc.Trait;   (* or, if not NIL, whose form *)
    top-: OvaCharacter.Character;  (* recomputed after a change *)
    shown: Traits;           (* shown[i]: line i + 1's *)
    n: INTEGER;
    nameW-: INTEGER;         (* the names' column's width, as Fit set it *)
    selected*: PROCEDURE (p: TraitPanel; t: OvaCharacter.Trait);
    changed*: PROCEDURE (p: TraitPanel)
  END;

VAR
  (* Shows a message: the window's. *)
  tell*: PROCEDURE (text: Rope);

PROCEDURE (p: TraitPanel) List(): OvaCalc.Trait;
BEGIN IF p.owner # NIL THEN RETURN p.owner.form ELSE RETURN p.sheet.traits END
END List;

PROCEDURE (p: TraitPanel) SetList(l: OvaCalc.Trait);
BEGIN IF p.owner # NIL THEN p.owner.form := l ELSE p.sheet.traits := l END
END SetList;

(* The trait on line line (from 1); NIL for none. *)
PROCEDURE (p: TraitPanel) TraitAt*(line: INTEGER): OvaCharacter.Trait;
BEGIN IF (line >= 1) & (line <= p.n) THEN RETURN p.shown[line - 1] ELSE RETURN NIL END
END TraitAt;

(* The selected trait; NIL for none. *)
PROCEDURE (p: TraitPanel) Selected*(): OvaCharacter.Trait;
BEGIN RETURN p.TraitAt(p.browser.Value())
END Selected;

(* Whether the lines show Scaled Cost's points: a sheet's own traits
   under it, not a form's, which no total counts (p. 63). *)
PROCEDURE (p: TraitPanel) ShowsPoints*(): BOOLEAN;
BEGIN RETURN (p.sheet # NIL) & (p.owner = NIL) & p.sheet.options.scaledCost
END ShowsPoints;

(* Sets the columns' widths from the browser's width, as it is now: the
   name's column takes what the points and the page leave. *)
PROCEDURE (p: TraitPanel) Fit*;
  VAR widths: ARRAY 3 OF INTEGER;
BEGIN
  IF p.ShowsPoints() THEN
    widths[0] := p.browser.W() - PointsW - PageW; widths[1] := PointsW; widths[2] := 0;
    p.browser.SetColumnWidths(widths, 3)
  ELSE
    widths[0] := p.browser.W() - 70; widths[1] := 0;  (* as OvaWidgets.OpenPanel *)
    p.browser.SetColumnWidths(widths, 2)
  END;
  p.nameW := widths[0];
  p.browser.Redraw
END Fit;

PROCEDURE (p: TraitPanel) Fill*;
  VAR t: OvaCalc.Trait; x: OvaCharacter.Trait; line: Rope; s: OvaText.String; page: ARRAY 16 OF CHAR;
    points: BOOLEAN;
BEGIN
  p.n := 0;
  IF p.sheet = NIL THEN RETURN END;
  points := p.ShowsPoints();
  p.Fit;
  t := p.List();
  WHILE t # NIL DO IF t.kind = p.kind THEN INC(p.n) END; t := t.next END;
  NEW(p.shown, p.n + 1);
  p.n := 0; t := p.List();
  WHILE t # NIL DO
    IF t.kind = p.kind THEN
      x := t(OvaCharacter.Trait); p.shown[p.n] := x; INC(p.n);
      IF x.level > 0 THEN line := Ropes.FromString("+") ELSE line := NIL END;
      OvaText.AddInt(line, x.level); OvaText.Add(line, " ");
      line := Ropes.Cat(line, x.name);
      IF x.hasDetail THEN OvaText.Add(line, " ("); line := Ropes.Cat(line, x.detail); OvaText.Add(line, ")") END;
      line := Ropes.AppendChar(line, 9X);
      IF points THEN
        OvaText.AddInt(line, x.points);
        IF x.points = 1 THEN OvaText.Add(line, " pt") ELSE OvaText.Add(line, " pts") END;
        line := Ropes.AppendChar(line, 9X)
      END;
      OvaRules.PageText(x.item, page); OvaText.Add(line, page);
      s := OvaText.Chars(line); p.browser.Add(s^)
    END;
    t := t.next
  END
END Fill;

(* The line t is on. *)
PROCEDURE (p: TraitPanel) LineOf(t: OvaCalc.Trait): INTEGER;
  VAR i: INTEGER; l: OvaCalc.Trait;
BEGIN
  i := 0; l := p.List();
  WHILE (l # NIL) & (l # t) DO IF l.kind = p.kind THEN INC(i) END; l := l.next END;
  RETURN i + 1
END LineOf;

PROCEDURE (p: TraitPanel) Select(t: OvaCharacter.Trait);
BEGIN IF p.selected # NIL THEN p.selected(p, t) END
END Select;

PROCEDURE (p: TraitPanel) Load*(line: INTEGER);
  VAR t: OvaCharacter.Trait; s: OvaText.String;
BEGIN
  t := p.shown[line - 1];
  p.Choose(t.item);
  p.spinner.SetValue(t.level);
  s := OvaText.Chars(t.detail); p.text.SetValue(s^);
  p.Select(t)
END Load;

(* The detail typed; NIL for none. *)
PROCEDURE (p: TraitPanel) Detail(): Rope;
  VAR s: OvaText.String;
BEGIN
  NEW(s, p.text.Length() + 1); p.text.Value(s^);
  RETURN OvaText.Trim(Ropes.FromString(s^))
END Detail;

PROCEDURE (p: TraitPanel) Add*(): INTEGER;
  VAR it: OvaRules.Item; t: OvaCharacter.Trait; l: OvaCalc.Trait;
BEGIN
  it := p.Item();
  IF it = NIL THEN tell(Ropes.FromString("Choose a name first.")); RETURN 0 END;
  t := OvaCharacter.NewTrait(it, p.kind, SHORT(ENTIER(p.spinner.Value())), NIL, p.Detail());
  l := p.List(); OvaCharacter.InsertTrait(l, t); p.SetList(l);
  OvaCharacter.Recompute(p.top);
  RETURN p.LineOf(t)
END Add;

(* A name the tables don't have stays, if none is chosen. *)
PROCEDURE (p: TraitPanel) Change*(line: INTEGER): INTEGER;
  VAR it: OvaRules.Item; t: OvaCharacter.Trait; l: OvaCalc.Trait;
BEGIN
  t := p.shown[line - 1];
  it := p.Item(); IF it = NIL THEN it := t.item END;
  l := p.List(); OvaCharacter.ChangeTrait(l, t, it, SHORT(ENTIER(p.spinner.Value())), p.Detail()); p.SetList(l);
  OvaCharacter.Recompute(p.top);
  RETURN p.LineOf(t)
END Change;

PROCEDURE (p: TraitPanel) Remove*(line: INTEGER): BOOLEAN;
  VAR l: OvaCalc.Trait;
BEGIN
  l := p.List(); OvaCharacter.RemoveTrait(l, p.shown[line - 1]); p.SetList(l);
  p.Select(NIL);
  OvaCharacter.Recompute(p.top);
  RETURN TRUE
END Remove;

PROCEDURE (p: TraitPanel) Changed*;
BEGIN IF p.changed # NIL THEN p.changed(p) END
END Changed;

(* Lists sheet's traits (owner NIL) or owner's form, recomputing top
   after a change; nothing selected. *)
PROCEDURE (p: TraitPanel) Show*(sheet: OvaCalc.Sheet; owner: OvaCalc.Trait; top: OvaCharacter.Character);
BEGIN
  p.sheet := sheet; p.owner := owner; p.top := top;
  p.Refresh(0);
  p.Select(NIL)
END Show;

(* Opens p at x, y, w wide, its browser h high, for kind's traits:
   levels +1 to +5 for an Ability, -1 to -3 for a Weakness. *)
PROCEDURE Open*(p: TraitPanel; x, y, w, h, kind: INTEGER; title: ARRAY OF CHAR);
BEGIN
  p.sheet := NIL; p.owner := NIL; p.top := NIL; p.n := 0; NEW(p.shown, 1);
  p.selected := NIL; p.changed := NIL;
  OvaWidgets.OpenPanel(p, x, y, w, h, kind, title, "level", "detail");
  p.nameW := p.browser.W() - 70;  (* as OpenPanel sets it *)
  IF kind = OvaRules.Ability THEN p.spinner.SetBounds(1, 5); p.spinner.SetValue(1)
  ELSE p.spinner.SetBounds(-3, -1); p.spinner.SetValue(-1)
  END
END Open;

BEGIN
  tell := NIL
END OvaTraitPanel.
