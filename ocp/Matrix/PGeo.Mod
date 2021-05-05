MODULE PGeo; (*author:"Patrick Hunziker, 2003-2020" Purpose "some geometric utility functions"*)
IMPORT Mathe:=MathL, PMath;

CONST pi=Mathe.pi;

TYPE Datatype=REAL;

(** distance of  points A and B *)
PROCEDURE DistanceofPoints*(Ax,Ay,Bx,By:Datatype):Datatype;
BEGIN
	RETURN Mathe.sqrt((Bx-Ax)*(Bx-Ax)+(By-Ay)*(By-Ay))
END DistanceofPoints;


(** distance of point C from line defined by points A and B 
Formeln & Tafeln, Orell Fuessli, Zurich 1977, p 68*)
PROCEDURE DistancePointfromLine*(Ax,Ay,Bx,By,Cx,Cy:Datatype):Datatype;
VAR m,q:Datatype;
BEGIN
	IF Ax=Bx THEN RETURN Cx-Ax	(*vertical line*)
	ELSIF Ay=By THEN RETURN Cy-Ay	(*horizontal line*)
	ELSE
		m:=(By-Ay)/(Bx-Ax);
		q:=Ay-m*Ax;
		RETURN ABS(-m*Cx+Cy-q)/Mathe.sqrt(m*m+1);
	END;
END DistancePointfromLine;

PROCEDURE PointOnLine*;
END PointOnLine;

PROCEDURE PointInTriangle(Vx,Vy,Ax,Ay,Bx,By,Cx,Cy:Datatype):BOOLEAN;
VAR a,b,c,d0,d1,d2: Datatype;
BEGIN
(*
  /* is T1 completly inside T2? */          \
  /* check if V0 is inside tri(U0,U1,U2) */ \
  a=U1[i1]-U0[i1];                          \
  b=-(U1[i0]-U0[i0]);                       \
  c=-a*U0[i0]-b*U0[i1];                     \
  d0=a*V0[i0]+b*V0[i1]+c;                   \
                                            \
  a=U2[i1]-U1[i1];                          \
  b=-(U2[i0]-U1[i0]);                       \
  c=-a*U1[i0]-b*U1[i1];                     \
  d1=a*V0[i0]+b*V0[i1]+c;                   \
                                            \
  a=U0[i1]-U2[i1];                          \
  b=-(U0[i0]-U2[i0]);                       \
  c=-a*U2[i0]-b*U2[i1];                     \
  d2=a*V0[i0]+b*V0[i1]+c;                   \
  if(d0*d1>0.0)                             \
  {                                         \
    if(d0*d2>0.0) return 1;                 \
  }                                         \
}

*)
END PointInTriangle;



PROCEDURE LineNormal*(Ax,Ay,Bx,By: Datatype; VAR Cx,Cy:Datatype);	(** A: first point, B: second point defining line; c is unit vector *)
VAR len:Datatype;
BEGIN
	Cx:=-(By-Ay); Cy:=Bx-Ax;
	len:=Mathe.sqrt(Cx*Cx+Cy*Cy);
	IF len=0 THEN RETURN END;
	Cx:=Cx/len; Cy:=Cy/len;
END LineNormal;

PROCEDURE CircleArea*(r:Datatype):Datatype;
BEGIN
	RETURN r*r*Mathe.pi
END CircleArea;

PROCEDURE SphereVolume*(r: Datatype):Datatype;
BEGIN
	RETURN 4/3*pi * r * r * r;
END SphereVolume;

PROCEDURE SphereSurface*(r:Datatype):Datatype;
BEGIN
	RETURN 4*pi*r * r;
END SphereSurface;

PROCEDURE SphereRadiusFromVolume*(vol:Datatype):Datatype;
BEGIN
	RETURN PMath.powerL(vol/4*3/pi, 1/3);
END SphereRadiusFromVolume;

(* TO DO:
-see ScalarCurvature, Mean Curvature, Gaussian Curvature, ...
PROCEDURE SphereCurvature(r:Datatype):Datatype;
BEGIN
	RETURN 
END SphereCurvature;
*)

(* using radius defined as center-to-corner distance in regular hexagon*)
PROCEDURE HexagonArea*(r:Datatype):Datatype; 
BEGIN
	RETURN 2.598076211* r * r; (* 3/2*sqrt(3) * sqr(r) *)
END HexagonArea;

PROCEDURE HexagonalPrismVol*(radius,height:Datatype):Datatype;
VAR A:Datatype;
BEGIN
	RETURN 2.598076211 * radius * radius * height; (* HexagonArea(r) * h*)
END HexagonalPrismVol;

PROCEDURE HexagonalPrismRadius*(volume,height:Datatype):Datatype;
VAR A:Datatype;
BEGIN
	RETURN Mathe.sqrt(volume/height/2.598076211)
END HexagonalPrismRadius;

(* valid for pyramids and cones *)
PROCEDURE PyramidVolume*(Area, height:Datatype):Datatype;
BEGIN
	RETURN Area*height/3
END PyramidVolume;

(* a frustum is a solid pyramid or cone clipped by two plane*)
(* assumption: parallel planes with area A1,A2 on top and bottom *)
PROCEDURE FrustumVol*(A1,A2,h:Datatype):Datatype;
BEGIN
	RETURN h/3*(A1+Mathe.sqrt(A1*A2)+A2)
END FrustumVol;

(** Volume of cone slice with height h, upper surface radius r1 and lower surface radius r2;
Formeln & Tafeln, Orell Fuessli, Zurich 1977, p 68*)
PROCEDURE CircularFrustumVol*(r1,r2,h:Datatype):Datatype;
VAR G,D:Datatype;
BEGIN
	G:=r1*r1*Mathe.pi; D:=r2*r2*Mathe.pi;
	RETURN h/3*(G+Mathe.sqrt(G*D)+D)
END CircularFrustumVol;

PROCEDURE Rotate*(X,Y,angle:Datatype; VAR x,y:Datatype);	(** rotation of point  X,Y around Zero by angle *)
BEGIN
	x:=X*Mathe.cos(angle)-Y*Mathe.sin(angle);
	y:=X*Mathe.sin(angle)+Y*Mathe.cos(angle);
END Rotate;

PROCEDURE Dot*(Ax,Ay,Bx,By:Datatype):Datatype; (** scalar product between to vectors *)
BEGIN
	RETURN Ax*Bx+Ay*By 
END Dot;

PROCEDURE Length*(X,Y:Datatype):Datatype; (** Length of vector *)
BEGIN
	RETURN Mathe.sqrt(X*X+Y*Y)
END Length;

PROCEDURE Normalize*(VAR X,Y:Datatype);
VAR len: Datatype;
BEGIN
	len:=Length(X,Y);
	IF len>0 THEN X:=X/len; Y:=Y/len 
	END;
END Normalize;

PROCEDURE CosAngle*(Ax,Ay,Bx,By:Datatype):Datatype; (** angle between to vectors *)
BEGIN
	RETURN Dot(Ax,Ay,Bx,By)/Length(Ax,Ay)/Length(Bx,By)
END CosAngle;

PROCEDURE Projection*(Ax,Ay,Bx,By:Datatype; VAR Cx,Cy:Datatype); (** vector C is projection of vector B on vector A *)
VAR length: Datatype;
BEGIN
	length:=Length(Ax,Ay);
	IF length=0 THEN 
		Cx:=0; Cy:=0
	ELSE
		length:=Dot(Ax,Ay,Bx,By)/length/length;
		Cx:=Ax*length;
		Cy:=Ay*length;
	END;
END Projection;

PROCEDURE ProjectionToPointRadial*(Ax,Ay,Bx,By,Cx,Cy:Datatype):Datatype; 
(* projection of vector BC to normalized vector AB/length(AB) *)
VAR length: Datatype;
BEGIN
	Cx := Cx - Bx;
	Cy := Cy -  By;
	Bx := Bx - Ax;
	By := By -  Ay;
	length:=Length(Bx,By);
	
	IF length=0 THEN
		RETURN Length(Cx,Cy);	
	ELSE
		RETURN Dot(Bx,By,Cx,Cy)/length;		
	END;
END ProjectionToPointRadial;

PROCEDURE ProjectionToPointTangential*(Ax,Ay,Bx,By,Cx,Cy:Datatype):Datatype; 
(* projection of vector BC to normalized vector AB/length(AB) that is rotated by +90 degree *)
VAR length: Datatype;
BEGIN
	Cx := Cx - Bx;
	Cy := Cy -  By;
	Bx := Bx - Ax;
	By := By -  Ay;
	length:=Length(Bx,By);
	
	IF length=0 THEN
		RETURN 0;	
	ELSE
		RETURN Dot(-By,Bx,Cx,Cy)/length;		
	END;
END ProjectionToPointTangential;

PROCEDURE ProjectionToLineNormal*(Ax,Ay,Bx,By,Cx,Cy,Dx,Dy:Datatype):Datatype; 
								(**  (scalar) is projection of vector CD to normal of Line AB (normals point away from line AB) *)
VAR U1, U2, LineSlope: Datatype;
BEGIN
	(* shift origin of coordinate system to (Ax, Ay) *)
	Bx := Bx - Ax; 
	By := By - Ay;
	Cx := Cx - Ax; 
	Cy := Cy - Ay;
	Dx := Dx - Ax; 
	Dy := Dy - Ay;
	IF (Bx # 0) THEN (* Line AB is not parallel to y-axis *)
		IF (Bx < 0) THEN
			Bx := -Bx;
			By := -By;
		END;
		LineSlope := By / Bx; 	
		IF (Cy > LineSlope * Cx) THEN
			U1 := -By; (* rotate by + 90 degree *)
			U2 := Bx;
		ELSE
			U1 := By;  (* rotate by -90 degree *)
			U2 := -Bx;
		END;
		RETURN ((Dx-Cx) * U1 + (Dy-Cy) * U2) / Length(Bx,By);
	ELSE (*  Line AB is parallel to y-axis *)
		IF (Cx < 0) THEN
			RETURN -(Dx-Cx);
		ELSE
			RETURN (Dx-Cx);
		END;
	END;
END ProjectionToLineNormal;

PROCEDURE ProjectionToLineParallel*(Ax,Ay,Bx,By,Cx,Cy,Dx,Dy:Datatype):Datatype; 
								(**  (scalar) is projection of vector CD to Line AB (line is oriented in +y direction) *)
VAR length, U1, U2, LineSlope: Datatype;
BEGIN
	(* shift origin of coordinate system to (Ax, Ay) *)
	Bx := Bx - Ax; 
	By := By - Ay;
	length := Length(Bx, By);
	IF (length # 0) THEN (* Line AB is not a single point *)
		IF (By < 0) THEN
			Bx := -Bx;
			By := -By;
		END;
		RETURN (Bx * (Dx - Cx) + By * (Dy - Cy)) / length;
	ELSE
		RETURN 0;		
	END;
END ProjectionToLineParallel;

(*
PROCEDURE Test*;
BEGIN
	(* Out.String("projection to point is "); Out.Real(ProjectionToPointRadial(1,0,  1,0,   0,1), 10);Out.Ln; *)
	Out.String("projection to line is "); Out.Real(ProjectionToLineNormal(56,16,  56,78,   12,90,  15,90), 10);Out.Ln;
END Test;
*)
	
END PGeo.

SystemTools.FreeDownTo PGeo ~
PGeo.Test