MODULE TestResize; (* OvaWindow: resized, everything in it stretched to the window's size *)

(* Needs a display: run by make test-gui, as TestWindow is. The window,
   never shown, is resized as a window manager would (Size, which FLTK
   passes to its Resize), larger and back. FLTK stretches the widgets;
   the window fits what it doesn't, after: the menu bar and the tabs'
   bar keep their height, the combat box's rows stretch with the box,
   the traits' names' column with its browser, the portrait with its
   box, keeping its proportions. A row made again after a resize (an
   attack removed) is stretched too. *)

IMPORT Check, Fl, FlImages, FlTest, OvaBackground, OvaWidgets, OvaWindow, Platform, Ropes;

CONST
  ImagePath = "../obj/resize-face.png";
  ImageW = 300; ImageH = 400;          (* larger than the box, and in its proportions taller *)
  PortraitH = 250;                     (* the box's first height *)
  Width = 640; Height = 800;           (* the window's first size, *)
  BigW = 960; BigH = 1200;             (* and the one it is resized to *)
  BarHeight = 25; TabHeight = 25;
  ColumnW = 620; RowW = 600; Row = 25; RowH = 30; LeftX = 10; NameW = 180;
  BoxH = 17 * 30 + 4;                  (* the combat box's first height *)

TYPE Rope = Ropes.Rope;

VAR
  chosenImage: Rope;
  bits: POINTER TO ARRAY OF CHAR;
  img: FlImages.Image;
  r: OvaWindow.AttackRow;
  path: ARRAY 64 OF CHAR;
  firstNameW, i: INTEGER;
  ok: BOOLEAN;

PROCEDURE R(s: ARRAY OF CHAR): Rope;
BEGIN RETURN Ropes.FromString(s)
END R;

PROCEDURE Tell(text: Rope);
BEGIN
END Tell;

PROCEDURE ChooseImage(VAR p: Rope): BOOLEAN;
BEGIN p := chosenImage; RETURN p # NIL
END ChooseImage;

PROCEDURE Round(x: REAL): INTEGER;
BEGIN RETURN SHORT(ENTIER(x + 0.5))
END Round;

(* Whether a and b differ by at most d: FLTK rounds each edge. *)
PROCEDURE Near(a, b, d: INTEGER): BOOLEAN;
BEGIN RETURN ABS(a - b) <= d
END Near;

(* Whether the combat box's rows are its rows stretched by the box's
   width and height over its first ones: each the first row's size so
   stretched, its ROLL box as wide and as far along, and each as far
   below the one before. *)
PROCEDURE RowsFit(): BOOLEAN;
  VAR r: OvaWindow.AttackRow; sx, sy: REAL; ok: BOOLEAN; box: Fl.Widget; i: INTEGER;
BEGIN
  box := OvaWindow.attackBox;
  sx := box.W() / ColumnW; sy := box.H() / BoxH;
  r := OvaWindow.rows; ok := r # NIL; i := 0;
  WHILE ok & (r # NIL) DO
    ok := Near(r.W(), Round(RowW * sx), 1) & Near(r.H(), Round(Row * sy), 1)
      & Near(r.Y() - box.Y(), Round((2 + i * RowH) * sy), 1)
      & Near(r.roll.W(), Round(OvaWidgets.Width * sx), 1)
      & Near(r.roll.X() - box.X(), Round((2 + NameW + 8) * sx), 2);
    INC(i); r := r.nextRow
  END;
  RETURN ok
END RowsFit;

(* Whether the portrait shown fills its box's height, within its width:
   the image is taller than wide, as the box. *)
PROCEDURE PortraitFits(): BOOLEAN;
  VAR img: FlImages.Image; box: Fl.Widget;
BEGIN
  img := OvaBackground.image; box := OvaBackground.portrait;
  RETURN (img # NIL) & (img.H() = box.H() - 6) & (img.W() <= box.W() - 6)
END PortraitFits;

(* Resizes the window to w by h, and lets it fit what FLTK doesn't
   stretch. *)
PROCEDURE Resize(w, h: INTEGER);
BEGIN OvaWindow.window.Size(w, h); FlTest.Settle
END Resize;

BEGIN
  OvaWindow.Build;
  OvaWindow.tell := Tell; OvaBackground.tell := Tell;
  OvaBackground.chooseImage := ChooseImage;

  (* A portrait: a gradient, ImageW by ImageH, as a PNG. *)
  NEW(bits, ImageW * ImageH * 3);
  FOR i := 0 TO ImageW * ImageH * 3 - 1 DO bits[i] := CHR(i MOD 251) END;
  NEW(img); FlImages.OpenRGB(img, bits^, ImageW, ImageH, 3, 0);
  Check.Check(img.SavePNG(ImagePath), "an image written to choose");
  img.Close;

  ok := OvaWindow.Load(R("data/Ai.yaml"));
  chosenImage := R(ImagePath); OvaBackground.choosePortrait.DoCallback;
  Check.Check(ok & (OvaWindow.rows # NIL) & (OvaWindow.rows.nextRow # NIL), "a character with two attacks");
  r := OvaWindow.rows;
  Check.Check((OvaWindow.window.W() = Width) & (OvaWindow.window.H() = Height) & (r.W() = RowW) & (r.H() = Row)
    & (r.roll.W() = OvaWidgets.Width) & (r.roll.X() = LeftX + 2 + NameW + 8) & RowsFit(), "at first: the rows as built");
  firstNameW := OvaWindow.abilities.nameW;
  Check.Check(firstNameW = OvaWindow.abilities.browser.W() - 70, "the names' column, as built");
  Check.Check(PortraitFits(), "the portrait fits its box");

  (* ---- Larger ---- *)
  Resize(BigW, BigH);
  Check.Check((OvaWindow.window.W() = BigW) & (OvaWindow.window.H() = BigH), "resized larger");
  Check.Check((OvaWindow.bar.H() = BarHeight) & (OvaWindow.characterChoice.H() = BarHeight)
    & (OvaWindow.characterChoice.X() + OvaWindow.characterChoice.W() = BigW),
    "the menu bar and the characters' choice: as high, across the window");
  Check.Check((OvaWindow.sheetTab.Y() = BarHeight + TabHeight) & (OvaWindow.sheetTab.W() = BigW)
    & (OvaWindow.sheetTab.H() = BigH - BarHeight - TabHeight) & (OvaWindow.markdownTab.W() = BigW)
    & (OvaWindow.markdownTab.H() = BigH - BarHeight - TabHeight), "the tabs' bar as high, the pages filling the rest");
  Check.Check((OvaWindow.attackBox.W() = Round(ColumnW * 1.5)) & (OvaWindow.abilities.browser.W() > firstNameW + 70)
    & (OvaWindow.combatNotes.W() = Round(ColumnW * 1.5)), "the widgets stretched");
  Check.Check(RowsFit() & (OvaWindow.rows.W() > RowW), "the combat box's rows stretched with it");
  Check.Check(OvaWindow.abilities.nameW = OvaWindow.abilities.browser.W() - 70, "the Abilities' names' column too");
  Check.Check(OvaWindow.weaknesses.nameW = OvaWindow.weaknesses.browser.W() - 70, "and the Weaknesses'");
  Check.Check(PortraitFits() & (OvaBackground.image.H() > PortraitH), "the portrait fits its larger box");

  (* A row made again, after a resize. *)
  OvaWindow.rows.remove.DoCallback; FlTest.Settle;
  Check.Check(RowsFit() & (OvaWindow.rows.nextRow = NIL) & (OvaWindow.rows.W() > RowW),
    "an attack removed: the row left, stretched");

  (* ---- Back ---- *)
  Resize(Width, Height);
  r := OvaWindow.rows;
  Check.Check((OvaWindow.sheetTab.H() = Height - BarHeight - TabHeight) & (r.W() = RowW) & (r.H() = Row)
    & (r.roll.W() = OvaWidgets.Width) & (r.roll.X() = LeftX + 2 + NameW + 8),
    "back to the first size: the rows as built");
  Check.Check((OvaWindow.abilities.nameW = firstNameW) & PortraitFits(), "the column and the portrait too");

  OvaWindow.Close;
  COPY(ImagePath, path); IF Platform.Unlink(path) = 0 THEN END;
  Check.Check(Fl.OpenWidgets() = 0, "every widget is deleted");
  Check.Summary
END TestResize.
