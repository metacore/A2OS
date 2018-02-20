MODULE srRotaVox;
IMPORT srBase, srMath, Math;

TYPE Voxel=srBase.Voxel;
TYPE PT=srBase.PT;
TYPE Ray=srBase.Ray;
TYPE SREAL=srBase.SREAL;

TYPE RVox*=OBJECT(Voxel);
VAR
	child: Voxel;
	phi: REAL; (* rotation angle about Z axis in radians *)
	dtick: REAL;
	center:PT;

PROCEDURE&init*(c:Voxel; dt: REAL);
BEGIN
	child:=c;
	dtick:=dt;
	register;
	center.x:=1/2; center.y:=1/2; center.z:=1/2;
END init;

PROCEDURE tick*;
BEGIN
	phi:=phi+dtick;
	IF phi > 6.2832 THEN phi:=0 END
END tick;

PROCEDURE d2(a,b:PT):SREAL;
BEGIN
	 RETURN((a.x-b.x)*(a.x-b.x)+ (a.y-b.y)*(a.y-b.y) + (a.z-b.z)*(a.z-b.z));
END d2;

PROCEDURE dia(a,b:PT):SREAL;
BEGIN
	 RETURN Math.sqrt((a.x-b.x)*(a.x-b.x)+ (a.y-b.y)*(a.y-b.y) + (a.z-b.z)*(a.z-b.z));
END dia;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	a,b,c,dxyz:PT;
	dc,x,y,z: REAL;
	i: INTEGER;
BEGIN
	(* advance ray to its intersection with the sphere of radius 1/2 centered in the voxel*)
	a:=ray.lxyz;
	b:= srBase.Exit(ray);
	c.x := (a.x+b.x)/2; c.y := (a.y+b.y)/2; c.z := (a.z + b.z)/2;
	FOR i := 0 TO 12 DO
		dc := d2(center,c);
		IF dc < 1/4 THEN
			b:=c;
		ELSE
			a:=c;
		END;
		c.x := (a.x+b.x)/2; c.y := (a.y+b.y)/2; c.z := (a.z + b.z)/2;
	END;
	dc := d2(center,c);
	IF ABS(dc-1/4)<0.001 THEN
		a.x:=(x-1/2)*2; a.y:=(y-1/2)*2; a.z:=(z-1/2)*2;      (* we know that the vector from (1/2,1/2,1/2) to (x,y,z) has length 1/2 so this translates and normalizeds it *)
		srMath.orrot(a,Zaxis,phi);
		a.x:=a.x/2+1/2; a.y:=a.y/2+1/2; a.z:=a.z/2+1/2;	(* denormalize and translate bacck*)
		ray.lxyz:=a;
		dxyz:=ray.dxyz;
		srMath.orrot(ray.dxyz,Zaxis,-phi);
		ray.normal:=ray.dxyz;
		child.Shade(ray);
		IF ~ray.changed THEN
			ray.dxyz:=dxyz

		ELSE		(* reflection or refraction. Must rotate back to enclosing coordinate system *)
					(* 2 B implemented *)
			ray.changed := FALSE;
			ray.dxyz:=dxyz
		END
	END;
END Shade;

END RVox;

VAR
	Zaxis: PT;
BEGIN
	Zaxis.z:=1;

END srRotaVox.