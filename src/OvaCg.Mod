MODULE OvaCg; (* ova_cg_po: an OVA character generator; the main module *)

(* PLAN.md, "Starting": the command line, then the file, then a
   display, then the window. A file that can't be opened is said on
   standard error, status 1, before a display is needed, as a mistake
   on the command line is (status 2). The program can't do anything
   without a window, so with no display it says so and exits with
   status 1, before FLTK is asked to open one (FLTK's own "Can't open
   display" is for a display that is set but can't be opened). *)

IMPORT ArgParser, Err, Fl, FlPreferences, OvaCharacter, OvaText, OvaViewer, OvaWindow, Out, Platform, Ropes;

CONST
  Program = "ova_cg_po";
  FailureStatus = 1;
  (* The preferences' file: $XDG_CONFIG_HOME (else ~/.config), then
     ova_cg_po/ova_cg_po.prefs (FLTK's vendor and application). *)
  Vendor = "ova_cg_po"; Application = "ova_cg_po";

VAR
  parser: ArgParser.Parser;
  helpShown: BOOLEAN;
  file: Ropes.Rope;  (* the file argument; NIL for none *)
  characters: OvaCharacter.Characters;  (* the file's; NIL for none *)
  preferences: FlPreferences.Preferences;

PROCEDURE Fail(status: INTEGER; a, b: ARRAY OF CHAR);
BEGIN
  Out.Flush;
  Err.String(Program); Err.String(": "); Err.String(a); Err.String(b); Err.Ln;
  Platform.Exit(status)
END Fail;

PROCEDURE DoHelp(): BOOLEAN;
BEGIN parser.Usage; helpShown := TRUE; RETURN FALSE
END DoHelp;

PROCEDURE DoRulebook(VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN OvaWindow.rulebookOption := Ropes.FromString(arg); RETURN TRUE
END DoRulebook;

PROCEDURE DoViewer(VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF ~OvaViewer.Parse(Ropes.FromString(arg), OvaWindow.viewer) THEN
    Fail(ArgParser.UsageErrorStatus,
      "--viewer takes okular, evince, mupdf, xdg-open, or a command with %f for the PDF: ", arg)
  END;
  OvaWindow.viewerOption := TRUE;
  RETURN TRUE
END DoViewer;

(* The one file to open. *)
PROCEDURE DoArgument(startIdx: INTEGER; VAR arg: ARRAY OF CHAR): BOOLEAN;
BEGIN
  IF file # NIL THEN Fail(ArgParser.UsageErrorStatus, "one file at a time: ", arg) END;
  file := Ropes.FromString(arg);
  RETURN TRUE
END DoArgument;

(* A mistake on the command line ends the program with
   ArgParser.UsageErrorStatus (2). *)
PROCEDURE ParseCommandLine;
BEGIN
  parser := ArgParser.NewParser("ova_cg_po [options] [file.yaml]", DoArgument);
  parser.AddOption(ArgParser.MakeOption("h", "help", "Display this text.", DoHelp));
  parser.AddOption(ArgParser.MakeStringOption("r", "rulebook",
    "The rulebook's PDF (else OVA_RULEBOOK, else the one chosen before, else ~/Reference/RPG/OVA/).",
    DoRulebook));
  parser.AddOption(ArgParser.MakeStringOption("v", "viewer",
    "okular, evince, mupdf, xdg-open, or a command: %f the PDF, %p its page, %l the printed page.", DoViewer));
  parser.ParseArguments(1)
END ParseCommandLine;

(* The file argument's characters, or a reason on standard error. *)
PROCEDURE LoadFile;
  VAR s: OvaText.String; msg: Ropes.Rope;
BEGIN
  s := OvaText.Chars(file);
  IF ~OvaCharacter.LoadAll(s^, characters, msg) THEN
    s := OvaText.Chars(msg); Fail(FailureStatus, s^, "")
  END
END LoadFile;

(* TRUE if the environment variable name is set and not empty. *)
PROCEDURE IsSet(name: ARRAY OF CHAR): BOOLEAN;
  VAR val: ARRAY 2 OF CHAR;
BEGIN RETURN Platform.getEnv(name, val) & (val[0] # 0X)
END IsSet;

(* With no display, the reason and, in tmux, where it came from (PLAN.md,
   "Findings": a tmux session last attached from a terminal without a
   display drops DISPLAY and WAYLAND_DISPLAY from new panes, and may keep
   a DISPLAY that is gone). Both unset is refused before FLTK is asked:
   FLTK would still try the socket wayland-0. *)
PROCEDURE RequireDisplay;
  VAR none, unset: BOOLEAN;
BEGIN
  unset := ~IsSet("DISPLAY") & ~IsSet("WAYLAND_DISPLAY");
  none := unset OR ~Fl.CanOpenDisplay();
  IF none THEN
    Out.Flush;
    Err.String(Program);
    IF unset THEN Err.String(": no display: neither DISPLAY nor WAYLAND_DISPLAY is set")
    ELSE Err.String(": no display: the one DISPLAY or WAYLAND_DISPLAY names can't be opened")
    END;
    Err.Ln;
    IF IsSet("TMUX") THEN
      Err.String(Program);
      Err.String(": in tmux, the session may have been attached from a terminal without one;");
      Err.String(" reattach from the desktop, or set them from `tmux show-environment -g`"); Err.Ln
    END;
    Platform.Exit(FailureStatus)
  END
END RequireDisplay;

BEGIN
  helpShown := FALSE; file := NIL; characters := NIL;
  ParseCommandLine;
  IF ~helpShown THEN
    IF file # NIL THEN LoadFile END;
    RequireDisplay;
    OvaWindow.Build;
    NEW(preferences); FlPreferences.Open(preferences, FlPreferences.User, Vendor, Application);
    OvaWindow.UsePreferences(preferences);
    OvaWindow.window.Show;
    IF characters # NIL THEN OvaWindow.Adopt(characters, file) END;
    Fl.Run;
    preferences.Close
  END
END OvaCg.
