(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE Streams IN Oberon;	(** portable *)
	IMPORT SYSTEM, Files;

	CONST
		closed* = 0; error* = 1; in* = 2; out* = 3; inout* = 4;
		binary* = 0; oberon* = 1; iso8859* = 2;

	TYPE
		Stream* = POINTER TO StreamDesc;
		StreamDesc* = RECORD
			ReadBytes*, WriteBytes*: PROCEDURE (S: Stream; VAR x: ARRAY OF SYSTEM.BYTE; n: SIGNED32);
			Available*: PROCEDURE (S: Stream): SIGNED32; (** returns the number of bytes which may read without blocking *)
			State*: PROCEDURE (S: Stream): SIGNED16; (** closed, error, in, out, inout *)
			Flush*: PROCEDURE (S: Stream); (** flush all buffers of the stream *)
			Close*: PROCEDURE (S: Stream); (** close the stream *)
			res*: SIGNED32; (** bytes requested but not read/written *)
			mode*: SIGNED16; (** binary, oberon, iso8859 *)
			eos*, buffer*: BOOLEAN (** set, when either the end of the stream is reached or the stream is closed. *)
		END;
		FileStream* = POINTER TO FileStreamDesc;
		FileStreamDesc = RECORD (StreamDesc)
			R: Files.Rider;
			state: SIGNED16;
			ch: CHAR
		END;

	VAR
		NULL*: Stream; (** a stream which does nothing *)

(** on any streams *)

	PROCEDURE Read*(S: Stream; VAR x: CHAR);
	BEGIN
		S.ReadBytes(S, x, 1)
	END Read;

	PROCEDURE Write*(S: Stream; x: CHAR);
	BEGIN
		S.WriteBytes(S, x, 1)
	END Write;

(** on binary streams *)
(** Portable routines to write and read the standard Oberon types. Each procedure is provided in a read and write pair. *)

	PROCEDURE ReadBool*(S: Stream; VAR x: BOOLEAN);
	BEGIN
		S.ReadBytes(S, x, 1)
	END ReadBool;

	PROCEDURE ReadInt*(S: Stream; VAR x: SIGNED16);
	BEGIN
		S.ReadBytes(S, x, 2)
	END ReadInt;

	PROCEDURE ReadLInt*(S: Stream; VAR x: SIGNED32);
	BEGIN
		S.ReadBytes(S, x, 4)
	END ReadLInt;

	PROCEDURE ReadLReal*(S: Stream; VAR x: FLOAT64);
	BEGIN
		S.ReadBytes(S, x, 8)
	END ReadLReal;

	PROCEDURE ReadNum*(S: Stream; VAR x: SIGNED32);
		VAR
			s, n: SIGNED32;
			ch: CHAR;
	BEGIN
		s := 0; n := 0;
		S.ReadBytes(S, ch, 1);
		WHILE ORD(ch) >= 128 DO
			INC(n, ASH(ORD(ch) - 128, s)); INC(s, 7); S.ReadBytes(S, ch, 1)
		END;
		x := n + ASH(ORD(ch) MOD 64 - ORD(ch) DIV 64 * 64, s)
	END ReadNum;

	PROCEDURE ReadReal*(S: Stream; VAR x: FLOAT32);
	BEGIN
		S.ReadBytes(S, x, 4)
	END ReadReal;

	PROCEDURE ReadSet*(S: Stream; VAR x: SET);
	BEGIN
		S.ReadBytes(S, x, 4)
	END ReadSet;

	PROCEDURE ReadString*(S: Stream; VAR x: ARRAY OF CHAR);
		VAR
			i: SIGNED32;
			ch: CHAR;
	BEGIN
		i := 0;
		REPEAT
			S.ReadBytes(S, ch, 1); x[i] := ch; INC(i)
		UNTIL ch = 0X
	END ReadString;

	PROCEDURE WriteBool*(S: Stream; x: BOOLEAN);
	BEGIN
		S.WriteBytes(S, x, 1)
	END WriteBool;

	PROCEDURE WriteInt*(S: Stream; x: SIGNED16);
	BEGIN
		S.WriteBytes(S, x, 2)
	END WriteInt;

	PROCEDURE WriteLInt*(S: Stream; x: SIGNED32);
	BEGIN
		S.WriteBytes(S, x, 4)
	END WriteLInt;

	PROCEDURE WriteLReal*(S: Stream; x: FLOAT64);
	BEGIN
		S.WriteBytes(S, x, 8)
	END WriteLReal;

	PROCEDURE WriteNum*(S: Stream; x: SIGNED32);
	BEGIN
		WHILE (x < - 64) OR (x > 63) DO
			Write(S, CHR(x MOD 128 + 128)); x := x DIV 128
		END;
		Write(S, CHR(x MOD 128))
	END WriteNum;

	PROCEDURE WriteReal*(S: Stream; x: FLOAT32);
	BEGIN
		S.WriteBytes(S, x, 4)
	END WriteReal;

	PROCEDURE WriteSet*(S: Stream; x: SET);
	BEGIN
		S.WriteBytes(S, x, 4)
	END WriteSet;

	PROCEDURE WriteString*(S: Stream; x: ARRAY OF CHAR);
		VAR i: SIGNED32;
	BEGIN
		i := 0;
		WHILE x[i] # 0X DO INC(i) END;
		S.WriteBytes(S, x, i+1)
	END WriteString;

	PROCEDURE NULLReadBytes(S: Stream; VAR x: ARRAY OF SYSTEM.BYTE; n: SIGNED32);
	END NULLReadBytes;

	PROCEDURE NULLWriteBytes(S: Stream; VAR x: ARRAY OF SYSTEM.BYTE; n: SIGNED32);
	END NULLWriteBytes;

	PROCEDURE NULLAvailable(S: Stream): SIGNED32;
	BEGIN
		RETURN 0
	END NULLAvailable;

	PROCEDURE NULLState(S: Stream): SIGNED16;
	BEGIN
		RETURN error
	END NULLState;

	PROCEDURE NULLFlush(S: Stream);
	END NULLFlush;

	PROCEDURE NULLClose(S: Stream);
	END NULLClose;

	PROCEDURE ReadFileBytes(S: Stream; VAR x: ARRAY OF SYSTEM.BYTE; n: SIGNED32);
		VAR pos: SIGNED32;
	BEGIN
		WITH S: FileStream DO
			pos := 0;
			WHILE ~S.eos & (n > 0) DO
				x[pos] := S.ch; INC(pos); DEC(n);
				Files.Read(S.R, S.ch); S.eos := S.R.eof
			END;
			S.res := n
		END
	END ReadFileBytes;

	PROCEDURE WriteFileBytes(S: Stream; VAR x: ARRAY OF SYSTEM.BYTE; n: SIGNED32);
	BEGIN
		WITH S: FileStream DO
			Files.WriteBytes(S.R, x, n);
			S.eos := FALSE; S.res := 0
		END
	END WriteFileBytes;

	PROCEDURE FileAvailable(S: Stream): SIGNED32;
	BEGIN
		WITH S: FileStream DO
			RETURN Files.Length(Files.Base(S.R)) - Files.Pos(S.R)
		END
	END FileAvailable;

	PROCEDURE FileState(S: Stream): SIGNED16;
	BEGIN
		WITH S: FileStream DO
			RETURN S.state
		END
	END FileState;

	PROCEDURE FileFlush(S: Stream);
	BEGIN
		WITH S: FileStream DO
			Files.Close(Files.Base(S.R))
		END
	END FileFlush;

	PROCEDURE FileClose(S: Stream);
	BEGIN
		WITH S: FileStream DO
			S.Flush(S);
			Files.Set(S.R, NIL, 0);
			S.eos := TRUE; S.state := closed
		END
	END FileClose;

(** Opens a stream reading on file F starting at postion pos. *)
	PROCEDURE OpenFileReader*(F: Files.File; pos: SIGNED32): Stream;
		VAR S: FileStream;
	BEGIN
		NEW(S); S.mode := binary; S.state := out;
		S.res := 0; Files.Set(S.R, F, pos); S.buffer := FALSE;
		S.ReadBytes := ReadFileBytes; S.eos := Files.Length(F) <= 0;
		Files.Read(S.R, S.ch);
		S.WriteBytes := NULL.WriteBytes;
		S.Available := FileAvailable;
		S.State := FileState;
		S.Flush := FileFlush;
		S.Close := FileClose;
		RETURN S
	END OpenFileReader;

(** Opens a stream writeing on file F starting at postion pos. *)
	PROCEDURE OpenFileWriter*(F: Files.File; pos: SIGNED32): Stream;
		VAR S: FileStream;
	BEGIN
		NEW(S); S.mode := binary; S.state := in; S.buffer := FALSE;
		S.res := 0; Files.Set(S.R, F, pos); S.eos := FALSE;
		S.ReadBytes := NULL.ReadBytes;
		S.WriteBytes := WriteFileBytes;
		S.Available := FileAvailable;
		S.State := FileState;
		S.Flush := FileFlush;
		S.Close := FileClose;
		RETURN S
	END OpenFileWriter;

	PROCEDURE FilePos*(S: FileStream): SIGNED32;
	BEGIN
		RETURN Files.Pos(S.R)
	END FilePos;

	PROCEDURE Copy*(src, dest: Stream);
		VAR
			buf: ARRAY 128 OF CHAR;
			len: SIGNED32;
	BEGIN
		WHILE ~src.eos DO
			len := src.Available(src);
			IF len > 128 THEN len := 128 END;
			src.ReadBytes(src, buf, len);
			dest.WriteBytes(dest, buf, len-src.res)
		END;
		dest.Flush(dest)
	END Copy;

BEGIN
	NEW(NULL); NULL.mode := binary; NULL.eos := FALSE; NULL.res := MAX(SIGNED16);
	NULL.ReadBytes := NULLReadBytes; NULL.WriteBytes := NULLWriteBytes;
	NULL.Available := NULLAvailable; NULL.State := NULLState;
	NULL.Flush := NULLFlush; NULL.Close := NULLClose; NULL.buffer := FALSE
END Streams.
