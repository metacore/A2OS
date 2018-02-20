MODULE srM5Space;
IMPORT srBase, srE,  Out := KernelLog;

CONST POS = TRUE;
CONST NEG = FALSE;

TYPE SREAL=srBase.SREAL;
TYPE PT = srBase.PT;
TYPE COLOR = srBase.COLOR;
TYPE Ray = srBase.Ray;
TYPE Voxel = srBase.Voxel;
TYPE NCUBE=RECORD
	filled: BOOLEAN;
	normal: PT;
	color:COLOR;
END;

TYPE cell* = OBJECT(Voxel);

VAR
	blox: AR5;
	nblox:  NR5;
	fiveblox: BR5;
	airred, airgreen, airblue, airblack: SREAL;

PROCEDURE & init*;
BEGIN
	SetColor(0,0,0,0);
	complex:=TRUE;
END init;

PROCEDURE SetColor* (R, G, B, BL: SREAL);
BEGIN
	airred := R/5;
	airgreen := G/5;
	airblue := B/5;
	airblack :=  BL/5;
END SetColor;

PROCEDURE bounds* (i, j, k: LONGINT; VAR out: BOOLEAN);
BEGIN
	IF (i < 0) OR (i > 4) OR (j < 0) OR (j > 4) OR (k < 0) OR (k > 4) THEN
		out := TRUE
	ELSE
		out := FALSE
	END
END bounds;

PROCEDURE fill*(v: Voxel);
VAR
	i,j,k: INTEGER;
BEGIN
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k:= 0 TO 4 DO
		blox[i,j,k] := v
	END END END
END fill;

PROCEDURE erase*;
VAR
	i,j,k: INTEGER;
BEGIN
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k:= 0 TO 4 DO
		blox[i,j,k] := NIL; nblox[i,j,k].filled := FALSE; fiveblox[i,j,k] := NIL;
	END END END
END erase;


PROCEDURE fillwithprobability*(v: Voxel; p: SREAL);
VAR
	i,j,k: INTEGER;
BEGIN
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k:= 0 TO 4 DO
		IF srBase.rand.Uniform()<p THEN blox[i,j,k] := v END
	END END END
END fillwithprobability;

PROCEDURE fillchequer*(v,w: Voxel);
VAR
	i,j,k: INTEGER;
BEGIN
	FOR i := 0 TO 4 DO FOR j := 0 TO 4 DO FOR k:= 0 TO 4 DO
		IF ODD(i+j+k) THEN blox[i,j,k] := v ELSE blox[i,j,k] := w END
	END END END
END fillchequer;

PROCEDURE color(VAR ray: Ray; cube:NCUBE);
VAR
	dot: SREAL;
	nx, ny, nz: INTEGER;
	inside: BOOLEAN;
BEGIN
(*	dot := ABS(cube.normal.x*ray.dxyz.x + cube.normal.y*ray.dxyz.y+ cube.normal.z*ray.dxyz.z);
	ray.r := ray.r + cube.color.red * ray.ra*dot;
	ray.g := ray.g + cube.color.green * ray.ga*dot;
	ray.b := ray.b + cube.color.blue * ray.ba*dot;
	ray.ra:=0; ray.ga:=0; ray.ba:=0; *)
	(*DIFFUSE SHADER*)
	CASE ray.face OF
		0: inside := TRUE
		|1: nx := -1
		|2: ny := -1
		|3: nz := -1
		|4: nx := 1
		|5: ny := 1
		|6: nz := 1
	ELSE
	END;
	IF inside THEN dot := 1 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END;
	ray.r := ray.r + cube.color.red * ray.ra*dot;
	ray.g := ray.g + cube.color.green * ray.ga*dot;
	ray.b := ray.b + cube.color.blue * ray.ba*dot;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;

END color;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	ijk: srBase.IPT;
	drx, dry, drz, dr,rr,gr,br,bl: SREAL;
	di, dj, dk: INTEGER;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	IF ray.recursion>6 THEN
		ray.a :=0
	ELSE
		INC(ray.recursion);
		oldxyz := ray.xyz;
		ray.scale := ray.scale/5;
		ray.xyz.x := ray.lxyz.x * 5  - ray.ddxyz.x;
		ray.xyz.y := ray.lxyz.y * 5  - ray.ddxyz.y;
		ray.xyz.z := ray.lxyz.z * 5  - ray.ddxyz.z;
		srE.E(ray.xyz,ijk);
		bounds(ijk.i,ijk.j,ijk.k, out);
		IF ~out & (ray.a > 1/10) THEN
			v := blox[ijk.i,ijk.j,ijk.k];
			IF v#NIL THEN
				ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
				ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
				ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
				v.Shade(ray);
			ELSE
				v := fiveblox[ijk.i,ijk.j,ijk.k];
				IF v#NIL THEN
				 	ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
					ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
					ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
					v.Shade(ray);
				ELSIF nblox[ijk.i,ijk.j,ijk.k].filled THEN
					color(ray,nblox[ijk.i,ijk.j,ijk.k])
				END
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
				IF ~out & (ray.a > 1/10) THEN
					v := blox[ijk.i,ijk.j,ijk.k];
					IF v#NIL THEN
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						v.Shade(ray);
					ELSE
						v := fiveblox[ijk.i,ijk.j,ijk.k];
						 IF v#NIL THEN
							ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
							ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
							ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
							v.Shade(ray);
						ELSIF nblox[ijk.i,ijk.j,ijk.k].filled THEN
							color(ray,nblox[ijk.i,ijk.j,ijk.k])
						END
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
		ray.scale := ray.scale*5;
		ray.xyz := oldxyz;
		DEC(ray.recursion);
	END
END Shade;

PROCEDURE probe*(x,y,z: SREAL):Voxel;
VAR
	X,Y,Z: SREAL;
	i,j,k: LONGINT;
BEGIN
	srBase.clamp3(x,y,z);
	X := x*5; Y := y*5; Z := z*5;
	i := ENTIER(X);
	j := ENTIER(Y);
	k := ENTIER(Z);
	IF blox[i,j,k]#NIL THEN RETURN(blox[i,j,k].probe(X-i, Y-j, Z-k)) END;
	IF fiveblox[i,j,k]#NIL THEN RETURN(fiveblox[i,j,k].probe(X-i, Y-j, Z-k)) END;
	IF nblox[i,j,k].filled THEN RETURN(SELF) END;
	RETURN(NIL);
END probe;

PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL);
VAR
	ijk: srBase.IPT;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	ray.xyz.x := ray.lxyz.x * 5;
	ray.xyz.y := ray.lxyz.y * 5;
	ray.xyz.z := ray.lxyz.z * 5;
	srE.E(ray.xyz,ijk);
	bounds(ijk.i,ijk.j,ijk.k, out);
	IF ~out THEN
		v := blox[ijk.i,ijk.j,ijk.k];
		IF v#NIL THEN
			ray.lxyz.x := ray.xyz.x;
			ray.lxyz.y := ray.xyz.y;
			ray.lxyz.z := ray.xyz.z;
			v.probeShade(ray,dx,dy,dz);
		END
	END
END probeShade;

PROCEDURE deathray*(VAR ray: Ray);
VAR
	oldxyz: srBase.PT;
	ijk: srBase.IPT;
	drx, dry, drz: SREAL;
	di, dj, dk: INTEGER;
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
					IF v.complex THEN
						ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
						ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
						ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
						Out.String('complex ');
						v.deathray(ray);
						IF ray.changed THEN killed := TRUE END;
					ELSE
						Out.String('simple: killing ');
						blox[ijk.i,ijk.j,ijk.k] := NIL;
						killed := TRUE; ray.changed := TRUE;
					END;
				END
			END;
		UNTIL  killed OR out;
	UNTIL  killed OR out;
	END;
	IF killed THEN ray.changed := TRUE END;
	ray.scale := ray.scale*5;
	ray.xyz := oldxyz;
	Out.Ln;
END deathray;

PROCEDURE stroke*(p:PT; level: LONGINT; normal:PT; color: COLOR; mirror:BOOLEAN);
VAR
	i,j,k: LONGINT;
BEGIN
	IF level>=1 THEN
		(* top mcell is 1x1x1 by definition *) (*root only*)
		srBase.clamPT(p);
		pdiv(p,5);
		i := ENTIER(p.x); j := ENTIER(p.y); k := ENTIER(p.z);
		IF level=1 THEN
			(* we're here. *)
			nblox[i,j,k].normal:=normal;
			nblox[i,j,k].color:=color;
			nblox[i,j,k].filled:=TRUE;
		ELSE
			IF fiveblox[i,j,k] = NIL THEN
				NEW(fiveblox[i,j,k]);
			END;
			p.x:=p.x-i; p.y:=p.y-j; p.z:=p.z-k;
			fiveblox[i,j,k].stroke(p, level-1,normal,color,mirror);
		END
	END
END stroke;

PROCEDURE strokevoxel*(p:PT; level: LONGINT; voxel:Voxel);
VAR
	i,j,k: LONGINT;
BEGIN
	IF level>=1 THEN
		(* top mcell is 1x1x1 by definition *) (*root only*)
		srBase.clamPT(p);
		pdiv(p,4.9999);
		i := ENTIER(p.x); j := ENTIER(p.y); k := ENTIER(p.z);
		p.x:=p.x-i; p.y:=p.y-j; p.z:=p.z-k;
		IF level=1 THEN
			(* we're here. *)
			blox[i,j,k]:=voxel;
		ELSE
			IF fiveblox[i,j,k] = NIL THEN
				NEW(fiveblox[i,j,k]);
			END;
			fiveblox[i,j,k].strokevoxel(p, level-1,voxel);
		END
	END
END strokevoxel;

PROCEDURE line*(a,b: PT; level: LONGINT; v: Voxel);
VAR
	tx,ty,tz, dxdt, dydt, dzdt: SREAL;
	t: LONGINT;
	delta: SREAL;
	n: LONGINT;
	p: PT;
BEGIN
	CASE level OF
		1: delta := 1/5;
		|2: delta := 1/25;
		| 3: delta := 1/125;
		|4: delta := 1/625;
		|5: delta := 1/3125;
	ELSE
		delta := 0;
	END;
	IF delta > 0 THEN
		n := ENTIER(srBase.distance(a,b)/delta);
		tx := b.x; ty := b.y; tz := b.z;
		dxdt := (a.x-b.x)/n; dydt := (a.y-b.y)/n; dzdt := (a.z-b.z)/n;
		FOR t := 0 TO n DO
			srBase.setPT(p,tx, ty, tz);
			strokevoxel(p, level,v);
			tx := tx + dxdt; ty := ty + dydt; tz := tz+dzdt;
		END
	END
END line;

END cell;

TYPE AR5 = ARRAY 5,5,5 OF Voxel;
TYPE NR5 = ARRAY 5,5,5 OF NCUBE;
TYPE BR5 = ARRAY 5,5,5 OF cell;

PROCEDURE pdiv(VAR p:PT; d:SREAL);
BEGIN
	p.x:=p.x*d;
	p.y:=p.y*d;
	p.z:=p.z*d;
END pdiv;

END srM5Space.