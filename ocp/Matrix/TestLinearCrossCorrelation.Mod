MODULE TestLinearCrossCorrelation; (** AUTHOR "Patrick Hunziker"; PURPOSE ""; *)

IMPORT LinearFFT, LinearWindowFunction, MathL, WMSimpleGraphs, Random;

TYPE Datatype=FLOAT64;

PROCEDURE Do*;
VAR d:ARRAY [*,*] OF Datatype;
	w: ARRAY [*] OF Datatype;
	i:SIGNED32;
	graphs:WMSimpleGraphs.Graphs; r:Datatype;
BEGIN
	NEW(d,7, 256);
	FOR i:=0 TO LEN(d,1)-1 DO
		r:=rand.Uniform();
		d[0,i]:= MathL.sin(i/50-0.3)+r;
		d[1,(i-5) MOD LEN(d,1)]:= MathL.sin(i/50 -0.3)+r;
	END;
	NEW(w, LEN(d,1));
	w:=LinearWindowFunction.SplineWindow(d[0,*],3 );
	d[4,*]:=w;
	d[5,*]:=d[0,*];
	d[6,*]:=d[1,*];
	d[0,*]:=d[0,*] .* w;
	d[1,*]:=d[1,*] .* w;

	LinearFFT.CrossCorrelation(d[0,*], d[1,*], d[2,*], d[3,*]);
	d[2..3]:=5*d[2..3]/LEN(d,1); (* scaling is abitrary, for nicer display *)
	NEW(graphs, d, "");
END Do;
VAR rand:Random.Generator;
BEGIN
	NEW(rand);
END TestLinearCrossCorrelation.

TestLinearCrossCorrelation.Do ~
System.Free TestLinearCrossCorrelation
System.FreeDownTo WMSimpleGraphs ~
