(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

(*
	Complex.Mod, jm 8.11.93

	Example of how to program an own abstract gadget. Note that this gadget
	should do its own type conversion when the values "Real" or "Imag" are set.
*)

MODULE Complex IN Oberon;	(** portable *)

IMPORT
	Math IN A2, Files, Objects, Gadgets, Strings;

TYPE
	Complex* = POINTER TO ComplexDesc;
	ComplexDesc* = RECORD (Gadgets.ObjDesc)
		real*, imag*: FLOAT32
	END;

PROCEDURE Phi(obj: Complex): FLOAT32;
VAR x: FLOAT32;
BEGIN
	IF obj.real = 0.0 THEN
		IF obj.imag < 0.0 THEN x := (Math.pi / 2)*3
		ELSIF obj.imag = 0.0 THEN x := 0.0
		ELSE x := Math.pi / 2
		END
	ELSE
		IF obj.imag = 0.0 THEN
			IF obj.real < 0.0 THEN x := Math.pi
			ELSE x := 0.0
			END
		ELSE
			x := Math.arctan(obj.imag/obj.real);
			IF obj.real < 0 THEN x := Math.pi + x
			ELSIF obj.imag < 0 THEN x := Math.pi*2 + x
			END
		END
	END;
	RETURN x
END Phi;

PROCEDURE Copy*(VAR M: Objects.CopyMsg; from, to: Complex);
BEGIN
	to.real := from.real; to.imag := from.imag;
	Gadgets.CopyObject(M, from, to)
END Copy;

PROCEDURE Handler*(obj: Objects.Object; VAR M: Objects.ObjMsg);
VAR obj0: Complex; x: FLOAT64;
BEGIN
	WITH obj: Complex DO
		IF M IS Objects.AttrMsg THEN
			WITH M: Objects.AttrMsg DO
				IF M.id = Objects.get THEN
					IF M.name = "Gen" THEN M.class := Objects.String; COPY("Complex.New", M.s); M.res := 0
					ELSIF M.name = "Real" THEN M.class := Objects.Real; M.x := obj.real; M.res := 0
					ELSIF M.name = "Imag" THEN M.class := Objects.Real; M.x := obj.imag; M.res := 0
					ELSIF M.name = "Rho" THEN M.class := Objects.Real; M.x := Math.sqrt(obj.real*obj.real + obj.imag*obj.imag); M.res := 0
					ELSIF M.name = "Phi" THEN M.class := Objects.Real; M.x := Phi(obj); M.res := 0
					ELSE Gadgets.objecthandle(obj, M)
					END
				ELSIF M.id = Objects.set THEN
					IF M.name = "Real" THEN
						IF M.class = Objects.String THEN Strings.StrToReal(M.s, x); M.x := SHORT(x); M.class := Objects.Real END;
						IF M.class = Objects.Real THEN obj.real := M.x; M.res := 0 END
					ELSIF M.name = "Imag" THEN
						IF M.class = Objects.String THEN Strings.StrToReal(M.s, x); M.x := SHORT(x); M.class := Objects.Real END;
						IF M.class = Objects.Real THEN obj.imag := M.x; M.res := 0 END
					ELSIF M.name = "Rho" THEN
						IF M.class = Objects.String THEN Strings.StrToReal(M.s, x); M.x := SHORT(x); M.class := Objects.Real END;
						IF M.class = Objects.Real THEN
							x := Phi(obj);
							obj.real := M.x*Math.cos(SHORT(x)); obj.imag := M.x*Math.sin(SHORT(x));
							M.res := 0
						END
					ELSIF M.name = "Phi" THEN
						IF M.class = Objects.String THEN Strings.StrToReal(M.s, x); M.x := SHORT(x); M.class := Objects.Real END;
						IF M.class = Objects.Real THEN
							x := Math.sqrt(obj.real*obj.real + obj.imag*obj.imag);
							obj.real := SHORT(x*Math.cos(M.x)); obj.imag := SHORT(x*Math.sin(M.x));
							M.res := 0
						END
					ELSIF M.name = "Value" THEN (* cannot be set *)
					ELSE Gadgets.objecthandle(obj, M)
					END
				ELSIF M.id = Objects.enum THEN
					M.Enum("Real"); M.Enum("Imag");  M.Enum("Rho"); M.Enum("Phi"); Gadgets.objecthandle(obj, M)
				END
			END
		ELSIF M IS Objects.CopyMsg THEN
			WITH M: Objects.CopyMsg DO
				IF M.stamp = obj.stamp THEN M.obj := obj.dlink	(* copy msg arrives again *)
				ELSE (* first time copy message arrives *)
					NEW(obj0); obj.stamp := M.stamp; obj.dlink := obj0;
					Copy(M, obj, obj0); M.obj := obj0
				END
			END
		ELSIF M IS Objects.FileMsg THEN
			WITH M: Objects.FileMsg DO
				IF M.id = Objects.store THEN
					Files.WriteReal(M.R, obj.real);
					Files.WriteReal(M.R, obj.imag)
				ELSIF M.id = Objects.load THEN
					Files.ReadReal(M.R, obj.real);
					Files.ReadReal(M.R, obj.imag)
				END;
				Gadgets.objecthandle(obj, M)
			END
		ELSE Gadgets.objecthandle(obj, M)
		END
	END
END Handler;

PROCEDURE Init*(obj: Complex);
BEGIN
	obj.handle := Handler; obj.real := 0.0; obj.imag := 0.0
END Init;

PROCEDURE New*;
VAR obj: Complex;
BEGIN
	NEW(obj); Init(obj); Objects.NewObj := obj
END New;

END Complex.

System.Free Complex ~
