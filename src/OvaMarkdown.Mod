MODULE OvaMarkdown; (* A character's sheet in Markdown: ova_fmt_po's -M *)

(* PLAN.md, "The Markdown sheet". The character as it would be saved,
   read back as ova_fmt_po reads it (OvaSave.ToEntity), and formatted
   by ova_fmt_po's own OvaCommon, copied, as `ova_fmt_po -M` formats
   the saved file: so the sheet is the same text, and test/files.sh
   checks that it is. OvaOut keeps the output in a rope instead of
   writing it. *)

IMPORT OvaCharacter, OvaCommon, OvaConfig, OvaEntities, OvaOut, OvaSave, OvaText, Platform, Ropes, SYSTEM;

TYPE Rope = Ropes.Rope;

VAR
  fd: Platform.FileHandle;      (* Save's file, for PutChunk *)
  writeError: Platform.ErrorCode;

(* c's sheet; NIL if c couldn't be read back (a programmer's error). *)
PROCEDURE Sheet*(c: OvaCharacter.Character): Rope;
  VAR e: OvaEntities.Entity;
BEGIN
  e := OvaSave.ToEntity(c);
  IF e = NIL THEN RETURN NIL END;
  OvaConfig.format := OvaConfig.Markdown;
  OvaOut.ToRope;
  OvaCommon.ProcessEntity(e, 1);
  RETURN OvaOut.TakeRope()
END Sheet;

(* One leaf of the text Save writes: a Ropes.ChunkVisitor, so a
   module-level procedure. *)
PROCEDURE PutChunk(VAR chunk: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF LEN(chunk) > 0 THEN writeError := Platform.Write(fd, SYSTEM.ADR(chunk[0]), LEN(chunk)) END;
  RETURN writeError = 0
END PutChunk;

(* Writes text to the file at path, through path.tmp, which replaces it
   only once written, as OvaSave.SaveAll does. FALSE, with msg, if it
   couldn't be, the old file left as it was. Not through OvaOut, whose
   first write error stays for the rest of the run. *)
PROCEDURE Save*(text: Rope; path: ARRAY OF CHAR; VAR msg: Rope): BOOLEAN;
  VAR t: Rope; tmp, p: OvaText.String; e, e2: Platform.ErrorCode;
BEGIN
  msg := NIL;
  t := Ropes.FromString(path); OvaText.Add(t, ".tmp"); tmp := OvaText.Chars(t);
  e := Platform.New(tmp^, fd);
  IF e = 0 THEN
    writeError := 0; Ropes.IterateChunks(text, PutChunk); e := writeError;
    e2 := Platform.Close(fd);
    IF e = 0 THEN e := e2 END;
    p := OvaText.Chars(Ropes.FromString(path));
    IF e = 0 THEN e := Platform.Rename(tmp^, p^) END;
    IF e # 0 THEN e2 := Platform.Unlink(tmp^) END
  END;
  IF e # 0 THEN
    msg := Ropes.FromString("couldn't write "); OvaText.Add(msg, path);
    OvaText.Add(msg, " (error "); msg := Ropes.Cat(msg, OvaText.Int(e)); OvaText.Add(msg, ")");
    RETURN FALSE
  END;
  RETURN TRUE
END Save;

END OvaMarkdown.
