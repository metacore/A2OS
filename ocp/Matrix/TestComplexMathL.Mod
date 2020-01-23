MODULE TestComplexMathL; (** AUTHOR ""; PURPOSE ""; *)

IMPORT CMath:=ComplexMathL, Log:=KernelLog;

PROCEDURE Demo*;
CONST size= 16;
VAR a,b,c: CMath.COMPLEXTYPE; x:FLOAT32; y,z:CMath.Datatype; i:SIGNED16; j:SIGNED32;
	A,B,C: CMath.COMPLEXARRAY; P: CMath.POLARARRAY; R,I,Y: CMath.FLOATARRAY;
BEGIN
	c:=CMath.Complex(1.3,0.9);
	b:=CMath.Complex(2.5,2.2);
	x:=3.3;
	y:=3.3;
	j:= 7;
	CMath.Out(c,12,6,0); CMath.Out(b,12,6,0); CMath.Out(b,12,6,0);
	a:=b*c; Log.String("b*c"); CMath.Out(a,12,6,0);
	a:=b+c; Log.String("b+c"); CMath.Out(a,12,6,0);
	a:=b-c; Log.String("b-c");  CMath.Out(a,12,6,0);
	a:=b+j; Log.String("b+j"); CMath.Out(a,12,6,0);
	a:=j+b; Log.String("j+b"); CMath.Out(a,12,6,0);
	a:=b*x; Log.String("b*x"); CMath.Out(a,12,6,0);
	a:=b*y; Log.String("b*y"); CMath.Out(a,12,6,0);
	a:=j*b; Log.String("j*b"); CMath.Out(a,12,6,0);
	a:=b*j; Log.String("b*j"); CMath.Out(a,12,6,0);
	a:=b/c; Log.String("b/c"); CMath.Out(a,12,6,0);
	a:=b/x; Log.String("b/x"); CMath.Out(a,12,6,0);
	a:=b/y; Log.String("b/y"); CMath.Out(a,12,6,0);
	a:=b/j; Log.String("b/j"); CMath.Out(a,12,6,0);
	a:=j/b; Log.String("j/b"); CMath.Out(a,12,6,0);
	a:=y/b; Log.String("y/b"); CMath.Out(a,12,6,0);
	a:=x/b; Log.String("x/b"); CMath.Out(a,12,6,0);
	a:=CMath.sqrt( b);  Log.String("sqrt(b)"); CMath.Out(a,12,6,0);
	a:=b; Log.String("a:=b"); CMath.Out(a,12,6,0);
	a:=x; Log.String("a:=x"); CMath.Out(a,12,6,0);
	a:=y; Log.String("a:=y"); CMath.Out(a,12,6,0);
	a:=j; Log.String("a:=j");  CMath.Out(a,12,6,0);
	IF a=b THEN END;
	IF a#b THEN END;
	NEW(A,size); NEW(B,size); NEW(C,size); NEW(P,size); NEW(R,size); NEW(I,size);
	CMath.SetComplexArray(A,[0,1,2,3,4,5,6,7,8,7,6,5,4,3,2,1],[4,3,2,2,4,5,6,7,8,7,6,5,4,3,4,4]);

	B:=A+1;

	(*
	CMath.GetComplexArray(A, R,I);
	CMath.Out(A, 2,10, 0); Log.Ln;
	CMath.Out(B, 2, 10, 0);

	Util.CMath.OutVector(R);
	Util.CMath.OutVector(I);
	*)

	c:=CMath.Complex(1.5,1.5);
	CMath.Out(c,12,6,0);

	A:=B;
	A:=P;
	P:=A;

	A:=B+C;
	A:=B-C;
	A:=B.*C;
	A:=B./C;

	A:= B*y;
	A:= y*C;
	A:= B/y;
	A:= y/C;

END Demo;

END TestComplexMathL.

TestComplexMathL.Demo

SystemTools.Free TestComplexMathL ComplexMathL MatrixUtilities~
