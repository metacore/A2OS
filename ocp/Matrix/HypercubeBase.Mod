MODULE HypercubeBase;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)

IMPORT  SYSTEM;

CONST
	cachesize* = 256 * 1024;   (* make dynamic *)
	cachefraction = 0.5;   (* how much of cache should be used for temporary data structure. This might be a good starting point for  ATLAS like machine-adaptive optimizations *)

TYPE
	Datatype* = FLOAT64;
	OneD = ARRAY [*] OF Datatype;
	TwoD = ARRAY [*,*] OF Datatype;
	ThreeD = ARRAY [*,*,*] OF Datatype;
	FourD = ARRAY [*,*,*,*] OF Datatype;
	LineHandler* = PROCEDURE {DELEGATE} ( CONST lineIn: OneD;  VAR lineOut: OneD );
	F4*=PROCEDURE {DELEGATE} (x,y,z,t:Datatype):Datatype;
	LineHandler1*=PROCEDURE {DELEGATE} ( CONST lineIn: OneD;   VAR lineOut: OneD; v:Datatype);


VAR
	Comments: BOOLEAN;
	(*debug*) t1, t2, t0: SIGNED32;  testscale: SIGNED16;

	(** applies a procedure 'linehandler' to all lines of a 3D dataset in the indicated directions. Avoids cache misses by copying the data into a work array that fits into the cache.*)
	PROCEDURE HandleLines4D*( CONST cube: FourD;  VAR rescube: FourD;
													    directions: SET;  linehandler: LineHandler );
	VAR templine, templine1: OneD;  rect, resrect: TwoD;  same:BOOLEAN;
		x, y, z, t, w0, w, h, i, j, k, lenX, lenY, lenZ, lenT, time: SIZE;
	BEGIN
		lenX := LEN( cube, 3 );  lenY := LEN( cube, 2 );  lenZ := LEN( cube, 1 ); lenT:= LEN(cube, 0);
		(*same:=ADDRESSOF(cube)=ADDRESSOF(rescube);*) (*solve in language*)
		IF 3 IN directions THEN  (*along x*)
			t:=0;
			WHILE t<lenT DO
				z := 0;
				WHILE z < lenZ DO
					FOR y := 0 TO lenY - 1 DO
						IF TRUE (*same*) THEN templine:=cube[t,z, y]; linehandler( templine, rescube[t,z, y]);  (* same variable does not work here*)
						ELSE linehandler( cube[t, z, y], rescube[t,z, y]);
						END
					END;
					INC( z );
				END;
				INC(t);
			END;
			lenX := LEN( rescube, 3 );
		END;

		IF 2 IN directions THEN  (*additional optimization option: only cut 'rect' out of cube if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			 h := lenY;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( rescube, 2 ), w0 );  t := 0;
			WHILE t<lenT DO
				z := 0;
				WHILE z < lenZ DO
					j := 0;
					WHILE j < lenX DO  (*work in slices of full lenY size, but limited with w to avoid cache misses *)
						w := MIN( w0, lenX - j );
						IF 3 IN directions THEN rect[.. , .. w - 1] := rescube[t, z, .. , j..j + w - 1];
						ELSE rect[.. , .. w - 1] := cube[t, z, .. , j..j + w - 1];
						END;
						FOR x := 0 TO w - 1 DO
							templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
							linehandler( templine, templine1 );  resrect[.. , x] := templine1;
							(*linehandler(rect[..,x], resrect[..,x]);*)
						END;
						rescube[t, z, .. , j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
					END;
					INC( z );
				END;
				INC(t)
			END;
			lenY := LEN( rescube, 2 );
		END;
(* here, a slice in the XZ plane is cut from the cube, with a size small enough to fit in cache. This should limit cache misses in the inner loop.
					Note that the XZ plane is better than the YZ plane for line handling in the z dimension, because entire lines
					can be extracted from the internal data structures   *)
			IF 1 IN directions THEN  (*additional optimization option: only cut 'rect' out of cube if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			h := lenZ;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( rescube, 1 ), w0 );  t := 0;
			WHILE t<lenT DO
						y:=0;
						WHILE y < lenY DO
					j := 0;
					WHILE j < lenX DO  (*work in slices of full lenZ size, but limited with w to avoid cache misses *)
						w := MIN( w0, lenX - j );
						IF 2 IN directions THEN rect[.. , .. w - 1] := rescube[t, .., y , j..j + w - 1];
						ELSE rect[.. , .. w - 1] := cube[t, .., y , j..j + w - 1];
						END;
						FOR x := 0 TO w - 1 DO
							templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
							linehandler( templine, templine1 );  resrect[.. , x] := templine1;
							(*linehandler(rect[..,x], resrect[..,x]);*)
						END;
						rescube[t, .., y , j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
					END;
					INC( y );
				END;
				INC(t);
			END;
			lenZ := LEN( rescube, 1 );
		END;
		IF 0 IN directions THEN
			h := lenT;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( rescube, 0 ), w0 );  z := 0;
			WHILE z<lenZ DO
						y := 0;
						WHILE y < lenY DO
					j := 0;
					WHILE j < lenX DO
						w := MIN( w0, lenX - j );
						IF  (*directions*{1,2} # {} *) (1 IN directions) OR (2 IN directions) THEN
							rect[.. , .. w - 1] := rescube[.. , z, y, j..j + w - 1];
						ELSE rect[.. , .. w - 1] := cube[.. , z, y, j..j + w - 1];
						END;
						FOR x := 0 TO w - 1 DO
							templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
							linehandler( templine, templine1 );  resrect[.. , x] := templine1;
							(*linehandler(rect[..,x], resrect[..,x])*)
						END;
						rescube[.. , z, y, j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
					END;
					INC( y );
				END;
				INC(z);
			END;
		END;
	END HandleLines4D;



(** applies a procedure 'linehandler' to all lines of a 3D dataset in the indicated directions.  passes result of f4(x,y,z,t) to the linehandler for parametrization according to the *)
	PROCEDURE HandleLines4D1*( CONST cube: FourD;  VAR rescube: FourD;   directions: SET;  linehandler: LineHandler1; f4:F4);
	VAR templine, templine1: OneD;  rect, resrect: TwoD;  same:BOOLEAN;
		x, y, z, t, w0, w, h, i, j, k, lenX, lenY, lenZ, lenT, time: SIZE;
	BEGIN
		lenX := LEN( cube, 3 );  lenY := LEN( cube, 2 );  lenZ := LEN( cube, 1 ); lenT:= LEN(cube, 0);
		(*same:=ADDRESSOF(cube)=ADDRESSOF(rescube);*) (*solve in language*)
		IF 3 IN directions THEN  (*along x*)
			WHILE t<lenT DO
				z := 0;
				WHILE z < lenZ DO
					FOR y := 0 TO lenY - 1 DO
						IF TRUE (*same*) THEN
							templine:=cube[t,z, y];
							linehandler( templine, rescube[t,z, y], f4(0,y,z,t));  (* same variable does not work here*)
						ELSE linehandler( cube[t, z, y], rescube[t,z, y], f4(0,y,z,t));
						END
					END;
					INC( z );
				END;
				INC(t);
			END;
			lenX := LEN( rescube, 3 );
		END;
		IF 2 IN directions THEN  (*additional optimization option: only cut 'rect' out of cube if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			 h := lenY;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( rescube, 1 ), w0 );  t := 0;
			WHILE t<lenT DO
				z := 0;
				WHILE z < lenZ DO
					j := 0;
					WHILE j < lenX DO  (*work in slices of full lenY size, but limited with w to avoid cache misses *)
						w := MIN( w0, lenX - j );
						IF 3 IN directions THEN rect[.. , .. w - 1] := rescube[t, z, .. , j..j + w - 1];
						ELSE rect[.. , .. w - 1] := cube[t, z, .. , j..j + w - 1];
						END;
						FOR x := 0 TO w - 1 DO
							templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
							linehandler( templine, templine1,f4(j+x, 0, z, t) );
							resrect[.. , x] := templine1;
							(*linehandler(rect[..,x], resrect[..,x]);*)
						END;
						rescube[t, z, .. , j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
					END;
					INC( z );
				END;
				INC(t)
			END;
			lenY := LEN( rescube, 2 );
		END;
(* here, a slice in the XZ plane is cut from the cube, with a size small enough to fit in cache. This should limit cache misses in the inner loop.
					Note that the XZ plane is better than the YZ plane for line handling in the z dimension, because entire lines
					can be extracted from the internal data structures   *)
			IF 1 IN directions THEN  (*additional optimization option: only cut 'rect' out of cube if XY plane does not fit into cache by itself (somewhat similar for z dimension) *)
			h := lenZ;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( rescube, 1 ), w0 );  t := 0;
			WHILE t<lenT DO
						y:=0;
						WHILE y < lenY DO
					j := 0;
					WHILE j < lenX DO  (*work in slices of full lenZ size, but limited with w to avoid cache misses *)
						w := MIN( w0, lenX - j );
						IF 2 IN directions THEN rect[.. , .. w - 1] := rescube[t, .., y , j..j + w - 1];
						ELSE rect[.. , .. w - 1] := cube[t, .., y , j..j + w - 1];
						END;
						FOR x := 0 TO w - 1 DO
							templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
							linehandler( templine, templine1, f4(j+x, y, 0, t) );  resrect[.. , x] := templine1;
							(*linehandler(rect[..,x], resrect[..,x]);*)
						END;
						rescube[t, .., y , j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
					END;
					INC( y );
				END;
				INC(t);
			END;
			lenZ := LEN( rescube, 1 );
		END;
		IF 0 IN directions THEN
			h := lenT;
			w0 := MIN( lenX, ENTIER( cachesize * cachefraction / SIZEOF( Datatype ) / h ) );
			NEW( rect, h, w0 );  NEW( resrect, LEN( rescube, 0 ), w0 );  z := 0;
			WHILE z<lenZ DO
						y := 0;
						WHILE y < lenY DO
					j := 0;
					WHILE j < lenX DO
						w := MIN( w0, lenX - j );
						IF  (*directions*{1,2} # {} *) (1 IN directions) OR (2 IN directions) THEN
							rect[.. , .. w - 1] := rescube[.. , z, y, j..j + w - 1];
						ELSE rect[.. , .. w - 1] := cube[.. , z, y, j..j + w - 1];
						END;
						FOR x := 0 TO w - 1 DO
							templine := rect[.. , x];  templine1 := resrect[.. , x];   (*HACK double data copy ! - there is a problem with the linehandler(rect[..,x], resrect[..,x]); data passing*)
							linehandler( templine, templine1, f4(j+x, y, t, 0) );  resrect[.. , x] := templine1;
							(*linehandler(rect[..,x], resrect[..,x])*)
						END;
						rescube[.. , z, y, j..j + w - 1] := resrect[.. , .. w - 1];  INC( j, w );
					END;
					INC( y );
				END;
				INC(z);
			END;
		END;
	END HandleLines4D1;

(*
	PROCEDURE copy( CONST in: OneD;  VAR in2: OneD );
	VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO LEN( in ) - 1 DO in2[i] := in[i];  END;
	END copy;

	PROCEDURE out( CONST in: OneD;  VAR in2: OneD );
	VAR i: SIGNED32;
	BEGIN
		FOR i := 0 TO LEN( in ) - 1 DO Out.Int( ENTIER( in[i] ), 6 );  (*Out.Int(  in2[i] , 6 );*) END;
		Out.Ln;
	END out;

	PROCEDURE Test*;
	VAR x, y, z, s, t, rep, time, i, j: SIGNED32;  cube, rescube: FourD;
	BEGIN
		In.Open;  In.LongInt( s );  In.LongInt( rep );
		IF In.Done THEN
			Out.String( "demonstrates fast linewise handling in arbitrary dimensional dataset, using temporary rectangles with size<cache to avoid cache misses" );  Out.Ln;
			Out.String( "data size [MB]: " );
			Out.Int( s * s * s * SIZEOF( Datatype ) DIV 1024 DIV 1024, 16 );  Out.Ln;  t0 := 0;
			t1 := 0;  t2 := 0;  NEW( cube, s, s, s, s);  NEW( rescube, s, s, s, s );
			FOR t:=0 TO s-1 DO
					FOR z := 0 TO s - 1 DO
					FOR y := 0 TO s - 1 DO
						FOR x := 0 TO s - 1 DO cube[t, z, y, x] := ((t*10 + z) * 10 + y) * 10 + x;  END;
					END;
				END;
			END;
			t0 := 0;  t1 := 0;  t2 := 0;  time := Oberon.Time();
			FOR i := 0 TO rep - 1 DO
				Comments := FALSE;  HandleLines4D( cube, rescube, {1}, copy );
				Comments := TRUE;
			END;
			time := Oberon.Time() - time;
			out( rescube[3, 3, 3, .. ], rescube[3, 3, 3, .. ] );
			out( rescube[3, 3, .., 3 ], rescube[3, 3, .., 3 ] );
			out( rescube[3, .., 3, 3 ], rescube[3, .., 3, 3 ] );
			out( rescube[.., 3, 3, 3 ], rescube[ .., 3, 3, 3 ] );
			Out.String( "overall time:" );  Out.Int( time, 5 );  Out.String( " z:" );  Out.Int( t0, 5 );
			Out.String( " y:" );  Out.Int( t1, 5 );  Out.String( " x:" );  Out.Int( t2, 5 );  Out.Ln;
		END;
	END Test;
*)
BEGIN
	Comments := FALSE;
END HypercubeBase.


fofPC.Compile \s *
System.Free HypercubeBase~
System.State HypercubeBase

HypercubeBase.Test 5 100000
HypercubeBase.Test 5 10
HypercubeBase.Test 200 5
HypercubeBase.Test 128 1
HypercubeBase.Test 256 1
HypercubeBase.Test 400 1


fofPC.Compile \s *
fofPC.Compile \f *

