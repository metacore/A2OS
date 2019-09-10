(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE TGZ IN Oberon;	(* pjm *)

IMPORT GZReaders, Files, Texts, Oberon, In;

CONST
	UnexpectedEOF = -5;
	WriteError = -6;

TYPE
	FileName = ARRAY 64 OF CHAR;

VAR
	w: Texts.Writer;

PROCEDURE WriteInfo(flag: CHAR; size: SIGNED32; VAR buf, fname: ARRAY OF CHAR; f: Files.File);
VAR name: FileName;
BEGIN
	Texts.Write(w, flag); Texts.Write(w, " "); Texts.WriteInt(w, size, 1);
	Texts.Write(w, " "); Texts.WriteString(w, buf); Texts.Write(w, " ");
	IF f # NIL THEN
		Files.GetName(f, name); Texts.WriteString(w, name)
	ELSE
		IF fname[0] # 0X THEN Texts.WriteString(w, fname); Texts.Write(w, " ") END;
		Texts.WriteString(w, "<ignored>")
	END;
	Texts.WriteLn(w); Texts.Append(Oberon.Log, w.buf)
END WriteInfo;

PROCEDURE GenName(VAR prefix, buf, fname: ARRAY OF CHAR);
VAR i, j: SIGNED32;
BEGIN
	i := 0; WHILE prefix[i] # 0X DO fname[i] := prefix[i]; INC(i) END;
	j := 0; WHILE buf[j] # 0X DO fname[i] := buf[j]; INC(i); INC(j) END;
	fname[i] := 0X
END GenName;

PROCEDURE GetNum(VAR buf: ARRAY OF CHAR; ofs, max: SIGNED32): SIGNED32;
VAR x: SIGNED32;
BEGIN
	x := 0;
	WHILE (max # 0) & (buf[ofs] = " ") DO INC(ofs); DEC(max) END;
	WHILE (max # 0) & (buf[ofs] >= "0") & (buf[ofs] <= "7") DO
		x := x * 8 + (ORD(buf[ofs])-ORD("0"));
		INC(ofs); DEC(max)
	END;
	RETURN x
END GetNum;

PROCEDURE UnpackTGZ(tgzname, prefix: ARRAY OF CHAR; VAR res: INTEGER);
CONST
	RS = 512;
VAR
	in: GZReaders.Reader; buf: ARRAY RS OF CHAR; read, size: SIGNED32; flag: CHAR;
	f: Files.File; r: Files.Rider; fname: FileName;
BEGIN
	GZReaders.Open(in, Files.Old(tgzname));
	IF in.res = GZReaders.Ok THEN
		LOOP
			GZReaders.ReadBytes(in, buf, 0, RS, read);	(* read file header *)
			IF in.res # GZReaders.Ok THEN res := in.res; EXIT END;
			IF (read = RS) & (buf[0] # 0X) THEN
				size := GetNum(buf, 7CH, 12);
				flag := buf[9CH];
				IF flag = "5" THEN size := 0	(* ignore size on directory *)
				ELSIF flag = 0X THEN flag := "0"	(* old unix-compatible flag *)
				END;
				IF flag = "0" THEN	(* normal file *)
					GenName(prefix, buf, fname); f := Files.New(fname)
				ELSE
					fname[0] := 0X; f := NIL
				END;
				WriteInfo(flag, size, buf, fname, f);
				Files.Set(r, f, 0);
				WHILE size > 0 DO
					GZReaders.ReadBytes(in, buf, 0, RS, read);
					IF in.res < 0 THEN res := in.res; EXIT END;
					IF (read # RS) THEN res := UnexpectedEOF; EXIT END;
					IF f # NIL THEN
						IF read > size THEN read := size END;
						Files.WriteBytes(r, buf, read);
						IF r.res # 0 THEN res := WriteError; EXIT END
					END;
					DEC(size, RS)
				END;
				IF f # NIL THEN Files.Register(f) END
			ELSE
				IF (in.res = GZReaders.StreamEnd) OR (read = 0) THEN res := 0
				ELSIF read # RS THEN res := UnexpectedEOF
				ELSE res := in.res
				END;
				EXIT
			END
		END;
		GZReaders.Close(in)
	ELSE
		res := in.res
	END
END UnpackTGZ;

PROCEDURE Extract*;	(** file.tgz dstprefix *)
VAR res: INTEGER; name, prefix: FileName;
BEGIN
	In.Open; In.String(name); In.String(prefix);
	IF In.Done THEN
		UnpackTGZ(name, prefix, res);
		IF res # 0 THEN
			Texts.WriteString(w, "Unpack error "); Texts.WriteInt(w, res, 1); Texts.WriteLn(w)
		END;
		Texts.Append(Oberon.Log, w.buf)
	END
END Extract;

BEGIN
	Texts.OpenWriter(w)
END TGZ.
