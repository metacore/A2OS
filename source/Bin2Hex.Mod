MODULE Bin2Hex;	(** AUTHOR "negelef"; PURPOSE "Binary file to Intel Hex-file converter"; *)

IMPORT Streams, Files, Commands;

PROCEDURE Byte (VAR w: Streams.Writer; val: LONGINT);
BEGIN w.Hex (val MOD 100H, -2);
END Byte;

PROCEDURE ExtendedAddressRecord* (VAR w: Streams.Writer; extadr: LONGINT);
BEGIN
	w.Char (':'); Byte (w, 2); Byte (w, 0); Byte (w, 0); Byte (w, 4);
	Byte (w, extadr DIV 100H); Byte (w, extadr);
	Byte (w, 100H - (2 + 0 + 0 + 4 + extadr DIV 100H MOD 100H + extadr MOD 100H) MOD 100H); w.Ln;
END ExtendedAddressRecord;

PROCEDURE DataRecord* (VAR w: Streams.Writer; CONST data: ARRAY OF CHAR; len, offset: LONGINT);
VAR checksum, i: LONGINT;
BEGIN
	checksum := len MOD 100H;
	INC (checksum, offset DIV 100H MOD 100H + offset MOD 100H);
	w.Char (':'); Byte (w, len); Byte (w, offset DIV 100H); Byte (w, offset); Byte (w, 0);
	FOR i := 0 TO len - 1 DO Byte (w, ORD (data[i])); INC (checksum, ORD (data[i])) END;
	Byte (w, 100H - checksum MOD 100H); w.Ln;
END DataRecord;

PROCEDURE EndOfFileRecord* (VAR w: Streams.Writer);
BEGIN w.Char (':'); Byte (w, 0); Byte (w, 0); Byte (w, 0); Byte (w, 1); Byte (w, 255); w.Ln;
END EndOfFileRecord;

PROCEDURE ConvertFile* (r: Streams.Reader; w: Streams.Writer; offset, maxlen: LONGINT);
VAR len, extadr: LONGINT; c: CHAR; data: POINTER TO ARRAY  OF CHAR;
BEGIN
	NEW(data,maxlen+1);
	extadr := offset DIV 10000H;
	IF extadr # 0 THEN ExtendedAddressRecord (w, extadr); END;

	REPEAT
		len := 0;
		LOOP
			r.Char (c); IF r.res # Files.Ok THEN EXIT END;
			data[len] := c; INC (len); IF len = maxlen THEN EXIT END;
		END;

		IF len # 0 THEN DataRecord (w, data^, len, offset) END;

		INC (offset, len);
		IF offset DIV 10000H # extadr THEN
			extadr := offset DIV 10000H;
			ExtendedAddressRecord (w, extadr);
		END;
	UNTIL r.res # Files.Ok;

	EndOfFileRecord (w);
END ConvertFile;

PROCEDURE Convert* (context: Commands.Context);
VAR
	source, dest: ARRAY Files.NameLength OF CHAR;
	offset, maxlen: LONGINT;
	src, dst: Files.File;
	r: Files.Reader; w: Files.Writer;
BEGIN
	context.arg.SkipWhitespace; context.arg.String (source);
	context.arg.SkipWhitespace; context.arg.String (dest);
	IF ~context.arg.GetInteger (offset, TRUE) THEN offset := 0 END;
	IF ~context.arg.GetInteger (maxlen, TRUE) THEN maxlen := 255 END;

	src := Files.Old (source);
	IF src = NIL THEN
		context.error.String ("failed to open binary file '"); context.error.String (source); context.error.Char ("'"); context.error.Ln;
		context.result := Commands.CommandError; RETURN;
	END;

	dst := Files.New (dest);
	IF src = NIL THEN
		context.error.String ("failed to open hex file '"); context.error.String (dest); context.error.Char ("'"); context.error.Ln;
		context.result := Commands.CommandError; RETURN;
	END;

	Files.OpenReader (r, src, 0); Files.OpenWriter (w, dst, 0);
	ConvertFile (r, w, offset, maxlen);

	w.Update;
	Files.Register (dst);
END Convert;

END Bin2Hex.
