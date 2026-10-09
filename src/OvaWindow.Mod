MODULE OvaWindow; (* The main window: its menu bar, and (later) its two tabs *)

(* PLAN.md, "The window". Phase 0 has the frame alone: the window and a
   menu bar with File > Quit. The window is kept in module variables,
   so that poc's collector sees it (FLTK's pointers it can't see) and a
   test can reach it. *)

IMPORT Fl, FlMenus;

CONST
  Width = 1280; Height = 800; BarHeight = 25;

VAR
  window-: Fl.DoubleWindow;
  bar-: FlMenus.MenuBar;
  body: Fl.Box;  (* fills the window under the menu bar until the tabs come *)
  quitItem-: INTEGER;  (* File > Quit's index in bar *)

(* File > Quit, and the window's close button: hide the window, which
   ends Fl.Run. Unsaved changes will be asked about here (PLAN.md). *)
PROCEDURE Quit*(w: Fl.Widget);
BEGIN window.Hide
END Quit;

(* Opens the window, not yet shown. *)
PROCEDURE Build*;
BEGIN
  NEW(window); Fl.OpenDoubleWindow(window, Width, Height, "OVA Character Generator");
  NEW(bar); FlMenus.OpenMenuBar(bar, 0, 0, Width, BarHeight, "");
  quitItem := bar.Add("&File/&Quit", ORD("q"), Fl.Command, Quit, {});
  NEW(body); Fl.OpenBox(body, 0, BarHeight, Width, Height - BarHeight, "");
  window.End;
  window.SetResizable(body);
  window.action := Quit
END Build;

(* Deletes the window and everything in it, for tests. *)
PROCEDURE Close*;
BEGIN
  window.Delete;
  window := NIL; bar := NIL; body := NIL
END Close;

END OvaWindow.
