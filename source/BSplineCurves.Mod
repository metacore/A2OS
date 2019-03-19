MODULE BSplineCurves;
(**
	AUTHOR "Alexey Morozov";
	PURPOSE "Parametric curves in B-Spline representation";

	This software is implemented on the base of the work
	M.Unser, "Splines: A Perfect Fit for Signal and Image Processing," IEEE Signal Processing Magazine, vol. 16, no. 6, pp. 22-38, November 1999
*)

IMPORT
	MathL, KernelLog;

CONST
	(* supported boundary conventions *)
	MirrorW = 0;
	Periodic = 1;

	Tolerance = 1.0D-9; (* default boundary handling tolerance *)

TYPE

	Buffer = OBJECT
	VAR x: ARRAY [*] OF LONGREAL;
		PROCEDURE &Init(len: LONGINT); BEGIN NEW(x,len); END Init;
		PROCEDURE Length(): LONGINT; BEGIN RETURN LEN(x,0); END Length;
	END Buffer;

	(*
		Direct B-Spline transform used for the transformation of data to the B-Spline domain
	*)
	DirectTransform = OBJECT
	VAR
		poles: ARRAY [*] OF LONGREAL;
		gain: LONGREAL;
		boundary: LONGINT;
		accelBuf: ARRAY [*] OF Buffer;

		(*
			Direct transform construction

			degree - B-Spline degree
			boundary - boundary handling convention
			tolerance - tolerance for handling the boundaries
		*)
		PROCEDURE &Init(degree, boundary: LONGINT; tolerance: LONGREAL);
		VAR
			i, j, n: LONGINT;
			p, v, w: LONGREAL;
			buf: Buffer;
		BEGIN
			GetDirectFilter(degree,poles,gain);

			(* prepare acceleration of the transform *)
			NEW(accelBuf,LEN(poles,0));
			v := MathL.ln(ABS(tolerance));

			FOR i := 0 TO LEN(poles,0)-1 DO

				p := poles[i];
				n := ENTIER(0.5D0 + (v / MathL.ln( ABS( p ) )) );

				NEW(buf,n); accelBuf[i] := buf; w := 1.0D0;
				FOR j := 0 TO n-1 DO buf.x[j] := w; w := w*p; END;
			END;

			SELF.boundary := boundary;
		END Init;

		PROCEDURE InitCausal(iPole: LONGINT; CONST s: ARRAY [*] OF LONGREAL): LONGREAL;
		VAR
			buf: Buffer;
			i: LONGINT;
			ic, z, zn, z2n, iz: LONGREAL;
		BEGIN

			CASE boundary OF

				|MirrorW:

					buf := accelBuf[iPole];

					IF buf.Length() < LEN(s,0) THEN (* acelerated computation *)

						ic := s[0..buf.Length()-1] +* buf.x;

					ELSE (* full loop *)

						z := poles[iPole];
						zn := z;  iz := 1.0D0 / z;

						z2n := IPower(ABS(z),LEN(s,0)-1);
						IF (z < 0) & ODD( LEN(s,0) - 1 ) THEN z2n := -z2n;  END;

						ic := s[0] + z2n * s[LEN(s,0) - 1];  z2n := z2n * z2n * iz;

						FOR i := 1 TO LEN(s,0) - 2 DO ic := ic + (zn + z2n) * s[i];  zn := zn * z;  z2n := z2n * iz;  END;
						ic := ic / (1.0D0 - zn * zn);
					END;

				|Periodic:

					buf := accelBuf[iPole];

					IF buf.Length() < LEN(s,0) THEN (* acelerated computation *)

						i := LEN(s,0)-buf.Length()+1;
						ic := s[0] + s[LEN(s,0)-1..i BY -1] +* buf.x[1..MAX];
						ic := ic / (1.0D0 - IPower(z,LEN(s,0)));

					ELSE (* full loop *)

						z := poles[iPole];

						zn := IPower(z,LEN(s,0) - 1);
						iz := 1.0D0 / z;

						ic := s[0];
						FOR i := 1 TO LEN(s,0)-1 DO
							ic := ic + zn * s[i];
							zn := zn * iz;
						END;

						ic := ic / (1.0D0 - IPower(z,LEN(s,0)));
					END;

			ELSE
				HALT(100);
			END;

			RETURN ic;
		END InitCausal;

		PROCEDURE InitAnticausal(iPole: LONGINT; CONST s: ARRAY [*] OF LONGREAL): LONGREAL;
		VAR
			buf: Buffer;
			i: LONGINT;
			ic, z, zn: LONGREAL;
		BEGIN

			CASE boundary OF

				|MirrorW:
					z := poles[iPole];
					ic := z * (s[LEN(s,0)-1] + z * s[LEN(s,0)-2]) / (z * z - 1);

				|Periodic:

					buf := accelBuf[iPole];
					z := poles[iPole];

					IF buf.Length() < LEN(s,0) THEN (* acelerated computation *)

						ic := s[0] + s[LEN(s,0)-1] / z;
						ic := ic + s[1..buf.Length()-1] +* buf.x[1..MAX];
						ic := ic * z * z / (IPower(z,LEN(s,0)) - 1.0D0);

					ELSE (* full loop *)

						ic := s[0] + s[LEN(s,0)-1] / z; zn := z;
						FOR i := 1 TO LEN(s,0)-2 DO
							ic := ic + zn * s[i]; zn := zn * z;
						END;
						ic := ic * z * z / (IPower(z,LEN(s,0)) - 1.0D0);

					END;

			END;

			RETURN ic;
		END InitAnticausal;

		(*
			Transform data to B-Spline domain

			s - input data array [N]
			c - output array of B-Spline coefficients [N]
		*)
		PROCEDURE Transform(CONST s: ARRAY [*] OF LONGREAL; VAR c: ARRAY [*] OF LONGREAL);
		VAR
			i, j: LONGINT;
			z: LONGREAL;
		BEGIN
			IF LEN(c,0) # LEN(s,0) THEN NEW(c,LEN(s,0)); END;

			c := s*gain;

			FOR i := 0 TO LEN(poles,0)-1 DO
				z := poles[i];
				c[0] := InitCausal(i,c);
				FOR j := 1 TO LEN(c,0) - 1 DO c[j] := c[j] + z*c[j-1];  END;
				c[LEN(c,0)-1] := InitAnticausal(i,c);
				FOR j := LEN(c,0)-2 TO 0 BY -1 DO c[j] := z*(c[j+1] - c[j]);  END;
			END;
		END Transform;

	END DirectTransform;

	(** A parametric B-Spline curve *)
	Curve* = OBJECT
	VAR
		degree-: LONGINT; (** B-Spline degree *)
		closed-: BOOLEAN; (** TRUE for closed curves *)
		kx-, ky-: ARRAY [*] OF LONGREAL; (** curve knots *)

		boundary: LONGINT;
		direct: DirectTransform;
		cx, cy: ARRAY [*] OF LONGREAL; (* B-Spline coefficieints for x(t) and y(t) corresponding to the knots *)
		dt: ARRAY [*] OF LONGREAL;

		(**
			Construct a B-Spline curve

			degree - B-Spline degree
			closed - TRUE for closed curve
		*)
		PROCEDURE &Init*(degree: LONGINT; closed: BOOLEAN);
		BEGIN
			IF closed THEN boundary := Periodic; ELSE boundary := MirrorW; END;

			IF degree > 1 THEN
				NEW(direct,degree,boundary,Tolerance);
			END;

			SELF.degree := degree;
			SELF.closed := closed;
		END Init;

		(**
			Set knots determining the curve

			knotsX, knotsY - x and y coordinates of the knots, in relative units
		*)
		PROCEDURE SetKnots*(CONST knotsX, knotsY: ARRAY [*] OF LONGREAL);
		BEGIN
			ASSERT(LEN(knotsX,0) = LEN(knotsY,0));

			IF degree >  1 THEN
				direct.Transform(knotsX,cx);
				direct.Transform(knotsY,cy);
			ELSE
				cx := knotsX;
				cy := knotsY;
			END;
			kx := knotsX;
			ky := knotsY;

			IF closed THEN
				IF LEN(dt,0) # LEN(kx,0) THEN NEW(dt,LEN(kx,0)); END;
			ELSE
				IF LEN(dt,0) # LEN(kx,0)-1 THEN NEW(dt,LEN(kx,0)-1); END;
			END;
		END SetKnots;

		(**
			Evaluate the points of the curve at a set of given parameter values

			t - input array of parameter values
			x, y - output point coordinates
		*)
		PROCEDURE Eval*(CONST t: ARRAY [*] OF LONGREAL; VAR x, y: ARRAY [*] OF LONGREAL);
		BEGIN
			IF LEN(x,0) # LEN(t,0) THEN NEW(x,LEN(t,0)); END;
			IF LEN(y,0) # LEN(t,0) THEN NEW(y,LEN(t,0)); END;
			Interpolate(degree,0,1,boundary,cx,t,x);
			Interpolate(degree,0,1,boundary,cy,t,y);
		END Eval;

		(**
			Get polyline used for rendering of the curve

			maxDist - maximal distance between the output polyline points, in relative units
			x, y - output set of points, in the same relative units
		*)
		PROCEDURE GetPoly*(maxDist: LONGREAL; VAR x, y: ARRAY [*] OF LONGREAL);
		VAR
			i, j, k, m, n: LONGINT;
			d1, d2, p, t: LONGREAL;
		BEGIN

			(*
				determine number of output points
			*)

			n := LEN(kx,0); (* account original knots *)
			FOR i := 0 TO LEN(kx,0)-2 DO

				(* distance between subsequent knots *)
				d1 := kx[i+1]-kx[i];
				d2 := ky[i+1]-ky[i];
				d1 := MathL.sqrt(d1*d1 + d2*d2);

				(* number of subintervals within the interval *)
				m := ENTIER(0.5D0 + (d1/ maxDist)) - 1;

				IF m > 1 THEN
					dt[i] := 1.0D0 / m;
					INC(n,m-1);
				ELSE
					dt[i] := 1.0D0;
				END;
			END;

			IF closed THEN (* additional interval for closed curves *)
				(* distance between last and first knots *)
				d1 := kx[0]-kx[LEN(kx,0)-1];
				d2 := ky[0]-ky[LEN(kx,0)-1];
				d1 := MathL.sqrt(d1*d1 + d2*d2);

				(* number of subintervals within the interval *)
				m := ENTIER(0.5D0 + (d1/ maxDist)) - 1;

				IF m > 1 THEN
					dt[LEN(dt,0)-1] := 1.0D0 / m;
					INC(n,m); (* add 1 for rendering the first knot to close the curve *)
				ELSE
					dt[LEN(dt,0)-1] := 1.0D0; INC(n);
				END;
			END;

			IF LEN(x,0) # n THEN NEW(x,n); END;
			IF LEN(y,0) # n THEN NEW(y,n); END;

			IF n > LEN(dt,0)+1 THEN

				j := 0;
				FOR i := 0 TO LEN(dt,0)-1 DO

					p := dt[i];
					m := ENTIER(0.5D0 + 1.0D0/p);

					t := i;
					FOR k := 0 TO m-1 DO
						y[j] := t; INC(j);
						t := t + p;
					END;
				END;

				ASSERT(j = n-1);

				y[j] := LEN(dt,0);

				Eval(y,x,y);
			ELSE

				x[0..LEN(kx,0)-1] := kx;
				y[0..LEN(ky,0)-1] := ky;

				IF closed THEN
					x[LEN(x,0)-1] := kx[0];
					y[LEN(y,0)-1] := ky[0];
				END;
			END;
		END GetPoly;

		(**
			Length of the curve, in relative units
		*)
		PROCEDURE Length*(): LONGREAL;
		BEGIN
			RETURN 0; (* not yet implemented *)
		END Length;

		(**
			Area occupied by the closed curve, in relative units
		*)
		PROCEDURE Area*(): LONGREAL;
		BEGIN
			RETURN 0; (* not yet implemented *)
		END Area;

	END Curve;

	(*
		Get pole-based representation of the symmetric IIR filter used for the direct transformation filtering

		degree - B-Spline degree

		poles - array of the filter poles
		gain - gain of the filter
	*)
	PROCEDURE GetDirectFilter(degree: LONGINT; VAR poles: ARRAY [*] OF LONGREAL; VAR gain: LONGREAL);
	VAR
		i: LONGINT;
	BEGIN
		CASE degree OF

			|2: NEW(poles,1); poles[0] := MathL.sqrt( 8.0D0 ) - 3.0D0;

			|3: NEW(poles,1);  poles[0] := MathL.sqrt( 3.0D0 ) - 2.0D0;

			|4:
				NEW(poles,2);
				poles[0] := MathL.sqrt(664.0D0 - MathL.sqrt(438976.0D0)) + MathL.sqrt(304.0D0) - 19.0D0;
				poles[1] := MathL.sqrt(664.0D0 + MathL.sqrt(438976.0D0)) - MathL.sqrt(304.0D0) - 19.0D0;

			|5:
				NEW(poles,2);
				poles[0] := MathL.sqrt(135.0D0 / 2.0D0 - MathL.sqrt(17745.0D0 / 4.0D0)) + MathL.sqrt(105.0D0 / 4.0D0)- 13.0D0 / 2.0D0;
                		poles[1] := MathL.sqrt(135.0D0 / 2.0D0 + MathL.sqrt(17745.0D0 / 4.0D0)) - MathL.sqrt(105.0D0 / 4.0D0)- 13.0D0 / 2.0D0;

			|6:
				NEW(poles,3);
				poles[0] := -0.48829458930304475513011803888378906211227916123938D0;
				poles[1] := -0.081679271076237512597937765737059080653379610398148D0;
				poles[2] := -0.0014141518083258177510872439765585925278641690553467D0;

			|7:
				NEW(poles,3);
				poles[0] := -0.53528043079643816554240378168164607183392315234269D0;
				poles[1] := -0.12255461519232669051527226435935734360548654942730D0;
				poles[2] := -0.0091486948096082769285930216516478534156925639545994D0;

			|8:
				NEW(poles,4);
				poles[0] := -0.57468690924876543053013930412874542429066157804125D0;
				poles[1] := -0.16303526929728093524055189686073705223476814550830D0;
				poles[2] := -0.023632294694844850023403919296361320612665920854629D0;
				poles[3] := -0.00015382131064169091173935253018402160762964054070043D0;

			|9:
				NEW(poles,4);
				poles[0] := -0.60799738916862577900772082395428976943963471853991D0;
				poles[1] := -0.20175052019315323879606468505597043468089886575747D0;
				poles[2] := -0.043222608540481752133321142979429688265852380231497D0;
				poles[3] := -0.0021213069031808184203048965578486234220548560988624D0;

			|10:
				NEW(poles,5);
				poles[0] := -0.63655066396942385875799205491349773313787959010128860432339D0;
				poles[1] := -0.238182798377573284887456162200161978666543494059728787251924D0;
				poles[2] := -0.065727033228308551538201803949684252205121694392255863103034D0;
				poles[3] := -0.0075281946755486906437698340318148831650567567441314086093636D0;
				poles[4] := -0.0000169827628232746642307274679399688786114400132341362095006930D0;

			|11:
				NEW(poles,5);
				poles[0] := -0.66126606890073470691013126292248166961816286716800880802421D0;
				poles[1] := -0.272180349294785885686295280258287768151235259565335176244192D0;
				poles[2] := -0.089759599793713309944142676556141542547561966017018544406214D0;
				poles[3] := -0.0166696273662346560965858360898150837154727205519335156053610D0;
				poles[4] := -0.00051055753444650205713591952840749392417989252534014106289610D0;
		ELSE

			(* kernels of any order can be constructed recursively:
				B-Spline Signal Processing: Part I - Theory by Michael Unser
			*)
			KernelLog.String("Unsupported B-spline degree!"); KernelLog.Ln;
			HALT(100);
		END;

		gain := 1.0D0;
		FOR i := 0 TO LEN(poles,0) - 1 DO gain := gain * (1.0D0 - poles[i]) * (1.0D0 - 1.0D0 / poles[i]);  END;
	END GetDirectFilter;

	(*
		B-Spline interpolation

		degree - B-Spline degree
		x0 - origin of the domain
		dx - step of the grid
		boundary - boundary handling convention
		c - array of B-Spline coefficients
		x - array of sample locations where to interpolate
		v - output array of interpolated values
	*)
	PROCEDURE Interpolate(degree: LONGINT; x0, dx: LONGREAL; boundary: LONGINT; CONST c: ARRAY [*] OF LONGREAL; CONST x: ARRAY [*] OF LONGREAL; VAR v: ARRAY [*] OF LONGREAL);
	VAR
		i, j, k, n: LONGINT;
		s, s2, s4, t, t0, t1, idx: LONGREAL;
		xx: LONGREAL;
		ind0: ARRAY 10 OF LONGINT;
		w0: ARRAY 10 OF LONGREAL;
	BEGIN

		idx := 1.0D0/dx;

		FOR k := 0 TO LEN(x,0)-1 DO

			xx := (x[k] - x0)*idx;

			IF ODD(degree) THEN j := ENTIER(xx) - (degree DIV 2);
			ELSE j := ENTIER(xx+0.5D0) - (degree DIV 2);
			END;

			FOR i := 0 TO degree DO ind0[i] := j+i; END;

			CASE degree OF
				|1:
					 s := xx - ind0[0];
		               	 w0[0] := 1.0D0-s;
		               	 w0[1] := s;
				|2:
					s := xx - ind0[1];
					w0[1] := 3.0D0 / 4.0D0 - s * s;
					w0[2] := (1.0D0 / 2.0D0) * (s - w0[1] + 1.0D0);
					w0[0] := 1.0D0 - w0[1] - w0[2];
				|3:
					s := xx - ind0[1];
					w0[3] := (1.0D0 / 6.0D0) * s * s * s;
					w0[0] := (1.0D0 / 6.0D0) + (1.0D0 / 2.0D0) * s * (s - 1.0D0) - w0[3];
					w0[2] := s + w0[0] - 2.0D0 * w0[3];
					w0[1] := 1.0D0 - w0[0] - w0[2] - w0[3];
				|4:
					s := xx - ind0[2];
	              		s2 := s * s;
	              		t := (1.0D0 / 6.0D0) * s2;
	                		w0[0] := 1.0D0 / 2.0D0 - s;
	                		w0[0] := w0[0] * w0[0];
	                		w0[0] := w0[0] * (1.0D0 / 24.0D0) * w0[0];
	                		t0 := s * (t - 11.0D0 / 24.0D0);
	                		t1 := 19.0D0 / 96.0D0 + s2 * (1.0D0 / 4.0D0 - t);
	                		w0[1] := t1 + t0;
	                		w0[3] := t1 - t0;
	                		w0[4] := w0[0] + t0 + (1.0D0 / 2.0D0) * s;
	                		w0[2] := 1.0D0 - w0[0] - w0[1] - w0[3] - w0[4];
	                	|5:
					s := xx - ind0[2];
					s2 := s * s;
	                		w0[5] := (1.0D0 / 120.0D0) * s * s2 * s2;
	                		s2 := s2 - s;
	                		s4 := s2 * s2;
	                		s := s - 1.0D0 / 2.0D0;
	                		t := s2 * (s2 - 3.0D0);
	                		w0[0] := (1.0D0 / 24.0D0) * (1.0D0 / 5.0D0 + s2 + s4) - w0[5];
	                		t0 := (1.0D0 / 24.0D0) * (s2 * (s2 - 5.0D0) + 46.0D0 / 5.0D0);
	                		t1 := (-1.0D0 / 12.0D0) * s * (t + 4.0D0);
	                		w0[2] := t0 + t1;
	                		w0[3] := t0 - t1;
	                		t0 := (1.0D0 / 16.0D0) * (9.0D0 / 5.0D0 - t);
	                		t1 := (1.0D0 / 24.0D0) * s * (s4 - s2 - 5.0D0);
	                		w0[1] := t0 + t1;
	                		w0[4] := t0 - t1;
				|6:
	                		s := xx - ind0[3];
	                		w0[0] := 1.0D0 / 2.0D0 - s;
	                		w0[0] := w0[0] * w0[0] * w0[0];
	                		w0[0] := w0[0] * w0[0] / 720.0D0;
	                		w0[1] := (361.0D0 / 192.0D0 - s * (59.0D0 / 8.0D0 + s * (-185.0D0 / 16.0D0 + s * (25.0D0 / 3.0D0 + s * (-5.0D0 / 2.0D0 + s) * (1.0D0 / 2.0D0 + s))))) / 120.0D0;
	                		w0[2] := (10543.0D0 / 960.0D0 + s * (-289.0D0 / 16.0D0 + s * (79.0D0 / 16.0D0 + s * (43.0D0 / 6.0D0 + s * (-17.0D0 / 4.0D0 + s * (-1.0D0 + s)))))) / 48.0D0;
	                		s2 := s * s;
	                		w0[3] := (5887.0D0 / 320.0D0 - s2 * (231.0D0 / 16.0D0 - s2 * (21.0D0 / 4.0D0 - s2))) / 36.0D0;
					w0[4] := (10543.0D0 / 960.0D0 + s * (289.0D0 / 16.0D0 + s * (79.0D0 / 16.0D0 + s * (-43.0D0 / 6.0D0 + s * (-17.0D0 / 4.0D0 + s * (1.0D0 + s)))))) / 48.0D0;
	                		w0[6] := 1.0D0 / 2.0D0 + s;
	                		w0[6] := w0[6] * w0[6] * w0[6];
	                		w0[6] := w0[6] * w0[6] / 720.0D0;
	                		w0[5] := 1.0D0 - w0[0] - w0[1] - w0[2] - w0[3] - w0[4] - w0[6];
				|7:
	                		s := xx - ind0[3];
	                		w0[0] := 1.0D0 - s;
	                		w0[0] := w0[0] * w0[0];
	                		w0[0] := w0[0] * w0[0] * w0[0];
	                		w0[0] := w0[0] * (1.0D0 - s) / 5040.0D0;
	                		s2 := s * s;
	                		w0[1] := (120.0D0 / 7.0D0 + s * (-56.0D0 + s * (72.0D0 + s * (-40.0D0 + s2 * (12.0D0 + s * (-6.0D0 + s)))))) / 720.0D0;
					w0[2] := (397.0D0 / 7.0D0 - s * (245.0D0 / 3.0D0 + s * (-15.0D0 + s * (-95.0D0 / 3.0D0 + s * (15.0D0 + s * (5.0D0 + s * (-5.0D0 + s))))))) / 240.0D0;
	                		w0[3] := (2416.0D0 / 35.0D0 + s2 * (-48.0D0 + s2 * (16.0D0 + s2 * (-4.0D0 + s)))) / 144.0D0;
					w0[4] := (1191.0D0 / 35.0D0 - s * (-49.0D0 + s * (-9.0D0 + s * (19.0D0 + s * (-3.0D0 + s) * (-3.0D0 + s2))))) / 144.0D0;
					w0[5] := (40.0D0 / 7.0D0 + s * (56.0D0 / 3.0D0 + s * (24.0D0 + s * (40.0D0 / 3.0D0 + s2 * (-4.0D0 + s * (-2.0D0 + s)))))) / 240.0D0;
					w0[7] := s2;
	                		w0[7] := w0[7] * w0[7] * w0[7];
	                		w0[7] := w0[7] * s / 5040.0D0;
	                		w0[6] := 1.0D0 - w0[0] - w0[1] - w0[2] - w0[3] - w0[4] - w0[5] - w0[7];
				|8:
	                		s := xx - ind0[4];
	                		w0[0] := 1.0D0 / 2.0D0 - s;
	                		w0[0] := w0[0] * w0[0];
	                		w0[0] := w0[0] * w0[0];
	                		w0[0] := w0[0] * w0[0] / 40320.0D0;
	                		s2 := s * s;
	                		w0[1] := (39.0D0 / 16.0D0 - s * (6.0D0 + s * (-9.0D0 / 2.0D0 + s2))) * (21.0D0 / 16.0D0 + s * (-15.0D0 / 4.0D0 + s * (9.0D0 / 2.0D0 + s * (-3.0D0 + s)))) / 5040.0D0;
	                		w0[2] := (82903.0D0 / 1792.0D0 + s * (-4177.0D0 / 32.0D0 + s * (2275.0D0 / 16.0D0 + s * (-487.0D0 / 8.0D0 + s * (-85.0D0 / 8.0D0 + s * (41.0D0 / 2.0D0 + s * (-5.0D0 + s * (-2.0D0 + s)))))))) / 1440.0D0;
	                		w0[3] := (310661.0D0 / 1792.0D0 - s * (14219.0D0 / 64.0D0 + s * (-199.0D0 / 8.0D0 + s * (-1327.0D0 / 16.0D0 + s * (245.0D0 / 8.0D0 + s * (53.0D0 / 4.0D0 + s * (-8.0D0 + s * (-1.0D0 + s)))))))) / 720.0D0;
	                		w0[4] := (2337507.0D0 / 8960.0D0 + s2 * (-2601.0D0 / 16.0D0 + s2 * (387.0D0 / 8.0D0 + s2 * (-9.0D0 + s2)))) / 576.0D0;
					w0[5] := (310661.0D0 / 1792.0D0 - s * (-14219.0D0 / 64.0D0 + s * (-199.0D0 / 8.0D0 + s * (1327.0D0 / 16.0D0 + s * (245.0D0 / 8.0D0 + s * (-53.0D0 / 4.0D0 + s * (-8.0D0 + s * (1.0D0 + s)))))))) / 720.0D0;
	                		w0[7] := (39.0D0 / 16.0D0 - s * (-6.0D0 + s * (-9.0D0 / 2.0D0 + s2))) * (21.0D0 / 16.0D0 + s * (15.0D0 / 4.0D0 + s * (9.0D0 / 2.0D0 + s * (3.0D0 + s)))) / 5040.0D0;
	                		w0[8] := 1.0D0 / 2.0D0 + s;
	                		w0[8] := w0[8] * w0[8];
	                		w0[8] := w0[8] * w0[8];
	                		w0[8] := w0[8] * w0[8] / 40320.0D0;
	                		w0[6] := 1.0D0 - w0[0] - w0[1] - w0[2] - w0[3] - w0[4] - w0[5] - w0[7] - w0[8];
				|9:
	                		s := xx - ind0[4];
	                		w0[0] := 1.0D0 - s;
	                		w0[0] := w0[0] * w0[0];
	                		w0[0] := w0[0] * w0[0];
	                		w0[0] := w0[0] * w0[0] * (1.0D0 - s) / 362880.0D0;
	                		w0[1] := (502.0D0 / 9.0D0 + s * (-246.0D0 + s * (472.0D0 + s * (-504.0D0 + s * (308.0D0 + s * (-84.0D0 + s * (-56.0D0 / 3.0D0 + s * (24.0D0 + s * (-8.0D0 + s))))))))) / 40320.0D0;
	                		w0[2] := (3652.0D0 / 9.0D0 - s * (2023.0D0 / 2.0D0 + s * (-952.0D0 + s * (938.0D0 / 3.0D0 + s * (112.0D0 + s * (-119.0D0 + s * (56.0D0 / 3.0D0 + s * (14.0D0 + s * (-7.0D0 + s))))))))) / 10080.0D0;
	                		w0[3] := (44117.0D0 / 42.0D0 + s * (-2427.0D0 / 2.0D0 + s * (66.0D0 + s * (434.0D0 + s * (-129.0D0 + s * (-69.0D0 + s * (34.0D0 + s * (6.0D0 + s * (-6.0D0 + s))))))))) / 4320.0D0;
	                		s2 := s * s;
	                		w0[4] := (78095.0D0 / 63.0D0 - s2 * (700.0D0 + s2 * (-190.0D0 + s2 * (100.0D0 / 3.0D0 + s2 * (-5.0D0 + s))))) / 2880.0D0;
					w0[5] := (44117.0D0 / 63.0D0 + s * (809.0D0 + s * (44.0D0 + s * (-868.0D0 / 3.0D0 + s * (-86.0D0 + s * (46.0D0 + s * (68.0D0 / 3.0D0 + s * (-4.0D0 + s * (-4.0D0 + s))))))))) / 2880.0D0;
	                		w0[6] := (3652.0D0 / 21.0D0 - s * (-867.0D0 / 2.0D0 + s * (-408.0D0 + s * (-134.0D0 + s * (48.0D0 + s * (51.0D0 + s * (-4.0D0 + s) * (-1.0D0 + s) * (2.0D0 + s))))))) / 4320.0D0;
	                		w0[7] := (251.0D0 / 18.0D0 + s * (123.0D0 / 2.0D0 + s * (118.0D0 + s * (126.0D0 + s * (77.0D0 + s * (21.0D0 + s * (-14.0D0 / 3.0D0 + s * (-6.0D0 + s * (-2.0D0 + s))))))))) / 10080.0D0;
	                		w0[9] := s2 * s2;
	                		w0[9] := w0[9] * w0[9] * s / 362880.0D0;
	                		w0[8] := 1.0D0 - w0[0] - w0[1] - w0[2] - w0[3] - w0[4] - w0[5] - w0[6] - w0[7] - w0[9];
			ELSE
				KernelLog.String("Unsupported B-spline degree!"); KernelLog.Ln;
	                	HALT(100);
			END;

			CASE boundary OF
				|MirrorW:
					n := 2*LEN(c,0)-2;
					FOR i := 0 TO degree DO
						IF (ind0[i] < 0) OR (ind0[i] >= LEN(c,0)) THEN
							ind0[i] := ABS(ind0[i]) MOD n;
							IF ind0[i] >= LEN(c,0) THEN ind0[i] := n - ind0[i]; END;
						END;
					END;

				|Periodic:
					n := LEN(c,0);
					FOR i := 0 TO degree DO
						IF ind0[i] < 0 THEN INC(ind0[i],((n - ind0[i] - 1) DIV n)*n);
						ELSIF ind0[i] >= n THEN ind0[i] := ind0[i] MOD n;
						END;
					END;
			ELSE
				HALT(100);
			END;

			s := 0;
			FOR i := 0 TO degree DO
				s := s + w0[i]*c[ind0[i]];
			END;

			v[k] := s;
		END;
	END Interpolate;

	(*
		Integer power: y := x^p
	*)
	PROCEDURE IPower(x: LONGREAL; p: LONGINT): LONGREAL;
	BEGIN
		IF x > 0 THEN
			RETURN MathL.exp(p*MathL.ln(x));
		ELSIF x # 0 THEN
			IF ODD(p) THEN
				RETURN -MathL.exp(p*MathL.ln(-x));
			ELSE
				RETURN MathL.exp(p*MathL.ln(-x));
			END;
		ELSE
			RETURN 0;
		END;
	END IPower;

END BSplineCurves.
