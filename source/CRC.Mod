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
	Init32 = SIGNED32(0FFFFFFFFH)  ;  (* initial CRC32 value *)

TYPE
	CRC16Stream* = OBJECT(Streams.Writer)
	VAR
		crc* : SIGNED16;

		PROCEDURE  &InitStream*;
		BEGIN
			crc := Init16;
			InitWriter(Send, 256)
		END InitStream;

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: INTEGER);
			VAR fcs, idx: SET32; i: SIZE;
		BEGIN
			fcs := SET32( crc ) * SET32( 0FFFFH );
			FOR i := ofs TO ofs + len - 1 DO
				idx := SET32( SIGNED32(fcs ) DIV 256 ) / SET32( LONG( ORD( buf[i] ) ) );
				fcs := CRC16Table[SIGNED32(idx) MOD 256] / SET32( SIGNED32(fcs ) * 256 )
			END;
			crc := SHORT( SIGNED32(fcs * SET32( 0FFFFH ) ) );
			res := Streams.Ok
		END Send;

		PROCEDURE SetCRC*(crc : SIGNED16);
		BEGIN
			Update();
			SELF.crc := crc;
		END SetCRC;

		PROCEDURE GetCRC*(): SIGNED16;
		BEGIN
			Update();
			RETURN crc
		END GetCRC;

	END CRC16Stream;

	CRC32Stream* = OBJECT(Streams.Writer)
	VAR
		crc : SIGNED32;

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

		PROCEDURE Send*(CONST buf: ARRAY OF CHAR; ofs, len: SIZE; propagate: BOOLEAN; VAR res: INTEGER);
		VAR idx: SIGNED32;
		BEGIN
			WHILE len > 0 DO
				idx := SIGNED32( SET32( crc) / SET32( LONG(ORD(buf[ofs])))) MOD 100H;
				crc := SIGNED32( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
				DEC(len); INC(ofs)
			END;
			res := Streams.Ok
		END Send;

		PROCEDURE SetCRC*(crc : SIGNED32);
		BEGIN
			Update();
			SELF.crc := crc;
		END SetCRC;

		PROCEDURE GetCRC*():SIGNED32;
		BEGIN
			Update();
			RETURN SIGNED32( SET32( crc)/{0..31})
		END GetCRC;

		PROCEDURE GetUninvertedCRC*():SIGNED32;
		BEGIN
			Update();
			RETURN crc
		END GetUninvertedCRC;
	END CRC32Stream;


TYPE CRC32*= OBJECT
	VAR crc : SIGNED32;

		PROCEDURE  &Init*;
		BEGIN
			crc := SIGNED32(0FFFFFFFFH);
		END Init;

		(* standard use: one character at a time *)
		PROCEDURE Char*(c: CHAR);
		VAR idx: SIGNED32;
		BEGIN
			idx := SIGNED32( SET32( crc) / SET32( LONG(ORD(c)))) MOD 100H;
			crc := SIGNED32( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
		END Char;

		(* nonstandard use - add a SIGNED32; LSB *)
		PROCEDURE Add*(i: SIGNED32);
		VAR idx: SIGNED32;
		BEGIN
			i:= SIGNED32( SET32( crc) / SET32( i));
			idx := i MOD 100H;
			crc := SIGNED32( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
			idx := i DIV 100H MOD 100H;
			crc := SIGNED32( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
			idx := i DIV 10000H MOD 100H;
			crc := SIGNED32( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
			idx := i DIV 1000000H MOD 100H;
			crc := SIGNED32( SET32( CRC32Table[idx])/SET32( LSH(crc, -8)));
		END Add;

		PROCEDURE Get*():SIGNED32;
		BEGIN
			RETURN SIGNED32( SET32( crc)/{0..31})
		END Get;

	END CRC32;

VAR
	CRC16Table, CRC32Table: ARRAY 256 OF SET32;

	PROCEDURE InitTable16;
	VAR fcs, t: SET32;  d, i, k: SIGNED32;
	BEGIN
		FOR i := 0 TO 255 DO
			fcs := { };  d := i*256;
			FOR k := 0 TO 7 DO
				t := fcs;  fcs := SET32( SIGNED32(fcs ) * 2 );
				IF (t / SET32( d )) * SET32( 8000H ) # {} THEN  fcs := fcs / SET32( 1021H ) END;
				d := d * 2
			END;
			CRC16Table[i] := fcs * SET32( 0FFFFH )
		END
	END InitTable16;

	PROCEDURE InitTable32;
	CONST poly = SIGNED32(0EDB88320H);
	VAR n, c, k: SIGNED32;
	BEGIN
		FOR n := 0 TO 255 DO
			c := n;
			FOR k := 0 TO 7 DO
				IF ODD(c) THEN c := SIGNED32( SET32( poly) / SET32( LSH(c, -1)))
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
