MODULE ComplexMathL; (** AUTHOR "Patrick Hunziker"; PURPOSE "COMPLEX math module"; *)


IMPORT Mathe:=MathL, Streams, Strings, KernelLog;

CONST Pi=3.14159265358979323846;

TYPE
	Datatype*=FLOAT64;

	COMPLEXTYPE * = RECORD re*,im*: Datatype END; (*complex number in component representation*)
	POLAR * = RECORD abs*,arg*: Datatype END; (*complex number in polar representation*)
	COMPLEXARRAY* = ARRAY [*] OF COMPLEXTYPE;
	POLARARRAY* = ARRAY [*] OF POLAR;
	FLOATARRAY* = ARRAY [*] OF Datatype;

VAR i-, one-, zero-: COMPLEXTYPE;

OPERATOR ":="*(VAR l:COMPLEXTYPE; r:Datatype);
BEGIN
	l.re:=r;
	l.im:=0;
END ":=";

OPERATOR ":="*(VAR l:COMPLEXTYPE; r:POLAR);
BEGIN
	l.re:=  r.abs * Mathe.cos(r.arg);
	l.im:= r.abs * Mathe.sin(r.arg);
END ":=";

OPERATOR ":="*(VAR l:POLAR; r:COMPLEXTYPE);
BEGIN
	l.abs:=Abs(r);
	l.arg:=Arg(r);
END ":=";

OPERATOR ":="*(VAR l:COMPLEXARRAY; CONST r:FLOATARRAY);
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		l[i].re:=r[i]; l[i].im:=0;
	END;
END ":=";

OPERATOR ":="*(VAR l:COMPLEXARRAY; CONST r:POLARARRAY);
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		l[i]:=r[i]; (*implicit conversion - potential for optimization *)
	END;
END ":=";


OPERATOR ":="*(VAR l:POLARARRAY; CONST r:COMPLEXARRAY);
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		l[i]:=r[i];  (*implicit conversion - potential for optimization*)
	END;
END ":=";

PROCEDURE Complex*(CONST re,im:Datatype):COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=re; res.im:=im;
	RETURN res;
END Complex;

PROCEDURE Polar*(CONST abs,arg:Datatype):POLAR;
VAR res: POLAR;
BEGIN
	res.abs:=abs; res.arg:=arg;
	RETURN res
END Polar;


PROCEDURE GetComplex*(CONST l: COMPLEXTYPE; VAR re,im:Datatype);
BEGIN
	re:=l.re; im:=l.im;
END GetComplex;

PROCEDURE SetComplexArray*(VAR l: COMPLEXARRAY; CONST re,im:FLOATARRAY);
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		l[i].re:=re[i]; l[i].im:=im[i];
	END;
END SetComplexArray;

PROCEDURE GetComplexArray*(CONST l: COMPLEXARRAY; VAR re,im:FLOATARRAY);
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		re[i]:=l[i].re; im[i]:=l[i].im;
	END;
END GetComplexArray;

OPERATOR "="*(VAR l:COMPLEXTYPE; r:COMPLEXTYPE):BOOLEAN;
BEGIN
	RETURN (l.re=r.re) & (l.im=r.im)
END "=";

OPERATOR "="*(VAR l:COMPLEXTYPE; r:Datatype):BOOLEAN;
BEGIN
	RETURN (l.re=r) & (l.im=0)
END "=";

OPERATOR "="*(VAR l:Datatype; r:COMPLEXTYPE):BOOLEAN;
BEGIN
	RETURN (l=r.re) & (0=r.im)
END "=";

OPERATOR "="*(VAR l:COMPLEXTYPE; r:POLAR):BOOLEAN;
VAR c:COMPLEXTYPE;
BEGIN
	c:=r;
	RETURN l=c;
END "=";

OPERATOR "="*(VAR l:POLAR; r:COMPLEXTYPE):BOOLEAN;
VAR c:COMPLEXTYPE;
BEGIN
	c:=l;
	RETURN r=c;
END "=";

OPERATOR "#"*(VAR l:COMPLEXTYPE; r:COMPLEXTYPE):BOOLEAN;
BEGIN
	RETURN (l.re#r.re) OR (l.im#r.im);
END "#";

OPERATOR "#"*(VAR l:COMPLEXTYPE; r:Datatype):BOOLEAN;
BEGIN
	RETURN (l.re#r) OR (l.im # 0);
END "#";

OPERATOR "#"*(VAR l:Datatype; r:COMPLEXTYPE):BOOLEAN;
BEGIN
	RETURN (l#r.re) OR ( 0 # r.im);
END "#";

OPERATOR "#"*(VAR l:POLAR; r:COMPLEXTYPE):BOOLEAN;
BEGIN
	RETURN ~ (l=r)
END "#";

OPERATOR "#"*(VAR l:COMPLEXTYPE; r:POLAR):BOOLEAN;
BEGIN
	RETURN ~ (l=r)
END "#";

(*POLAR operators not yet defined - convert to COMPLEX before use*)

OPERATOR "+"*(l,r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l.re+r.re;
	res.im:=l.im+r.im;
	RETURN res
END "+";

OPERATOR "+"*(l:COMPLEXTYPE; r:Datatype): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l.re+r; res.im:=l.im;
	RETURN res;
END "+";

OPERATOR "+"*(l:Datatype; r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l+r.re; res.im:=r.im;
	RETURN res
END "+";

OPERATOR "+"*(l,r:POLAR): POLAR;
VAR a, b, c:COMPLEXTYPE; res:POLAR;
BEGIN
	a:=l; b:=r; c:=a+b; res:=c; (*perform addition in component representation*)
	RETURN res
END "+";

OPERATOR "+"*(CONST l,r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]+r[i];
	END;
	RETURN RESULT
END "+";

OPERATOR "+"*(CONST l:COMPLEXARRAY; CONST r: FLOATARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]+r[i];
	END;
	RETURN RESULT
END "+";

OPERATOR "+"*( CONST l: FLOATARRAY; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]+r[i];
	END;
	RETURN RESULT
END "+";

OPERATOR "+"*(CONST l:COMPLEXARRAY; r:COMPLEXTYPE):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]+r;
	END;
	RETURN RESULT
END "+";

OPERATOR "+"*(l:COMPLEXTYPE; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l+r[i];
	END;
	RETURN RESULT
END "+";

OPERATOR "+"*(CONST l:COMPLEXARRAY; r: Datatype):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]+r;
	END;
	RETURN RESULT
END "+";

OPERATOR "+"*( CONST l: Datatype; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l+r[i];
	END;
	RETURN RESULT
END "+";

OPERATOR "-"*(r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=-r.re;
	res.im:=-r.im;
	RETURN res
END "-";

OPERATOR "-"*(l,r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l.re-r.re;
	res.im:=l.im-r.im;
	RETURN res
END "-";

OPERATOR "-"*(l:COMPLEXTYPE; r:Datatype): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l.re-r;
	res.im:=l.im;
	RETURN res
END "-";

OPERATOR "-"*(l:Datatype; r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l-r.re;
	res.im:=-r.im;
	RETURN res
END "-";

OPERATOR "-"*(l,r:POLAR): POLAR;
VAR a, b, c:COMPLEXTYPE; res:POLAR;
BEGIN
	a:=l; b:=r; c:=a-b; res:=c; (*perform operation in component representation*)
	RETURN res
END "-";

OPERATOR "-"*(CONST l,r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]-r[i];
	END;
	RETURN RESULT
END "-";

OPERATOR "-"*(CONST l:COMPLEXARRAY; CONST r: FLOATARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]-r[i];
	END;
	RETURN RESULT
END "-";

OPERATOR "-"*( CONST l: FLOATARRAY; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]-r[i];
	END;
	RETURN RESULT
END "-";

OPERATOR "-"*(CONST l:COMPLEXARRAY; r:COMPLEXTYPE):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]-r;
	END;
	RETURN RESULT
END "-";

OPERATOR "-"*(l:COMPLEXTYPE; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l-r[i];
	END;
	RETURN RESULT
END "-";

OPERATOR "-"*(CONST l:COMPLEXARRAY; r: Datatype):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]-r;
	END;
	RETURN RESULT
END "-";

OPERATOR "-"*( CONST l: Datatype; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l-r[i];
	END;
	RETURN RESULT
END "-";

OPERATOR "*"*(l,r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:= l.re*r.re - l.im*r.im;
	res.im:=l.im*r.re + l.re*r.im;
	RETURN res
END "*";

OPERATOR "*"*(l: Datatype; r:COMPLEXTYPE): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l*r.re;
	res.im:=l*r.im;
	RETURN res
END "*";

OPERATOR "*"*(l:COMPLEXTYPE; r:Datatype): COMPLEXTYPE;
VAR res:COMPLEXTYPE;
BEGIN
	res.re:=l.re*r;
	res.im:=l.im*r;
	RETURN res
END "*";

OPERATOR "*"*(l,r:POLAR): POLAR;
VAR a, b, c:COMPLEXTYPE; res:POLAR;
BEGIN
	a:=l; b:=r; c:=a*b; res:=c; (*perform operation in component representation*)
	RETURN res
END "*";

OPERATOR "*"*(CONST l:COMPLEXARRAY; r:COMPLEXTYPE):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]*r;
	END;
	RETURN RESULT
END "*";

OPERATOR "*"*(l:COMPLEXTYPE; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l*r[i];
	END;
	RETURN RESULT
END "*";

OPERATOR "*"*(CONST l:COMPLEXARRAY; r: Datatype):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]*r;
	END;
	RETURN RESULT
END "*";

OPERATOR "*"*( CONST l: Datatype; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l*r[i];
	END;
	RETURN RESULT
END "*";

OPERATOR ".*"*(CONST l,r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]*r[i];
	END;
	RETURN RESULT
END ".*";

OPERATOR ".*"*(CONST l:COMPLEXARRAY; CONST r: FLOATARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]*r[i];
	END;
	RETURN RESULT
END ".*";

OPERATOR ".*"*( CONST l: FLOATARRAY; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]*r[i];
	END;
	RETURN RESULT
END ".*";

OPERATOR "/"*(l,r:COMPLEXTYPE): COMPLEXTYPE;
VAR rsqr:Datatype; VAR res:COMPLEXTYPE;
BEGIN
	rsqr:= r.re*r.re + r.im*r.im;
	res.re:=(l.re * r.re + l.im*r.im)/rsqr;
	res.im:=(l.im* r.re - l.re*r.im)/rsqr;
	RETURN res
END "/";

OPERATOR "/"*(l:Datatype; r:COMPLEXTYPE): COMPLEXTYPE;
VAR rsqr:Datatype; VAR res:COMPLEXTYPE;
BEGIN
	rsqr:= r.re*r.re + r.im*r.im;
	res.re:= l * r.re /rsqr;
	res.im:= - l*r.im/rsqr;
	RETURN res
END "/";

OPERATOR "/"*(l:COMPLEXTYPE; r:Datatype): COMPLEXTYPE;
VAR rsqr:Datatype; VAR res:COMPLEXTYPE;
BEGIN
	rsqr:= r*r;
	res.re:= l.re / r;
	res.im:=l.im/r;
	RETURN res
END "/";

OPERATOR "/"*(l,r:POLAR): POLAR;
VAR a, b, c:COMPLEXTYPE; res:POLAR;
BEGIN
	a:=l; b:=r; c:=a*b; res:=c; (*perform operation in component representation*)
	RETURN res
END "/";

OPERATOR "/"*(CONST l:COMPLEXARRAY; r:COMPLEXTYPE):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]/r;
	END;
	RETURN RESULT
END "/";

OPERATOR "/"*(l:COMPLEXTYPE; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l/r[i];
	END;
	RETURN RESULT
END "/";

OPERATOR "/"*(CONST l:COMPLEXARRAY; r: Datatype):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]/r;
	END;
	RETURN RESULT
END "/";

OPERATOR "/"*( CONST l: Datatype; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(r,0)-1 DO
		RESULT[i]:=l/r[i];
	END;
	RETURN RESULT
END "/";


OPERATOR "./"*(CONST l,r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]/r[i];
	END;
	RETURN RESULT
END "./";

OPERATOR "./"*(CONST l:COMPLEXARRAY; CONST r: FLOATARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]/r[i];
	END;
	RETURN RESULT
END "./";

OPERATOR "./"*( CONST l: FLOATARRAY; CONST r:COMPLEXARRAY):COMPLEXARRAY;
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(l,0)-1 DO
		RESULT[i]:=l[i]/r[i];
	END;
	RETURN RESULT
END "./";

(** Complex conjugate *)
OPERATOR "~"*( r: COMPLEXTYPE ): COMPLEXTYPE;
VAR res: COMPLEXTYPE;
BEGIN
	res.re := r.re;  res.im := -r.im;
	RETURN res
END "~";

PROCEDURE sqrt*(c:COMPLEXTYPE): COMPLEXTYPE;
VAR pol:POLAR; res:COMPLEXTYPE;
BEGIN
	IF c.im=0 THEN
		IF c.re<0 THEN res.re:=0; res.im := Mathe.sqrt(-c.re)
		ELSIF c.re=0 THEN res.re:=0; res.im:=0
		ELSE res.re:=Mathe.sqrt(c.re); res.im:=0;
		END;
	ELSE
		pol:=c;
		pol.abs:=Mathe.sqrt(pol.abs);
		pol.arg:=pol.arg/2;
		res:=pol;
	END;
	RETURN res
END sqrt;

(*! TODO: for the following procedures, special cases like argument=0 etc are not yet checked. Procedures are note yet tested *)

PROCEDURE sqrtp*(p:POLAR): POLAR;
VAR res:POLAR;
BEGIN
	res.abs:=Mathe.sqrt(p.abs);
	res.arg:=p.arg/2;
	RETURN res
END sqrtp;

PROCEDURE ln(c:COMPLEXTYPE): COMPLEXTYPE; (* -pi..+pi *)
VAR pol:POLAR; res:COMPLEXTYPE;
BEGIN
	pol:=c;
	RETURN Complex(Mathe.ln(pol.abs), pol.arg)
END ln;

PROCEDURE log(c, base:COMPLEXTYPE): COMPLEXTYPE;
BEGIN
	RETURN ln(c) / ln(base)
END log;

(* source: http://whyslopes.com/freeAccess/trigonometry_and_complex_numbers.html*)
PROCEDURE exp*(c:COMPLEXTYPE): COMPLEXTYPE; (*! not yet tested*)
BEGIN
	RETURN Mathe.exp(c.re) * cis(c.im);
END exp;

PROCEDURE sin(c:COMPLEXTYPE): COMPLEXTYPE; (*! not yet tested*)
BEGIN
	(*d:= i*c; RETURN ( exp(d)-exp(-d))/2/i *)
	RETURN sinh (i *c)/i
END sin;

PROCEDURE cos(c:COMPLEXTYPE): COMPLEXTYPE; (*! not yet tested*)
BEGIN
	RETURN  cosh(i * c) (*
	( d:= i*c; RETURN exp(d)+exp(-d))/2*)
END cos;

 (** cos(arg) + i*sin(arg) *)
PROCEDURE cis*(arg: Datatype): COMPLEXTYPE; (*! not yet tested*)
BEGIN
	RETURN Complex(Mathe.cos(arg), Mathe.sin(arg))
END cis;

PROCEDURE arctan(c:COMPLEXTYPE): COMPLEXTYPE; (*! not yet tested*)
END arctan;

PROCEDURE sinh(c:COMPLEXTYPE): COMPLEXTYPE; (*! not yet tested*)
BEGIN
	RETURN (exp(c) - exp(-c))/2
END sinh;

PROCEDURE cosh(c:COMPLEXTYPE): COMPLEXTYPE; (*! not yet tested*)
BEGIN
	RETURN (exp(c) + exp(-c))/2
END cosh;

PROCEDURE power*(c, expo: COMPLEXTYPE):COMPLEXTYPE; (*! not yet tested*)
BEGIN
	RETURN exp(expo * ln(c))
END power;

(** r'th root of complex number. r is real number*)
PROCEDURE root*(c: COMPLEXTYPE; r: Datatype):COMPLEXTYPE; (*! not yet tested*)
VAR pol: POLAR;
BEGIN
	IF c.im =0 THEN
		IF c.re=0 THEN RETURN zero
		ELSE RETURN Complex(Mathe.exp( Mathe.ln(pol.abs) / r), 0);
		END;
	ELSE
		pol:=c;
		RETURN cis(pol.arg/r) * Mathe.exp( Mathe.ln(pol.abs) / r)
	END;
END root;

	(* Abs & Arg from NbrCplx.Mod *)

PROCEDURE Abs*(c:COMPLEXTYPE):Datatype;
VAR res,absRe,absIm,ratio: Datatype;
BEGIN
	absRe:=ABS(c.re); absIm:=ABS(c.im);
	IF absRe>absIm THEN ratio := absIm/absRe; res :=absRe * Mathe.sqrt(1+ratio*ratio)
	ELSIF absIm=0 THEN res:=0
	ELSE ratio :=absRe/absIm; res:= absIm *Mathe.sqrt(1+ratio*ratio)
	END;
	RETURN res
END Abs;

PROCEDURE Arg*( x: COMPLEXTYPE ): Datatype;
VAR arg: Datatype;
	PROCEDURE ArcTan( xn, xd: Datatype): Datatype;
	VAR sn, sd: SIGNED32;  atan, ratio: Datatype;
	BEGIN
		IF xn < 0 THEN sn := -1
		ELSIF xn = 0 THEN sn := 0
		ELSE sn := 1
		END;
		IF xd < 0 THEN sd := -1
		ELSIF xd = 0 THEN sd := 0
		ELSE sd := 1
		END;
		IF xd = 0 THEN atan := sn * Pi / 2
		ELSIF xn = 0 THEN atan := (1 - sd) * Pi / 2
		ELSE ratio := xn / xd;  atan := Mathe.arctan( ratio ) + sn * (1 - sd) * Pi / 2
		END;
		RETURN atan
	END ArcTan;
	BEGIN
	IF x = 0 THEN arg := 0 ELSE arg := ArcTan( x.im, x.re ) END;
	RETURN arg
END Arg;

PROCEDURE Read(s:Streams.Reader):COMPLEXTYPE;
VAR c:COMPLEXTYPE;
BEGIN
	s.RawLReal(c.re); s.RawLReal(c.im); RETURN c
END Read;

PROCEDURE Write(s:Streams.Writer; c:COMPLEXTYPE); (*  2*conversion overhead when POLARs are written using this procedure *)
BEGIN
	s.RawLReal(c.re); s.RawLReal(c.im);
END Write;

PROCEDURE OutFloat(x: FLOAT64;  n, f, D: SIGNED32 );
	VAR str: ARRAY 64 OF CHAR;
	BEGIN
		Strings.FloatToStr( x, n, f, D, str );  KernelLog.String( str );
	END OutFloat;

PROCEDURE Out*(c:COMPLEXTYPE; n, f, D: SIGNED32 );
BEGIN
	OutFloat(c.re,n,f,D); OutFloat(c.im,n,f,D); KernelLog.String("i"); KernelLog.Ln;
END Out;

BEGIN
	i := Complex(0,1);
	zero := Complex(0,0);
	one := Complex(1,0);
END ComplexMathL.


TestComplexMathL.Demo

SystemTools.FreeDownTo ComplexMathL ~
