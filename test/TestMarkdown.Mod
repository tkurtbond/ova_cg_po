MODULE TestMarkdown; (* OvaMarkdownTab: the character's Markdown sheet, kept current, copied and saved *)

(* Needs a display: run by make test-gui, as TestWindow is. The tab
   shows OvaMarkdown's sheet of the character shown, after every kind of
   change (a name typed, an Ability added, Background text typed, a
   file opened); Copy puts it on the clipboard, read back by pasting it
   into an input of this test's own; Save Markdown... writes it where
   the chooser says, suggesting the character's name, and says why when
   it can't. Inline, checked, shows the inline paragraph instead, kept
   current the same way, and Save Markdown... takes it. That the sheet
   is ova_fmt_po -M's, and the paragraph -i's, is test/files.sh's. *)

IMPORT Check, Fl, FlInputs, FlText, OvaBackground, OvaMarkdown, OvaMarkdownTab, OvaRules, OvaText, OvaWidgets,
  OvaWindow, Out, Platform, Ropes;

CONST
  SavePath = "../obj/files/markdown-tab.md";
  BadPath = "../obj/no/such/dir/markdown-tab.md";

TYPE Rope = Ropes.Rope;

VAR
  tells, asks: INTEGER;
  chosen, suggested, back: Rope;
  win: Fl.Window;
  in: FlInputs.MultilineInput;
  buf: FlText.TextBuffer;
  s: Fl.String;
  path: ARRAY 64 OF CHAR;
  ok: BOOLEAN;

(* ---- What would wait for the user ---- *)

PROCEDURE Tell(text: Rope);
  VAR s: OvaText.String;
BEGIN INC(tells); s := OvaText.Chars(text); Out.String("    told: "); Out.String(s^); Out.Ln
END Tell;

PROCEDURE Ask(question: Rope): INTEGER;
BEGIN RETURN OvaWindow.Discard
END Ask;

PROCEDURE ChoosePath(suggest: Rope; VAR p: Rope): BOOLEAN;
BEGIN INC(asks); suggested := suggest; p := chosen; RETURN p # NIL
END ChoosePath;

(* ---- Looking ---- *)

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE Has(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.Find(r, s, 0) >= 0
END Has;

(* Whether the tab shows the sheet of the character shown, or its
   inline paragraph if Inline is checked, as OvaMarkdown makes it, in
   its display. *)
PROCEDURE Shown(): BOOLEAN;
  VAR b: FlText.TextBuffer; t: Fl.String; want: Rope;
BEGIN
  IF OvaMarkdownTab.inline.Value() THEN want := OvaMarkdown.Inline(OvaWindow.character)
  ELSE want := OvaMarkdown.Sheet(OvaWindow.character)
  END;
  b := OvaMarkdownTab.display.Buffer(); t := b.Text();
  RETURN (want # NIL) & Ropes.Equal(OvaMarkdownTab.sheet, want) & Ropes.EqualString(want, t^)
END Shown;

(* ---- Doing ---- *)

PROCEDURE Pick(p: OvaWidgets.Panel; name: ARRAY OF CHAR);
  VAR it: OvaRules.Item; i: INTEGER;
BEGIN
  it := OvaRules.Find(name); ASSERT(it # NIL);
  i := 0; WHILE OvaRules.Get(p.kind, i) # it DO INC(i) END;
  p.choice.Choose(i);
  p.choice.DoCallback
END Pick;

PROCEDURE AddAbility(name: ARRAY OF CHAR; level: INTEGER);
BEGIN
  Pick(OvaWindow.abilities, name); OvaWindow.abilities.spinner.SetValue(level);
  OvaWindow.abilities.text.SetValue(""); OvaWindow.abilities.add.DoCallback
END AddAbility;

(* Checks or unchecks Inline, as a click does. *)
PROCEDURE SetInline(on: BOOLEAN);
BEGIN OvaMarkdownTab.inline.SetValue(on); OvaMarkdownTab.inline.DoCallback
END SetInline;

(* Deletes the file at p, if there is one. *)
PROCEDURE Remove(p: ARRAY OF CHAR);
BEGIN COPY(p, path); IF Platform.Unlink(path) = 0 THEN END
END Remove;

BEGIN
  tells := 0; asks := 0; chosen := NIL; suggested := NIL;
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaWindow.ask := Ask;
  OvaMarkdownTab.tell := Tell; OvaMarkdownTab.choosePath := ChoosePath;
  OvaWindow.tabs.SetValue(OvaWindow.markdownTab);
  OvaWindow.markdownTab.GetLabel(path);
  Check.Check((path = "Markdown") & OvaMarkdownTab.display.Visible(), "the Markdown tab");
  Check.Check(Shown(), "a new character's sheet");

  (* ---- Kept current ---- *)
  OvaWindow.nameIn.SetValue("Kiri"); OvaWindow.nameIn.DoCallback;
  Check.Check(Shown() & Has(OvaMarkdownTab.sheet, "# Kiri"), "a name typed: the sheet's title");
  AddAbility("Attack", 3);
  Check.Check(Shown() & Has(OvaMarkdownTab.sheet, "Attack +3"), "an Ability added: listed");
  buf := OvaBackground.prose[OvaBackground.Background].Buffer(); buf.Append("Kiri grew up by the sea.");
  Check.Check(Shown() & Has(OvaMarkdownTab.sheet, "Kiri grew up by the sea."), "Background typed: in the sheet");
  ok := OvaWindow.Load(R("data/Ai.yaml"));
  Check.Check(ok & ~OvaWindow.modified & Shown() & Has(OvaMarkdownTab.sheet, "# Ai (Amnesiatic ESPer)"),
    "a file opened: its character's sheet");

  (* ---- Copy ---- *)
  OvaMarkdownTab.copy.DoCallback;
  NEW(win); Fl.OpenWindow(win, 100, 100, "TestMarkdown");
  NEW(in); FlInputs.OpenMultilineInput(in, 0, 0, 100, 100, "");
  win.End;
  Fl.Paste(in, Fl.Clipboard);
  s := in.Text();
  Check.Check(Ropes.EqualString(OvaMarkdownTab.sheet, s^), "Copy: the whole sheet on the clipboard");
  win.Delete; win := NIL; in := NIL;

  (* ---- Save Markdown... ---- *)
  Remove(SavePath); chosen := R(SavePath);
  OvaMarkdownTab.save.DoCallback;
  Check.Check((asks = 1) & Ropes.EqualString(suggested, "Ai.md"), "Save Markdown...: the character's name suggested");
  Check.Check(Ropes.ReadFile(SavePath, back) & Ropes.Equal(back, OvaMarkdownTab.sheet) & (tells = 0)
    & ~OvaWindow.modified, "the sheet written where chosen, the character not marked changed");
  Remove(SavePath); chosen := NIL;
  OvaMarkdownTab.save.DoCallback;
  Check.Check((asks = 2) & ~Ropes.ReadFile(SavePath, back) & (tells = 0), "cancelled: nothing written, nothing said");
  chosen := R(BadPath);
  OvaMarkdownTab.save.DoCallback;
  Check.Check(tells = 1, "a file that can't be written: said why");
  OvaWindow.bar.Pick(OvaWindow.newItem); chosen := R(SavePath);
  OvaMarkdownTab.save.DoCallback;
  Check.Check((suggested = NIL) & Ropes.ReadFile(SavePath, back) & Ropes.Equal(back, OvaMarkdownTab.sheet),
    "a character with no name: nothing suggested, the sheet saved");

  (* ---- Inline ---- *)
  ok := OvaWindow.Load(R("data/Ai.yaml"));
  Check.Check(ok & ~OvaMarkdownTab.inline.Value() & Shown(), "Inline starts unchecked: the sheet");
  SetInline(TRUE);
  Check.Check(Shown() & Has(OvaMarkdownTab.sheet, "**Ai.** An amnesiac") & ~Has(OvaMarkdownTab.sheet, "# Ai"),
    "Inline checked: the inline paragraph");
  OvaWindow.nameIn.SetValue("Aiko"); OvaWindow.nameIn.DoCallback;
  Check.Check(Shown() & Has(OvaMarkdownTab.sheet, "**Aiko.**"), "Inline: kept current");
  Remove(SavePath); chosen := R(SavePath);
  OvaMarkdownTab.save.DoCallback;
  Check.Check(Ropes.EqualString(suggested, "Aiko-inline.md") & Ropes.ReadFile(SavePath, back)
    & Ropes.Equal(back, OvaMarkdownTab.sheet), "Inline: Save Markdown... suggests NAME-inline.md, saves the paragraph");
  Remove(SavePath);
  SetInline(FALSE);
  Check.Check(Shown() & Has(OvaMarkdownTab.sheet, "# Aiko"), "Inline unchecked: the sheet again");

  OvaWindow.Close;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestMarkdown.
