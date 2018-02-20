(* CAPO - Computational Analysis Platform for Oberon - by Alan Freed and Felix Friedrich. *)
(* Version 1, Update 2 *)

MODULE MathErf;   (** AUTHOR "adf"; PURPOSE "The error function:  erf(x) = (2/Vp) x0x exp(-t2) dt"; *)

(* To change to 64-bit reals, address the code fragments written in light red. *)

(* Ref:  J.F. Hart, E.W. Cheney, C.L. Lawson, H.J. Maehly, C.K. Mesztenyi, J.R. Rice, H.G. Thacher, Jr., and C. Witzgall,
		"Computer Approximations," in: The SIAM Series in Applied MathLematics, Wiley, New York, 1968. *)

IMPORT NbrInt, NbrRe, DataErrors, MathRe, MathReSeries;

VAR
	maxIterations: NbrInt.Integer;  twoBySqrtPi: NbrRe.Real;
	(* Whenever NbrRe.Real is a 32-bit real, define the following arrays. *)
	erfcP1: ARRAY 3 OF NbrRe.Real;
	erfcP, erfcQ1: ARRAY 4 OF NbrRe.Real;
	erfcQ: ARRAY 5 OF NbrRe.Real;
	(* Or whenever NbrRe.Real is a 64-bit real, define the following arrays. *)
	(*  erfcP1: ARRAY 6 OF NbrRe.Real;
	erfcP, erfcQ1: ARRAY 7 OF NbrRe.Real;
	erfcQ: ARRAY 8 OF NbrRe.Real;  *)

TYPE
	ErfP = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		VAR m: NbrInt.Integer;
		BEGIN
			IF n = 0 THEN coef := 0
			ELSIF n = 1 THEN coef := 1
			ELSE
				coef := 2 * (n - 1) * x;  m := n + 1;
				IF NbrInt.Odd( m ) THEN coef := -coef END
			END;
			IF n > maxIterations THEN eos := TRUE;  DataErrors.ReWarning( x, "Did not converge -  timed out." ) END
		END Evaluate;

	END ErfP;

	ErfQ = OBJECT (MathReSeries.Coefficient)

		PROCEDURE Evaluate*;
		BEGIN
			IF n = 0 THEN coef := 0
			ELSIF n = 1 THEN coef := 1
			ELSE coef := 1 + 2 * (n - 1)
			END
		END Evaluate;

	END ErfQ;

	PROCEDURE Erfc( x: NbrRe.Real ): NbrRe.Real;
	VAR max: NbrInt.Integer;  erfc: NbrRe.Real;
	BEGIN
		max := 26;   (* Asymptote reached by this value. *)
		IF x > max THEN erfc := 0
		ELSIF x < -max THEN erfc := 2
		ELSE
			IF NbrRe.Abs( x ) > 9 THEN
				erfc := MathReSeries.TruncatedRationalFunction( erfcP1, erfcQ1, NbrRe.Abs( x ) )
			ELSE erfc := MathReSeries.TruncatedRationalFunction( erfcP, erfcQ, NbrRe.Abs( x ) )
			END;
			erfc := erfc * NbrRe.Exp( -x * x );
			IF x < 0 THEN erfc := 2 - erfc END
		END;
		RETURN erfc
	END Erfc;

	PROCEDURE Fn*( x: NbrRe.Real ): NbrRe.Real;
	VAR erf: NbrRe.Real;  p: ErfP;  q: ErfQ;
	BEGIN
		IF NbrRe.Abs( x ) > 0.1 THEN erf := 1 - Erfc( x )
		ELSE
			NEW( p );  NEW( q );
			erf := twoBySqrtPi * MathRe.Exp( -x * x ) * MathReSeries.ContinuedFraction( p, q, x )
		END;
		RETURN erf
	END Fn;

(*
	PROCEDURE CplxFn*( z: NbrCplx.Complex ): NbrCplx.Complex;
	VAR
	BEGIN
	END CplxFn;
*)


BEGIN
	maxIterations := 1000;  twoBySqrtPi := 2 / MathRe.Sqrt( NbrRe.Pi );
	(* Whenever NbrRe.Real is a 32-bit real, use the following eonstants. *)
	(* Constants from Table ERFC 5663 from "Computer Approximations".   *)
	erfcP[0] := 1.000464117E1;  erfcP[1] := 8.426552865;  erfcP[2] := 3.460259332;  erfcP[3] := 5.623536121E-1;
	erfcQ[0] := 1.000464117E1;  erfcQ[1] := 1.971558074E1;  erfcQ[2] := 1.570228809E1;  erfcQ[3] := 6.090748787;
	erfcQ[4] := 1.0;
	(* Constants from Table ERFC 5722 from "Computer Approximations".  *)
	erfcP1[0] := 6.141050179E-1;  erfcP1[1] := 3.295899049E-1;  erfcP1[2] := 5.641895902E-1;
	erfcQ1[0] := 2.953483222E-1;  erfcQ1[1] := 1.588352760;  erfcQ1[2] := 5.841849230E-1;  erfcQ1[3] := 1.0
	(* Or, whenever NbrRe.Real is a 64-bit real, use the following eonstants. *)
	(*  (* Constants from Table ERFC 5666 from "Computer Approximations". *)
	erfcP[0] := 4.4041373582475223325269D2;  erfcP[1] := 6.25686535769683006135193D2;
	erfcP[2] := 4.483171659914834429345063D2;  erfcP[3] := 1.9184014058796685752390301D2;
	erfcP[4] := 5.0991697628253203795669523D1;  erfcP[5] := 7.9239298287415448527194039D0;
	erfcP[6] := 0.56419994559825748305038673D0;  erfcQ[0] := 4.4041373582475221430599D2;
	erfcQ[1] := 1.122640220177046578853681D3;  erfcQ[2] := 1.2746672667576622866580268D3;
	erfcQ[3] := 8.3881036547840644197941778D2;  erfcQ[4] := 3.47122928811784331429078057D2;
	erfcQ[5] := 9.08727112035370362595507371D1;  erfcQ[6] := 1.404533730546113829847322587D1;
	erfcQ[7] := 1.0D0;
	(* Constants from Table ERFC 5725 from "Computer Approximations". *)
	erfcP1[0] := 2.9788656263939928862D0;  erfcP1[1] := 7.409740605964741794425D0;
	erfcP1[2] := 6.1602098531096305440906D0;  erfcP1[3] := 5.019049726784267463450058D0;
	erfcP1[4] := 1.275366644729965952479585264D0;  erfcP1[5] := 0.5641895835477550741253201704D0;
	erfcQ1[0] := 3.3690752069827527677D0;  erfcQ1[1] := 9.608965327192787870698D0;
	erfcQ1[2] := 1.708144074746600431571095D1;  erfcQ1[3] := 1.20489519278551290360340491D1;
	erfcQ1[4] := 9.396034016235054150430579648D0;  erfcQ1[5] := 2.260528520767326969591866945D0;
	erfcQ1[6] := 1.0D0  *)
END MathErf.
