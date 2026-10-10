MODULE OvaBackground; (* The window's second tab: the sheet's left half, the fluff, and the notes *)

(* PLAN.md, "The window", the second tab: the Summary; Background,
   Appearance, Personality and Other Notes, each an FlText editor; the
   Character Portrait, an image file whose path is saved relative to
   the YAML file; the fluff fields (p. 20) in a grid; and the headed
   notes ova_fmt prints as callouts (`notes:`), so everything a file
   holds can be edited.

   OvaWindow owns the character and the file: it builds this tab inside
   its Tabs (Build), shows a character here (Show), and is told of each
   change (changed). What would wait for the user -- a message, the
   image chooser -- goes through procedure variables a test sets, as
   OvaWindow's do. Every change goes into the character at once, as
   the user types; nothing here holds the only copy. *)

IMPORT Fl, FlBrowsers, FlButtons, FlDialogs, FlImages, FlInputs, FlLayout, FlText, OvaCharacter, OvaEntities, OvaPaths,
  OvaText, Ropes;

CONST
  Row = 25;
  LeftX = 10; RightX = 650; ColumnW = 620;
  (* The prose sections, ProseBuffer.which. *)
  Background* = 0; Appearance* = 1; Personality* = 2; OtherNotes* = 3;
  NProse = 4;
  PortraitW = 200; PortraitH = 250;
  FluffRows = 7;
  NFluff = OvaCharacter.NFluff;

TYPE
  Rope = Ropes.Rope;

  (* A prose section's text: each change goes to the character. *)
  ProseBuffer = POINTER TO RECORD (FlText.TextBufferDesc) which: INTEGER END;

VAR
  character: OvaCharacter.Character;
  fileDir: Rope;      (* the YAML file's directory, absolute; NIL: never saved *)
  filling: BOOLEAN;   (* the widgets being set from the character: no change to report *)

  summaryIn-: FlInputs.Input;
  prose-: ARRAY NProse OF FlText.TextEditor;
  buffers: ARRAY NProse OF ProseBuffer;
  portrait-: Fl.Box;                  (* shows the image, or why it can't *)
  portraitPath-: FlInputs.Output;     (* the path as saved *)
  choosePortrait-, removePortrait-: FlButtons.Button;
  image-: FlImages.Image;             (* the portrait shown; NIL: none *)
  fluffGrid-: FlLayout.Grid;
  fluffIn-: ARRAY NFluff OF FlInputs.Input;
  notes-: FlBrowsers.HoldBrowser;     (* the notes' headers, in order *)
  noteHeader-: FlInputs.Input;
  noteText-: FlInputs.MultilineInput;
  addNote-, changeNote-, removeNote-: FlButtons.Button;

  (* Set by the window: called after every change the user makes here. *)
  changed*: PROCEDURE;
  (* What would wait for the user: tell shows a message; chooseImage asks
     for an image file, FALSE if cancelled. *)
  tell*: PROCEDURE (text: Rope);
  chooseImage*: PROCEDURE (VAR path: Rope): BOOLEAN;

(* ---- Text ---- *)

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

(* What input i holds, trimmed; NIL if blank. *)
PROCEDURE InputText(i: FlInputs.Input): Rope;
  VAR s: OvaText.String;
BEGIN
  NEW(s, i.Length() + 1); i.Value(s^);
  RETURN OvaText.Trim(Ropes.FromString(s^))
END InputText;

PROCEDURE SetInput(i: FlInputs.Input; r: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(r); i.SetValue(s^)
END SetInput;

PROCEDURE Changed;
BEGIN IF changed # NIL THEN changed END
END Changed;

(* ---- The prose sections ---- *)

PROCEDURE ProseOf(which: INTEGER; VAR has: BOOLEAN; VAR r: Rope);
  VAR c: OvaCharacter.Character;
BEGIN
  c := character;
  CASE which OF
    Background: has := c.hasBackground; r := c.background
  | Appearance: has := c.hasAppearance; r := c.appearance
  | Personality: has := c.hasPersonality; r := c.personality
  | OtherNotes: has := c.hasOtherNotes; r := c.otherNotes
  END
END ProseOf;

(* Section which's text, trimmed as the loader trims it, so what is saved
   loads the same; blank is absent. *)
PROCEDURE (b: ProseBuffer) Modified*(pos, inserted, deleted, restyled: INTEGER);
  VAR s: OvaText.String; r: Rope; c: OvaCharacter.Character;
BEGIN
  IF filling OR (character = NIL) OR (inserted = 0) & (deleted = 0) THEN RETURN END;
  NEW(s, b.Length() + 1); b.GetText(s^);
  r := OvaText.Trim(Ropes.FromString(s^));
  c := character;
  CASE b.which OF
    Background: OvaCharacter.SetText(c.hasBackground, c.background, r)
  | Appearance: OvaCharacter.SetText(c.hasAppearance, c.appearance, r)
  | Personality: OvaCharacter.SetText(c.hasPersonality, c.personality, r)
  | OtherNotes: OvaCharacter.SetText(c.hasOtherNotes, c.otherNotes, r)
  END;
  Changed
END Modified;

(* ---- The portrait ---- *)

(* Shows the character's portrait, or says why it can't. *)
PROCEDURE ShowPortrait;
  VAR abs: Rope; s: OvaText.String; img: FlImages.Image;
BEGIN
  SetInput(portraitPath, character.portrait);
  img := NIL;
  IF character.hasPortrait THEN
    abs := OvaPaths.Absolute(character.portrait, fileDir);
    s := OvaText.Chars(abs);
    NEW(img);
    IF FlImages.Load(img, s^) THEN
      img.Scale(PortraitW - 6, PortraitH - 6, TRUE, FALSE);
      portrait.SetLabel("")
    ELSE
      img := NIL; portrait.SetLabel("The image can't be read.")
    END
  ELSE
    portrait.SetLabel("No portrait.")
  END;
  FlImages.SetImage(portrait, img);  (* the box keeps its own hold *)
  IF image # NIL THEN image.Close END;
  image := img;
  IF character.hasPortrait THEN removePortrait.Activate ELSE removePortrait.Deactivate END;
  portrait.Redraw
END ShowPortrait;

PROCEDURE ChoosePortraitAction(w: Fl.Widget);
  VAR p: Rope; c: OvaCharacter.Character;
BEGIN
  IF chooseImage(p) THEN
    c := character;
    (* Relative to the file once there is one; until then absolute, for
       the first save to make relative (OvaPaths.Rebase). *)
    IF fileDir # NIL THEN p := OvaPaths.Relative(p, fileDir) ELSE p := OvaPaths.Absolute(p, NIL) END;
    OvaCharacter.SetText(c.hasPortrait, c.portrait, p);
    ShowPortrait;
    Changed
  END
END ChoosePortraitAction;

PROCEDURE RemovePortraitAction(w: Fl.Widget);
BEGIN
  OvaCharacter.SetText(character.hasPortrait, character.portrait, NIL);
  ShowPortrait;
  Changed
END RemovePortraitAction;

PROCEDURE DialogImage(VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; name: ARRAY 4096 OF CHAR; filter: ARRAY 64 OF CHAR; ok: BOOLEAN;
BEGIN
  NEW(c); FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseFile);
  c.SetTitle("Choose the character's portrait");
  filter := "Images *.{png,jpg,jpeg,gif,bmp,svg}"; filter[6] := 9X;  (* FLTK's "name<tab>pattern" *)
  c.SetFilter(filter);
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN c.FileName(0, name); p := Ropes.FromString(name); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogImage;

PROCEDURE DialogTell(text: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(text); FlDialogs.Message(s^)
END DialogTell;

(* ---- The summary and the fluff ---- *)

PROCEDURE TextAction(w: Fl.Widget);
  VAR i: INTEGER; c: OvaCharacter.Character;
BEGIN
  IF filling THEN RETURN END;
  c := character;
  IF w = summaryIn THEN OvaCharacter.SetText(c.hasSummary, c.summary, InputText(summaryIn))
  ELSE
    i := 0; WHILE (i < NFluff) & (w # fluffIn[i]) DO INC(i) END;
    IF i = NFluff THEN RETURN END;
    OvaCharacter.SetText(c.hasFluffField[i], c.fluff[i], InputText(fluffIn[i]));
    (* The fluff: block is written while any field has text. *)
    c.hasFluff := FALSE;
    FOR i := 0 TO NFluff - 1 DO c.hasFluff := c.hasFluff OR c.hasFluffField[i] END
  END;
  Changed
END TextAction;

(* ---- The notes ---- *)

(* The note on browser line line (from 1). *)
PROCEDURE NoteAt(line: INTEGER): OvaCharacter.Note;
  VAR n: OvaCharacter.Note;
BEGIN
  n := character.notes;
  WHILE (n # NIL) & (line > 1) DO n := n.next; DEC(line) END;
  RETURN n
END NoteAt;

(* The notes' headers listed again, line line selected (0: none). *)
PROCEDURE ShowNotes(line: INTEGER);
  VAR n: OvaCharacter.Note; s: OvaText.String;
BEGIN
  notes.Clear;
  n := character.notes;
  WHILE n # NIL DO s := OvaText.Chars(n.header); notes.Add(s^); n := n.next END;
  IF (line > 0) & (line <= notes.Count()) THEN
    IF notes.Select(line, TRUE) THEN END;
    n := NoteAt(line); SetInput(noteHeader, n.header); SetInput(noteText, n.text)
  ELSE
    noteHeader.SetValue(""); noteText.SetValue("")
  END
END ShowNotes;

PROCEDURE NotesAction(w: Fl.Widget);
  VAR n: OvaCharacter.Note;
BEGIN
  n := NoteAt(notes.Value());
  IF (notes.Value() > 0) & (n # NIL) THEN SetInput(noteHeader, n.header); SetInput(noteText, n.text) END
END NotesAction;

(* The header and text typed; FALSE, said why, if either is blank: the
   loader requires both. *)
PROCEDURE NoteRead(VAR header, text: Rope): BOOLEAN;
BEGIN
  header := InputText(noteHeader); text := InputText(noteText);
  IF (header = NIL) OR (text = NIL) THEN tell(R("A note needs a header and some text.")); RETURN FALSE END;
  RETURN TRUE
END NoteRead;

(* Add puts the note last; Change and Remove need a line selected. *)
PROCEDURE NoteButtonAction(w: Fl.Widget);
  VAR line, i: INTEGER; header, text: Rope; n, last: OvaCharacter.Note;
BEGIN
  line := notes.Value();
  IF w = addNote THEN
    IF ~NoteRead(header, text) THEN RETURN END;
    NEW(n); n.header := header; n.text := text; n.next := NIL;
    IF character.notes = NIL THEN character.notes := n; line := 1
    ELSE
      last := character.notes; i := 2;
      WHILE last.next # NIL DO last := last.next; INC(i) END;
      last.next := n; line := i
    END
  ELSIF line = 0 THEN RETURN
  ELSIF w = changeNote THEN
    IF ~NoteRead(header, text) THEN RETURN END;
    n := NoteAt(line); n.header := header; n.text := text
  ELSE
    n := NoteAt(line);
    IF line = 1 THEN character.notes := n.next
    ELSE last := NoteAt(line - 1); last.next := n.next
    END;
    line := 0
  END;
  ShowNotes(line);
  Changed
END NoteButtonAction;

(* ---- Showing a character ---- *)

(* Shows c, whose file is in directory dir (NIL: none). *)
PROCEDURE Show*(c: OvaCharacter.Character; dir: Rope);
  VAR i: INTEGER; has: BOOLEAN; r: Rope; s: OvaText.String;
BEGIN
  character := c; fileDir := dir;
  filling := TRUE;
  SetInput(summaryIn, c.summary);
  FOR i := 0 TO NProse - 1 DO
    ProseOf(i, has, r); s := OvaText.Chars(r); buffers[i].SetText(s^)
  END;
  FOR i := 0 TO NFluff - 1 DO SetInput(fluffIn[i], c.fluff[i]) END;
  ShowNotes(0);
  ShowPortrait;
  filling := FALSE
END Show;

(* The file is now in directory dir: a portrait path is shown from it.
   The window has rebased the path already (OvaPaths.Rebase). *)
PROCEDURE SetDir*(dir: Rope);
BEGIN fileDir := dir; ShowPortrait
END SetDir;

(* ---- Building ---- *)

PROCEDURE Heading(x, y, w: INTEGER; text: ARRAY OF CHAR);
  VAR b: Fl.Box;
BEGIN
  NEW(b); Fl.OpenBox(b, x, y, w, 20, text);
  b.SetAlign(Fl.AlignLeft + Fl.AlignInside); b.SetLabelFont(Fl.Bold)
END Heading;

PROCEDURE ProseEditor(which, y, h: INTEGER; title: ARRAY OF CHAR);
  VAR e: FlText.TextEditor; b: ProseBuffer;
BEGIN
  Heading(LeftX, y, ColumnW, title);
  NEW(b); FlText.OpenBuffer(b); b.which := which;
  NEW(e); FlText.OpenTextEditor(e, LeftX, y + 20, ColumnW, h, "");
  e.SetBuffer(b); e.SetWrapMode(FlText.WrapAtBounds, 0);
  prose[which] := e; buffers[which] := b
END ProseEditor;

PROCEDURE FluffField(i, row, col: INTEGER; label: ARRAY OF CHAR);
  VAR b: Fl.Box; in: FlInputs.Input;
BEGIN
  NEW(b); Fl.OpenBox(b, 0, 0, 0, 0, label); b.SetAlign(Fl.AlignRight + Fl.AlignInside);
  fluffGrid.Place(b, row, 2 * col, FlLayout.GridFill);
  NEW(in); FlInputs.OpenInput(in, 0, 0, 0, 0, "");
  in.SetWhen(Fl.WhenChanged); in.action := TextAction;
  fluffGrid.Place(in, row, 2 * col + 1, FlLayout.GridFill);
  fluffIn[i] := in
END FluffField;

(* Opens the tab as a child of the group being built, at x, y, w by h,
   labelled "Background". *)
PROCEDURE Build*(tab: Fl.Group; x, y, w, h: INTEGER);
  CONST Top = 10;
  VAR yy, ph, i: INTEGER; b: FlButtons.Button;
BEGIN
  Fl.OpenGroup(tab, x, y, w, h, "Background");
  (* The left column: the summary and the four prose sections. *)
  yy := y + Top;
  NEW(summaryIn); FlInputs.OpenInput(summaryIn, LeftX + 80, yy, ColumnW - 80, Row, "Summary");
  summaryIn.SetWhen(Fl.WhenChanged); summaryIn.action := TextAction;
  yy := yy + Row + 10;
  ph := (y + h - 10 - yy) DIV NProse - 25;
  ProseEditor(Background, yy, ph, "Background"); yy := yy + ph + 25;
  ProseEditor(Appearance, yy, ph, "Appearance"); yy := yy + ph + 25;
  ProseEditor(Personality, yy, ph, "Personality"); yy := yy + ph + 25;
  ProseEditor(OtherNotes, yy, ph, "Other Notes");

  (* The right column: the portrait, the fluff, the notes. *)
  yy := y + Top;
  Heading(RightX, yy, PortraitW, "Character Portrait");
  NEW(portrait); Fl.OpenBox(portrait, RightX, yy + 20, PortraitW, PortraitH, "");
  portrait.SetBoxType(Fl.DownFrame); portrait.SetAlign(Fl.AlignInside + Fl.AlignWrap);
  NEW(portraitPath); FlInputs.OpenOutput(portraitPath, RightX + PortraitW + 10, yy + 40, ColumnW - PortraitW - 10, Row,
    "Image file, relative to the character's");
  portraitPath.SetAlign(Fl.AlignTopLeft);
  NEW(b); FlButtons.OpenButton(b, RightX + PortraitW + 10, yy + 75, 100, Row, "Choose...");
  b.action := ChoosePortraitAction; choosePortrait := b;
  NEW(b); FlButtons.OpenButton(b, RightX + PortraitW + 115, yy + 75, 80, Row, "Remove");
  b.action := RemovePortraitAction; removePortrait := b;

  yy := yy + 20 + PortraitH + 10;
  NEW(fluffGrid); FlLayout.OpenGrid(fluffGrid, RightX, yy, ColumnW, FluffRows * (Row + 5), "");
  fluffGrid.SetLayout(FluffRows, 4); fluffGrid.SetGap(5, 5);
  fluffGrid.SetColWeight(0, 0); fluffGrid.SetColWidth(0, 100);
  fluffGrid.SetColWeight(2, 0); fluffGrid.SetColWidth(2, 100);
  FluffField(OvaEntities.Concept, 0, 0, "Concept"); FluffField(OvaEntities.Birthday, 0, 1, "Birthday");
  FluffField(OvaEntities.Age, 1, 0, "Age"); FluffField(OvaEntities.Gender, 1, 1, "Gender");
  FluffField(OvaEntities.Height, 2, 0, "Height"); FluffField(OvaEntities.Weight, 2, 1, "Weight");
  FluffField(OvaEntities.Hair, 3, 0, "Hair"); FluffField(OvaEntities.Eyes, 3, 1, "Eyes");
  FluffField(OvaEntities.Association, 4, 0, "Association"); FluffField(OvaEntities.Hobbies, 4, 1, "Hobbies");
  FluffField(OvaEntities.FavoriteFood, 5, 0, "Favorite Food"); FluffField(OvaEntities.Allies, 5, 1, "Allies");
  FluffField(OvaEntities.Enemies, 6, 0, "Enemies"); FluffField(OvaEntities.LoveInterests, 6, 1, "Love Interests");
  fluffGrid.End;
  FOR i := 0 TO NFluff - 1 DO ASSERT(fluffIn[i] # NIL) END;

  yy := yy + FluffRows * (Row + 5) + 10;
  Heading(RightX, yy, ColumnW, "Notes");
  NEW(notes); FlBrowsers.OpenHoldBrowser(notes, RightX, yy + 20, 200, y + h - 10 - Row - 5 - yy - 20, "");
  notes.SetFormatChar(0X); notes.action := NotesAction;
  NEW(noteHeader); FlInputs.OpenInput(noteHeader, RightX + 270, yy + 20, ColumnW - 270, Row, "Header");
  NEW(noteText); FlInputs.OpenMultilineInput(noteText, RightX + 270, yy + 50, ColumnW - 270,
    y + h - 10 - (yy + 50), "Text");
  noteText.SetWrap(TRUE); noteText.SetAlign(Fl.AlignLeft + Fl.AlignTop);
  yy := y + h - 10 - Row;
  NEW(b); FlButtons.OpenButton(b, RightX, yy, 65, Row, "Add"); b.action := NoteButtonAction; addNote := b;
  NEW(b); FlButtons.OpenButton(b, RightX + 68, yy, 65, Row, "Change"); b.action := NoteButtonAction; changeNote := b;
  NEW(b); FlButtons.OpenButton(b, RightX + 136, yy, 65, Row, "Remove"); b.action := NoteButtonAction; removeNote := b;
  tab.End
END Build;

(* Gives up the buffers and the image, after the window is deleted. *)
PROCEDURE Close*;
  VAR i: INTEGER;
BEGIN
  FOR i := 0 TO NProse - 1 DO
    IF buffers[i] # NIL THEN buffers[i].Close END;
    buffers[i] := NIL; prose[i] := NIL
  END;
  FOR i := 0 TO NFluff - 1 DO fluffIn[i] := NIL END;
  IF image # NIL THEN image.Close END;
  image := NIL; character := NIL;
  summaryIn := NIL; portrait := NIL; portraitPath := NIL; choosePortrait := NIL; removePortrait := NIL;
  fluffGrid := NIL; notes := NIL; noteHeader := NIL; noteText := NIL;
  addNote := NIL; changeNote := NIL; removeNote := NIL
END Close;

BEGIN
  character := NIL; fileDir := NIL; filling := FALSE; image := NIL;
  changed := NIL; tell := DialogTell; chooseImage := DialogImage
END OvaBackground.
