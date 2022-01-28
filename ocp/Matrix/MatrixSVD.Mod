MODULE MatrixSVD;   (** AUTHOR "Patrick Hunziker"; PURPOSE "Solves a linear system of equations using SVD."; *)  (*TO DO: sorting by magnitude of eigenvectors may have a problem; small matrices *)
(*Version: 9/2019*)

(* Outlook to the future, not yet implemented: high performance version using randomized algorithm: for very large data sets up to 100x faster than best competitor:
http://pages.cs.wisc.edu/~sifakis/papers/SVD_TR1690.pdf *)

IMPORT Base := MatrixBase, Math := MathL, PMath, Util:=MatrixUtilities , Commands, Kernel;

CONST
	Tiny = 1.0D-10;  DefaultIterations = 30;

TYPE
	(** on initialization NEW(s,A) the matrix A of size m*n is subjected to the singular value decomposition A= u * w *  v ;     *)
	Real = Base.Datatype;  Vector* = Base.Vector;  Matrix* = Base.Matrix;  IntVector*=ARRAY [*] OF SIZE;
	Solver* = OBJECT (Base.Solver);
	VAR u-, w-, vt-, tmp, tmp2: Matrix;   (**  result matrices; u is size m*n, w is size n*n; note that the algorithm returns the transpose  vT(size n*n) instead of v *)
		uSorted-,wSorted-,vtSorted-:Matrix;
		tv, tv2, tv3, tv4: Vector;
		isSorted-:BOOLEAN;
		threshold*: Real;   (** for level of accuracy; default = 1.0D-10*)
		iterations*: INTEGER;   (** for detection of non-convergence; default = 30*)
		zero, mag: Real;
		index-,null: IntVector; (* ordering of diagonal matrix w with descending magnitude *)

		PROCEDURE & Init*( CONST A: Matrix );
		BEGIN
			handleError := Base.HandleError;  res := Base.OK;  isSorted:=FALSE; index:=null;
			IF LEN( A ) = 0 THEN RETURN END;
			IF (LEN( u, 0 ) # LEN( A, 0 )) OR (LEN( u, 1 ) # LEN( A, 1 )) THEN NEW( u, LEN( A, 0 ), LEN( A, 1 ) );  END;
			u := A;  mag := MaxAbs( u );  u := u / mag;  zero := 0.0D0;  
			iterations := DefaultIterations;  threshold := Tiny;  
			decompose;  
			w := w * mag;
		END Init;

		PROCEDURE decompose;
		VAR m, n: SIZE;  rv1: Vector;  anorm, scale, c, f, g, h, s, x, y, z: Real;  i, its, j, jj, k, l, nm: SIZE;  flag: BOOLEAN;
		BEGIN
			isSorted:=FALSE;
			IF LEN(u)=[2,2] THEN decompose2x2; RETURN END;
			IF LEN( u ) = 0 THEN res := Base.SIZEMISMATCH;  handleError( Base.SIZEMISMATCH, "An zero size matrix was supplied." );  RETURN END;
			n := LEN( u, 1 );  m := LEN( u, 0 );
			IF LEN( rv1 ) # n THEN NEW( rv1, n ) ELSE rv1 := 0 END;
			IF (LEN( w, 0 ) # n) OR (LEN( w, 1 ) # n) THEN NEW( w, n, n ) ELSE w := 0 END;
			IF (LEN( vt, 0 ) # n) OR (LEN( vt, 1 ) # n) THEN NEW( vt, n, n ) ELSE vt := 0 END;
			g := 0;  scale := 0;  anorm := 0;
			FOR i := 0 TO n - 1 DO
				l := i + 1;  rv1[i] := scale * g;  g := 0;  s := 0;  scale := 0.0;
				IF (i < m) THEN
					scale := Util.SumAbs( u[i..m - 1, i] );(* SUM(ABS()) overhead: allocation of temp array behind the scenes*)
					IF (scale # 0.0) THEN
						u[i..m - 1, i] := u[i..m - 1, i] / scale;  s := s + u[i..m - 1, i] +* u[i..m - 1, i];  f := u[i, i];
						IF f >= 0 THEN g := -Math.sqrt( s ) ELSE g := Math.sqrt( s ) END;
						h := f * g - s;  u[i, i] := (f - g);
						FOR j := l TO n - 1 DO
							s := u[i..m - 1, i] +* u[i..m - 1, j];
							f := s / h;
							tv3 := f * u[i..m - 1, i];
							u[i..m - 1, j] := u[i..m - 1, j] + tv3 (*+ f*u[i..m-1,i]*)
						END;
						u[i..m - 1, i] := u[i..m - 1, i] * scale
					END
				END;
				w[i, i] := (scale * g);  g := 0;  s := 0;  scale := 0.0;
				IF (i < m) & (i # (n - 1)) THEN
					scale := Util.SumAbs( u[i, l..n - 1] );(* SUM(ABS()) overhead: allocation of temp array behind the scenes*)
					IF (scale # 0.0) THEN
						u[i, l..n - 1] := u[i, l..n - 1] / scale;  s := s + u[i, l..n - 1] +* u[i, l..n - 1];  f := u[i, l];
						IF f >= 0 THEN g := -Math.sqrt( s ) ELSE g := Math.sqrt( s ) END;
						h := f * g - s;  u[i, l] := (f - g);  rv1[l..n - 1] := u[i, l..n - 1] / h;
						FOR j := l TO m - 1 DO
							s := u[j, l..n - 1] +* u[i, l..n - 1];
							tv4 := s * rv1[l..n - 1];
							u[j, l..n - 1] := u[j, l..n - 1] + tv4;   (*+ s*rv1[l..n-1] ) *)
						END;
						u[i, l..n - 1] := (u[i, l..n - 1] * scale)
					END;
				END;
				anorm := MAX( anorm, ABS( w[i, i] ) + ABS( rv1[i] ) )
			END;
			FOR i := n - 1 TO 0 BY -1 DO
				IF (i < (n - 1)) THEN
					IF g # 0.0 THEN
						vt[l..n - 1, i] := (u[i, l..n - 1] / (u[i, l] * g));
						FOR j := l TO n - 1 DO
							s := u[i, l..n - 1] +* vt[l..n - 1, j];
							IF s # 0 THEN tv4 := s * vt[l..n - 1, i];  vt[l..n - 1, j] := vt[l..n - 1, j] + tv4;   (*+ s*vt[l..n-1, i]) *) ;  END;
						END;
					END;
					vt[i, l..n - 1] := zero;  vt[l..n - 1, i] := zero;
				END;
				vt[i, i] := (1.0);  g := rv1[i];  l := i;
			END;
			FOR i := MIN( m, n ) - 1 TO 0 BY -1 DO
				l := i + 1;  g := w[i, i];
				u[i, l..n - 1] := zero;
				IF (g # 0.0) THEN
					g := 1.0 / g;
					FOR j := l TO n - 1 DO
						s := 0.0;
						FOR k := l TO m - 1 DO s := s + u[k, i] * u[k, j] END;
						f := s * g / u[i, i];
						IF f # 0 THEN
							tv4 := f * u[i..m - 1, i];
							u[i..m - 1, j] := u[i..m - 1, j] + tv4;   (*+ f*u[i..m-1, i]) *)
						END;
					END;
					u[i..m - 1, i] := (u[i..m - 1, i] * g)
				ELSE u[i..m - 1, i] := zero
				END;
				u[i, i] := (u[i, i] + 1.0);
			END;
			FOR k := n - 1 TO 0 BY -1 DO
				its := 0;
				LOOP
					INC( its );
					IF its > iterations THEN EXIT END;
					flag := TRUE;  l := k;
					LOOP
						nm := l - 1;
						IF ABS( rv1[l] ) + anorm = anorm THEN flag := FALSE;  EXIT
						ELSIF ABS( w[nm, nm] ) + anorm = anorm THEN EXIT
						END;
						DEC( l );
						IF l < 0 THEN EXIT END;
					END;
					IF flag THEN
						c := 0.0;  s := 1.0;  i := l;
						LOOP
							f := s * rv1[i];  rv1[i] := rv1[i] * c;
							IF ABS( f ) + anorm = anorm THEN EXIT END;
							g := w[i, i];  h := pythag( f, g );  w[i, i] := (h);  h := 1.0 / h;  c := g * h;  s := -f * h;

							FOR j := 0 TO m - 1 DO y := u[j, nm];  z := u[j, i];  u[j, nm] := (y * c + z * s);  u[j, i] := (z * c - y * s);  END;
							(*  u[0..m-1, nm] := u[0..m-1, nm] *c + u[0..m-1, i] * s;  (*wait for compiler compatibility of [[c,s],[c,-s]] *)
									u[0..m-1, i] := u[0..m-1, i]*c - u[0..m-1, nm] * s; (*not independent, not vectorizable ? but maybe vectorizable ...*)
									*)
							IF i = k THEN EXIT END;
							INC( i )
						END;
					END;
					z := w[k, k];
					IF (l = k) THEN
						IF (z < 0.0) THEN w[k, k] := (-z);  vt[.. n - 1, k] := (-vt[.. n - 1, k]);  END;
						EXIT;
					END;
					IF (its = iterations) THEN
						res := Base.NONCONVERGENCE;  handleError( Base.NONCONVERGENCE, "Singular value decomposition iterations do not converge" );  u := 0;  w := 0;  vt := 0;
						RETURN;
					END;
					x := w[l, l];  nm := k - 1;  y := w[nm, nm];  g := rv1[nm];  h := rv1[k];  f := ((y - z) * (y + z) + (g - h) * (g + h)) / (2.0 * h * y);  g := pythag( f, zero + 1 );
					f := ((x - z) * (x + z) + h * ((y / (f + sign( f ) * ABS( g ))) - h)) / x;  c := 1.0;  s := 1.0;
					FOR j := l TO nm DO
						i := j + 1;  g := rv1[i];  y := w[i, i];  h := s * g;  g := c * g;  z := pythag( f, h );
						rv1[j] := z;  c := f / z;  s := h / z;  f := x * c + g * s;  g := g * c - x * s;  h := y * s;  y := y * c;
						FOR jj := 0 TO n - 1 DO x := vt[jj, j];  z := vt[jj, i];  vt[jj, j] := (x * c + z * s);  vt[jj, i] := (z * c - x * s);  END;
						(*  vt[..n-1, j] := ( vt[..n-1, j]*c + vt[..n-1, i]*s);  (*wait for compiler compatibility of [[c,s],[c,-s]] *)
								vt[..n-1, i] := (  vt[..n-1, i]*c - vt[..n-1, j]*s); (*not independent, not vectorizable ? rather not*)
								*)
						z := pythag( f, h );  w[j, j] := (z);
						IF (z # 0.0) THEN z := 1.0 / z;  c := f * z;  s := h * z;  END;(*? does c:=, s:= need to go out of loop ?*)
						f := c * g + s * y;  x := c * y - s * g;
						FOR jj := 0 TO m - 1 DO y := u[jj, j];  z := u[jj, i];  u[jj, j] := (y * c + z * s);  u[jj, i] := (z * c - y * s);  END;
						(*  u[..m-1, j] := (  u[..m-1, j]*c + u[..m-1, i]*s);  (*wait for compiler compatibility of [[c,s],[c,-s]] *)
								u[..m-1, i] := (  u[..m-1, i]*c - u[..m-1, j]*s);  (*not independent, not vectorizable ? rather not*)
								*)
					END;
					rv1[l] := 0.0;  rv1[k] := f;  w[k, k] := (x);
				END
			END;
			RETURN;
		END decompose;

		(* https://scicomp.stackexchange.com/questions/8899/robust-algorithm-for-2-times-2-svd *)
		PROCEDURE decompose2x2;
		VAR 
			E,F,G,H,Q,R,sx,sy,a1,a2,theta, phi, sinPhi,sinTheta,cosPhi,cosTheta: Real;
		BEGIN
			E:=(u[0,0]+u[1,1])/2;
			F:=(u[0,0]-u[1,1])/2;
			G:=(u[1,0]+u[0,1])/2;
			H:=(u[1,0]-u[0,1])/2;
			Q:=pythag(E,H);
			R:=pythag(F,G);
			sx:=Q+R;
			sy:=Q-R;
			a1:=PMath.arctan2L(G,F);
			a2:=PMath.arctan2L(H,E);
			theta:=(a2-a1)/2;
			phi:=(a2+a1)/2;
			cosPhi:=Math.cos(phi);
			sinPhi:=Math.sin(phi);
			cosTheta:=Math.cos(theta);
			sinTheta:=Math.sin(theta);
			(*? changes below might be related to differences in result range (0..2pi versus -pi..pi) of arctan() ? *)
			(*u:=[[cosPhi, -sinPhi],[sinPhi,cosPhi]];*)(*was according to scicomp reference, but leads to permuted sign/elements of u*)
			u:=[[-sinPhi, cosPhi],[-cosPhi,-sinPhi]];
			w:=[[sx,0],[0,sy]];
			(*v:=[[cosTheta,-sinTheta],[sinTheta,cosTheta]];*)(*according to scicomp reference, but leads to permuted sign/elements *)
			vt:=[[-cosTheta,sinTheta],[-sinTheta,-cosTheta]];
	    END decompose2x2;
		
		PROCEDURE Solve*( CONST b: Vector ): Vector;
		VAR i: SIZE;
		BEGIN
			IF (LEN( tmp, 0 ) # LEN( w, 0 )) OR (LEN( tmp, 1 ) # LEN( w, 1 )) THEN NEW( tmp, LEN( w, 0 ), LEN( w, 1 ) );  ELSE tmp := 0 END;
			IF LEN( tv ) # LEN( u, 0 ) THEN NEW( tv, LEN( u, 0 ) ) ELSE tv := 0 END;
			IF LEN( tv2 ) # LEN( u, 0 ) THEN NEW( tv2, LEN( u, 0 ) ) ELSE tv2 := 0 END;
			FOR i := 0 TO LEN( w,0 ) - 1 DO	tmp[i,i]:=reciprocal(w[i,i]) END;
			tv := u` * b;  tv2 := tmp * tv;  RETURN vt * tv2
		END Solve;

		PROCEDURE SortDescending*;
		VAR sorted:Vector;
		BEGIN
			index:=null;
			Util.GetDiagonalOrder(w, sorted,index,FALSE);
			wSorted:=Util.ReorderMatrix(w,index, FALSE); (* reorder diagonal matrix w in columns and rows*)
			wSorted:=Util.ReorderMatrix(wSorted, index,TRUE);
			uSorted:=Util.ReorderMatrix(u,index, FALSE); (* reorder u by columns*)
			vtSorted:=Util.ReorderMatrix(vt, index, FALSE); (* reorder v by rows (i.e. reorder vt by columns)*)
			isSorted:=TRUE;
		END SortDescending;

		PROCEDURE PseudoInverse*( ): Matrix;
		VAR i: SIZE;
		BEGIN
			IF (LEN( tmp, 0 ) # LEN( w, 0 )) OR (LEN( tmp, 1 ) # LEN( w, 1 )) THEN NEW( tmp, LEN( w, 0 ), LEN( w, 1 ) );  ELSE tmp := 0 END;
			tmp2 := 0;
			FOR i := 0 TO LEN( w,0 ) - 1 DO	tmp[i,i]:=reciprocal(w[i,i]) END;
			tmp2 := tmp * u`;  
			RETURN vt * tmp2;
		END PseudoInverse;
	END Solver;
	
	PROCEDURE reciprocal-( x: Real ): Real; 
	BEGIN
		IF ABS( x ) < Tiny THEN x := 0.0D0 
		ELSE 
			x := 1.0D0/x;
			IF ABS(x) < Tiny THEN x := 0.0D0 END;
		END;
		RETURN x
	END reciprocal;

	PROCEDURE pythag( a, b: Real ): Real;
	VAR absa, absb, zero: Real;
	BEGIN
		zero := 0;  absa := ABS( a );  absb := ABS( b );
		IF absa > absb THEN RETURN absa * Math.sqrt( 1.0 + absb / absa * absb / absa );
		ELSIF absb = 0 THEN RETURN zero
		ELSE RETURN absb * Math.sqrt( 1.0 + absa / absb * absa / absb )
		END;
	END pythag;

	PROCEDURE MaxAbs( CONST m: Matrix ): Real;
	BEGIN
		RETURN MAX( MAX( m ), -MIN( m ) );   (*non-copying MAX(ABS(m))*)
	END MaxAbs;

	PROCEDURE sign-( x: Real ): INTEGER;
	BEGIN
		IF x >= 0 THEN RETURN 1 ELSE RETURN -1 END;
	END sign;

	(* 3*3 SVD for simd: see http://pages.cs.wisc.edu/~sifakis/papers/SVD_TR1690.pdf *)

	PROCEDURE Test*(context:Commands.Context);
	VAR a, aa, aaa, U, W, V, VT: Matrix;  b,x: Vector; scale, zero: Real;  s: Solver;  i,t0,t1:INTEGER;
	BEGIN
		context.out.Ln;  context.out.String( "-------Singular Value Decomposition Test-------------" );
		context.out.String( " Singular Value Decomposition of Matrix A; " );  context.out.Ln;
		context.out.String( " should yield eigenvalues w (in diagonal matrix) and " );  context.out.Ln;
		context.out.String( " orthonormal matrices u & vT which, " );  context.out.Ln;
		context.out.String( " multiplied by itself, should give unit matrices; " );  context.out.Ln;
		context.out.String( " Finally, PseudoInverse of A is calculated, " );  context.out.Ln;
		context.out.String( " and Pseudoinverse of Pseudoinverse should lead back to A (least square approximation of..) " );  context.out.Ln;

		NEW( a, 8, 10 ); a[..3,..4]:=[[1.0,0,2,0,0],[2,0,0,0,0],[0,3,0,0,0],[3,2,0,0,4]];
		NEW( s, a );		(* at this point, solver is initialized with matrix m and SVD already performed in the background *)
		
		t0:=Kernel.GetTicks(); FOR i:=0 TO 10000 DO s.Init(a )	END;	t1:=Kernel.GetTicks();
		context.out.String("time [ms]: "); context.out.Int (t1-t0,0); context.out.Ln;

		b:=[1,5,4,8,7,3,4,7,0,4,3,2,6,7,8];
		
		context.out.String("SUM(ABS()) versus Util.SumAbs() ");
		t0:=Kernel.GetTicks();	FOR i:=0 TO 10000 * 80 DO scale := SUM(ABS(b)) 	END; t1:=Kernel.GetTicks();
		context.out.String("time [ms]: "); context.out.Int (t1-t0,0);
		t0:=Kernel.GetTicks();	FOR i:=0 TO 10000* 80 DO scale := Util.SumAbs(b)	END;t1:=Kernel.GetTicks();
		context.out.String("  time [ms]: "); context.out.Int (t1-t0,0); context.out.Ln;

		context.out.String( "a:" );  context.out.Ln;  Util.Print(context.out,  a , 7,4,0 );  context.out.String( "w:" );  context.out.Ln;  Util.Print(context.out,  s.w, 7,4,0 );
		context.out.String( "v,vt,v*vt:" );  context.out.Ln;
		Util.Print(context.out,  s.vt, 7,4,0 );  (*V := s.vt`;*)  Util.Print(context.out,  s.vt`, 7,4,0 );  (*V := s.vt*V;*)  Util.Print(context.out,  s.vt*(s.vt`), 7,4,0 );  
		context.out.String( "u,ut,u*ut:" );  context.out.Ln;
		Util.Print(context.out,  s.u, 7,4,0 );  (*U := s.u`;*)  Util.Print(context.out,  s.u`, 7,4,0 );  (*U := s.u*U;*)  Util.Print(context.out,  s.u * (s.u`), 7,4,0 );  
		context.out.String( "u*w*v:" );  context.out.Ln;
		Util.Print(context.out,  s.u * (s.w*(s.vt`)), 7,4,0 );
		context.out.String( "a, PseudoInverse(a), PseudoInverse(PseudoInverse(a)):" );  context.out.Ln;  
		Util.Print(context.out,  a, 7,4,0 );
		Util.Print(context.out,  s.PseudoInverse(), 7,4,0 );  s.Init( s.PseudoInverse() );  
		Util.Print(context.out,  s.PseudoInverse(), 7,4,0 );

		(*SVD as solver*)
		NEW( a, 5, 5 );
		NEW(x,5);
		(*arbitrary matrix fill *)
		a:=[ [5.1, 4.1, 2.2, 5.3, 2.0],
  				[2.3, 4.2, 0.0, 3.0, 0.0],
  				[5.3, 3.0, 2.5, 3.6, 0.0],
  				[3.4, 2.0, 2.1, 1.0, 4.0],
  				[2.0, 0.0, 4.0, 2.0, 1.0]];
		b:=[5,4,3,1,4];
		context.out.String( "A, b, x, A*x:" );  context.out.Ln;  
		Util.Print(context.out,  a, 7,4,0 );
		Util.Print(context.out,  b, 7,4,0);    context.out.Ln;
		s.Init(a);
		x:=s.Solve(b);
		Util.Print(context.out, x, 7,4,0);  context.out.Ln;
		Util.Print(context.out, a*x, 7,4,0);context.out.Ln;

		context.out.String("SVD, pseudoInverse, pseudoInverse(pseudoInverse) of 2*2 matrix"); context.out.Ln;
		a:=[[2,1.8],[-1,1]];
		Util.Print(context.out,  a, 7,4,0 ); 
		NEW(s,a);
		Util.Print(context.out, s.u, 7,4,0);
		Util.Print(context.out, s.u*s.u`, 7,4,0);
		Util.Print(context.out, s.w, 7,4,0);
		Util.Print(context.out, s.vt, 7,4,0);
		Util.Print(context.out, s.vt`*s.vt, 7,4,0);
		Util.Print(context.out, s.u*(s.w*(s.vt`)), 7,4,0);
		aa:=s.PseudoInverse();
		Util.Print(context.out,  aa, 7,4,0 );  
		NEW(s, aa );  
		aaa:=s.PseudoInverse();
		Util.Print(context.out,  aaa, 7,4,0 );
	END Test;
	
	PROCEDURE {TEST} TestPseudoInverse*; (*interface chosen because currently, GETPROCEDURE does not accept more suitable interface, and has problems with different names than TEST *)
	VAR a,aa:Matrix; s,ss:Solver;
	BEGIN (* generic matrix *)
		NEW( a, 8, 10 ); a[..3,..4]:=[[1.0,0,2,0,0],[2,0,0,0,0],[0,3,0,0,0],[3,2,0,0,4]];
		NEW( s, a );	
		NEW( ss, s.PseudoInverse());
		aa:=ss.PseudoInverse();
		ASSERT((aa-a)+*(aa-a)<0.0001); 
	END TestPseudoInverse;	
	
	PROCEDURE {TEST} Test2x2*; 
	VAR s,ss:Solver; a,aa:Matrix; 
	BEGIN
		NEW(a,2,2); a:=[[2,1.8],[-1,1]];
		NEW( s, a );	
		NEW( ss, s.PseudoInverse());
		aa:=ss.PseudoInverse();
		ASSERT ((aa-a)+*(aa-a)<0.0001);
	END Test2x2;
	
	PROCEDURE {TEST} TestSolve*; 
	VAR a:Matrix; b,bb,x:Vector; s:Solver;
	BEGIN (*solving*)
		a:=[ [5.1, 4.1, 2.2, 5.3, 2.0],
  				[2.3, 4.2, 0.0, 3.0, 0.0],
  				[5.3, 3.0, 2.5, 3.6, 0.0],
  				[3.4, 2.0, 2.1, 1.0, 4.0],
  				[2.0, 0.0, 4.0, 2.0, 1.0]];
		b:=[5.0,4,3,1,4]; NEW(x,5);
		NEW(s,a);
		x:=s.Solve(b);
		bb:=a*x; bb:=bb-b;
		ASSERT( bb+*bb < 0.0001 ); 
	END TestSolve;

BEGIN
END MatrixSVD.
System.Time ~
System.FreeDownTo MatrixSVD~
MatrixSVD.Test
LinEqSVD.Test

System.FreeDownTo  MatrixSVD  ~

OFormatter.Format *
fofPC.Compile \s *
fofPC.Compile \f *

History:
-on Aug 9, 2006 (no SIMD yet) the fofPC.Compiled MatrixSVD.Mod runs somewhat faster than the PC.Compiled LinEqSVD.Mod
-most inner loops can be parallelized.
-in contrast, MatrixSVD.Mod produces more object code (12668 versus 8004 Bytes);
-some translation problems are shown in red above.

- on Oct, 2006, this module (no SIMD yet) runs about twice as fast as PC compiled LinEqSVD.Mod
- on March 2008, with SIMD in compiler, 4x faster than LinEqSVD.Mod


