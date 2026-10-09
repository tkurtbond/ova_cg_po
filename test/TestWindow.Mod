MODULE TestWindow; (* OvaWindow: the window opens, and quits from the menu and the close button *)

(* Needs a display: run by make test-gui, under make test-headless or
   make test-sway (AGENTS.md: never on the desktop). Picking a menu item
   and the window's callback are driven directly, as pofltk's tests do. *)

IMPORT Check, Fl, OvaWindow;

VAR i: INTEGER;

(* Shows the window and lets FLTK put it on the screen. *)
PROCEDURE ShowIt;
BEGIN
  OvaWindow.window.Show;
  OvaWindow.window.WaitForExpose;
  IF Fl.Check() THEN END
END ShowIt;

BEGIN
  OvaWindow.Build;
  Check.Check(OvaWindow.window.IsOpen(), "the window opens");
  Check.Check(~OvaWindow.window.Shown(), "the window isn't shown until asked");
  i := OvaWindow.bar.FindIndex("&File/&Quit");
  Check.Check((i >= 0) & (i = OvaWindow.quitItem), "the menu bar has File > Quit");

  ShowIt;
  Check.Check(OvaWindow.window.Shown(), "the window is shown");
  OvaWindow.bar.Pick(OvaWindow.quitItem);
  IF Fl.Check() THEN END;
  Check.Check(~OvaWindow.window.Shown(), "File > Quit hides the window, which ends Fl.Run");

  ShowIt;
  Check.Check(OvaWindow.window.Shown(), "the window is shown again");
  OvaWindow.window.DoCallback;  (* what the window's close button does *)
  IF Fl.Check() THEN END;
  Check.Check(~OvaWindow.window.Shown(), "closing the window hides it");

  OvaWindow.Close;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestWindow.
