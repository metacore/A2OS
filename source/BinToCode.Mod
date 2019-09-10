MODULE BinToCode;	(** AUTHOR "negelef"; PURPOSE "Binary Code to Oberon code converter"; *)

IMPORT Files, Commands, Streams;

CONST
	BufferAddressName = "a";
	MaxBufferSize = 4;

TYPE
	Buffer = ARRAY MaxBufferSize OF CHAR;

VAR
	hexdigit: ARRAY 17 OF CHAR;

PROCEDURE WriteBuffer (w: Streams.Writer; CONST buffer: Buffer; offset, size: SIGNED32);
VAR
	i: SIGNED32;
BEGIN
	w.String ("SYSTEM.PUT"); w.Int (size * 8, 0);
	w.Char ("("); w.String (BufferAddressName); w.String (", 0");
	FOR i := size - 1 TO 0 BY -1 DO
		w.Char (hexdigit[ORD (buffer[offset + i]) DIV 10H]);
		w.Char (hexdigit[ORD (buffer[offset + i]) MOD 10H]);
	END;
	w.String ("H); INC ("); w.String (BufferAddressName);
	IF size > 1 THEN
		w.String (", "); w.Int (size, 0);
	END;
	w.String (");"); w.Ln;
END WriteBuffer;

(* Usage: Bin2Code.Convert binaryfile *)
PROCEDURE Convert* (context: Commands.Context);
VAR fileName: Files.FileName;
	reader: Files.Reader;
	buffer: Buffer;
	file: Files.File;
	size: SIGNED32;
	offset: SIGNED32;
	power: SIGNED32;
BEGIN
	context.arg.SkipWhitespace; context.arg.String (fileName);
	file := Files.Old (fileName);

	IF file = NIL THEN
		context.error.String ("Failed to open file ");
		context.error.String (fileName);
		context.error.Ln;
		RETURN;
	END;

	Files.OpenReader (reader, file, 0);

	size := 0; offset := 0;

	context.out.String ("(* put binary code copy of ");
	context.out.String (fileName);
	context.out.String (" to address ");
	context.out.String (BufferAddressName);
	context.out.String (" (cf. BinToCode.Mod ) *)");
	context.out.Ln;

	WHILE reader.res = Files.Ok DO
		reader.Char (buffer[size]);
		IF reader.res = Files.Ok THEN
			INC (size);
			IF size = MaxBufferSize THEN
				WriteBuffer (context.out, buffer, 0, size);
				size := 0;
			END;
		END;
	END;

	WHILE size # 0 DO
		IF size > 1 THEN
			power := (size DIV 2) * 2;
		ELSE
			power := 1;
		END;
		WriteBuffer (context.out, buffer, offset, power);
		INC (offset, power);
		DEC (size, power);
	END;
END Convert;

BEGIN
	hexdigit := "0123456789ABCDEF";
END BinToCode.

System.Free BinToCode~
BinToCode.Convert Tutorials.Book ~
