MODULE srVoxel5;
IMPORT srBase, srVoxel;

TYPE SREAL=srBase.SREAL;
TYPE Ray = srBase.Ray;
TYPE Voxel = srBase.Voxel;

TYPE SwastiVox* = OBJECT(Voxel);
VAR
	r, g, b, br, bg, bb: SREAL;
	SW: ARRAY 8,8 OF CHAR;

(*
PROCEDURE & swastinit;
BEGIN
	SW[0] := "0000000";
	SW[1] := "0S0SSS0";
	SW[2] := "0SRSR00";
	SW[3] := "0SSSSS0";
	SW[4] := "00RSRS0";
	SW[5] := "0SSS0S0";
	SW[6] := "0000000";
END swastinit;
*)

PROCEDURE & swastinit*;
BEGIN
	SW[0] := "R0R0R0R";
	SW[1] := "0S0S0S0";
	SW[2] := "R0S0S0F";
	SW[3] := "0S0S0S0";
	SW[4] := "R0S0S0F";
	SW[5] := "0S0S0S0";
	SW[6] := "R0R0R0R";
END swastinit;

PROCEDURE SetSwastiColor* (red, green, blue : SREAL);
BEGIN
	r := srBase.clamp(red );
	g := srBase.clamp(green );
	b := srBase.clamp(blue );
END SetSwastiColor;
PROCEDURE SetBackColor* (red, green, blue : SREAL);
BEGIN
	br := srBase.clamp(red );
	bg := srBase.clamp(green );
	bb := srBase.clamp(blue );
END SetBackColor;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	lx, ly, dot: SREAL;
	i,j,nx,ny,nz: SIGNED32;
	inside, swastika: BOOLEAN;
BEGIN
	CASE ray.face OF
		0: inside := TRUE;
		| 1: lx := ray.lxyz.y; ly := ray.lxyz.z; nx := -1;
		|2: lx := ray.lxyz.x; ly := ray.lxyz.z; ny := -1;
		|3: lx := ray.lxyz.x; ly := ray.lxyz.y; nz := -1;
		|4: lx := ray.lxyz.y; ly := ray.lxyz.z; nx := 1;
		|5: lx := ray.lxyz.x; ly := ray.lxyz.z; ny := 1;
		|6: lx := ray.lxyz.x; ly := ray.lxyz.y;  nz := 1;
	ELSE
	END;
(* BUG: RARELY, I OR J GOES OUT OF BOUNDS BELOW WHEN THIS VOXEL
IS EMBEDDED IN A BLOC10. MAYBE BLOC10 HANDS DOWN AN LXYZ VALUE OVER 1
UNDER RARE CONDITIONS. ANYWAY IT CRASHES THE RENDERER; THE NEXT LINE IS A
HACK TO FIX IT *)
	IF lx >= 1 THEN lx := 0.9 END; IF ly >= 1 THEN ly := 0.9 END;
	IF inside THEN dot := 1 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END;
	i := ENTIER(lx*7); j := ENTIER(ly*7);
	IF SW[i,j] = 'R' THEN
		lx := lx*7-i; ly := ly*7-j;
		i := ENTIER(lx*7); j := ENTIER(ly*7);
		IF SW[i,j] = 'R' THEN
			lx := lx*7-i; ly := ly*7-j;
			i := ENTIER(lx*7); j := ENTIER(ly*7);
			IF SW[i,j] = 'S' THEN
				ray.r := ray.r + r*ray.ra*dot;
				ray.g := ray.g + g*ray.ga*dot;
				ray.b := ray.b + b*ray.ba*dot;
				ray.ra := 0; ray.ga := 0; ray.ba := 0;
				swastika := TRUE;
			END
		ELSIF SW[i,j] = 'S' THEN
			ray.r := ray.r + r*ray.ra*dot;
			ray.g := ray.g + g*ray.ga*dot;
			ray.b := ray.b + b*ray.ba*dot;
			ray.ra := 0; ray.ga := 0; ray.ba := 0;
			swastika := TRUE;
		END;
	ELSIF SW[i,j] = 'S' THEN
		ray.r := ray.r + r*ray.ra*dot;
		ray.g := ray.g + g*ray.ga*dot;
		ray.b := ray.b + b*ray.ba*dot;
		ray.ra := 0; ray.ga := 0; ray.ba := 0;
		swastika := TRUE;
	END;
	IF ~swastika THEN
		ray.r := ray.r + br*ray.ra*dot;
		ray.g := ray.g + bg*ray.ga*dot;
		ray.b := ray.b + bb*ray.ba*dot;
		ray.ra := 0; ray.ga := 0; ray.ba := 0;
	END
END Shade;
END SwastiVox;

TYPE Blinker = OBJECT(Voxel);
VAR varray: ARRAY 10 OF Voxel;

PROCEDURE &init*;
VAR
	x: srVoxel.TransparaVox;
	i: SIGNED16;
BEGIN
	FOR i := 0 TO 9 DO
		NEW(x);
		x.SetColor(1,0,1,(i+1)/10);
		varray[i] := x;
	END;
	register;
END init;

PROCEDURE Shade*(VAR ray: srBase.Ray);
BEGIN
	varray[srBase.frame MOD 10].Shade(ray);
END Shade;
END Blinker;

TYPE Blinker7 = OBJECT(Voxel);
VAR
	varray: ARRAY 7 OF Voxel;

PROCEDURE & init*;
VAR
	x: srVoxel.TransparaVox;
	i: SIGNED16;
BEGIN
	FOR i := 0 TO 6 DO
		NEW(x);
		x.SetColor(1,1/2,0,(i+1)/7);
		varray[i] := x;
	END;
	register;
END init;
END Blinker7;

TYPE Blinker13 = OBJECT(Voxel);
VAR
	varray: ARRAY 13 OF Voxel;

PROCEDURE & init*;
VAR
	x: srVoxel.TransparaVox;
	i: SIGNED16;
BEGIN
	FOR i := 0 TO 12 DO
		NEW(x);
		x.SetColor(1,1/2,1,(i+1)/13);
		varray[i] := x;
	END;
	register;
END init;


PROCEDURE Shade*(VAR ray: srBase.Ray);
BEGIN
	varray[srBase.frame MOD 13].Shade(ray);
END Shade;

END Blinker13;

VAR
	ff1*: Blinker;
	ff2*: Blinker7;
	ff3*: Blinker13;

BEGIN
	NEW(ff1); NEW(ff2); NEW(ff3);

END srVoxel5.