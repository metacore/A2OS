 (**	Oberon Version: (c) P.Hunziker, July 2002, the 2D Version is based on the C-Program of Ph.Thevenaz from EPFL Lausanne mentioned below *)


(******************************************************************************
 *	Date: January 29, 2002
 *----------------------------------------------------------------------------
 *	This C program is based on the following three papers:
 *		[1]	M. Unser,
 *			"Splines: A Perfect Fit for Signal and Image Processing,"
 *			IEEE Signal Processing Magazine, vol. 16, no. 6, pp. 22-38,
 *			November 1999.
 *		[2]	M. Unser, A. Aldroubi and M. Eden,
 *			"B-Spline Signal Processing: Part I--Theory,"
 *			IEEE Transactions on Signal Processing, vol. 41, no. 2, pp. 821-832,
 *			February 1993.
 *		[3]	M. Unser, A. Aldroubi and M. Eden,
 *			"B-Spline Signal Processing: Part II--Efficient Design and Applications,"
 *			IEEE Transactions on Signal Processing, vol. 41, no. 2, pp. 834-848,
 *			February 1993.
 *----------------------------------------------------------------------------
 *	EPFL/STI/IOA/BIG
 *	Philippe Thevenaz
 *	Bldg. BM-Ecublens 4.137
 *	CH-1015 Lausanne
 *----------------------------------------------------------------------------
 *	phone (CET):	+41(21)693.51.61
 *	fax:			+41(21)693.37.01
 *	RFC-822:		philippe.thevenaz@epfl.ch
 *	X-400:			/C=ch/A=400net/P=switch/O=epfl/S=thevenaz/G=philippe/
 *	URL:			http://bigwww.epfl.ch/
 *===================================================
*)

MODULE MatrixInterpolation;

IMPORT  MatrixBase, Commands, Out;   (*Imports only needed for Test Procedure*)

TYPE
	Datatype = MatrixBase.Datatype;
	Vector = MatrixBase.Vector;
	Matrix = MatrixBase.Matrix;
	Volume = ARRAY [*,*,*] OF Datatype;
	Hypercube = ARRAY [ *,*,*,* ] OF Datatype;
	Tensor = ARRAY [?] OF Datatype;

	(*! is there a problem with degree 4,5 interpolation ?*)
	(**Interpolate signal: convert the original, sampled signal into continous spline model of 'SplineDegree' (1..5).
	Then, use procedure InterpolateSpline to get interpolated value at position x; respectively at position x,y	*)
	PROCEDURE InterpolateSpline*	( CONST Bcoeff: Vector (*	float*   *) ;   (* input B-spline array of coefficients *)
																x: Datatype;   (* x coordinate where to interpolate *)
																SplineDegree: SIGNED32 (* degree of the spline model *)
																): Datatype;
	VAR xWeight: ARRAY 6 OF Datatype;
		xIndex: ARRAY 6 OF SIZE;
		interpolated, w, w2, w4, t, t0, t1, val: Datatype;  Width, Width2: SIZE;  i, j, k: SIGNED32;
	BEGIN
		ASSERT ( (SplineDegree >= 0) & (SplineDegree < 6), 101 );
		(* compute the interpolation indexes *)
		Width := LEN( Bcoeff,0 );  Width2 := 2 * Width - 2;
		IF SplineDegree = 1 THEN RETURN Bcoeff[ENTIER(x)]; (*! ?? *)
		ELSIF SplineDegree = 1 THEN RETURN linear1D( Bcoeff, x );  (*! ?? *)
		END;
		IF ODD( SplineDegree ) THEN
			i := ENTIER( x ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO xIndex[k] := i;  INC( i );  END;
		ELSE
			i := ENTIER( x + 0.5 ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO xIndex[k] := i;  INC( i );  END
		END;

		(* compute the interpolation weights *)
		CASE SplineDegree OF
		| 2:
				(* x *)
				w := x - xIndex[1];
				xWeight[1] := 3 / 4 - w * w;
				xWeight[2] := (1 / 2) * (w - xWeight[1] + 1);
				xWeight[0] := 1 - xWeight[1] - xWeight[2];
		| 3:
				(* x *)
				w := x - xIndex[1];
				xWeight[3] := (1 / 6) * w * w * w;
				xWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - xWeight[3];
				xWeight[2] := w + xWeight[0] - 2 * xWeight[3];
				xWeight[1] := 1 - xWeight[0] - xWeight[2] - xWeight[3];
		| 4:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  t := (1 / 6) * w2;  xWeight[0] := 1 / 2 - w;
				xWeight[0] := xWeight[0] * xWeight[0];
				xWeight[0] := xWeight[0] * (1 / 24) * xWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				xWeight[1] := t1 + t0;  xWeight[3] := t1 - t0;
				xWeight[4] := xWeight[0] + t0 + (1 / 2) * w;
				xWeight[2] :=
					1 - xWeight[0] - xWeight[1] - xWeight[3] - xWeight[4];
		| 5:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  xWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2;  t := w2 * (w2 - 3);
				xWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - xWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				xWeight[2] := t0 + t1;  xWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				xWeight[1] := t0 + t1;  xWeight[4] := t0 - t1;
		ELSE  (*should not happen*)
			RETURN (0);
		END;

		(* apply the mirror boundary conditions *)
		FOR k := 0 TO SplineDegree DO
			IF (Width = 1) THEN xIndex[k] := 0
			ELSIF xIndex[k] < 0 THEN
				xIndex[k] := -xIndex[k] - Width2 * ((-xIndex[k]) DIV Width2)
			ELSE xIndex[k] := xIndex[k] - Width2 * (xIndex[k] DIV Width2)
			END;
			IF (Width <= xIndex[k]) THEN xIndex[k] := Width2 - xIndex[k];  END;
		END;

		(* perform interpolation *)
		interpolated := 0.0;  w := 0;
		FOR i := 0 TO SplineDegree DO
		(*Bcoeff.get(val,xIndex[i]);*)
			val := Bcoeff[xIndex[i]];  w := w + xWeight[i] * val;
		END;
		interpolated := w;  RETURN (interpolated);
	END InterpolateSpline;

(** to do InterpolateSplineN for two dimensional regular displacement by [dx,dy]*)

PROCEDURE InterpolateSplineN*	( CONST Bcoeff: Vector (*	float*   *) ;   (* input B-spline array of coefficients *)
																VAR res: Vector;(*	result is in the signal domain, not a spline   *)
																x: Datatype;   (* first x coordinate where to interpolate *)
																SplineDegree: SIGNED32 (* degree of the spline model *)
																);  (*this appears to be mirrorW boundaries, while the DirectBSpline Transform is mirrorH boundaries -> debug !*)
	VAR xWeight: ARRAY 6 OF Datatype;
		xIndex, xIndex2: ARRAY [6] OF SIZE;
		interpolated, w, w2, w4, t, t0, t1, val, dx: Datatype;  Width, Width2, l, maxx: SIZE;  i, j, k, x0, len: SIGNED32;
	BEGIN
		ASSERT ( (SplineDegree >= 0) & (SplineDegree < 6), 101 );
		(* compute the interpolation indexes *)
		Width := LEN( Bcoeff,0 );  Width2 := 2 * Width - 2;
		x0:=ENTIER(x);
		dx:=x-x0;
		IF SplineDegree = 0 THEN
			res [0..LEN(res,0)-x0-1]:=Bcoeff[x0..];
			RETURN ;
			ELSIF SplineDegree = 1 THEN
			maxx:=MIN(LEN(Bcoeff,0)-2, x0+LEN(res,0)-1);
			res [0..maxx-x0]:= (1-dx)*Bcoeff[x0..maxx] + dx*Bcoeff[x0+1..maxx+1];
			RETURN ;
		END;
		IF ODD( SplineDegree ) THEN
			i :=  - (SplineDegree DIV 2);(*?? precedence of minus operator has changed - inside or outside brackets ??*)
			FOR k := 0 TO SplineDegree DO xIndex[k] := i;  INC( i );  END;
		ELSE
			i := ENTIER( dx + 0.5 ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO xIndex[k] := i;  INC( i );  END
		END;

		(* compute the interpolation weights *)
		CASE SplineDegree OF
		| 2:
				(* x *)
				w := dx-xIndex[1];
				xWeight[1] := 3 / 4 - w * w;
				xWeight[2] := (1 / 2) * (w - xWeight[1] + 1);
				xWeight[0] := 1 - xWeight[1] - xWeight[2];
		| 3:
				(* x *)
				w := dx-xIndex[1];
				xWeight[3] := (1 / 6) * w * w * w;
				xWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - xWeight[3];
				xWeight[2] := w + xWeight[0] - 2 * xWeight[3];
				xWeight[1] := 1 - xWeight[0] - xWeight[2] - xWeight[3];
		| 4:
				(* x *)
				w := dx-xIndex[2];
				w2 := w * w;  t := (1 / 6) * w2;  xWeight[0] := 1 / 2 - w;
				xWeight[0] := xWeight[0] * xWeight[0];
				xWeight[0] := xWeight[0] * (1 / 24) * xWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				xWeight[1] := t1 + t0;  xWeight[3] := t1 - t0;
				xWeight[4] := xWeight[0] + t0 + (1 / 2) * w;
				xWeight[2] := 1 - xWeight[0] - xWeight[1] - xWeight[3] - xWeight[4];
		| 5:
				(* x *)
				w := dx-xIndex[2];
				w2 := w * w;  xWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2;  t := w2 * (w2 - 3);
				xWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - xWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				xWeight[2] := t0 + t1;  xWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				xWeight[1] := t0 + t1;  xWeight[4] := t0 - t1;
		END;

		FOR l:=MAX(x0,0) TO MIN( x0+LEN(res,0), LEN(Bcoeff,0))-1 DO	(* To Do: export this to MatrixFilters.Mod, as an "interpolation filter" *)

			xIndex2:=xIndex+l;
			(* apply the mirrorW boundary conditions *)
			FOR k := 0 TO SplineDegree DO
				IF (Width = 1) THEN xIndex2[k] := 0
				ELSIF xIndex2[k] < 0 THEN
					xIndex2[k] := -xIndex2[k] - Width2 * ((-xIndex2[k]) DIV Width2)
				ELSIF xIndex2[k] >= Width2 THEN
							xIndex2[k] := xIndex2[k] - Width2 * (xIndex2[k] DIV Width2)
				(*ELSE xIndex2[k] := xIndex2[k] - Width2 * (xIndex2[k] DIV Width2) *)
				END;
				IF (Width <= xIndex2[k]) THEN xIndex2[k] := Width2 - xIndex2[k];  END;
			END;

			(* perform interpolation *)
			w := 0;
			FOR i := 0 TO SplineDegree DO
				val := Bcoeff[xIndex2[i]];  w := w + xWeight[i] * val;
			END;
			res[l-x0] := w;
		END;
	END InterpolateSplineN;


	PROCEDURE InterpolateSpline2D*
	( CONST Bcoeff: Matrix (*	float*   *) ;   (* input B-spline array of coefficients *)
	x, y: Datatype;   (* x coordinate where to interpolate *)  (* y coordinate where to interpolate *)
	SplineDegree: SIGNED32 (* degree of the spline model *)
	): Datatype;
	VAR xWeight, yWeight: ARRAY 6 OF Datatype;
		xIndex, yIndex: ARRAY 6 OF SIZE;
		interpolated, w, w2, w4, t, t0, t1, val: Datatype;
		Width, Height, Width2, Height2: SIZE;  i, j, k: SIGNED32;
	BEGIN
		ASSERT ( (SplineDegree > 0) & (SplineDegree < 6), 101 );
		(* compute the interpolation indexes *)
		Width := LEN( Bcoeff, 1 );  Height := LEN( Bcoeff, 0 );  Width2 := 2 * Width - 2;
		Height2 := 2 * Height - 2;
		IF SplineDegree = 1 THEN RETURN linear2D( Bcoeff, x, y );  END;
		IF ODD( SplineDegree ) THEN
			i := ENTIER( x ) - SplineDegree DIV 2;  j := ENTIER( y ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO xIndex[k] := i;  INC( i );  yIndex[k] := j;  INC( j );  END;
		ELSE
			i := ENTIER( x + 0.5 ) - SplineDegree DIV 2;
			j := ENTIER( y + 0.5 ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO xIndex[k] := i;  INC( i );  yIndex[k] := j;  INC( j );  END
		END;

		(* compute the interpolation weights *)
		CASE SplineDegree OF
		| 2:
				(* x *)
				w := x - xIndex[1];
				xWeight[1] := 3 / 4 - w * w;
				xWeight[2] := (1 / 2) * (w - xWeight[1] + 1);
				xWeight[0] := 1 - xWeight[1] - xWeight[2];
				(* y *)
				w := y - yIndex[1];  yWeight[1] := 3 / 4 - w * w;
				yWeight[2] := (1 / 2) * (w - yWeight[1] + 1);
				yWeight[0] := 1 - yWeight[1] - yWeight[2];
		| 3:
				(* x *)
				w := x - xIndex[1];
				xWeight[3] := (1 / 6) * w * w * w;
				xWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - xWeight[3];
				xWeight[2] := w + xWeight[0] - 2 * xWeight[3];
				xWeight[1] := 1 - xWeight[0] - xWeight[2] - xWeight[3];
				(* y *)
				w := y - yIndex[1];  yWeight[3] := (1 / 6) * w * w * w;
				yWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - yWeight[3];
				yWeight[2] := w + yWeight[0] - 2 * yWeight[3];
				yWeight[1] := 1 - yWeight[0] - yWeight[2] - yWeight[3];
		| 4:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  t := (1 / 6) * w2;  xWeight[0] := 1 / 2 - w;
				xWeight[0] := xWeight[0] * xWeight[0];
				xWeight[0] := xWeight[0] * (1 / 24) * xWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				xWeight[1] := t1 + t0;  xWeight[3] := t1 - t0;
				xWeight[4] := xWeight[0] + t0 + (1 / 2) * w;
				xWeight[2] :=
					1 - xWeight[0] - xWeight[1] - xWeight[3] - xWeight[4];
				(* y *)
				w := y - yIndex[2];  w2 := w * w;  t := (1 / 6) * w2;
				yWeight[0] := 1 / 2 - w;  yWeight[0] := yWeight[0] * yWeight[0];
				yWeight[0] := yWeight[0] * (1 / 24) * yWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				yWeight[1] := t1 + t0;  yWeight[3] := t1 - t0;
				yWeight[4] := yWeight[0] + t0 + (1 / 2) * w;
				yWeight[2] := 1 - yWeight[0] - yWeight[1] - yWeight[3] - yWeight[4];
		| 5:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  xWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2;  t := w2 * (w2 - 3);
				xWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - xWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				xWeight[2] := t0 + t1;  xWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				xWeight[1] := t0 + t1;  xWeight[4] := t0 - t1;
				(* y *)
				w := y - yIndex[2];  w2 := w * w;
				yWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2.0;  t := w2 * (w2 - 3);
				yWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - yWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				yWeight[2] := t0 + t1;  yWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				yWeight[1] := t0 + t1;  yWeight[4] := t0 - t1;
		ELSE  (*should not happen*)
			RETURN (0);
		END;

		(* apply the mirror boundary conditions *)
		FOR k := 0 TO SplineDegree DO
			IF (Width = 1) THEN xIndex[k] := 0
			ELSIF xIndex[k] < 0 THEN
				xIndex[k] := -xIndex[k] - Width2 * ((-xIndex[k]) DIV Width2)
			ELSE xIndex[k] := xIndex[k] - Width2 * (xIndex[k] DIV Width2)
			END;
			(*xIndex[k] := (Width == 1L) ? (0) : ((xIndex[k] < 0) ?
			(-xIndex[k] - Width2 * ((-xIndex[k]) / Width2))
			: (xIndex[k] - Width2 * (xIndex[k] / Width2)));*)
			IF (Width <= xIndex[k]) THEN xIndex[k] := Width2 - xIndex[k];  END;
			IF (Height = 1) THEN yIndex[k] := 0
			ELSIF yIndex[k] < 0 THEN
				yIndex[k] := -yIndex[k] - Height2 * ((-yIndex[k]) DIV Height2)
			ELSE yIndex[k] := yIndex[k] - Height2 * (yIndex[k] DIV Height2)
			END;
			(*yIndex[k] := (Height == 1L) ? (0) : ((yIndex[k] < 0) ?
			(-yIndex[k] - Height2 * ((-yIndex[k]) / Height2))
			: (yIndex[k] - Height2 * (yIndex[k] / Height2)));*)
			IF (Height <= yIndex[k]) THEN yIndex[k] := Height2 - yIndex[k];  END
		END;

		(* perform interpolation *)
		interpolated := 0.0;
		FOR j := 0 TO SplineDegree DO
			w := 0;
			FOR i := 0 TO SplineDegree DO
			(*Bcoeff.get(val,xIndex[i],yIndex[j]);*)
				val := Bcoeff[yIndex[j], xIndex[i]];  w := w + xWeight[i] * val;
			END;
			interpolated := interpolated + yWeight[j] * w;
		END;

		RETURN (interpolated);
	END InterpolateSpline2D;

	PROCEDURE linear1D( CONST data: Vector;  x: Datatype ): Datatype;
	VAR dx, xM, res: Datatype;  i: SIGNED32;  lenX: SIZE;  X, X1: Datatype;
	BEGIN
		lenX := LEN( data, 0 );
		IF (x < 0) OR (x > lenX - 1) THEN RETURN 0 END;
		i := ENTIER( x );  x := x - i;  xM := 1 - x;  X := data[i MOD lenX];
		X1 := data[(i + 1) MOD lenX];  RETURN X * xM + X1 * x;
	END linear1D;

	PROCEDURE linear2D( CONST data: Matrix;  x, y: Datatype ): Datatype;
	VAR dx, dy, xM, yM, res: Datatype;  i, j, k: SIGNED32; lenX, lenY: SIZE;
		XY, X1Y, XY1, X1Y1: Datatype;
	BEGIN
		lenX := LEN( data, 1 );  lenY := LEN( data, 0 );
		IF (x < 0) OR (x > lenX - 1) THEN RETURN 0 END;
		i := ENTIER( x );  j := ENTIER( y );  x := x - i;  y := y - j;  xM := 1 - x;  yM := 1 - y;
		XY := data[j MOD lenY, i MOD lenX];
		X1Y := data[j MOD lenY, (i + 1) MOD lenX];
		XY1 := data[(j + 1) MOD lenY, i MOD lenX];
		X1Y1 := data[(j + 1) MOD lenY, (i + 1) MOD lenX];
		RETURN XY * xM * yM + X1Y * x * yM + XY1 * xM * y + X1Y1 * x * y;
	END linear2D;

	PROCEDURE linear3D( CONST data: Volume;  x, y, z: Datatype ): Datatype;
	VAR dx, dy, dz, xM, yM, zM, res: Datatype;  i, j, k: SIGNED32;  lenX, lenY, lenZ: SIZE;
		XYZ, X1YZ, XY1Z, XYZ1, X1Y1Z, X1YZ1, XY1Z1, X1Y1Z1: Datatype;
	BEGIN
		lenX := LEN( data, 2 );  lenY := LEN( data, 1 );  lenZ := LEN( data, 0 );
		IF (x < 0) OR (x > lenX - 1) THEN RETURN 0 END;
		i := ENTIER( x );  j := ENTIER( y );  k := ENTIER( z );  x := x - i;  y := y - j;  z := z - k;  xM := 1 - x;
		yM := 1 - y;  zM := 1 - z;
		XYZ := data[k MOD lenZ, j MOD lenY, i MOD lenX];
		X1YZ := data[k MOD lenZ, j MOD lenY, (i + 1) MOD lenX];
		XY1Z := data[k MOD lenZ, (j + 1) MOD lenY, i MOD lenX];
		XYZ1 := data[(k + 1) MOD lenZ, j MOD lenY, i MOD lenX];
		X1Y1Z := data[k MOD lenZ, (j + 1) MOD lenY, (i + 1) MOD lenX];
		X1YZ1 := data[(k + 1) MOD lenZ, j MOD lenY, (i + 1) MOD lenX];
		XY1Z1 := data[(k + 1) MOD lenZ, (j + 1) MOD lenY, i MOD lenX];
		X1Y1Z1 := data[(k + 1) MOD lenZ, (j + 1) MOD lenY, (i + 1) MOD lenX];
		RETURN XYZ * xM * yM * zM + X1YZ * x * yM * zM + XY1Z * xM * y * zM +
					    XYZ1 * xM * yM * z + X1Y1Z * x * y * zM + XY1Z1 * xM * y * z +
					    X1YZ1 * x * yM * z + X1Y1Z1 * x * y * z;
	END linear3D;

	PROCEDURE linear4D( CONST data: Hypercube;
										    x, y, z, t: Datatype ): Datatype;
	VAR dx, dy, dz, dt, xM, yM, zM, tM, res: Datatype;
		i, j, k, l: SIGNED32; lenX, lenY, lenZ, lenT: SIZE;
		XYZT, X1YZT, XY1ZT, XYZ1T, XYZT1, X1Y1ZT, X1YZ1T, X1YZT1, XY1Z1T, XY1ZT1, XYZ1T1, X1Y1Z1T, X1Y1ZT1, X1YZ1T1, XY1Z1T1, X1Y1Z1T1: Datatype;

	BEGIN
		lenX := LEN( data, 3 );  lenY := LEN( data, 2 );  lenZ := LEN( data, 1 );  lenT := LEN( data, 0 );
		IF (x < 0) OR (x > lenZ - 1) THEN RETURN 0 END;
		i := ENTIER( x );  j := ENTIER( y );  k := ENTIER( z );  l := ENTIER( t );  x := x - i;  y := y - j;  z := z - k;
		t := t - l;  xM := 1 - x;  yM := 1 - y;  zM := 1 - z;  tM := 1 - t;

		XYZT := data[l MOD lenT, k MOD lenZ, j MOD lenY, i MOD lenX];

		X1YZT := data[l MOD lenT, k MOD lenZ, j MOD lenY, (i + 1) MOD lenX];
		XY1ZT := data[l MOD lenT, k MOD lenZ, (j + 1) MOD lenY, i MOD lenX];
		XYZ1T := data[l MOD lenT, (k + 1) MOD lenZ, j MOD lenY, i MOD lenX];
		XYZT1 := data[(l + 1) MOD lenT, k MOD lenZ, j MOD lenY, i MOD lenX];

		X1Y1ZT := data[l MOD lenT, k MOD lenZ, (j + 1) MOD lenY, (i + 1) MOD lenX];
		X1YZ1T := data[l MOD lenT, (k + 1) MOD lenZ, j MOD lenY, (i + 1) MOD lenX];
		X1YZT1 := data[(l + 1) MOD lenT, k MOD lenZ, j MOD lenY, (i + 1) MOD lenX];
		XY1Z1T := data[l MOD lenT, (k + 1) MOD lenZ, (j + 1) MOD lenY, i MOD lenX];
		XY1ZT1 := data[(l + 1) MOD lenT, k MOD lenZ, (j + 1) MOD lenY, i MOD lenX];
		XYZ1T1 := data[(l + 1) MOD lenT, (k + 1) MOD lenZ, j MOD lenY, i MOD lenX];

		X1Y1Z1T := data[l MOD lenT, (k + 1) MOD lenZ, (j + 1) MOD lenY, (i + 1) MOD lenX];
		X1Y1ZT1 := data[(l + 1) MOD lenT, k MOD lenZ, (j + 1) MOD lenY, (i + 1) MOD lenX];
		X1YZ1T1 := data[(l + 1) MOD lenT, (k + 1) MOD lenZ, j MOD lenY, (i + 1) MOD lenX];
		XY1Z1T1 := data[(l + 1) MOD lenT, (k + 1) MOD lenZ, (j + 1) MOD lenY, i MOD lenX];

		X1Y1Z1T1 := data[(l + 1) MOD lenT, (k + 1) MOD lenZ, (j + 1) MOD lenY, (i + 1) MOD lenX];

		RETURN XYZT * xM * yM * zM * tM + X1YZT * x * yM * zM * tM +
					    XY1ZT * xM * y * zM * tM + XYZ1T * xM * yM * z * tM +
					    XYZT1 * xM * yM * zM * t + X1Y1ZT * x * y * zM * tM +
					    X1YZ1T * x * yM * z * tM + X1YZT1 * x * yM * zM * t +
					    XY1Z1T * xM * y * z * tM + XY1ZT1 * xM * y * zM * t +
					    XYZ1T1 * xM * yM * z * t + X1Y1Z1T * x * y * z * tM +
					    X1Y1ZT1 * x * y * zM * t + X1YZ1T1 * x * yM * z * t +
					    XY1Z1T1 * xM * y * z * t + X1Y1Z1T1 * x * y * z * t;
	END linear4D;

	PROCEDURE InterpolateSplineTensor*( CONST Bcoeff: Tensor (*	float*   *) ;   (* input B-spline array of coefficients *)
	CONST x: Vector;   (* x coordinate where to interpolate *)  (* y coordinate where to interpolate *)
	SplineDegree: SIGNED32 (* degree of the spline model; currently implemented: degrees 2-5 *)
	): Datatype;
	BEGIN
		IF (DIM(Bcoeff)=LEN(x,0)) & (LEN(x)=3) THEN
			RETURN InterpolateSpline3D(Bcoeff, x[0], x[1], x[2], SplineDegree)
		ELSE HALT(200); (*implementation limitation*)
		END;
	END InterpolateSplineTensor;


	PROCEDURE InterpolateSpline3D*
	( CONST Bcoeff: Volume (*	float*   *) ;   (* input B-spline array of coefficients *)
	x, y, z: Datatype;   (* x coordinate where to interpolate *)  (* y coordinate where to interpolate *)
	SplineDegree: SIGNED32 (* degree of the spline model; currently implemented: degrees 2-5 *)
	): Datatype;

	VAR xWeight, yWeight, zWeight: ARRAY 6 OF Datatype;
		xIndex, yIndex, zIndex: ARRAY 6 OF SIZE;
		interpolated, w, w2, w4, t, t0, t1, u, v: Datatype;
		Width, Height, Depth, Width2, Height2, Depth2: SIZE;  i, j, k, l: SIGNED32;
	BEGIN
		ASSERT ( (SplineDegree >= 0) & (SplineDegree < 6), 101 );
		Width := LEN( Bcoeff, 2 );  Height := LEN( Bcoeff, 1 );  Depth := LEN( Bcoeff, 0 );
		Width2 := 2 * Width - 2;  Height2 := 2 * Height - 2;
		Depth2 := 2 * Depth - 2;

		IF SplineDegree = 1 THEN RETURN linear3D( Bcoeff, x, y, z )
		ELSIF SplineDegree = 0 THEN
			IF (x < 0) OR (x > Width - 1) OR (y < 0) OR (y > Height - 1) OR (z < 0) OR
				 (z > Depth - 1) THEN
				RETURN 0
			ELSE u := Bcoeff[ENTIER( x ), ENTIER( y ), ENTIER( x )];  RETURN u
			END;
		END;

		(* compute the interpolation indexes *)
		(*Width:=Bcoeff.lenX; Height:=Bcoeff.lenY;Depth:=Bcoeff.lenZ;*)
		IF ODD( SplineDegree ) THEN
			i := ENTIER( x ) - SplineDegree DIV 2;
			j := ENTIER( y ) - SplineDegree DIV 2;
			l := ENTIER( z ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO
				xIndex[k] := i;  INC( i );  yIndex[k] := j;  INC( j );  zIndex[k] := l;  INC( l );
			END;
		ELSE
			i := ENTIER( x + 0.5 ) - SplineDegree DIV 2;
			j := ENTIER( y + 0.5 ) - SplineDegree DIV 2;
			l := ENTIER( z + 0.5 ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO
				xIndex[k] := i;  INC( i );  yIndex[k] := j;  INC( j );  zIndex[k] := l;  INC( l );
			END
		END;

		(* compute the interpolation weights *)
		CASE SplineDegree OF
		| 2:
				(* x *)
				w := x - xIndex[1];
				xWeight[1] := 3 / 4 - w * w;
				xWeight[2] := (1 / 2) * (w - xWeight[1] + 1);
				xWeight[0] := 1 - xWeight[1] - xWeight[2];
				(* y *)
				w := y - yIndex[1];  yWeight[1] := 3 / 4 - w * w;
				yWeight[2] := (1 / 2) * (w - yWeight[1] + 1);
				yWeight[0] := 1 - yWeight[1] - yWeight[2];
				(* z *)
				w := z - zIndex[1];  zWeight[1] := 3 / 4 - w * w;
				zWeight[2] := (1 / 2) * (w - zWeight[1] + 1);
				zWeight[0] := 1 - zWeight[1] - zWeight[2];
		| 3:
				(* x *)
				w := x - xIndex[1];
				xWeight[3] := (1 / 6) * w * w * w;
				xWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - xWeight[3];
				xWeight[2] := w + xWeight[0] - 2 * xWeight[3];
				xWeight[1] := 1 - xWeight[0] - xWeight[2] - xWeight[3];
				(* y *)
				w := y - yIndex[1];  yWeight[3] := (1 / 6) * w * w * w;
				yWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - yWeight[3];
				yWeight[2] := w + yWeight[0] - 2 * yWeight[3];
				yWeight[1] := 1 - yWeight[0] - yWeight[2] - yWeight[3];
				(* z *)
				w := z - zIndex[1];  zWeight[3] := (1 / 6) * w * w * w;
				zWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - zWeight[3];
				zWeight[2] := w + zWeight[0] - 2 * zWeight[3];
				zWeight[1] := 1 - zWeight[0] - zWeight[2] - zWeight[3];
		| 4:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  t := (1 / 6) * w2;  xWeight[0] := 1 / 2 - w;
				xWeight[0] := xWeight[0] * xWeight[0];
				xWeight[0] := xWeight[0] * (1 / 24) * xWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				xWeight[1] := t1 + t0;  xWeight[3] := t1 - t0;
				xWeight[4] := xWeight[0] + t0 + (1 / 2) * w;
				xWeight[2] :=
					1 - xWeight[0] - xWeight[1] - xWeight[3] - xWeight[4];
				(* y *)
				w := y - yIndex[2];  w2 := w * w;  t := (1 / 6) * w2;
				yWeight[0] := 1 / 2 - w;  yWeight[0] := yWeight[0] * yWeight[0];
				yWeight[0] := yWeight[0] * (1 / 24) * yWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				yWeight[1] := t1 + t0;  yWeight[3] := t1 - t0;
				yWeight[4] := yWeight[0] + t0 + (1 / 2) * w;
				yWeight[2] := 1 - yWeight[0] - yWeight[1] - yWeight[3] - yWeight[4];
				(* z *)
				w := z - zIndex[2];  w2 := w * w;  t := (1 / 6) * w2;
				zWeight[0] := 1 / 2 - w;  zWeight[0] := zWeight[0] * zWeight[0];
				zWeight[0] := zWeight[0] * (1 / 24) * zWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				zWeight[1] := t1 + t0;  zWeight[3] := t1 - t0;
				zWeight[4] := zWeight[0] + t0 + (1 / 2) * w;
				zWeight[2] := 1 - zWeight[0] - zWeight[1] - zWeight[3] - zWeight[4];
		| 5:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  xWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2;  t := w2 * (w2 - 3);
				xWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - xWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				xWeight[2] := t0 + t1;  xWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				xWeight[1] := t0 + t1;  xWeight[4] := t0 - t1;
				(* y *)
				w := y - yIndex[2];  w2 := w * w;
				yWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2.0;  t := w2 * (w2 - 3);
				yWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - yWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				yWeight[2] := t0 + t1;  yWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				yWeight[1] := t0 + t1;  yWeight[4] := t0 - t1;
				(* z *)
				w := z - zIndex[2];  w2 := w * w;
				zWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2.0;  t := w2 * (w2 - 3);
				zWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - zWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				zWeight[2] := t0 + t1;  zWeight[3] := t0 - t1;  t0 := (1 / 16) * (9 / 5 - t);
				t1 := (1 / 24) * w * (w4 - w2 - 5);  zWeight[1] := t0 + t1;
				zWeight[4] := t0 - t1;
		ELSE  (*should not happen*)
			RETURN (0);
		END;

		(* apply the mirror boundary conditions *)
		FOR k := 0 TO SplineDegree DO
		(*x*)
			IF (Width = 1) THEN xIndex[k] := 0
			ELSIF xIndex[k] < 0 THEN
				xIndex[k] := -xIndex[k] - Width2 * ((-xIndex[k]) DIV Width2)
			ELSE xIndex[k] := xIndex[k] - Width2 * (xIndex[k] DIV Width2)
			END;
			IF (Width <= xIndex[k]) THEN xIndex[k] := Width2 - xIndex[k];  END;
			(*y*)
			IF (Height = 1) THEN yIndex[k] := 0
			ELSIF yIndex[k] < 0 THEN
				yIndex[k] := -yIndex[k] - Height2 * ((-yIndex[k]) DIV Height2)
			ELSE yIndex[k] := yIndex[k] - Height2 * (yIndex[k] DIV Height2)
			END;
			IF (Height <= yIndex[k]) THEN yIndex[k] := Height2 - yIndex[k];  END;
			(*z*)
			IF (Depth = 1) THEN zIndex[k] := 0
			ELSIF zIndex[k] < 0 THEN
				zIndex[k] := -zIndex[k] - Depth2 * ((-zIndex[k]) DIV Depth2)
			ELSE zIndex[k] := zIndex[k] - Depth2 * (zIndex[k] DIV Depth2)
			END;
			IF (Depth <= zIndex[k]) THEN zIndex[k] := Depth2 - zIndex[k];  END;
		END;

		(* perform interpolation *)
		interpolated := 0.0;
		FOR l := 0 TO SplineDegree DO
			v := 0;
			FOR j := 0 TO SplineDegree DO
				w := 0;
				FOR i := 0 TO SplineDegree DO
				(*Bcoeff.get(u,xIndex[i],yIndex[j],zIndex[l]);*)
					u := Bcoeff[zIndex[l], yIndex[j], xIndex[i]];
					w := w + xWeight[i] * u;   (*inlining needs too many registers on Intel...*)
				END;
				v := v + yWeight[j] * w;
			END;
			interpolated := interpolated + zWeight[l] * v;
		END;

		RETURN (interpolated);
	END InterpolateSpline3D;

	PROCEDURE InterpolateSpline4D*( CONST Bcoeff: Hypercube (*	float*   *) ;   (* input B-spline array of coefficients *)
																			x, y, z, tm: Datatype;   (* coordinates, where to interpolate *)
																			SplineDegree: SIGNED32 (* degree of the spline model; currently implemented: degrees 0-5 *)
																			): Datatype;

	VAR xWeight, yWeight, zWeight, tWeight: ARRAY 6 OF Datatype;
		xIndex, yIndex, zIndex, tIndex: ARRAY 6 OF SIZE;
		interpolated, w, w2, w4, t, t0, t1, u, v, r: Datatype;
		Width, Height, Depth, Time, Width2, Height2, Depth2, Time2: SIZE;  i, j, k, l, m: SIGNED32;

	BEGIN
		ASSERT ( (SplineDegree >= 0) & (SplineDegree < 6), 101 );
		Width := LEN( Bcoeff, 3 );  Height := LEN( Bcoeff, 2 );  Depth := LEN( Bcoeff, 1 );
		Time := LEN( Bcoeff, 0 );  Width2 := 2 * Width - 2;  Height2 := 2 * Height - 2;
		Depth2 := 2 * Depth - 2;  Time2 := 2 * Time - 2;

		IF SplineDegree = 1 THEN RETURN linear4D( Bcoeff, x, y, z, tm );
		ELSIF SplineDegree = 0 THEN
			IF (x < 0) OR (x > Width - 1) OR (y < 0) OR (y > Height - 1) OR (z < 0) OR
				 (z > Depth - 1) OR (tm < 0) OR (tm > Time - 1) THEN
				RETURN 0;
			ELSE
				(*Bcoeff.get(u,ENTIER(x),ENTIER(y),ENTIER(z), ENTIER(t)); *)
				u := Bcoeff[ENTIER( t ), ENTIER( z ), ENTIER( y ), ENTIER( x )];  RETURN u;
			END;
		END;

		(* compute the interpolation indexes *)
		(*Width:=Bcoeff.lenX; Height:=Bcoeff.lenY;Depth:=Bcoeff.lenZ; Time:=Bcoeff.lenT;*)


		IF ODD( SplineDegree ) THEN
			i := ENTIER( x ) - SplineDegree DIV 2;  j := ENTIER( y ) - SplineDegree DIV 2;
			l := ENTIER( z ) - SplineDegree DIV 2;  m := ENTIER( tm ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO
				xIndex[k] := i;  INC( i );  yIndex[k] := j;  INC( j );  zIndex[k] := l;  INC( l );
				tIndex[k] := m;  INC( m );
			END;
		ELSE
			i := ENTIER( x + 0.5 ) - SplineDegree DIV 2;
			j := ENTIER( y + 0.5 ) - SplineDegree DIV 2;  l := ENTIER( z + 0.5 ) - SplineDegree DIV 2;
			m := ENTIER( tm + 0.5 ) - SplineDegree DIV 2;
			FOR k := 0 TO SplineDegree DO
				xIndex[k] := i;  INC( i );  yIndex[k] := j;  INC( j );  zIndex[k] := l;  INC( l );
				tIndex[k] := m;  INC( m );
			END
		END;

		(* compute the interpolation weights *)
		CASE SplineDegree OF
		| 2:
				(* x *)
				w := x - xIndex[1];
				xWeight[1] := 3 / 4 - w * w;
				xWeight[2] := (1 / 2) * (w - xWeight[1] + 1);
				xWeight[0] := 1 - xWeight[1] - xWeight[2];
				(* y *)
				w := y - yIndex[1];  yWeight[1] := 3 / 4 - w * w;
				yWeight[2] := (1 / 2) * (w - yWeight[1] + 1);
				yWeight[0] := 1 - yWeight[1] - yWeight[2];
				(* z *)
				w := z - zIndex[1];  zWeight[1] := 3 / 4 - w * w;
				zWeight[2] := (1 / 2) * (w - zWeight[1] + 1);
				zWeight[0] := 1 - zWeight[1] - zWeight[2];
				(* t *)
				w := tm - tIndex[1];  tWeight[1] := 3 / 4 - w * w;
				tWeight[2] := (1 / 2) * (w - tWeight[1] + 1);
				tWeight[0] := 1 - tWeight[1] - tWeight[2];
		| 3:
				(* x *)
				w := x - xIndex[1];
				xWeight[3] := (1 / 6) * w * w * w;
				xWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - xWeight[3];
				xWeight[2] := w + xWeight[0] - 2 * xWeight[3];
				xWeight[1] := 1 - xWeight[0] - xWeight[2] - xWeight[3];
				(* y *)
				w := y - yIndex[1];  yWeight[3] := (1 / 6) * w * w * w;
				yWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - yWeight[3];
				yWeight[2] := w + yWeight[0] - 2 * yWeight[3];
				yWeight[1] := 1 - yWeight[0] - yWeight[2] - yWeight[3];
				(* z *)
				w := z - zIndex[1];  zWeight[3] := (1 / 6) * w * w * w;
				zWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - zWeight[3];
				zWeight[2] := w + zWeight[0] - 2 * zWeight[3];
				zWeight[1] := 1 - zWeight[0] - zWeight[2] - zWeight[3];
				(* t *)
				w := tm - tIndex[1];  tWeight[3] := (1 / 6) * w * w * w;
				tWeight[0] := (1 / 6) + (1 / 2) * w * (w - 1) - tWeight[3];
				tWeight[2] := w + tWeight[0] - 2 * tWeight[3];
				tWeight[1] := 1 - tWeight[0] - tWeight[2] - tWeight[3];
		| 4:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  t := (1 / 6) * w2;  xWeight[0] := 1 / 2 - w;
				xWeight[0] := xWeight[0] * xWeight[0];
				xWeight[0] := xWeight[0] * (1 / 24) * xWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				xWeight[1] := t1 + t0;  xWeight[3] := t1 - t0;
				xWeight[4] := xWeight[0] + t0 + (1 / 2) * w;
				xWeight[2] :=
					1 - xWeight[0] - xWeight[1] - xWeight[3] - xWeight[4];
				(* y *)
				w := y - yIndex[2];  w2 := w * w;  t := (1 / 6) * w2;
				yWeight[0] := 1 / 2 - w;  yWeight[0] := yWeight[0] * yWeight[0];
				yWeight[0] := yWeight[0] * (1 / 24) * yWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				yWeight[1] := t1 + t0;  yWeight[3] := t1 - t0;
				yWeight[4] := yWeight[0] + t0 + (1 / 2) * w;
				yWeight[2] := 1 - yWeight[0] - yWeight[1] - yWeight[3] - yWeight[4];
				(* z *)
				w := z - zIndex[2];  w2 := w * w;  t := (1 / 6) * w2;
				zWeight[0] := 1 / 2 - w;  zWeight[0] := zWeight[0] * zWeight[0];
				zWeight[0] := zWeight[0] * (1 / 24) * zWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				zWeight[1] := t1 + t0;  zWeight[3] := t1 - t0;
				zWeight[4] := zWeight[0] + t0 + (1 / 2) * w;
				zWeight[2] := 1 - zWeight[0] - zWeight[1] - zWeight[3] - zWeight[4];
				(* t *)
				w := tm - tIndex[2];  w2 := w * w;  t := (1 / 6) * w2;
				tWeight[0] := 1 / 2 - w;  tWeight[0] := tWeight[0] * tWeight[0];
				tWeight[0] := tWeight[0] * (1 / 24) * tWeight[0];
				t0 := w * (t - 11 / 24);  t1 := 19 / 96 + w2 * (1 / 4 - t);
				tWeight[1] := t1 + t0;  tWeight[3] := t1 - t0;
				tWeight[4] := tWeight[0] + t0 + (1 / 2) * w;
				tWeight[2] := 1 - tWeight[0] - tWeight[1] - tWeight[3] - tWeight[4];
		| 5:
				(* x *)
				w := x - xIndex[2];
				w2 := w * w;  xWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2;  t := w2 * (w2 - 3);
				xWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - xWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				xWeight[2] := t0 + t1;  xWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				xWeight[1] := t0 + t1;  xWeight[4] := t0 - t1;
				(* y *)
				w := y - yIndex[2];  w2 := w * w;
				yWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2.0;  t := w2 * (w2 - 3);
				yWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - yWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				yWeight[2] := t0 + t1;  yWeight[3] := t0 - t1;
				t0 := (1 / 16) * (9 / 5 - t);  t1 := (1 / 24) * w * (w4 - w2 - 5);
				yWeight[1] := t0 + t1;  yWeight[4] := t0 - t1;
				(* z *)
				w := z - zIndex[2];  w2 := w * w;
				zWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2.0;  t := w2 * (w2 - 3);
				zWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - zWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				zWeight[2] := t0 + t1;  zWeight[3] := t0 - t1;  t0 := (1 / 16) * (9 / 5 - t);
				t1 := (1 / 24) * w * (w4 - w2 - 5);  zWeight[1] := t0 + t1;
				zWeight[4] := t0 - t1;
				(* t *)
				w := tm - tIndex[2];  w2 := w * w;
				tWeight[5] := (1 / 120) * w * w2 * w2;  w2 := w2 - w;
				w4 := w2 * w2;  w := w - 1 / 2.0;  t := w2 * (w2 - 3);
				tWeight[0] := (1 / 24) * (1 / 5 + w2 + w4) - tWeight[5];
				t0 := (1 / 24) * (w2 * (w2 - 5) + 46 / 5);  t1 := (-1 / 12) * w * (t + 4);
				tWeight[2] := t0 + t1;  tWeight[3] := t0 - t1;  t0 := (1 / 16) * (9 / 5 - t);
				t1 := (1 / 24) * w * (w4 - w2 - 5);  tWeight[1] := t0 + t1;
				tWeight[4] := t0 - t1;
		ELSE  (*should not happen*)
			RETURN (0);
		END;

		(* apply the mirror boundary conditions *)
		FOR k := 0 TO SplineDegree DO
		(*x*)
			IF (Width = 1) THEN xIndex[k] := 0
			ELSIF xIndex[k] < 0 THEN
				xIndex[k] := -xIndex[k] - Width2 * ((-xIndex[k]) DIV Width2)
			ELSE xIndex[k] := xIndex[k] - Width2 * (xIndex[k] DIV Width2)
			END;
			IF (Width <= xIndex[k]) THEN xIndex[k] := Width2 - xIndex[k];  END;
			(*y*)
			IF (Height = 1) THEN yIndex[k] := 0
			ELSIF yIndex[k] < 0 THEN
				yIndex[k] := -yIndex[k] - Height2 * ((-yIndex[k]) DIV Height2)
			ELSE yIndex[k] := yIndex[k] - Height2 * (yIndex[k] DIV Height2)
			END;
			IF (Height <= yIndex[k]) THEN yIndex[k] := Height2 - yIndex[k];  END;
			(*z*)
			IF (Depth = 1) THEN zIndex[k] := 0;
			ELSIF zIndex[k] < 0 THEN
				zIndex[k] := -zIndex[k] - Depth2 * ((-zIndex[k]) DIV Depth2);
			ELSE zIndex[k] := zIndex[k] - Depth2 * (zIndex[k] DIV Depth2);
			END;
			IF (Depth <= zIndex[k]) THEN zIndex[k] := Depth2 - zIndex[k];  END;
			(*t*)
			IF (Time = 1) THEN tIndex[k] := 0;
			ELSIF tIndex[k] < 0 THEN
				tIndex[k] := -tIndex[k] - Time2 * ((-tIndex[k]) DIV Time2);
			ELSE tIndex[k] := tIndex[k] - Time2 * (tIndex[k] DIV Time2);
			END;
			IF (Time <= tIndex[k]) THEN tIndex[k] := Time2 - tIndex[k];  END;
		END;

		(* perform interpolation *) (* possible optimisation: take out boundaries and do inner product*)
		interpolated := 0.0;
		FOR m := 0 TO SplineDegree DO
			r := 0;
			FOR l := 0 TO SplineDegree DO
				v := 0;
				FOR j := 0 TO SplineDegree DO
					w := 0;
					FOR i := 0 TO SplineDegree DO
					(*Bcoeff.get(u,xIndex[i],yIndex[j],zIndex[l], tIndex[m]);*)
						u := Bcoeff[tIndex[m], zIndex[l], yIndex[j], xIndex[i]];
						w := w + xWeight[i] * u;   (*inlining needs too many registers on Intel...*)
					END;
					v := v + yWeight[j] * w;
				END;
				r := r + zWeight[l] * v;
			END;
			interpolated := interpolated + tWeight[m] * r;
		END;

		RETURN (interpolated);

	 END InterpolateSpline4D;

	PROCEDURE {TEST} Test*;
	VAR data: Vector; i: INTEGER; 
	CONST degree = 3;
		PROCEDURE Rnd(x:REAL):INTEGER;
		BEGIN RETURN ENTIER(1000*x+0.5) 
		END Rnd;
	BEGIN
		NEW( data, 10 );
		FOR i := 0 TO 9 DO
			IF ODD( i ) THEN data[i] := -1.0 ELSE data[i] := 1.0 END;
		END;
		ASSERT( (Rnd(InterpolateSpline(data,0.0,degree ))=333) &  (Rnd(InterpolateSpline( data,0.1,degree ))=315) &  (Rnd(InterpolateSpline( data, 0.5, degree ))=0.0) & (Rnd(InterpolateSpline( data, 0.8, degree ))=-264), 200); 
	END Test;
(*
	PROCEDURE Test2*(context:Commands.Context);
	VAR data: Vector;  x, y, z: REAL;  i, n: INTEGER;  v: Datatype;
	CONST degree = 3;
	BEGIN
		IF context.arg.GetReal( x ) &  context.arg.GetInteger( n, FALSE ) THEN
			NEW( data, n );
			FOR i := 0 TO n - 1 DO
				data[i] := 1 (*i*) ;
				IF ODD( i ) THEN data[i] := -data[i] END;
			END;
		END;
		context.out.String( ' interpolation at ' );  context.out.FloatFix( x, 12, 3, 0 );  context.out.String( ' =' );
		context.out.FloatFix( InterpolateSpline( data, x, degree ), 12, 3, 0 );  context.out.Ln; context.out.Update;
	END Test2;


	PROCEDURE Test3*(context:Commands.Context);
	VAR data, res: Vector;  x, y, z: REAL;  i, n,m, degree: SIGNED32;  v: Datatype;
	BEGIN
		IF context.arg.GetInteger(degree, FALSE) & context.arg.GetInteger( n, FALSE ) & context.arg.GetInteger( m, FALSE ) & context.arg.GetReal(x) THEN
			NEW( data, n ); NEW(res,m);
			FOR i := 0 TO n DIV 3 - 1 DO
				data[i] := i MOD 4;
				context.out.FloatFix(data[i],12,3,0);
			END;
			Out.Ln;
			InterpolateSplineN(data, res, x, degree);
			Out.String( ' interpolation ' );  Out.Ln;
			FOR i:=0 TO m-1 DO
				context.out.FloatFix( res[i], 12, 3, 0 );
			END;
			Out.Ln;
		END;
	END Test3;
*)
END MatrixInterpolation.


MatrixInterpolation.Test~ 1.5 1.2 1	1	100000
MatrixInterpolation.Test4D 1.5 1.2 1.0 0.0	1	100000

MatrixInterpolation.Test2 -0.2 100
MatrixInterpolation.Test2 -0.1 100
MatrixInterpolation.Test2 0.0 100
MatrixInterpolation.Test2 0.1 100
MatrixInterpolation.Test2 0.2 100
MatrixInterpolation.Test2 0.5 100
MatrixInterpolation.Test2 0.8 100
MatrixInterpolation.Test2 0.9 100
MatrixInterpolation.Test2 1.0 100
MatrixInterpolation.Test2 1.5 100
MatrixInterpolation.Test2 2.0 100


MatrixInterpolation.Test3 2 256 256 3.6~

System.Free DSPWarp MatrixInterpolation ~

fofPC.Compile \s *

fofPC.Compile \f *

