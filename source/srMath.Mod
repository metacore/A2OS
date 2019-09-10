MODULE srMath;
IMPORT Math, srBase;

TYPE SREAL=srBase.SREAL;

CONST
	R = 10000;
	N = 1000;
	twopi = 2*Math.pi;
	dx = twopi/R;
	dtp = twopi/N;

VAR
	Sin,Cos: ARRAY R OF SREAL;
	Norm: ARRAY N,N OF srBase.PT;
	i, j: SIGNED32;
	x, theta, phi: SREAL;

PROCEDURE sin*(x: SREAL): SREAL;
VAR i: SIGNED32;
BEGIN
	i := ENTIER(x/dx) MOD R;
	RETURN Sin[i];
END sin;

PROCEDURE cos*(x: SREAL): SREAL;
VAR i: SIGNED32;
BEGIN
	i := ENTIER(x/dx) MOD R;
	RETURN Cos[i];
END cos;

PROCEDURE norm*(theta, phi: SREAL):srBase.PT;
BEGIN
	i := ENTIER(theta/dtp) MOD N;
	j := ENTIER(phi/dtp) MOD N;
	RETURN Norm[i,j];
END norm;

PROCEDURE arccos*(x: SREAL): SREAL;
BEGIN
	RETURN(Math.arctan(Math.sqrt(ABS((1-x*x))/x)));
END arccos;

PROCEDURE orrot*(VAR a: srBase.PT; b: srBase.PT; theta: SREAL);

(* ROTATION OF VECTORS. A ABOUT B. A,B ARE POINTS ON THE UNIT SPHERE. *)
VAR
	costheta, sintheta: SREAL;
	x,y,z: SREAL;
	u,v,w: SREAL;
	uvula: SREAL;
BEGIN
	srBase.normalizePT(a);
	srBase.normalizePT(b);
	costheta := cos(theta); sintheta := sin(theta);
	x:=a.x; y:=a.y; z:=a.z;
	u:=b.x; w:=b.y; v:=b.z;
	uvula:= u*x+v*y+w*z;
	a.x := u*uvula + costheta*(x*(v*v+w*w)-u*(v*y+w*z))+ sintheta*(-w*y+v*z);
	a.y := v*uvula + costheta*(y*(u*u+w*w)-v*(u*x+w*z))+ sintheta*(w*x-u*z);
	a.z := w*uvula + costheta*(z*(u*u+v*v)-w*(u*x+v*y))+ sintheta*(-v*x+u*y);
END orrot;

BEGIN
	x := 0;
	FOR i := 0 TO R-1 DO
		Sin[i] := Math.sin(x);
		IF Sin[i] = 0 THEN Sin[i] := 0.0000001 END;  (* Because we must avoid ever dividing by zero *)
		Cos[i] := Math.cos(x);
		IF Cos[i] = 0 THEN Cos[i] := 0.0000001 END;	(* in shaders                                                  *)
		x := x+dx;
	END;
	FOR i := 0 TO N-1 DO
		theta := twopi*i/N;
		FOR j := 0 TO N-1 DO
			phi := twopi*j/N;
			Norm[i,j].x := cos(theta)*sin(phi);
			Norm[i,j].y := sin(theta)*sin(phi);
			Norm[i,j].z := cos(theta);
		END
	END
END srMath.