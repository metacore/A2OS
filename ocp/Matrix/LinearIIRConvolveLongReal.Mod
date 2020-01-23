MODULE LinearIIRConvolveLongReal ;	(**  AUTHOR "Patrick Hunziker"; PURPOSE "";  **)
IMPORT math:=MathL;
CONST	finite* = 0;  periodic* = 1;  mirrorH* = 2;  mirrorW* = 3;  antimirrorH* = 4;  antimirrorW* = 5;
	OneDivLn10= 0.434294483456101D0;
		(*tolerance=-15.9;*) (*log10(eps) FLOAT64*)
		tolerance=-7.2;

TYPE Datatype=FLOAT64;

PROCEDURE ConvolveFinite*(CONST in: ARRAY [*] OF Datatype; VAR out: ARRAY [*] OF Datatype; CONST poles: ARRAY [*] OF Datatype; gain: Datatype);
(**	Discrete recursive convolution:
				signal has finite support LEN(in,0)
				kernel is given by its real poles
		Preconditions:
				input and output may use the same array*)
VAR i,j:SIZE; pole:Datatype;
BEGIN
	ASSERT(LEN(poles,0)>0,100);
	ASSERT(LEN(in,0)<=LEN(out),101);
	FOR i:=0 TO LEN(in,0)-1 DO out[i]:=in[i]*gain END;
	IF LEN(in,0)=1 THEN RETURN END;
	FOR i:=0 TO LEN(poles,0)-1 DO
		pole:=poles[i];
		FOR j:=1 TO LEN(in,0)-1 		DO out[j]:=out[j]+out[j-1]*pole END;
		j:=LEN(in,0)-2;
		FOR j:=LEN(in,0)-2 TO 0 BY -1 DO out[j]:=out[j]+out[j+1]*pole END;
	END;
END ConvolveFinite;

(*
PROCEDURE ConvolveFiniteB*(CONST in: ARRAY [*] OF Datatype; VAR out: ARRAY [*] OF Datatype; CONST poles: ARRAY [*] OF Datatype; gain: Datatype);
(**	Discrete recursive convolution:
				signal has finite support LEN(in,0)
				kernel is given by its real poles
		Preconditions:
				input and output may use the same array*)
VAR i,j:SIGNED32; pole:Datatype;
BEGIN
	ASSERT(LEN(poles,0)>0,100);
	ASSERT(LEN(in,0)<=LEN(out),101);
	FOR i:=0 TO LEN(in,0)-1 DO out[i]:=in[i]*gain END;
	IF LEN(in,0)=1 THEN RETURN END;
	FOR i:=0 TO LEN(poles,0)-1 DO
		pole:=poles[i];
		FOR j:=1 TO LEN(in,0)-1 		DO out[j]:=out[j]+out[j-1]*pole END;(*original version*)
		(*out[1..]:=out[1..] + [..LEN(out-1)] * pole;  *) (*not correctg: loop above is dependent on itself, leading to a data collision in this kind of parallelization*)
		j:=LEN(in,0)-2;
		FOR j:=LEN(in,0)-2 TO 0 BY -1 DO out[j]:=out[j]+out[j+1]*pole END;

	END;
END ConvolveFiniteB;
*)

PROCEDURE ConvolveMirror*(CONST in: ARRAY [*] OF Datatype; VAR out: ARRAY [*] OF Datatype; CONST poles: ARRAY [*] OF Datatype; gain: Datatype );
(**	Discrete recursive convolution:
				signal has infinite, periodic support  2*LEN(in,0)
				data [LEN(in,0)..2*LEN(in,0)-1] = mirror image of data[0..LEN(in,0)-1]
				kernel is given by its real poles
		Preconditions:
				input and output may use the same array *)

VAR i,j,k,n,n2:SIZE;
	x0,pole:Datatype;
BEGIN
	ASSERT(LEN(in,0)<=LEN(out),101);
	ASSERT(LEN(poles,0)>0,100);
	n:=LEN(in,0);
	FOR k:=0 TO n-1 DO out[k]:=in[k]*gain END;
	IF n=1 THEN RETURN END;
	n2:=(2*LEN(in,0)-1);
	FOR i:=0 TO LEN(poles,0)-1 DO
		pole:=poles[i];
		j:=ENTIER(tolerance/math.ln(ABS(pole))*OneDivLn10)+1;
		k:=j-n2*(j DIV n2);
		j:=j-k;
		IF k< n THEN x0:=out[k]
		ELSE
			x0:=out[n2-k];
			FOR k:=n2-k+1 TO n-1 DO x0:=pole*x0+out[k] END;
		END;
		FOR k:=n-1 TO 0 BY -1 	DO x0:=pole*x0+out[k] END;
		WHILE j>0 DO
			FOR k:=1 TO n-1 		DO x0:=pole*x0+out[k] END;
			FOR k:=n-2 TO 0 BY -1 DO x0:=pole*x0+out[k] END;
			j:=j-n2;
		END;
		out[0]:=x0;
		x0:=out[n-1];
		FOR k:=1 TO n-1 		DO out[k]:=out[k]+out[k-1]*pole END;
		out[n-1]:=(2*out[n-1]-x0)/(1-pole*pole);
		FOR k:=n-2 TO 0 BY -1 DO out[k]:=out[k]+out[k+1]*pole END;
	END;
END ConvolveMirror;

PROCEDURE ConvolvePeriodic*(CONST in: ARRAY [*] OF Datatype; VAR out: ARRAY [*] OF Datatype; CONST poles: ARRAY [*] OF Datatype; gain: Datatype);
(**	Discrete recursive convolution:
				signal has infinite, periodic support  LEN(in,0)
				for any x: signal[x]=signal[x MOD LEN(in,0)]
				kernel is given by its real poles
		Preconditions:
				input and output may use the same array*)
VAR i,j,k,n,k0:SIZE;
	x0,x1,pole:Datatype;
BEGIN
	ASSERT(LEN(poles,0)>0,100);
	ASSERT(LEN(in,0)<=LEN(out),101);
	n:=LEN(in,0);
	FOR k:=0 TO n-1 	DO out[k]:=in[k]*gain END;
	IF n=1 THEN RETURN END;
	FOR i:=0 TO LEN(poles,0)-1 DO
		pole:=poles[i];
		k:=ENTIER(tolerance/math.ln(ABS(pole))*OneDivLn10)+1;
		k0:=k-n*(k DIV n);
		x0:=out[n-1-k0];
		x1:=out[k0];
		FOR j:=k0-1 TO 0 BY -1 DO
			x0:=pole*x0+out[n-1-j];
			x1:=pole*x1+out[j]
		END;
		k:=k-k0;
		WHILE k>0 DO
			FOR j:=0 TO n-1 DO
				x0:=pole*x0+out[j];
				x1:=pole*x1+out[n-1-j];
			END;
			DEC(k,n);
		END;
		out[0]:=out[0]+pole*x0;
		x0:=out[n-1];
		x1:=pole*x1+x0;
		FOR j:=0 TO n-2 			DO out[j+1]:=out[j+1]+out[j]*pole END;
		out[n-1]:=(out[n-1]+x1-x0)/(1-pole*pole);
		FOR j:=n-2 TO 0 BY -1	DO out[j]:=out[j]+out[j+1]*pole END;
	END;
END ConvolvePeriodic;


END LinearIIRConvolveLongReal.

fofPC.Compile \s *
