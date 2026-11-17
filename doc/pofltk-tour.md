# A tour of ova_cg_po for pofltk readers

ova_cg_po is a complete [pofltk](https://github.com/tkurtbond/pofltk)
program: a window of about 3,600 lines of Oberon-2 over a model and
rules of about 3,400 more, with tests that drive the window on a
virtual display. This tour says where to look for each thing a pofltk
program usually needs, and why it is done that way. The README says how
to build it; you don't need to know the game to follow the code.

Names below are modules and procedures, not line numbers, so they stay
right as the code changes.

![The window's Character tab, showing Miho, one of the rulebook's sample
characters: the menu bar with the file's characters at its right, the
tabs, the Abilities and Weaknesses each with its page, their editors,
and the totals with an override box beside each](window.png)

*The Character tab with `test/data/Miho.yaml` open, on Xvfb.*

## How it is divided

| Part | Modules | Imports pofltk? |
|---|---|---|
| The rules and the numbers | `OvaRules`, `OvaCalc` | no |
| The character, loading and saving | `OvaCharacter`, `OvaSave`, `OvaPaths`, and the six modules copied from ova_fmt_po | no |
| The window | `OvaWindow`, `OvaWidgets`, `OvaTraitPanel`, `OvaBackground`, `OvaMarkdownTab` | yes |
| Its dialogs | `OvaAttackDialog`, `OvaLinkedDialog`, `OvaSettings` | yes |
| The main module | `OvaCg` | yes |

**Nothing below the window imports pofltk.** Every number the window
shows comes from `OvaCalc`, and no callback does arithmetic of its
own. A callback changes the model, asks it for the results, and shows
them. So the rules have tests that need no display, and the window
tests only check that the window shows what the model says.

## Starting and stopping: `OvaCg`

The main module's body is the whole life of the program:

1. parse the command line (ArgParser) and load the file, before any
   window exists, so a bad file is reported on standard error;
2. `RequireDisplay`: check for a display with `Fl.CanOpenDisplay`
   before building anything, so the program can say why it can't run,
   not just fail;
3. `OvaWindow.Build`, then open the preferences
   (`FlPreferences.Open(p, FlPreferences.User, vendor, application)`),
   `window.Show`, and `Fl.Run`;
4. after `Fl.Run` returns, close the preferences.

`Fl.Run` returns when the last window is hidden. File > Quit and the
window's close button both call `OvaWindow.Quit` (`window.action :=
Quit`). It asks whether to save first, and then hides the window. The
program never calls `exit` from inside a callback.

## The main window: `OvaWindow.Build`

- **The window is a type of its own.** `MainWindow` extends
  `Fl.DoubleWindowDesc` and overrides `Resize`. FLTK stretches the
  widgets, and the override starts a zero-length timer (`fit`, an
  `Fl.Timer` with an `action`) to lay out what FLTK doesn't stretch
  once the new size is settled.
- **The menu bar** is built with `bar.Add("&File/&Save", ORD("s"),
  Fl.Command, SaveAction, {})`: a path with `&` for the underlined
  key, a shortcut, its modifiers, the callback, and flags such as
  `FlMenus.MenuDivider` and `FlMenus.MenuToggle` (Character >
  Transformed form). `Add` returns the item's index, which is kept to
  grey out items later (`removeCharacterItem`).
- **A `Choice` sits in the menu bar's row**, at its right end, listing
  the file's characters.
- **Tabs**: `FlLayout.OpenTabs`. Each tab is a `Group`, built by its
  own module (`OvaBackground.Build`, `OvaMarkdownTab.Build`).
- **Resizing** is said once, at the end: `tabs.SetResizable(sheetTab)`,
  `window.SetResizable(tabs)`, and `window.SizeRange(Width, Height, 0,
  0)` for the smallest size. The menu bar keeps its height and the tabs'
  bar its own, and everything inside a tab stretches.

## Callbacks, and getting back to your own data

pofltk gives two ways to handle a widget's callback, and both are
used:

- **A procedure in `action`**: `b.action := SaveAction`, where
  `SaveAction(w: Fl.Widget)` is a module-level procedure. Most buttons
  and inputs work this way. Where several widgets share one procedure,
  it tells them apart by comparing `w` (`OvaWindow.TextAction`), or
  finds the record a widget belongs to (`OvaWindow.RowOf` searches the
  attack rows for the row whose Edit or Remove button `w` is).
- **A type-bound `Callback`**: extend the widget and override
  `Callback`. `OvaWidgets.Entry` extends `FlInputs.InputDesc` with a
  pointer back to its `NumberBox`, and `HelpButton` extends
  `FlButtons.ButtonDesc` with the rulebook page it opens. The widget
  carries its own data, so nothing has to be looked up.

Callbacks must be module-level procedures (poc has no closures), and
everything FLTK can call back into must be reachable from a module
variable, because the collector can't see FLTK's pointers. That's why
the window's widgets, panels and the character all live in module
variables, and why `OvaWidgets` keeps a list of every open `Panel`.

## Widgets made of widgets: `OvaWidgets`

- **`NumberBox`** extends `Fl.GroupDesc`: an `Output` showing the
  computed number and an `Input` for an override, side by side. It
  shows itself with `Display`, not `Show`: a method named after one of
  the widget's own would replace FLTK's.
- **`Panel`** is a plain record that holds a list and its editor: a
  `HoldBrowser`, a `Choice` of names, a `Spinner` for the level, an
  `Input`, Add/Change/Remove buttons and a `?` button.
  **`OvaTraitPanel.TraitPanel`** extends it for Abilities and
  Weaknesses. The same panel is used in the main window, a
  Transformation's form and a Companion's sheet. It reports back
  through procedure fields (`selected`, `changed`), so each owner
  decides what a change means.

## Browsers, choices and spinners

- **Browsers** show columns separated by tabs, with
  `SetColumnWidths`. The list ends at the first 0, as FLTK's does, and
  a column past the list takes the rest. A width of -1 (pofltk 0.7.0)
  takes what the other columns leave, recomputed as the browser
  resizes: the trait panels use `[-1, 70]`, the name with its page in a
  column of 70 at the right (`OvaWidgets.OpenPanel`,
  `OvaTraitPanel`). Every browser that shows names calls
  `SetFormatChar(0X)`, so a name that starts with `@` is shown as it
  is, not read as a format code. Browser lines count from 1 (`Value()`
  0 means none).
- **Choices** are filled with `AppendText`, which shows the text as it
  is, including `&`, `@` and `/`. `Add` is for menu paths and
  shortcuts. A Choice's items count from 0 (-1 means none).
  `FlTest.Choose` picks one by its label in the tests.
- **Spinners** (`FlValuators.OpenSpinner`) set levels and limits
  (`OvaSettings`, the Limits dialog).

## Text

- **The Background tab** has five `FlText.TextEditor`s. Each has a
  buffer of its own type, `ProseBuffer`, which extends
  `FlText.TextBufferDesc` and overrides `Modified` to copy the text
  into the character as the user types. `Modified` also runs when the
  program sets the text itself, so `OvaBackground` sets a `filling`
  flag while it shows a character, and `Modified` ignores changes
  then.
- **Inputs** report every keystroke with `SetWhen(Fl.WhenChanged)`,
  and the override boxes only when the user leaves them or presses
  Enter (`Fl.WhenRelease + Fl.WhenEnterKey`).
- Read text with `Text()`, which returns the whole text with no length
  limit, rather than into a fixed array.
- **The Markdown tab** (`OvaMarkdownTab`) is a read-only
  `FlText.TextDisplay`. It copies the sheet to the clipboard with
  `Fl.Copy(s^, Fl.Clipboard)` and saves it through the native file
  chooser.

## Layout with a grid, and an image

- **The Fluff tab** (`OvaBackground.Build`) lays out pairs of labels
  and inputs with `FlLayout.Grid`: `OpenGrid`, `SetLayout(rows,
  columns)`, `SetGap`, `SetColWeight` and `SetColWidth` for the label
  columns, `Place(widget, row, column, FlLayout.GridFill)` for each
  cell, and `End`.
- **The portrait** is a `Box` with `FlImages.Load` and
  `FlImages.SetImage`. `FlImages.SetImageFit(box, TRUE, FALSE)` shrinks
  the image to fit the box as the window resizes, and never enlarges
  it. The box keeps its own hold on the image.

## File choosers and dialogs, and never waiting

- **The native file chooser**:
  `FlDialogs.OpenNativeFileChooser(c, FlDialogs.BrowseFile)` or
  `BrowseSaveFile` (`OvaWindow.DialogPath`, `OvaBackground`'s portrait,
  `OvaMarkdownTab`'s Save).
- **Messages and questions** use `FlDialogs.Choice(text, "Save",
  "Don't save", "Cancel")` and the like, but **never directly**. Every
  dialog the window would wait on goes through a procedure variable:
  `OvaWindow.tell`, `ask`, `confirm`, `choosePath`, `choosePdf`,
  `askText`, and `OvaWidgets.openPage`. Each module's body sets the
  real one, and a test replaces it with one that answers immediately
  and records what it was asked. That is how the tests cover Save
  versus Don't save versus Cancel without a modal dialog stopping
  them.
- **The program's own dialogs don't block either.**
  `OvaAttackDialog.EditAttack` opens a `DoubleWindow` with `SetModal`,
  calls `Show`, and returns at once. OK or Cancel later calls the
  `done` procedure it was given. A test presses OK with
  `OvaAttackDialog.Ok`. Modal here only means the main window ignores
  input while the dialog is open; no procedure waits for it to close.

## Deleting widgets

- **Never delete a widget inside its own callback.** An attack row's
  Remove button can't rebuild the rows it belongs to while its callback
  is running, so `OvaWindow.RemoveAction` changes the model and calls
  `Fl.Later(Rebuild)`. A `Later` can't be cancelled, so `Rebuild`
  first checks that the window still exists.
- **Every module that builds widgets has a `Close`** that deletes
  them and sets its variables to NIL (`OvaWindow.Close` closes the
  dialogs, removes the timer, deletes the window, then calls the tabs'
  `Close`). The program doesn't need it at exit, but the tests do (see
  below).

## Preferences

`FlPreferences` keeps the rulebook's path and the chosen viewer between
runs: `Open(p, FlPreferences.User, vendor, application)` in the
program, and `FlPreferences.OpenFile(p, dir, vendor, application)` in
the tests, so a test never writes the user's own preferences. A test
also checks that every database it opened was closed
(`FlPreferences.openDatabases = 0`).

## The tests

The window tests (`test/TestWindow.Mod`, `TestBackground`,
`TestLinked`, `TestLimits`, `TestMarkdown`, `TestResize`) use pofltk's
`FlTest` to act as a user would, on windows that are never shown to
anyone:

- `FlTest.Fill(input, text)` types into a field and fires its
  callback; `FlTest.SelectLine(browser, FlTest.LineWith(browser,
  "Telekinesis"))` selects a line by its text; `FlTest.Choose(choice,
  label)` picks an item; `b.DoCallback` presses a button.
- `FlTest.Settle` runs the event loop briefly, so `Fl.Later` and
  timers take effect; `FlTest.Expose(window)` shows a window and waits
  until it has been drawn.
- `TestResize` checks what was actually drawn: `FlTest.Capture(box)`
  and `FlTest.Pixel(x, y)` read the portrait's pixels after a resize.
- Each test ends with `OvaWindow.Close` and checks
  `Fl.OpenWidgets() = 0`, so a widget left undeleted fails the test,
  and `make valgrind` (with pofltk's `test/vg-check.sh`) fails on any
  memory pofltk allocated that wasn't freed.

They run on a display of their own, never on your desktop:

```sh
make test-headless   # on Xvfb
make test-sway       # on a headless sway (Wayland)
```

## Not pofltk, but nearby

- **`OvaSpawn`** (with `OvaSpawn.c`) starts the PDF viewer: an argument
  vector, no shell, detached in its own session. It shows how a poc
  module includes a small C file, and how C's types are declared with
  `SYSTEM`'s.
- **polibfyaml** reads and writes the YAML (`OvaCharacter`,
  `OvaSave`), and **Ropes** holds the text throughout.

## Where to read next

- `OvaCg.Mod`, then `OvaWindow.Build`, for the shape of the program.
- `OvaWidgets.Mod` for making your own widgets out of FLTK's.
- `test/TestWindow.Mod` for driving a window from a test.
- pofltk's own `README.md`, `examples/` and `doc/fltk-issues.md`.
- [AGENTS.md](../AGENTS.md), "Working with ropes, pofltk and poc here",
  for the rules this program follows, each learned the hard way.
