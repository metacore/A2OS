(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE WTSPict IN Oberon;	(** portable *)

	IMPORT WTS, Pictures, Objects, Files, Rembrandt;

	PROCEDURE Load(P: Pictures.Picture; VAR R: Files.Rider);
		VAR len: SIGNED32; ch: CHAR;
	BEGIN Files.Read(R, ch); Files.Read(R, ch);
		Files.Read(R, ch); Files.Read(R, ch);	(*pict id*)
		Pictures.Load(P, Files.Base(R), Files.Pos(R), len);
		(*Files.Set(R, Files.Base(R), Files.Pos(R)+len)*)
	END Load;

	PROCEDURE New*;
		VAR pict: Pictures.Picture; F: Rembrandt.Frame;
	BEGIN NEW(pict); Load(pict, WTS.R);
		NEW(F);
		Rembrandt.NewP(F, pict); Objects.NewObj := F
	END New;

END WTSPict.
