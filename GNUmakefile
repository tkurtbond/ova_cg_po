# ova_cg_po -- an OVA character generator in Oberon-2, built with poc,
# the Peaseblossom Oberon Compiler, with pofltk (FLTK) for its window and
# polibfyaml for its files.  See AGENTS.md and PLAN.md.
#
# poc builds a program from its main module's source.  The shared
# modules come compiled, from the poc libraries argparser, ropes,
# polibfyaml and pofltk on the library path; the program's own modules
# it finds on the import path (src/, and test/ for the tests) and
# compiles again on each build, so a new module needs no rule.  What poc
# writes -- each module's .sym, .ll and .o, and the test programs --
# goes into $(OBJ).
#
# Every program writes this repo's modules' files into the same $(OBJ),
# so make must not build two at once.

SHELL = bash

POC      ?= poc
# Size model: polibfyaml and pofltk require -OC, and models can't be
# mixed, so every module here gets it.
POCFLAGS := -OC

# libfyaml's link flags: the polibfyaml library doesn't record them.
# pofltk's manifest records its own (c++, -lfltk_images, -lfltk).
FYAML_LIBS := $(shell pkg-config --libs libfyaml)
LINK := $(foreach f,$(FYAML_LIBS),-link $(f))

# The libraries, each installed by its own repo into POCLIBDIR: argparser
# and ropes (make -f pocGNUmakefile install in ArgParser and Ropes),
# polibfyaml and pofltk (make install).  None of their sources is copied
# here.  POCLIBDIR doesn't follow PREFIX, which says where this program
# installs.
POCLIBDIR ?= $(HOME)/.local/lib/poc
SHAREDLIBS := argparser ropes polibfyaml pofltk
LIBPATH := -library-path $(abspath $(POCLIBDIR))

# The libraries this build takes are the ones in $(POCLIBDIR).  A library
# on POC_LIBRARY_PATH would stop the build if another poc wrote it.
unexport POC_LIBRARY_PATH
IMPORTS := -import-path src $(LIBPATH)

OBJ := obj

PROGRAM := ova_cg_po
MAIN    := OvaCg

# Every source and library a program is built from, for make's
# dependencies: a reinstalled library rebuilds the programs.
SHAREDLIBMANIFESTS := $(foreach l,$(SHAREDLIBS),$(wildcard $(POCLIBDIR)/*/OC/$(l).library))
PROGSRC := $(wildcard src/*.Mod src/*.c)

# Test support modules, and test programs (test/<name>.Mod, main
# modules): TESTS need no display, GUITESTS do.
TESTSUPPORT := test/Check.Mod
TESTS       := TestRules TestCalc TestFiles TestModel TestPaths TestSpawn TestViewer
GUITESTS    := TestWindow TestBackground TestLinked TestLimits TestMarkdown TestResize
TESTBINS    := $(TESTS:%=$(OBJ)/%)
GUITESTBINS := $(GUITESTS:%=$(OBJ)/%)
# Seconds a test may run before it counts as hung, and how long the
# program must keep running to count as started (test-gui).
TIMEOUT  ?= 60
RUNTIME  ?= 3

# Only building needs the libraries, so the cleaning targets don't check
# for them.
ifneq ($(if $(MAKECMDGOALS),$(filter-out clean uninstall print-%,$(MAKECMDGOALS)),all),)
$(foreach l,$(SHAREDLIBS),$(if $(wildcard $(POCLIBDIR)/*/OC/$(l).library),,$(error the $(l) library is not in $(POCLIBDIR); install it from its repo (AGENTS.md))))
endif

.PHONY: all tests test check-pages test-viewers test-gui test-headless test-sway valgrind valgrind-headless valgrind-sway \
  display install uninstall clean
.NOTPARALLEL:

all: $(PROGRAM)

tests: $(PROGRAM) $(TESTBINS) $(GUITESTBINS)

$(OBJ):
	mkdir -p $@

# TestFiles saves its copies here, for test/files.sh.
$(OBJ)/files: | $(OBJ)
	mkdir -p $@

$(PROGRAM): src/$(MAIN).Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -output-dir $(OBJ) $(LINK) -o $@ $<

$(OBJ)/Test%: test/Test%.Mod $(TESTSUPPORT) $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) $(LINK) -o $@ $<

# ova_fmt_po, the oracle for files: what the generator saves must
# format as the file it loaded (test/files.sh, after TestFiles).
OVA_FMT_PO ?= $(HOME)/Repos/RPG/Tools/ova_fmt_po/ova_fmt_po

# What needs no display: the unit tests, test/files.sh, then
# test/cli.sh; fail at the end if any failed.
test: $(PROGRAM) $(TESTBINS) | $(OBJ)/files
	@status=0; for t in $(TESTS); do \
	  echo "== $$t"; (cd test && timeout $(TIMEOUT) ../$(OBJ)/$$t) || status=1; \
	done; \
	echo "== files.sh"; test/files.sh $(OVA_FMT_PO) || status=1; \
	echo "== cli.sh"; test/cli.sh ./$(PROGRAM) || status=1; \
	exit $$status

# Every page in OvaRules against the rulebook: the entries' headings,
# found by their font in the PDF (tools/rulebook-headings.py, which needs
# mutool).  Not part of make test, which can't count on the PDF.
RULEBOOK ?= $(HOME)/Reference/RPG/OVA/OVA_The_Anime_Role-Playing_Game.pdf
$(OBJ)/ListRules: test/ListRules.Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) $(LINK) -o $@ $<
check-pages: $(OBJ)/ListRules
	@tools/rulebook-headings.py $(RULEBOOK) > $(OBJ)/headings.txt
	@$(OBJ)/ListRules > $(OBJ)/rules.txt
	@if diff $(OBJ)/headings.txt $(OBJ)/rules.txt; then \
	  echo "ok   - all $$(wc -l < $(OBJ)/rules.txt) pages match the rulebook's headings"; \
	else echo "FAIL - OvaRules (>) differs from the rulebook's headings (<)"; exit 1; fi

# OvaViewer with the real viewers, okular, evince and mupdf, on a
# headless sway of test/viewer.sh's own, on a private D-Bus session bus,
# with a scratch HOME.  Not part of make test: it needs the viewers, and
# takes a minute or two.
$(OBJ)/OpenPage: test/OpenPage.Mod $(PROGSRC) $(SHAREDLIBMANIFESTS) | $(OBJ)
	$(POC) $(POCFLAGS) $(IMPORTS) -import-path test -output-dir $(OBJ) $(LINK) -o $@ $<
test-viewers: $(OBJ)/OpenPage
	test/viewer.sh $(OBJ)/OpenPage

# FLTK needs a display even for windows never shown.  An agent never
# runs these on the user's desktop (AGENTS.md): use test-headless or
# test-sway.
display:
	@if [ -z "$$DISPLAY$$WAYLAND_DISPLAY" ]; then \
	  echo "the window tests need a display: use make test-headless or make test-sway"; exit 1; \
	fi

# The window tests, then the program itself, which waits for the user:
# it must still be running after RUNTIME seconds, when timeout ends it
# (status 124): it started, drew, and didn't crash.  Then test/quit.sh:
# started again, Ctrl+E opens Limits from a text input and it quits on
# Ctrl+Q (X11 only; skipped on Wayland).
# The program's own runs keep their preferences in obj/config, not the
# user's ~/.config.
test-gui: tests display | $(OBJ)/files
	@export XDG_CONFIG_HOME=$(CURDIR)/$(OBJ)/config; \
	status=0; for t in $(GUITESTS); do \
	  echo "== $$t"; (cd test && timeout $(TIMEOUT) ../$(OBJ)/$$t) || status=1; \
	done; \
	echo "== $(PROGRAM) (must still be running after $(RUNTIME) s)"; \
	timeout $(RUNTIME) ./$(PROGRAM); st=$$?; \
	if [ $$st -eq 124 ]; then echo "ok   - $(PROGRAM) started and ran"; \
	else echo "FAIL - $(PROGRAM) exited with $$st"; status=1; fi; \
	echo "== quit.sh"; test/quit.sh ./$(PROGRAM) || status=1; \
	exit $$status

# On a virtual X server (Xvfb).  WAYLAND_DISPLAY is unset because FLTK
# prefers Wayland when it is set, even under xvfb-run (pofltk's
# finding).
test-headless: tests
	env -u WAYLAND_DISPLAY xvfb-run -a $(MAKE) test-gui

# On Wayland, on a headless sway (tools/with-sway.sh, pofltk's).
test-sway: tests
	tools/with-sway.sh $(MAKE) test-gui

# The tests under valgrind.  Memory errors fail a run; leaks don't by
# themselves, since FLTK's display stack (fontconfig, Pango, and GTK's
# decorations under Wayland) leaks by design.  pofltk's vg-check.sh fails
# instead on any leak whose allocator is pofltk's (a widget never
# deleted); test/poc-gc.supp holds the collector's stack-scan reports
# (pofltk's AGENTS.md, "Valgrind").  A child OvaSpawn forks reports
# nothing: it only execs or exits (_exit, leaving its copy of the
# argument vector), and what it runs isn't ours to check.
POFLTK ?= $(HOME)/Repos/Oberon/pofltk
VALGRIND ?= valgrind --leak-check=full --show-leak-kinds=all --errors-for-leak-kinds=none \
  --error-exitcode=99 --child-silent-after-fork=yes --suppressions=$(CURDIR)/test/poc-gc.supp
valgrind: tests display | $(OBJ)/files
	@status=0; for t in $(TESTS) $(GUITESTS); do \
	  echo "== valgrind $$t"; \
	  (cd test && $(VALGRIND) --log-file=../$(OBJ)/$$t.vg ../$(OBJ)/$$t) || status=1; \
	  grep -E 'ERROR SUMMARY' $(OBJ)/$$t.vg; \
	  $(POFLTK)/test/vg-check.sh $(OBJ)/$$t.vg || { echo "FAIL - $$t: memory pofltk allocated was not freed"; status=1; }; \
	done; \
	if [ $$status -eq 0 ]; then echo "All checks passed."; else exit 1; fi

valgrind-headless: tests
	env -u WAYLAND_DISPLAY xvfb-run -a $(MAKE) valgrind

valgrind-sway: tests
	tools/with-sway.sh $(MAKE) valgrind

# ---- Installation ----
#
# To $(PREFIX)/bin, $HOME/local/bin by default, as ova_fmt_po's.
# DESTDIR is prepended, for staging.
PREFIX ?= $(HOME)/local
BINDIR ?= $(PREFIX)/bin

install: $(PROGRAM)
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 $(PROGRAM) $(DESTDIR)$(BINDIR)/$(PROGRAM)

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/$(PROGRAM)

clean:
	rm -rf $(OBJ) $(PROGRAM)

print-%: ; @echo $* = $($*)
