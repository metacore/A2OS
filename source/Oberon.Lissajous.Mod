(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Lissajous IN Oberon;

IMPORT
	Math IN A2, Objects, Gadgets, BasicGadgets, Complex;

(* Return the value of a input gadget *)
PROCEDURE GetValue(name: ARRAY OF CHAR; default: FLOAT32): FLOAT32;
VAR obj: Objects.Object;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, name);
	IF (obj # NIL) & (obj IS BasicGadgets.Real) THEN RETURN SHORT(obj(BasicGadgets.Real).val)
	ELSIF (obj # NIL) & (obj IS BasicGadgets.Integer) THEN RETURN obj(BasicGadgets.Integer).val
	ELSE RETURN default
	END
END GetValue;

PROCEDURE Do*;
VAR obj: Objects.Object; i: SIGNED16; freqA, freqB: FLOAT32;
BEGIN
	obj := Gadgets.FindObj(Gadgets.context, "Controller");
	IF (obj # NIL) & (obj IS Complex.Complex) THEN
		WITH obj: Complex.Complex DO
			freqA := GetValue("FreqA", 2); freqB := GetValue("FreqB", 2);
			i := 0;
			WHILE i < 360 DO
				obj.real := Math.sin(freqA * Math.pi / 180 * i); obj.imag := Math.sin(freqB *Math.pi / 180 * i);
				Gadgets.Update(obj); (* and plot *)
				INC(i)
			END
		END
	END
END Do;

END Lissajous.

Gadgets.Link Complex.New ~
System.Free Lissajous Graphs~

Gadgets.Insert Graphs.NewGraph ~