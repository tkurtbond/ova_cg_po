MODULE OvaSpawn; (* Running other programs: the rulebook's viewer and its D-Bus queries *)

(* PLAN.md, "The rulebook viewer": a viewer is started detached, in a
   session of its own, so a hangup of the program's terminal doesn't
   end it (Platform.System's did), and a failed start comes back as an
   errno instead of a shell's message on the terminal. Capture runs a
   program and returns its standard output, for gdbus. A program is an
   argument vector built with Clear and Add, run with execvp: never a
   shell command line, so nothing needs quoting. The work is in the C
   part, OvaSpawn.c. Needs no display, and imports no pofltk. *)

IMPORT SYSTEM, Ropes;

CONST
  (* The bytes an argument vector holds, its strings' 0Xs included. *)
  MaxArgs = 8192;
  (* errno values the module returns itself (Linux's). *)
  ENOENT* = 2;
  ESRCH* = 3;
  EINVAL* = 22;
  E2BIG* = 7;

TYPE
  Rope* = Ropes.Rope;

  (* An argument vector: n strings, each ended by 0X, packed in
     buf[0 .. len-1]. One that didn't fit sets overflow, and running it
     fails with E2BIG. *)
  Args* = RECORD
    buf: ARRAY MaxArgs OF CHAR;
    len, n: INTEGER;
    overflow: BOOLEAN
  END;

  (* A program Detached started: its pid, and when it started, which
     tells it from a later process given the same pid. pid = 0 for
     none. *)
  Process* = RECORD
    pid-: INTEGER;
    start: SYSTEM.INT64
  END;

PROCEDURE ["C", "ova_spawn_detached"] CDetached(buf: SYSTEM.ADDRESS; n: SYSTEM.INT32;
  pid: SYSTEM.ADDRESS): SYSTEM.INT32;
PROCEDURE ["C", "ova_spawn_capture"] CCapture(buf: SYSTEM.ADDRESS; n: SYSTEM.INT32;
  fd, pid: SYSTEM.ADDRESS): SYSTEM.INT32;
PROCEDURE ["C", "ova_spawn_read"] CRead(fd: SYSTEM.INT32; buf: SYSTEM.ADDRESS;
  len: SYSTEM.INT64): SYSTEM.INT64;
PROCEDURE ["C", "ova_spawn_finish"] CFinish(fd, pid: SYSTEM.INT32): SYSTEM.INT32;
PROCEDURE ["C", "ova_spawn_start_time"] CStartTime(pid: SYSTEM.INT32): SYSTEM.INT64;
PROCEDURE ["C", "ova_spawn_terminate"] CTerminate(pid: SYSTEM.INT32; start: SYSTEM.INT64): SYSTEM.INT32;
PROCEDURE ["C", "ova_spawn_on_path"] COnPath(name: SYSTEM.ADDRESS): SYSTEM.INT32;
PROCEDURE ["C", "ova_spawn_error_text"] CErrorText(err: SYSTEM.INT32; buf: SYSTEM.ADDRESS;
  len: SYSTEM.INT32);
PROCEDURE ["C", "ova_spawn_session"] CSession(pid: SYSTEM.INT32): SYSTEM.INT32;

(* ---- Argument vectors ---- *)

PROCEDURE Clear*(VAR a: Args);
BEGIN a.len := 0; a.n := 0; a.overflow := FALSE
END Clear;

(* Appends s, up to its first 0X, as the next argument. *)
PROCEDURE Add*(VAR a: Args; s: ARRAY OF CHAR);
  VAR i: INTEGER;
BEGIN
  i := 0;
  WHILE (i < LEN(s)) & (s[i] # 0X) DO INC(i) END;
  IF a.overflow OR (a.len + i + 1 > MaxArgs) THEN
    a.overflow := TRUE
  ELSE
    i := 0;
    WHILE (i < LEN(s)) & (s[i] # 0X) DO a.buf[a.len] := s[i]; INC(a.len); INC(i) END;
    a.buf[a.len] := 0X; INC(a.len); INC(a.n)
  END
END Add;

(* Appends r as the next argument. A rope holding 0X would end the
   argument there, as C sees it; none of this program's do. *)
PROCEDURE AddRope*(VAR a: Args; r: Rope);
  VAR len: LONGINT;
BEGIN
  len := Ropes.Length(r);
  IF a.overflow OR (a.len + len + 1 > MaxArgs) THEN
    a.overflow := TRUE
  ELSE
    Ropes.Blit(r, 0, a.buf, a.len, len);
    INC(a.len, SHORT(len));
    a.buf[a.len] := 0X; INC(a.len); INC(a.n)
  END
END AddRope;

PROCEDURE Count*(VAR a: Args): INTEGER;
BEGIN RETURN a.n
END Count;

(* Argument i (0 is the program), for tests and messages; NIL past the
   end. *)
PROCEDURE Arg*(VAR a: Args; i: INTEGER): Rope;
  VAR p, start: INTEGER;
BEGIN
  IF (i < 0) OR (i >= a.n) THEN RETURN NIL END;
  p := 0;
  WHILE i > 0 DO
    WHILE a.buf[p] # 0X DO INC(p) END;
    INC(p); DEC(i)
  END;
  start := p;
  WHILE a.buf[p] # 0X DO INC(p) END;
  RETURN Ropes.FromSubstring(a.buf, start, p - start)
END Arg;

(* ---- Running ---- *)

(* Starts a's program detached (OvaSpawn.c): in its own session, with
   standard input, output and error on /dev/null, never a zombie of
   ours. p is the program; 0, or the errno of a failed start, whose p
   is none. *)
PROCEDURE Detached*(VAR a: Args; VAR p: Process): INTEGER;
  VAR pid, err: SYSTEM.INT32;
BEGIN
  p.pid := 0; p.start := -1;
  IF a.overflow THEN RETURN E2BIG END;
  err := CDetached(SYSTEM.ADR(a.buf), a.n, SYSTEM.ADR(pid));
  IF err = 0 THEN
    p.pid := pid;
    (* The program may already have ended; then start is -1, and
       Terminate leaves the pid alone. *)
    p.start := CStartTime(pid)
  END;
  RETURN err
END Detached;

(* Runs a's program and waits for it, with its standard output in out
   and its standard input and error on /dev/null. status is its exit
   status, or -1 if a signal ended it. 0, or the errno of a failed
   start, when out is NIL and status -1. *)
PROCEDURE Capture*(VAR a: Args; VAR out: Rope; VAR status: INTEGER): INTEGER;
  VAR fd, pid, err: SYSTEM.INT32; got: LONGINT; chunk: ARRAY 4096 OF CHAR;
BEGIN
  out := NIL; status := -1;
  IF a.overflow THEN RETURN E2BIG END;
  err := CCapture(SYSTEM.ADR(a.buf), a.n, SYSTEM.ADR(fd), SYSTEM.ADR(pid));
  IF err = 0 THEN
    REPEAT
      got := SYSTEM.VAL(LONGINT, CRead(fd, SYSTEM.ADR(chunk), LEN(chunk)));
      IF got > 0 THEN out := Ropes.Cat(out, Ropes.FromSubstring(chunk, 0, got)) END
    UNTIL got <= 0;
    status := CFinish(fd, pid)
  END;
  RETURN err
END Capture;

(* ---- Processes ---- *)

PROCEDURE None*(VAR p: Process);
BEGIN p.pid := 0; p.start := -1
END None;

(* Whether p is still running: the same process, not a later one given
   its pid. *)
PROCEDURE Alive*(VAR p: Process): BOOLEAN;
BEGIN RETURN (p.pid > 0) & (p.start >= 0) & (CStartTime(p.pid) = p.start)
END Alive;

(* Ends p with SIGTERM, if it is still running, and makes it none. Only
   a process this program started is ended, never one found by name,
   which could be the user's own. *)
PROCEDURE Terminate*(VAR p: Process): BOOLEAN;
  VAR ok: BOOLEAN;
BEGIN
  ok := (p.pid > 0) & (CTerminate(p.pid, p.start) = 0);
  None(p);
  RETURN ok
END Terminate;

(* pid's session, -1 if there is no such process: for tests. *)
PROCEDURE Session*(pid: INTEGER): INTEGER;
BEGIN RETURN CSession(pid)
END Session;

(* ---- Finding programs ---- *)

(* Whether execvp would find name and could run it: a name with a "/"
   as it is, any other in PATH. *)
PROCEDURE OnPath*(name: ARRAY OF CHAR): BOOLEAN;
  VAR s: ARRAY 1024 OF CHAR;
BEGIN
  (* A copy, so the C part is sure of a 0X. *)
  COPY(name, s);
  RETURN COnPath(SYSTEM.ADR(s)) # 0
END OnPath;

(* err's text, as strerror gives it ("No such file or directory"). *)
PROCEDURE ErrorText*(err: INTEGER): Rope;
  VAR s: ARRAY 256 OF CHAR;
BEGIN
  CErrorText(err, SYSTEM.ADR(s), LEN(s));
  RETURN Ropes.FromString(s)
END ErrorText;

END OvaSpawn.
