MODULE VolumeNabla;	(**  AUTHOR "Patrick Hunziker 2008"; PURPOSE "Nabla operators";  **)

(*see overview of Del in cartesian and spherical coordinates in wikipedia:
http://en.wikipedia.org/wiki/Del_in_cylindrical_and_spherical_coordinates *)

(*
see also wikipedia: "Del"
Nabla A is Gradient (Vector)	- (corresponds to elementwise products)
Nabla dot A is Divergence (Scalar) - (corresponds to inner product)
Nabla cross A is Rot (Curl) (Vector) - (corresponds to cross product)
NablaXXX A is  Tensor Derivative == Jacobian (Tensor) - (corresponds to tensor product)

see wikipedia: "Del": Del can also be applied to a vector field with the result being a tensor. The tensor derivative of a vector field \vec{v} is a 9-term second-rank tensor, but can be denoted simply as \nabla \otimes \vec{v} , where \otimes represents the dyadic product. This quantity is equivalent to the Jacobian matrix of the vector field with respect to space
 =  = 2  is Laplacian
 *)

CONST
	x=0; y=1; z=2;
	(*sampling type*)
	centered*=0; (*entier*)
	linear*=1;
	spline2*=2;
	spline3*=3;
	entier*=4;
	nearestneighbour*=8;


TYPE
	Datatype* = FLOAT64;
	ScalarField* = ARRAY [*,*,*] OF Datatype;
	VectorField* = ARRAY [*,*,*,*] OF Datatype; (* dimension in first index: [3, *,*,*]  *)
	Field= ARRAY [*,*,*,*] OF Datatype; (* scalar & vector quantity at a point *)
	TensorField* = ARRAY [*,*,*,*,*] OF Datatype;

PROCEDURE dx* (CONST sf:ScalarField; sampling:SIGNED32): ScalarField;	(*to do: implement exact computation*)
BEGIN
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2)) END;
	CASE sampling OF
		centered:
			RESULT[.., .. , 1..LEN( RESULT, 2 ) - 2] := 0.5 * sf[.., .. , 2..LEN( RESULT, 2 ) - 1];
			(*RESULT[.., .. , 1..LEN( RESULT, 2 ) - 2] := RESULT[.., .. , 1..LEN( RESULT, 2 ) - 2] - 0.5 * sf[.., .. , 0..LEN( RESULT, 2 ) - 3];*)
						
			RESULT[.., .. , 1..LEN( RESULT, 2 ) - 2] := DECMUL(0.5, sf[.., .. , 0..LEN( RESULT, 2 ) - 3]);(*! but, INCMUL may not be part of FoxArrayOptimized SSE procedures => slower ??*)

			RESULT[.., .., 0]:= sf[.., ..,1]-sf[..,..,0];
			RESULT[..,..,LEN(RESULT,2)-1]:=sf[..,.. ,LEN( sf, 2 ) - 1]-sf[..,.. ,LEN( sf, 2 ) - 2];
		| nearestneighbour:
			RESULT[..,.., 1..LEN(sf,2)-2] := sf[.., .., 2..]-sf[.., .. LEN(sf,2)-3];
			RESULT[..,..,0]:=RESULT[..,..,1]; RESULT[..,.., LEN(sf,2)-1]:=RESULT[..,.., LEN(sf,2)-2];(*simplistic boundary handling*)
			RESULT:=0.5*RESULT;
	ELSE HALT(100);
		(*VolumeBase.Handle3D(sf,RESULT,{toSpline,derivative,fromSpline},{2}, boundary); *)
	END;
	RETURN RESULT
END dx;

PROCEDURE dy* (CONST sf:ScalarField; sampling:SIGNED32): ScalarField;
BEGIN
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2)) END;
	CASE sampling OF
	centered:
			RESULT[.. , 1..LEN( RESULT, 1 ) - 2] := 0.5 * sf[.. , 2..LEN( RESULT, 1 ) - 1];
			(*RESULT[ .. , 1..LEN( RESULT, 1 ) - 2] := RESULT[ .. , 1..LEN( RESULT, 1 ) - 2] - 0.5 * sf[.. , 0..LEN( RESULT, 1 ) - 3];*)
			RESULT[ .. , 1..LEN( RESULT, 1 ) - 2] := DECMUL(0.5, sf[.. , 0..LEN( RESULT, 1 ) - 3]);(*! but, INCMUL may not be part of FoxArrayOptimized SSE procedures => slower ??*)
			RESULT[ .., 0]:= sf[..,1]-sf[..,0];
			RESULT[ .., LEN(RESULT,1)-1]:=sf[.. ,LEN( sf, 1 ) - 1]-sf[.. ,LEN( sf, 1 ) - 2];
	|nearestneighbour:
		RESULT[.., 1..LEN(sf,1)-2] := sf[..,2..]-sf[.., .. LEN(sf,1)-3];
		RESULT[..,0]:=RESULT[..,1];
		RESULT[.., LEN(sf,1)-1]:=RESULT[.., LEN(sf,1)-2]; (*simplistic boundary handling*)
	ELSE HALT(100)
	END;
	RESULT:=0.5*RESULT;
	 RETURN RESULT
END dy;

PROCEDURE dz* (CONST sf:ScalarField; sampling:SIGNED32): ScalarField;
BEGIN
	IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2)) END;
	CASE sampling OF
	centered:
		RESULT[ 1..LEN( RESULT, 0 ) - 2] := 0.5 * sf[ 2..LEN( RESULT, 0 ) - 1];
		(*RESULT[1..LEN( RESULT, 0 ) - 2] := RESULT[1..LEN( RESULT, 0 ) - 2] - 0.5 * sf[ 0..LEN( RESULT, 0 ) - 3];*)
		RESULT[1..LEN( RESULT, 0 ) - 2] := DECMUL(0.5, sf[ 0..LEN( RESULT, 0 ) - 3]);(*! but, INCMUL may not be part of FoxArrayOptimized SSE procedures => slower ??*)
		RESULT[ 0]:= sf[1]-sf[0];
		RESULT[LEN(RESULT,0)-1]:=sf[LEN( sf, 0 ) - 1]-sf[LEN( sf, 0 ) - 2];
	|nearestneighbour:
		RESULT[1..LEN(sf,0)-2] := sf[2..]-sf[..LEN(sf,0)-3];
		RESULT[0]:=RESULT[1]; RESULT[ LEN(sf,0)-1]:=RESULT[ LEN(sf,0)-2]; (*simplistic boundary handling*)
	ELSE HALT(100);
	END;
	RESULT:=0.5*RESULT;
	RETURN RESULT
END dz;

PROCEDURE Grad* (CONST sf:ScalarField; sampling:SIGNED32):VectorField;
BEGIN
	IF  LEN(RESULT,0)=0 THEN NEW(RESULT, 3, LEN(sf,0), LEN(sf,1), LEN(sf,2)); END;
	RESULT[x,..,..,..]:=dx(sf, sampling);
	RESULT[y,..,..,..]:=dy(sf, sampling);
	RESULT[z,..,..,..]:=dz(sf, sampling);
	RETURN RESULT
END Grad;

(* u dot grad sf *) (* corresponds to "advective derivative" or "material derivative"*)
(*directional derivative is derivative along u; corresponds to inner product of partial derivative with vector u = <d/dx, d/dy, d/dz> * <ux, uy, uz>  *)
PROCEDURE DirectionalDerivative*(CONST sf:ScalarField; CONST u: VectorField; sampling:SIGNED32):ScalarField;
BEGIN
	RESULT:=u[x].*dx(sf, sampling);
	RESULT:=RESULT + u[y].*dy(sf, sampling);
	RESULT:=RESULT + u[z].*dz(sf, sampling);
	RETURN RESULT
END DirectionalDerivative;

(** Divergence operator *)
PROCEDURE Div*(CONST vf:VectorField; sampling:SIGNED32):ScalarField;
BEGIN
	IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(vf,1), LEN(vf,2), LEN(vf,3)) END;
	RESULT:=dx(vf[x,..,..,..],sampling);
	RESULT:=RESULT+dy(vf[y,..,..,..], sampling);
	RESULT:=RESULT+dz(vf[z,..,..,..], sampling);
	RETURN RESULT;
END Div;

(** Rotation or Curl operator *)
PROCEDURE Rot* (CONST vf: VectorField; sampling:SIGNED32): VectorField;
BEGIN
	IF  LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(vf)); END;
	RESULT[x,..,..,..]:=dy(vf[x,..,..,..], sampling) - dz(vf[x,..,..,..], sampling);
	RESULT[y,..,..,..]:=dz(vf[y,..,..,..], sampling) - dx(vf[y,..,..,..], sampling);
	RESULT[z,..,..,..]:=dx(vf[z,..,..,..], sampling) - dy(vf[z,..,..,..], sampling);
	RETURN RESULT
END Rot;

(**  Laplacian Operator, see  http://en.wikipedia.org/wiki/Laplace_operator *)
PROCEDURE Laplacian*(CONST sf:ScalarField; sampling:SIGNED32): ScalarField;
BEGIN
	IF  LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(sf)); END;
	RESULT:=dx(dx(sf, sampling),sampling);
	RESULT:=RESULT+dy(dy(sf, sampling),sampling);
	RESULT:=RESULT+dz(dz(sf, sampling),sampling);
	RETURN RESULT
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
In a sense, both the gradient and Jacobian are "first derivatives" . the former the first derivative of a scalar function of several variables,
the latter the first derivative of a vector function of several variables.
In general, the gradient can be regarded as a special version of the Jacobian: it is the Jacobian of a scalar function of several variables.
*)
PROCEDURE Jacobian*(CONST vf:VectorField; sampling:SIGNED32):TensorField; (** == TensorDerivative *)
BEGIN
	IF LEN(RESULT,0)=0 THEN NEW(RESULT,3, 3, LEN(RESULT,1), LEN(RESULT,2), LEN(RESULT,3)) END;
	RESULT[x,..,..,..,..] := Grad(vf[x], sampling);
	RESULT[y,..,..,..,..] := Grad(vf[y], sampling);
	RESULT[z,..,..,..,..] := Grad(vf[z], sampling);
	RETURN RESULT;
END Jacobian;

(*
The Hessian matrix (or simply the Hessian) is the square matrix of second-order partial derivatives of a scalar function;
that is, it describes the local curvature of a function of many variables.
*)
PROCEDURE Hessian*(CONST sf:ScalarField; sampling:SIGNED32):TensorField;
BEGIN
	RETURN Jacobian(Grad(sf, sampling),sampling);
END Hessian;


(** Laplacian of Vector Field, see http://en.wikipedia.org/wiki/Vector_Laplacian *)
PROCEDURE VectorLaplacian*(CONST vf:VectorField; sampling:SIGNED32): VectorField;
BEGIN
 IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(vf,0), LEN(vf,1), LEN(vf,2), 3); END;
 RESULT[x,..,..,..] := Laplacian(vf[x,..,..,..], sampling);
 RESULT[y,..,..,..] := Laplacian(vf[y,..,..,..], sampling);
 RESULT[z,..,..,..] := Laplacian(vf[z,..,..,..], sampling);
 RETURN RESULT
END VectorLaplacian;

(*
Hessian for a vector-valued function: the array of second partial derivatives is not a two-dimensional matrix of size n \times n,
but rather a tensor of order 3.
This can be thought of as a multi-dimensional array with dimensions m \times n \times n, which degenerates to the usual Hessian matrix for m = 1.
*)

PROCEDURE VectorHessian*(CONST vf: VectorField; sampling:SIGNED32): TensorField; (* HALT: this is not yet correct, because tensor has diffferent shape than current tensorfield ! *)
BEGIN
 HALT (200);
END VectorHessian;

END VolumeNabla.

System.FreeDownTo VolumeNabla ~
