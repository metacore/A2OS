MODULE HomogenousVectors; (** AUTHOR "Patrick Hunziker"; PURPOSE "low level fast operations on homogenous (4-vector) coordinates and 4*4 transforms"; *)

IMPORT SYSTEM;

TYPE 
	Vector*=ARRAY [4] OF FLOAT32;
	Transform*= ARRAY [4] OF Vector;

	(*
	OPERATOR "-"*((* CONST *) x: Vector): Vector;
	BEGIN
		RESULT:=-x[..];
		RETURN RESULT
	END "-";
	*)
	
	OPERATOR -"-"*(x {REGISTER}: Vector): Vector;
	VAR res{REGISTER}: Vector;	
	BEGIN
		CODE
			XORPS res, res
			SUBPS res, x
		END;
		RETURN res;
	END "-";

	(*
	OPERATOR "*"*((* CONST *) a,b: Vector):Vector; (*3D cross product in Vector[4]*)
	BEGIN
	RESULT[..2]:=a[..2]*b[..2];
	RESULT[3]:=0;
	RETURN RESULT
	END "*";	
	*)
	(*
	CONST  m*=[1.0,1.0,1.0,0.0];
	*)
	
	OPERATOR -"*"*(a{REGISTER},b{REGISTER}: Vector):Vector; (*3D cross product in Vector[4]*)
	VAR mask {REGISTER}, x{REGISTER}: Vector;
	BEGIN
		mask := [1.0,1.0,1.0,0.0];
		CODE
			MOVAPS x, a ; Make a copy of vector A
			
			; cross product: = [a2b3 - a3b2, a3b1 - a1b3, a1b2 - a2b1, 0]
			SHUFPS a, a, 0C9H ; 11 00 10 01 rearrange elements of A
			SHUFPS b, b, 0D2H ; 11 01 00 10 rearrange elements of B
			MULPS a, b ; Multiply the modified register vectors

			SHUFPS x, x, 0D2H ; 11 01 00 10 rearrange A copy

			SHUFPS b,b, 0D2H		; 00 10 11 01 re-rearranging elements 
			MULPS x, b

			SUBPS a, x ; Subtract the two resulting register vectors

			MULPS a, mask; remove element[3] of homogenous coordinate; needed not for vectors but for point
		END;
		RETURN a;
	END "*";	

	(*
 	OPERATOR "*"* ((* CONST *) A: Transform; (* CONST *) b: Vector):Vector; 
	BEGIN
		RESULT:=A[..3,..3]*b[..3];
		RETURN RESULT
	END "*";
	*)

	OPERATOR -"*"* ( CONST  A: Transform; vec{REGISTER}: Vector):Vector; (*! eventually use the SSE4 DPPS operation, but at current, it offers no speed or portability benefit*)
	VAR t0{REGISTER},t1{REGISTER},t2{REGISTER},t3{REGISTER}: Vector;
	BEGIN
		t0 := A[0];
		t1 := A[1];
		t2 := A[2];
		t3 := A[3];
		CODE		
			MULPS t0, vec 
			MULPS t1, vec 
			HADDPS t0, t1	; adjacent pairs are horizontally added 
			MULPS t2, vec 
			MULPS t3, vec 
			HADDPS t2, t3	; adjacent pairs are horizontally added 
			HADDPS t0, t2	; adjacent pairs are horizontally added
		END; 
		RETURN t0;
	END "*";

	(*
	OPERATOR "+"*((* CONST *) x,y: Vector): Vector;
	BEGIN
		RESULT:=x[..3]+y[..3];
		RETURN RESULT
	END "+";
	*)
	
	OPERATOR -"+"*(x{REGISTER},y{REGISTER}: Vector): Vector; (* x can be a point, y must be a vector*)
	BEGIN
		CODE
			ADDPS x,y
		END;
		RETURN x;
	END "+";
	
	(*
	OPERATOR "-"*((* CONST *) x,y: Vector): Vector;
	VAR result: Vector;
		res2: Vector;
	BEGIN
		RESULT:=x[..3]-y[..3];
		RETURN RESULT;
	END "-";
	*)
	
	OPERATOR -"-"*(x{REGISTER},y{REGISTER}: Vector): Vector; (* x can be a point, y must be a vector*)
	BEGIN
		CODE
			SUBPS x, y
		END;
		RETURN x;
	END "-";
	
	(*
	OPERATOR ".*"*((* CONST *) x,y: Vector): Vector;
	VAR result: Vector;
		res2: Vector;
	BEGIN
		RESULT:=x[..3] .*y [..3];
		RETURN RESULT;
	END ".*";
	*)
	
	OPERATOR -".*"*((* CONST *) x{REGISTER},y{REGISTER}: Vector): Vector;
	BEGIN
		CODE
			MULPS x,y
		END;
		RETURN x
	END ".*";
	
	(*
	OPERATOR "+*"*((* CONST *) x,y: Vector): FLOAT32;
	BEGIN
		RETURN x[..2] +*y [..2];
	END "+*";
	*)

	OPERATOR -"+*"* (left{REGISTER},right{REGISTER}: Vector):FLOAT32;
	VAR mask{REGISTER}: Vector; res{REGISTER}: FLOAT32;
	BEGIN
		mask := [1.0,1.0,1.0,0];
		CODE
			MULPS left, mask; remove leftmost element of homogenous coordinate
			MULPS left, right ; elementwise multiply
			HADDPS left, left ; adjacent pairs are horizontally added
			HADDPS left, left ; adjacent pairs are horizontally added
			; SSE4:shortens to; DPPS left, right ; but not faster at present and less portable
			MOVUPS res, left
		END;
		RETURN res;
	END "+*";
		
	(*
	OPERATOR "*"*((* CONST *) a: FLOAT32; (* CONST *) b: Vector):Vector; (*! 3-element scaling, to work with vector and points *)
	BEGIN
		RESULT[..2]:=a*b[..2];
		RESULT[3] := b[3];
		RETURN RESULT
	(*	RETURN a*b[..] (* XXXX führt zu falschem Bild *) *)
	(*	RETURN a*b[..2] (* XXXX führt zu erratischem Trap *) *)
	END "*";
	*)
	(*
	CONST  one*=[0.0, 0, 0, 1];
	*)
	
	OPERATOR -"*"*(r0{REGISTER}: FLOAT32; (* CONST *) r1{REGISTER}: Vector):Vector; (*! to do: distribute to position 0-2, leave 3 unchanged to work with vector and points *)
	(*(* CONST *) m=[1.0,1.0,1.0,0.0];*)
	VAR r2{REGISTER}: Vector;
	BEGIN
		r2 := [0.0,0,0,1];
		CODE
			; MULPS left, mask; remove leftmost element of homogenous coordinate; needed not for vectors but for points
			ADDPS r0, r2				; r0[3]:=1.0
			SHUFPS r0, r0, 0C0H ; 11 00 00 00 distribute factor a to r[0..2], keep r0[3]=1.0;
			MULPS r1, r0 
		END;
		RETURN r1;
	END "*";


	(*
		(* experimental 3-element comparison*)
		OPERATOR "<"*((* CONST *) left, right: Vector): BOOLEAN; (*! 3-element operator...*)
		BEGIN
		RETURN left[0..2]<right[0..2]
		END "<";
	*)
 	(* experimental 3-element comparison*)
	OPERATOR -"<"*((* CONST *) left{REGISTER}, right{REGISTER}: Vector): BOOLEAN; (* 3-element operator...*)
	VAR res{REGISTER}: BOOLEAN; R{REGISTER}: SIGNED32;
	BEGIN
		CODE
			CMPPS left, right, 001H ; less, elementwise comparison; 'true' for each element comparison results in 0FFFFFFFFH, 'false' results in 0H for each element 
			MOVMSKPS R, left ; produce one SIGNED32 from sign bit of all four REALs; in case of 'all true' this is 0FH, 
			CMP R, 07H ; three elements are true, one is false; i.e. a three element comparison
			JE true
			MOV res, 0
			JMP end
			true:
			MOV res, 1
			end:
		END;
		RETURN res;
	END "<";

	(*	
	(* experimental 3-element comparison*) 
	OPERATOR ">"*((* CONST *) left, right: Vector): BOOLEAN; (*! 3-element operator...*)
	BEGIN
		RETURN left[0..2]>right[0..2]
	END ">";
	*)

		(* experimental 3-element comparison*) (* TODO: 3-element comparators need improvement: the last element should have NO impact whatsoever*)
	OPERATOR -">"*(left{REGISTER}, right{REGISTER}: Vector): BOOLEAN; (* 3-element operator...*)
	VAR res{REGISTER}: BOOLEAN; R{REGISTER}: SIGNED32;
	BEGIN
		CODE
			CMPPS right, left, 001H ; less, elementwise comparison; 'true' for each element comparison results in 0FFFFFFFFH, 'false' results in 0H for each element 
			MOVMSKPS R, right ; produce one SIGNED32 from sign bit of all four REALs; in case of 'all true' this is 0FH, 
			CMP R, 07H ; three elements are true, one is false; i.e. a three element comparison
			JE true
			MOV res, 0
			JMP end
			true:
			MOV res, 1
			end:
		END;
		RETURN res;
	END ">";

	(*
	OPERATOR "<="*((* CONST *) left, right: Vector): BOOLEAN; (*! 4-element operator...*)
	BEGIN
	RETURN left[0..3]<=right[0..3]
	END "<=";
	*)
	
	OPERATOR -"<="*(left{REGISTER}, right{REGISTER}: Vector): BOOLEAN;
	VAR res{REGISTER}: BOOLEAN; R{REGISTER}: SIGNED32;
	BEGIN
		CODE
			CMPPS left, right, 002H ; less, elementwise comparison; 'true' for each element comparison results in 0FFFFFFFFH, 'false' results in 0H for each element 
			MOVMSKPS R, left ; produce one SIGNED32 from sign bit of all four REALs; in case of 'all true' this is 0FH, 
			CMP R, 0FH ; three elements are true, one is false; i.e. a three element comparison
			JE true
			MOV res, 0
			JMP end
			true:
			MOV res, 1
			end:
		END;
		RETURN res;
	END "<=";

	(*
		OPERATOR ">="*((* CONST *) left, right: Vector): BOOLEAN; (*! 4-element operator...*)
		BEGIN
		RETURN left[0..3]>=right[0..3]
		END ">=";
	*)

	OPERATOR -">="*(left{REGISTER}, right{REGISTER}: Vector): BOOLEAN;
	VAR res{REGISTER}: BOOLEAN; R{REGISTER}: SIGNED32;
	BEGIN
		CODE
			CMPPS right, left, 002H ; less, elementwise comparison; 'true' for each element comparison results in 0FFFFFFFFH, 'false' results in 0H for each element 
			MOVMSKPS R, right ; produce one SIGNED32 from sign bit of all four REALs; in case of 'all true' this is 0FH, 
			CMP R, 0FH ; three elements are true, one is false; i.e. a three element comparison
			JE true
			MOV res, 0
			JMP end
			true:
			MOV res, 1
			end:
		END;
		RETURN res;
	END ">=";
	
	
	(*
	OPERATOR "MAX"*((* CONST *) left, right: Vector): Vector;
	BEGIN
			RESULT[0]:=MAX(left[0],right[0]); 
			RESULT[1]:=MAX(left[1],right[1]); 
			RESULT[2]:=MAX(left[2],right[2]); 
			RESULT[3]:=MAX(left[3],right[3]); 
			RETURN RESULT
	END "MAX";
	*)

	OPERATOR -"MAX"*((* CONST *) left{REGISTER}, right{REGISTER}: Vector): Vector;
	BEGIN
		CODE
			MAXPS left, right ; elementwise maximum
		END;
		RETURN left
	END "MAX";

	(*
	OPERATOR "MIN"*((* CONST *) left, right: Vector): Vector;
	BEGIN
			RESULT[0]:=MIN(left[0],right[0]); 
			RESULT[1]:=MIN(left[1],right[1]); 
			RESULT[2]:=MIN(left[2],right[2]); 
			RESULT[3]:=MIN(left[3],right[3]); 
			RETURN RESULT
	END "MIN";

	*)

	OPERATOR -"MIN"*((* CONST *) left{REGISTER}, right{REGISTER}: Vector): Vector;
 	BEGIN
		CODE
			MINPS left, right ; elementwise minimum
		END;
		RETURN left;
	END "MIN";

	(*
		PROCEDURE Length* ((* CONST *) a: Vector):FLOAT32;
		VAR v:Vector;
		BEGIN
		v := a.*[1.0,1,1,0];
		RETURN Mathe.sqrt(v+*v);
		END Length;
	*)

 	PROCEDURE -Length* ((* CONST *) left{REGISTER}: Vector):FLOAT32;
	VAR res{REGISTER}: FLOAT32;
	BEGIN
		CODE
			PSLLDQ left, 4H
			PSRLDQ left, 4H
			;MULPS left, mask; in homogenous coordinates, the last element is 1 for points an 0 for vectors, and should not go into the length computation	
			MULPS left, left ; elementwise multiply
			HADDPS left, left ; adjacent pairs are horizontally added
			HADDPS left, left ; adjacent pairs are horizontally added
			SQRTSS left, left; SQRT is slow. could replace in outer scope by comparing squared length; or by using less accurate but faster (RSQRT + inverse)
			MOVUPS res, left
		END;
		RETURN res;
	END Length;
	
	(*
	PROCEDURE Normalize* ((* CONST *) a: Vector):Vector; (* works correctly only for vectors. if it is a point[3]=1 , the last element should remain constant! *)
	VAR v: Vector;
	BEGIN
	(*	v[..2]:= a[..2]/Mathe.sqrt(Length(a)); *)
		v[..2]:= a[..2]/Length(a); 
		v[3]:=a[3];
		RETURN v
	END Normalize;
	*)
	

	PROCEDURE -Normalize* ((* CONST *) a{REGISTER}: Vector):Vector; (* works correctly only for vectors. if it is a point[3]=1 , the last element should remain constant! *)
	VAR r0{REGISTER}, r1{REGISTER}, r2{REGISTER}, r3{REGISTER}, r4{REGISTER}, v{REGISTER}: Vector;
	CONST
	half4=[0.5, 0.5, 0.5, 0.5]; 
	three4=[3.0,3,3,3];
	BEGIN
		r0 := a;
		
		r3 := three4;
		r4 := half4;
		
		CODE
			;PSLLDQ r0, 4H
			;PSRLDQ r0, 4H
			;MULPS r0, mask; in homogenous coordinates, the last element is 1 for points an 0 for vectors, and should not go into the length computation

			MOVAPS r1, r0
			MULPS r0, r0 ; elementwise multiply

			HADDPS r0, r0 ; adjacent pairs are horizontally added
			HADDPS r0, r0 ; adjacent pairs are horizontally added
			SHUFPS r0, r0, 000H ; propagate first element to all elements 
			RSQRTPS r2, r0 ; 

			MULPS r0, r2; Newton Raphson iteration to improve on precision, which is not good enough for visual,otherwise
			MULPS r0, r2; muls
			MULPS r2, r4;
			SUBPS r3, r0;
			MULPS r3, r2 
			MULPS r3, r1; scale 
		END;
		
		RETURN r3;
	END Normalize;

	(*
	PROCEDURE InnerSquareDiff* ((* CONST *) a,b: Vector):FLOAT32;
	VAR v:Vector;
	BEGIN
		v:=b-a;
		RETURN v[..2] +* v[..2];
	END InnerSquareDiff;
	*)

	PROCEDURE -InnerSquareDiff* ((* CONST *) left{REGISTER},right{REGISTER}: Vector) : FLOAT32;
	VAR res {REGISTER} : FLOAT32;
	BEGIN
		CODE
			SUBPS left, right; vector difference
			MULPS left, left ; elementwise multiply of difference
			HADDPS left, left ; adjacent pairs are horizontally added
			HADDPS left, left ; adjacent pairs are horizontally added
			MOVUPS res, left
		END;
		RETURN res
	END InnerSquareDiff;

	(*
	PROCEDURE CastVector*(a,b,c,d: FLOAT32):Vector;
	BEGIN
		RETURN [a,b,c,d];
	END CastVector;
	*)
	
	PROCEDURE CastVector*(a{REGISTER},b{REGISTER}, c{REGISTER},d{REGISTER}: FLOAT32):Vector;
	VAR v{REGISTER}: Vector;
	BEGIN
		CODE
			MOVSS v,d
			SHUFPS v, v, 027H ; 00 10 01 11 exchange 0 and 3
			MOVSS v,c
			SHUFPS v, v, 0C6H ; 11 00 01 10 exchange 0 and 2
			MOVSS v,b
			SHUFPS v, v, 0E1H; 11 10 00 01 exchange 0 and 1
			MOVSS v,a
		END;
		RETURN v;
	END CastVector;

	(*
	OPERATOR -"/"* ( CONST  A: Transform; vec {REGISTER}: Vector):Vector;	
	VAR t0{REGISTER},t1{REGISTER},t2{REGISTER},t3{REGISTER}: Vector
	BEGIN
		(*t0 := A[0];
		t1 := A[1];
		t2 := A[2];
		t3 := A[3];
		CODE		
			MULPS t0, vec 
			MULPS t1, vec 
			HADDPS t0, t1	; adjacent pairs are horizontally added 
			MULPS t2, vec 
			MULPS t3, vec 
			HADDPS t2, t3	; adjacent pairs are horizontally added 
			HADDPS t0, t2	; adjacent pairs are horizontally added
		END; 
		RETURN t0;
		*)
	END "/";
		

	PROCEDURE InitGeometry(CONST a: Vector);
	BEGIN
		
	END InitGeometry;
	
	PROCEDURE TransformX*(CONST t: Transform);
	VAR A: Vector;
	BEGIN
		InitGeometry(t/A);		
	END TransformX;
	*)
	
	PROCEDURE P():Vector;
	BEGIN
		RETURN [1.0,2,3,4];	
	END P;
	
	PROCEDURE Test;
	VAR a,b,c: Vector;
	BEGIN
		a := P() + P() + P();
		a := b;
	END Test;
			
	
END HomogenousVectors.


System.FreeDownTo HomogenousVectors~
System.FreeDownTo FoxGlobal ~ HomogenousVectors~

System.FreeDownTo FoxIntermediateBackend ~ HomogenousVectors~
