MODULE OvaPaths; (* File paths: made absolute, a file's directory, and one path relative to a directory *)

(* PLAN.md, "The second tab": a character's portrait is saved as a path
   relative to its YAML file (Changes to ova_fmt, `portrait`), so the
   window finds the image from the file's directory, and Save As to
   another directory rebases the path. Paths here are text alone: no
   file is looked at, and symbolic links aren't followed, so "a/../b"
   is "b" even where a is a link. A path is "/"-separated; an empty
   one is NIL. *)

IMPORT Ropes, Platform;

TYPE
  Rope = Ropes.Rope;
  Parts = POINTER TO ARRAY OF Rope;

(* path's parts between "/"s, without empty ones and ".", each ".."
   taking out the part before it (one at the start of an absolute path
   is dropped; of a relative one, kept). n: how many. *)
PROCEDURE Split(path: Rope; VAR parts: Parts; VAR n: INTEGER);
  VAR len, start, i: LONGINT; part: Rope; abs: BOOLEAN;
BEGIN
  len := Ropes.Length(path); abs := (len > 0) & (Ropes.Fetch(path, 0) = "/");
  NEW(parts, len DIV 2 + 1); n := 0;
  start := 0;
  WHILE start <= len DO
    i := Ropes.IndexChar(path, "/", start);
    IF i < 0 THEN i := len END;
    part := Ropes.Substring(path, start, i - start);
    IF (part = NIL) OR Ropes.EqualString(part, ".") THEN
    ELSIF Ropes.EqualString(part, "..") & (n > 0) & ~Ropes.EqualString(parts[n - 1], "..") THEN DEC(n)
    ELSIF Ropes.EqualString(part, "..") & abs THEN
    ELSE parts[n] := part; INC(n)
    END;
    start := i + 1
  END
END Split;

(* parts[from..n-1] joined by "/", after "/" if abs. *)
PROCEDURE Join(parts: Parts; from, n: INTEGER; abs: BOOLEAN): Rope;
  VAR r: Rope; i: INTEGER;
BEGIN
  IF abs THEN r := Ropes.FromString("/") ELSE r := NIL END;
  FOR i := from TO n - 1 DO
    IF i > from THEN r := Ropes.AppendChar(r, "/") END;
    r := Ropes.Cat(r, parts[i])
  END;
  RETURN r
END Join;

PROCEDURE IsAbsolute*(path: Rope): BOOLEAN;
BEGIN RETURN (path # NIL) & (Ropes.Fetch(path, 0) = "/")
END IsAbsolute;

(* path without "." parts, doubled "/"s, a "/" at the end, or ".."
   after a name: "a/./b//../c/" is "a/c". "." for a relative path that
   comes to nothing. *)
PROCEDURE Normalize*(path: Rope): Rope;
  VAR parts: Parts; n: INTEGER; r: Rope;
BEGIN
  Split(path, parts, n);
  r := Join(parts, 0, n, IsAbsolute(path));
  IF r = NIL THEN r := Ropes.FromString(".") END;
  RETURN r
END Normalize;

(* path made absolute against directory base (itself made absolute
   against the working directory), and normalized; NIL for NIL. *)
PROCEDURE Absolute*(path, base: Rope): Rope;
  VAR r: Rope;
BEGIN
  IF path = NIL THEN RETURN NIL END;
  IF IsAbsolute(path) THEN r := path
  ELSE
    IF ~IsAbsolute(base) THEN
      r := Ropes.FromString(Platform.CWD);
      IF base # NIL THEN r := Ropes.AppendChar(r, "/"); r := Ropes.Cat(r, base) END;
      base := r
    END;
    r := Ropes.AppendChar(base, "/"); r := Ropes.Cat(r, path)
  END;
  RETURN Normalize(r)
END Absolute;

(* The absolute directory file is in. *)
PROCEDURE Dir*(file: Rope): Rope;
  VAR abs: Rope; slash: LONGINT;
BEGIN
  abs := Absolute(file, NIL);
  slash := Ropes.RIndexChar(abs, "/", Ropes.Length(abs));
  IF slash <= 0 THEN RETURN Ropes.FromString("/") ELSE RETURN Ropes.Substring(abs, 0, slash) END
END Dir;

(* path (made absolute as Absolute does, against the working directory)
   relative to directory dir: "../images/a.png". "." for dir itself. *)
PROCEDURE Relative*(path, dir: Rope): Rope;
  VAR p, d: Parts; np, nd, k, i: INTEGER; r: Rope;
BEGIN
  Split(Absolute(path, NIL), p, np); Split(Absolute(dir, NIL), d, nd);
  k := 0;
  WHILE (k < np) & (k < nd) & Ropes.Equal(p[k], d[k]) DO INC(k) END;
  r := NIL;
  FOR i := k TO nd - 1 DO
    IF r # NIL THEN r := Ropes.AppendChar(r, "/") END;
    r := Ropes.Cat(r, Ropes.FromString(".."))
  END;
  IF k < np THEN
    IF r # NIL THEN r := Ropes.AppendChar(r, "/") END;
    r := Ropes.Cat(r, Join(p, k, np, FALSE))
  END;
  IF r = NIL THEN r := Ropes.FromString(".") END;
  RETURN r
END Relative;

(* path, given relative to directory from, rewritten relative to
   directory to: a portrait's path when its YAML file moves. An
   absolute path is made relative to to: a character never saved (from
   NIL) holds the absolute path it was given until its first save. A
   relative path with no from to resolve it against stays as it is. *)
PROCEDURE Rebase*(path, from, to: Rope): Rope;
BEGIN
  IF path = NIL THEN RETURN NIL END;
  IF (from = NIL) & ~IsAbsolute(path) THEN RETURN path END;
  RETURN Relative(Absolute(path, from), to)
END Rebase;

END OvaPaths.
