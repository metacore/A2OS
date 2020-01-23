MODULE HypercubeNabla;	(**  AUTHOR "ph"; PURPOSE "";  **)
CONST
	x=0; y=1; z=2; t=3;
	projected=0;
TYPE
	Datatype* = FLOAT64;
	ScalarField* = ARRAY [*,*,*,*] OF Datatype;
	VectorField* = ARRAY [*,*,*,*,*] OF Datatype;
	TensorField* = ARRAY [?] OF Datatype;
	Field= ARRAY [*,*,*,*,*] OF Datatype; (* scalar & vector quantity at a point *)

PROCEDURE dx* (CONST sf:ScalarField; exact:BOOLEAN): ScalarField;	(*to do: implement exact computation*)
BEGIN
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2), LEN(sf,3)) END;
	IF TRUE (*~exact*) THEN
		RESULT[..,..,.., 1..LEN(sf,3)-2] := sf[..,.., .., 2..]-sf[..,..,.., .. LEN(sf,3)-3];
		RESULT[..,..,..,0]:=RESULT[..,..,..,1]; RESULT[..,..,.., LEN(sf,3)-1]:=RESULT[..,..,.., LEN(sf,3)-2];(*simplistic boundary handling*)
		RESULT:=RESULT/2;
	ELSE HALT(100);
		(*VolumeBase.Handle3D(sf,RESULT,{toSpline,derivative,fromSpline},{2}, boundary); *)
	END;
	RETURN RESULT
END dx;

PROCEDURE dy* (CONST sf:ScalarField; exact:BOOLEAN): ScalarField;
BEGIN
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2), LEN(sf,3)) END;
	RESULT[..,.., 1..LEN(sf,2)-2] := sf[..,..,2..]-sf[..,..,..LEN(sf,2)-3];
	RESULT[..,..,0]:=RESULT[..,..,1]; RESULT[..,.., LEN(sf,2)-1]:=RESULT[..,.., LEN(sf,2)-2]; (*simplistic boundary handling*)
	RESULT:=RESULT/2;
	 RETURN RESULT
END dy;

PROCEDURE dz* (CONST sf:ScalarField; exact:BOOLEAN): ScalarField;
BEGIN
	IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2), LEN(sf,3)) END;
	RESULT[..,1..LEN(sf,1)-2] := sf[..,2..]-sf[..,..LEN(sf,1)-3];
	RESULT[..,0]:=RESULT[..,1]; RESULT[ .., LEN(sf,1)-1]:=RESULT[ .., LEN(sf,1)-2]; (*simplistic boundary handling*)
	RESULT:=RESULT/2;
	RETURN RESULT
END dz;

PROCEDURE dt* (CONST sf:ScalarField; exact:BOOLEAN): ScalarField;
BEGIN
	IF LEN(RESULT)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2), LEN(sf,3)) END;
	RESULT[1..LEN(sf,0)-2] := sf[2..]-sf[..LEN(sf,0)-3];
	RESULT[0]:=RESULT[1]; RESULT[ LEN(sf,0)-1]:=RESULT[ LEN(sf,0)-2]; (*simplistic boundary handling*)
	RESULT:=RESULT/2;
	RETURN RESULT
END dt;


PROCEDURE Grad* (CONST sf:ScalarField; exact:BOOLEAN):VectorField;
BEGIN
	IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(sf,0), LEN(sf,1), LEN(sf,2), LEN(sf,3), 4); END;
	RESULT[x,..,..,..,..]:=dx(sf, exact);
	RESULT[y,..,..,..,..]:=dy(sf, exact);
	RESULT[z,..,..,..,..]:=dz(sf, exact);
	RESULT[t,..,..,..,..]:=dt(sf, exact);
	RETURN RESULT
END Grad;

(** Divergence operator *)
PROCEDURE Div*(CONST vf:VectorField; exact:BOOLEAN):ScalarField;
BEGIN
	RETURN dx(vf[x,..,..,..,..],exact) + dy(vf[y,..,..,..,..], exact) + dz(vf[z,..,..,..,..],exact) + dt(vf[t,..,..,..,..], exact);
END Div;

(*! MIXUP OF indices
(** Rotation or Curl operator *)
PROCEDURE Rot* (CONST vf: VectorField; exact:BOOLEAN): VectorField; (*this is incomplete/incorrect 4D rotation ...*)
BEGIN
	HALT(100); (*this is incomplete/incorrect 4D rotation ... -does Rot (i.e. cross product) exist in 4D ?)*)
	RESULT[x,..,..,..,..]:=dy(vf[..,..,..,..,z], exact) - dz(vf[..,..,..,..,y], exact);
	RESULT[y,..,..,..,..]:=dz(vf[..,..,..,..,x], exact) - dx(vf[..,..,..,..,z], exact);
	RESULT[z,..,..,..,..]:=dx(vf[..,..,..,..,y], exact) - dy(vf[..,..,..,..,x], exact);
	RESULT[t,..,..,..,..]:=dx(vf[..,..,..,..,y], exact) - dy(vf[..,..,..,..,x], exact);
	RETURN RESULT
END Rot;
*)

(**  Laplacian Operator, see  http://en.wikipedia.org/wiki/Laplace_operator *)
PROCEDURE Laplacian*(CONST sf:ScalarField; exact:BOOLEAN): ScalarField;
BEGIN
 RETURN dx(dx(sf, exact),exact) + dy(dy(sf, exact),exact) + dz(dz(sf, exact),exact) + dt(dt(sf, exact),exact)
END Laplacian;

(** Laplacian of Vector Field, see http://en.wikipedia.org/wiki/Vector_Laplacian *)
PROCEDURE VectorLaplacian*(CONST vf:VectorField; exact:BOOLEAN): VectorField;
BEGIN
 IF LEN(RESULT,0)=0 THEN NEW(RESULT, LEN(vf,0), LEN(vf,1), LEN(vf,2), LEN(vf,3), 4); END;
 RESULT[x,..,..,..,..] := Laplacian(vf[x,..,..,..,..], exact);
 RESULT[y,..,..,..,..] := Laplacian(vf[y,..,..,..,..], exact);
 RESULT[z,..,..,..,..] := Laplacian(vf[z,..,..,..,..], exact);
 RESULT[t,..,..,..,..] := Laplacian(vf[t,..,..,..,..], exact);
 RETURN RESULT
END VectorLaplacian;

(** http://en.wikipedia.org/wiki/Del   - not yet implemented *)
(* Del can also be applied to a vector field with the result being a tensor.
The tensor derivative of a vector field \vec{v} is a 9-term second-rank tensor, but can be denoted simply as \nabla \otimes \vec{v} , where \otimes represents the dyadic product.
This quantity is equivalent to the Jacobian matrix of the vector field with respect to space.
For a small displacement \delta \vec{r}, the change in the vector field is given by:   \delta \vec{v} = (\nabla \otimes \vec{v}) \sdot \delta \vec{r}
*)
PROCEDURE TensorDerivative*();
END TensorDerivative;
(*
In a sense, both the gradient and Jacobian are "first derivatives"  £ the former the first derivative of a scalar function of several variables,
the latter the first derivative of a vector function of several variables.
In general, the gradient can be regarded as a special version of the Jacobian: it is the Jacobian of a scalar function of several variables.
*)
PROCEDURE Jacobian*(CONST vf:VectorField; exact: BOOLEAN):TensorField; (** == TensorDerivative *)
END Jacobian;

(*
The Hessian matrix (or simply the Hessian) is the square matrix of second-order partial derivatives of a scalar function;
that is, it describes the local curvature of a function of many variables.
*)
PROCEDURE Hessian*(CONST sf:ScalarField; exact: BOOLEAN):TensorField;
VAR vf: VectorField;
BEGIN
	vf:= Grad(sf,exact);
	RETURN Jacobian(vf,exact)   (*!  does not compile*)
END Hessian;


END HypercubeNabla.
