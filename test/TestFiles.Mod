MODULE TestFiles; (* OvaCharacter and OvaSave: loading, saving, and loading again *)

(* PLAN.md, "Files". Each fixture holding one character is loaded,
   saved into ../obj/files/ (for test/files.sh, which formats both with
   po_ova_fmt and compares), and loaded again: the second load must
   give the same YAML and the same notices. The notices are the numbers
   kept as overrides; until Phase 3a's keys, they are exactly the
   samples' numbers the files can't yet say how to compute. Then the
   files that can't be loaded, a failed save, and a character with text
   plain YAML can't hold. Needs no display. *)

IMPORT Check, Fyaml, OvaCalc, OvaCharacter, OvaEntities, OvaSave, OvaText, Out, Ropes, Strings;

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

(* Loads name, saves it, loads the copy; want: the notices expected. *)
PROCEDURE RoundTrip(name: ARRAY OF CHAR; want: INTEGER);
  VAR path, saved: ARRAY 128 OF CHAR; c, c2: OvaCharacter.Character; msg, text, text2: Ropes.Rope;
    loaded, n: INTEGER; ok: BOOLEAN; m: OvaText.String;
BEGIN
  Path(DataDir, name, path); Path(SavedDir, name, saved);
  ok := OvaCharacter.Load(path, c, msg);
  L(name, "loaded"); Check.Check(ok, label);
  IF ~ok THEN m := OvaText.Chars(msg); Out.String("    "); Out.String(m^); Out.Ln; RETURN END;
  n := OvaCharacter.notices.n;
  L(name, "notices");
  Check.Check(n = want, label);
  IF (n # want) OR (n > 0) THEN ShowNotices END;
  text := OvaSave.ToText(c);
  L(name, "saved"); Check.Check(OvaSave.Save(c, saved, msg), label);
  ok := OvaCharacter.Load(saved, c2, msg);
  L(name, "the copy loaded"); Check.Check(ok, label);
  IF ok THEN
    L(name, "the copy has the same notices"); Check.Check(OvaCharacter.notices.n = n, label);
    text2 := OvaSave.ToText(c2);
    L(name, "the copy saves the same"); Check.Check((text # NIL) & Ropes.Equal(text, text2), label)
  END
END RoundTrip;

PROCEDURE Fixtures;
BEGIN
  (* The samples. Those with notices: what Phase 3a's keys will let
     the rules compute, Ai's attacks made with Telekinesis (2 DX),
     Fukiko's sheet shown transformed (4 ROLL, 3 DX, Barrier's Defense,
     and TV), Miho's Mode SP made transformed (its ROLL, and TV, which
     counts it until it is marked); and the book's two rulings, Braun's
     ROLL (his TV of 0 then follows) and Natsuki's Stiletto Kick's DX. *)
  RoundTrip("Ai", 2); RoundTrip("Auren", 0); RoundTrip("Braun", 1); RoundTrip("Cora", 0);
  RoundTrip("Daisuke", 0); RoundTrip("Fukiko", 9); RoundTrip("Karis", 0); RoundTrip("Miho", 2);
  RoundTrip("Natsuki", 1); RoundTrip("Raine", 0); RoundTrip("Shou", 0); RoundTrip("Yuu", 0);
  (* po_ova_fmt's own, for its formats: their numbers were never the
     rules', so they come back as overrides. *)
  RoundTrip("Escaping", 5); RoundTrip("Unsorted", 8); RoundTrip("Vehicle", 5)
END Fixtures;

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
  Refused("data/Fragment.yaml", "holds 2 characters", "Fragment.yaml");
  Refused("data/Options.yaml", "holds 2 characters", "Options.yaml");
  Refused("data/no-such-file.yaml", "no-such-file.yaml", "a missing file");
  c := OvaCharacter.New(); c.name := Ropes.FromString("Nobody");
  ok := OvaSave.Save(c, "../obj/no-such-dir/x.yaml", msg);
  Check.Check(~ok & (msg # NIL), "a save to a missing directory fails, with a message")
END Errors;

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
     it on loading, as po_ova_fmt and the Ada ova_fmt do. *)
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

BEGIN
  Fixtures;
  Errors;
  AwkwardText;
  Check.Summary
END TestFiles.
