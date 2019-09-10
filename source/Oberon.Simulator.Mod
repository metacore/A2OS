(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Simulator IN Oberon; (*JG 10.10.93*)
  IMPORT Display, Gadgets, Attributes, Diagrams;

  VAR seed: SIGNED32;

  PROCEDURE Random (): FLOAT32;
    CONST a = 16807; m = 2147483647; q = m DIV a; r = m MOD a;
  BEGIN seed := a*(seed MOD q) - r*(seed DIV q);
    IF seed <= 0 THEN seed := seed + m END;
    RETURN seed * (1.0/m)
  END Random;

  PROCEDURE Start*;
    VAR a, b, r, x: FLOAT64; t, T: SIGNED32; limited: BOOLEAN;
      N: Diagrams.UpdateMsg;
  BEGIN
    Attributes.GetBool(Gadgets.FindObj(Gadgets.context, "Loss"), "Value", limited);
    Attributes.GetLongReal(Gadgets.FindObj(Gadgets.context, "Mean"), "Value", x); b := 1/x;
    Attributes.GetInt(Gadgets.FindObj(Gadgets.context, "Period"), "Value", T);
    Attributes.GetLongReal(Gadgets.FindObj(Gadgets.context, "Load"), "Value", x); a := x/100 * b;
    N.F := NIL; N.n := 0; t := 0;
    REPEAT INC(t); r := Random ();
      IF r < a THEN INC(N.n)
        ELSIF (N.n > 0) & (r > 1-b) THEN DEC(N.n)
      END;
      Display.Broadcast(N);
      IF limited & (N.res > 0) THEN DEC(N.n) END
    UNTIL t >= T
  END Start;

BEGIN seed := 1235
END Simulator.
