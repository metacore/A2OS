MODULE srVoxel3;
IMPORT srBase, srVoxel, srVoxel2, Random, srE;

VAR
	rand: Random.Generator;
	GO: BOOLEAN;
TYPE SREAL=srBase.SREAL;
TYPE Ray = srBase.Ray;
TYPE Voxel = srBase.Voxel;
TYPE Bloc3 = srVoxel2.Bloc3;
TYPE Bloc5 = srVoxel2.Bloc5;

TYPE Serp*=OBJECT(Voxel);
VAR
	core: SerpBloc;
PROCEDURE&init*(kore, mid: Voxel);
BEGIN
	NEW(core, kore, mid);
	passable := TRUE;
	core.passable := TRUE;
END init;

PROCEDURE probe*(x,y,z: SREAL):Voxel;
BEGIN
	core.containscamera := TRUE; (*never used*)
	RETURN core.probe(x,y,z);
END probe;

PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL);
BEGIN
	core.probeShade(ray,dx,dy,dz);
END probeShade;

PROCEDURE Shade*(VAR ray: Ray);
BEGIN
	core.Shade(ray);
END Shade;

PROCEDURE tick*;
(*BEGIN IF GO THEN core.tick END*)
END tick;

END Serp;

TYPE Tower*=OBJECT(Voxel);
VAR
	 core : SlantBloc;
PROCEDURE&init*(a,b,c: Voxel);
BEGIN
	NEW(core,a,b);
	passable := TRUE;
END init;

PROCEDURE Shade*(VAR ray: Ray);
BEGIN
	core.Shade(ray);
END Shade;

PROCEDURE tick*;
END tick;

END Tower;

TYPE SerpBloc = OBJECT(Bloc3);
VAR
	core: Voxel;
	containscamera : BOOLEAN;

PROCEDURE&init*(kore, mid: Voxel);
BEGIN
	Fill(SELF);
	SetMid(mid);
	core := kore;
	rlimit := 7;
END init;

PROCEDURE SetMid(v: Voxel);
BEGIN
	blox[0, 1, 1] := v;
	blox[1, 0, 1] := v;
	blox[1, 1, 0] := v;
	blox[1, 1, 1] := v;
	blox[2, 1, 1] := v;
	blox[1, 2, 1] := v;
	blox[1, 1, 2] := v;
END SetMid;

PROCEDURE Fill*(v: Voxel);
VAR
	i, j, k: SIGNED16;
BEGIN
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i, j, k] := v
	END END END;
END Fill;

PROCEDURE tick*;
(*
VAR
	v: Voxel;
	a, b, c, d, e, f: SIGNED32;
BEGIN
	a := rand.Dice(3);
	b := rand.Dice(3);
	c := rand.Dice(3);
	d := rand.Dice(3);
	e := rand.Dice(3);
	f := rand.Dice(3);
	v := blox[a, b, c];
	blox[a, b, c] := blox[d, e, f];
	blox[d, e, f] := v;
	rlimit := SHORT(rand.Dice(7)); *)
END tick;

PROCEDURE limit(VAR ray: Ray);
VAR
	dx,dy,dz, d2: SREAL;
BEGIN
	dx := ray.origin.x-ray.xyz.x;
	dy := ray.origin.y-ray.xyz.y;
	dz := ray.origin.z-ray.xyz.z;
	d2 := dx*dx+dy*dy+dz*dz;
	rlimit := 1;
	IF d2 < 2 THEN rlimit := 2
	ELSIF d2 < 1 THEN rlimit := 3
	ELSIF d2 < 1/2 THEN rlimit := 3
	ELSIF d2 < 1/4 THEN rlimit := 4
	END
END limit;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	oldxyz, xyz: srBase.PT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	ijk: srBase.IPT;
BEGIN
	INC(ray.recursion);
	oldxyz := ray.xyz;
	IF (ray.recursion < srBase.rlimit) & (ray.a > 0.1)  THEN
		ray.changed := FALSE;
		xyz.x := ray.lxyz.x*3 -  ray.ddxyz.x;
		xyz.y := ray.lxyz.y*3 - ray.ddxyz.y;
		xyz.z := ray.lxyz.z*3 - ray.ddxyz.z;
		ray.scale:= ray.scale/3;
		srE.E(xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out & (ray.a > 1/10) THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF v # NIL THEN
				ray.lxyz.x := ABS(xyz.x - ijk.i);
				ray.lxyz.y := ABS(xyz.y - ijk.j);
				ray.lxyz.z := ABS(xyz.z - ijk.k);
				v.Shade(ray);
			END
		END;
		IF ~ray.changed THEN REPEAT
			ray.changed := FALSE;
			IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
			IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
			IF ray.dxyz.z < 0 THEN dk := - 1  ELSE dk := 1 END;
			REPEAT
				IF di > 0 THEN
					drx := ( (ijk.i + 1) - xyz.x) / ray.dxyz.x
				ELSE
					drx :=  (ijk.i -  xyz.x) / ray.dxyz.x
				END;
				IF dj > 0 THEN
					dry := ( (ijk.j + 1) - xyz.y) / ray.dxyz.y
				ELSE
					dry :=  (ijk.j - xyz.y) / ray.dxyz.y
				END;
				IF dk > 0 THEN
					drz := ( (ijk.k + 1) - xyz.z) / ray.dxyz.z
				ELSE
					drz :=  (ijk.k - xyz.z) / ray.dxyz.z
				END;
				IF (drx < dry) THEN
				IF (drx < drz ) THEN
					INC(ijk.i, di);
					IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
					xyz.x := xyz.x + drx * ray.dxyz.x;
					xyz.y := xyz.y + drx * ray.dxyz.y;
					xyz.z  := xyz.z + drx * ray.dxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z
				END
			ELSIF (dry < drz) THEN
				INC(ijk.j, dj);
				IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
				xyz.x := xyz.x + dry * ray.dxyz.x;
				xyz.y := xyz.y + dry * ray.dxyz.y;
				xyz.z  := xyz.z+ dry * ray.dxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z
				END;
				ray.xyz.x := ray.xyz.x+ xyz.x/3;
				ray.xyz.y := ray.xyz.y + xyz.y/3;
				ray.xyz.z := ray.xyz.z + xyz.z/3;
				bounds(ijk.i,ijk.j,ijk.k, out);
				IF ~out & (ray.a > 0.1) THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v # NIL THEN
						ray.lxyz.x := ABS(xyz.x - ijk.i);
						ray.lxyz.y := ABS(xyz.y - ijk.j);
						ray.lxyz.z := ABS(xyz.z - ijk.k);
						v.Shade(ray);
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out; END; (* end IF *)
	ELSIF core # NIL THEN core.Shade(ray) END;
	ray.scale:=ray.scale*3;
	ray.xyz := oldxyz;
	DEC(ray.recursion);
END Shade;


PROCEDURE probe*(x,y,z: SREAL):Voxel;
BEGIN
(* RETURN(core); *)
	RETURN(NIL);
END probe;

PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL);
VAR
	oldxyz, xyz: srBase.PT;
	drx, dry, drz: SREAL;
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	ijk: srBase.IPT;
BEGIN
	IF (ray.recursion < srBase.rlimit) & (ray.a > 0.1)  THEN
		oldxyz := ray.xyz;
		ray.changed := FALSE;
		xyz.x := ray.lxyz.x * 3 + ray.dxyz.x / 1000000;
		xyz.y := ray.lxyz.y * 3 + ray.dxyz.y / 1000000;
		xyz.z := ray.lxyz.z * 3 + ray.dxyz.z / 1000000;
		srE.E(xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF v # NIL THEN
				ray.lxyz.x := ABS(xyz.x - ijk.i);
				ray.lxyz.y := ABS(xyz.y - ijk.j);
				ray.lxyz.z := ABS(xyz.z - ijk.k);
				v.probeShade(ray,dx,dy,dz);
			END
		END;
		REPEAT
			IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
			IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
			IF ray.dxyz.z < 0 THEN dk := - 1  ELSE dk := 1 END;
			REPEAT
				IF di > 0 THEN
					drx := ( (ijk.i + 1) - xyz.x) / ray.dxyz.x
				ELSE
					drx :=  (ijk.i -  xyz.x) / ray.dxyz.x
				END;
				IF dj > 0 THEN
					dry := ( (ijk.j + 1) - xyz.y) / ray.dxyz.y
				ELSE
					dry :=  (ijk.j - xyz.y) / ray.dxyz.y
				END;
				IF dk > 0 THEN
					drz := ( (ijk.k + 1) - xyz.z) / ray.dxyz.z
				ELSE
					drz :=  (ijk.k - xyz.z) / ray.dxyz.z
				END;
				IF (drx < dry) THEN
				IF (drx < drz ) THEN
					INC(ijk.i, di);
					IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
					xyz.x := xyz.x + drx * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drx * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drx * ray.dxyz.z + ray.ddxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z + ray.ddxyz.z
				END
			ELSIF (dry < drz) THEN
				INC(ijk.j, dj);
				IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
				xyz.x := xyz.x + dry * ray.dxyz.x + ray.ddxyz.x;
				xyz.y := xyz.y + dry * ray.dxyz.y + ray.ddxyz.y;
				xyz.z  := xyz.z+ dry * ray.dxyz.z + ray.ddxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z + ray.ddxyz.z
				END;
				ray.xyz.x := ray.xyz.x+ xyz.x/3;
				ray.xyz.y := ray.xyz.y + xyz.y/3;
				ray.xyz.z := ray.xyz.z + xyz.z/3;
				bounds(ijk.i,ijk.j,ijk.k, out);
				IF ~out & (ray.a > 0.1) THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v # NIL THEN
						ray.lxyz.x := ABS(xyz.x - ijk.i);
						ray.lxyz.y := ABS(xyz.y - ijk.j);
						ray.lxyz.z := ABS(xyz.z - ijk.k);
						v.probeShade(ray,dx,dy,dz);
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
	ray.xyz := oldxyz;
	ELSIF (core # NIL) & (ray.a > 1/10) THEN
(*		ray.lxyz := ray.slxyz; *)
			INC(ray.recursion);
			core.probeShade(ray,dx,dy,dz);
			DEC(ray.recursion);
	END;

END probeShade;

END SerpBloc;

(*TYPE cacheSerpBloc = OBJECT(Voxel);
VAR
	core, mid: Voxel;
	containscamera : BOOLEAN;
	blox: ARRAY 3,3,3 OF CHAR;

PROCEDURE&init(kore, mid: Voxel);
VAR
	i, j, k: SIGNED16;
BEGIN
	Fill('X');
	SetMid('M');
	core := kore;
	rlimit := 7;
END init;

PROCEDURE SetMid(v: Voxel);
VAR
	b3: Bloc3;
BEGIN
	blox[0, 1, 1] := v;
	blox[1, 0, 1] := v;
	blox[1, 1, 0] := v;
	blox[1, 1, 1] := v;
	blox[2, 1, 1] := v;
	blox[1, 2, 1] := v;
	blox[1, 1, 2] := v;
END SetMid;

PROCEDURE Fill*(v: Voxel);
VAR
	i, j, k: SIGNED16;
BEGIN
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i, j, k] := v
	END END END;
END Fill;
PROCEDURE tick;
VAR
	v: Voxel;
	a, b, c, d, e, f: SIGNED32;
BEGIN
	a := rand.Dice(3);
	b := rand.Dice(3);
	c := rand.Dice(3);
	d := rand.Dice(3);
	e := rand.Dice(3);
	f := rand.Dice(3);
	v := blox[a, b, c];
	blox[a, b, c] := blox[d, e, f];
	blox[d, e, f] := v;
	rlimit := SHORT(rand.Dice(7));
END tick;

PROCEDURE limit(VAR ray: Ray);
VAR
	dx,dy,dz, d2: SREAL;
BEGIN
	dx := ray.origin.x-ray.xyz.x;
	dy := ray.origin.y-ray.xyz.y;
	dz := ray.origin.z-ray.xyz.z;
	d2 := dx*dx+dy*dy+dz*dz;
	rlimit := 1;
	IF d2 < 2 THEN rlimit := 2
	ELSIF d2 < 1 THEN rlimit := 3
	ELSIF d2 < 1/2 THEN rlimit := 3
	ELSIF d2 < 1/4 THEN rlimit := 4
	END
END limit;

PROCEDURE Shade(VAR ray: Ray);
VAR
	oldxyz, xyz: srBase.PT;
	drx, dry, drz: SREAL;
	iter, di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	ijk: ARRAY 3 OF SIGNED16;
	lx, ly, lz, distance: SREAL;
BEGIN
	IF (ray.recursion < srBase.rlimit) & (ray.a > 0.1)  THEN
		oldxyz := ray.xyz;
		ray.changed := FALSE;
		xyz.x := ray.lxyz.x * 3 - ray.dxyz.x / 10000;
		xyz.y := ray.lxyz.y * 3 - ray.dxyz.y / 10000;
		xyz.z := ray.lxyz.z * 3 - ray.dxyz.z / 10000;
		srE.E(xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out & (ray.a > 1/10) THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF v # NIL THEN
				ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
				ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
				ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
				INC(ray.recursion);
				v.Shade(ray);
				DEC(ray.recursion);
			END
		END;
		REPEAT
			ray.changed := FALSE;
			IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
			IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
			IF ray.dxyz.z < 0 THEN dk := - 1  ELSE dk := 1 END;
			REPEAT
				IF di > 0 THEN
					drx := ( (ijk.i + 1) - xyz.x) / ray.dxyz.x
				ELSE
					drx :=  (ijk.i -  xyz.x) / ray.dxyz.x
				END;
				IF dj > 0 THEN
					dry := ( (ijk.j + 1) - xyz.y) / ray.dxyz.y
				ELSE
					dry :=  (ijk.j - xyz.y) / ray.dxyz.y
				END;
				IF dk > 0 THEN
					drz := ( (ijk.k + 1) - xyz.z) / ray.dxyz.z
				ELSE
					drz :=  (ijk.k - xyz.z) / ray.dxyz.z
				END;
				IF (drx < dry) THEN
				IF (drx < drz ) THEN
					INC(ijk.i, di);
					IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
					xyz.x := xyz.x + drx * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drx * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drx * ray.dxyz.z + ray.ddxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z + ray.ddxyz.z
				END
			ELSIF (dry < drz) THEN
				INC(ijk.j, dj);
				IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
				xyz.x := xyz.x + dry * ray.dxyz.x + ray.ddxyz.x;
				xyz.y := xyz.y + dry * ray.dxyz.y + ray.ddxyz.y;
				xyz.z  := xyz.z+ dry * ray.dxyz.z + ray.ddxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z + ray.ddxyz.z
				END;
				ray.xyz.x := ray.xyz.x+ xyz.x/3;
				ray.xyz.y := ray.xyz.y + xyz.y/3;
				ray.xyz.z := ray.xyz.z + xyz.z/3;
				bounds(ijk.i,ijk.j,ijk.k, out);
				IF ~out & (ray.a > 0.1) THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v # NIL THEN
						ray.lxyz.x := ABS(xyz.x - ijk.i);
						ray.lxyz.y := ABS(xyz.y - ijk.j);
						ray.lxyz.z := ABS(xyz.z - ijk.k);
						INC(ray.recursion);
						v.Shade(ray);
						DEC(ray.recursion)
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
	ELSIF core # NIL THEN core.Shade(ray) END;
	ray.xyz := oldxyz;
END Shade;


PROCEDURE probe(x,y,z: SREAL):Voxel;
VAR
	X,Y,Z: SREAL;
	i,j,k: SIGNED32;
BEGIN
 RETURN(core);
END probe;

PROCEDURE probeShade(VAR ray: Ray);
VAR
	oldxyz, xyz: srBase.PT;
	drx, dry, drz: SREAL;
	iter, di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	ijk: ARRAY 3 OF SIGNED16;
	lx, ly, lz, distance: SREAL;
BEGIN
	IF (ray.recursion < srBase.rlimit) & (ray.a > 0.1)  THEN
		oldxyz := ray.xyz;
		ray.changed := FALSE;
		xyz.x := ray.lxyz.x * 3 + ray.dxyz.x / 1000000;
		xyz.y := ray.lxyz.y * 3 + ray.dxyz.y / 1000000;
		xyz.z := ray.lxyz.z * 3 + ray.dxyz.z / 1000000;
		srE.E(xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF v # NIL THEN
				ray.lxyz.x := ABS(xyz.x - ijk.i);
				ray.lxyz.y := ABS(xyz.y - ijk.j);
				ray.lxyz.z := ABS(xyz.z - ijk.k);
				INC(ray.recursion);
				v.Shade(ray);
				DEC(ray.recursion)
			END
		END;
		REPEAT
			IF ray.dxyz.x < 0 THEN di := - 1  ELSE di := 1 END;
			IF ray.dxyz.y < 0 THEN dj := - 1  ELSE dj := 1 END;
			IF ray.dxyz.z < 0 THEN dk := - 1  ELSE dk := 1 END;
			REPEAT
				IF di > 0 THEN
					drx := ( (ijk.i + 1) - xyz.x) / ray.dxyz.x
				ELSE
					drx :=  (ijk.i -  xyz.x) / ray.dxyz.x
				END;
				IF dj > 0 THEN
					dry := ( (ijk.j + 1) - xyz.y) / ray.dxyz.y
				ELSE
					dry :=  (ijk.j - xyz.y) / ray.dxyz.y
				END;
				IF dk > 0 THEN
					drz := ( (ijk.k + 1) - xyz.z) / ray.dxyz.z
				ELSE
					drz :=  (ijk.k - xyz.z) / ray.dxyz.z
				END;
				IF (drx < dry) THEN
				IF (drx < drz ) THEN
					INC(ijk.i, di);
					IF di > 0 THEN ray.face := 1 ELSE ray.face := 4 END;
					xyz.x := xyz.x + drx * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drx * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drx * ray.dxyz.z + ray.ddxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z + ray.ddxyz.z
				END
			ELSIF (dry < drz) THEN
				INC(ijk.j, dj);
				IF dj > 0 THEN ray.face := 2 ELSE ray.face := 5 END;
				xyz.x := xyz.x + dry * ray.dxyz.x + ray.ddxyz.x;
				xyz.y := xyz.y + dry * ray.dxyz.y + ray.ddxyz.y;
				xyz.z  := xyz.z+ dry * ray.dxyz.z + ray.ddxyz.z
				ELSE
					INC(ijk.k, dk);
					IF dk > 0 THEN ray.face := 3 ELSE ray.face := 6 END;
					xyz.x := xyz.x + drz * ray.dxyz.x + ray.ddxyz.x;
					xyz.y := xyz.y + drz * ray.dxyz.y + ray.ddxyz.y;
					xyz.z  := xyz.z + drz * ray.dxyz.z + ray.ddxyz.z
				END;
				ray.xyz.x := ray.xyz.x+ xyz.x/3;
				ray.xyz.y := ray.xyz.y + xyz.y/3;
				ray.xyz.z := ray.xyz.z + xyz.z/3;
				bounds(ijk.i,ijk.j,ijk.k, out);
				IF ~out & (ray.a > 0.1) THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v # NIL THEN
						ray.lxyz.x := ABS(xyz.x - ijk.i);
						ray.lxyz.y := ABS(xyz.y - ijk.j);
						ray.lxyz.z := ABS(xyz.z - ijk.k);
						INC(ray.recursion);
						v.Shade(ray);
						DEC(ray.recursion)
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
	ray.xyz := oldxyz;
	ELSIF (core # NIL) & (ray.a > 1/10) THEN
(*		ray.lxyz := ray.slxyz; *)
			INC(ray.recursion);
			core.Shade(ray);
			DEC(ray.recursion);
	END;

END probeShade;

END cacheSerpBloc; *)

TYPE BraidBloc* = OBJECT(SerpBloc);
PROCEDURE & init*(kore, mid: Voxel);
BEGIN
	core := kore;
	rlimit := srBase.rlimit + 3;
	Fill(mid);
	blox[0, 0, 0] := SELF;
	blox[1, 1, 0] :=  SELF;
	blox[2, 2, 0] := SELF;
	blox[0, 2, 2] := SELF;
	blox[1, 1, 1] :=  core;
	blox[1, 1, 2] :=  SELF;
	blox[2, 0, 2] := SELF;
	blox[2, 0, 0] := SELF;
	blox[2, 1, 1] :=  SELF;
	blox[2, 2, 2] := SELF;
	blox[0, 0, 2] := SELF;
	blox[0, 1, 1] :=  SELF;
	blox[0, 2, 0] := SELF;
	register;
END init;

END BraidBloc;

TYPE TowerBloc* = OBJECT(SerpBloc);
PROCEDURE & init*(a,b: Voxel);
BEGIN
	rlimit := srBase.rlimit + 3;
	Fill(NIL);
	blox[0,0,0] := SELF;
	blox[1,1,0] := SELF;
	blox[2,2,0] := SELF;
	blox[0,0,1] := SELF;
	blox[1,1,1] := SELF;
	blox[2,2,1] := SELF;
	blox[0,0,2] := SELF;
	blox[1,1,2] := SELF;
	blox[2,2,2] := SELF;
	blox[1,0,0] := a;
	blox[2,1,0] := b;
	blox[2,0,0] := b;
	blox[1,0,1] := b;
	blox[2,1,1] := a;
	blox[2,0,1] := a;
	blox[1,0,2] := b;
	blox[2,1,2] := a;
	blox[2,0,2] := core;
END init;
END TowerBloc;

TYPE SlantBloc* = OBJECT(SerpBloc);
PROCEDURE fn(i,j,k: SIGNED16): SIGNED16;
BEGIN
	IF k= 0 THEN IF i+j <=1  THEN RETURN(1) ELSE RETURN(2) END END;
	IF k=1 THEN IF i+j = 0 THEN RETURN(0) ELSIF i+j=2 THEN RETURN(1) ELSE RETURN(2) END END;
	IF k=2 THEN IF i+j = 4 THEN RETURN(1) ELSE RETURN(0)  END END;
	RETURN(0);
END fn;

PROCEDURE & init*(a,b: Voxel);
VAR
	i, j, k, r: SIGNED16;
BEGIN
	rlimit := srBase.rlimit + 3;
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		r:= fn(i,j,k);
		CASE r OF
			0: blox[i,j,k] := NIL;
			|1: blox[i,j,k] := SELF;
			|2: IF ODD(i+j+k) THEN blox[i,j,k] := a ELSE blox[i,j,k] := b END
		ELSE
		END;
	END END END;
END init;

END SlantBloc;

TYPE VegeBloc* = OBJECT(SerpBloc);
PROCEDURE&init*(kore, mid: Voxel);
BEGIN
	rlimit := 3;
	core := kore;
	Fill(mid);
	blox[0, 0, 0] := SELF;
	blox[0, 0, 2] := SELF;
	blox[0,2, 0] :=  SELF;
	blox[0, 2, 2] := SELF;
	blox[2, 0, 2] := SELF;
	blox[2, 2, 0] := SELF;
	blox[2, 0, 0] := SELF;
	blox[2, 2, 2] := SELF;
	blox[1,1,1] := SELF;
END init;

END VegeBloc;

(*TYPE ScuteBloc* = OBJECT(SerpBloc);

PROCEDURE&init(kore, mid: Voxel);
VAR
	air: srVoxel.AlphaVox;
	ground: srLitVox.FaceVox;
	reeds: srVaster.reeds2;
	red, green, blue: srVoxel.GouraudVox;
BEGIN
	NEW(air);
	NEW(ground);
	NEW(reeds);
	NEW(red);
	NEW(blue);
	NEW(green);
	red.SetColor(1,0,0);
	blue.SetColor(0,0,1);
	green.SetColor(2/3,1,1/2);
	ground.SetFaces(red,green,blue,red,green,blue);
	air.SetColor(1,1,1,1/3);
	SetGround(ground);
	SetAir(air);
	SetSurface(SELF);
	core := ground;
	passable := TRUE;
END init;

PROCEDURE SetAir*(v: Voxel);
BEGIN
	blox[2,2,2] := v;
	blox[2,2,1] := v;
	blox[2,1,2] := v;
	blox[1,2,2] := v;
END SetAir;

PROCEDURE SetSurface*(v: Voxel);
BEGIN
	blox[2,2,0] := v;
	blox[2,0,2] := v;
	blox[0,0,2] := v;
	blox[2,0,0] := v;
	blox[0,2,0] := v;
	blox[0,2,2] := v;
	blox[1,1,2] := v;
	blox[2,1,1] := v;
	blox[1,2,1] := v;
END SetSurface;

PROCEDURE SetGround*(v: Voxel);
VAR
	i, j, k: SIGNED16;
BEGIN
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i, j, k] := v
	END END END;
END SetGround;

END ScuteBloc;

TYPE Pyra5core = OBJECT(srVoxel2.Bloc5);

PROCEDURE&init;
VAR
	air: Voxel;
	ground: srVoxel.GouraudVox;
	reeds: srVaster.reeds2;
	i, j, k: SIGNED16;
BEGIN
	NEW(air);
	NEW(ground);
	NEW(reeds);
	ground.SetColor(1,1,0);
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		blox[i, j, k] := air
	END END END;
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO
		blox[i, j, 0] := ground;
		blox[i, j, 1] := reeds;
	END END;
	FOR i := 1 TO 3 DO FOR j := 1 TO 3 DO
		blox[i, j, 1] := ground;
		blox[i, j, 2] := reeds;
	END END;
	blox[2,2,2] := ground;
	blox[2,2,3] := ground;
	blox[2,2,4] := SELF;
END init;

END Pyra5core;

TYPE Pyra5* = OBJECT(srVoxel2.Bloc5);

PROCEDURE&init;
VAR
	air: Voxel;
(*	air: srVoxel.HexaVox; *)
	hex: srVoxel.SPHexaVox;
	ground: srVoxel.GouraudVox;
	surface : Pyra5core;
	i, j, k: SIGNED16;
BEGIN
	NEW(air);
	NEW(ground);
	ground.SetColor(0,1,0);
	NEW(hex);
	hex.V := ground;
	NEW(surface);
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		blox[i, j, k] := air
	END END END;
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO
		blox[i, j, 0] := hex;
		blox[i, j, 1] := surface
	END END;
	FOR i := 1 TO 3 DO FOR j := 1 TO 3 DO
		blox[i, j, 1] := hex;
		blox[i, j, 2] := surface
	END END;

	passable := TRUE;
END init;

END Pyra5; *)

TYPE Tree3* = OBJECT(Bloc3);
VAR
	trunk, leaf, gap: Voxel;
PROCEDURE&init*(t,l,g: Voxel);
BEGIN
	trunk := t; leaf := l; gap := g;
	Fill(SELF);
	blox[1,1,0 ] := trunk;
	blox[1,1,1 ] := trunk;
	blox[1,1,2 ] := trunk;
	blox[0,0,2 ] := leaf;
	blox[2,0,2 ] := leaf;
	blox[0,2,2 ] := leaf;
	blox[2,2,2 ] := leaf;
	rlimit := 5;
END init;

PROCEDURE Fill*(v: Voxel);
VAR
	i, j, k: SIGNED16;
BEGIN
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k := 0 TO 2 DO
		blox[i, j, k] := v
	END END END;
END Fill;

END Tree3;

TYPE Tree5* = OBJECT(Bloc5);
VAR
	trunk, leaf, gap: Voxel;

PROCEDURE&new*(t,l,g: Voxel);
BEGIN
	trunk := t; leaf := l; gap := g;
	Fill(g);
	blox[2,2,0 ] := trunk;
	blox[2,2,1 ] := trunk;
	blox[1,2,3 ] := trunk;
	blox[2,1,3 ] := trunk;
	blox[2,3,3 ] := trunk;
	blox[3,2,3 ] := trunk;
	blox[2,2,2 ] := SELF;
	blox[1,2,3 ] := SELF;
	blox[2,1,3 ] := SELF;
	blox[2,3,3 ] := SELF;
	blox[3,2,3 ] := SELF;

	rlimit := 5;
END new;

PROCEDURE Fill*(v: Voxel);
VAR
	i, j, k: SIGNED16;
BEGIN
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k := 0 TO 4 DO
		blox[i, j, k] := v
	END END END;
END Fill;

END Tree5;

PROCEDURE STOPGO*;
BEGIN
	GO := ~GO
END STOPGO;


BEGIN
	NEW(rand);
END srVoxel3.