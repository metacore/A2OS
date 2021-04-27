MODULE HomogenousVectors; (** AUTHOR "Patrick Hunziker"; PURPOSE "low level fast operations on homogenous (4-vector) coordinates and 4*4 transforms"; *)

IMPORT SYSTEM, Out, Mathe := Math;

TYPE 
	Vector*=ARRAY [4] OF FLOAT32;
	Transform*= ARRAY [4] OF Vector;

CONST
	half4=[0.5, 0.5, 0.5, 0.5]; 
	three4=[3.0,3,3,3];
	
	OPERATOR "-"*(CONST x: Vector): Vector;
	VAR result: Vector;
	BEGIN
		result:=-x[..];
		RETURN result
	END "-";

	OPERATOR  "*"*(CONST a,b: Vector):Vector; (*3D cross product in Vector[4]*)
	VAR result: Vector;
	BEGIN
		 result[..2]:=a[..2]*b[..2];
		 result[3]:=0;
		 RETURN result
	END "*";	
	
	OPERATOR "*"* (CONST A: Transform; CONST b: Vector):Vector; 
	VAR result: Vector;
	BEGIN
		result:=A[..3,..3]*b[..3];
		RETURN result;
	END "*";
	
	OPERATOR "+"*(CONST x,y: Vector): Vector;
	VAR result: Vector;
	BEGIN
		result :=x[..3]+y[..3];
		RETURN result
	END "+";
	
	OPERATOR "-"*(CONST x,y: Vector): Vector;
	VAR result: Vector;
		res2: Vector;
	BEGIN
		result:=x[..3]-y[..3];
		RETURN result;
	END "-";
	
	OPERATOR ".*"*(CONST x,y: Vector): Vector;
	VAR result: Vector;
		res2: Vector;
	BEGIN
		result:=x[..3] .*y [..3];
		RETURN result;
	END ".*";

	OPERATOR "+*"*(CONST x,y: Vector): FLOAT32;
	BEGIN
		RETURN x[..2] +*y [..2];
	END "+*";

	OPERATOR "*"*(CONST a: FLOAT32; CONST b: Vector):Vector; (*! 3-element scaling, to work with vector and points *)
	VAR result: Vector;
	BEGIN
		result[..2]:=a*b[..2];
		result[3] := b[3];
		RETURN result;
	END "*";
   
	(* experimental 3-element comparison*)
	OPERATOR "<"*(CONST left, right: Vector): BOOLEAN; (*! 3-element operator...*)
	BEGIN
		RETURN left[0..2]<right[0..2]
	END "<";
	
	(* experimental 3-element comparison*) 
	OPERATOR ">"*(CONST left, right: Vector): BOOLEAN; (*! 3-element operator...*)
	BEGIN
		RETURN left[0..2]>right[0..2]
	END ">";

	OPERATOR "<="*(CONST left, right: Vector): BOOLEAN; (*! 4-element operator...*)
	BEGIN
		RETURN left[0..3]<=right[0..3]
	END "<=";

	OPERATOR ">="*(CONST left, right: Vector): BOOLEAN; (*! 4-element operator...*)
	BEGIN
		RETURN left[0..3]>=right[0..3]
	END ">=";
	
	OPERATOR "MAX"*(CONST left, right: Vector): Vector;
	VAR result: Vector;
	BEGIN
		result[0]:=MAX(left[0],right[0]); 
		result[1]:=MAX(left[1],right[1]); 
		result[2]:=MAX(left[2],right[2]); 
		result[3]:=MAX(left[3],right[3]); 
		RETURN result
	END "MAX";
	
	OPERATOR "MIN"*(CONST left, right: Vector): Vector;
	VAR result: Vector;
	BEGIN
		result[0]:=MIN(left[0],right[0]); 
		result[1]:=MIN(left[1],right[1]); 
		result[2]:=MIN(left[2],right[2]); 
		result[3]:=MIN(left[3],right[3]); 
		RETURN result
	END "MIN";

	PROCEDURE Length* (CONST a: Vector):FLOAT32;
	VAR v:Vector;
	BEGIN
	   v := a.*[1.0,1,1,0];
	   RETURN Mathe.sqrt(v+*v);
	END Length;

	PROCEDURE Normalize* (CONST a: Vector):Vector; (* works correctly only for vectors.  if it is a point[3]=1 , the last element should remain constant! *)
	VAR v: Vector;
	BEGIN
	  (*	v[..2]:= a[..2]/Mathe.sqrt(Length(a)); *)
		v[..2]:= a[..2]/Length(a); 
		v[3]:=a[3];
		RETURN v
	END Normalize;

	PROCEDURE InnerSquareDiff* (CONST a,b: Vector):FLOAT32;
	VAR v:Vector;
	BEGIN
	   v:=b-a;
	   RETURN v[..2] +* v[..2];
	END InnerSquareDiff;

	PROCEDURE CastVector*(a,b,c,d: FLOAT32):Vector;
	BEGIN
		RETURN [a,b,c,d];
	END CastVector;

END HomogenousVectors.

System.FreeDownTo HomogenousVectors~
