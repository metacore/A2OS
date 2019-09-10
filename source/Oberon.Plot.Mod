(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Plot IN Oberon;

IMPORT Objects, Gadgets, BasicGadgets, Math IN A2;

PROCEDURE FindY(): BasicGadgets.Integer;
VAR obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "YAxis");
	IF (obj # NIL) & (obj IS BasicGadgets.Integer) THEN RETURN obj(BasicGadgets.Integer)
	ELSE RETURN NIL
	END
END FindY;

PROCEDURE GetValue(name: ARRAY OF CHAR; default: FLOAT32): FLOAT32;
VAR obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, name);
	IF (obj # NIL) & (obj IS BasicGadgets.Real) THEN RETURN SHORT(obj(BasicGadgets.Real).val)
	ELSIF (obj # NIL) & (obj IS BasicGadgets.Integer) THEN RETURN obj(BasicGadgets.Integer).val * 1.0
	ELSE RETURN default
	END
END GetValue;

PROCEDURE Plot*;
VAR y: BasicGadgets.Integer; i: SIGNED16;
	AmpA, FreqA, AmpB, FreqB, tmp: FLOAT32;
BEGIN
	AmpA := GetValue("AmpA", 200); FreqA := GetValue("FreqA", 40);
	AmpB := GetValue("AmpB", 200); FreqB := GetValue("FreqB", 40);
	y := FindY();
	IF y # NIL THEN
		i := 0;
		WHILE i < 360 DO
			tmp := AmpB * Math.sin(FreqB * Math.pi / 180 * i);
			y.val := ENTIER(AmpA * Math.sin(FreqA * Math.pi / 180 * i) + tmp);
			Gadgets.Update(y);
			INC(i)
		END
	END
END Plot;

END Plot.

System.Free Plot ~