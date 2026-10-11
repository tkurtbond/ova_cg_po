MODULE TestFiles; (* OvaCharacter and OvaSave: loading, saving, and loading again *)

(* PLAN.md, "Files". Each fixture, every character in it, is loaded,
   saved into ../obj/files/ (for test/files.sh, which formats both with
   ova_fmt_po and compares), and loaded again: the second load must
   give the same YAML, and no notices, since the copy's overrides: keys
   list every number kept as an override. The notices are the numbers
   the first load kept as overrides, those the file differs from the
   rules on without listing them. Then the files that can't be loaded,
   a failed save, and a character with text plain YAML can't hold.
   Each fixture's Markdown sheet (OvaMarkdown), one character's after
   another, is saved beside its copy, as NAME.md, which test/files.sh
   compares with ova_fmt_po -M's of the copy. Needs no display. *)

IMPORT Check, Fyaml, OvaCalc, OvaCharacter, OvaEntities, OvaMarkdown, OvaSave, OvaText, Out, Platform, Ropes, Strings;

CONST
  DataDir = "data/";
  SavedDir = "../obj/files/";

VAR
  label: ARRAY 256 OF CHAR;

PROCEDURE L(name, what: ARRAY OF CHAR);
BEGIN COPY(name, label); Strings.Append(": ", label); Strings.Append(what, label)
END L;

PROCEDURE Path(dir, name: ARRAY OF CHAR; VAR path: ARRAY OF CHAR);
BEGIN COPY(dir, path); Strings.Append(name, path); Strings.Append(".yaml", path)
END Path;

PROCEDURE ShowNotices;
  VAR i: INTEGER; s: OvaText.String;
BEGIN
  FOR i := 0 TO OvaCharacter.notices.n - 1 DO
    s := OvaText.Chars(OvaCharacter.notices.items[i]); Out.String("    "); Out.String(s^); Out.Ln
  END
END ShowNotices;

(* Loads name, every character in it, saves them, loads the copy;
   want: the notices expected. *)
PROCEDURE RoundTrip(name: ARRAY OF CHAR; want: INTEGER);
  VAR path, saved, md: ARRAY 128 OF CHAR; c, c2: OvaCharacter.Characters; msg, text, text2, sheet: Ropes.Rope;
    loaded, n, i: INTEGER; ok: BOOLEAN; m: OvaText.String;
BEGIN
  Path(DataDir, name, path); Path(SavedDir, name, saved);
  ok := OvaCharacter.LoadAll(path, c, msg);
  L(name, "loaded"); Check.Check(ok, label);
  IF ~ok THEN m := OvaText.Chars(msg); Out.String("    "); Out.String(m^); Out.Ln; RETURN END;
  n := OvaCharacter.notices.n;
  L(name, "notices");
  Check.Check(n = want, label);
  IF (n # want) OR (n > 0) THEN ShowNotices END;
  text := OvaSave.AllToText(c);
  L(name, "saved"); Check.Check(OvaSave.SaveAll(c, saved, msg), label);
  sheet := NIL; ok := TRUE;
  FOR i := 0 TO SHORT(LEN(c^)) - 1 DO
    text2 := OvaMarkdown.Sheet(c[i]); ok := ok & (text2 # NIL); sheet := Ropes.Cat(sheet, text2)
  END;
  COPY(SavedDir, md); Strings.Append(name, md); Strings.Append(".md", md);
  IF Platform.Unlink(md) = 0 THEN END;  (* so files.sh never compares a file from before *)
  L(name, "its Markdown sheet saved"); Check.Check(ok & OvaMarkdown.Save(sheet, md, msg), label);
  ok := OvaCharacter.LoadAll(saved, c2, msg);
  L(name, "the copy loaded"); Check.Check(ok, label);
  IF ok THEN
    L(name, "the copy has no notices: it lists its overrides"); Check.Check(OvaCharacter.notices.n = 0, label);
    IF OvaCharacter.notices.n > 0 THEN ShowNotices END;
    text2 := OvaSave.AllToText(c2);
    L(name, "the copy saves the same"); Check.Check((text # NIL) & Ropes.Equal(text, text2), label)
  END
END RoundTrip;

PROCEDURE Fixtures;
BEGIN
  (* The samples: every number is the rules', given the Phase 3a keys
     the fixtures carry (Ai's attacks made with Telekinesis, Fukiko's
     sheet shown transformed, Miho's Mode SP made transformed), but the
     book's two rulings, Braun's ROLL and Natsuki's Stiletto Kick's DX,
     which their overrides: list. Without those keys there were 15
     notices (Phase 3). Sheet uses every key; Defenses and Wisp, the
     three Defense values, and Incorporeal Form's alone. *)
  RoundTrip("Ai", 0); RoundTrip("Auren", 0); RoundTrip("Braun", 0); RoundTrip("Cora", 0);
  RoundTrip("Daisuke", 0); RoundTrip("Fukiko", 0); RoundTrip("Karis", 0); RoundTrip("Miho", 0);
  RoundTrip("Natsuki", 0); RoundTrip("Raine", 0); RoundTrip("Shou", 0); RoundTrip("Yuu", 0);
  RoundTrip("Sheet", 0); RoundTrip("Defenses", 0); RoundTrip("Wisp", 0);
  (* ova_fmt_po's own, for its formats: their numbers were never the
     rules', so they come back as overrides. *)
  RoundTrip("Escaping", 5); RoundTrip("Unsorted", 8); RoundTrip("Vehicle", 5);
  (* The Sample NPCs: a Secondary NPC's sheet is a Companion's
     (npc-type:), so Dr. Tomori's and Jiro's numbers are the rules';
     Nazo's and Shadowman's single Defense is their best, as the book
     prints it, but Nazo's TV is the book's own
     (CHARACTER-DIFFERENCES.md). Acacia and Zurkrieg hold more than one
     entity (Several); Acacia's notice is its Lock Heaven's Door's END. *)
  RoundTrip("Acacia", 1); RoundTrip("Zurkrieg", 0);
  RoundTrip("Ancel", 0); RoundTrip("Dr-Tomori", 0); RoundTrip("Jiro", 0); RoundTrip("Nazo", 1);
  RoundTrip("Saspar", 0); RoundTrip("Shadowman", 0);
  (* The NPC Fragments: no combat: block, so nothing to compare. *)
  RoundTrip("Beat-Cop", 0); RoundTrip("Cat-Burglar", 0); RoundTrip("Dragon", 0);
  RoundTrip("Ebullient-Club-President", 0); RoundTrip("Ghosts", 0); RoundTrip("Goblin", 0);
  RoundTrip("GPL-Agents", 0); RoundTrip("Indebted-Yakuza", 0); RoundTrip("Magical-Fairies", 0);
  RoundTrip("Ninja", 0); RoundTrip("Oni", 0); RoundTrip("Sentry-Bots", 0); RoundTrip("Shady-Teacher", 0);
  RoundTrip("Shinto-Priest", 0); RoundTrip("Snobbish-Upperclassman", 0); RoundTrip("Spider-Tank", 0);
  RoundTrip("Thugs", 0); RoundTrip("Venomous-Killer", 0); RoundTrip("Weathered-Salaryman", 0);
  RoundTrip("Weird-Exchange-Student", 0); RoundTrip("Wild-Beast", 0); RoundTrip("Zombies", 0);
  (* ova_fmt_po's two of two Fragments each, and the generator's own of
     two YAML documents. *)
  RoundTrip("Fragment", 0); RoundTrip("Options", 0); RoundTrip("two-documents", 0)
END Fixtures;

(* Whether r holds s. *)
PROCEDURE^ Holds(r: Ropes.Rope; s: ARRAY OF CHAR): BOOLEAN;

(* Whether cs are n characters named by names, "|" between them. *)
PROCEDURE Named(cs: OvaCharacter.Characters; n: INTEGER; names: ARRAY OF CHAR): BOOLEAN;
  VAR i: INTEGER; r: Ropes.Rope;
BEGIN
  IF (cs = NIL) OR (LEN(cs^) # n) THEN RETURN FALSE END;
  r := cs[0].name;
  FOR i := 1 TO n - 1 DO OvaText.Add(r, "|"); r := Ropes.Cat(r, cs[i].name) END;
  RETURN Ropes.EqualString(r, names)
END Named;

(* Files of several characters (PLAN.md, "Several characters in a
   file"): every one loaded, in order, each its notices, and saved in
   that order; Load still takes exactly one. *)
PROCEDURE Several;
  VAR cs, cs2: OvaCharacter.Characters; c: OvaCharacter.Character; msg: Ropes.Rope; ok: BOOLEAN;
    s: OvaText.String;
BEGIN
  ok := OvaCharacter.LoadAll("data/Acacia.yaml", cs, msg);
  Check.Check(ok & Named(cs, 3, "Acacia|Sazza and Fraz|High Fructo Cezar"),
    "Acacia.yaml: her and her two demons, in the file's order");
  Check.Check((OvaCharacter.notices.n = 1) & Holds(OvaCharacter.notices.items[0], "Acacia: Lock Heaven's Door: END"),
    "its one notice names its character");
  ok := OvaCharacter.LoadAll("data/two-documents.yaml", cs, msg);
  Check.Check(ok & Named(cs, 2, "First Of Two|Second Of Two"), "two-documents.yaml: a character from each document");
  ok := OvaSave.SaveAll(cs, "../obj/two-documents.yaml", msg)
    & OvaCharacter.LoadAll("../obj/two-documents.yaml", cs2, msg);
  Check.Check(ok & Named(cs2, 2, "First Of Two|Second Of Two")
    & (Ropes.Find(OvaSave.AllToText(cs), "---", 1) < 0),
    "saved as one document, the two in order");
  ok := OvaCharacter.LoadAll("data/Zurkrieg.yaml", cs, msg);
  Check.Check(ok & Named(cs, 2, "Zurkrieg|Men in Black") & cs[0].hasCombat & cs[1].isFragment & ~cs[1].hasCombat
    & (OvaCharacter.notices.n = 0), "Zurkrieg.yaml: him, with combat stats, and his Men in Black, a Fragment; no notices");
  ok := OvaCharacter.Load("data/Zurkrieg.yaml", c, msg);
  s := OvaText.Chars(msg);
  Check.Check(~ok & (c = NIL) & (Strings.Pos("holds 2 characters, not one", s^, 0) >= 0),
    "Load, for one character, refuses it, saying how many it holds")
END Several;

(* A file that can't be loaded: msg must hold want. *)
PROCEDURE Refused(path, want: ARRAY OF CHAR; what: ARRAY OF CHAR);
  VAR c: OvaCharacter.Character; msg: Ropes.Rope; ok: BOOLEAN; m: OvaText.String; i: INTEGER;
    found: BOOLEAN; w: Ropes.Rope;
BEGIN
  ok := OvaCharacter.Load(path, c, msg);
  m := OvaText.Chars(msg);
  w := Ropes.FromString(want);
  found := FALSE; i := 0;
  WHILE ~found & (i + Ropes.Length(w) <= Ropes.Length(msg)) DO
    found := Ropes.Equal(Ropes.Substring(msg, i, Ropes.Length(w)), w); INC(i)
  END;
  COPY(what, label); Strings.Append(": refused, saying ", label); Strings.Append(want, label);
  Check.Check(~ok & (c = NIL) & found, label);
  IF ~found THEN Out.String("    said: "); Out.String(m^); Out.Ln END
END Refused;

PROCEDURE Errors;
  VAR c: OvaCharacter.Character; msg: Ropes.Rope; ok: BOOLEAN;
BEGIN
  Refused("data/Broken.yaml", "level", "Broken.yaml");
  Refused("data/no-such-file.yaml", "no-such-file.yaml", "a missing file");
  c := OvaCharacter.New(); c.name := Ropes.FromString("Nobody");
  ok := OvaSave.Save(c, "../obj/no-such-dir/x.yaml", msg);
  Check.Check(~ok & (msg # NIL), "a save to a missing directory fails, with a message")
END Errors;

(* Whether r holds s. *)
PROCEDURE Holds(r: Ropes.Rope; s: ARRAY OF CHAR): BOOLEAN;
  VAR w: Ropes.Rope; i: LONGINT;
BEGIN
  w := Ropes.FromString(s); i := 0;
  WHILE i + Ropes.Length(w) <= Ropes.Length(r) DO
    IF Ropes.Equal(Ropes.Substring(r, i, Ropes.Length(w)), w) THEN RETURN TRUE END;
    INC(i)
  END;
  RETURN FALSE
END Holds;

(* Whether r holds the line s, ending in a line feed. *)
PROCEDURE HoldsLine(r: Ropes.Rope; s: ARRAY OF CHAR): BOOLEAN;
  VAR line: ARRAY 128 OF CHAR; n: INTEGER;
BEGIN
  COPY(s, line); n := Strings.Length(line); line[n] := 0AX; line[n + 1] := 0X;
  RETURN Holds(r, line)
END HoldsLine;

(* name, loaded, saved: its text holds the line want. *)
PROCEDURE SavesAs(name, want: ARRAY OF CHAR);
  VAR path: ARRAY 128 OF CHAR; c: OvaCharacter.Character; msg, text: Ropes.Rope; s: OvaText.String;
BEGIN
  Path(DataDir, name, path);
  IF OvaCharacter.Load(path, c, msg) THEN text := OvaSave.ToText(c) ELSE text := NIL END;
  L(name, "saved with "); Strings.Append(want, label);
  Check.Check((text # NIL) & HoldsLine(text, want), label);
  IF (text # NIL) & ~HoldsLine(text, want) THEN s := OvaText.Chars(text); Out.String(s^) END
END SavesAs;

(* Up to three Defense values (PLAN.md, Phase 11): one where the rules
   give more is the best; two, the Defense and the first alternate; an
   overridden alternate the character doesn't have is saved where it is
   read back. *)
PROCEDURE Defenses;
  VAR c, c2: OvaCharacter.Character; msg, text: Ropes.Rope; ok: BOOLEAN; slot: INTEGER;
BEGIN
  RoundTrip("defense-best", 0);
  SavesAs("defense-best", "defense: 4");
  RoundTrip("defense-best-differs", 1);
  SavesAs("defense-best-differs", "defense: 3");
  ok := OvaCharacter.Load("data/defense-best-differs.yaml", c, msg);
  Check.Check(ok & c.incorporeal.overridden & ~c.barrier.overridden & ~c.defense.overridden
    & OvaCharacter.SingleDefense(c, slot) & (slot = OvaCharacter.IncorporealSlot),
    "defense-best-differs: read as Incorporeal Form's, the best by the rules, and saved as one");
  RoundTrip("defense-two", 0);
  SavesAs("defense-two", "defense: 2/3/4");

  (* One value, but another overridden since: all of them saved. *)
  ok := OvaCharacter.Load("data/defense-best.yaml", c, msg);
  OvaCalc.Override(c.defense, 3, FALSE, FALSE); OvaCharacter.Recompute(c);
  text := OvaSave.ToText(c);
  Check.Check(ok & ~OvaCharacter.SingleDefense(c, slot) & HoldsLine(text, "defense: 3/4/4")
    & HoldsLine(text, "    - defense"), "defense-best, its DEFENSE overridden: saved with all three");

  (* An overridden Incorporeal Form's Defense the character doesn't have:
     Barrier's is saved before it, so it is read back as the third. *)
  c := OvaCharacter.New(); c.name := Ropes.FromString("Ghostless");
  OvaCalc.Override(c.incorporeal, 7, FALSE, FALSE); OvaCharacter.Recompute(c);
  text := OvaSave.ToText(c);
  Check.Check(HoldsLine(text, "defense: 2/0/7") & HoldsLine(text, "    - defense-3"),
    "an overridden Incorporeal Form's DEFENSE without it: saved third, after Barrier's 0");
  ok := OvaSave.Save(c, "../obj/ghostless.yaml", msg) & OvaCharacter.Load("../obj/ghostless.yaml", c2, msg);
  Check.Check(ok & (OvaCharacter.notices.n = 0) & c2.incorporeal.overridden & (OvaCalc.Value(c2.incorporeal) = 7)
    & ~c2.barrier.overridden, "and read back as Incorporeal Form's, with no notice")
END Defenses;

(* Text plain YAML can't hold, saved and loaded back. *)
PROCEDURE AwkwardText;
  VAR c, c2: OvaCharacter.Character; msg: Ropes.Rope; ok: BOOLEAN; s, bg: OvaText.String;
    note: OvaCharacter.Note; d: Fyaml.Document; err: Fyaml.Error; root, n: Fyaml.Node; got: Fyaml.String;
BEGIN
  c := OvaCharacter.New();
  c.name := Ropes.FromString('#1 "Ace"');
  c.hasTagline := TRUE; c.tagline := Ropes.FromString("'Til the end: - and | >");
  c.hasBackground := TRUE; c.background := Ropes.FromString("  Indented first line,");
  OvaText.Add(c.background, 0AX); OvaText.Add(c.background, "then a second; # not a comment");
  NEW(note); note.next := NIL; note.header := Ropes.FromString("? Header");
  note.text := Ropes.FromString("@line one"); OvaText.Add(note.text, 0AX); OvaText.Add(note.text, 0AX);
  OvaText.Add(note.text, "%line three"); c.notes := note;
  c.hasFluff := TRUE; c.hasFluffField[OvaEntities.Hobbies] := TRUE; c.fluff[OvaEntities.Hobbies] := Ropes.FromString("#1 fan");
  OvaCalc.Compute(c);
  Check.Check(OvaSave.Save(c, "../obj/files/awkward.yaml", msg), "awkward text: saved");
  ok := OvaCharacter.Load("../obj/files/awkward.yaml", c2, msg);
  Check.Check(ok, "awkward text: loaded");
  IF ~ok THEN s := OvaText.Chars(msg); Out.String(s^); Out.Ln; RETURN END;
  Check.Check(Ropes.Equal(c2.name, c.name), "awkward text: the name");
  Check.Check(Ropes.Equal(c2.tagline, c.tagline), "awkward text: the tagline");
  (* The file keeps the background's first blanks; OvaEntities trims
     it on loading, as ova_fmt_po and the Ada ova_fmt do. *)
  d := Fyaml.ParseFile("../obj/files/awkward.yaml", err);
  ok := d # NIL;
  IF ok THEN
    root := d.Root(); n := root.ByPath("/0/background");
    bg := OvaText.Chars(c.background);
    ok := (n # NIL) & n.IsScalar();
    IF ok THEN got := n.Scalar(); ok := got^ = bg^ END;
    d.Close
  END;
  Check.Check(ok, "awkward text: the file holds the background exactly, its first blanks too");
  Check.Check(Ropes.Equal(c2.background, OvaText.Trim(c.background)), "awkward text: the background loads trimmed");
  Check.Check((c2.notes # NIL) & Ropes.Equal(c2.notes.header, note.header) & Ropes.Equal(c2.notes.text, note.text),
              "awkward text: the note");
  Check.Check(c2.hasFluffField[OvaEntities.Hobbies] & Ropes.Equal(c2.fluff[OvaEntities.Hobbies], c.fluff[OvaEntities.Hobbies]), "awkward text: hobbies #1 fan");
  Check.Check(OvaCharacter.notices.n = 0, "awkward text: no notices")
END AwkwardText;

(* OvaMarkdown.Save: a file that can't be written is said so, and the
   next save, to a file that can, works. *)
PROCEDURE MarkdownSave;
  VAR msg, back: Ropes.Rope; ok: BOOLEAN; path: ARRAY 32 OF CHAR;
BEGIN
  ok := OvaMarkdown.Save(Ropes.FromString("# A"), "../obj/no/such/dir/sheet.md", msg);
  Check.Check(~ok & Holds(msg, "couldn't write ../obj/no/such/dir/sheet.md"), "a Markdown sheet that can't be written: said so");
  path := "../obj/sheet.md"; IF Platform.Unlink(path) = 0 THEN END;
  ok := OvaMarkdown.Save(Ropes.FromString("# B"), "../obj/sheet.md", msg);
  Check.Check(ok & (msg = NIL) & Ropes.ReadFile("../obj/sheet.md", back) & Ropes.EqualString(back, "# B"),
    "then one that can: written, all of it")
END MarkdownSave;

BEGIN
  Fixtures;
  MarkdownSave;
  Errors;
  Defenses;
  Several;
  AwkwardText;
  Check.Summary
END TestFiles.
