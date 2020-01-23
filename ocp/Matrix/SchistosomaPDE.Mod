MODULE SchistosomaPDE; (** AUTHOR ""; PURPOSE ""; *)

IMPORT PlanarPDE, WMMatrix, Stat:=StatisticsBase, Util:=MatrixUtilities;

CONST Size=256;

TYPE
	Grid = PlanarPDE.Grid;

	PROCEDURE TestConstrainedLaplace*;
	CONST threshold = 1;
	VAR
		con:PlanarPDE.Constraint;
		laplace: PlanarPDE.Laplace;
	BEGIN
		NEW(con); con.Set(c,b);
		NEW( laplace );  laplace.SolveMultigrid(map , threshold, 64, 1000, 10000, con.Constrain );
		Util.Mirror(map,0);
		WMMatrix.AddWindow(map,"map");
	END TestConstrainedLaplace;

	PROCEDURE TestConstrainedDiffusion*;
	VAR p: Grid;  i: SIGNED32;
		P:WMMatrix.Window;
		diffusion: PlanarPDE.Diffusion;
		con:PlanarPDE.Constraint;

	BEGIN
		NEW( p, Size, Size );
		NEW( diffusion );
		NEW( P, p, "p" );  P.AddWindow;

		NEW(con); con.Set(c,b);
		FOR i := 0 TO 10000 DO
			diffusion.SolveMultigrid( map, p, 10, 1, 1, 0.1,16, 100, con.Constrain );
			P.SetImage( p);
			map:=p; p:=0;
		END;
	END TestConstrainedDiffusion;

VAR data, map, c: Grid; b: PlanarPDE.BooleanMap; x,y,i:SIGNED32;
BEGIN
	(*lat, long, prevalence, elevation:*)
	data :=[ [1.567166677, 1.571662648, 1.536716668, 1.431950001, 1.419500001, 1.475500001, 1.409933334, 1.443366668, 1.315866667, 1.351633334, 1.377216667, 1.354500001, 1.433033334, 1.488450001, 1.396966667, 1.710716668, 1.768133335, 1.761216668, 3.367933334, 3.274416667, 3.276183334, 3.391666667, 3.540416668, 3.570833334, 2.106866667, 2.026033333, 2.02125, 2.177316667, 2.156683334, 2.11195, 1.9575, 1.957778, 1.973611, 1.989444, 2.026667, 2.176111, 2.129167, 2.13, 1.315855556, 1.314832323, 1.339933334, 1.309436754, 1.307547833, 1.386538313, 1.403345452, 1.363333404, 1.355336374, 1.5319, 1.5663889, 1.4025, 2.0422222, 1.942631, 1.5755556, 1.5563889, 1.5588889, 1.3966667, 1.4061111, 1.3533333, 1.3547222, 1.3511111],
			[30.26445343, 30.24121233, 30.25223333, 30.04445, 30.02263333, 30.01616667, 29.81956667, 29.7815, 29.74196667, 29.49541667, 29.44081667, 29.09091667, 30.48371667, 30.49715, 30.44486667, 30.14366667, 30.25488333, 30.2545, 30.45208333, 30.57285, 30.64221667, 30.71346667, 30.6523, 30.76171667, 30.76985, 30.89655, 30.91696667, 30.92841667, 30.95811667, 30.96561667, 31.00278, 30.99417, 31.00556, 31.02194, 31.04889, 31.2725, 31.22417, 31.23556, 29.74, 29.79, 29.80556667, 29.7134624, 29.70836592, 29.66674635, 29.68123954, 29.63491555, 29.54149667, 30.258272, 30.278889, 30.4425, 31.049167, 30.970162, 30.245, 30.25222, 30.250556, 27.601944, 27.6, 29.083611, 29.095556, 29.075278],
			[12.0, 41.7, 42.7, 52.3, 47.7, 45.1, 35.1, 59.7, 52.3, 41.2, 44.7, 67.2, 68.9, 78.4, 74.5, 11.5, 6.5, 9.8, 6.4, 10.2, 0.0, 2.0, 10.5, 0.0, 0.0, 24.0, 4.4, 4.0, 12.8, 6.4, 75.6, 68.8, 72.7, 64.3, 66.7, 90.2, 72.1, 78.6, 52.3, 58.1, 46.2, 44.8, 61.5, 38.9, 54.2, 66.7, 48.3, 46.1, 47.9, 68.8, 60.0, 85.7, 65.1, 63.0, 42.1, 24.1, 51.0, 94.2, 87.5, 78.6],
			[1350, 1250, 1290, 1070, 1090, 1030, 930, 880, 890, 855, 915, 900, 625, 625, 615, 1355, 1320, 1320, 1105, 1170, 1165, 1170, 1190, 1195, 1920, 2080, 2090, 1805, 1870, 1905, 610, 690, 840, 930, 945, 605, 625, 610, 890, 880, 885, 880, 880, 875, 870, 860, 860, 1300, 1350, 640, 950, 615, 1250, 1270, 1260, 560, 550, 900, 910, 890]];

	data[0,..]:=data[0,..]-MIN(data[0,..]);
	data[0,..]:=data[0,..]/MAX(data[0,..]);

	data[1,..]:=data[1,..]-MIN(data[1,..]);
	data[1,..]:=data[1,..]/MAX(data[1,..]);

	NEW(map, Size, Size); map:=Stat.Mean(data[2,..]); (*initialize with eduated guess of solution*)
	NEW(b, Size, Size);
	NEW(c, Size, Size);
	(*c:=Stat.Mean(data[2,..]);*)
	FOR i:=0 TO LEN(data,1)-1 DO
		y:=ENTIER(16+(Size-32) * data[0,i]);
		x:=ENTIER(16+(Size-32) * data[1,i]);
		c[y..y+2,x..x+2]:=data[2,i];
		b[y..y+2,x..x+2]:=TRUE;
	END;

END SchistosomaPDE.

SchistosomaPDE.TestConstrainedLaplace ~
SchistosomaPDE.TestConstrainedDiffusion ~