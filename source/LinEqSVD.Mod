(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE LinEqSVD;  (** AUTHOR "ph"; PURPOSE "Solves a linear system of equations using SVD."; *)

IMPORT Nbr := NbrRe, Vec := VecRe, Mtx := MtxRe, LinEq := LinEqRe, Errors := DataErrors, MathRe, Out  := KernelLog ;

TYPE
	(** on initialization NEW(s,A) the matrix A of size m*n is subjected to the singular value decomposition A= u * w *  v ;     *)
	Solver* = OBJECT
			VAR u-, w-, vt-: Mtx.Matrix;   (**  result matrices; u is size m*n, w is size n*n; note that the algorithm returns the transpose  vT(size n*n) instead of v *)
				threshold*: Nbr.Real;   (** for level of accuracy; default = 1.0D-10*)
				iterations*: SIGNED32;   (** for detection of non-convergence; default = 30*)
				Reciprocal: Vec.Map;
				zero, mag: Nbr.Real;

				PROCEDURE & Initialize*( VAR A: Mtx.Matrix );
				BEGIN
					IF A # NIL THEN
						u := A.Copy( );  LinEq.NormalizeMatrix( u, mag );  zero := 0;  threshold := 1.0E-10;  iterations := 30;
						Reciprocal := reciprocal;  decompose();  w := w*mag;
					ELSE Errors.Error( "A NIL matrix was supplied." )
					END
				END Initialize;

				PROCEDURE decompose;
				VAR m, n: SIGNED32;
					rv1: POINTER TO ARRAY OF Nbr.Real;
					anorm, scale, c, f, g, h, s, x, y, z: Nbr.Real;  i, its, j, jj, k, l, nm: SIGNED32;  flag: BOOLEAN;
				BEGIN
					IF u = NIL THEN Errors.Error(  "A NIL matrix was supplied." );  RETURN END;
					m := u.rows;  n := u.cols;  NEW( rv1, n );
					IF (w = NIL ) OR (w.rows # n) OR (w.cols # n)  THEN NEW( w, 0, n, 0, n ) ELSE w.Multiply( zero ) END;
					IF (vt = NIL ) OR (vt.rows # n) OR (vt.cols # n)  THEN NEW( vt, 0, n, 0, n ) ELSE vt.Multiply( zero ) END;
					g := 0;  scale := 0;  anorm := 0;
					FOR i := 0 TO n - 1 DO
						l := i + 1;  rv1[i] := scale*g;  g := 0;  s := 0;  scale := 0.0;
						IF (i < m) THEN
							FOR k := i TO m - 1 DO scale := scale + ABS( u.Get(k, i) ) END;
							IF (scale # 0.0) THEN
								FOR k := i TO m - 1 DO u.Set(k, i, u.Get(k, i)/scale);  s := s + u.Get(k, i)*u.Get(k, i);  END;
								f := u.Get(i, i);
								IF f >= 0 THEN g := -MathRe.Sqrt( s ) ELSE g := MathRe.Sqrt( s ) END;
								h := f*g - s;  u.Set(i, i, f - g);
								FOR j := l TO n - 1 DO
									s := 0.0;
									FOR k := i TO m - 1 DO s := s + u.Get(k, i)*u.Get(k, j) END;
									f := s/h;
									FOR k := i TO m - 1 DO u.Set(k, j, u.Get(k, j) + f*u.Get(k, i)) END;
								END;
								FOR k := i TO m - 1 DO u.Set(k, i , u.Get(k, i)*scale) END;
							END
						END;
						w.Set(i, i, scale*g);  g := 0;  s := 0;  scale := 0.0;
						IF (i < m) & (i # (n - 1)) THEN
							FOR k := l TO n - 1 DO scale := scale + ABS( u.Get(i, k) ) END;
							IF (scale # 0.0) THEN
								FOR k := l TO n - 1 DO u.Set(i, k, u.Get(i, k)/scale);  s := s + u.Get(i, k)*u.Get(i, k);  END;
								f := u.Get(i, l);
								IF f >= 0 THEN g := -MathRe.Sqrt( s ) ELSE g := MathRe.Sqrt( s ) END;
								h := f*g - s;  u.Set(i, l, f - g);
								FOR k := l TO n - 1 DO rv1[k] := u.Get(i, k)/h END;
								FOR j := l TO m - 1 DO
									s := 0.0;
									FOR k := l TO n - 1 DO s := s + u.Get(j, k)*u.Get(i, k) END;
									FOR k := l TO n - 1 DO u.Set(j, k, u.Get(j, k) + s*rv1[k] )END;
								END;
								FOR k := l TO n - 1 DO u.Set(i, k,  u.Get(i, k)*scale) END;
							END;
						END;
						anorm := Max( anorm, ABS( w.Get(i, i) ) + ABS( rv1[i] ) )
					END;
					FOR i := n - 1 TO 0 BY -1 DO
						IF (i < (n - 1)) THEN
							IF g # 0.0 THEN
								FOR j := l TO n - 1 DO vt.Set(j, i, u.Get(i, j)/(u.Get(i, l)*g)) END;
								FOR j := l TO n - 1 DO
									s := 0;
									FOR k := l TO n - 1 DO s := s + u.Get(i, k)*vt.Get(k, j) END;
									FOR k := l TO n - 1 DO
										IF (s # 0.0) THEN vt.Set(k, j,  vt.Get(k, j) + s*vt.Get(k, i)) END;
									END;
								END;
							END;
							FOR j := l TO n - 1 DO vt.Set(i, j,  0.0);  vt.Set(j, i,  0.0) END;
						END;
						vt.Set(i, i, 1.0);  g := rv1[i];  l := i;
					END;
					FOR i := MinI( m, n ) - 1 TO 0 BY -1 DO
						l := i + 1;  g := w.Get(i, i);
						FOR j := l TO n - 1 DO u.Set(i, j, 0.0) END;
						IF (g # 0.0) THEN
							g := 1.0/g;
							FOR j := l TO n - 1 DO
								s := 0.0;
								FOR k := l TO m - 1 DO s := s + u.Get(k, i)*u.Get(k, j) END;
								f := s*g/u.Get(i, i);
								FOR k := i TO m - 1 DO
									IF (f # 0.0) THEN u.Set(k, j, u.Get(k, j) + f*u.Get(k, i)) END;
								END;
							END;
							FOR j := i TO m - 1 DO u.Set(j, i,  u.Get(j, i)*g)  END;
						ELSE
							FOR j := i TO m - 1 DO u.Set(j, i,  0.0) END;
						END;
						u.Set(i, i,  u.Get(i, i) + 1.0) ;
					END;
					FOR k := n - 1 TO 0 BY -1 DO
						its := 0;
						LOOP
							INC( its );
							IF its > iterations THEN EXIT END;
							flag := TRUE;  l := k;
							LOOP
								nm := l - 1;
								IF ((ABS( rv1[l] ) + anorm) = anorm) THEN flag := FALSE;  EXIT
								ELSIF ((ABS( w.Get(nm, nm) ) + anorm) = anorm) THEN EXIT
								END;
								DEC( l );
								IF l < 0 THEN EXIT END;
							END;
							IF flag THEN
								c := 0.0;  s := 1.0;  i := l;
								LOOP
									f := s*rv1[i];  rv1[i] := rv1[i]*c;
									IF ((ABS( f ) + anorm) = anorm) THEN EXIT END;
									g := w.Get(i, i);  h := pythag( f, g );  w.Set(i, i, h);  h := 1.0/h;  c := g*h;  s := -f*h;
									FOR j := 0 TO m - 1 DO
										y := u.Get(j, nm);  z := u.Get(j, i);  u.Set(j, nm, y*c + z*s);  u.Set(j, i,z*c - y*s);
									END;
									IF i = k THEN EXIT END;
									INC( i )
								END;
							END;
							z := w.Get(k, k);
							IF (l = k) THEN
								IF (z < 0.0) THEN
									w.Set(k, k,-z);
									FOR j := 0 TO n - 1 DO vt.Set(j, k, -vt.Get(j, k)) END;
								END;
								EXIT;
							END;
							IF (its = iterations) THEN
								Errors.Error(  "Singular value decomposition iterations do not converge" );
								u := NIL;  w := NIL;  vt := NIL;  RETURN;
							END;
							x := w.Get(l, l);  nm := k - 1;  y := w.Get(nm, nm);  g := rv1[nm];  h := rv1[k];
							f := ((y - z)*(y + z) + (g - h)*(g + h))/(2.0*h*y);  g := pythag( f, zero + 1 );
							f := ((x - z)*(x + z) + h*((y/(f + sign( f )*ABS( g ))) - h))/x;  c := 1.0;  s := 1.0;
							FOR j := l TO nm DO
								i := j + 1;  g := rv1[i];  y := w.Get(i, i);  h := s*g;  g := c*g;  z := pythag( f, h );  rv1[j] := z;  c := f/z;
								s := h/z;  f := x*c + g*s;  g := g*c - x*s;  h := y*s;  y := y*c;
								FOR jj := 0 TO n - 1 DO
									x := vt.Get(jj, j);  z := vt.Get(jj, i);  vt.Set(jj, j, x*c + z*s);  vt.Set(jj, i,  z*c - x*s);
								END;
								z := pythag( f, h );  w.Set(j, j, z);
								IF (z # 0.0) THEN z := 1.0/z;  c := f*z;  s := h*z;  END;
								f := c*g + s*y;  x := c*y - s*g;
								FOR jj := 0 TO m - 1 DO
									y := u.Get(jj, j);  z := u.Get(jj, i);  u.Set(jj, j,  y*c + z*s);  u.Set(jj, i,  z*c - y*s);
								END;
							END;
							rv1[l] := 0.0;  rv1[k] := f;  w.Set(k, k, x);
						END
					END;
					RETURN;
				END decompose;

				PROCEDURE PseudoInverse*( ): Mtx.Matrix;
				VAR p, q, r, psinv: Mtx.Matrix;
				BEGIN
					q := w.Copy( );  q.MapAll( Reciprocal );  p := Mtx.Transpose( u );  r := vt*q;  psinv := r*p;
					(*    psinv := (v*q)* Mtx.Transpose( u );   (*this would be more straightforward, but leads to a runtime trap *)
						*)
					RETURN psinv
				END PseudoInverse;

				PROCEDURE reciprocal( VAR x: Nbr.Real );
				BEGIN
					IF ABS( x ) < threshold THEN x := 0 ELSE x := 1.0/x END;
					IF ABS( x ) < threshold THEN x := 0 END;
				END reciprocal;

			END Solver;

	(******************************************************************)

	PROCEDURE pythag( a, b: Nbr.Real ): Nbr.Real;
	VAR absa, absb, zero: Nbr.Real;
	BEGIN
		zero := 0;  absa := ABS( a );  absb := ABS( b );
		IF absa > absb THEN RETURN absa*MathRe.Sqrt( 1.0 + absb/absa*absb/absa );
		ELSIF absb = 0 THEN RETURN zero
		ELSE RETURN absb*MathRe.Sqrt( 1.0 + absa/absb*absa/absb )
		END;
	END pythag;

	PROCEDURE Max( x, y: Nbr.Real ): Nbr.Real;
	BEGIN
		IF x > y THEN RETURN x ELSE RETURN y END;
	END Max;

	PROCEDURE MinI( i, j: SIGNED32 ): SIGNED32;
	BEGIN
		IF i < j THEN RETURN i ELSE RETURN j;  END;
	END MinI;

	PROCEDURE sign( x: Nbr.Real ): SIGNED32;
	BEGIN
		IF x >= 0 THEN RETURN 1 ELSE RETURN -1 END;
	END sign;

	PROCEDURE Log( m: Mtx.Matrix );
	VAR i, j: SIGNED32;
	BEGIN
		FOR j := 0 TO m.rows - 1 DO
			FOR i := 0 TO m.cols - 1 DO  (*Out.LongRealFix( m.Get(j, i), 10, 5 );  *)END;
			Out.Ln;
		END;
		Out.Ln;
	END Log;

	PROCEDURE Test*;
	VAR a, U, W, V, VT: Mtx.Matrix;  zero: Nbr.Real;  s: Solver;
	BEGIN
		Out.Ln;  Out.String( "-------Singular Value Decomposition Test-------------" );
		Out.String( " Singular Value Decomposition of Matrix A; " );  Out.Ln;
		Out.String( " should yield eigenvalues w (in diagonal matrix) and " );  Out.Ln;
		Out.String( " orthonormal matrices u & vT which, " );  Out.Ln;
		Out.String( " multiplied by itself, should give unit matrices; " );  Out.Ln;
		Out.String( " Finally, PseudoInverse of A is calculated, " );  Out.Ln;
		Out.String( " and Pseudoinverse of Pseudoinverse should lead back to A (least square approximation of..) " );  Out.Ln;

		NEW( a, 0, 4, 0, 5 );

		(*arbitrary matrix fill *)
		zero := 0;   (* hack to initialize matrix easier *)
		a.Set( 0, 0, zero + 1 );  a.Set( 1, 0, zero + 2 );   (* ' type casting', not very elegant *)
		a.Set( 3, 0, zero + 3 );  a.Set( 0, 2, zero + 2 );  a.Set( 2, 1, zero + 3 );  a.Set( 3, 1, zero + 2 );
		a.Set( 3, 4, zero + 4 );

		NEW( s, a );   (* at this point, solver is initialized with matrix m and SVD already performed in the background *)

		Out.String( "a:" );  Out.Ln;  Log( a );  Out.String( "w:" );  Out.Ln;  Log( s.w );  Out.String( "v,vt,v*vt:" );  Out.Ln;
		Log( s.vt );  V := Mtx.Transpose( s.vt );  Log( V );  V := s.vt*V;  Log( V );  Out.String( "u,ut,u*ut:" );  Out.Ln;
		Log( s.u );  U := Mtx.Transpose( s.u );  Log( U );  U := s.u*U;  Log( U );  Out.String( "u*w*v:" );  Out.Ln;
		VT := Mtx.Transpose( s.vt );  W := s.w*VT;  U := s.u*W;  Log( U );
		Out.String( "a, PseudoInverse(a), PseudoInverse(PseudoInverse(a)):" );  Out.Ln;  Log( a );
		a := s.PseudoInverse();  Log( a );  s.Initialize( a );  a := s.PseudoInverse();  Log( a );
	END Test;

END LinEqSVD.

LinEqSVD.Test

System.Free LinEqSVD ~

