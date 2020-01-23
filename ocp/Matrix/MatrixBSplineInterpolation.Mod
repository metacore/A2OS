MODULE MatrixBSplineInterpolation;	(**  AUTHOR "ph"; PURPOSE "";  **)
IMPORT  MatrixBase, MatrixFilters:=LinearFilters;

TYPE Datatype=MatrixBase.Datatype;
		Vector=MatrixBase.Vector;
		Vector4=ARRAY[4]OF Datatype;
		Matrix=MatrixBase.Matrix;

 PROCEDURE cubicinterpolationfilter*(CONST B: Vector4):MatrixFilters.FIRFilter;
 VAR f:MatrixFilters.FIRFilter; T: ARRAY [4] OF Datatype;
 BEGIN
 	NEW(f); IF LEN(f.coeff)#4 THEN NEW(f.coeff,4); END;
 	f.origin:=1;
	f.coeff :=    [[-1.0D0,3,-3,1],
				[3,-6,3,0],
				[-3,0,3,0],
				[1,4,1,0]]
			* B;
	f.coeff := 1/6 * f.coeff;
	RETURN f
 END cubicinterpolationfilter;

 (*
 Simplify:
 Input:
A := {-1 , 3 , -3 , 1 ;
3 , -6 , 3 , 0 ;
-3 , 0 , 3 , 0 ;
1 , 4 , 1 , 0}

T := {ttt , tt , t , 1}

I := T * A;
I := {(1+(-1*ttt)+(3*tt)+(-3*t)) , (4+(3*ttt)+(-6*tt)) , (1+(-3*ttt)+(3*(t+tt))) , ttt}

I := I / 6
I := {((1/6)*(1+(-1*ttt)+(3*tt)+(-3*t))) , ((1/6)*(4+(3*ttt)+(-6*tt))) , ((1/6)*(1+(-3*ttt)+(3*(t+tt)))) , ((1/6)*ttt)}

B := 4 cubic B-spline coefficients
Interpolation value at (t) = B +* I
*)

(** input: 4 points given by their B-Spline coefficients B[0..3]; interpolation coordinate 0<=t<1 located between B[1] and B[2];
		output:  signal value at location t*)
PROCEDURE interpolate* (t: Datatype; CONST B: ARRAY [*] OF Datatype; splinedegree: SIGNED32): Datatype;
VAR T: ARRAY [*] OF Datatype;
		F: ARRAY [*,*] OF Datatype;
BEGIN
(*
						   	    [-1	3	-3	1]	[ba]
	s:=	 [t3  t2  t  1]  *  1/6 *  [3	 -6	3	 0]	[bb]
							    [-3	0	 3	 0]	[bc]
							    [1	  4	 1	 0]	[bd]
*)
	CASE splinedegree OF
	0: RETURN B[1]
	| 1: RETURN (1-t)*B[1] + t*B[2]	(* RETURN [1-t, t] +* B[1..2] *)
	| 2:
	(* correct version: see MatrixInterpolation.Mod*)
	(*  (*see "Interpolation Revisited, thevenaz0002.pdf"*)
		(*this is NOT the correct matrix for given B-spline coefficients*)
	(*with x0=-3/2*)
		T:=[t*t, t, 1];
		T:=T*
		[[9, 12,4],
		[6, 0, -8],
		[9,-12,4]];
		RETURN T+* B /8
	*)
	| 3:
		(* T:=[t*t*t, t*t, t, 1]; *)
		NEW(T,4);
		T[0]:= t*t*t; T[1]:=t*t; T[2]:=t; T[3]:=1;
 		T:=	T *
 		   [[-1.0D0,3,-3,1],
			[3,-6,3,0],
			[-3,0,3,0],
			[1,4,1,0]] ;
		RETURN T +*  B /6;
	| 4:
	| 5:
	ELSE
	END;
END interpolate;

(** given 3 Points by their B-Spline Coefficients B[0], B[1], B[2] yields new Coefficients B[01],B[11],B[12] which define
	the new, binary subdivided point sequence B[0], B[01],B[11],B[12], B[2] ;
	given 4 Points B[0], B[1], B[2], B[3] the new points B[01],B[11],B[12], B[22], B[23] are computed,
	yielding the sequence  B[0], B[01],B[11],B[12], B[22], B[23], B[3] *)
PROCEDURE subdivide* (t: Datatype; CONST B: ARRAY [*] OF Datatype; VAR NewB: ARRAY [*] OF Datatype; splinedegree: SIGNED32);
BEGIN

(*
						[4	4	 0]	[ba]
	s:=	 1/8 *  [1	 6	1]	[bb]
						[0	4	 4]	[bc]
*)
	IF LEN(B)=3 THEN
		CASE splinedegree OF
		0: NewB[0]:=0.5*B[0] + 0.5*B[1];  NewB[1]:=B[1]; NewB[2]:=0.5*B[1] + 0.5*B[2];
		| 1: NewB[0]:=0.75*B[0] + 0.25*B[1];  NewB[1]:=0.5*B[0] + 0.5*B[2]; NewB[2]:=0.25*B[1] + 0.75*B[2]; (* is this really order 1 ?*)
		| 2:
		| 3:
			 NewB:=
		 		   [[4.0D0, 4, 0],
					[1, 6, 1],
					[0, 4, 4]]
					*  B;
			NewB:=NewB/8;
		| 4:
		| 5:
		ELSE
		END;
	ELSIF LEN(B)=4 THEN
		CASE splinedegree OF
		0,1:
		| 2:
		| 3:
			 NewB:=
		 		   [[4.0D0, 4, 0, 0],
					[1, 6, 1, 0],
					[0, 4, 4, 0],
					[1, 6, 1, 0],
					[0, 0, 4, 4]]
					*  B;
			NewB:=NewB/8;
		| 4:
		| 5:
		ELSE
		END;
	END;
END subdivide;

(** interpolation from a regularly sampled dataset in 1D to a result vector with a new sampling interval by spline interpolation.
input: a 1D array of N spline coefficients C at regular intervals; result vector size M.
output: a M*4 matrix of weights for interpolation; an index table of size M giving the position of the first coeffient for each interpolation location.
application: do an inner product of strides of 4 coefficients of the signal coefficients (starting at indices[i]) with the weights given in the table row[i].
CAVE: boundary not handled here; i.e., indices array will contain indices <0 and/or > LEN(C) *)
PROCEDURE LineInterpolationWeights*(datasize,resultsize, splinedegree: SIZE; x,dx:Datatype; VAR indices: ARRAY [*] OF SIGNED32): Matrix;
CONST div6=1/6;
VAR w:Matrix;
		t,tt,ttt: Datatype;
		i:SIZE; index:SIGNED32;
BEGIN
	NEW(w,resultsize,4);
	NEW(indices,resultsize);
	(*dx:= (datasize-1) / (resultsize-1);*)
	FOR i:=0 TO resultsize-1 DO
		index:=ENTIER(x);
		indices[i]:=index-1; (*first coefficient relevant for interplation at x*)
		t:=x-index; tt:=t*t; ttt:=t*tt;
		w[i,0]:= (1-ttt+3*tt-3*t)/6;
		w[i,1]:= (4+3*ttt-6*tt)/6;
		w[i,2]:= (1-3*ttt+3*(t+tt))/6;
		w[i,3]:= ttt/6;
		x:=x+dx;
	END;
	RETURN w
END LineInterpolationWeights;

PROCEDURE InterpolateLine*(CONST coefficients: Vector; CONST weights:Matrix; CONST indices:ARRAY [*] OF SIGNED32):Vector;
VAR v:Vector; i, size:SIZE;
BEGIN
	NEW(v,LEN(indices,0));
	size:=LEN(weights,1);
	FOR i:=size DIV 2 +1 TO LEN(v,0)-2 - size DIV 2 DO
		v[i]:=weights[i] +* coefficients[indices[i]..indices[i]+size-1]
	END;
	RETURN v
END InterpolateLine;
(*
PROCEDURE Do*;
VAR P: ARRAY [*] OF Datatype; t,s: Datatype; f:MatrixFilters.FIRFilter;
BEGIN
	In.Open; In.LongReal(t);
	P:= [0,0,0,1];
	s:= interpolate(t,P,3);
	Out.LongRealFix(s,3,6); Out.Ln;
	f := cubicinterpolationfilter(0.5);
	Out.LongRealFix(f.coeff[0],3,6); Out.Ln;
	Out.LongRealFix(f.coeff[1],3,6); Out.Ln;
	Out.LongRealFix(f.coeff[2],3,6); Out.Ln;
	Out.LongRealFix(f.coeff[3],3,6); Out.Ln;
END Do;

PROCEDURE Do2*;
VAR c,s:Vector; w:Matrix; indices:ARRAY [*] OF SIGNED32;
BEGIN
	c:=[0,0,1,2,3,4,5,6,7,8,9,10,9,8,7,6,5,0,0,0];
	NEW(s,15);
	w:=LineInterpolationWeights(LEN(c), LEN(s), 3, 5, (LEN(c)-1)/(LEN(s)-1+10), indices);
	s:=InterpolateLine(c, w, indices);
	MatrixUtilities.OutVector(c);
	MatrixUtilities.OutMatrix(w); Out.Ln;
	MatrixUtilities.OutVector(indices); Out.Ln;
	MatrixUtilities.OutVector(s); Out.Ln;
END Do2;
*)

END MatrixBSplineInterpolation.

MatrixBSplineInterpolation.Do

System.Free
MatrixFilters
MatrixBSplineInterpolation.Do 1
MatrixBSplineInterpolation.Do2
fofPC.Compile \f *

