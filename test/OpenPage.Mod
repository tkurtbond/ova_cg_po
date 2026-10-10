MODULE OpenPage; (* test/viewer.sh's driver: OvaViewer.Open with a real viewer *)

(* OpenPage VIEWER PDF PAGE...
   Opens each printed PAGE of PDF in VIEWER (as OvaViewer.Parse takes
   it), one after another in this one process, PAUSE ms apart (3000),
   as the program's ? buttons would: so a mupdf started for one page is
   ended before the next. Prints each Open's message, and exits 1 if
   one fails. *)

IMPORT Args, OvaViewer, Out, Platform, Ropes;

CONST Pause = 3000;

VAR
  v: OvaViewer.Viewer;
  arg: ARRAY 4096 OF CHAR;
  pdf, msg: Ropes.Rope;
  page: LONGINT;
  i: INTEGER;
  ok: BOOLEAN;

PROCEDURE Message(r: Ropes.Rope);
  VAR s: ARRAY 512 OF CHAR;
BEGIN
  Ropes.ToString(r, s); Out.String(s); Out.Ln
END Message;

BEGIN
  ok := Args.argc >= 4;
  IF ok THEN
    Args.Get(1, arg);
    ok := OvaViewer.Parse(Ropes.FromString(arg), v)
  END;
  IF ~ok THEN
    Out.String("usage: OpenPage VIEWER PDF PAGE..."); Out.Ln; Platform.Exit(2)
  END;
  Args.Get(2, arg); pdf := Ropes.FromString(arg);
  FOR i := 3 TO Args.argc - 1 DO
    IF i > 3 THEN Platform.Delay(Pause) END;
    page := 0; Args.GetInt(i, page);
    IF ~OvaViewer.Open(v, pdf, SHORT(page), msg) THEN ok := FALSE END;
    IF msg # NIL THEN Message(msg) END
  END;
  IF ~ok THEN Platform.Exit(1) END
END OpenPage.
