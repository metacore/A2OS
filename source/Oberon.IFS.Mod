(* ETH Oberon, Copyright 2001 ETH Zuerich Institut fuer Computersysteme, ETH Zentrum, CH-8092 Zuerich.
Refer to the "General ETH Oberon System Source License" contract available at: http://www.oberon.ethz.ch/ *)

MODULE  IFS IN Oberon;	(** portable *)
(* Iterated Function System, page 92 *)
IMPORT  RandomNumbers, In, Out, XYplane;

VAR
	a1, b1, c1, d1, e1, f1, p1: FLOAT32;   (* IFS parameters *)
	a2, b2, c2, d2, e2, f2, p2: FLOAT32;   (* IFS parameters *)
	a3, b3, c3, d3, e3, f3, p3: FLOAT32;   (* IFS parameters *)
	a4, b4, c4, d4, e4, f4, p4: FLOAT32;   (* IFS parameters *)
	X, Y: FLOAT32;		(* the position of the pen *)
	x0: SIGNED16;	(* Distance of origin fm left edge[pixels] *)
	y0: SIGNED16;	(* Distance of origin from bottom edge[pixels] *)
	e: SIGNED16;	(* Size of unit interval [pixels] *)
	initialized: BOOLEAN;	(* Are parameters initialized? *)

PROCEDURE  Draw*;	(* command marked for export *)
VAR
	x, y: FLOAT32; 				(* new position *)
	xi, eta: SIGNED16;	   (* pixel coordinates of pen *)
	rn: FLOAT32;
BEGIN
IF initialized THEN
	REPEAT
		rn := RandomNumbers.Uniform();
		IF rn < p1 THEN
			x := a1 * X + b1 * Y + e1;	y := c1 * X + d1 * Y + f1
		ELSIF rn < (p1 + p2) THEN
			x := a2 * X + b2 * Y + e2;	y := c2 * X + d2 * Y + f2
		ELSIF rn < (p1 + p2 + p3) THEN
			x := a3 * X + b3 * Y + e3;	y := c3 * X + d3 * Y + f3
		ELSE
			x := a4 * X + b4 * Y + e4;	y := c4 * X + d4 * Y + f4
		END;
		X := x;  xi := x0 + SHORT(ENTIER(X*e));
		Y := y;  eta := y0 + SHORT(ENTIER(Y*e));
		XYplane.Dot(xi, eta, XYplane.draw)
	UNTIL  "s" = XYplane.Key()
END
END Draw;

PROCEDURE Init*;	(* command marked for export *)
BEGIN
	X := 0;   Y := 0;		(* Initial position of pen *)
	initialized := FALSE;
	In.Open;
	In.Int(x0);		In.Int(y0);		In.Int(e);
	In.Real(a1);	In.Real(a2); 	In.Real(a3);	In.Real(a4);
	In.Real(b1);	In.Real(b2);	In.Real(b3);	In.Real(b4);
	In.Real(c1);	In.Real(c2);	In.Real(c3);	In.Real(c4);
	In.Real(d1);	In.Real(d2);	In.Real(d3);	In.Real(d4);
	In.Real(e1);	In.Real(e2);	In.Real(e3);	In.Real(e4);
	In.Real(f1);	In.Real(f2);	In.Real(f3);	In.Real(f4);
	In.Real(p1);	In.Real(p2);	In.Real(p3);	In.Real(p4);
	IF In.Done THEN XYplane.Open;  initialized := TRUE
	ELSE Out.String("Parameter error"); Out.Ln
	END
END Init;

BEGIN  initialized := FALSE
END IFS.	(* Copyright M. Reiser, 1992 *)

IFS.Init 200 50 40
0.0 0.85 0.2 -0.15
0.0 0.04 -0.26 0.28
0.0 -0.04 0.23 0.26
0.16 0.85 0.22 0.24
0.0 0.0 0.0 0.0
0.0 1.6 1.6 0.44
0.01 0.85 0.07 0.07 ~

IFS.Draw