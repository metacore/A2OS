(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE Aos IN Oberon; (** AUTHOR "pjm"; PURPOSE "Aos toolbox for Oberon"; *)

IMPORT KernelLog IN A2, Objects IN A2, Streams IN A2, Commands IN A2, Texts, Oberon;

VAR
	w: Texts.Writer;

PROCEDURE Call*;	(** [\w] ( cmd {parms} | ^ ) ~ *)
VAR
	s: Texts.Scanner; par: POINTER TO ARRAY OF CHAR; i, len, pos, res, beg, end, time: SIGNED32;
	flags: SET; text: Texts.Text; msg: ARRAY 128 OF CHAR; ch: CHAR;
	context : Commands.Context; arg : Streams.StringReader; out : Streams.Writer;
BEGIN
	flags := {};
	Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(s);
	WHILE (s.class = Texts.Char) & (s.c = "\") DO
		Texts.Scan(s);
		IF s.class = Texts.Name THEN
			IF s.s = "w" THEN INCL(flags, Commands.Wait) END;
			Texts.Scan(s)
		END
	END;
	IF (s.class = Texts.Char) & (s.c = "^") THEN
		Oberon.GetSelection(text, beg, end, time);
		IF time # -1 THEN
			Texts.OpenScanner(s, text, beg);
			Texts.Scan(s);
		ELSE
			s.class := Texts.Inval
		END
	ELSE
		text := Oberon.Par.text
	END;
	IF s.class = Texts.Name THEN
		pos := Texts.Pos(s);
		Texts.Read(s, ch); len := 0;
		WHILE ~s.eot & (* (ch # 0DX) & *) (ch # "~") DO INC(len); Texts.Read(s, ch) END;
		NEW(par, len+1);
		Texts.OpenReader(s, text, pos);
		FOR i := 0 TO len-1 DO Texts.Read(s, par[i]) END;
		par[len] := 0X;
		NEW(arg, len + 1); arg.SetRaw(par^, 0, len+1);
		NEW(out, KernelLog.Send, 128);
		NEW(context, NIL, arg, out, out, NIL);
(*
		IF s.s = "Compiler.Compile" THEN
			Oberon.Par.text := text; Oberon.Par.pos := pos;
			Kernel.UnlockOberon
		END;
*)
		Commands.Activate(s.s, context, flags, res, msg);
(*
		IF s.s = "Compiler.Compile" THEN Kernel.LockOberon END;
*)
		IF res # 0 THEN
			Texts.WriteString(w, msg); Texts.WriteLn(w);
			Texts.Append(Oberon.Log, w.buf)
		END
	END
END Call;

PROCEDURE SetPriority*;	(** Low | Normal | High | priority *)
VAR s: Texts.Scanner;
BEGIN
	Texts.OpenScanner(s, Oberon.Par.text, Oberon.Par.pos);
	Texts.Scan(s);
	IF (s.class = Texts.Name) THEN
		s.class := Texts.Int;
		IF s.s = "Low" THEN s.i := Objects.Low
		ELSIF s.s = "Normal" THEN s.i := Objects.Normal
		ELSIF s.s = "High" THEN s.i := Objects.High
		ELSE s.class := Texts.Inval
		END
	END;
	IF (s.class = Texts.Int) & (s.i >= Objects.Low) & (s.i <= Objects.High) THEN
		Objects.SetPriority(s.i)
	END
END SetPriority;

BEGIN
	Texts.OpenWriter(w)
END Aos.

Aos.Call ^

Aos.SetPriority Low
Aos.SetPriority Normal
Aos.SetPriority High
