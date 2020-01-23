MODULE PlanarNabla;	(**  AUTHOR "Patrick Hunziker"; PURPOSE "Nabla Operators";  **)

(* consider: extend such that arbitrary prefiltering with a user-supplied filter may be done *)

IMPORT PlanarBase;
CONST x=0; y=1;
	(*sampling type*)
	centered*=0; (*entier*)
	linear*=1;
	spline2*=2;
	spline3*=3;
	entier*=4;
	nearestneighbour*=8;

TYPE
	Scalar* = PlanarBase.Datatype;
	Line = ARRAY [*] OF Scalar;
	Vector = Line;
	ScalarField* = ARRAY [*,*] OF Scalar;
	VectorField* = RECORD x*,y*: ScalarField END;
	TensorField* = RECORD xx*,xy*, yx*, yy*: ScalarField END;

PROCEDURE dx* (CONST sf:ScalarField; sampling:SIGNED32): ScalarField; (* to do: place result directly in return variable *)
VAR res:ScalarField;
BEGIN
	IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1)); END;
	CASE sampling OF
		centered:
			RESULT[.. , 1..LEN( RESULT, 1 ) - 2] := 0.5 * sf[.. , 2..LEN( RESULT, 1 ) - 1];
			RESULT[.. , 1..LEN( RESULT, 1 ) - 2] := RESULT[.. , 1..LEN( RESULT, 1 ) - 2] - 0.5 * sf[.. , 0..LEN( RESULT, 1 ) - 3];
			RESULT[.., 0]:= sf[..,1]-sf[..,0]; RESULT[..,LEN(RESULT,1)-1]:=sf[.. ,LEN( sf, 1 ) - 1]-sf[.. ,LEN( sf, 1 ) - 2]; (*boundary handling; costly in terms of cache misses*)
		| linear, spline2:
			(*discrete filtered version*)
			HALT(100);
			(*
			filter := MatrixFilters.CreateFIRFilter( [-0.5, 0, 0.5], 1 );  PlanarTransform.Filter2D( g, g1, filter, {1}, MatrixFilters.mirrorH );
			*)
			(*spline version*)
			(*
				PlanarTransform.Filter2D( g, g1,    DSPFilters.CreateSplineFilter( DSPFilters.DirectBSpline3 ),    {1}, DSPFilters.mirrorH );
				PlanarTransform.Filter2D( g1, g1,    DSPFilters.CreateSplineFilter( DSPFilters.SplineDerivative ),    {1}, DSPFilters.mirrorH );   (*maps back one spline degree*)
				PlanarTransform.Filter2D( g1, g1,  DSPFilters.CreateSplineFilter( DSPFilters.InverseBSpline2 ),   {1}, DSPFilters.mirrorH );
			*)
		| spline3:
				(*HALT (100);*) (*ADD DIRECT B-Spline transform. does not work - probably the problem of SAME in/out variable in the Filter2D() procedure below*)
				(*PlanarTransform.Filter2D( sf, RESULT, DSPFilters.CreateSplineFilter( DSPFilters.DirectBSpline0 + SHORT(sampling) ), {1}, DSPFilters.mirrorH ); *)
				(*PlanarTransform.Filter2D( sf, RESULT,MatrixFilters.CreateSplineFilter( MatrixFilters.CubicSplineDifferentiator), {1}, MatrixFilters.mirrorH );*)
		| entier: RESULT[.. ,..LEN(sf,1)-2] := sf[.., 1..]-sf[.., ..LEN(sf,1)-2];
		ELSE  (*Out.String("Filter not implemented"); Out.Ln; *) HALT (100);
		END;
	RETURN RESULT
END dx;

PROCEDURE dy* (CONST sf:ScalarField; sampling:SIGNED32): ScalarField; (* to do: place result directly in return variable *)
VAR res:ScalarField;
BEGIN
	IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1)) END;
	CASE sampling OF
		centered:
			RESULT[1..LEN( RESULT, 0 ) - 2, .. ] := 0.5 * sf[2..LEN( RESULT, 0 ) - 1, .. ];
			RESULT[1..LEN( RESULT, 0 ) - 2, .. ] := RESULT[1..LEN( RESULT, 0 ) - 2, .. ] - 0.5 * sf[0..LEN( RESULT, 0 ) - 3, .. ];
			RESULT[0, ..]:= sf[1,..]-sf[0,..]; RESULT[LEN(RESULT,0)-1,..]:=sf[LEN( sf, 0 ) - 1,..]-sf[LEN( sf, 0 ) - 2,..]; (*boundary handling*)
		| linear, spline2:
			(*discrete version*)
			(*
			filter := MatrixFilters.CreateFIRFilter( [-0.5, 0, 0.5], 1 );  PlanarTransform.Filter2D( g, g1, filter, {0}, MatrixFilters.mirrorH );
			*)
			(*spline version*)
			(*
			PlanarTransform.Filter2D( g, g1,    DSPFilters.CreateSplineFilter( DSPFilters.DirectBSpline3 ),    {0}, DSPFilters.mirrorH );
			PlanarTransform.Filter2D( g1, g1,    DSPFilters.CreateSplineFilter( DSPFilters.SplineDerivative ),    {0}, DSPFilters.mirrorH );   (*maps back one spline degree*)
			PlanarTransform.Filter2D( g1, g1,    DSPFilters.CreateSplineFilter( DSPFilters.InverseBSpline2 ),   {0}, DSPFilters.mirrorH );
			*)
		| spline3:
				(*HALT (100);*) (*ADD direct  B-Spline transform. does not work - probably the problem of SAME in/out variable in the Filter2D() procedure below*)
				(*PlanarTransform.Filter2D( sf, dx, DSPFilters.CreateSplineFilter( DSPFilters.DirectBSpline0 + SHORT(sampling) ), {0}, DSPFilters.mirrorH );*)
				(*PlanarTransform.Filter2D( sf, RESULT, MatrixFilters.CreateSplineFilter( MatrixFilters.CubicSplineDifferentiator), {0}, MatrixFilters.mirrorH );*)
		| entier: RESULT[..LEN(sf,0)-2] := sf[1..]-sf[..LEN(sf,0)-2];
		ELSE (*Out.String("Filter not implemented"); Out.Ln; *)HALT (100);
		END;
	RETURN RESULT
END dy;

(** Gradients : nabla sf*)
PROCEDURE Grad* (CONST sf:ScalarField; sampling:SIGNED32): VectorField;	(* reuse of target variable not implemented *)
VAR grad: VectorField;
BEGIN
	IF LEN(grad.x)=0 THEN NEW(grad.x, LEN(sf,0), LEN(sf,1)) END;	(*compiler limitation here, call to the RETURN variable LEN(Grad.x) should be directly used. It appears that this is not allowed in the compiler*)
	IF LEN(grad.y)=0 THEN NEW(grad.y, LEN(sf,0), LEN(sf,1)) END;
	grad.x:=dx(sf, sampling);
	grad.y:=dy(sf, sampling);
	RETURN grad;
END Grad;

(* u dot grad sf *)
PROCEDURE DirectionalDerivative*(CONST sf:ScalarField; CONST u: VectorField; sampling:SIGNED32):ScalarField;
BEGIN
	(*directional derivative is derivative along u; corresponds to inner product of partial derivative with vector u = <d/dx, d/dy> * <ux, uy>  *)
	RETURN dx(sf, sampling) .* u.x + dy(sf, sampling) .* u.y
END DirectionalDerivative;

(** Divergence : nabla dot vf*)
PROCEDURE Div*(CONST vf:VectorField; sampling:SIGNED32):ScalarField; (* to do: place result directly in return variable *)
BEGIN
	RETURN dx(vf.x,sampling) + dy(vf.y, sampling);
END Div;

(** Rotation - Rot=Curl ; nabla cross vf
is a vector field in general, but in 2D, it only consists of an "z", component, i.e. a scalar value*)
PROCEDURE Rot* (CONST vf: VectorField; sampling:SIGNED32): ScalarField;  (* to do: place result directly in return variable *)
BEGIN
	RETURN dx(vf.y, sampling) - dy(vf.x, sampling)
END Rot;

(**  Laplacian Operator, 'nabla square', i.e. nabla dot nabla
see  http://en.wikipedia.org/wiki/Laplace_operator *)
PROCEDURE Laplacian*(CONST sf:ScalarField; sampling:SIGNED32): ScalarField;
BEGIN
 RETURN dx(dx(sf, sampling),sampling) + dy(dy(sf, sampling),sampling)
END Laplacian;



(** http://en.wikipedia.org/wiki/Del   - not yet implemented *)
(* Del can also be applied to a vector field with the result being a tensor.
The tensor derivative of a vector field \vec{v} is a 9-term second-rank tensor, but can be denoted simply as \nabla \otimes \vec{v} , where \otimes represents the dyadic product.
This quantity is equivalent to the Jacobian matrix of the vector field with respect to space.
For a small displacement \delta \vec{r}, the change in the vector field is given by:   \delta \vec{v} = (\nabla \otimes \vec{v}) \sdot \delta \vec{r}
*)
PROCEDURE TensorDerivative*(); (*! TBD *)
END TensorDerivative;
(*
In a sense, both the gradient and Jacobian are "first derivatives"  £ the former the first derivative of a scalar function of several variables,
the latter the first derivative of a vector function of several variables.
In general, the gradient can be regarded as a special version of the Jacobian: it is the Jacobian of a scalar function of several variables.
*)
PROCEDURE Jacobian*(CONST vf:VectorField; sampling:SIGNED32):TensorField; (** == TensorDerivative *)
VAR jac: TensorField;
BEGIN
	jac.xx := dx(vf.x, sampling);
	jac.xy := dy(vf.x, sampling);
	jac.yx := dx(vf.y, sampling);
	jac.yy := dy(vf.y, sampling);
	RETURN jac
END Jacobian;

(*
The Hessian matrix (or simply the Hessian) is the square matrix of second-order partial derivatives of a scalar function;
that is, it describes the local curvature of a function of many variables.
It corresponds to the Jacobian of the gradient , which in a sense is the "second derivative" of the scalar function of several variables in question.
*)

PROCEDURE Hessian*(CONST sf:ScalarField; sampling:SIGNED32):TensorField;
VAR hes:TensorField;
BEGIN
	(*HALT(200);*)
	RETURN  Jacobian(Grad(sf,sampling),sampling); (*! doe not compile   *)
END Hessian;

PROCEDURE VectorLaplacian*(CONST vf: VectorField; sampling:SIGNED32): ScalarField; (* to do: place result directly in return variable *)
BEGIN
 RETURN dx(dx(vf.x, sampling),sampling) + dy(dy(vf.y, sampling),sampling)
END VectorLaplacian;

(*
Hessian for a vector-valued function: the array of second partial derivatives is not a two-dimensional matrix of size n \times n,
but rather a tensor of order 3.
This can be thought of as a multi-dimensional array with dimensions m \times n \times n, which degenerates to the usual Hessian matrix for m = 1.
*)

PROCEDURE VectorHessian*(CONST vf: VectorField; sampling:SIGNED32): TensorField; (* HALT: this is not yet correct, because tensor has diffferent shape than current tensorfield ! *)
END VectorHessian;

(** Nabla in cylindrical coordinates, see http://en.wikipedia.org/wiki/Del_in_cylindrical_and_spherical_coordinates
Data precondition: Scalarfield[phi,r]; unit grid for r and phi; r0 for center of rotation *)

PROCEDURE r(len, r0:SIGNED32): Line;
VAR line:Line; i:SIGNED32;
BEGIN
	NEW(line,len);
	FOR i:=0 TO len-1 DO line[i]:= i-r0 END;
	RETURN line;
END r;

PROCEDURE invr(len, r0:SIGNED32): Line;
VAR line:Line; i:SIGNED32;
BEGIN
	NEW(line,len);
	FOR i:=r0 TO len-1 DO line[i]:= 1/MAX(1,i-r0) END; (*CAVE: singularity at r=0 *)
	FOR i:=0 TO r0-1 DO line[i]:= 1/(i-r0) END;
	RETURN line;
END invr;

PROCEDURE invr2(len, r0:SIGNED32): Line;
VAR line:Line; i:SIGNED32;
BEGIN
	NEW(line,len);
	FOR i:=r0 TO len-1 DO line[i]:= 1/MAX(1,i-r0)/MAX(1,i-r0) END; (*CAVE: singularity at r=0 *)
	FOR i:=0 TO r0-1 DO line[i]:= 1/(i-r0)/(i-r0) END;
	RETURN line;
END invr2;

PROCEDURE scalefieldbylinex(VAR p:ScalarField; CONST line: Line);
VAR i:SIZE;
BEGIN
	FOR i:=0 TO LEN(p,0)-1 DO p[i]:=p[i] .* line END;
END scalefieldbylinex;

PROCEDURE CylGrad* (CONST sf:ScalarField; r0:SIGNED32; sampling:SIGNED32): VectorField;	(* reuse of target variable not implemented *)
VAR grad: VectorField;
BEGIN
	IF LEN(grad.x)=0 THEN NEW(grad.x, LEN(sf,0), LEN(sf,1)) END;	(*BUG here, call to the RETURN variable LEN(Grad.x) should be directly used. It appears that this is not allowed in the compiler*)
	IF LEN(grad.y)=0 THEN NEW(grad.y, LEN(sf,0), LEN(sf,1)) END;
	grad.x:=dx(sf, sampling);
	grad.y:=dy(sf, sampling);
	scalefieldbylinex(grad.x, invr(LEN(grad.x,1)(SIGNED32), LEN(grad.x,0)(SIGNED32) DIV 2));
	RETURN grad;
END CylGrad;

PROCEDURE CylDiv*(CONST vx,vy:ScalarField; r0: SIGNED32; phi: Scalar; sampling:SIGNED32):ScalarField; (* to do: place result directly in return variable *)
VAR f: ScalarField;
BEGIN
	f := vx; scalefieldbylinex(f, r(LEN(f,1)(SIGNED32), r0));
	RESULT:= dx(f,sampling) ;
	f:= dy(vy, sampling);
	f:= f / phi;
	RESULT:= RESULT + f;
	scalefieldbylinex(RESULT, invr(LEN(f,1)(SIGNED32), r0));
	RETURN RESULT
END CylDiv;

(** Rotation *)
PROCEDURE CylRot* (CONST vx,vy: ScalarField; r0: SIGNED32; phi: Scalar; sampling:SIGNED32): ScalarField; (*is the sign correct ?*) (* to do: place result directly in return variable *)
VAR f: ScalarField;
BEGIN
	f := vy; scalefieldbylinex(f, r(LEN(f,1)(SIGNED32), r0));
	RESULT:= dx(f,sampling) ;
	f:= dy(vx, sampling);
	f:= f/phi;
	RESULT:= RESULT - dy(vx, sampling);
	scalefieldbylinex(RESULT, invr(LEN(f,1)(SIGNED32), r0));
	RETURN RESULT
END CylRot;

(**  Laplacian Operator, see  http://en.wikipedia.org/wiki/Laplace_operator *)
PROCEDURE CylLaplacian*(CONST sf:ScalarField; r0:SIGNED32; phi:Scalar; sampling:SIGNED32): ScalarField;
VAR f,g: ScalarField;
BEGIN
	 f := dx(sf, sampling);
	 scalefieldbylinex(f, r(LEN(f,1)(SIGNED32), r0));
	 g:= dx(f, sampling);
	 scalefieldbylinex(g, invr(LEN(f,1)(SIGNED32), r0));
	 RESULT:= g;
	 f:=dy(sf, sampling);
	 f:= f/phi;
	 g:= dy(f,sampling);
	 g:= g/phi;
	 scalefieldbylinex(g, invr2(LEN(f,1)(SIGNED32), r0));
	 RESULT:=RESULT + g;
	 RETURN RESULT
END CylLaplacian;

PROCEDURE CylVectorLaplacian*(CONST vx,vy: ScalarField; sampling:SIGNED32): ScalarField; (* to do: place result directly in return variable *)
END CylVectorLaplacian;


END PlanarNabla.
