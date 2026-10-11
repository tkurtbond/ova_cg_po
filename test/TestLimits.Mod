MODULE TestLimits; (* Character > Limits..., the totals in red, and the preferences: the rulebook and the viewer *)

(* Needs a display: run by make test-gui, as TestWindow is. The limits
   dialog driven as the user drives it, on a new character with an
   Attack +3 (a total of 3; 4 points under Scaled Cost, the Abilities'
   and the net), checked in the model, in what is saved, and in which
   total is red; then the
   Rulebook menu's choices, kept in a preferences file in obj/ and read
   back. *)

IMPORT Check, Fl, FlButtons, FlPreferences, FlValuators, OvaCharacter, OvaRules, OvaSave, OvaSettings, OvaText,
  OvaViewer, OvaWidgets, OvaWindow, Out, Ropes;

CONST
  PrefsDir = "../obj";  (* the preferences file: obj/ova_cg_po.prefs *)
  Vendor = "ova_cg_po"; Application = "ova_cg_po";

TYPE Rope = Ropes.Rope;

VAR
  tells, pdfAsks: INTEGER;
  pdfAnswer, textAnswer: Rope;  (* NIL: cancelled *)
  c: OvaCharacter.Character;
  prefs: FlPreferences.Preferences;
  s: ARRAY 256 OF CHAR;
  ok: BOOLEAN;

PROCEDURE Tell(text: Rope);
  VAR s: OvaText.String;
BEGIN INC(tells); s := OvaText.Chars(text); Out.String("    told: "); Out.String(s^); Out.Ln
END Tell;

PROCEDURE Ask(question: Rope): INTEGER;
BEGIN RETURN OvaWindow.Discard
END Ask;

PROCEDURE ChoosePdf(VAR p: Rope): BOOLEAN;
BEGIN INC(pdfAsks); p := pdfAnswer; RETURN p # NIL
END ChoosePdf;

PROCEDURE AskText(prompt: Rope; VAR text: Rope): BOOLEAN;
BEGIN IF textAnswer = NIL THEN RETURN FALSE END; text := textAnswer; RETURN TRUE
END AskText;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE Saved(): Rope;
BEGIN RETURN OvaSave.ToText(OvaWindow.character)
END Saved;

PROCEDURE Has(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.Find(r, s, 0) >= 0
END Has;

PROCEDURE Red(b: OvaWidgets.NumberBox): BOOLEAN;
BEGIN RETURN b.shown.TextColor() = Fl.Red
END Red;

(* Which of the Abilities' levels, the Total, the points and the
   Abilities' points are red: "ATPa" for all four, "-T--" for the Total
   alone. *)
PROCEDURE Reds(VAR s: ARRAY OF CHAR);
BEGIN
  COPY("----", s);
  IF Red(OvaWindow.numbers[6]) THEN s[0] := "A" END;
  IF Red(OvaWindow.numbers[8]) THEN s[1] := "T" END;
  IF Red(OvaWindow.numbers[9]) THEN s[2] := "P" END;
  IF Red(OvaWindow.numbers[11]) THEN s[3] := "a" END
END Reds;

PROCEDURE RedsAre(want: ARRAY OF CHAR): BOOLEAN;
  VAR s: ARRAY 5 OF CHAR;
BEGIN Reds(s); RETURN s = want
END RedsAre;

(* Sets check box b, as the user clicks it. *)
PROCEDURE Turn(b: FlButtons.CheckButton; on: BOOLEAN);
BEGIN b.SetValue(on); b.DoCallback
END Turn;

(* Sets spinner s to v, as the user types it. *)
PROCEDURE Spin(s: FlValuators.Spinner; v: INTEGER);
BEGIN s.SetValue(v); s.DoCallback
END Spin;

(* Chooses name in p's Choice, as the user does. *)
PROCEDURE Pick(p: OvaWidgets.Panel; name: ARRAY OF CHAR);
  VAR it: OvaRules.Item; i: INTEGER;
BEGIN
  it := OvaRules.Find(name); ASSERT(it # NIL);
  i := 0; WHILE OvaRules.Get(p.kind, i) # it DO INC(i) END;
  IF p.choice.SetValue(i) THEN END;
  p.choice.DoCallback
END Pick;

PROCEDURE AddAbility(name: ARRAY OF CHAR; level: INTEGER);
BEGIN
  Pick(OvaWindow.abilities, name); OvaWindow.abilities.spinner.SetValue(level);
  OvaWindow.abilities.text.SetValue(""); OvaWindow.abilities.add.DoCallback
END AddAbility;

PROCEDURE Value(s: FlValuators.Spinner): INTEGER;
BEGIN RETURN SHORT(ENTIER(s.Value()))
END Value;

(* A new character with Attack +3, unmodified; Limits... opened. *)
PROCEDURE Fresh;
BEGIN
  OvaWindow.bar.Pick(OvaWindow.newItem); c := OvaWindow.character;
  AddAbility("Attack", 3);
  OvaWindow.Adopt(OvaCharacter.One(c), NIL);
  OvaWindow.bar.Pick(OvaWindow.limitsItem)
END Fresh;

PROCEDURE ViewerIs(name: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.EqualString(OvaViewer.Name(OvaWindow.viewer), name)
END ViewerIs;

PROCEDURE Title(VAR s: ARRAY OF CHAR);
BEGIN OvaWindow.window.GetLabel(s)
END Title;

PROCEDURE Modified(): BOOLEAN;
  VAR s: ARRAY 128 OF CHAR;
BEGIN Title(s); RETURN Ropes.Find(R(s), " *", 0) >= 0
END Modified;

PROCEDURE Warned(text: ARRAY OF CHAR): BOOLEAN;
  VAR i: INTEGER; line: ARRAY 256 OF CHAR; found: BOOLEAN;
BEGIN
  found := FALSE;
  FOR i := 1 TO OvaWindow.warnings.Count() DO
    OvaWindow.warnings.GetText(i, line);
    IF Ropes.Find(R(line), text, 0) >= 0 THEN found := TRUE END
  END;
  RETURN found
END Warned;

PROCEDURE OpenPrefs;
BEGIN NEW(prefs); FlPreferences.OpenFile(prefs, PrefsDir, Vendor, Application)
END OpenPrefs;

PROCEDURE Kept(name: ARRAY OF CHAR; VAR s: ARRAY OF CHAR);
BEGIN prefs.GetText(name, "", s)
END Kept;

BEGIN
  tells := 0; pdfAsks := 0; pdfAnswer := NIL; textAnswer := NIL;
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaWindow.ask := Ask; OvaWindow.choosePdf := ChoosePdf; OvaWindow.askText := AskText;
  OvaWindow.window.Show; OvaWindow.window.WaitForExpose; IF Fl.Check() THEN END;
  OvaWindow.bar.ItemLabel(OvaWindow.limitsItem, s);
  Check.Check(s = "&Limits...", "Character > Limits...");

  (* ---- Limits... ---- *)
  Fresh;
  Check.Check((OvaSettings.dialog # NIL) & ~OvaSettings.baseZero.Value() & ~OvaSettings.powerCeiling.Value()
    & ~OvaSettings.startingLevels.Value() & ~OvaSettings.scaledCost.Value() & ~OvaSettings.halfCost.Value()
    & ~OvaSettings.combined.Value(), "a new character: no limits");
  Check.Check((Value(OvaSettings.baseZeroRange) = 5) & (Value(OvaSettings.starting) = 5)
    & (Value(OvaSettings.ceiling) = 15) & ~OvaSettings.baseZeroRange.Active() & ~OvaSettings.ceiling.Active()
    & ~OvaSettings.starting.Active() & ~OvaSettings.halfCost.Active(),
    "their numbers p. 21's example, inactive; half cost inactive with none of its rules");
  Check.Check((c.total.value = 3) & RedsAre("----") & ~Modified(), "Attack +3: a total of 3, nothing red");

  Turn(OvaSettings.baseZero, TRUE);
  Check.Check(c.options.baseZero & (c.options.baseZeroRange = 5) & c.hasOptions & OvaSettings.baseZeroRange.Active()
    & OvaSettings.halfCost.Active() & Modified() & Has(Saved(), "base-zero: 5") & RedsAre("----"),
    "Base Zero on: its range 5, saved, the title marked; 3 within it");
  Spin(OvaSettings.baseZeroRange, 2);
  Check.Check((c.options.baseZeroRange = 2) & RedsAre("-T--") & Warned("Base Zero") & Has(Saved(), "base-zero: 2"),
    "range 2: the Total red, and the warning");
  Spin(OvaSettings.baseZeroRange, 3);
  Check.Check(RedsAre("----") & ~Warned("Base Zero"), "range 3: not red");
  Turn(OvaSettings.scaledCost, TRUE);
  Check.Check(c.options.scaledCost & (c.points.value = 4) & OvaWindow.numbers[9].Visible() & RedsAre("--P-")
    & Has(Saved(), "scaled-cost: true"), "Scaled Cost: 4 points, shown, beyond 3: the points red, not the Total");
  Check.Check((c.abilityPoints.value = 4) & OvaWindow.numbers[11].Visible(), "and the Abilities' 4 points shown");
  Turn(OvaSettings.powerCeiling, TRUE); Spin(OvaSettings.ceiling, 3);
  Check.Check(RedsAre("--Pa") & Warned("Power Ceiling"),
    "Power Ceiling 3 on Scaled Cost: the Abilities' points red, not their levels");
  Spin(OvaSettings.ceiling, 15); Turn(OvaSettings.powerCeiling, FALSE);
  Turn(OvaSettings.scaledCost, FALSE); Turn(OvaSettings.baseZero, FALSE);
  Check.Check(~c.options.baseZero & ~OvaSettings.baseZeroRange.Active() & ~OvaSettings.halfCost.Active()
    & (Value(OvaSettings.baseZeroRange) = 3) & RedsAre("----") & ~Has(Saved(), "base-zero"),
    "Base Zero off: its number kept, inactive, not saved");

  Turn(OvaSettings.powerCeiling, TRUE);
  Check.Check(c.options.powerCeiling & (c.options.ceiling = 15) & RedsAre("----") & Has(Saved(), "power-ceiling: 15"),
    "Power Ceiling 15: 3 under it");
  Spin(OvaSettings.ceiling, 2);
  Check.Check(RedsAre("A---") & Warned("Power Ceiling"), "Power Ceiling 2: the Abilities red, and the warning");
  Turn(OvaSettings.powerCeiling, FALSE);
  Turn(OvaSettings.startingLevels, TRUE);
  Check.Check(c.options.startingLevels & (c.options.starting = 5) & RedsAre("----") & Has(Saved(), "starting-levels: 5"),
    "5 starting levels: 3 within them");
  Spin(OvaSettings.starting, 2);
  Check.Check(RedsAre("A---") & Warned("starting levels"), "2 starting levels: the Abilities red");
  Turn(OvaSettings.startingLevels, FALSE);

  AddAbility("Knowledge", 3);
  Turn(OvaSettings.powerCeiling, TRUE); Turn(OvaSettings.halfCost, TRUE);
  Check.Check(c.options.halfCostKnowledge & (c.abilityLevels.value = 5) & Has(Saved(), "half-cost-knowledge: true"),
    "half cost: Knowledge +3 counts 2 (p. 57)");
  Turn(OvaSettings.powerCeiling, FALSE);
  Check.Check(c.options.halfCostKnowledge & ~OvaSettings.halfCost.Active() & (c.abilityLevels.value = 6),
    "with none of its rules: kept, inactive, and Knowledge counts 3");
  Turn(OvaSettings.combined, TRUE);
  Check.Check(c.options.combinedEffectiveness & Has(Saved(), "combined-effectiveness: true"),
    "Combined Effectiveness on, saved");

  OvaSettings.cancel.DoCallback;
  Check.Check((OvaSettings.dialog = NIL) & ~c.hasOptions & ~c.options.halfCostKnowledge
    & ~c.options.combinedEffectiveness & ~c.options.powerCeiling & ~Has(Saved(), "options:") & RedsAre("----")
    & (c.abilityLevels.value = 6) & ~Modified(), "Cancel: no limits again, nothing saved, the title unmarked");

  Fresh;
  Turn(OvaSettings.baseZero, TRUE); Spin(OvaSettings.baseZeroRange, 1);
  OvaSettings.ok.DoCallback;
  Check.Check((OvaSettings.dialog = NIL) & c.options.baseZero & Has(Saved(), "base-zero: 1") & Modified()
    & RedsAre("-T--"), "OK: kept, saved, the title marked, the Total red");
  OvaWindow.bar.Pick(OvaWindow.limitsItem);
  Check.Check(OvaSettings.baseZero.Value() & (Value(OvaSettings.baseZeroRange) = 1) & OvaSettings.baseZeroRange.Active(),
    "opened again: as left");
  Turn(OvaSettings.baseZero, FALSE);
  OvaSettings.dialog.DoCallback;  (* the window's close button *)
  Check.Check((OvaSettings.dialog = NIL) & c.options.baseZero & RedsAre("-T--") & Modified(),
    "closed by its close button: as Cancel, the title still marked from before");

  OvaWindow.bar.Pick(OvaWindow.newItem); c := OvaWindow.character;
  c.hasOptions := TRUE;  (* as a file with an empty options: block loads *)
  OvaWindow.bar.Pick(OvaWindow.limitsItem);
  Turn(OvaSettings.baseZero, TRUE); Turn(OvaSettings.baseZero, FALSE);
  Check.Check(c.hasOptions & Has(Saved(), "options:"), "an empty options: block, changed and changed back: kept");
  Turn(OvaSettings.combined, TRUE); Turn(OvaSettings.combined, FALSE); Turn(OvaSettings.baseZero, TRUE);
  OvaSettings.ok.DoCallback;
  ok := OvaWindow.Load(R("data/Sheet.yaml"));
  OvaWindow.bar.Pick(OvaWindow.limitsItem);
  Check.Check(ok & ~OvaSettings.baseZero.Value() & OvaSettings.powerCeiling.Value() & (Value(OvaSettings.ceiling) = 30)
    & OvaSettings.startingLevels.Value() & (Value(OvaSettings.starting) = 20) & OvaSettings.halfCost.Value()
    & OvaSettings.halfCost.Active() & ~OvaSettings.scaledCost.Value(), "Sheet's: Power Ceiling 30, 20 starting levels, half cost");
  OvaSettings.Cancel;

  (* ---- The rulebook and the viewer, kept ---- *)
  OpenPrefs; prefs.Clear;
  OvaWindow.UsePreferences(prefs);
  Check.Check(OvaWindow.savedRulebook = NIL, "no rulebook kept");
  pdfAnswer := R("data/Sheet.yaml");  (* any file stands for the PDF *)
  OvaWindow.bar.Pick(OvaWindow.choosePdfItem);
  Kept("rulebook", s);
  Check.Check((pdfAsks = 1) & Ropes.Equal(OvaWindow.rulebookOption, OvaWindow.savedRulebook)
    & Has(R(s), "/test/data/Sheet.yaml") & (s[0] = "/"), "Choose PDF...: used from now on, and kept, absolute");

  textAnswer := R("evince");
  OvaWindow.bar.Pick(OvaWindow.viewerItem);
  Kept("viewer", s);
  Check.Check(ViewerIs("evince") & (s = "evince"), "Viewer...: evince, kept");
  textAnswer := R("cat %f");
  OvaWindow.bar.Pick(OvaWindow.viewerItem);
  Kept("viewer", s);
  Check.Check(ViewerIs("cat %f") & (s = "cat %f"), "a command, kept");
  tells := 0; textAnswer := R("nonsense");
  OvaWindow.bar.Pick(OvaWindow.viewerItem);
  Kept("viewer", s);
  Check.Check(ViewerIs("cat %f") & (s = "cat %f") & (tells = 1), "not a viewer: said so, nothing changed");
  textAnswer := NIL;
  OvaWindow.bar.Pick(OvaWindow.viewerItem);
  Check.Check(ViewerIs("cat %f"), "cancelled: nothing changed");

  prefs.Close; OpenPrefs;
  OvaViewer.Default(OvaWindow.viewer); OvaWindow.rulebookOption := NIL;
  OvaWindow.UsePreferences(prefs);
  Check.Check(ViewerIs("cat %f") & Has(OvaWindow.savedRulebook, "/test/data/Sheet.yaml"),
    "read back on the next run: the viewer and the rulebook");
  OvaViewer.Default(OvaWindow.viewer); OvaWindow.viewerOption := TRUE;
  OvaWindow.UsePreferences(prefs);
  Check.Check(~ViewerIs("cat %f"), "--viewer's wins over the one kept");
  OvaWindow.viewerOption := FALSE;
  prefs.SetText("viewer", "nonsense");
  ok := OvaViewer.Parse(R("mupdf"), OvaWindow.viewer);
  OvaWindow.UsePreferences(prefs);
  Check.Check(ViewerIs("mupdf"), "a viewer kept that isn't one: ignored");

  (* Not found: asked for once, then opened with it. *)
  ok := OvaViewer.Parse(R("true %f %p"), OvaWindow.viewer);
  OvaWindow.rulebookOption := R("no/such/rulebook.pdf");
  pdfAsks := 0; tells := 0; pdfAnswer := NIL;
  OvaWindow.bar.Pick(OvaWindow.rulebookItem);
  Check.Check((pdfAsks = 1) & (tells = 1), "the rulebook not found: asked for, and cancelled, said where it isn't");
  pdfAnswer := R("data/Sheet.yaml"); tells := 0;
  OvaWindow.bar.Pick(OvaWindow.rulebookItem);
  Kept("rulebook", s);
  Check.Check((pdfAsks = 2) & (tells = 0) & Has(OvaWindow.rulebookOption, "/test/data/Sheet.yaml")
    & Has(R(s), "/test/data/Sheet.yaml"), "chosen: opened, and kept");
  OvaWindow.bar.Pick(OvaWindow.rulebookItem);
  Check.Check(pdfAsks = 2, "found the next time: not asked again");

  prefs.Close;
  OvaWindow.UsePreferences(NIL);
  OvaWindow.Close;
  Check.Check((Fl.OpenWidgets() = 0) & (FlPreferences.openDatabases = 0), "every widget and database closed");
  Check.Summary
END TestLimits.
