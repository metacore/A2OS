(* Aos, Copyright 2001, Pieter Muller, ETH Zurich *)

MODULE FileDir IN Oberon;	(* pjm *)
(** AUTHOR "pjm"; PURPOSE "Oberon for Aos file directory"; *)

IMPORT Files IN A2;

CONST
	Directory*= Files.Directory;

TYPE
	FileName* = Files.FileName;

	EntryHandler* = PROCEDURE (name: ARRAY OF CHAR; time, date, size: SIGNED32; VAR continue: BOOLEAN);
	FileEnumerator*= PROCEDURE (path,name: ARRAY OF CHAR; time,date,size: SIGNED32; attrs: SET);

VAR
	PathChar*: CHAR;

PROCEDURE Enumerate*(mask: ARRAY OF CHAR; detail: BOOLEAN; proc: EntryHandler);
VAR enum: Files.Enumerator; time, date: SIGNED32; size: Files.Size; continue: BOOLEAN; name: FileName; flags: SET;
BEGIN
	NEW(enum);
	IF detail THEN enum.Open(mask, {Files.EnumSize, Files.EnumTime})
	ELSE enum.Open(mask, {})
	END;
	continue := TRUE;
	WHILE continue & enum.GetEntry(name, flags, time, date, size) DO
		proc(name, time, date, size(SIGNED32), continue)
	END;
	enum.Close
END Enumerate;

PROCEDURE EnumerateFiles*(path,pattern: ARRAY OF CHAR; detail: BOOLEAN; proc: FileEnumerator);
VAR i,j: SIGNED32;  enum: Files.Enumerator; name: FileName; continue: BOOLEAN; flags: SET; time, date: SIGNED32; size: Files.Size;
BEGIN
	i := 0;
	WHILE(path[i] # 0X) DO
		name[i] := path[i];
		INC(i);
	END;
	IF (i > 0) & (name[i-1] # PathChar) THEN name[i] := PathChar; INC(i); END;

	j := 0;
	WHILE(pattern[j] #0X) DO
		name[i] := pattern[j];
		INC(i); INC(j);
	END;
	name[i] := 0X;

	NEW(enum);
	IF detail THEN enum.Open(name, {Files.EnumSize, Files.EnumTime})
	ELSE enum.Open(name, {})
	END;
	continue := TRUE;

	WHILE continue & enum.GetEntry(name, flags, time, date, size) DO
		(* name -> path + name *)
		i := 0; j := 0;
		WHILE(name[i] # 0X) DO
			IF name[i] = PathChar THEN j := i; END;
			path[i] := name[i];
			INC(i);
		END;
		path[j] := 0X;
		IF name[j] = PathChar THEN INC(j) END;
		i := 0;
		WHILE(name[j] # 0X) DO
			name[i] := name[j];
			INC(i); INC(j);
		END;
		name[i] := 0X;

		proc(path,name,time,date,size(SIGNED32),flags)
	END;
	enum.Close

END EnumerateFiles;

PROCEDURE CreateDirectory*(name: ARRAY OF CHAR; done: BOOLEAN);
VAR res: INTEGER;
BEGIN
	Files.CreateDirectory(name,res);
	done := (res=0);
END CreateDirectory;



BEGIN
	PathChar := "/"
END FileDir.
