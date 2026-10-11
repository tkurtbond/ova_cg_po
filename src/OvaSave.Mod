MODULE OvaSave; (* Writes a character as YAML in ova_fmt's format *)

(* PLAN.md, "Files". The document is built with polibfyaml's emitter,
   never written as text here, so the quoting is libfyaml's: text goes
   through CreateStyledScalar, since the installed libfyaml writes a
   CreateScalar plain even where plain YAML can't hold it (#1 fan reads
   back as a comment; polibfyaml's PLAN.md, "Scalar styles"). Text of
   more than one line is a literal block, as in ova_fmt's fixtures; any
   other, plain where that is safe, else double-quoted. Numbers,
   booleans and keys are plain.

   One document, a sequence of one entity, its keys in the order of
   ova_fmt's fixtures. The numbers written are the ones in effect: an
   override where there is one, which the mapping's overrides: key
   then lists. Only keys both ova_fmts read are written (AGENTS.md).

   A failed save leaves the old file as it was: the document goes to
   NAME.tmp, which then replaces NAME. *)

IMPORT Fyaml, OvaCalc, OvaCharacter, OvaEntities, OvaRules, OvaText, Platform, Ropes;

TYPE
  Rope = Ropes.Rope;
  Node = Fyaml.Node;

VAR
  d: Fyaml.Document;  (* the document being built *)
  ok: BOOLEAN;        (* every AppendPair so far succeeded *)
  fluffKeys: ARRAY OvaCharacter.NFluff, 16 OF CHAR;  (* OvaEntities' keys, by its constants *)

(* ---- Scalars ---- *)

PROCEDURE AppendTo(VAR s: ARRAY OF CHAR; a: ARRAY OF CHAR);
  VAR i, j: INTEGER;
BEGIN
  i := 0; WHILE s[i] # 0X DO INC(i) END;
  j := 0; WHILE (a[j] # 0X) & (i < LEN(s) - 1) DO s[i] := a[j]; INC(i); INC(j) END;
  s[i] := 0X
END AppendTo;

PROCEDURE HasLineBreak(r: Rope): BOOLEAN;
BEGIN RETURN Ropes.IndexChar(r, 0AX, 0) >= 0
END HasLineBreak;

PROCEDURE Text(r: Rope): Node;
  VAR s: OvaText.String;
BEGIN
  s := OvaText.Chars(r);
  IF HasLineBreak(r) THEN RETURN d.CreateStyledScalar(s^, Fyaml.StyleLiteral)
  ELSE RETURN d.CreateStyledScalar(s^, Fyaml.StylePlain)
  END
END Text;

PROCEDURE Int(i: INTEGER): Node;
  VAR s: OvaText.String;
BEGIN s := OvaText.Chars(OvaText.Int(i)); RETURN d.CreateScalar(s^)
END Int;

PROCEDURE Bool(b: BOOLEAN): Node;
BEGIN IF b THEN RETURN d.CreateScalar("true") ELSE RETURN d.CreateScalar("false") END
END Bool;

(* n in effect: "4", "1/2", "10+". *)
PROCEDURE Num(VAR n: OvaCalc.Number): Node;
  VAR s: ARRAY 32 OF CHAR;
BEGIN OvaCalc.Text(n, s); RETURN d.CreateStyledScalar(s, Fyaml.StylePlain)
END Num;

(* ---- Mappings ---- *)

PROCEDURE Pair(m: Node; key: ARRAY OF CHAR; v: Node);
  VAR err: Fyaml.Error;
BEGIN IF ok THEN ok := m.AppendPair(d.CreateScalar(key), v, err) END
END Pair;

(* Adds k to set if n is overridden. *)
PROCEDURE Over(VAR set: SET; k: INTEGER; VAR n: OvaCalc.Number);
BEGIN IF n.overridden THEN INCL(set, k) END
END Over;

(* "overrides: [...]", the keys in set in OvaEntities' order, if any. *)
PROCEDURE Overrides(m: Node; set: SET);
  VAR seq: Node; k: INTEGER; name: ARRAY 16 OF CHAR;
BEGIN
  IF set = {} THEN RETURN END;
  seq := d.CreateSequence();
  FOR k := 0 TO MAX(SET) DO
    IF k IN set THEN OvaEntities.KeyName(k, name); seq.Append(d.CreateScalar(name)) END
  END;
  Pair(m, "overrides", seq)
END Overrides;

PROCEDURE TextPair(m: Node; key: ARRAY OF CHAR; has: BOOLEAN; r: Rope);
BEGIN IF has THEN Pair(m, key, Text(r)) END
END TextPair;

(* ---- Perks and Flaws ---- *)

(* A plain name, as the fixtures write most; a mapping when it has a
   detail, a count or a cost to say. *)
PROCEDURE ModNode(x: OvaCalc.Mod): Node;
  VAR m: OvaCharacter.Mod; n: Node;
BEGIN
  m := x(OvaCharacter.Mod);
  IF ~m.hasDetail & (m.times = 1) & ~m.hasCost THEN RETURN Text(m.name) END;
  n := d.CreateMapping();
  Pair(n, "name", Text(m.name));
  TextPair(n, "detail", m.hasDetail, m.detail);
  IF m.times # 1 THEN Pair(n, "counts-as", Int(m.times)) END;
  IF m.hasCost THEN Pair(n, "cost", Int(m.cost)) END;
  RETURN n
END ModNode;

(* The Perks (flaws FALSE) or Flaws of mods, under key, if any. *)
PROCEDURE Mods(m: Node; key: ARRAY OF CHAR; mods: OvaCalc.Mod; flaws: BOOLEAN);
  VAR seq: Node; x: OvaCalc.Mod;
BEGIN
  seq := NIL; x := mods;
  WHILE x # NIL DO
    IF x(OvaCharacter.Mod).isFlaw = flaws THEN
      IF seq = NIL THEN seq := d.CreateSequence() END;
      seq.Append(ModNode(x))
    END;
    x := x.next
  END;
  IF seq # NIL THEN Pair(m, key, seq) END
END Mods;

(* ---- Traits ---- *)

PROCEDURE^ Partner(c: OvaCharacter.Character): Node;

PROCEDURE TraitNode(x: OvaCalc.Trait): Node;
  VAR t: OvaCharacter.Trait; n, seq, sn: Node; f: OvaCalc.Trait; sp: OvaCalc.Spell; s: OvaCharacter.Spell;
    p: OvaCharacter.Character; key: ARRAY 16 OF CHAR; lc: OvaText.String; set: SET;
BEGIN
  t := x(OvaCharacter.Trait);
  n := d.CreateMapping();
  Pair(n, "name", Text(t.name));
  Pair(n, "level", Int(t.level));
  TextPair(n, "detail", t.hasDetail, t.detail);
  Mods(n, "perks", t.mods, FALSE); Mods(n, "flaws", t.mods, TRUE);
  (* An END of 0 isn't written, as the fixtures don't write one; an
     override always is. *)
  IF t.hasEnd & (OvaCalc.Value(t.end) # 0) OR t.end.overridden THEN Pair(n, "endurance", Num(t.end)) END;
  TextPair(n, "note", t.hasNote, t.note);
  IF t.hasHalfTV THEN Pair(n, "threat-value-half", Bool(t.halfTV)) END;
  set := {}; Over(set, OvaEntities.OvEndurance, t.end); Overrides(n, set);
  IF t.form # NIL THEN
    seq := NIL; f := t.form;
    WHILE f # NIL DO
      IF f.kind = OvaRules.Ability THEN
        IF seq = NIL THEN seq := d.CreateSequence() END;
        seq.Append(TraitNode(f))
      END;
      f := f.next
    END;
    IF seq # NIL THEN Pair(n, "abilities", seq) END;
    seq := NIL; f := t.form;
    WHILE f # NIL DO
      IF f.kind = OvaRules.Weakness THEN
        IF seq = NIL THEN seq := d.CreateSequence() END;
        seq.Append(TraitNode(f))
      END;
      f := f.next
    END;
    IF seq # NIL THEN Pair(n, "weaknesses", seq) END
  END;
  IF t.spells # NIL THEN
    seq := d.CreateSequence(); sp := t.spells;
    WHILE sp # NIL DO
      s := sp(OvaCharacter.Spell);
      sn := d.CreateMapping();
      Pair(sn, "name", Text(s.name));
      Pair(sn, "ability", Text(s.ability));
      Pair(sn, "level", Int(s.level));
      Pair(sn, "endurance", Num(s.end));
      set := {}; Over(set, OvaEntities.OvEndurance, s.end); Overrides(sn, set);
      seq.Append(sn);
      sp := sp.next
    END;
    Pair(n, "spells", seq)
  END;
  IF t.partner # NIL THEN
    p := t.partner(OvaCharacter.Character);
    lc := OvaText.Chars(OvaText.FoldCI(p.label)); COPY(lc^, key);  (* "companion" or "vehicle" *)
    Pair(n, key, Partner(p))
  END;
  RETURN n
END TraitNode;

(* The Traits of list of kind, under key, if any. *)
PROCEDURE Traits(m: Node; key: ARRAY OF CHAR; list: OvaCalc.Trait; kind: INTEGER);
  VAR seq: Node;
BEGIN
  seq := NIL;
  WHILE list # NIL DO
    IF list.kind = kind THEN
      IF seq = NIL THEN seq := d.CreateSequence() END;
      seq.Append(TraitNode(list))
    END;
    list := list.next
  END;
  IF seq # NIL THEN Pair(m, key, seq) END
END Traits;

(* ---- Combat ---- *)

PROCEDURE Combat(m: Node; c: OvaCharacter.Character);
  VAR n, seq, an: Node; x: OvaCalc.Attack; a: OvaCharacter.Attack; def, b: ARRAY 32 OF CHAR; set: SET;
BEGIN
  IF ~c.hasCombat THEN RETURN END;
  n := d.CreateMapping();
  OvaCalc.Text(c.defense, def);
  IF c.hasBarrier & ~c.omitBarrier OR c.barrier.overridden THEN
    OvaCalc.Text(c.barrier, b); AppendTo(def, "/"); AppendTo(def, b)
  END;
  Pair(n, "defense", d.CreateStyledScalar(def, Fyaml.StylePlain));
  Pair(n, "health", Num(c.health));
  Pair(n, "endurance", Num(c.endurance));
  IF c.hasThreatValue THEN Pair(n, "threat-value", Num(c.tv)) END;
  IF c.transformed THEN Pair(n, "transformed", Bool(TRUE)) END;
  set := {};
  Over(set, OvaEntities.OvDefense, c.defense); Over(set, OvaEntities.OvBarrier, c.barrier);
  Over(set, OvaEntities.OvHealth, c.health); Over(set, OvaEntities.OvEndurance, c.endurance);
  IF c.hasThreatValue THEN Over(set, OvaEntities.OvThreatValue, c.tv) END;
  Overrides(n, set);
  TextPair(n, "notes", c.hasCombatNotes, c.combatNotes);
  IF c.attacks # NIL THEN
    seq := d.CreateSequence(); x := c.attacks;
    WHILE x # NIL DO
      a := x(OvaCharacter.Attack);
      an := d.CreateMapping();
      Pair(an, "name", Text(a.name));
      Mods(an, "perks", a.mods, FALSE);
      TextPair(an, "affinity", a.hasAffinity, a.affinity);
      Mods(an, "flaws", a.mods, TRUE);
      TextPair(an, "description", a.hasDescription, a.description);
      Pair(an, "roll", Num(a.roll));
      Pair(an, "dx", Num(a.dx));
      Pair(an, "endurance", Num(a.end));
      IF a.telekinetic THEN Pair(an, "telekinesis", Bool(TRUE)) END;
      IF a.transformed THEN Pair(an, "transformed", Bool(TRUE)) END;
      set := {};
      Over(set, OvaEntities.OvRoll, a.roll); Over(set, OvaEntities.OvDx, a.dx);
      Over(set, OvaEntities.OvEndurance, a.end);
      Overrides(an, set);
      seq.Append(an);
      x := x.next
    END;
    Pair(n, "attacks", seq)
  END;
  Pair(m, "combat", n)
END Combat;

(* ---- Entities ---- *)

(* A Companion's or Vehicle's mapping. *)
PROCEDURE Partner(c: OvaCharacter.Character): Node;
  VAR m: Node;
BEGIN
  m := d.CreateMapping();
  Pair(m, "name", Text(c.name));
  IF c.isFragment THEN Pair(m, "fragment", Bool(TRUE)) END;
  Traits(m, "abilities", c.traits, OvaRules.Ability);
  Traits(m, "weaknesses", c.traits, OvaRules.Weakness);
  Combat(m, c);
  RETURN m
END Partner;

PROCEDURE Entity(c: OvaCharacter.Character): Node;
  VAR m, seq, n, f: Node; note: OvaCharacter.Note; o: Node; i: INTEGER;
BEGIN
  m := d.CreateMapping();
  Pair(m, "name", Text(c.name));
  IF c.isFragment THEN Pair(m, "fragment", Bool(TRUE)) END;
  IF c.hasNpcType THEN Pair(m, "npc-type", Text(OvaEntities.NpcTypeName(c.npcType))) END;
  TextPair(m, "player", c.hasPlayer, c.player);
  TextPair(m, "portrait", c.hasPortrait, c.portrait);
  TextPair(m, "tagline", c.hasTagline, c.tagline);
  TextPair(m, "summary", c.hasSummary, c.summary);
  TextPair(m, "background", c.hasBackground, c.background);
  TextPair(m, "appearance", c.hasAppearance, c.appearance);
  TextPair(m, "personality", c.hasPersonality, c.personality);
  TextPair(m, "character-hooks", c.hasCharacterHooks, c.characterHooks);
  TextPair(m, "other-notes", c.hasOtherNotes, c.otherNotes);
  IF c.hasOptions THEN
    o := d.CreateMapping();
    IF c.options.baseZero THEN Pair(o, "base-zero", Int(c.options.baseZeroRange)) END;
    IF c.options.powerCeiling THEN Pair(o, "power-ceiling", Int(c.options.ceiling)) END;
    IF c.options.startingLevels THEN Pair(o, "starting-levels", Int(c.options.starting)) END;
    IF c.options.scaledCost THEN Pair(o, "scaled-cost", Bool(TRUE)) END;
    IF c.options.halfCostKnowledge THEN Pair(o, "half-cost-knowledge", Bool(TRUE)) END;
    IF c.options.combinedEffectiveness THEN Pair(o, "combined-effectiveness", Bool(TRUE)) END;
    Pair(m, "options", o)
  END;
  Traits(m, "abilities", c.traits, OvaRules.Ability);
  Traits(m, "weaknesses", c.traits, OvaRules.Weakness);
  Combat(m, c);
  IF c.notes # NIL THEN
    seq := d.CreateSequence(); note := c.notes;
    WHILE note # NIL DO
      n := d.CreateMapping();
      Pair(n, "header", Text(note.header));
      Pair(n, "text", Text(note.text));
      seq.Append(n);
      note := note.next
    END;
    Pair(m, "notes", seq)
  END;
  IF c.hasFluff THEN
    f := d.CreateMapping();
    FOR i := 0 TO OvaCharacter.NFluff - 1 DO
      IF c.hasFluffField[i] THEN Pair(f, fluffKeys[i], Text(c.fluff[i])) END
    END;
    Pair(m, "fluff", f)
  END;
  RETURN m
END Entity;

(* c's document; NIL if building it failed (a duplicate key: a
   programmer's error, never the user's). *)
PROCEDURE Document(c: OvaCharacter.Character): Fyaml.Document;
  VAR root: Node;
BEGIN
  d := Fyaml.NewDocument(); ok := TRUE;
  root := d.CreateSequence(); d.SetRoot(root);
  root.Append(Entity(c));
  IF ~ok THEN d.Close; d := NIL END;
  RETURN d
END Document;

(* c as YAML text, for the tests. *)
PROCEDURE ToText*(c: OvaCharacter.Character): Rope;
  VAR doc: Fyaml.Document; s: Fyaml.String; err: Fyaml.Error; r: Rope;
BEGIN
  doc := Document(c); r := NIL;
  IF doc # NIL THEN
    s := doc.ToYAML(Fyaml.emitModeBlock, err);
    IF s # NIL THEN r := Ropes.FromString(s^) END;
    doc.Close
  END;
  d := NIL;
  RETURN r
END ToText;

(* Writes c to the file at path, through path.tmp, which replaces it
   only once written. FALSE, with msg, if it couldn't be, the old file
   left as it was. *)
PROCEDURE Save*(c: OvaCharacter.Character; path: ARRAY OF CHAR; VAR msg: Rope): BOOLEAN;
  VAR doc: Fyaml.Document; err: Fyaml.Error; tmp, p: OvaText.String; t: Rope; e: Platform.ErrorCode;
    written: BOOLEAN;
BEGIN
  msg := NIL;
  doc := Document(c);
  IF doc = NIL THEN
    msg := Ropes.FromString("the character's YAML couldn't be built (a duplicate key)"); RETURN FALSE
  END;
  t := Ropes.FromString(path); OvaText.Add(t, ".tmp"); tmp := OvaText.Chars(t);
  written := doc.ToFile(tmp^, Fyaml.emitModeBlock, err);
  doc.Close; d := NIL;
  IF ~written THEN
    msg := OvaText.Trim(Ropes.FromString(err.msg^));
    e := Platform.Unlink(tmp^);
    RETURN FALSE
  END;
  p := OvaText.Chars(Ropes.FromString(path));
  e := Platform.Rename(tmp^, p^);
  IF e # 0 THEN
    msg := Ropes.FromString("couldn't replace "); OvaText.Add(msg, path);
    OvaText.Add(msg, " with "); OvaText.Add(msg, tmp^); OvaText.Add(msg, " (error ");
    msg := Ropes.Cat(msg, OvaText.Int(e)); OvaText.Add(msg, ")");
    RETURN FALSE
  END;
  RETURN TRUE
END Save;

BEGIN
  (* OvaEntities' fluff keys, in the order of its constants. *)
  fluffKeys[OvaEntities.Concept] := "concept"; fluffKeys[OvaEntities.Birthday] := "birthday";
  fluffKeys[OvaEntities.Age] := "age"; fluffKeys[OvaEntities.Gender] := "gender";
  fluffKeys[OvaEntities.Height] := "height"; fluffKeys[OvaEntities.Weight] := "weight";
  fluffKeys[OvaEntities.Hair] := "hair"; fluffKeys[OvaEntities.Eyes] := "eyes";
  fluffKeys[OvaEntities.Association] := "association"; fluffKeys[OvaEntities.Hobbies] := "hobbies";
  fluffKeys[OvaEntities.FavoriteFood] := "favorite-food"; fluffKeys[OvaEntities.Allies] := "allies";
  fluffKeys[OvaEntities.Enemies] := "enemies"; fluffKeys[OvaEntities.LoveInterests] := "love-interests"
END OvaSave.
