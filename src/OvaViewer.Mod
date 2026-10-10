MODULE OvaViewer; (* The rulebook viewer: finding the PDF, and turning a viewer to a page *)

(* PLAN.md, "The rulebook viewer": reuse a viewer already open, start
   one only when none is. okular is turned over D-Bus (gdbus) when one
   shows the rulebook already, evince reuses its own window, mupdf can't
   be reused, so the one this program started last is ended (by its
   pid, never by name) before the next starts, and xdg-open can't turn
   to a page at all, so the caller is told which. A command template
   runs as given. Every program is started with OvaSpawn, never a
   shell. Needs no display, and imports no pofltk.

   The programs' names are variables, so the tests can put fakes in
   their place (TestViewer). *)

IMPORT OvaRules, OvaSpawn, OvaText, Platform, Ropes;

CONST
  (* Viewer kinds. *)
  Okular* = 0; Evince* = 1; Mupdf* = 2; XdgOpen* = 3; Template* = 4;

  (* The rulebook where it is looked for last, under the home
     directory. *)
  DefaultRulebook = "/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf";

  (* okular's interface, and its main window's object. *)
  OkularIface = "org.kde.okular";
  OkularShell = "/okularshell";
  (* The most tabs of one okular looked through. *)
  MaxTabs = 50;

TYPE
  Rope* = Ropes.Rope;

  (* A viewer: its kind, and for a Template, the command, whose words
     %f, %p and %l become the PDF, the page index and the label. *)
  Viewer* = RECORD
    kind-: INTEGER;
    template-: Rope
  END;

VAR
  (* The programs run, by name on PATH. *)
  okular*, evince*, mupdf*, xdgOpen*, gdbus*: ARRAY 256 OF CHAR;
  (* The mupdf this program started last. *)
  lastMupdf: OvaSpawn.Process;

(* ---- The PDF ---- *)

(* path, made absolute against the working directory: okular is asked
   which tab shows it, and the viewers given it are run elsewhere. *)
PROCEDURE Absolute(path: Rope): Rope;
  VAR r: Rope;
BEGIN
  r := path;
  IF (r # NIL) & (Ropes.Fetch(r, 0) # "/") & (Platform.CWD[0] # 0X) THEN
    r := Ropes.FromString(Platform.CWD);
    r := Ropes.AppendChar(r, "/");
    r := Ropes.Cat(r, path)
  END;
  RETURN r
END Absolute;

(* Whether a file is at path. *)
PROCEDURE Exists*(path: Rope): BOOLEAN;
  VAR s: OvaText.String; id: Platform.FileIdentity;
BEGIN
  s := OvaText.Chars(path);
  RETURN (path # NIL) & (Platform.IdentifyByName(s^, id) = 0)
END Exists;

(* The rulebook's PDF: the first of option (--rulebook), env
   (OVA_RULEBOOK), saved (the preferences) that isn't empty, else the
   default under home, made absolute. Whether a file is there. *)
PROCEDURE Choose*(option, env, saved, home: Rope; VAR path: Rope): BOOLEAN;
BEGIN
  IF option # NIL THEN path := option
  ELSIF env # NIL THEN path := env
  ELSIF saved # NIL THEN path := saved
  ELSE path := home; OvaText.Add(path, DefaultRulebook)
  END;
  path := Absolute(path);
  RETURN Exists(path)
END Choose;

(* The value of the environment variable name; NIL if unset or empty. *)
PROCEDURE Env(name: ARRAY OF CHAR): Rope;
  VAR v: ARRAY 4096 OF CHAR;
BEGIN
  IF ~Platform.getEnv(name, v) THEN v[0] := 0X END;
  RETURN Ropes.FromString(v)
END Env;

(* Choose, with OVA_RULEBOOK and HOME from the environment. *)
PROCEDURE FindRulebook*(option, saved: Rope; VAR path: Rope): BOOLEAN;
BEGIN RETURN Choose(option, Env("OVA_RULEBOOK"), saved, Env("HOME"), path)
END FindRulebook;

(* ---- Viewers ---- *)

(* The viewer used when the user hasn't chosen one: the first of okular,
   evince and mupdf on PATH, else xdg-open. *)
PROCEDURE Default*(VAR v: Viewer);
BEGIN
  v.template := NIL;
  IF OvaSpawn.OnPath(okular) THEN v.kind := Okular
  ELSIF OvaSpawn.OnPath(evince) THEN v.kind := Evince
  ELSIF OvaSpawn.OnPath(mupdf) THEN v.kind := Mupdf
  ELSE v.kind := XdgOpen
  END
END Default;

(* The viewer s names: "okular", "evince", "mupdf", "xdg-open", or a
   command template, which must hold %f. FALSE, v unchanged, for
   anything else. *)
PROCEDURE Parse*(s: Rope; VAR v: Viewer): BOOLEAN;
  VAR ok: BOOLEAN;
BEGIN
  s := OvaText.Trim(s);
  ok := TRUE;
  IF Ropes.EqualString(s, "okular") THEN v.kind := Okular; v.template := NIL
  ELSIF Ropes.EqualString(s, "evince") THEN v.kind := Evince; v.template := NIL
  ELSIF Ropes.EqualString(s, "mupdf") THEN v.kind := Mupdf; v.template := NIL
  ELSIF Ropes.EqualString(s, "xdg-open") THEN v.kind := XdgOpen; v.template := NIL
  ELSIF Ropes.Find(s, "%f", 0) >= 0 THEN v.kind := Template; v.template := s
  ELSE ok := FALSE
  END;
  RETURN ok
END Parse;

(* What Parse takes back: the viewer's name, or its template. *)
PROCEDURE Name*(VAR v: Viewer): Rope;
  VAR r: Rope;
BEGIN
  CASE v.kind OF
    Okular: r := Ropes.FromString("okular")
  | Evince: r := Ropes.FromString("evince")
  | Mupdf: r := Ropes.FromString("mupdf")
  | XdgOpen: r := Ropes.FromString("xdg-open")
  | Template: r := v.template
  END;
  RETURN r
END Name;

(* Adds the words of template to a, each with %f, %p, %l and %%
   replaced by pdf, index, label and %, the replacement staying within
   its word however many blanks it holds. *)
PROCEDURE AddTemplate(VAR a: OvaSpawn.Args; template, pdf: Rope; index, label: INTEGER);
  VAR i, len: LONGINT; ch, next: CHAR; word: Rope; inWord: BOOLEAN;
BEGIN
  len := Ropes.Length(template);
  i := 0; word := NIL; inWord := FALSE;
  WHILE i <= len DO
    IF i < len THEN ch := Ropes.Fetch(template, i) ELSE ch := " " END;
    IF (ch = " ") OR (ch = 09X) THEN
      IF inWord THEN OvaSpawn.AddRope(a, word); word := NIL; inWord := FALSE END
    ELSE
      inWord := TRUE;
      IF (ch = "%") & (i + 1 < len) THEN next := Ropes.Fetch(template, i + 1) ELSE next := 0X END;
      IF next = "f" THEN word := Ropes.Cat(word, pdf); INC(i)
      ELSIF next = "p" THEN word := Ropes.Cat(word, OvaText.Int(index)); INC(i)
      ELSIF next = "l" THEN word := Ropes.Cat(word, OvaText.Int(label)); INC(i)
      ELSIF next = "%" THEN word := Ropes.AppendChar(word, "%"); INC(i)
      ELSE word := Ropes.AppendChar(word, ch)
      END
    END;
    INC(i)
  END
END AddTemplate;

(* The command that starts v on pdf at printed page page, in a. *)
PROCEDURE Command*(VAR v: Viewer; pdf: Rope; page: INTEGER; VAR a: OvaSpawn.Args);
  VAR index: Rope;
BEGIN
  index := OvaText.Int(OvaRules.PdfIndex(page));
  OvaSpawn.Clear(a);
  CASE v.kind OF
    Okular:
      OvaSpawn.Add(a, okular); OvaSpawn.Add(a, "--unique");
      OvaSpawn.Add(a, "-p"); OvaSpawn.AddRope(a, index); OvaSpawn.AddRope(a, pdf)
  | Evince:
      OvaSpawn.Add(a, evince); OvaSpawn.Add(a, "-i"); OvaSpawn.AddRope(a, index);
      OvaSpawn.AddRope(a, pdf)
  | Mupdf:
      OvaSpawn.Add(a, mupdf); OvaSpawn.AddRope(a, pdf); OvaSpawn.AddRope(a, index)
  | XdgOpen:
      OvaSpawn.Add(a, xdgOpen); OvaSpawn.AddRope(a, pdf)
  | Template:
      AddTemplate(a, v.template, pdf, OvaRules.PdfIndex(page), page)
  END
END Command;

(* ---- okular, over D-Bus ---- *)

(* Hex digit d, 0 to 15, in upper case. *)
PROCEDURE HexChar(d: INTEGER): CHAR;
  VAR ch: CHAR;
BEGIN
  IF d < 10 THEN ch := CHR(ORD("0") + d) ELSE ch := CHR(ORD("A") + d - 10) END;
  RETURN ch
END HexChar;

(* pdf as a file: URL for okular's openDocument, with only "%", "#",
   "?" and control characters percent-encoded: okular compares the URL
   with its tabs' as given, and its tab opened from a plain path has
   "'" not "%27", so a URL encoded more than this opens the PDF again
   in a new tab (PLAN.md, "Findings"). *)
PROCEDURE FileUrl*(pdf: Rope): Rope;
  VAR r: Rope; i: LONGINT; ch: CHAR;
BEGIN
  r := Ropes.FromString("file://");
  FOR i := 0 TO Ropes.Length(pdf) - 1 DO
    ch := Ropes.Fetch(pdf, i);
    IF (ch >= " ") & (ch # 7FX) & (ch # "%") & (ch # "#") & (ch # "?") THEN
      r := Ropes.AppendChar(r, ch)
    ELSE
      r := Ropes.AppendChar(r, "%");
      r := Ropes.AppendChar(r, HexChar(ORD(ch) DIV 16));
      r := Ropes.AppendChar(r, HexChar(ORD(ch) MOD 16))
    END
  END;
  RETURN r
END FileUrl;

(* The value of hex digit ch, -1 if it isn't one. *)
PROCEDURE HexDigit(ch: CHAR): INTEGER;
  VAR d: INTEGER;
BEGIN
  IF (ch >= "0") & (ch <= "9") THEN d := ORD(ch) - ORD("0")
  ELSIF (ch >= "A") & (ch <= "F") THEN d := ORD(ch) - ORD("A") + 10
  ELSIF (ch >= "a") & (ch <= "f") THEN d := ORD(ch) - ORD("a") + 10
  ELSE d := -1
  END;
  RETURN d
END HexDigit;

(* doc as a path: a file: URL's path, percent-decoded; anything else as
   it is. *)
PROCEDURE DocPath(doc: Rope): Rope;
  VAR r: Rope; i, len: LONGINT; ch: CHAR; hi, lo: INTEGER;
BEGIN
  IF Ropes.Find(doc, "file://", 0) # 0 THEN RETURN doc END;
  r := NIL; len := Ropes.Length(doc); i := 7;
  WHILE i < len DO
    ch := Ropes.Fetch(doc, i);
    hi := -1; lo := -1;
    IF (ch = "%") & (i + 2 < len) THEN
      hi := HexDigit(Ropes.Fetch(doc, i + 1)); lo := HexDigit(Ropes.Fetch(doc, i + 2))
    END;
    IF (hi >= 0) & (lo >= 0) THEN r := Ropes.AppendChar(r, CHR(hi * 16 + lo)); INC(i, 3)
    ELSE r := Ropes.AppendChar(r, ch); INC(i)
    END
  END;
  RETURN r
END DocPath;

(* The first string in out, gdbus's print of a GVariant tuple, such as
   ('/a/b.pdf',) or ("/an O'Brien.pdf",): quoted by ' or ", with \
   escapes. NIL, ok FALSE, if there is none. *)
PROCEDURE FirstString(out: Rope; from: LONGINT; VAR next: LONGINT; VAR ok: BOOLEAN): Rope;
  VAR r: Rope; i, len: LONGINT; q, ch: CHAR;
BEGIN
  r := NIL; ok := FALSE; len := Ropes.Length(out);
  i := from;
  WHILE (i < len) & (Ropes.Fetch(out, i) # "'") & (Ropes.Fetch(out, i) # 22X) DO INC(i) END;
  IF i < len THEN
    q := Ropes.Fetch(out, i); INC(i);
    WHILE (i < len) & (Ropes.Fetch(out, i) # q) DO
      ch := Ropes.Fetch(out, i);
      IF (ch = "\") & (i + 1 < len) THEN
        INC(i); ch := Ropes.Fetch(out, i);
        IF ch = "n" THEN ch := 0AX ELSIF ch = "t" THEN ch := 09X END
      END;
      r := Ropes.AppendChar(r, ch); INC(i)
    END;
    ok := i < len;
    INC(i)
  END;
  next := i;
  RETURN r
END FirstString;

(* In a, a gdbus call on the session bus to dest's object obj, its
   method method (interface and name); the caller adds the method's
   arguments. *)
PROCEDURE GdbusCall(VAR a: OvaSpawn.Args; dest, obj: Rope; method: ARRAY OF CHAR);
BEGIN
  OvaSpawn.Clear(a);
  OvaSpawn.Add(a, gdbus); OvaSpawn.Add(a, "call"); OvaSpawn.Add(a, "--session");
  OvaSpawn.Add(a, "--timeout"); OvaSpawn.Add(a, "5");
  OvaSpawn.Add(a, "--dest"); OvaSpawn.AddRope(a, dest);
  OvaSpawn.Add(a, "--object-path"); OvaSpawn.AddRope(a, obj);
  OvaSpawn.Add(a, "--method"); OvaSpawn.Add(a, method)
END GdbusCall;

(* Whether name is an okular's on the bus: org.kde.okular (started
   --unique) or org.kde.okular-PID; not its Instance_ alias. *)
PROCEDURE IsOkular(name: Rope): BOOLEAN;
  VAR i: LONGINT; ok: BOOLEAN;
BEGIN
  ok := Ropes.EqualString(name, OkularIface);
  IF ~ok & (Ropes.Find(name, "org.kde.okular-", 0) = 0) & (Ropes.Length(name) > 15) THEN
    ok := TRUE;
    FOR i := 15 TO Ropes.Length(name) - 1 DO
      IF (Ropes.Fetch(name, i) < "0") OR (Ropes.Fetch(name, i) > "9") THEN ok := FALSE END
    END
  END;
  RETURN ok
END IsOkular;

(* Tab number tab's object in an okular: /okular, /okular2, ... *)
PROCEDURE TabObject(tab: INTEGER): Rope;
  VAR r: Rope;
BEGIN
  r := Ropes.FromString("/okular");
  IF tab > 1 THEN r := Ropes.Cat(r, OvaText.Int(tab)) END;
  RETURN r
END TabObject;

(* Looks through every okular on the session bus for a tab showing pdf;
   if one does, brings it forward and turns it to page index. Whether
   one did. *)
PROCEDURE OkularTurn(pdf: Rope; index: INTEGER): BOOLEAN;
  VAR a: OvaSpawn.Args; out, names, name, obj, doc, dest: Rope;
    status, tab: INTEGER; pos, end: LONGINT; ok, more, found: BOOLEAN;
BEGIN
  found := FALSE;
  GdbusCall(a, Ropes.FromString("org.freedesktop.DBus"), Ropes.FromString("/org/freedesktop/DBus"),
    "org.freedesktop.DBus.ListNames");
  IF (OvaSpawn.Capture(a, names, status) = 0) & (status = 0) THEN
    pos := 0; more := TRUE;
    WHILE more & ~found DO
      name := FirstString(names, pos, pos, more);
      IF more & IsOkular(name) THEN
        tab := 1;
        REPEAT
          obj := TabObject(tab);
          GdbusCall(a, name, obj, "org.kde.okular.currentDocument");
          ok := (OvaSpawn.Capture(a, out, status) = 0) & (status = 0);
          IF ok THEN
            doc := FirstString(out, 0, end, ok);
            IF ok & Ropes.Equal(DocPath(doc), pdf) THEN found := TRUE; dest := name END
          END;
          INC(tab)
        UNTIL ~ok OR found OR (tab > MaxTabs)
      END
    END
  END;
  IF found THEN
    (* openDocument of a file open in a tab brings that tab forward
       (no new tab); then the tab turns to the page. *)
    GdbusCall(a, dest, Ropes.FromString(OkularShell), "org.kde.okular.openDocument");
    OvaSpawn.AddRope(a, FileUrl(pdf));
    found := (OvaSpawn.Capture(a, out, status) = 0) & (status = 0);
    IF found THEN
      GdbusCall(a, dest, obj, "org.kde.okular.goToPage");
      OvaSpawn.AddRope(a, OvaText.Int(index));
      found := (OvaSpawn.Capture(a, out, status) = 0) & (status = 0)
    END
  END;
  RETURN found
END OkularTurn;

(* ---- Opening ---- *)

(* Shows printed page page of pdf (an absolute path, as Choose gives)
   in v. FALSE, with msg saying why, if the viewer couldn't be started;
   TRUE with msg set if the user has more to do (xdg-open can't turn to
   a page), and with msg NIL if not. *)
PROCEDURE Open*(VAR v: Viewer; pdf: Rope; page: INTEGER; VAR msg: Rope): BOOLEAN;
  VAR a: OvaSpawn.Args; p: OvaSpawn.Process; err, index: INTEGER;
BEGIN
  msg := NIL; err := 0;
  index := OvaRules.PdfIndex(page);
  IF (v.kind = Okular) & OkularTurn(pdf, index) THEN
    (* turned over D-Bus; without gdbus, OkularTurn is FALSE *)
  ELSE
    Command(v, pdf, page, a);
    IF v.kind = Mupdf THEN
      IF OvaSpawn.Terminate(lastMupdf) THEN END;
      err := OvaSpawn.Detached(a, lastMupdf)
    ELSE
      err := OvaSpawn.Detached(a, p)
    END;
    IF err # 0 THEN
      msg := Ropes.FromString("can't start ");
      msg := Ropes.Cat(msg, OvaSpawn.Arg(a, 0));
      OvaText.Add(msg, ": ");
      msg := Ropes.Cat(msg, OvaSpawn.ErrorText(err))
    ELSIF v.kind = XdgOpen THEN
      msg := Ropes.FromString("xdg-open can't turn to a page: turn to page ");
      OvaText.AddInt(msg, page);
      OvaText.Add(msg, " (the PDF's page ");
      OvaText.AddInt(msg, index);
      OvaText.Add(msg, ")")
    END
  END;
  RETURN err = 0
END Open;

(* Ends the mupdf Open started last, if it is still running. *)
PROCEDURE EndMupdf*;
BEGIN IF OvaSpawn.Terminate(lastMupdf) THEN END
END EndMupdf;

(* The mupdf Open started last, for the tests: its pid, 0 for none or
   ended. *)
PROCEDURE LastMupdf*(): INTEGER;
  VAR pid: INTEGER;
BEGIN
  pid := 0;
  IF OvaSpawn.Alive(lastMupdf) THEN pid := lastMupdf.pid END;
  RETURN pid
END LastMupdf;

BEGIN
  okular := "okular"; evince := "evince"; mupdf := "mupdf";
  xdgOpen := "xdg-open"; gdbus := "gdbus";
  OvaSpawn.None(lastMupdf)
END OvaViewer.
