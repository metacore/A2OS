MODULE MatrixActive; (** AUTHOR "Patrick Hunziker"; PURPOSE "EXPERIMENTAL - implicit statement parallel  execution of matrix algebra by operator overloading with synchronization statements "; *)

(* note: no efforts invested yet  to speed up code by non-copy data handling *)

(** COMPILER PROBLEMS
	- operator definition for ".*" does not work
	- how to defined operator for constant array, e.g. for  MatrixObject * [[1,2,],[3,4]]
	- inability to access return parameters for objects causes copy overhead ...
*)

IMPORT Objects, MatrixUtilities, MatrixBase, Out:=KernelLog;

CONST
	(*operations*)
	add=1;
	sub=2;
	mul=3;
	inner=11;
	outer=12;
	elementwise=13;
	solve=21;

	(** priorities*)
	Low*=Objects.Low;
	Normal*=Objects.Normal;
	High*=Objects.High;

TYPE
	Datatype*=FLOAT64;
	BaseVector* = ARRAY [*] OF Datatype; (*MatrixBase.Vector*)
	BaseMatrix* = ARRAY [*,*] OF Datatype;(*MatrixBase.Matrix*)

	Solver=MatrixBase.Solver;

	Matrix*= OBJECT
		VAR data*:BaseMatrix;
			vec*:BaseVector;
			val*:Datatype;
			locked:BOOLEAN; (*nonreentrant lock *)
			readers:SIGNED32; (*reentrant read-only locks*)
		PROCEDURE Lock; BEGIN {EXCLUSIVE} AWAIT((~locked)&(readers=0)); locked:=TRUE END Lock;
		PROCEDURE UnLock; BEGIN{EXCLUSIVE} locked:=FALSE END UnLock;
		PROCEDURE IncLock; BEGIN{EXCLUSIVE} INC(readers) END IncLock;
		PROCEDURE DecLock; BEGIN{EXCLUSIVE} DEC(readers) END DecLock;
		PROCEDURE WaitReadable*; BEGIN {EXCLUSIVE} AWAIT(~locked) END WaitReadable;
		PROCEDURE Log*;
			BEGIN{EXCLUSIVE} AWAIT(~locked);
				IF LEN(data)>0 THEN MatrixUtilities.OutMatrix(data);
				ELSIF LEN(vec)>0 THEN MatrixUtilities.OutVector(vec);
				ELSE Out.Int(ENTIER(val),0); Out.Char(".");
				Out.Int(ENTIER(10*val) MOD 10,0);
				Out.Int(ENTIER(100*val) MOD 10,0);
				Out.Ln;
				END;
			END Log;
	END Matrix;

	Writer=OBJECT
		PROCEDURE Write (CONST s:ARRAY OF CHAR);
		BEGIN {EXCLUSIVE}
			Out.String(s); Out.Ln;
		END Write;
	END Writer;

TYPE
	Op= OBJECT
		VAR l,r,res:Matrix;
			op:SIGNED32;
			solver:Solver;
		PROCEDURE &Set(op: SIGNED32; priority: SIGNED32; CONST l,r:Matrix; VAR res:Matrix);
		BEGIN
			(*BEGIN{EXCLUSIVE} AWAIT((r#NIL)&(l#NIL)) END; (*experiment*)*)
			Objects.SetPriority(priority);
			SELF.l:=l;
			SELF.r:=r;
			IF res=NIL THEN 	NEW(res) END;
			SELF.res:=res;
			SELF.op:=op;
			 res.Lock; 				(*blocks caller thread until res ready for being written*)
			 l.IncLock; r.IncLock;		(*add readers. no new write access before these are satisfied (see DecLock)*)
		END Set;

	BEGIN {ACTIVE}
		IF res#l THEN l.WaitReadable END; (*l must be ready. IF res=l THEN res is always locked at this moment *)
		IF res#r THEN r.WaitReadable END;
		(* optional: wait here until global number of computing threads is small enough to avoid collisions *)
		w.Write("computing ");
		INC(computingObjectCount);
		CASE op OF
			add: res.data:=l.data + r.data;
			| sub: res.data:=l.data - r.data;
			| mul: res.data:=l.data * r.data;
			| inner: res.val:=l.data +* r.data;
			| solve: NEW(solver,l.data); res:=solver.Solve(r.vec);
		END;
		l.DecLock;
		r.DecLock;
		res.UnLock;
		DEC(computingObjectCount);
	END Op;

VAR w:Writer;
	computingObjectCount-: SIGNED32;

OPERATOR ":="*(VAR l: Matrix; CONST r: BaseMatrix );
	BEGIN
		IF l=NIL THEN NEW(l) END;
		l.Lock;
		(*l.data:=r;*)
		l.data:=ALIAS OF r;(* TO DO check l.data size here and in other copying*)
		l.UnLock;
	END ":=";

OPERATOR ":="*(VAR l: Matrix;CONST r: BaseVector );
	BEGIN
		IF l=NIL THEN NEW(l) END;
		l.Lock;
		l.vec:=r;
		l.UnLock;
	END ":=";

OPERATOR ":="*(VAR l: BaseMatrix;CONST r: Matrix );
	BEGIN
		(*BEGIN{EXCLUSIVE} AWAIT(r#NIL) END; (*experiment*)*)
		r.IncLock;
		r.WaitReadable;
		(*l:=r.data;*)
		(*l := ALIAS OF r.data;*)(* PH nonfinal*) (*check l size *)
		l := r.data;
		r.DecLock;
	END ":=";

OPERATOR ":="*(VAR l: BaseVector;CONST r: Matrix );
	BEGIN
		(*BEGIN{EXCLUSIVE} AWAIT(r#NIL) END; (*experiment*)*)
		r.IncLock;
		r.WaitReadable;
		l:=r.vec;
		r.DecLock;
	END ":=";

OPERATOR "*"*(CONST l,r: Matrix):Matrix;
	VAR res:Matrix; op:Op;
	BEGIN
			(*IF RETURNPARAMETER=NIL THEN NEW(res) (*COMPILER PROBLEM _ DOES NOT WORK*)
			ELSE res:=RETURNPARAMETER
			END;*)
			NEW(op,mul,Normal,l,r,res);
			RETURN res
	END "*";

OPERATOR "*"*(CONST l: Matrix; CONST r:BaseMatrix):Matrix;
	VAR res,rtemp:Matrix; op:Op;
	BEGIN rtemp:=r; NEW(op,mul,Normal,l,rtemp,res); RETURN res
	END "*";

OPERATOR "*"*(CONST l: BaseMatrix; CONST r:Matrix):Matrix;
	VAR res,ltemp:Matrix; op:Op;
	BEGIN	ltemp:=l;NEW(op,mul,Normal,ltemp,r,res);RETURN res
	END "*";

OPERATOR "+"*(CONST l,r: Matrix):Matrix;
	VAR res:Matrix;op:Op;
	BEGIN NEW(op,add,Normal,l,r,res); RETURN res
	END "+";

OPERATOR "+"*(CONST l: Matrix; CONST r:BaseMatrix):Matrix;
	VAR rtemp,res:Matrix;op:Op;
	BEGIN rtemp:=r; NEW(op,add,Normal,l,rtemp,res); RETURN res
	END "+";

OPERATOR "+"*(CONST l: BaseMatrix; r: Matrix):Matrix;
	VAR ltemp,res:Matrix;op:Op;
	BEGIN ltemp:=l; NEW(op,add,Normal,ltemp,r,res); RETURN res
	END "+";

OPERATOR "-"*(CONST l,r: Matrix):Matrix;
	VAR res:Matrix;op:Op;
	BEGIN NEW(op,sub,Normal,l,r,res);	RETURN res
	END "-";

OPERATOR "-"*(CONST l: Matrix; CONST r:BaseMatrix):Matrix;
	VAR rtemp,res:Matrix;op:Op;
	BEGIN rtemp:=r; NEW(op,sub,Normal,l,rtemp,res); RETURN res
	END "-";

OPERATOR "-"*(CONST l: BaseMatrix; r: Matrix):Matrix;
	VAR ltemp,res:Matrix;op:Op;
	BEGIN ltemp:=l; NEW(op,sub,Normal,ltemp,r,res); RETURN res
	END "-";

(* (*compiler problem*)
OPERATOR ".*" (CONST l,r: Matrix):Matrix;
VAR res:Matrix;
BEGIN
		RETURN res
END ".*";
*)

OPERATOR "+*"*(CONST l,r: Matrix):Matrix;
	VAR res:Matrix; op:Op;
	BEGIN NEW(op,inner,Normal,l,r,res);	RETURN res
	END "+*";

OPERATOR "+*"*(CONST l: Matrix; CONST r:BaseMatrix):Matrix;
	VAR rtemp,res:Matrix; op:Op;
	BEGIN rtemp:=r; NEW(op,inner,Normal,l,rtemp,res);	RETURN res
	END "+*";

OPERATOR "+*"*(CONST l:BaseMatrix; CONST r: Matrix):Matrix;
	VAR ltemp,res:Matrix; op:Op;
	BEGIN ltemp:=l; NEW(op,inner,Normal,ltemp,r,res);	RETURN res
	END "+*";

OPERATOR "\"*(CONST l,r: Matrix):Matrix;
	VAR res:Matrix; op:Op;
	BEGIN NEW(op,solve,Normal,l,r,res); RETURN res
	END "\";

OPERATOR "\"*(CONST l: Matrix; CONST r:BaseVector):Matrix;
	VAR res,rtemp:Matrix; op:Op;
	BEGIN rtemp:=r; NEW(op,solve,Normal,l,rtemp,res); RETURN res
	END "\";

OPERATOR "\"*(CONST l: BaseMatrix; CONST r:Matrix):Matrix;
	VAR res,ltemp:Matrix; op:Op;
	BEGIN ltemp:=l; NEW(op,solve,Normal,ltemp,r,res); RETURN res
	END "\";

BEGIN
	NEW(w)
END MatrixActive.

SystemTools.Free TestMatrixActive MatrixActive  MatrixUtilities ~
TestMatrixActive.Test ~

