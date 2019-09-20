MODULE BorrowsWheeler;  (** AUTHOR GF; PURPOSE  "Borrows Wheeler Transformation"; *)

CONST
	BlockSize* = 8*1024;

TYPE
	MTF = OBJECT (* move to front *)
		TYPE
			Node = POINTER TO RECORD
				byte: CHAR;  next: Node
			END;
		VAR
			alpha: Node;


			PROCEDURE Initialize;
			VAR n: Node;  i: INTEGER;
			BEGIN
				alpha := NIL;
				FOR i := 0 TO 255 DO
					NEW( n );  n.next :=alpha;  n.byte := CHR( 255 - i );  alpha := n
				END
			END Initialize;

			PROCEDURE Encode( VAR buf: ARRAY OF CHAR; len: SIZE );
			VAR l, m: Node;  i: SIZE;  k: INTEGER; ch: CHAR;
			BEGIN
				Initialize;
				FOR i := 0 TO len - 1 DO
					ch := buf[i];
					IF alpha.byte = ch THEN  k := 0
					ELSE
						l := alpha;  m := alpha.next;  k := 1;
						WHILE m.byte # ch DO
							INC( k );  l := m;  m := m.next
						END;
						l.next := m.next;  m.next := alpha;  alpha := m
					END;
					buf[i] := CHR( k )
				END
			END Encode;

			PROCEDURE Decode( VAR buf: ARRAY OF CHAR; len: SIZE );
			VAR l, m: Node;  i: SIZE;  c: INTEGER;  ch: CHAR;
			BEGIN
				Initialize;
				FOR i := 0 TO len - 1 DO
					ch := buf[i];
					IF ch # 0X THEN
						c := ORD( ch );  l := alpha;
						WHILE c > 1 DO  l := l.next;  DEC( c )  END;
						m := l.next;  l.next := m.next;  m.next := alpha;
						alpha := m
					END;
					buf[i] := alpha.byte;
				END
			END Decode;

	END MTF;

TYPE
	Encoder* = OBJECT
		VAR
			mtf: MTF;
			sbuf: ARRAY 2*BlockSize OF CHAR;  bufLength: INTEGER;
			rotation: ARRAY BlockSize OF SIGNED16;

			PROCEDURE &New*;
			BEGIN
				NEW( mtf );
			END New;


			PROCEDURE Less( a, b: INTEGER ): BOOLEAN;
			VAR i1, i2, n, diff: INTEGER;
			BEGIN
				n := 0;  i1 := rotation[a];  i2 := rotation[b];
				REPEAT
					diff := ORD( sbuf[i1]) - ORD( sbuf[i2] );
					INC( i1 );  INC( i2 );  INC( n );
				UNTIL (diff # 0) OR (n = bufLength);
				RETURN diff < 0
			END Less;

			PROCEDURE Swap( a, b: INTEGER );
			VAR  tmp: SIGNED16;
			BEGIN
				tmp := rotation[a];  rotation[a] := rotation[b];  rotation[b] := tmp
			END Swap;

			PROCEDURE InsertSort( lo, hi: INTEGER );
			VAR x, i, l, m, ip: INTEGER;  tmp: SIGNED16;
			BEGIN
				x := lo + 1;
				WHILE x <= hi DO
					IF Less( x, x - 1 )  THEN
						(* find insert position ip *)
						ip := x - 1;  l := lo;
						WHILE l < ip DO
							m := (l + ip) DIV 2;
							IF Less( x, m ) THEN  ip := m  ELSE  l := m + 1  END
						END;
						(* insert rotation[x] at position ip*)
						tmp := rotation[x];  i := x;
						REPEAT  rotation[i] := rotation[i - 1];  DEC( i )  UNTIL i = ip;
						rotation[ip] := tmp;
					END;
					INC( x )
				END
			END InsertSort;

			PROCEDURE SortR( lo, hi: INTEGER );
			VAR i, j, m, n: INTEGER;
			BEGIN
				IF lo < hi THEN
					n := hi - lo + 1;
					IF n = 2 THEN
						IF Less( hi, lo ) THEN  Swap( lo, hi )  END
					ELSIF n < 16 THEN
						InsertSort( lo, hi )  (* less expensive string compares! *)
					ELSE
						(* QuickSort *)
						i := lo;  j := hi;  m := (lo + hi) DIV 2;
						REPEAT
							WHILE Less( i, m ) DO  INC( i )  END;
							WHILE Less( m, j ) DO  DEC( j )  END;
							IF i <= j THEN
								IF m = i THEN  m := j  ELSIF  m = j THEN  m := i  END;
								Swap( i, j );  INC( i );  DEC( j )
							END
						UNTIL i > j;
						SortR( lo, j );  SortR( i, hi )
					END
				END
			END SortR;

			PROCEDURE EncodeBlock*( VAR buf: ARRAY OF CHAR; len: INTEGER ): INTEGER;
			VAR  i, index: INTEGER;
			BEGIN
				ASSERT( len <= BlockSize );  bufLength := len;
				FOR i := 0 TO bufLength - 1 DO  sbuf[i] := buf[i];  sbuf[i+bufLength] := buf[i]  END;
				FOR i := 0 TO bufLength - 1 DO  rotation[i] := SIGNED16( i )  END;
				SortR( 0, bufLength - 1 );
				(* find index of the original row *)
				index := 0;  WHILE rotation[index] # 0 DO  INC( index )  END;
				(* replace buf by column L *)
				FOR i := 0 TO bufLength -1 DO  buf[i] := sbuf[rotation[i] + bufLength - 1]  END;
				mtf.Encode( buf, bufLength );
				RETURN index
			END EncodeBlock;

	END Encoder;


TYPE
	Decoder* = OBJECT
		VAR
			mtf: MTF;
			f, l: ARRAY BlockSize OF CHAR;
			lc, fc: ARRAY BlockSize OF SIGNED16;

			PROCEDURE &New*;
			BEGIN
				NEW( mtf );
			END New;


			PROCEDURE -Swap( a, b: INTEGER );
			VAR  tmp: CHAR;
			BEGIN
				tmp := f[a];  f[a] := f[b];  f[b] := tmp
			END Swap;


			PROCEDURE SortF( lo, hi: INTEGER );
			VAR i, j, m: INTEGER;
			BEGIN
				IF lo < hi THEN
					IF (hi - lo) = 1 THEN
						IF f[hi] < f[lo] THEN  Swap( lo, hi )  END;
					ELSE
						(* QuickSort *)
						i := lo;  j := hi;  m := (lo + hi) DIV 2;
						REPEAT
							WHILE f[i] < f[m] DO  INC( i )  END;
							WHILE f[m] < f[j] DO  DEC( j )  END;
							IF i <= j THEN
								IF m = i THEN  m := j  ELSIF m = j THEN  m := i  END;
								Swap( i, j );  INC( i );  DEC( j )
							END
						UNTIL i > j;
						SortF( lo, j );  SortF( i, hi )
					END
				END
			END SortF;


			PROCEDURE DecodeBlock*( VAR buf: ARRAY OF CHAR; len, index: INTEGER );
			VAR
				i, j, n: INTEGER;  ch: CHAR;
				xn: ARRAY 256 OF SIGNED16;
			BEGIN
				ASSERT( len <= BlockSize );
				mtf.Decode( buf, len );
				FOR i := 0 TO 255 DO  xn[i] := 0  END;
				FOR i := 0 TO len - 1 DO
					l[i] := buf[i];  f[i] := buf[i];
					j := ORD( l[i] );  lc[i] := xn[j];  INC( xn[j] )
				END;
				SortF( 0, len - 1 );
				FOR i := 0 TO 255 DO  xn[i] := 0  END;
				FOR i := 0 TO len - 1 DO
					j := ORD( f[i] );  fc[i] := xn[j];  INC( xn[j] )
				END;
				FOR i := 0 TO len - 1 DO
					ch := f[index];  n := fc[index];  buf[i] := ch;  index := 0;
					WHILE (l[index] # ch) OR (lc[index] # n) DO  INC( index )  END
				END;
			END DecodeBlock;

	END Decoder;


END BorrowsWheeler.
