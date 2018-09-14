MODULE RealConversions;  (* GF *)

IMPORT SYSTEM;

TYPE 
	ReadProc* = PROCEDURE {DELEGATE} ( ): CHAR;

VAR
	H, L: INTEGER;

	(**	Scan a floating-point number. 
		EBNF: Real = Digit {Digit} '.' Digit {Digit} ['e'|'E' ['+'|'-'] Digit {Digit}]. *)
	PROCEDURE ScanReal*( next: ReadProc ): LONGREAL;
	VAR 
		e: INTEGER; y, g: LONGREAL; neg, negE: BOOLEAN; ch: CHAR;
	BEGIN
		ch := next();
		WHILE (ch = "0") DO  ch := next()  END;
		IF ch = "-" THEN  neg := TRUE; ch := next()  ELSE  neg := FALSE  END;
		WHILE (ch = " ") OR (ch = "0") DO  ch := next()  END;
		y := 0;
		WHILE ("0" <= ch) & (ch <= "9") DO
			y := y * 10 + (ORD(ch) - ORD("0"));
			ch := next();
		END;
		IF ch = "." THEN
			ch := next();
			g := 1;
			WHILE ("0" <= ch) & (ch <= "9") DO
				g := g / 10;  y := y + g * (ORD(ch) - ORD("0"));
				ch := next()
			END;
		END;
		IF (ch = "d") OR (ch = "D") OR (ch = "e") OR (ch = "E") THEN
			ch := next();  e := 0;
			IF ch = "-" THEN  negE := TRUE; ch := next()
			ELSIF ch = "+" THEN  negE := FALSE; ch := next()
			ELSE  negE := FALSE
			END;
			WHILE (ch = "0") DO  ch := next()  END;
			WHILE ("0" <= ch) & (ch <= "9") DO
				e := e * 10 + (ORD(ch) - ORD("0"));
				ch := next()
			END;
			IF negE THEN  y := y / Ten(e)
			ELSE  y := y * Ten(e)
			END;
		END;
		IF neg THEN  y := -y  END;
		RETURN y
	END ScanReal;
	


	(**	Convert LONGREAL x  to string using n character positions. *)
	PROCEDURE RealToString*( x: LONGREAL;  n: WORD;  VAR buf: ARRAY OF CHAR );
	(* BM 1993.4.22. Do not simplify rounding! *)
	VAR 
		e, h, l, i, pos: LONGINT;  z: LONGREAL;  d: ARRAY 16 OF CHAR;
		
		PROCEDURE Char( c: CHAR );
		BEGIN
			buf[pos] := c;  INC( pos )
		END Char;
		
		PROCEDURE String( CONST s: ARRAY OF CHAR );
		VAR i: LONGINT;
		BEGIN
			i := 0;
			WHILE s[i] # 0X DO  Char( s[i] );  INC( i )  END
		END String;
			
	BEGIN
		pos := 0;
		e := ExpoL( x );
		IF e = 2047 THEN
			WHILE n > 5 DO  Char( " " );  DEC( n )  END;
			NaNCodeL( x, h, l );
			IF (h # 0) OR (l # 0) THEN  String( "  NaN" )
			ELSIF x < 0 THEN  String(" -INF" )
			ELSE  String("  INF" )
			END
		ELSE
			IF n <= 9 THEN  n := 1  ELSE  DEC( n, 8 )  END;
			REPEAT  Char( " " );  DEC( n )  UNTIL n <= 15;   (* 0 <= n <= 15 fraction digits *)
			IF (e # 0) & (x < 0) THEN  Char( "-" );  x := -x  ELSE  Char( " " )  END;
			IF e = 0 THEN
				h := 0;  l := 0 (* no denormals *)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
				z := Ten( e + 1 );
				IF x >= z THEN  x := x / z;  INC( e )  ELSE  x := x * Ten( -e )  END;
				IF x >= 10 THEN  x := x * Ten( -1 ) + 0.5D0 / Ten( n );  INC( e )
				ELSE
					x := x + 0.5D0 / Ten( n );
					IF x >= 10 THEN  x := x * Ten( -1 );  INC( e )  END
				END;
				x := x * Ten( 7 );  h := ENTIER( x );  x := (x - h) * Ten( 8 );  l := ENTIER( x )
			END;
			i := 15;
			WHILE i > 7 DO  d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i )  END;
			WHILE i >= 0 DO  d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i )  END;
			Char( d[0] );  Char( "." );  i := 1;
			WHILE i <= n DO  Char( d[i] );  INC( i )  END;
			IF e < 0 THEN  String( "E-" );  e := -e  ELSE  String( "E+" )  END;
			Char( CHR( e DIV 100 + ORD( "0" ) ) );  e := e MOD 100;  
			Char( CHR( e DIV 10 + ORD( "0" ) ) );  Char( CHR( e MOD 10 + ORD( "0" ) ) )
		END;
		Char( 0X )
	END RealToString;


	(**	Convert LONGREAL x to string in a fixed point notation. 
		n is the overall minimal length for the output field, f the number of fraction digits following the decimal point, 
		D the fixed exponent (printed only when D # 0). *)
	PROCEDURE RealToStringFix*( x: LONGREAL;  n, f, D: WORD; VAR buf: ARRAY OF CHAR );
	(* BM 1993.4.22. Do not simplify rounding! / JG formatting adjusted *)
	VAR 
		e, h, l, i, pos: LONGINT;  r, z: LONGREAL;
		d: ARRAY 16 OF CHAR;
		s: CHAR;  dot: BOOLEAN;
		
		PROCEDURE Char( c: CHAR );
		BEGIN
			buf[pos] := c;  INC( pos )
		END Char;
		
		PROCEDURE String( CONST s: ARRAY OF CHAR );
		VAR i: LONGINT; ch: CHAR;
		BEGIN
			ch := s[0]; i := 1;
			WHILE ch # 0X DO  Char( ch );  ch := s[i];  INC( i )  END
		END String;
			
	BEGIN
		pos := 0;
		e := ExpoL( x );
		IF (e = 2047) OR (ABS( D ) > 308) THEN
			WHILE n > 5 DO  Char( " " );  DEC( n )  END;
			NaNCodeL( x, h, l );
			IF (h # 0) OR (l # 0) THEN  String( "  NaN" )
			ELSIF x < 0 THEN  String( " -INF" )
			ELSE  String( "  INF" )
			END
		ELSE
			IF D = 0 THEN 
				IF f = 0 THEN  dot := FALSE; DEC( n, 1 )  ELSE  dot := TRUE;  DEC( n, 2 )  END 
			ELSE  dot := TRUE;  DEC( n, 7 ) 
			END;
			IF n < 2 THEN  n := 2  END;
			IF f < 0 THEN  f := 0  END;
			IF n < f + 2 THEN  n := f + 2  END;
			DEC( n, f );
			IF (e # 0) & (x < 0) THEN  s := "-";  x := -x  ELSE  s := " "  END;
			IF e = 0 THEN
				h := 0;  l := 0;  DEC( e, D - 1 ) (* no denormals *)
			ELSE
				e := (e - 1023) * 301029 DIV 1000000;   (* ln(2)/ln(10) = 0.301029996 *)
				z := Ten( e + 1 );
				IF x >= z THEN  x := x / z;  INC( e )  ELSE  x := x * Ten( -e )  END;
				DEC( e, D - 1 );  i := -(e + f);
				IF i <= 0 THEN  r := 5 * Ten( i )  ELSE  r := 0  END;
				IF x >= 10 THEN  x := x * Ten( -1 ) + r;  INC( e )
				ELSE
					x := x + r;
					IF x >= 10 THEN  x := x * Ten( -1 );  INC( e )  END
				END;
				x := x * Ten( 7 );  h := ENTIER( x );  x := (x - h) * Ten( 8 );  l := ENTIER( x )
			END;
			i := 15;
			WHILE i > 7 DO  d[i] := CHR( l MOD 10 + ORD( "0" ) );  l := l DIV 10;  DEC( i )  END;
			WHILE i >= 0 DO  d[i] := CHR( h MOD 10 + ORD( "0" ) );  h := h DIV 10;  DEC( i )  END;
			IF n <= e THEN  n := e + 1  END;
			IF e > 0 THEN
				WHILE n > e DO  Char( " " );  DEC( n )  END;
				Char( s );  e := 0;
				WHILE n > 0 DO
					DEC( n );
					IF e < 16 THEN  Char( d[e] );  INC( e )  ELSE  Char( "0" )  END
				END;
				IF dot THEN  Char( "." )  END;
			ELSE
				WHILE n > 1 DO  Char( " " );  DEC( n )  END;
				Char( s );  Char( "0" );  IF dot  THEN Char( "." )  END;
				WHILE (0 < f) & (e < 0) DO  Char( "0" );  DEC( f );  INC( e )  END
			END;
			WHILE f > 0 DO
				DEC( f );
				IF e < 16 THEN  Char( d[e] );  INC( e )  ELSE  Char( "0" )  END
			END;
			IF D # 0 THEN
				IF D < 0 THEN  String( "E-" );  D := -D  ELSE  String( "E+" )  END;
				Char( CHR( D DIV 100 + ORD( "0" ) ) );  D := D MOD 100;  
				Char( CHR( D DIV 10 + ORD( "0" ) ) );  Char( CHR( D MOD 10 + ORD( "0" ) ) )
			END
		END;
		Char( 0X )
	END RealToStringFix;
	
	

	(*** the following procedures stem from Reals.Mod *)

	(** Returns the NaN code (0 <= h < 1048576, MIN(LONGINT) <= l <= MAX(LONGINT)) or (-1,-1) if not NaN/Infinite. *)
	PROCEDURE NaNCodeL( x: LONGREAL;  VAR h, l: LONGINT );
	BEGIN
		SYSTEM.GET( ADDRESSOF( x ) + H, h );  SYSTEM.GET( ADDRESSOF( x ) + L, l );
		IF ASH( h, -20 ) MOD 2048 = 2047 THEN  (* Infinite or NaN *)
			h := h MOD 100000H (* lowest 20 bits *)
		ELSE h := -1;  l := -1
		END
	END NaNCodeL;


	(** Returns the shifted binary exponent (0 <= e < 2048). *)
	PROCEDURE ExpoL( x: LONGREAL ): LONGINT;
	VAR i: LONGINT;
	BEGIN
		SYSTEM.GET( ADDRESSOF( x ) + H, i );  RETURN ASH( i, -20 ) MOD 2048
	END ExpoL;

	(** Convert hexadecimal to LONGREAL. h and l are the high and low parts.*)
	PROCEDURE RealL( h, l: LONGINT ): LONGREAL;
	VAR x: LONGREAL;
	BEGIN
		SYSTEM.PUT( ADDRESSOF( x ) + H, h );  SYSTEM.PUT( ADDRESSOF( x ) + L, l );  RETURN x
	END RealL;


	(** Returns 10^e (e <= 308, 308 < e delivers IEEE-code +INF). *)
	PROCEDURE Ten( e: LONGINT ): LONGREAL;   (* naiive version *)
	VAR r: LONGREAL;
	BEGIN
		IF e < -307 THEN RETURN 0
		ELSIF 308 < e THEN RETURN RealL( 2146435072, 0 )
		END;
		r := 1;
		WHILE (e > 0) DO r := r * 10;  DEC( e );  END;
		WHILE (e < 0) DO r := r / 10;  INC( e );  END;
		RETURN r;
	END Ten;

	PROCEDURE InitHL;
	VAR i: ADDRESS;  dmy: INTEGER;  littleEndian: BOOLEAN;
	BEGIN
		dmy := 1;  i := ADDRESSOF( dmy );
		SYSTEM.GET( i, littleEndian );   (* indirection via i avoids warning on SUN cc -O *)
		IF littleEndian THEN  H := 4;  L := 0  ELSE  H := 0;  L := 4  END
	END InitHL;

BEGIN  
	InitHL
END RealConversions.

