MODULE TestPlanarPDE;

(**
	PURPOSE "Tests partial differential equations for 2D"
	AUTHOR: "Patrick Hunziker; email patrick.hunziker@swissnano.org"
	DATE 2009-2-12
**)

IMPORT PlanarPDE, WMMatrix, Files, MatrixUtilities;

CONST TestFileName*="Matrix/PlanarPDE_ConstrainedLaplace.MtA";

TYPE
	Datatype = PlanarPDE.Datatype;
	Grid = PlanarPDE.Grid;

	PROCEDURE TestDiffusion*;
	CONST size = 200;
	VAR d,dm1, p: Grid;  i: SIGNED32;  c: Datatype;
		D,P:WMMatrix.Window;
		diffusion: PlanarPDE.Diffusion;
	BEGIN
		NEW( d, size, size );  d[90..109] := 1;  d[.. , 90..109] := 1;  NEW( p, size, size );
		NEW( diffusion );
		NEW( D, d, "d" );  D.AddWindow;
		NEW( P, p, "p" );  P.AddWindow;
		FOR i := 0 TO 100 DO
			diffusion.SolveMultigrid( d, p, 1, 1, 1, 0.1,16, 16, NIL );
			P.SetImage( p);
			d:=p; p:=0;
		END;
	END TestDiffusion;

	PROCEDURE TestLaplace*;
	CONST size = 200;  threshold = 1;
	VAR d: Grid;  laplace: PlanarPDE.Laplace;
	BEGIN
		NEW( d, size, size );  d[45..55] := 1;  d[.. , 45..55] := -1;
		NEW( laplace );  laplace.SolveMultigrid( d, threshold, 32, 20, 200, NIL );
		WMMatrix.AddWindow(d,"d");
	END TestLaplace;

	PROCEDURE TestConstrainedLaplace*;
	CONST size = 200;  threshold = 1;
	VAR d,c: Grid;  b: PlanarPDE.BooleanMap;
		con:PlanarPDE.Constraint;
		laplace: PlanarPDE.Laplace;
	BEGIN
		NEW( d, size, size );
		NEW( c, size, size); c[45..55] := 1;  c[.. , 45..55] := -1;   c[100.. , 145..155] := 1;
		NEW( b, size, size); b[45..55] := TRUE;  b[.. , 45..55] := TRUE;   b[100.. , 145..155] := TRUE;
		NEW(con); con.Set(c,b);
		NEW( laplace );  laplace.SolveMultigrid( d, threshold, 32, 20, 200, con.Constrain );
		WMMatrix.AddWindow(d,"d");
	END TestConstrainedLaplace;

	PROCEDURE StoreConstrainedLaplace*;
	CONST size = 64;  threshold = 1;
	VAR d,c: Grid;  b: PlanarPDE.BooleanMap;
		con:PlanarPDE.Constraint;
		laplace: PlanarPDE.Laplace;
		f:Files.File; w:Files.Writer;
	BEGIN
		NEW( d, size, size );
		NEW( c, size, size); c[20..30] := 1;  c[.. , 20..25] := -1;   c[32.. , 50..55] := 1;
		NEW( b, size, size); b[20..30] := TRUE;  b[.. , 20..25] := TRUE;   b[32.. , 50..55] := TRUE;
		NEW(con); con.Set(c,b);
		NEW( laplace );  laplace.SolveMultigrid( d, threshold, 32, 20, 200, con.Constrain );
		WMMatrix.AddWindow(d,"d");
		f:=Files.New(TestFileName); Files.OpenWriter(w,f,0); Files.Register(f);
		MatrixUtilities.StoreLR(w,d);
	END StoreConstrainedLaplace;
	
	PROCEDURE {TEST} Test*;
	CONST size = 64;  threshold = 1;
	VAR 
		e, d,c: Grid;  b: PlanarPDE.BooleanMap;
		con:PlanarPDE.Constraint;
		laplace: PlanarPDE.Laplace;
		f:Files.File; r:Files.Reader;
	BEGIN
		NEW( d, size, size );
		NEW( c, size, size); c[20..30] := 1;  c[.. , 20..25] := -1;   c[32.. , 50..55] := 1;
		NEW( b, size, size); b[20..30] := TRUE;  b[.. , 20..25] := TRUE;   b[32.. , 50..55] := TRUE;
		NEW(con); con.Set(c,b);
		NEW( laplace );  laplace.SolveMultigrid( d, threshold, 32, 20, 200, con.Constrain );
		f:=Files.Old(TestFileName);
		Files.OpenReader(r,f,0);
		e:=MatrixUtilities.LoadLR(r);
		ASSERT(d=e);
	END Test;
	

	PROCEDURE TestPoisson*;
	CONST size = 200;  threshold = 1;
	VAR d, p: Grid;  poisson: PlanarPDE.Poisson;
	BEGIN
		NEW( d, size, size );  d[45..55] := 1;  d[.. , 45..55] := 1;   NEW( p, size, size );
		NEW( poisson );  poisson.SolveMultigrid( d, p, 0.01, threshold, 20, 10, NIL );
		WMMatrix.AddWindow(d,"d");
		WMMatrix.AddWindow(p,"p");
	END TestPoisson;

	PROCEDURE TestWave*;
	CONST size = 128;
	VAR d,dm1, p: Grid;  i: SIGNED32;  c: Datatype;
		D,P:WMMatrix.Window;
		wave: PlanarPDE.Wave;
	BEGIN
		NEW( dm1, size, size );  dm1[..,15..18] := 1;  dm1[ 15..18] := 1;
		NEW( d, size, size );  d[..,17..20] := 1;  d[ 17..20] := 1;
		NEW( p, size, size);
		c := 1;

		NEW(wave);
		NEW( D, d, "d" );  D.AddWindow;
		NEW( P, p, "p" );  P.AddWindow;
		FOR i := 0 TO 200 DO
			wave.SolveMultigrid( dm1,d, p, c, 1,  1, 1, 16, 30, 10,  NIL );  (*dm1[@-1], d[@0] => p[@+1]*)
			P.SetImage( p);
			dm1:=d; d:=p;
		END;
	END TestWave;

END TestPlanarPDE.

System.Free TestPlanarPDE  PlanarPDE PlanarNabla PlanarBase ~

TestPlanarPDE.TestLaplace
TestPlanarPDE.ConstrainedLaplace
TestPlanarPDE.TestPoisson
TestPlanarPDE.TestDiffusion
TestPlanarPDE.TestWave

TestPlanarPDE.StoreConstrainedLaplace
TestPlanarPDE.Test

