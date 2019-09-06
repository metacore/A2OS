MODULE CRC; (** AUTHOR "prk/TF"; PURPOSE "CRC utilities"; *)
(**
 * History:
 *
 *	28.09.2000	added CRC32 support -- TF
 *	08.01.2007	added SetCRC procedures to enable other initial values (staubesv)
 *)

IMPORT
	SYSTEM, Streams;

CONST
	Init16 = -1;	(* initial CRC16 value *)
	Init32 = LONGINT(0FFFFFFFFH)  ;  (* initial CRC32 value *)

TYPE
	CRC16Stream* = OBJECT(Streams.Writer)
	VAR
		crc* : INTEGER;

		PROCEDURE  &InitStream*;
		BEGIN
			crc := Init16;
			InitWriter(Send, 256)
		END InitStream;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: WORD);
			VAR fcs, idx: SET32; i: SIZE;
		BEGIN
			fcs := SET32( crc ) * SET32( 0FFFFH );
			FOR i := ofs TO ofs + len - 1 DO
				idx := SET32( LONGINT(fcs ) DIV 256 ) / SET32( LONG( ORD( buf[i] ) ) );
				fcs := CRC16Table[LONGINT(idx) MOD 256] / SET32( LONGINT(fcs ) * 256 )
			END;
			crc := SHORT( LONGINT(fcs * SET32( 0FFFFH ) ) );
			res := Streams.Ok
		END Send;

		PROCEDURE SetCRC*(crc : INTEGER);
		BEGIN
			Update();
			SELF.crc := crc;
		END SetCRC;

		PROCEDURE GetCRC*(): INTEGER;
		BEGIN
			Update();
			RETURN crc
		END GetCRC;

	END CRC16Stream;

	CRC32Stream* = OBJECT(Streams.Writer)
	VAR
		crc : LONGINT;

		PROCEDURE  &InitStream*;
		BEGIN
			crc := Init32;
			InitWriter(Send, 256)
		END InitStream;

		PROCEDURE Reset*;
		BEGIN
			Update();
			crc := Init32
		END Reset;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: WORD);
		VAR idx: LONGINT;
		BEGIN
			WHILE len > 0 DO
				idx := LONGINT( SET32( crc) / SET32( LONG(ORD(buf[ofs])))) MOD 100H;
				crc := LONGINT( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
				DEC(len); INC(ofs)
			END;
			res := Streams.Ok
		END Send;

		PROCEDURE SetCRC*(crc : LONGINT);
		BEGIN
			Update();
			SELF.crc := crc;
		END SetCRC;

		PROCEDURE GetCRC*():LONGINT;
		BEGIN
			Update();
			RETURN LONGINT( SET32( crc)/{0..31})
		END GetCRC;

		PROCEDURE GetUninvertedCRC*():LONGINT;
		BEGIN
			Update();
			RETURN crc
		END GetUninvertedCRC;
	END CRC32Stream;


TYPE CRC32*= OBJECT
	VAR crc : LONGINT;

		PROCEDURE  &Init*;
		BEGIN
			crc := LONGINT(0FFFFFFFFH);
		END Init;

		(* standard use: one character at a time *)
		PROCEDURE Char*(c: CHAR);
		VAR idx: LONGINT;
		BEGIN
			idx := LONGINT( SET32( crc) / SET32( LONG(ORD(c)))) MOD 100H;
			crc := LONGINT( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
		END Char;

		(* nonstandard use - add a LONGINT; LSB *)
		PROCEDURE Add*(i: LONGINT);
		VAR idx: LONGINT;
		BEGIN
			i:= LONGINT( SET32( crc) / SET32( i));
			idx := i MOD 100H;
			crc := LONGINT( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
			idx := i DIV 100H MOD 100H;
			crc := LONGINT( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
			idx := i DIV 10000H MOD 100H;
			crc := LONGINT( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
			idx := i DIV 1000000H MOD 100H;
			crc := LONGINT( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
		END Add;

		PROCEDURE Get*():LONGINT;
		BEGIN
			RETURN LONGINT( SET32( crc)/{0..31})
		END Get;

	END CRC32;

VAR
	CRC16Table, CRC32Table: ARRAY 256 OF SET32;

	PROCEDURE InitTable16;
	VAR fcs, t: SET32;  d, i, k: LONGINT;
	BEGIN
		FOR i := 0 TO 255 DO
			fcs := { };  d := i*256;
			FOR k := 0 TO 7 DO
				t := fcs;  fcs := SET32( LONGINT(fcs ) * 2 );
				IF (t / SET32( d )) * SET32( 8000H ) # {} THEN  fcs := fcs / SET32( 1021H ) END;
				d := d * 2
			END;
			CRC16Table[i] := fcs * SET32( 0FFFFH )
		END
	END InitTable16;

	PROCEDURE InitTable32;
	CONST poly = LONGINT(0EDB88320H);
	VAR n, c, k: LONGINT;
	BEGIN
		FOR n := 0 TO 255 DO
			c := n;
			FOR k := 0 TO 7 DO
				IF ODD(c) THEN c := LONGINT( SET32( poly) / SET32( LSH(c, -1)))
				ELSE c := LSH(c, -1)
				END
			END;
			CRC32Table[n] := SET32( c)
		END
	END InitTable32;

BEGIN
	InitTable16;
	InitTable32
END CRC.

System.Free CRC ~
