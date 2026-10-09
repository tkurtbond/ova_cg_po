MODULE OvaCg; (* po_ova_cg: an OVA character generator; the main module *)

(* PLAN.md, "Starting": the command line, then a display, then the
   window. The program can't do anything without a window, so with no
   display it says so and exits with status 1, before FLTK is asked to
   open one (FLTK's own "Can't open display" is for a display that is set
   but can't be opened). *)

IMPORT ArgParser, Err, Fl, OvaWindow, Out, Platform;

CONST
  Program = "po_ova_cg";
  NoDisplayStatus = 1;

VAR
  parser: ArgParser.Parser;
  helpShown: BOOLEAN;

PROCEDURE DoHelp(): BOOLEAN;
BEGIN parser.Usage; helpShown := TRUE; RETURN FALSE
END DoHelp;

(* A file to open is Phase 3's (PLAN.md, "Build order"). *)
PROCEDURE DoArgument(startIdx: INTEGER; VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN
  Out.Flush;
  Err.String(Program); Err.String(": opening a file isn't written yet: "); Err.String(arg); Err.Ln;
  Platform.Exit(ArgParser.UsageErrorStatus);
  RETURN FALSE
END DoArgument;

(* A mistake on the command line ends the program with
   ArgParser.UsageErrorStatus (2). *)
PROCEDURE ParseCommandLine;
BEGIN
  parser := ArgParser.NewParser("po_ova_cg [options]", DoArgument);
  parser.AddOption(ArgParser.MakeOption("h", "help", "Display this text.", DoHelp));
  parser.ParseArguments(1)
END ParseCommandLine;

(* TRUE if the environment variable name is set and not empty. *)
PROCEDURE IsSet(name: ARRAY OF CHAR): BOOLEAN;
  VAR val: ARRAY 2 OF CHAR;
BEGIN RETURN Platform.getEnv(name, val) & (val[0] # 0X)
END IsSet;

(* With no display, the reason and, in tmux, where it came from (PLAN.md,
   "Findings": a tmux session last attached from a terminal without a
   display drops DISPLAY and WAYLAND_DISPLAY from new panes). *)
PROCEDURE RequireDisplay;
BEGIN
  IF ~IsSet("DISPLAY") & ~IsSet("WAYLAND_DISPLAY") THEN
    Out.Flush;
    Err.String(Program); Err.String(": no display: neither DISPLAY nor WAYLAND_DISPLAY is set"); Err.Ln;
    IF IsSet("TMUX") THEN
      Err.String(Program);
      Err.String(": in tmux, the session may have been attached from a terminal without one;");
      Err.String(" reattach from the desktop, or set them from `tmux show-environment -g`"); Err.Ln
    END;
    Platform.Exit(NoDisplayStatus)
  END
END RequireDisplay;

BEGIN
  helpShown := FALSE;
  ParseCommandLine;
  IF ~helpShown THEN
    RequireDisplay;
    OvaWindow.Build;
    OvaWindow.window.Show;
    Fl.Run
  END
END OvaCg.
