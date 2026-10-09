MODULE ListRules; (* Prints OvaRules' items as "PAGE<TAB>NAME", in the book's order, for make check-pages *)

IMPORT OvaRules, Out;

VAR k, i: INTEGER; it: OvaRules.Item;

BEGIN
  FOR k := OvaRules.Ability TO OvaRules.Flaw DO
    FOR i := 0 TO OvaRules.Count(k) - 1 DO
      it := OvaRules.Get(k, i);
      Out.Int(it.page, 0); Out.Char(09X); Out.String(it.name); Out.Ln
    END
  END
END ListRules.
