MODULE BitStreams;	(* GF *)

IMPORT Streams;

TYPE
	BitReader* = OBJECT
	VAR
		r: Streams.Reader;
		byte, bit: INTEGER;
		
		PROCEDURE &New*( arch: Streams.Reader );
		BEGIN 
			r := arch;
			bit := 0;
		END New;
		
		PROCEDURE Reset*;
		BEGIN
			bit := 0;
		END Reset;

		PROCEDURE InBit*( ): INTEGER;
		VAR
			i: INTEGER;  ch: CHAR;
		BEGIN 
			IF bit = 0 THEN
				r.Char( ch ); byte := ORD( ch )
			END;
			i := ASH( byte, bit - 8 + 1) MOD 2;
			bit := (bit + 1) MOD 8;
			RETURN i;
		END InBit;

		PROCEDURE InBits*( n: INTEGER ): INTEGER;
		VAR
			i, c: INTEGER;
		BEGIN 
			c := 0;
			FOR i := 1 TO n DO
				c := 2*c + InBit();
			END;
			RETURN c;
		END InBits;
		
	END BitReader;
	
	
	
	BitWriter* = OBJECT
	VAR
		w: Streams.Writer;
		byte, bit: INTEGER;
		
		PROCEDURE &Init*( arch: Streams.Writer );
		BEGIN
			w := arch;
			bit := 0;  byte := 0;
		END Init;
		
		PROCEDURE OutBit*( b: INTEGER );
		BEGIN 
			byte := 2*byte + b;
			bit := (bit + 1) MOD 8;
			IF bit = 0 THEN
				w.Char( CHR( byte ) );  byte := 0;
			END;
		END OutBit;

		PROCEDURE OutBits*( c, n: INTEGER );
		VAR
			i: INTEGER;
		BEGIN 
			FOR i := n - 1 TO 0 BY -1 DO
				OutBit( ASH( c, -i ) MOD 2 );
			END;
		END OutBits;
			
		PROCEDURE Finish*;
		BEGIN 
			WHILE bit > 0 DO  OutBit( 0 )  END;
			w.Update
		END Finish;
		
	END BitWriter;
	
END BitStreams.