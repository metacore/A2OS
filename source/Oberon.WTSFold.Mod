(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE WTSFold IN Oberon;	(** portable *)

IMPORT
	Objects, Files, Texts, WTS, Outlines;

CONST
	colLeft* = 0; colRight* = 1; expRight* = 2; expLeft* = 3;	(*fold element mode*)
	leftMode = {colLeft, expLeft};

PROCEDURE New*;
VAR k, mode: SIGNED8;  len: SIGNED32; F: Outlines.Outline; t: Texts.Text; ch: CHAR;
BEGIN
	Objects.NewObj := NIL; F:= Outlines.MakeOutline(-1);
	Files.Read(WTS.R, k); mode := k MOD 4;
	IF mode IN leftMode THEN
		NEW(F.buf); Texts.OpenBuf(F.buf);
		IF k < 4 THEN
			NEW(t);
			Files.Read(WTS.R, ch);
			IF (ch = Texts.TextBlockId) THEN
				Texts.Load(t, Files.Base(WTS.R), Files.Pos(WTS.R), len);
				Texts.Save(t, 0, t.len, F.buf);
			END
		END
	END;
	IF mode = colLeft THEN
		F.fstate := Outlines.folded; Objects.NewObj := F
	ELSIF mode = colRight THEN
	ELSIF mode = expLeft THEN
		F.fstate := Outlines.open; Objects.NewObj := F
	ELSIF mode = expRight THEN
		F.fstate := Outlines.close; Objects.NewObj := F
	END
END New;

END WTSFold.
