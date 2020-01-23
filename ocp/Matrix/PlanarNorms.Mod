MODULE PlanarNorms; (** AUTHOR "Patrick Hunziker"; PURPOSE "Norms in planar data"; *)
(* see also MatrixNorms.Mod *)

IMPORT PlanarBase, PlanarMath, PlanarNabla, PMath, MathL, Commands, KernelLog;

TYPE
	Datatype=PlanarBase.Datatype;
	Complex=PlanarBase.Complex;

	Plane=PlanarBase.TwoD;
	ComplexPlane=ARRAY [*,*] OF Complex;

PROCEDURE Power*(CONST p:Plane):Datatype;
BEGIN
	RETURN p+*p
END Power;

PROCEDURE PowerComplex*(CONST p:ComplexPlane):Datatype;
VAR tmp:Plane;
BEGIN
	tmp:=ABS(p);
	RETURN tmp+*tmp
END PowerComplex;

PROCEDURE TotalVariation*(CONST p:Plane; sampling:SIGNED32): Datatype; (* to do: optimize *)
BEGIN
	RETURN SUM(PlanarMath.Sqrt(PlanarMath.Sqr(PlanarNabla.dx(p,sampling))
									+ PlanarMath.Sqr(PlanarNabla.dy(p,sampling))))
END TotalVariation;


(** SNR, PSNR, RMSE, MAE for images, see http://bigwww.epfl.ch/sage/soft/snr/	*)

(** sinus to noise ratio for images = 10 log (...) *)
PROCEDURE SNR*(CONST test, reference:Plane):Datatype;
VAR dividend, divisor: Datatype; tmp: Plane;
BEGIN
	(*dividend:=SUM(reference .* reference);*)
	dividend:=reference +* reference;
	(*divisor:=SUM(PlanarMath.Sqr( reference-test));*)
	tmp:=reference-test;
	divisor:= tmp+*tmp;
	RETURN 10*PMath.log (SHORT(dividend/divisor))
END SNR;

PROCEDURE SNRComplex*(CONST test, reference:ComplexPlane):Datatype; (* see http://mathworld.wolfram.com/AveragePower.htm and http://bigwww.epfl.ch/sage/soft/snr/ *)
VAR dividend, divisor: Datatype; tmp: Plane; tmpC: ComplexPlane;
BEGIN
	tmp:=ABS(reference);
	dividend:=tmp+*tmp;
	tmpC:=reference-test;
	tmp:=ABS(tmpC);
	divisor:=tmp+*tmp;
	RETURN 10*PMath.log (SHORT(dividend/divisor))
END SNRComplex;


(** peak sinus to noise ratio for images = 10 log (...) *)
PROCEDURE PSNR*(CONST test, reference:Plane):Datatype;
VAR dividend, divisor: Datatype;
BEGIN
	dividend:=MAX(reference .* reference);
	divisor:=SUM(PlanarMath.Sqr( reference-test));
	RETURN 10*PMath.log (SHORT(dividend*LEN(test,0)*LEN(test,1)/divisor))
END PSNR;

(** root mean square error*)
PROCEDURE RMSE*(CONST test, reference:Plane):Datatype;
BEGIN
	RETURN MathL.sqrt(SUM(PlanarMath.Sqr( reference-test))/(LEN(test,0)*LEN(test,1)))
END RMSE;

(** mean absolute error *)
PROCEDURE MAE*(CONST test, reference:Plane):Datatype;
BEGIN
	RETURN SUM(ABS( reference-test))/(LEN(test,0)*LEN(test,1))
END MAE;

PROCEDURE Test*(context:Commands.Context);
VAR a,b: Plane; c:ComplexPlane;
BEGIN
	NEW(a,10,10); a[4,4]:=10;
	NEW(b,10,10);b[4,4]:=10.5;
	context.out.Float(SNR(a,b),14);
	context.out.Float(PSNR(a,b),14);
	context.out.Float(RMSE(a,b),14);
	context.out.Float(MAE(a,b),14);
	context.out.Float(TotalVariation(a, PlanarNabla.centered),14);
	context.out.Ln; context.out.Update;
END Test;

END PlanarNorms.

PlanarNorms.Test ~
SystemTools.FreeDownTo PlanarNorms ~

