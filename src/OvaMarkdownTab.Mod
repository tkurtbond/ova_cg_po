MODULE OvaMarkdownTab; (* The window's last tab: the character's sheet in Markdown, to copy or save *)

(* PLAN.md, "The Markdown sheet". The sheet OvaMarkdown makes, shown as
   text the user can select, with Copy, which puts all of it on the
   clipboard, and Save Markdown..., which writes it to a file. Inline,
   checked, shows the inline paragraph instead (OvaMarkdown.Inline), and
   Copy and Save Markdown... take that.

   OvaWindow owns the character: it builds this tab inside its Tabs
   (Build) and shows the character here again after each change
   (Show), so the text is always the character's. What would wait for
   the user -- a message, the file chooser -- goes through procedure
   variables a test sets, as OvaWindow's do. *)

IMPORT Fl, FlButtons, FlDialogs, FlText, OvaCharacter, OvaMarkdown, OvaText, Ropes;

CONST
  Row = 25;
  LeftX = 10; ColumnW = 620;

TYPE Rope = Ropes.Rope;

VAR
  sheet-: Rope;                    (* the text shown *)
  display-: FlText.TextDisplay;
  buffer: FlText.TextBuffer;
  copy-, save-: FlButtons.Button;
  inline-: FlButtons.CheckButton;  (* checked: the inline paragraph *)
  character: OvaCharacter.Character;  (* the character shown *)
  (* The character's name, for the file chooser's suggestion; NIL:
     none. *)
  name: Rope;

  (* tell shows a message; choosePath asks where to save the sheet,
     suggesting suggested (NIL: nothing). The window's dialogs; a test
     sets its own. *)
  tell*: PROCEDURE (text: Rope);
  choosePath*: PROCEDURE (suggested: Rope; VAR path: Rope): BOOLEAN;

PROCEDURE DialogTell(text: Rope);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(text); FlDialogs.Message(s^)
END DialogTell;

PROCEDURE DialogPath(suggested: Rope; VAR p: Rope): BOOLEAN;
  VAR c: FlDialogs.NativeFileChooser; path: ARRAY 4096 OF CHAR; filter: ARRAY 32 OF CHAR; s: OvaText.String;
    ok: BOOLEAN;
BEGIN
  NEW(c); FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseSaveFile);
  c.SetTitle("Save the Markdown sheet as"); c.SetOptions(FlDialogs.SaveAsConfirm);
  filter := "Markdown *.md"; filter[8] := 9X;  (* FLTK's "name<tab>pattern" *)
  c.SetFilter(filter);
  IF suggested # NIL THEN s := OvaText.Chars(suggested); c.SetPresetFile(s^) END;
  ok := c.Show() = FlDialogs.Chosen;
  IF ok THEN c.FileName(0, path); p := Ropes.FromString(path); ok := p # NIL END;
  c.Close;
  RETURN ok
END DialogPath;

(* Shows c's sheet, or its inline paragraph if Inline is checked. *)
PROCEDURE Show*(c: OvaCharacter.Character);
  VAR s: OvaText.String;
BEGIN
  character := c;
  IF inline.Value() THEN sheet := OvaMarkdown.Inline(c) ELSE sheet := OvaMarkdown.Sheet(c) END;
  name := c.name;
  s := OvaText.Chars(sheet); buffer.SetText(s^)
END Show;

(* Inline: the character shown again, the other way. *)
PROCEDURE InlineAction(w: Fl.Widget);
BEGIN IF character # NIL THEN Show(character) END
END InlineAction;

(* Copy: the whole sheet on the clipboard. *)
PROCEDURE CopyAction(w: Fl.Widget);
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(sheet); Fl.Copy(s^, Fl.Clipboard)
END CopyAction;

(* Save Markdown...: the sheet in a file the user chooses, the
   character's name suggested: NAME.md, or NAME-inline.md for the
   inline paragraph. *)
PROCEDURE SaveAction(w: Fl.Widget);
  VAR p, msg, suggested: Rope; s: OvaText.String;
BEGIN
  IF name = NIL THEN suggested := NIL
  ELSIF inline.Value() THEN suggested := Ropes.Cat(name, Ropes.FromString("-inline.md"))
  ELSE suggested := Ropes.Cat(name, Ropes.FromString(".md"))
  END;
  IF choosePath(suggested, p) THEN
    s := OvaText.Chars(p);
    IF ~OvaMarkdown.Save(sheet, s^, msg) THEN tell(msg) END
  END
END SaveAction;

(* Opens the tab, as a child of the group being built, at x, y, w by
   h. *)
PROCEDURE Build*(tab: Fl.Group; x, y, w, h: INTEGER);
  CONST Top = 10;
BEGIN
  Fl.OpenGroup(tab, x, y, w, h, "Markdown");
  NEW(copy); FlButtons.OpenButton(copy, LeftX, y + Top, 80, Row, "Copy");
  copy.action := CopyAction; copy.SetTooltip("Put the whole sheet on the clipboard");
  NEW(save); FlButtons.OpenButton(save, LeftX + 85, y + Top, 150, Row, "Save Markdown...");
  save.action := SaveAction;
  NEW(inline); FlButtons.OpenCheckButton(inline, LeftX + 245, y + Top, 100, Row, "Inline");
  inline.action := InlineAction;
  inline.SetTooltip("Show the character as one paragraph, as an adventure's cast lists it");
  NEW(buffer); FlText.OpenBuffer(buffer);
  NEW(display); FlText.OpenTextDisplay(display, LeftX, y + Top + Row + 10, ColumnW, h - Top - Row - 20, "");
  display.SetBuffer(buffer); display.SetTextFont(Fl.Courier);
  display.SetWrapMode(FlText.WrapAtBounds, 0);
  tab.End
END Build;

(* Gives up the buffer, after the window is deleted. *)
PROCEDURE Close*;
BEGIN
  IF buffer # NIL THEN buffer.Close END;
  buffer := NIL; display := NIL; copy := NIL; save := NIL; inline := NIL; sheet := NIL; name := NIL;
  character := NIL
END Close;

BEGIN
  sheet := NIL; name := NIL; buffer := NIL; display := NIL; copy := NIL; save := NIL; inline := NIL;
  character := NIL;
  tell := DialogTell; choosePath := DialogPath
END OvaMarkdownTab.
