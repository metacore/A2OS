		MODULE srVoxel2;
IMPORT srBase, Random, srVoxel, srE, Out := KernelLog;

CONST POS = TRUE;
CONST NEG = FALSE;

TYPE SREAL=srBase.SREAL;
TYPE Ray=srBase.Ray;
TYPE Voxel = srBase.Voxel;
TYPE AR2* = ARRAY 2,2,2 OF Voxel;
TYPE AR3* = ARRAY 3,3,3 OF Voxel;
TYPE AR5* = ARRAY 5,5,5 OF Voxel;
TYPE AR10* = ARRAY 10,10,10 OF Voxel;

TYPE NilVox*=OBJECT(Voxel);
PROCEDURE Shade*(VAR ray: Ray);
VAR drx, dry, drz: SREAL;
	di, dj, dk: BOOLEAN;
	dx, dy, dz: SREAL;
BEGIN
	IF ray.dxyz.x < 0 THEN di := NEG  ELSE di := POS END;
	IF ray.dxyz.y < 0 THEN dj := NEG  ELSE dj := POS END;
	IF ray.dxyz.z< 0 THEN dk := NEG  ELSE dk := POS END;
	dx := ray.dxyz.x*ray.scale;
	dy := ray.dxyz.y*ray.scale;
	dz := ray.dxyz.z*ray.scale;
	IF di  THEN
		drx :=  (1- ray.lxyz.x) / dx
	ELSE
		drx := -ray.lxyz.x/ dx
	END;
	IF dj THEN
		dry := ( 1 - ray.lxyz.y) / dy
	ELSE
		dry := -ray.lxyz.y/dy
	END;
	IF dk THEN
		drz := (1 - ray.lxyz.z)/dz
	ELSE
		drz := -ray.lxyz.z/dz
	END;
	IF (drx < dry) THEN
		IF (drx < drz ) THEN
			IF di THEN ray.face := 1 ELSE ray.face := 4 END;
			ray.lxyz.x := ray.lxyz.x + drx * ray.dxyz.x * ray.ddxyz.x;
			ray.lxyz.y := ray.lxyz.y + drx * ray.dxyz.y * ray.ddxyz.y;
			ray.lxyz.z := ray.lxyz.z + drx * ray.dxyz.z * ray.ddxyz.z;
		ELSE
			IF dk THEN ray.face := 3 ELSE ray.face := 6 END;
			ray.lxyz.x := ray.lxyz.x + drz * ray.dxyz.x * ray.ddxyz.x;
			ray.lxyz.y := ray.lxyz.y + drz * ray.dxyz.y * ray.ddxyz.y;
			ray.lxyz.z  := ray.lxyz.z + drz * ray.dxyz.z* ray.ddxyz.z;
		END
	ELSIF (dry < drz) THEN
		IF dj  THEN ray.face := 2 ELSE ray.face := 5 END;
		ray.lxyz.x := ray.lxyz.x + dry * ray.dxyz.x * ray.ddxyz.x;
		ray.lxyz.y := ray.lxyz.y + dry * ray.dxyz.y * ray.ddxyz.y;
		ray.lxyz.z  := ray.lxyz.z+ dry * ray.dxyz.z * ray.ddxyz.z
	ELSE
		IF dk  THEN ray.face := 3 ELSE ray.face := 6 END;
		ray.lxyz.x := ray.lxyz.x + drz * ray.dxyz.x * ray.ddxyz.x;
		ray.lxyz.y := ray.lxyz.y + drz * ray.dxyz.y * ray.ddxyz.y;
		ray.lxyz.z  := ray.lxyz.z + drz * ray.dxyz.z  * ray.ddxyz.z;
	END;
END Shade;
END NilVox;

TYPE Bloc2* = OBJECT(Voxel);
VAR
	blox*: AR2;

PROCEDURE split*;
VAR
	a,b,c,d,e,f,g,h: Bloc2;
BEGIN
	NEW(a); NEW(b); NEW(c); NEW(d); NEW(e); NEW(f); NEW(g); NEW(h);
	blox[0,0,0] := a;
	blox[0,0,1] := b;
	blox[0,1,0] := b;
	blox[0,1,1] := d;
	blox[1,0,0] := e;
	blox[1,0,1] := f;
	blox[1,1,0] := g;
	blox[1,1,1] := h;
END split;

PROCEDURE bounds* (i, j, k: SIGNED32; VAR out: BOOLEAN);
BEGIN
	IF (i < 0) OR (i > 1) OR (j < 0) OR (j > 1) OR (k < 0) OR (k > 1) THEN
		out := TRUE
	ELSE
		out := FALSE
	END
END bounds;

PROCEDURE turn;
VAR
	b: AR2;
BEGIN
	b[0,0,0] := blox[0,0,1];
	b[0,0,1] := blox[0,1,1];
	b[0,1,1] := blox[0,1,0];
	b[0,1,0] := blox[0,0,0];
	b[1,0,0] := blox[1,0,1];
	b[1,0,1] := blox[1,1,1];
	b[1,1,1] := blox[1,1,0];
	b[1,1,0] := blox[1,0,0];
	blox := b;
END turn;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	drx, dry, drz, dr: SREAL;
	iter, di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	ijk: srBase.IPT;
BEGIN
		oldxyz := ray.xyz;
		ray.scale := ray.scale/2;
		ray.xyz.x := ray.lxyz.x * 2- ray.ddxyz.x;
		ray.xyz.y := ray.lxyz.y * 2- ray.ddxyz.y;
		ray.xyz.z := ray.lxyz.z * 2- ray.ddxyz.z;
			iter := 0;
			srE.E(ray.xyz,ijk);
			bounds(ijk.i,ijk.j,ijk.k, out);
			IF ~out & (ray.a > 1/10) THEN
				v := blox[ijk.i,ijk.j,ijk.k];
				IF v # NIL THEN
					ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
					ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
					ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
					INC(ray.recursion);
					v.Shade(ray);
					DEC(ray.recursion)
				END
			END;
			IF  ~ray.changed THEN
				IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
				IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
				IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
				REPEAT
					IF di > 0 THEN
						drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
					ELSE
						drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
					END;
					IF dj > 0 THEN
						dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
					ELSE
						dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
					END;
					IF dk > 0 THEN
						drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
					ELSE
						drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
					END;
					IF (drx < dry) THEN
						IF (drx < drz ) THEN
							dr := drx;
							INC(ijk.i, di);
							IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
							ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
						ELSE
							dr := drz;
							INC(ijk.k, dk);
							IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
							ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
						END
					ELSIF (dry < drz) THEN
						dr := dry;
						INC(ijk.j, dj);
						IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
						ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
					ELSE
						dr := drz;
						INC(ijk.k, dk);
						IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
						ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
					END;
					bounds(ijk.i,ijk.j,ijk.k, out);
					IF ~out & (ray.a > 1/10) THEN
						v := blox[ijk.i,ijk.j,ijk.k];
						IF (v#NIL) THEN
							ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
							ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
							ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
							INC(ray.recursion);
							v.Shade(ray);
							DEC(ray.recursion);
						ELSE
							ray.a := ray.a - 0.1;
						END
					END;
				UNTIL   (ray.a < 0.1) OR out OR ray.changed;
			END;
		ray.xyz.x := oldxyz.x;
		ray.xyz.y := oldxyz.y;
		ray.xyz.z := oldxyz.z;
		ray.scale := ray.scale*2;
END Shade;


END Bloc2;

TYPE Bloc3* = OBJECT(Voxel);
VAR
	blox*: AR3;

PROCEDURE bounds* (i, j, k: SIGNED32; VAR out: BOOLEAN);
BEGIN
	IF (i < 0) OR (i > 2) OR (j < 0) OR (j > 2) OR (k < 0) OR (k > 2) THEN
		out := TRUE
	ELSE
		out := FALSE
	END
END bounds;

PROCEDURE flipx*;
VAR
	b: AR3 ;
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 2  DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		b[2-i,j,k] := blox[i,j,k];
	END END END;
		FOR i := 0 TO 2  DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i,j,k] := b[i,j,k];
	END END END;
END flipx;

PROCEDURE flipy*;
VAR
	b: AR3 ;
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 2  DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		b[i,2-j,k] := blox[i,j,k];
	END END END;
		FOR i := 0 TO 2  DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i,j,k] := b[i,j,k];
	END END END;
END flipy;

PROCEDURE flipz*;
VAR
	b: AR3 ;
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 2  DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		b[i,j,2-k] := blox[i,j,k];
	END END END;
		FOR i := 0 TO 2  DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i,j,k] := b[i,j,k];
	END END END;
END flipz;

PROCEDURE fill(v: Voxel);
VAR
	i,j,k: SIGNED16;
BEGIN
FOR i:=0 TO 2 DO FOR j:=0 TO 2 DO FOR k:=0 TO 2 DO
	blox[i,j,k]:=v
END END END
END fill;

PROCEDURE fillSerp*(v,w: Voxel);
BEGIN
	fill(v);
	blox[1,1,0]:=w;
	blox[1,0,1]:=w;
	blox[0,1,1]:=w;
	blox[1,1,1]:=w;
	blox[1,1,2]:=w;
	blox[1,2,1]:=w;
	blox[2,1,1]:=w;
END fillSerp;

PROCEDURE tick*;
VAR
	i, j, k, ii, jj, kk, n: SIGNED32;
	v: Voxel;
BEGIN
	n := rand.Dice(3);
	FOR i := 0 TO n DO
		i := rand.Dice(3);
		j := rand.Dice(3);
		k := rand.Dice(3);
		ii := rand.Dice(3);
		jj := rand.Dice(3);
		kk := rand.Dice(3);
		v := blox[i, j, k];
		blox[i, j, k] := blox[ii, jj, kk];
		blox[ii, jj, kk] := v;
	END;
END tick;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	ijk: srBase.IPT;
BEGIN
	IF ray.recursion>6 THEN
		ray.a :=0
	ELSE
		oldxyz := ray.xyz;
		ray.scale := ray.scale/3;
		ray.changed := FALSE;
		ray.xyz.x := ray.lxyz.x * 3 - ray.dxyz.x / 1000000;
		ray.xyz.y := ray.lxyz.y * 3 - ray.dxyz.y / 1000000;
		ray.xyz.z := ray.lxyz.z * 3 - ray.dxyz.z / 1000000;
			srE.E(ray.xyz,ijk);
			bounds(ijk.i,ijk.j,ijk.k, out);
			IF ~out & (ray.a > 1/10) THEN
				v := blox[ijk.i,ijk.j,ijk.k];
				IF v # NIL THEN
					ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
					ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
					ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
					v.Shade(ray);
				END
			END;
			IF ~ray.changed THEN REPEAT
				ray.changed := FALSE;
				IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
				IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
				IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
				REPEAT
					IF di > 0 THEN
						drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
					ELSE
						drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
					END;
					IF dj > 0 THEN
						dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
					ELSE
						dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
					END;
					IF dk > 0 THEN
						drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
					ELSE
						drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
					END;
					IF (drx < dry) THEN
						IF (drx < drz ) THEN
							INC(ijk.i, di);
							IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
							ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
						ELSE
							INC(ijk.k, dk);
							IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
							ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
						END
					ELSIF (dry < drz) THEN
						INC(ijk.j, dj);
						IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
						ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
					ELSE
						INC(ijk.k, dk);
						IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
						ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
					END;
					bounds(ijk.i,ijk.j,ijk.k, out);
					IF ~out & (ray.a > 1/10) THEN
						v := blox[ijk.i,ijk.j,ijk.k];
						IF (v# NIL) THEN
							ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
							ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
							ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
							INC(ray.recursion);
							v.Shade(ray);
							DEC(ray.recursion);
						END
					END;
				UNTIL   (ray.a < 0.1) OR out OR ray.changed;
			UNTIL   (ray.a < 0.1) OR out; END; (*end IF *)
		ray.xyz := oldxyz;
		ray.scale := ray.scale*3;
	END
END Shade;

PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL);
VAR
	ijk: srBase.IPT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	ray.xyz.x := ray.lxyz.x * 3;
	ray.xyz.y := ray.lxyz.y * 3 ;
	ray.xyz.z := ray.lxyz.z * 3 ;
	srE.E(ray.xyz,ijk);
		IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
		IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
		IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
		IF di > 0 THEN
			drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
		ELSE
			drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
		END;
		IF dj > 0 THEN
			dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
		ELSE
			dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
		END;
		IF dk > 0 THEN
			drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
		ELSE
			drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
		END;
		IF (drx < dry) THEN
			IF (drx < drz ) THEN
				INC(ijk.i, di);
				IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
				ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
			ELSE
				INC(ijk.k, dk);
				IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
				ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
			END
		ELSIF (dry < drz) THEN
			INC(ijk.j, dj);
			IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
			ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
	ELSE
			INC(ijk.k, dk);
			IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
			ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
	END;
	srE.E(ray.xyz,ijk);
	bounds(ijk.i,ijk.j,ijk.k, out);
	IF ~out THEN
		v := blox[ijk.i,ijk.j,ijk.k];
		IF v # NIL THEN
			ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
			ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
			ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
			v.probeShade(ray,dx,dy,dz);
		END
	END;
END probeShade;

END Bloc3;

TYPE Bloc5* = OBJECT(Voxel);
VAR
	blox*: AR5;
	airred, airgreen, airblue, airblack: SREAL;

PROCEDURE & init*;
BEGIN
	SetColor(0,0,0,1);
	complex:=TRUE;
END init;

PROCEDURE SetColor* (R, G, B, BL: SREAL);
BEGIN
	airred := R/5;
	airgreen := G/5;
	airblue := B/5;
	airblack :=  BL/5;
END SetColor;

PROCEDURE bounds* (i, j, k: SIGNED32; VAR out: BOOLEAN);
BEGIN
	IF (i < 0) OR (i > 4) OR (j < 0) OR (j > 4) OR (k < 0) OR (k > 4) THEN
		out := TRUE
	ELSE
		out := FALSE
	END
END bounds;

PROCEDURE fill*(v: Voxel);
VAR
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k:= 0 TO 4 DO
		blox[i,j,k] := v
	END END END
END fill;

(*PROCEDURE flipx*;
VAR
	b: AR3 ;
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 4  DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		b[2-i,j,k] := blox[i,j,k];
	END END END;
		FOR i := 0 TO 4  DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		blox[i,j,k] := b[i,j,k];
	END END END;
END flipx;

PROCEDURE flipy*;
VAR
	b: AR3 ;
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 4  DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		b[i,2-j,k] := blox[i,j,k];
	END END END;
		FOR i := 0 TO 4  DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		blox[i,j,k] := b[i,j,k];
	END END END;
END flipy;

PROCEDURE flipz*;
VAR
	b: AR3 ;
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 4  DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		b[i,j,2-k] := blox[i,j,k];
	END END END;
		FOR i := 0 TO 4  DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		blox[i,j,k] := b[i,j,k];
	END END END;
END flipz;*)

PROCEDURE Shade*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	ijk: srBase.IPT;
	drx, dry, drz, dr,rr,gr,br,bl: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	IF ray.recursion>6 THEN
		ray.a :=0
	ELSE
		oldxyz := ray.xyz;
		ray.scale := ray.scale/5;
		ray.xyz.x := ray.lxyz.x * 5  - ray.dxyz.x / 1000000 ;
		ray.xyz.y := ray.lxyz.y * 5  - ray.dxyz.y / 1000000 ;
		ray.xyz.z := ray.lxyz.z * 5  - ray.dxyz.z / 1000000 ;
		srE.E(ray.xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out & (ray.a > 1/10) THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF  v # NIL THEN
				ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
				ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
				ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
				v.Shade(ray);
			END
		END;
		REPEAT
			ray.changed := FALSE;
			IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
			IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
			IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
			REPEAT
				IF di > 0 THEN
					drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
				ELSE
					drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
				END;
				IF dj > 0 THEN
					dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
				ELSE
					dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
				END;
				IF dk > 0 THEN
					drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
				ELSE
					drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
				END;
				IF (drx < dry) THEN
					IF (drx < drz ) THEN
						dr := drx;
						INC(ijk.i, di);
						IF di > 0 THEN
							ray.face := 1; ray.normal:= srBase.Face[0]
						ELSE
							ray.face := 4; ray.normal:= srBase.Face[3]
						END;
						ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
					ELSE
						dr := drz;
						INC(ijk.k, dk);
						IF dk > 0 THEN
							ray.face := 3; ray.normal:= srBase.Face[2]
						ELSE
							ray.face := 6; ray.normal:= srBase.Face[5]
						END;
						ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
					END
				ELSIF (dry < drz) THEN
					dr := dry;
					INC(ijk.j, dj);
					IF dj > 0 THEN
						ray.face := 2; ray.normal:= srBase.Face[1]
					ELSE
						ray.face := 5; ray.normal:= srBase.Face[4]
					END;
					ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
				ELSE
					dr := drz;
					INC(ijk.k, dk);
					IF dk > 0 THEN
						ray.face := 3; ray.normal:= srBase.Face[2]
					ELSE
						ray.face := 6; ray.normal:= srBase.Face[5]
					END;
					ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
				END;
				rr := airred*dr; gr := airgreen*dr; br := airblue*dr; bl:=airblack*dr;
				ray.r := ray.r + rr*ray.a;
				ray.g:= ray.g + gr*ray.a;
				ray.b := ray.b + br*ray.a;
				ray.ra := ray.ra -rr - bl;
				ray.ga := ray.ga -gr -bl;
				ray.ba := ray.ba -br -bl;
				srBase.clamp3(ray.ra,ray.ga,ray.ba);
				ray.a := (ray.ra+ray.ga+ray.ba)/3;
				bounds(ijk.i,ijk.j,ijk.k, out);
				IF ~out & (ray.a > 1/10)THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v # NIL THEN
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						INC(ray.recursion);
						v.Shade(ray);
		(*				ray.length := ray.length + ray.scale;  don't calculate distance, just use 1 *)
						DEC(ray.recursion)
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
		ray.scale := ray.scale*5;
		ray.xyz := oldxyz;
	END
END Shade;

PROCEDURE probe*(x,y,z: SREAL):Voxel;
VAR
	X,Y,Z: SREAL;
	i,j,k: SIGNED32;
BEGIN
	srBase.clamp3(x,y,z);
	X := x*5; Y := y*5; Z := z*5;
	i := ENTIER(X);
	j := ENTIER(Y);
	k := ENTIER(Z);
	IF blox[i,j,k]=NIL THEN
		RETURN(NIL)
	ELSE
		RETURN(blox[i,j,k].probe(X-i, Y-j, Z-k))
	END
END probe;

PROCEDURE deathray*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	ijk: srBase.IPT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	killed: BOOLEAN;
BEGIN
	Out.String('..looking for something to kill..');
	oldxyz := ray.xyz;
	ray.scale := ray.scale/5;
	ray.xyz.x := ray.lxyz.x * 5  - ray.dxyz.x / 1000000 ;
	ray.xyz.y := ray.lxyz.y * 5  - ray.dxyz.y / 1000000 ;
	ray.xyz.z := ray.lxyz.z * 5  - ray.dxyz.z / 1000000 ;
	srE.E(ray.xyz,ijk);
	bounds(ijk.i,ijk.j,ijk.k, out);
	IF ~out THEN
		v := blox[ijk.i,ijk.j,ijk.k];
		IF  v # NIL THEN
			Out.String('..inside something..');
			IF v.complex THEN
				ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
				ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
				ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
				Out.String('..something complex..');
				v.deathray(ray);
				killed := TRUE
			END
		END
	END;
	IF ~killed THEN REPEAT
		IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
		IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
		IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
		REPEAT
			IF di > 0 THEN
				drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
			ELSE
				drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
			END;
			IF dj > 0 THEN
				dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
			ELSE
				dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
			END;
			IF dk > 0 THEN
				drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
			ELSE
				drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
			END;
			IF (drx < dry) THEN
				IF (drx < drz ) THEN
					INC(ijk.i, di);
					IF di > 0 THEN
						ray.face := 1; ray.normal:= srBase.Face[0]
					ELSE
						ray.face := 4; ray.normal:= srBase.Face[3]
					END;
					ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN
						ray.face := 3; ray.normal:= srBase.Face[2]
					ELSE
						ray.face := 6; ray.normal:= srBase.Face[5]
					END;
					ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
				END
			ELSIF (dry < drz) THEN
				INC(ijk.j, dj);
				IF dj > 0 THEN
					ray.face := 2; ray.normal:= srBase.Face[1]
				ELSE
					ray.face := 5; ray.normal:= srBase.Face[4]
				END;
				ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
			ELSE
				INC(ijk.k, dk);
				IF dk > 0 THEN
					ray.face := 3; ray.normal:= srBase.Face[2]
				ELSE
					ray.face := 6; ray.normal:= srBase.Face[5]
				END;
				ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
			END;
			bounds(ijk.i,ijk.j,ijk.k, out);
			IF ~out THEN
				v := blox[ijk.i,ijk.j,ijk.k];
				Out.String('nil ');
				IF v # NIL THEN
					IF v.complex THEN
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						Out.String('complex ');
						v.deathray(ray)
					ELSE
						Out.String('simple: killing ');
						blox[ijk.i,ijk.j,ijk.k] := NIL;
						srBase.deathflag:=TRUE;
					END;
					killed := TRUE;
				END
			END;
		UNTIL  killed OR out;
	UNTIL  killed OR out;
	END;
	ray.scale := ray.scale*5;
	ray.xyz := oldxyz;
	Out.Ln;
END deathray;


END Bloc5;

TYPE Bloc10* = OBJECT(Voxel);
VAR
	blox*: AR10;
	airred, airgreen, airblue, airblack: SREAL;

PROCEDURE & init*;
BEGIN
	SetColor(0,0,1,1/10);
	complex:=TRUE;
END init;

PROCEDURE SetColor* (R, G, B, BL: SREAL);
BEGIN
	airred := R/10;
	airgreen := G/10;
	airblue := B/10;
	airblack :=  BL/10;
END SetColor;

PROCEDURE fill*(v: Voxel);
VAR
	i,j,k: SIGNED16;
BEGIN
	FOR i:=0 TO 9 DO
		FOR j:=0 TO 9 DO
			FOR k:=0 TO 9 DO
				blox[i,j,k]:=v
			END
		END
	END
END fill;

(*PROCEDURE tick;
VAR
	i: SIGNED16;
BEGIN
	FOR i := 0 TO 100 DO tickit END
END tick;

PROCEDURE tickit;
VAR
	v: Voxel;
	a, b, c, d, e, f: SIGNED32;
BEGIN
	a := rand.Dice(10);
	b := rand.Dice(10);
	c := rand.Dice(10);
	d := rand.Dice(10);
	e := rand.Dice(10);
	f := rand.Dice(10);
	v := blox[a, b, 0];
	blox[a, b, c] := blox[d, e, f];
	blox[d, e, f] := v;
END tickit;*)

PROCEDURE bounds* (i, j, k: SIGNED32; VAR out: BOOLEAN);
BEGIN
	IF (i < 0) OR (i > 9) OR (j < 0) OR (j > 9) OR (k < 0) OR (k > 9) THEN
		out := TRUE
	ELSE
		out := FALSE
	END
END bounds;

PROCEDURE probe*(x,y,z: SREAL):Voxel;
VAR
	X,Y,Z: SREAL;
	i,j,k: SIGNED32;
BEGIN
	srBase.clamp3(x,y,z);
	X := x*10; Y := y*10; Z := z*10;
	i := ENTIER(X);
	j := ENTIER(Y);
	k := ENTIER(Z);
	IF blox[i,j,k]=NIL THEN
		RETURN(NIL)
	ELSE
		RETURN(blox[i,j,k].probe(X-i, Y-j, Z-k))
	END
END probe;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	ijk: srBase.IPT;
	drx, dry, drz, dr,rr,gr,br,bl: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	IF ray.recursion>6 THEN
		ray.a :=0
	ELSE
		oldxyz := ray.xyz;
		ray.scale := ray.scale/10;
		ray.xyz.x := ray.lxyz.x * 10  - ray.dxyz.x / 1000000 ;
		ray.xyz.y := ray.lxyz.y * 10  - ray.dxyz.y / 1000000 ;
		ray.xyz.z := ray.lxyz.z * 10  - ray.dxyz.z / 1000000 ;
		srE.E(ray.xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out & (ray.a > 1/10) THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF  v # NIL THEN
				ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
				ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
				ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
				v.Shade(ray);
			END
		END;
		REPEAT
			ray.changed := FALSE;
			IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
			IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
			IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
			REPEAT
				IF di > 0 THEN
					drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
				ELSE
					drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
				END;
				IF dj > 0 THEN
					dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
				ELSE
					dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
				END;
				IF dk > 0 THEN
					drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
				ELSE
					drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
				END;
				IF (drx < dry) THEN
					IF (drx < drz ) THEN
						dr := drx;
						INC(ijk.i, di);
						IF di > 0 THEN
							ray.face := 1; ray.normal:= srBase.Face[0]
						ELSE
							ray.face := 4; ray.normal:= srBase.Face[3]
						END;
						ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
					ELSE
						dr := drz;
						INC(ijk.k, dk);
						IF dk > 0 THEN
							ray.face := 3; ray.normal:= srBase.Face[2]
						ELSE
							ray.face := 6; ray.normal:= srBase.Face[5]
						END;
						ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
					END
				ELSIF (dry < drz) THEN
					dr := dry;
					INC(ijk.j, dj);
					IF dj > 0 THEN
						ray.face := 2; ray.normal:= srBase.Face[1]
					ELSE
						ray.face := 5; ray.normal:= srBase.Face[4]
					END;
					ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
				ELSE
					dr := drz;
					INC(ijk.k, dk);
					IF dk > 0 THEN
						ray.face := 3; ray.normal:= srBase.Face[2]
					ELSE
						ray.face := 6; ray.normal:= srBase.Face[5]
					END;
					ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
				END;
				rr := airred*dr; gr := airgreen*dr; br := airblue*dr; bl:=airblack*dr;
				ray.r := ray.r + rr*ray.a;
				ray.g:= ray.g + gr*ray.a;
				ray.b := ray.b + br*ray.a;
				ray.ra := ray.ra -rr - bl;
				ray.ga := ray.ga -gr -bl;
				ray.ba := ray.ba -br -bl;
				srBase.clamp3(ray.ra,ray.ga,ray.ba);
				ray.a := (ray.ra+ray.ga+ray.ba)/3;
				bounds(ijk.i,ijk.j,ijk.k, out);
				IF ~out & (ray.a > 1/10)THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v # NIL THEN
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						INC(ray.recursion);
						v.Shade(ray);
						ray.length := ray.length + ray.scale;  (*?? where should this go? *)
						DEC(ray.recursion)
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
		ray.scale := ray.scale*10;
		ray.xyz := oldxyz;
	END
END Shade;


PROCEDURE deathray*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	ijk: srBase.IPT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	killed: BOOLEAN;
BEGIN
	Out.String('..looking for something to kill..');
	oldxyz := ray.xyz;
	INC(ray.recursion);
	ray.scale := ray.scale/10;
	ray.xyz.x := ray.lxyz.x * 10  - ray.dxyz.x / 1000000 ;
	ray.xyz.y := ray.lxyz.y * 10  - ray.dxyz.y / 1000000 ;
	ray.xyz.z := ray.lxyz.z * 10  - ray.dxyz.z / 1000000 ;
	srE.E(ray.xyz,ijk);
	bounds(ijk.i,ijk.j,ijk.k, out);
	IF ~out THEN
		v := blox[ijk.i,ijk.j,ijk.k];
		IF  v # NIL THEN
			Out.String('..inside something..');
			IF v.complex THEN
				ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
				ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
				ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
				Out.String('..something complex..');
				v.deathray(ray);
				IF ray.changed THEN killed := TRUE END;
			END
		END
	END;
	IF ~killed THEN REPEAT
		IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
		IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
		IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
		REPEAT
			IF di > 0 THEN
				drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
			ELSE
				drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
			END;
			IF dj > 0 THEN
				dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
			ELSE
				dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
			END;
			IF dk > 0 THEN
				drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
			ELSE
				drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
			END;
			IF (drx < dry) THEN
				IF (drx < drz ) THEN
					INC(ijk.i, di);
					IF di > 0 THEN
						ray.face := 1; ray.normal:= srBase.Face[0]
					ELSE
						ray.face := 4; ray.normal:= srBase.Face[3]
					END;
					ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN
						ray.face := 3; ray.normal:= srBase.Face[2]
					ELSE
						ray.face := 6; ray.normal:= srBase.Face[5]
					END;
					ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
				END
			ELSIF (dry < drz) THEN
				INC(ijk.j, dj);
				IF dj > 0 THEN
					ray.face := 2; ray.normal:= srBase.Face[1]
				ELSE
					ray.face := 5; ray.normal:= srBase.Face[4]
				END;
				ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
			ELSE
				INC(ijk.k, dk);
				IF dk > 0 THEN
					ray.face := 3; ray.normal:= srBase.Face[2]
				ELSE
					ray.face := 6; ray.normal:= srBase.Face[5]
				END;
				ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
			END;
			bounds(ijk.i,ijk.j,ijk.k, out);
			IF ~out THEN
				v := blox[ijk.i,ijk.j,ijk.k];
				Out.String('nil ');
				IF v # NIL THEN
					IF FALSE (*v.complex*) THEN
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						Out.String('complex ');
						v.deathray(ray);
					ELSE
						Out.String('simple: killing ');
						blox[ijk.i,ijk.j,ijk.k] := NIL;
						ray.changed:= TRUE;
					END;
					IF ray.changed THEN killed := TRUE END;
				END
			END;
		UNTIL  killed OR out;
	UNTIL  killed OR out;
	END;
	ray.scale := ray.scale*10;
	ray.xyz := oldxyz;
	Out.Ln;
END deathray;

PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL);
VAR
	ijk: srBase.IPT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	ray.xyz.x := ray.lxyz.x * 10;
	ray.xyz.y := ray.lxyz.y * 10 ;
	ray.xyz.z := ray.lxyz.z * 10 ;
	srE.E(ray.xyz,ijk);
		IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
		IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
		IF ray.dxyz.z< 0 THEN dk := - 1  ELSE dk := 1 END;
		IF di > 0 THEN
			drx := ( (ijk.i + 1) - ray.xyz.x) / ray.dxyz.x
		ELSE
			drx :=  (ijk.i -  ray.xyz.x) / ray.dxyz.x
		END;
		IF dj > 0 THEN
			dry := ( (ijk.j + 1) - ray.xyz.y) / ray.dxyz.y
		ELSE
			dry :=  (ijk.j - ray.xyz.y) / ray.dxyz.y
		END;
		IF dk > 0 THEN
			drz := ( (ijk.k + 1) - ray.xyz.z) / ray.dxyz.z
		ELSE
			drz :=  (ijk.k - ray.xyz.z) / ray.dxyz.z
		END;
		IF (drx < dry) THEN
			IF (drx < drz ) THEN
				INC(ijk.i, di);
				IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
				ray.xyz.x := ray.xyz.x + drx * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drx * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drx * ray.dxyz.z
			ELSE
				INC(ijk.k, dk);
				IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
				ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
			END
		ELSIF (dry < drz) THEN
			INC(ijk.j, dj);
			IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
			ray.xyz.x := ray.xyz.x + dry * ray.dxyz.x; ray.xyz.y := ray.xyz.y + dry * ray.dxyz.y; ray.xyz.z  := ray.xyz.z+ dry * ray.dxyz.z
	ELSE
			INC(ijk.k, dk);
			IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
			ray.xyz.x := ray.xyz.x + drz * ray.dxyz.x; ray.xyz.y := ray.xyz.y + drz * ray.dxyz.y; ray.xyz.z  := ray.xyz.z + drz * ray.dxyz.z
	END;
	srE.E(ray.xyz,ijk);
	bounds(ijk.i,ijk.j,ijk.k, out);
	IF ~out THEN
		v := blox[ijk.i,ijk.j,ijk.k];
		IF v # NIL THEN
			ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
			ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
			ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
			v.probeShade(ray,dx,dy,dz);
		END
	END;
END probeShade;

END Bloc10;

VAR
	rand: Random.Generator;
	nil*: NilVox;
BEGIN
	NEW(rand);
	NEW(nil);
END srVoxel2.