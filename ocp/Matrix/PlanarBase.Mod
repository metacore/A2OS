MODULE PlanarBase;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

IMPORT Out := KernelLog, MatrixBase,SYSTEM;

CONST
	cachesize* = 256 * 1024;   (* make dynamic *)
	cachefraction = 0.5;   (* how much of cache should be used for temporary data structure. This might be a good starting point for  ATLAS like machine-adaptive optimizations *)

TYPE
	Datatype* = MatrixBase.Datatype;
	Complex*=MatrixBase.Complex;
	OneD* = ARRAY [*] OF Datatype;
	TwoD* = ARRAY [*,*] OF Datatype;
	ThreeD* = ARRAY [*,*,*] OF Datatype;
	LineHandler* = PROCEDURE {DELEGATE} ( CONST lineIn: OneD;
																		   VAR lineOut: OneD );

VAR
	Comments: BOOLEAN;
	(*debug*) t1, t2, t0: SIGNED32;  testscale: SIGNED16;

	(** applies a procedure 'linehandler' to all lines of a 2D dataset in the indicated directions. Avoids cache misses by copying the data into a work array that fits into the cache.*)
	PROCEDURE HandleLines2D*( CONST data: TwoD;  VAR resdata: TwoD;
													    directions: SET;  linehandler: LineHandler );
	VAR templine, templine1: OneD;  rect, resrect: TwoD;
		x, y, z, w0, w, h, i, j, lenX, lenY: SIZE;
	BEGIN
		lenX := LEN( data, 1 );  lenY := LEN( data, 0 );
		IF 1 IN directions THEN  (*along x*)
			FOR y := 0 TO lenY - 1 DO linehandler( data[y], resdata[y] ) END;
		END;

		(* here, a slice in the XZ plane is cut from the data, with a size small enough to fit in cache. This should limit cache misses in the inner loop.
					Note that the XZ plane is better than the YZ plane for line handling in the z dimension, because entire lines
					can be extracted from the internal data structures   *)
		IF 0 IN directions THEN  (*additional optimization option: only cut 'rect' out of data if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			lenX := LEN( resdata, 1 );
			h := lenY;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( resdata, (*1*)0 ), w0 );
				j := 0;
				WHILE j < lenX DO  (*work in slices of full lenY size, but limited with w to avoid cache misses *)
					w := MIN( w0, lenX - j );
					IF 1 IN directions THEN rect[.. , .. w - 1] := resdata[.. , j..j + w - 1];
					ELSE rect[.. , .. w - 1] := data[.. , j..j + w - 1];
					END;
					FOR x := 0 TO w - 1 DO
						templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
						linehandler( templine, templine1 );  resrect[.. , x] := templine1;
						(*linehandler(rect[..,x], resrect[..,x]);*)
					END;
					resdata[.. , j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
				END;
			lenY := LEN( resdata, (*1*) 0 );
		END;
	END HandleLines2D;

	PROCEDURE copy( CONST in: OneD;  VAR in2: OneD );
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( in,0 ) - 1 DO in2[i] := in[i];  END;
	END copy;

	PROCEDURE out( CONST in: OneD;  VAR in2: OneD );
	VAR i: SIZE;
	BEGIN
		FOR i := 0 TO LEN( in,0 ) - 1 DO Out.Int( ENTIER( in2[i] ), 6 );  (*Out.Int(  in2[i] , 6 );*) END;
		Out.Ln;
	END out;

(*
	PROCEDURE Test*;
	VAR x, y, z, s, rep, time, i, j: SIGNED32;  data, resdata: TwoD;
	BEGIN
		In.Open;  In.LongInt( s );  In.LongInt( rep );
		IF In.Done THEN
			Out.String( "demonstrates fast linewise handling in arbitrary dimensional dataset, using temporary rectangles with size<cache to avoid cache misses" );  Out.Ln;  Out.String( "data size [kB]: " );
			Out.Int( s * s *  SIZE( Datatype ) DIV 1024, 16 );  Out.Ln;  t0 := 0;
			t1 := 0;  t2 := 0;  NEW( data, s, s );  NEW( resdata, s, s );
			FOR y := 0 TO s - 1 DO
				FOR x := 0 TO s - 1 DO data[y, x] := y * s + x;  END;
			END;
			t0 := 0;  t1 := 0;  t2 := 0;  time := Oberon.Time();
			FOR i := 0 TO rep - 1 DO
				Comments := FALSE;  HandleLines2D( data, resdata, {1}, copy );
				Comments := TRUE;
			END;
			time := Oberon.Time() - time;  out( resdata[3, .. ], resdata[3, .. ] );
			Out.String( "overall time:" );  Out.Int( time, 5 );  Out.String( " z:" );  Out.Int( t0, 5 );
			Out.String( " y:" );  Out.Int( t1, 5 );  Out.String( " x:" );  Out.Int( t2, 5 );  Out.Ln;
		END;
	END Test;
*)
BEGIN
	Comments := FALSE;
END PlanarBase.


fofPC.Compile \s *
System.Free PlanarBase~
System.State PlanarBase

PlanarBase.Test 5 100000
PlanarBase.Test 50 100
PlanarBase.Test 200 5
PlanarBase.Test 128 1
PlanarBase.Test 256 1
PlanarBase.Test 400 1


fofPC.Compile \s *
fofPC.Compile \f *
