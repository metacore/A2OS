MODULE MatrixPolynomEq;   (**  AUTHOR "Patrick Hunziker"; PURPOSE "robust computation of polynomial roots: quadratic, cubic,  quartic (directly ) ; higher (by iterative methods) ";  **)

IMPORT MathL, MatrixBase;

CONST
	inv3 = 1 / 3;  eps = 1.11022302463E-16;
TYPE
	Datatype = MatrixBase.Datatype;
	Vector = MatrixBase.Vector;

VAR
	rt3, Max: Datatype;

	PROCEDURE pow( base, exponent: Datatype ): Datatype;
	BEGIN
		IF ABS( base ) < eps THEN RETURN 0
		ELSE RETURN MathL.exp( exponent * MathL.ln( base ) );
		END;
	END pow;

	PROCEDURE sign( x: Datatype ): Datatype;
	BEGIN
		IF x < 0 THEN RETURN -1
		ELSIF x > 0 THEN RETURN 1
		ELSE RETURN 0
		END;
	END sign;

	PROCEDURE arccos( x: Datatype ): Datatype;   (* Returns the arcus cosine of 'x' in the range [0, p] where -1 <= x <= 1 *)
	CONST dec=0.000001;
	VAR n, d, abs: Datatype;
	BEGIN
		abs := ABS( x );
		IF x>1 THEN x:=x-dec ELSIF x<-1 THEN x:=x+dec END; (*catch rounding errors*)
		IF FALSE THEN
		ELSIF x = 1 THEN n := 0;  d := x;  RETURN arctan2( n, d )
		ELSIF x = -1 THEN n := 0;  d := x;  RETURN arctan2( n, d )
		ELSE n := MathL.sqrt( 1 - x * x );  d := x;  RETURN arctan2( n, d )
		END;
	END arccos;

	PROCEDURE arctan2( xn, xd: Datatype ): Datatype;   (** Quadrant-correct arcus tangent: atan(xn/xd). *)
	BEGIN
		IF xd = 0 THEN
			IF xn # 0 THEN RETURN sign( xn ) * MathL.pi / 2
			ELSE HALT( 100 );  RETURN 0
			END
		ELSIF xn = 0 THEN RETURN (1 - sign( xd )) * MathL.pi / 2
		ELSE
			RETURN MathL.arctan( xn / xd ) + sign( xn ) * (1 - sign( xd )) * MathL.pi / 2
		END;
	END arctan2;

	PROCEDURE acos3( x: Datatype ): Datatype;
	BEGIN
		RETURN MathL.cos( arccos( x ) * inv3 )
	END acos3;

	PROCEDURE cubicroot( x: Datatype ): Datatype;
	BEGIN
		IF x > 0 THEN RETURN pow( x, inv3 )
		ELSIF x < 0 THEN RETURN -pow( -x, inv3 )
		ELSE RETURN 0
		END;
	END cubicroot;

(*
(*not yet tested/activated*)
PROCEDURE cubenewton (p,q,r: Datatype; VAR v3: Vector);
VAR j,k,n3: SIGNED32; corr, deriv, err, root: Datatype;
BEGIN
	FOR j:=0 TO LEN(v3)-1 DO
		FOR k:=0 TO 3 DO
			root:=v3[j];
			err := ((root+p)*root+q * root)+r;
			deriv := (3*root + 2* p)*root + q;
			IF deriv # 0.0 THEN corr := err/deriv ELSE corr := 0 END;
			v3[j] := v3[j] - err;
		END;
	END;
END cubenewton;
*)
PROCEDURE new(VAR v: Vector; minsize:SIZE);
BEGIN
	IF LEN(v)<minsize THEN NEW(v,minsize) ELSE v:=0 END;
END new;


(** Find real roots of cubic equation x3 +px2 +qx +r = 0 ; method: D.E. Littlewood, "A University Algebra" pp.173; *)
	PROCEDURE Cubic*( p, q, r: Datatype ): Vector;  (*If result target is already an allocated vector with length >= number of eigenvalues, it is reused in the existing length; otherwise, a new vector of minimum necessary length (length 1..3) is given*)
	VAR n3: SIGNED32;
		po3, po3sq, qo3, po3q, uo3, u2o3, uo3sq4, uo3cu4, v, v0, vsq, wsq: Datatype;
		m1, m2, mcube, muo3, s, scube, t, cosk, rt3sink, sinsqk: Datatype;
		v2, v3: Vector;
	BEGIN
		m1 := 0;  m2 := 0;  po3 := 0;  v := 0;  uo3 := 0;  cosk := 0;
		v3:=RESULT; (*redundant local variable*)
		(*n3:=1; *)  (*default*)
		IF r = 0 THEN
			v2 := Quadratic( p, q );  new( v3, LEN( v2,0 ) + 1 );
			v3[.. LEN( v2,0 ) - 1] := v2;   (*v3[n3++]:=0;*)  (*TO DO check if correct number of roots inclusive lagging 0 is returned*)
		ELSIF (p = 0) & (q = 0) THEN new( v3, 3 );  v3[0] := cubicroot( -r );  v3[1] := v3[0];  v3[2] := v3[0];
		ELSIF (p > Max) OR (p < -Max) THEN new( v3, 1 );  v3[0] := -p;
		ELSIF (q > Max) OR (q < -Max) THEN
			new( v3, 1 );
			IF q > 0 THEN v3[0] := -r / q;
			ELSIF q < 0 THEN v3[0] := -MathL.sqrt( -q );
			ELSE v3[0] := 0;
			END;
		ELSIF (r > Max) OR (r < -Max) THEN
			new( v3, 1 );  v3[0] := -cubicroot( r );
		ELSE
			po3 := p * inv3;  po3q := po3 * q;  po3sq := po3 * po3;
			IF po3sq > Max THEN new( v3, 1 );  v3[0] := -p;
			ELSE
				v := r + po3 * (po3sq + po3sq - q);
				IF (v > Max) OR (v < -Max) THEN new( v3, 1 );  v3[0] := -p;
				ELSE
					vsq := v * v;  qo3 := q * inv3;  uo3 := qo3 - po3sq;  u2o3 := uo3 + uo3;
					IF (u2o3 > Max) OR (u2o3 < -Max) THEN
						IF p = 0 THEN
							IF q > 0 THEN v3[0] := -r / q;
							ELSIF q < 0 THEN v3[0] := -MathL.sqrt( -q );
							ELSE v3[0] := 0;
							END;
						ELSE v3[0] := -q / p;
						END;
					ELSE
						uo3sq4 := u2o3 * u2o3;
						IF uo3sq4 > Max THEN
							new( v3, 1 );
							IF p = 0 THEN
								IF q > 0 THEN v3[0] := -r / q;
								ELSIF q < 0 THEN v3[0] := -MathL.sqrt( -q );
								ELSE v3[0] := 0
								END;
							ELSE v3[0] := -q / p;
							END;
						ELSE
							uo3cu4 := uo3sq4 * uo3;  wsq := uo3cu4 + vsq;
							IF wsq > 0 THEN  (*cubic has one real root -*)
								IF v <= 0 THEN mcube := (-v + MathL.sqrt( wsq )) * 0.5;
								ELSE mcube := (-v - MathL.sqrt( wsq )) * 0.5;
								END;
								m1 := cubicroot( mcube );
								IF m1 # 0 THEN m2 := -uo3 / m1;  ELSE m2 := 0;  END;
								new( v3, 1 );  v3[0] := m1 + m2 - po3;
							ELSE  (*cubic has three real roots *)
								IF uo3 < 0 THEN
									muo3 := -uo3;
									IF muo3 > 0 THEN
										s := MathL.sqrt( muo3 );
										IF p > 0 THEN s := -s END;
									ELSE s := 0;
									END;
									scube := s * muo3;
									IF scube = 0 THEN new( v3, 1 );  v3[0] := m1 + m2 - po3;
									ELSE
										t := -v / (scube + scube);  cosk := acos3( t );
										(*v3[0]*) v0 := (s + s) * cosk - po3;
										sinsqk := 1 - cosk * cosk;
										IF sinsqk >= 0 THEN
											new( v3, 3 );  v3[0] := v0;
											rt3sink := rt3 * MathL.sqrt( sinsqk );
											v3[1] := s * (-cosk + rt3sink) - po3;
											v3[2] := s * (-cosk - rt3sink) - po3;  n3 := 3;
										ELSE new( v3, 1 );  v3[0] := v0;
										END;
									END;
								ELSE  (*  cubic has multiple root *)
									new( v3, 3 );  v3[0] := cubicroot( v ) - po3;  v3[1] := v3[0];
									v3[2] := v3[0];
								END;
							END;
						END;
					END;
				END;
			END;
		END;
		(*IF iterate THEN cubnewton(p,q,r,n3,v3); END;*)	(*improve roots by NewtonRaphson iteration*) (*not yet implemented*)
		RETURN v3
	END Cubic;

(** solve the quadratic equation x^2 + bx + c = 0 *)
	PROCEDURE Quadratic*( b, c: Datatype ): Vector;
	VAR dis, rtdis: Datatype;  roots: Vector;
	BEGIN
		dis := b * b - 4 * c;
		IF b = 0 THEN
			IF c = 0 THEN roots := [0, 0];
			ELSIF c < 0 THEN
				NEW( roots, 2 );  roots[0] := MathL.sqrt( -c );  roots[1] := -roots[0];
			ELSE
				(*nroots := 0;*)
			END;
		ELSIF c = 0 THEN
			NEW( roots, 2 );  roots[0] := -b;   (*roots[1]:=0; *)
		ELSIF dis >= 0 THEN
			NEW( roots, 2 );
			rtdis := MathL.sqrt( dis );
			IF b > 0 THEN roots[0] := (-b - rtdis) * 0.5;
			ELSE roots[0] := (-b + rtdis) * 0.5;
			END;
			IF roots[0] = 0 THEN roots[1] := -b;  ELSE roots[1] := c / roots[0];  END;
		ELSE
			(*nroots := 0;*)
		END;
		RETURN roots
	END Quadratic;

(** solve the quadratic equation  x^4 +a*x^3 +b*x^2 + cx + d = 0 *)
(*
	PROCEDURE Quartic*;
		 (*not yet implemented*)
		(*for a very general version circumventing all possible problems, see http://linus.socs.uts.edu.au/~don/src/quartic.c  and http://linus.socs.uts.edu.au/~don/pubs/solving.html *)
	END Quartic;
*)

BEGIN
	rt3 := MathL.sqrt( 3 );  Max := MathL.sqrt( MAX( FLOAT64 ) );
END MatrixPolynomEq.

(*
(** method of Cardano to solve cubic equation x3+ax2+bx+c=0  , see http://en.wikipedia.org/wiki/Cubic_equation *)
PROCEDURE cardano(a,b,c: Datatype; VAR x0,x1,x2:Datatype  ); (*solves cubic equation, see wikipedia 'cubic equation'; implementation limitation: real case/real result*)
VAR p,q,u,v,t:Datatype;
BEGIN
	p:=b-sqr(a)/3;
	q:=c + (2*cub(a)-9*a*b)/27;
	IF p=0 THEN
		IF q=0 THEN
			x0:=-a/3; x1:=-a/3; x2:=-a/3;
			RETURN
		ELSE
			u0:=pow(q, 1/3);
			(*u1, u2*) (*complex solutions*)
		END
	ELSE
		u0:= pow((q/2 + MathL.sqrt(sqr(q)/4+cub(p)/27)), 1/3); (*principal solution*)
		(* u1:= u0* (-1/2 + i*MathL.sqrt(3)/2);			*)(*complex solutions with *)
		(* u2:= u0* (-1/2 - i*MathL.sqrt(3)/2);			*)
	END;
	x0:=p/3/u0 - u0 - a/3;
	HALT(100); (*complex solutions and evaluation of u1,u2 neglected here ! *)
END cardano;

*)

fofPC.Compile \s *

fofPC.
OFormatter.Format *

 (*  solving quartic equations directly:
 see  http://linus.socs.uts.edu.au/~don/pubs/solving.html; circumvents the individual problems of each implementation for solving quartic equations *)
(*not tested*)

PROCEDURE quartic(a,b,c,d: Datatype; VAR rts: ARRAY [4] OF Datatype);
(*
   Solve quartic equation using either
   quadratic, Ferrari's or Neumark's algorithm.
   calls  descartes, ferrari, neumark, yacfraid.
     15 Dec 2003  added yacfraid
     10 Dec 2003  added descartes with neg coeffs
     21 Jan 1989  Don Herbison-Evans
*)
  VAR
  	j,k,nq,nr: SIGNED32;
  	odd, even: Datatype;
   	roots: ARRAY [4] OF Datatype;
BEGIN
   IF (ABS(a) > Max) THEN
   	nr := yacfraid(a,b,c,d,rts);
   ELSE
 	  if (a = 0) & (c = 0) THEN
 	     nq = quadratic(b,d,roots);
 	     nr = 0;
 	     FOR j:=0 TO nq-1 DO
 	        IF (roots[0] >= 0) THEN
 	           rts[0] := MathL.sqrt(roots[0]);
 	           rts[1] := -rts[0];
 	           nr := 2;
 	        END;
 	        IF (roots[1] >= 0) THEN
 	           rts[nr] := MathL.sqrt(roots[1]);
 	           rts[nr+1] := -rts[nr];
 	           INC(nr, 2);
 	        END;
 	     END;
 	  ELSE
 	     k = 0;
 	     IF a < 0 THEN INC(k,2) END;
 	     IF b < 0 THEN INC(k,1) END;
 	     IF c < 0 THEN INC(k,8) END;
 	     IF d < 0 THEN INC(k,4) END;
 	     CASE k OF
 	             0 : nr := neumark(a,b,c,d,rts);
 	             | 1 : nr := neumark(a,b,c,d,rts);
 	             | 2 : nr := neumark(a,b,c,d,rts);
 	             | 3 : nr := ferrari(a,b,c,d,rts);
 	             | 4 : nr := neumark(a,b,c,d,rts);
 	             | 5 : nr := descartes(a,b,c,d,rts);
 	             | 6 : nr := neumark(a,b,c,d,rts);
 	             | 7 : nr := neumark(a,b,c,d,rts);
 	             | 8 : nr := neumark(a,b,c,d,rts);
 	             | 9 : nr := ferrari(a,b,c,d,rts);
 	             | 10 : nr := neumark(a,b,c,d,rts);
 	             | 11 : nr := neumark(a,b,c,d,rts);
 	             | 12 : nr := neumark(a,b,c,d,rts);
 	             | 13 : nr := neumark(a,b,c,d,rts);
 	             | 14 : nr := neumark(a,b,c,d,rts);
 	             | 15 : nr := descartes(-a,b,-c,d,rts);
 	     END;
 	     IF k = 15 THEN
 	       FOR j := 0 TO nr -1 DO rts[j] := -rts[j] END;
 	     END;
 	  END;
 	  RETURN nr;
END quartic;
