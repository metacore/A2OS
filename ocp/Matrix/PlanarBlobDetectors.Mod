MODULE PlanarBlobDetectors; (** AUTHOR "Patrick Hunziker"; PURPOSE "Blob detection"; *)
(*! alpha version - work in progress *)

(*see http://en.wikipedia.org/wiki/Blob_detection *)

IMPORT PlanarBase, PlanarNabla, PlanarTransform, WMMatrix,LinearFilters, StatisticsBase;

TYPE
	Datatype=PlanarBase.Datatype;
	ScalarField=PlanarNabla.ScalarField;

(** Laplacian of Gaussian is a classic blob detector. *)
(* Laplacian of Gaussian: 
Support of Window Defines the Responsivity of the operator. Use sampling modes from PlanarNabla.Mod *)
(*! not yet finished: support width. Best used in a scale-space setup, i.e. multiresolution or multiple Gauss Support *)
PROCEDURE LaplacianOfGaussian*(CONST p:ScalarField; sampling:SIGNED32):ScalarField;
BEGIN
	RETURN PlanarNabla.Laplacian(Smooth(p), sampling); (*smoothing approximates gaussian filtering*)
END LaplacianOfGaussian;

(*to do: PROCEDURE DeterminantOfHessian() *)

(*to do: PROCEDURE HessianLaplace()b*)

(*to do: Lindeberg's watershed *)

(*to do PROCEDURE SplineBased..*)

(*to do: Scale-Space approach*)

	PROCEDURE Smooth(CONST data:ScalarField):ScalarField;
	VAR fir:LinearFilters.Filter;
	BEGIN
		fir:=LinearFilters.CreateSplineFilter(LinearFilters.InverseBSpline7); (*with increasing spline degree, b-Spline filters approximate a gaussian*)
		IF LEN(RESULT)#LEN(data) THEN NEW(RESULT,LEN(data)) END;
		PlanarTransform.Filter2D(data,RESULT, fir, {0,1}, PlanarTransform.mirrorH);
		RETURN RESULT
	END Smooth;

PROCEDURE LineNonMaxSuppression*(CONST in: ARRAY [*] OF Datatype; VAR out: ARRAY [*] OF Datatype);
CONST KeepEquals=TRUE;
VAR i:SIZE;
BEGIN
	IF in[0]>in[1] THEN out[0]:=1 ELSE out[1]:=0 END;
	IF in[LEN(in,0)-1]>in[LEN(in,0)-2] THEN out[LEN(in,0)-1]:=1 ELSE out[LEN(in,0)-1]:=0 END;
	FOR i:=1 TO LEN(in,0)-2 DO
		IF KeepEquals THEN
			IF (in[i]=MAX(in[i-1..i+1]))  THEN out[i]:=1 ELSE out[i]:=0 END;
		ELSE
			IF (in[i]>in[i-1]) & (in[i]>in[i+1]) THEN out[i]:=1 ELSE out[i]:=0 END;
		END;
	END;
END LineNonMaxSuppression;

PROCEDURE PlanarMaxima*(CONST in: ScalarField):ScalarField;
VAR i,j: SIZE;
BEGIN  (*!tbd: boundaries*)
	IF ~(LEN(RESULT)>= LEN(in)) THEN NEW(RESULT, LEN(in)) END;
	FOR j:=1 TO LEN(in,0)-2 DO
		FOR i:=1 TO LEN(in,1)-2 DO
			IF (in[j,i]=MAX(in[j-1..j+1,i-1..i+1])) & (in[j,i]>MIN(in[j-1..j+1,i-1..i+1])) THEN 
				RESULT[j,i]:=1.0 ELSE RESULT[j,i]:=0.0 
			END;
		END;
	END;	
	RETURN RESULT
END PlanarMaxima;

(** Non -maxima suppression in 2D *)
PROCEDURE NonMaximaSuppression*(CONST in:ScalarField):ScalarField; 
VAR m:ScalarField;
BEGIN
	m:=PlanarMaxima(Smooth(in));
	RETURN m.*in;
END NonMaximaSuppression;

PROCEDURE Test*;
VAR in,out: ScalarField; window: WMMatrix.Window;
BEGIN
	NEW(in,100,100);
	in[40..60,40..60]:=1;
	NEW(window, LaplacianOfGaussian(in, PlanarNabla.centered), "LOG 20"); window.AddWindow;
	in:=0; in[48..51, 48..51]:=1;
	NEW(window, LaplacianOfGaussian(in, PlanarNabla.centered), "LOG 4"); window.AddWindow;
	in:=0; in[49..50, 49..50]:=1;
	NEW(window, LaplacianOfGaussian(in, PlanarNabla.centered), "LOG 2"); window.AddWindow;
	in:=0; in[49..50, 49..50]:=1;
	in:=Smooth(in);
	out:=NonMaximaSuppression(in);
	NEW(window, out, "Planar maxima"); window.AddWindow;

END Test;


END PlanarBlobDetectors.

PlanarBlobDetectors.Test

System.FreeDownTo WMMatrix PlanarBlobDetectors ~
