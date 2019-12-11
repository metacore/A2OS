MODULE MoveToFront;  (** AUTHOR GF; PURPOSE "move to front transformation" *)

TYPE 	
	MTF* = OBJECT
		VAR
			alpha: INTEGER;
			list: ARRAY 256 OF INTEGER;
		
		PROCEDURE &Initialize*;
		VAR
			i: INTEGER;
		BEGIN 
			alpha := 0;
			FOR i := 0 TO 255 DO
				list[i] := (i + 1) MOD 256;
			END;
		END Initialize;

	
		PROCEDURE Encode*( c: CHAR ): CHAR;
		VAR
			l, m, k, n: INTEGER;
		BEGIN 
			n := ORD( c );
			IF n = alpha THEN  RETURN 0X  END;
			l := alpha;  k := 1;  m := list[l];
			WHILE m # n DO
				INC( k );  l := m;  m := list[l];
			END;
			list[l] := list[m];  list[m] := alpha;  alpha := m;
			RETURN CHR( k );
		END Encode;
		
		
		PROCEDURE Decode*( ch: CHAR ): CHAR;
		VAR
			l, m, c: INTEGER;
		BEGIN 
			IF ch = 0X THEN  RETURN CHR( alpha )  END;
			c := ORD( ch ) - 1;  l := alpha; 
			WHILE c > 0 DO
				l := list[l];  DEC( c );
			END;
			m := list[l];  list[l] := list[m];  list[m] := alpha;
			alpha := m;
			RETURN CHR( m );
		END Decode;
		
	END MTF;

END MoveToFront.

