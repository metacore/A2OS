(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE CalcGauss;   (** AUTHOR "adf"; PURPOSE "Accurate computation of an integral"; *)

(* To change to 64-bit reals, go to the module body and select the appropriate constants commented in light red. *)

(**  Gauss-Kronrod integrators that solve to a specified error tolerance achieved by automatic subdivision.  *)

IMPORT NbrInt, NbrRe, NbrCplx, Data, DataLists, CalcFn;

CONST
	(** Admissible parameters to pass that select the 'integrator'.
				Coarse  should only be selected for smooth integrands.
				Medium  should be used as the default.
				Fine  should be selected for oscillating integrands. *)
	Coarse* = 99;  Medium* = 100;  Fine* = 101;
	(** Status of an integration, i.e., the admissible values for the returned parameter 'res'. *)
	OKay* = 0;  MaxSubDivReached* = 1;  RoundoffError* = 2;  RoughIntegrand* = 3;

VAR
	(** Upper bound on the number of subintervals of integration. *)
	MaxIntervals-: NbrInt.Integer;
	node8, wgtGauss4, wgtKronrod8, node16, wgtGauss8, wgtKronrod16, node31, wgtGauss15,
	wgtKronrod31: POINTER TO ARRAY OF NbrRe.Real;

TYPE
	(* The Read and Write methods are not required because Intervals belong to lists that are not saved to file. *)

	Interval = OBJECT (Data.Datum)
	VAR a, b, error: NbrRe.Real;

		PROCEDURE & Initialize*;
		BEGIN
			Initialize^;
			(* Intialize the local data. *)
			a := 0;  b := 0;  error := 0
		END Initialize;

		PROCEDURE Copy*( VAR copy: Data.Datum );
		VAR new, obj: Interval;
		BEGIN
			(* Create object copy. *)
			IF (copy = NIL ) OR ~(copy IS Interval) THEN NEW( new );  copy := new END;
			(* Copy the lower-level data structures first. *)
			Copy^( copy );
			(* Type cast copy so that the local data structure can be copied. *)
			obj := copy( Interval );
			(* Make a deep copy of the local data to obj. *)
			obj.a := a;  obj.b := b;  obj.error := error;
			(* Reassign the copied object for returning. *)
			copy := obj
		END Copy;

	END Interval;

	ReInterval = OBJECT (Interval)
	VAR soln: NbrRe.Real;

		PROCEDURE & Initialize*;
		BEGIN
			Initialize^;
			(* Intialize the local data. *)
			soln := 0
		END Initialize;

		PROCEDURE Copy*( VAR copy: Data.Datum );
		VAR new, obj: ReInterval;
		BEGIN
			(* Create object copy. *)
			IF (copy = NIL ) OR ~(copy IS ReInterval) THEN NEW( new );  copy := new END;
			(* Copy the lower-level data structures first. *)
			Copy^( copy );
			(* Type cast copy so that the local data structure can be copied. *)
			obj := copy( ReInterval );
			(* Make a deep copy of the local data to obj. *)
			obj.soln := soln;
			(* Reassign the copied object for returning. *)
			copy := obj
		END Copy;

	END ReInterval;

	CplxInterval = OBJECT (Interval)
	VAR soln: NbrCplx.Complex;

		PROCEDURE & Initialize*;
		BEGIN
			Initialize^;
			(* Intialize the local data. *)
			soln := 0
		END Initialize;

		PROCEDURE Copy*( VAR copy: Data.Datum );
		VAR new, obj: CplxInterval;
		BEGIN
			(* Create object copy. *)
			IF (copy = NIL ) OR ~(copy IS CplxInterval) THEN NEW( new );  copy := new END;
			(* Copy the lower-level data structures first. *)
			Copy^( copy );
			(* Type cast copy so that the local data structure can be copied. *)
			obj := copy( CplxInterval );
			(* Make a deep copy of the local data to obj. *)
			obj.soln := soln;
			(* Reassign the copied object for returning. *)
			copy := obj
		END Copy;

	END CplxInterval;

	PROCEDURE GetKey( a, b, atX: NbrRe.Real ): Data.Key;
	VAR k: Data.Key;
	BEGIN
		k := NbrRe.Int( MaxIntervals * (atX - a)/(b - a) );  RETURN k
	END GetKey;

	PROCEDURE ReGaussKronrod( f: CalcFn.ReArg;  fromX, toX: NbrRe.Real;  integrator: NbrInt.Integer;
												  VAR result, absError, absResult: NbrRe.Real );
	(*  f :  integrand
			fromX :  lower limit of integration
			toX (> fromX) :  upper limit of integration
			integrator N  {Coarse, Medium, Fine}
			result :  approximation to the integral
			absError :  estimate of the absolute error
			absResult :  approximation to the integral of ABS(f(x)) over [fromX, toX]
		*)
	VAR i, len: NbrInt.Integer;
		abscissa, center, fCenter, fSum, halfLength, resultGauss, resultKronrod, tolerance: NbrRe.Real;
		fAbove, fBelow, node, wgtGauss, wgtKronrod: POINTER TO ARRAY OF NbrRe.Real;
	BEGIN
		IF integrator = Coarse THEN
			len := 8;  NEW( node, 8 );  NEW( wgtGauss, 4 );  NEW( wgtKronrod, 8 );
			FOR i := 0 TO 7 DO node[i] := node8[i];  wgtKronrod[i] := wgtKronrod8[i] END;
			FOR i := 0 TO 3 DO wgtGauss[i] := wgtGauss4[i]  END
		ELSIF integrator = Fine THEN
			len := 31;  NEW( node, 31 );  NEW( wgtGauss, 15 );  NEW( wgtKronrod, 31 );
			FOR i := 0 TO 30 DO node[i] := node31[i];  wgtKronrod[i] := wgtKronrod31[i] END;
			FOR i := 0 TO 14 DO wgtGauss[i] := wgtGauss15[i]  END
		ELSE  (* integrator = Medium, the default *)
			len := 16;  NEW( node, 16 );  NEW( wgtGauss, 8 );  NEW( wgtKronrod, 16 );
			FOR i := 0 TO 15 DO node[i] := node16[i];  wgtKronrod[i] := wgtKronrod16[i] END;
			FOR i := 0 TO 7 DO wgtGauss[i] := wgtGauss8[i]  END
		END;
		NEW( fAbove, len - 1 );  NEW( fBelow, len - 1 );  center := (fromX + toX) / 2;  halfLength := (toX - fromX) / 2;
		fCenter := f( center );  resultKronrod := wgtKronrod[len - 1] * fCenter;  absResult := ABS( resultKronrod );
		IF NbrInt.Odd( len ) THEN resultGauss := 0 ELSE resultGauss := wgtGauss[(len DIV 2) - 1] * fCenter END;
		FOR i := 0 TO len - 2 DO
			abscissa := halfLength * node[i];  fAbove[i] := f( center + abscissa );  fBelow[i] := f( center - abscissa );
			fSum := fAbove[i] + fBelow[i];  resultKronrod := resultKronrod + wgtKronrod[i] * fSum;
			absResult := absResult + wgtKronrod[i] * (ABS( fAbove[i] ) + ABS( fBelow[i] ));
			IF NbrInt.Odd( i ) THEN resultGauss := resultGauss + wgtGauss[i DIV 2] * fSum END
		END;
		result := halfLength * resultKronrod;  absResult := halfLength * absResult;
		absError := ABS( halfLength * (resultKronrod - resultGauss) );  tolerance := 50 * NbrRe.Epsilon;
		IF absResult > 1/NbrRe.MaxNbr*tolerance THEN absError := NbrRe.Max( absError, tolerance * absResult ) END
	END ReGaussKronrod;

(** Computes  I(f) = xab f(x) dx  to a specified error tolerance. *)
	PROCEDURE Solve*( f: CalcFn.ReArg;  a, b: NbrRe.Real;  integrator: NbrInt.Integer;  VAR error: NbrRe.Real;
						   VAR res: NbrInt.Integer ): NbrRe.Real;
	(* This algorithm is a partial port of the FORTRAN subroutine DPAG from the QUADPACK library of routines.
		R. Piessens, E. de Doncker-Kapenga, C. überhuber, and D. K. Kahaner.  QUADPACK - A Subroutine Package for
		Automatic Integration.  No. 1 in: Springer Series in Computational Mathematics, Springer, Berlin, 1983.   *)
	VAR ignor, successful: BOOLEAN;  key, maxKey: Data.Key;  sign: NbrInt.Integer;
		aa, bb, maxError, maxTol, midPoint, sumError, sumResult, tolerance: NbrRe.Real;  datum: Data.Datum;
		interval, intervalL, intervalR: ReInterval;  history: DataLists.List;

		PROCEDURE Create( withKey: Data.Key ): ReInterval;
		VAR int: ReInterval;
		BEGIN
			NEW( int );  int.SetKey( withKey );  RETURN int
		END Create;

		PROCEDURE Update( VAR int: ReInterval );
		VAR absApprox, absError, approx: NbrRe.Real;
		BEGIN
			ReGaussKronrod( f, int.a, int.b, integrator, approx, absError, absApprox );  int.soln := approx;
			int.error := absError * (int.b - int.a) / (bb - aa);
			IF (absError < 100 * NbrRe.Epsilon * absApprox) & (absError > tolerance) THEN
				res := RoundoffError
			END;
			IF NbrRe.Abs( int.b ) < ((1 + 100*NbrRe.Epsilon) * (NbrRe.Abs( int.a ) + 1000/NbrRe.MaxNbr)) THEN
				res := RoughIntegrand
			END
		END Update;

	BEGIN
		IF f # NIL THEN
			res := OKay;
			IF a = b THEN error := 0;  sign := 1;  sumResult := 0
					ELSE  (* integrate *)
				maxTol := 0.1;  tolerance := NbrRe.Max( 100 * NbrRe.Epsilon, NbrRe.Min( maxTol, error ) );
				IF a < b THEN sign := 1;  aa := a;  bb := b ELSE sign := -1;  aa := b;  bb := a END;
				key := GetKey( aa, bb, bb );  interval := Create( key );  interval.a := aa;  interval.b := bb;
				Update( interval );  sumResult := interval.soln;  sumError := interval.error;
				IF NbrRe.Abs( sumResult ) < 1 THEN error := sumError
				ELSE error := NbrRe.Abs( sumError / sumResult )
				END;
				IF error > tolerance THEN
					NEW( history );  history.Insert( interval, ignor );
					(* Refine the integration. *)
					LOOP
					(* Search for the interval with the largest error estimate. *)
						history.rider.Home;  datum := history.rider.Inspect();  interval := datum( ReInterval );
						maxError := interval.error;  interval.GetKey( maxKey );
						WHILE ~history.rider.eol DO
							history.rider.Next;  datum := history.rider.Inspect();  interval := datum( ReInterval );
							IF interval.error > maxError THEN
								maxError := interval.error;  interval.GetKey( maxKey )
							END
						END;
						(* Bisect the interval with the largest error estimate and integrate these two subintervals. *)
						datum := history.rider.Retrieve( maxKey );  interval := datum( ReInterval );
						history.Delete( maxKey, ignor );  midPoint := (interval.a + interval.b) / 2;
						key := GetKey( interval.a, interval.b, midPoint );  intervalL := Create( key );
						intervalL.a := interval.a;  intervalL.b := midPoint;  Update( intervalL );
						history.Insert( intervalL, successful );
						IF successful & (key # maxKey) THEN
							intervalR := Create( maxKey );  intervalR.a := midPoint;  intervalR.b := interval.b;
							Update( intervalR );  history.Insert( intervalR, ignor )
						ELSE
							IF successful THEN history.Delete( key, ignor ) END;
							history.Insert( interval, ignor );  res := MaxSubDivReached
						END;
						IF res # OKay THEN EXIT END;
						sumResult := sumResult + intervalL.soln + intervalR.soln - interval.soln;
						sumError := sumError + intervalL.error + intervalR.error - interval.error;
						IF NbrRe.Abs( sumResult ) < 1 THEN error := sumError
						ELSE error := NbrRe.Abs( sumError / sumResult )
						END;
						IF error < tolerance THEN EXIT END
					END
				END
			END
		ELSE sign := 1;  sumResult := 0
		END;
		RETURN sign * sumResult
	END Solve;

	PROCEDURE CplxGaussKronrod( f: CalcFn.MixedArg;  fromX, toX: NbrRe.Real;  z: NbrCplx.Complex;
													integrator: NbrInt.Integer;  VAR result: NbrCplx.Complex;
													VAR absError, absResult: NbrRe.Real );
	(*  f :  integrand
			fromX :  lower limit of integration
			toX (> fromX) :  upper limit of integration
			z  is a passed parameter to  f
			integrator N  {Coarse, Medium, Fine}
			result :  approximation to the integral
			absError :  estimate of the absolute error
			absResult :  approximation to the integral of ABS(f(x)) over [fromX, toX]
	*)
	VAR i, len: NbrInt.Integer;  abscissa, center, halfLength, tolerance: NbrRe.Real;
		fCenter, fSum, resultGauss, resultKronrod: NbrCplx.Complex;
		node, wgtGauss, wgtKronrod: POINTER TO ARRAY OF NbrRe.Real;
		fAbove, fBelow: POINTER TO ARRAY OF NbrCplx.Complex;
	BEGIN
		IF integrator = Coarse THEN
			len := 8;  NEW( node, 8 );  NEW( wgtGauss, 4 );  NEW( wgtKronrod, 8 );
			FOR i := 0 TO 7 DO node[i] := node8[i];  wgtKronrod[i] := wgtKronrod8[i] END;
			FOR i := 0 TO 3 DO wgtGauss[i] := wgtGauss4[i]  END
		ELSIF integrator = Fine THEN
			len := 31;  NEW( node, 31 );  NEW( wgtGauss, 15 );  NEW( wgtKronrod, 31 );
			FOR i := 0 TO 30 DO node[i] := node31[i];  wgtKronrod[i] := wgtKronrod31[i] END;
			FOR i := 0 TO 14 DO wgtGauss[i] := wgtGauss15[i]  END
		ELSE  (* integrator = Medium, the default *)
			len := 16;  NEW( node, 16 );  NEW( wgtGauss, 8 );  NEW( wgtKronrod, 16 );
			FOR i := 0 TO 15 DO node[i] := node16[i];  wgtKronrod[i] := wgtKronrod16[i] END;
			FOR i := 0 TO 7 DO wgtGauss[i] := wgtGauss8[i]  END
		END;
		NEW( fAbove, len - 1 );  NEW( fBelow, len - 1 );  center := (fromX + toX) / 2;  halfLength := (toX - fromX) / 2;
		fCenter := f( center, z );  resultKronrod := wgtKronrod[len - 1] * fCenter;
		absResult := NbrCplx.Abs( resultKronrod );
		IF NbrInt.Odd( len ) THEN resultGauss := 0 ELSE resultGauss := wgtGauss[(len DIV 2) - 1] * fCenter END;
		FOR i := 0 TO len - 2 DO
			abscissa := halfLength * node[i];  fAbove[i] := f( center + abscissa, z );  fBelow[i] := f( center - abscissa, z );
			fSum := fAbove[i] + fBelow[i];  resultKronrod := resultKronrod + wgtKronrod[i] * fSum;
			absResult := absResult + wgtKronrod[i] * (NbrCplx.Abs( fAbove[i] ) + NbrCplx.Abs( fBelow[i] ));
			IF NbrInt.Odd( i ) THEN resultGauss := resultGauss + wgtGauss[i DIV 2] * fSum END
		END;
		result := halfLength * resultKronrod;  absResult := halfLength * absResult;
		absError := NbrCplx.Abs( halfLength * (resultKronrod - resultGauss) );  tolerance := 50 * NbrRe.Epsilon;
		IF absResult > 1/NbrRe.MaxNbr*tolerance THEN absError := NbrRe.Max( absError, tolerance * absResult ) END
	END CplxGaussKronrod;

(** Computes  I(f) = xab f(x,z) dx  to a specified error tolerance. *)
	PROCEDURE SolveCplx*( f: CalcFn.MixedArg;  a, b: NbrRe.Real;  z: NbrCplx.Complex;  integrator: NbrInt.Integer;
								  VAR error: NbrRe.Real;  VAR res: NbrInt.Integer ): NbrCplx.Complex;
	VAR ignor, successful: BOOLEAN;  key, maxKey: Data.Key;  sign: NbrInt.Integer;
		aa, bb, maxError, maxTol, midPoint, sumError, tolerance: NbrRe.Real;  sumResult: NbrCplx.Complex;
		datum: Data.Datum;  interval, intervalL, intervalR: CplxInterval;  history: DataLists.List;

		PROCEDURE Create( withKey: Data.Key ): CplxInterval;
		VAR int: CplxInterval;
		BEGIN
			NEW( int );  int.SetKey( withKey );  RETURN int
		END Create;

		PROCEDURE Update( VAR int: CplxInterval );
		VAR absApprox, absError: NbrRe.Real;  approx: NbrCplx.Complex;
		BEGIN
			CplxGaussKronrod( f, int.a, int.b, z, integrator, approx, absError, absApprox );  int.soln := approx;
			int.error := absError * (int.b - int.a) / (bb - aa);
			IF (absError < 100 * NbrRe.Epsilon * absApprox) & (absError > tolerance) THEN
				res := RoundoffError
			END;
			IF NbrRe.Abs( int.b ) < ((1 + 100*NbrRe.Epsilon) * (NbrRe.Abs( int.a ) + 1000/NbrRe.MaxNbr)) THEN
				res := RoughIntegrand
			END
		END Update;

	BEGIN
		IF f # NIL THEN
			res := OKay;
			IF a = b THEN error := 0;  sign := 1;  sumResult := 0
					ELSE  (* integrate *)
				maxTol := 0.1;  tolerance := NbrRe.Max( 100 * NbrRe.Epsilon, NbrRe.Min( maxTol, error ) );
				IF a < b THEN sign := 1;  aa := a;  bb := b ELSE sign := -1;  aa := b;  bb := a END;
				key := GetKey( aa, bb, bb );  interval := Create( key );  interval.a := aa;  interval.b := bb;
				Update( interval );  sumResult := interval.soln;  sumError := interval.error;
				IF NbrCplx.Abs( sumResult ) < 1 THEN error := sumError
				ELSE error := NbrCplx.Abs( sumError / sumResult )
				END;
				IF error > tolerance THEN
					NEW( history );  history.Insert( interval, ignor );
					(* Refine the integration. *)
					LOOP
					(* Search for the interval with the largest error estimate. *)
						history.rider.Home;  datum := history.rider.Inspect();  interval := datum( CplxInterval );
						maxError := interval.error;  interval.GetKey( maxKey );
						WHILE ~history.rider.eol DO
							history.rider.Next;  datum := history.rider.Inspect();  interval := datum( CplxInterval );
							IF interval.error > maxError THEN
								maxError := interval.error;  interval.GetKey( maxKey )
							END
						END;
						(* Bisect the interval with the largest error estimate and integrate these two subintervals. *)
						datum := history.rider.Retrieve( maxKey );  interval := datum( CplxInterval );
						history.Delete( maxKey, ignor );  midPoint := (interval.a + interval.b) / 2;
						key := GetKey( interval.a, interval.b, midPoint );  intervalL := Create( key );
						intervalL.a := interval.a;  intervalL.b := midPoint;  Update( intervalL );
						history.Insert( intervalL, successful );
						IF successful & (key # maxKey) THEN
							intervalR := Create( maxKey );  intervalR.a := midPoint;  intervalR.b := interval.b;
							Update( intervalR );  history.Insert( intervalR, ignor )
						ELSE
							IF successful THEN history.Delete( key, ignor ) END;
							history.Insert( interval, ignor );  res := MaxSubDivReached
						END;
						IF res # OKay THEN EXIT END;
						sumResult := sumResult + intervalL.soln + intervalR.soln - interval.soln;
						sumError := sumError + intervalL.error + intervalR.error - interval.error;
						IF NbrCplx.Abs( sumResult ) < 1 THEN error := sumError
						ELSE error := NbrCplx.Abs( sumError / sumResult )
						END;
						IF error < tolerance THEN EXIT END
					END
				END
			END
		ELSE sign := 1;  sumResult := 0
		END;
		RETURN sign * sumResult
	END SolveCplx;

	PROCEDURE Quadrature;
	(* Gauss-Kronrod integration parameters for solving  I(f) = x-11 f(y) dy  via  I(f) p Si=1N wi f(ni).
			Because of symmetry over [-1, 1], only the positive nodes and their corresponding weights are given.
			Kronrod integration takes place at all the nodes.  Gauss integration only takes place at the odd nodes.
			These weights and nodes came from the FORTRAN subroutine DPAG from the QUADPACK library of routines.
			  R. Piessens, E. de Doncker-Kapenga, C. überhuber, and D. K. Kahaner.  QUADPACK - A Subroutine Package for
			  Automatic Integration.  No. 1 in: Springer Series in Computational Mathematics, Springer, Berlin, 1983.  *)
	BEGIN
		(* Whenever NbrRe.Real is a 32-bit real, use the following eonstants. *)
		 (* For Coarse integration *)
		NEW( node8, 8 );  NEW( wgtGauss4, 4 );  NEW( wgtKronrod8, 8 );  node8[0] := 0.99145537112081263920E0;
		node8[1] := 0.949107912;  node8[2] := 0.864864423;  node8[3] := 0.741531185;  node8[4] := 0.586087235;
		node8[5] := 0.405845151;  node8[6] := 0.207784955;  node8[7] := 0.0;
		wgtGauss4[0] := 0.129484966;  wgtGauss4[1] := 0.279705391;  wgtGauss4[2] := 0.381830051;
		wgtGauss4[3] := 0.417959183;
		wgtKronrod8[0] := 0.022935322;
		wgtKronrod8[1] := 0.063092093;  wgtKronrod8[2] := 0.104790010;  wgtKronrod8[3] := 0.140653260;
		wgtKronrod8[4] := 0.169004727;  wgtKronrod8[5] := 0.190350578;  wgtKronrod8[6] := 0.204432940;
		wgtKronrod8[7] := 0.209482141;
		(* For Medium integration *)
		NEW( node16, 16 );  NEW( wgtGauss8, 8 );  NEW( wgtKronrod16, 16 );
		node16[0] := 0.998002299;  node16[1] := 0.987992518;  node16[2] := 0.967739076;  node16[3] := 0.937273392;
		node16[4] := 0.897264532;  node16[5] := 0.848206583;  node16[6] := 0.790418501;  node16[7] := 0.724417731;
		node16[8] := 0.650996741;  node16[9] := 0.570972173;  node16[10] := 0.48508186;  node16[11] := 0.39415135;
		node16[12] := 0.29918001;  node16[13] := 0.20119409;  node16[14] := 0.10114207;  node16[15] := 0.0;
		wgtGauss8[0] := 0.030753242;  wgtGauss8[1] := 0.070366047;  wgtGauss8[2] := 0.107159220;
		wgtGauss8[3] := 0.139570678;  wgtGauss8[4] := 0.166269206;  wgtGauss8[5] := 0.186161000;
		wgtGauss8[6] := 0.198431485;  wgtGauss8[7] := 0.202578242;
		wgtKronrod16[0] := 0.005377480;  wgtKronrod16[1] := 0.015007947;  wgtKronrod16[2] := 0.025460847;
		wgtKronrod16[3] := 0.035346361;  wgtKronrod16[4] := 0.044589751;  wgtKronrod16[5] := 0.053481525;
		wgtKronrod16[6] := 0.062009568;  wgtKronrod16[7] := 0.069854121;  wgtKronrod16[8] := 0.076849681;
		wgtKronrod16[9] := 0.083080503;  wgtKronrod16[10] := 0.088564443;  wgtKronrod16[11] := 0.093126598;
		wgtKronrod16[12] := 0.096642727;  wgtKronrod16[13] := 0.099173599;  wgtKronrod16[14] := 0.100769846;
		wgtKronrod16[15] := 0.101330007;
		(* For Fine integration *)
		NEW( node31, 31 );  NEW( wgtGauss15, 15 );  NEW( wgtKronrod31, 31 );
		node31[0] := 0.999484410;  node31[1] := 0.996893484;  node31[2] := 0.991630997;  node31[3] := 0.983668123;
		node31[4] := 0.973116323;  node31[5] := 0.960021865;  node31[6] := 0.944374445;  node31[7] := 0.926200047;
		node31[8] := 0.905573308;  node31[9] := 0.882560536;  node31[10] := 0.857205234;  node31[11] := 0.829565762;
		node31[12] := 0.799727836;  node31[13] := 0.767777432;  node31[14] := 0.733790062;  node31[15] := 0.697850495;
		node31[16] := 0.660061064;  node31[17] := 0.620526183;  node31[18] := 0.579345236;  node31[19] := 0.536624148;
		node31[20] := 0.492480468;  node31[21] := 0.447033770;  node31[22] := 0.400401255;  node31[23] := 0.352704726;
		node31[24] := 0.304073202;  node31[25] := 0.254636926;  node31[26] := 0.204525117;  node31[27] := 0.153869914;
		node31[28] := 0.102806938;  node31[29] := 0.051471843;  node31[30] := 0.0;
		wgtGauss15[0] := 0.007968192;  wgtGauss15[1] := 0.018466468;  wgtGauss15[2] := 0.028784708;
		wgtGauss15[3] := 0.038799193;  wgtGauss15[4] := 0.048402673;  wgtGauss15[5] := 0.057493156;
		wgtGauss15[6] := 0.065974230;  wgtGauss15[7] := 0.073755975;  wgtGauss15[8] := 0.080755895;
		wgtGauss15[9] := 0.086899787;  wgtGauss15[10] := 0.092122522;  wgtGauss15[11] := 0.096368737;
		wgtGauss15[12] := 0.099593421;  wgtGauss15[13] := 0.101762390;  wgtGauss15[14] := 0.102852653;
		wgtKronrod31[0] := 0.001389014;  wgtKronrod31[1] := 0.003890461;  wgtKronrod31[2] := 0.006630704;
		wgtKronrod31[3] := 0.009273280;  wgtKronrod31[4] := 0.011823015;  wgtKronrod31[5] := 0.014369730;
		wgtKronrod31[6] := 0.016920889;  wgtKronrod31[7] := 0.019414141;  wgtKronrod31[8] := 0.021828036;
		wgtKronrod31[9] := 0.024191162;  wgtKronrod31[10] := 0.026509955;  wgtKronrod31[11] := 0.028754049;
		wgtKronrod31[12] := 0.030907258;  wgtKronrod31[13] := 0.032981447;  wgtKronrod31[14] := 0.034979338;
		wgtKronrod31[15] := 0.036882365;  wgtKronrod31[16] := 0.038678946;  wgtKronrod31[17] := 0.040374539;
		wgtKronrod31[18] := 0.041969810;  wgtKronrod31[19] := 0.043452540;  wgtKronrod31[20] := 0.044814800;
		wgtKronrod31[21] := 0.046059238;  wgtKronrod31[22] := 0.047185547;  wgtKronrod31[23] := 0.048185862;
		wgtKronrod31[24] := 0.049055435;  wgtKronrod31[25] := 0.049795683;  wgtKronrod31[26] := 0.050405921;
		wgtKronrod31[27] := 0.050881796;  wgtKronrod31[28] := 0.051221548;  wgtKronrod31[29] := 0.051426129;
		wgtKronrod31[30] := 0.051494729
		(* Or, whenever NbrRe.Real is a 64-bit real, use the following eonstants. *)
		(* (* For Coarse integration *)
		NEW( node8, 8 );  NEW( wgtGauss4, 4 );  NEW( wgtKronrod8, 8 );  node8[0] := 0.99145537112081263920D0;
		node8[1] := 0.94910791234275852452D0;  node8[2] := 0.86486442335976907278D0;
		node8[3] := 0.74153118559939443986D0;  node8[4] := 0.58608723546769113029D0;
		node8[5] := 0.40584515137739716690D0;  node8[6] := 0.20778495500789846760D0;
		node8[7] := 0.00000000000000000000D0;  wgtGauss4[0] := 0.12948496616886969327D0;
		wgtGauss4[1] := 0.27970539148927666790D0;  wgtGauss4[2] := 0.38183005050511894495D0;
		wgtGauss4[3] := 0.41795918367346938775D0;  wgtKronrod8[0] := 0.02293532201052922496D0;
		wgtKronrod8[1] := 0.06309209262997855329D0;  wgtKronrod8[2] := 0.10479001032225018383D0;
		wgtKronrod8[3] := 0.14065325971552591874D0;  wgtKronrod8[4] := 0.16900472663926790282D0;
		wgtKronrod8[5] := 0.19035057806478540991D0;  wgtKronrod8[6] := 0.20443294007529889241D0;
		wgtKronrod8[7] := 0.20948214108472782801D0;
		(* For Medium integration *)
		NEW( node16, 16 );  NEW( wgtGauss8, 8 );  NEW( wgtKronrod16, 16 );
		node16[0] := 0.99800229869339706028D0;  node16[1] := 0.98799251802048542848D0;
		node16[2] := 0.96773907567913913425D0;  node16[3] := 0.93727339240070590430D0;
		node16[4] := 0.89726453234408190088D0;  node16[5] := 0.84820658341042721620D0;
		node16[6] := 0.79041850144246593296D0;  node16[7] := 0.72441773136017004741D0;
		node16[8] := 0.65099674129741697053D0;  node16[9] := 0.57097217260853884753D0;
		node16[10] := 0.48508186364023968069D0;  node16[11] := 0.39415134707756336989D0;
		node16[12] := 0.29918000715316881216D0;  node16[13] := 0.20119409399743452230D0;
		node16[14] := 0.10114206691871749902D0;  node16[15] := 0.00000000000000000000D0;
		wgtGauss8[0] := 0.03075324199611726835D0;  wgtGauss8[1] := 0.07036604748810812470D0;
		wgtGauss8[2] := 0.10715922046717193501D0;  wgtGauss8[3] := 0.13957067792615431444D0;
		wgtGauss8[4] := 0.16626920581699393355D0;  wgtGauss8[5] := 0.18616100001556221102D0;
		wgtGauss8[6] := 0.19843148532711157645D0;  wgtGauss8[7] := 0.20257824192556127288D0;
		wgtKronrod16[0] := 0.00537747987292334898D0;  wgtKronrod16[1] := 0.01500794732931612253D0;
		wgtKronrod16[2] := 0.02546084732671532018D0;  wgtKronrod16[3] := 0.03534636079137584622D0;
		wgtKronrod16[4] := 0.04458975132476487660D0;  wgtKronrod16[5] := 0.05348152469092808726D0;
		wgtKronrod16[6] := 0.06200956780067064028D0;  wgtKronrod16[7] := 0.06985412131872825870D0;
		wgtKronrod16[8] := 0.07684968075772037889D0;  wgtKronrod16[9] := 0.08308050282313302103D0;
		wgtKronrod16[10] := 0.08856444305621177064D0;  wgtKronrod16[11] := 0.09312659817082532122D0;
		wgtKronrod16[12] := 0.09664272698362367850D0;  wgtKronrod16[13] := 0.09917359872179195933D0;
		wgtKronrod16[14] := 0.10076984552387559504D0;  wgtKronrod16[15] := 0.10133000701479154901D0;
		(* For Fine integration *)
		NEW( node31, 31 );  NEW( wgtGauss15, 15 );  NEW( wgtKronrod31, 31 );
		node31[0] := 0.99948441005049063757D0;  node31[1] := 0.99689348407464954027D0;
		node31[2] := 0.99163099687040459485D0;  node31[3] := 0.98366812327974720997D0;
		node31[4] := 0.97311632250112626837D0;  node31[5] := 0.96002186496830751221D0;
		node31[6] := 0.94437444474855997941D0;  node31[7] := 0.92620004742927432587D0;
		node31[8] := 0.90557330769990779854D0;  node31[9] := 0.88256053579205268154D0;
		node31[10] := 0.85720523354606109895D0;  node31[11] := 0.82956576238276839744D0;
		node31[12] := 0.79972783582183908301D0;  node31[13] := 0.76777743210482619491D0;
		node31[14] := 0.73379006245322680472D0;  node31[15] := 0.69785049479331579693D0;
		node31[16] := 0.66006106412662696137D0;  node31[17] := 0.62052618298924286114D0;
		node31[18] := 0.57934523582636169175D0;  node31[19] := 0.53662414814201989926D0;
		node31[20] := 0.49248046786177857499D0;  node31[21] := 0.44703376953808917678D0;
		node31[22] := 0.40040125483039439253D0;  node31[23] := 0.35270472553087811347D0;
		node31[24] := 0.30407320227362507737D0;  node31[25] := 0.25463692616788984643D0;
		node31[26] := 0.20452511668230989143D0;  node31[27] := 0.15386991360858354696D0;
		node31[28] := 0.10280693796673703014D0;  node31[29] := 0.05147184255531769583D0;
		node31[30] := 0.00000000000000000000D0;  wgtGauss15[0] := 0.00796819249616660561D0;
		wgtGauss15[1] := 0.01846646831109095914D0;  wgtGauss15[2] := 0.02878470788332336934D0;
		wgtGauss15[3] := 0.03879919256962704959D0;  wgtGauss15[4] := 0.04840267283059405290D0;
		wgtGauss15[5] := 0.05749315621761906648D0;  wgtGauss15[6] := 0.06597422988218049512D0;
		wgtGauss15[7] := 0.07375597473770520626D0;  wgtGauss15[8] := 0.08075589522942021535D0;
		wgtGauss15[9] := 0.08689978720108297980D0;  wgtGauss15[10] := 0.09212252223778612871D0;
		wgtGauss15[11] := 0.09636873717464425963D0;  wgtGauss15[12] := 0.09959342058679526706D0;
		wgtGauss15[13] := 0.10176238974840550459D0;  wgtGauss15[14] := 0.10285265289355884034D0;
		wgtKronrod31[0] := 0.00138901369867700762D0;  wgtKronrod31[1] := 0.00389046112709988405D0;
		wgtKronrod31[2] := 0.00663070391593129217D0;  wgtKronrod31[3] := 0.00927327965951776342D0;
		wgtKronrod31[4] := 0.01182301525349634174D0;  wgtKronrod31[5] := 0.01436972950704580481D0;
		wgtKronrod31[6] := 0.01692088918905327262D0;  wgtKronrod31[7] := 0.01941414119394238117D0;
		wgtKronrod31[8] := 0.02182803582160919229D0;  wgtKronrod31[9] := 0.02419116207808060136D0;
		wgtKronrod31[10] := 0.02650995488233310161D0;  wgtKronrod31[11] := 0.02875404876504129284D0;
		wgtKronrod31[12] := 0.03090725756238776247D0;  wgtKronrod31[13] := 0.03298144705748372603D0;
		wgtKronrod31[14] := 0.03497933802806002413D0;  wgtKronrod31[15] := 0.03688236465182122922D0;
		wgtKronrod31[16] := 0.03867894562472759295D0;  wgtKronrod31[17] := 0.04037453895153595911D0;
		wgtKronrod31[18] := 0.04196981021516424614D0;  wgtKronrod31[19] := 0.04345253970135606931D0;
		wgtKronrod31[20] := 0.04481480013316266319D0;  wgtKronrod31[21] := 0.04605923827100698811D0;
		wgtKronrod31[22] := 0.04718554656929915394D0;  wgtKronrod31[23] := 0.04818586175708712914D0;
		wgtKronrod31[24] := 0.04905543455502977888D0;  wgtKronrod31[25] := 0.04979568342707420635D0;
		wgtKronrod31[26] := 0.05040592140278234684D0;  wgtKronrod31[27] := 0.05088179589874960649D0;
		wgtKronrod31[28] := 0.05122154784925877217D0;  wgtKronrod31[29] := 0.05142612853745902593D0;
		wgtKronrod31[30] := 0.05149472942945156755D0 *)
	END Quadrature;

BEGIN
	Quadrature;  MaxIntervals := NbrInt.MaxNbr
END CalcGauss.