MODULE TestBackground; (* OvaBackground: the second tab, driven as a user would, and what it saves *)

(* Needs a display: run by make test-gui, as TestWindow is. The text,
   the fluff, the notes and the portrait shown from a character, each
   change made as the user makes it (text typed into an editor's
   buffer, an input's value set and its callback run, a button pushed),
   and checked in the model, in the window's title, and in what is
   saved. The portrait is an image this test writes, saved as a path
   relative to the YAML file, and rebased when Save As moves the file. *)

IMPORT Check, Fl, FlImages, FlInputs, FlText, OvaBackground, OvaCharacter, OvaEntities, OvaPaths, OvaSave,
  OvaText, OvaWindow, Out, Ropes;

CONST
  ImagePath = "../obj/face.png";        (* written here *)
  SavePath = "../obj/files/bg.yaml";    (* beside it, in obj/files *)
  BadPath = "../obj/no/such/dir/bg.yaml";
  ImageW = 40; ImageH = 60;

TYPE Rope = Ropes.Rope;

VAR
  tells: INTEGER;
  chosenImage, chosenPath: Rope;
  c: OvaCharacter.Character;
  buf: FlText.TextBuffer;
  img: FlImages.Image;
  bits: POINTER TO ARRAY OF CHAR;
  text: Rope;
  s: ARRAY 256 OF CHAR;
  i, n: INTEGER;
  ok: BOOLEAN;

(* ---- What would wait for the user ---- *)

PROCEDURE Tell(text: Rope);
  VAR s: OvaText.String;
BEGIN INC(tells); s := OvaText.Chars(text); Out.String("    told: "); Out.String(s^); Out.Ln
END Tell;

PROCEDURE Ask(question: Rope): INTEGER;
BEGIN RETURN OvaWindow.Discard
END Ask;

PROCEDURE ChoosePath(save: BOOLEAN; VAR p: Rope): BOOLEAN;
BEGIN p := chosenPath; RETURN p # NIL
END ChoosePath;

PROCEDURE ChooseImage(VAR p: Rope): BOOLEAN;
BEGIN p := chosenImage; RETURN p # NIL
END ChooseImage;

(* ---- Looking ---- *)

PROCEDURE Saved(): Rope;
BEGIN RETURN OvaSave.ToText(OvaWindow.character)
END Saved;

PROCEDURE Has(r: Rope; s: ARRAY OF CHAR): BOOLEAN;
BEGIN RETURN Ropes.Find(r, s, 0) >= 0
END Has;

(* Whether buffer b's text, trimmed as the tab trims it, is r (blank
   for NIL). *)
PROCEDURE BufferIs(b: FlText.TextBuffer; r: Rope): BOOLEAN;
  VAR s: OvaText.String;
BEGIN NEW(s, b.Length() + 1); b.GetText(s^); RETURN Ropes.Equal(OvaText.Trim(Ropes.FromString(s^)), r)
END BufferIs;

(* Whether input i's text, trimmed as the tab trims it, is r (blank
   for NIL). *)
PROCEDURE InputIs(i: FlInputs.Input; r: Rope): BOOLEAN;
  VAR v: ARRAY 256 OF CHAR;
BEGIN i.Value(v); RETURN Ropes.Equal(OvaText.Trim(Ropes.FromString(v)), r)
END InputIs;

PROCEDURE Prose(which: INTEGER): FlText.TextBuffer;
BEGIN RETURN OvaBackground.prose[which].Buffer()
END Prose;

(* Whether every field of the tab shows the character's text. *)
PROCEDURE AllShown(): BOOLEAN;
  VAR c: OvaCharacter.Character; ok: BOOLEAN; i: INTEGER;
BEGIN
  c := OvaWindow.character;
  ok := InputIs(OvaBackground.summaryIn, c.summary)
    & BufferIs(Prose(OvaBackground.Background), c.background)
    & BufferIs(Prose(OvaBackground.Appearance), c.appearance)
    & BufferIs(Prose(OvaBackground.Personality), c.personality)
    & BufferIs(Prose(OvaBackground.OtherNotes), c.otherNotes)
    & InputIs(OvaBackground.portraitPath, c.portrait);
  FOR i := 0 TO OvaCharacter.NFluff - 1 DO ok := ok & InputIs(OvaBackground.fluffIn[i], c.fluff[i]) END;
  RETURN ok
END AllShown;

(* Whether the notes' browser lists the character's notes' headers. *)
PROCEDURE NotesShown(): BOOLEAN;
  VAR n: OvaCharacter.Note; i: INTEGER; ok: BOOLEAN; line: ARRAY 256 OF CHAR;
BEGIN
  n := OvaWindow.character.notes; i := 0; ok := TRUE;
  WHILE ok & (n # NIL) DO
    INC(i); ok := i <= OvaBackground.notes.Count();
    IF ok THEN OvaBackground.notes.GetText(i, line); ok := Ropes.EqualString(n.header, line) END;
    n := n.next
  END;
  RETURN ok & (i = OvaBackground.notes.Count())
END NotesShown;

PROCEDURE NoteCount(): INTEGER;
  VAR n: OvaCharacter.Note; i: INTEGER;
BEGIN
  i := 0; n := OvaWindow.character.notes; WHILE n # NIL DO INC(i); n := n.next END;
  RETURN i
END NoteCount;

(* Whether the portrait box shows an image, scaled to fit it. *)
PROCEDURE ImageShown(): BOOLEAN;
  VAR img: FlImages.Image;
BEGIN
  img := OvaBackground.image;
  RETURN (img # NIL) & img.IsOpen() & (img.W() > 0) & (img.W() <= OvaBackground.portrait.W())
    & (img.H() <= OvaBackground.portrait.H())
END ImageShown;

PROCEDURE PortraitSays(text: ARRAY OF CHAR): BOOLEAN;
  VAR label: ARRAY 64 OF CHAR;
BEGIN OvaBackground.portrait.GetLabel(label); RETURN label = text
END PortraitSays;

PROCEDURE Title(VAR s: ARRAY OF CHAR);
BEGIN OvaWindow.window.GetLabel(s)
END Title;

PROCEDURE Modified(): BOOLEAN;
  VAR s: ARRAY 128 OF CHAR; i: INTEGER;
BEGIN
  Title(s); i := 0; WHILE s[i] # 0X DO INC(i) END;
  RETURN OvaWindow.modified & (i > 2) & (s[i - 1] = "*")
END Modified;

(* ---- Driving ---- *)

PROCEDURE Load(name: ARRAY OF CHAR): BOOLEAN;
  VAR r: Rope;
BEGIN r := Ropes.FromString("data/"); OvaText.Add(r, name); RETURN OvaWindow.Load(r)
END Load;

(* Types text into input i, as the user does: its callback runs. *)
PROCEDURE Type(i: FlInputs.Input; text: ARRAY OF CHAR);
BEGIN i.SetValue(text); i.DoCallback
END Type;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

BEGIN
  tells := 0; chosenImage := NIL; chosenPath := NIL;
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaWindow.ask := Ask; OvaWindow.choosePath := ChoosePath;
  OvaBackground.chooseImage := ChooseImage;

  (* An image to choose: a gradient, ImageW by ImageH, as a PNG. *)
  NEW(bits, ImageW * ImageH * 3);
  FOR i := 0 TO ImageW * ImageH * 3 - 1 DO bits[i] := CHR(i MOD 251) END;
  NEW(img); FlImages.OpenRGB(img, bits^, ImageW, ImageH, 3, 0);
  Check.Check(img.SavePNG(ImagePath), "an image written to choose");
  img.Close;

  Check.Check(OvaWindow.tabs.Value() = OvaWindow.sheetTab, "the Character tab first");
  OvaWindow.tabs.SetValue(OvaWindow.backgroundTab);
  OvaWindow.window.Show; OvaWindow.window.WaitForExpose; IF Fl.Check() THEN END;
  Check.Check(OvaBackground.prose[OvaBackground.Background].Visible(), "the Background tab, shown");
  Check.Check(AllShown() & NotesShown() & PortraitSays("No portrait.") & (OvaBackground.image = NIL)
    & ~OvaBackground.removePortrait.Active(), "a new character: every field empty, no portrait");

  (* ---- Shown from a file ---- *)
  ok := Load("Sheet.yaml"); c := OvaWindow.character;
  Check.Check(ok & AllShown(), "Sheet.yaml: the summary, the four sections, the fluff and the portrait's path shown");
  Check.Check(c.hasBackground & c.hasAppearance & c.hasPersonality & c.hasOtherNotes & c.hasSummary
    & c.hasFluffField[OvaEntities.Concept], "and it has each");
  Check.Check(InputIs(OvaBackground.portraitPath, R("images/hana.png")) & (OvaBackground.image = NIL)
    & PortraitSays("The image can't be read.") & OvaBackground.removePortrait.Active(),
    "its portrait, not there: the path, and why there's no image");
  ok := Load("Raine.yaml");
  Check.Check(ok & (NoteCount() > 0) & NotesShown(), "Raine.yaml: the notes' headers listed");
  OvaBackground.notes.GetText(1, s);
  Check.Check(s = "Nightmares", "the first, Nightmares");
  IF OvaBackground.notes.Select(1, TRUE) THEN END; OvaBackground.notes.DoCallback;
  c := OvaWindow.character;
  Check.Check(InputIs(OvaBackground.noteHeader, c.notes.header) & InputIs(OvaBackground.noteText, c.notes.text),
    "a note selected: its header and text to edit");

  (* ---- Text typed ---- *)
  ok := Load("Sheet.yaml"); c := OvaWindow.character;
  Check.Check(~OvaWindow.modified, "loaded: nothing changed");
  buf := Prose(OvaBackground.Appearance);
  buf.Append(" She hums.");
  Check.Check(Has(c.appearance, "coat that never stops moving. She hums.") & Modified(),
    "typing in Appearance: the character's, and the title marked");
  Check.Check(Has(Saved(), "She hums."), "and saved");
  buf.Insert(0, "  ");
  Check.Check(Ropes.Fetch(c.appearance, 0) = "S", "blanks at the ends are trimmed, as the loader trims them");
  buf.SetText("   ");
  Check.Check(~c.hasAppearance & (c.appearance = NIL) & ~Has(Saved(), "appearance:"), "emptied: not saved");
  buf := Prose(OvaBackground.OtherNotes); buf.SetText("Owes two favors now.");
  Check.Check(Has(Saved(), "other-notes: Owes two favors now."), "Other Notes saved");
  Type(OvaBackground.summaryIn, "A schoolgirl and a storm.");
  Check.Check(Ropes.EqualString(c.summary, "A schoolgirl and a storm.") & Has(Saved(), "summary: A schoolgirl and a storm."),
    "the summary typed and saved");

  (* ---- The fluff ---- *)
  Type(OvaBackground.fluffIn[OvaEntities.Hair], "Black");
  Check.Check(c.hasFluffField[OvaEntities.Hair] & Has(Saved(), "hair: Black"), "Hair typed: saved in fluff:");
  Type(OvaBackground.fluffIn[OvaEntities.FavoriteFood], "Melon bread");
  Check.Check(Has(Saved(), "favorite-food: Melon bread"), "Favorite Food: its key, favorite-food");
  FOR i := 0 TO OvaCharacter.NFluff - 1 DO Type(OvaBackground.fluffIn[i], " ") END;
  Check.Check(~c.hasFluff & ~Has(Saved(), "fluff:"), "every field emptied: no fluff: block");
  Type(OvaBackground.fluffIn[OvaEntities.Age], "15");
  Check.Check(c.hasFluff & Has(Saved(), "fluff:") & Has(Saved(), "age: 15"), "one field again: the block again");
  Check.Check(AllShown(), "and every field still shows the character's");

  (* ---- The notes ---- *)
  tells := 0;
  OvaBackground.noteHeader.SetValue("Rivals"); OvaBackground.noteText.SetValue("");
  OvaBackground.addNote.DoCallback;
  Check.Check((tells = 1) & (NoteCount() = 0), "a note with no text: said so, not added");
  OvaBackground.noteText.SetValue("The track team's captain.");
  OvaBackground.addNote.DoCallback;
  OvaBackground.noteHeader.SetValue("Secrets"); OvaBackground.noteText.SetValue("Nobody knows about the Gale.");
  OvaBackground.addNote.DoCallback;
  Check.Check((NoteCount() = 2) & NotesShown() & (OvaBackground.notes.Value() = 2), "two added, in order, the last selected");
  text := Saved();
  Check.Check(Has(text, "header: Rivals") & Has(text, "The track team's captain.") & Has(text, "header: Secrets"),
    "and saved");
  IF OvaBackground.notes.Select(1, TRUE) THEN END; OvaBackground.notes.DoCallback;
  OvaBackground.noteHeader.SetValue("Rival");
  OvaBackground.changeNote.DoCallback;
  Check.Check(Ropes.EqualString(c.notes.header, "Rival") & NotesShown() & (OvaBackground.notes.Value() = 1),
    "Change: the header changed, in its place");
  OvaBackground.removeNote.DoCallback;
  Check.Check((NoteCount() = 1) & Ropes.EqualString(c.notes.header, "Secrets") & NotesShown(), "Remove");
  n := NoteCount();
  OvaBackground.removeNote.DoCallback;
  Check.Check(NoteCount() = n, "Remove with nothing selected removes nothing");

  (* ---- The portrait ---- *)
  (* Sheet.yaml is in test/data; the image in obj. *)
  chosenImage := OvaPaths.Absolute(R(ImagePath), NIL);
  OvaBackground.choosePortrait.DoCallback;
  Check.Check(Ropes.EqualString(c.portrait, "../../obj/face.png") & AllShown(),
    "an image chosen: its path relative to the character's file");
  Check.Check(ImageShown() & PortraitSays("") & OvaBackground.removePortrait.Active(), "and shown, scaled to the box");
  Check.Check(Has(Saved(), 'portrait: "../../obj/face.png"'), "and saved so (quoted, as OvaSave quotes text starting with .)");
  tells := 0; chosenPath := R(BadPath);
  OvaWindow.bar.Pick(OvaWindow.saveAsItem);
  Title(s);
  Check.Check((tells = 1) & Ropes.EqualString(c.portrait, "../../obj/face.png")
    & (s = "OVA Character Generator - Sheet.yaml *"), "a save that fails: said so, the path as it was");
  chosenPath := R(SavePath);
  OvaWindow.bar.Pick(OvaWindow.saveAsItem);
  Title(s);
  Check.Check(Ropes.EqualString(c.portrait, "../face.png") & (s = "OVA Character Generator - bg.yaml")
    & ImageShown() & AllShown(), "Save As to obj/files: the path rebased, the image still shown");
  text := Saved();
  ok := OvaWindow.Load(chosenPath); c := OvaWindow.character;
  Check.Check(ok & (tells = 1) & Ropes.EqualString(c.portrait, "../face.png") & ImageShown() & AllShown()
    & NotesShown(), "loaded again: the portrait found from the file's directory");
  Check.Check(Ropes.Equal(Saved(), text), "and everything the tab set, the same");
  chosenImage := NIL;
  OvaBackground.choosePortrait.DoCallback;
  Check.Check(Ropes.EqualString(c.portrait, "../face.png") & ~OvaWindow.modified, "the chooser cancelled: nothing changes");
  OvaBackground.removePortrait.DoCallback;
  Check.Check(~c.hasPortrait & ~Has(Saved(), "portrait:") & PortraitSays("No portrait.") & (OvaBackground.image = NIL)
    & ~OvaBackground.removePortrait.Active() & Modified(), "Remove: no portrait");

  (* A character never saved holds the absolute path, until its first save. *)
  OvaWindow.bar.Pick(OvaWindow.newItem); c := OvaWindow.character;
  Check.Check(AllShown() & NotesShown() & (OvaBackground.image = NIL), "New: every field empty again");
  chosenImage := R(ImagePath);
  OvaBackground.choosePortrait.DoCallback;
  Check.Check(Ropes.Equal(c.portrait, OvaPaths.Absolute(R(ImagePath), NIL)) & ImageShown(),
    "no file yet: the image's absolute path");
  OvaWindow.nameIn.SetValue("Someone"); OvaWindow.nameIn.DoCallback;
  OvaWindow.bar.Pick(OvaWindow.saveItem);
  Check.Check(Ropes.EqualString(c.portrait, "../face.png") & ~OvaWindow.modified & ImageShown(),
    "the first save: made relative");

  OvaWindow.Close;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestBackground.
