MODULE srM2Space;
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
	mirror:BOOLEAN;
	reflectivity:FLOAT32;
	normal: PT;
	color:COLOR;
END;

TYPE cell* = OBJECT(Voxel);

VAR
	blox: AR2;
	nblox:  NR2;
	twoblox: BR2;
	airred, airgreen, airblue, airblack: SREAL;

PROCEDURE & init*;
BEGIN
	SetColor(0,0,0,0);
	complex:=TRUE;
	passable:=TRUE;
END init;

PROCEDURE SetColor* (R, G, B, BL: SREAL);
BEGIN
	airred := R/2;
	airgreen := G/2;
	airblue := B/2;
	airblack :=  BL/2;
END SetColor;

PROCEDURE bounds* (i, j, k: SIGNED32; VAR out: BOOLEAN);
BEGIN
	IF ((i=0) OR (i=1)) & ((j=0) OR (j=1)) & ((k=0) OR (k=1)) THEN
		out := FALSE
	ELSE
		out := TRUE
	END
END bounds;

PROCEDURE fill*(v: Voxel);
VAR
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k:= 0 TO 2 DO
		blox[i,j,k] := v
	END END END
END fill;

PROCEDURE erase*;
VAR
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 2 DO FOR j := 0 TO 2 DO FOR k:= 0 TO 1 DO
	 twoblox[i,j,k] := NIL;
	END END END
END erase;


PROCEDURE fillwithprobability*(v: Voxel; p: SREAL);
VAR
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 1 DO FOR j := 0 TO 1 DO FOR k:= 0 TO 2 DO
		IF srBase.rand.Uniform()<p THEN blox[i,j,k] := v END
	END END END
END fillwithprobability;

PROCEDURE fillchequer*(v,w: Voxel);
VAR
	i,j,k: SIGNED16;
BEGIN
	FOR i := 0 TO 1 DO FOR j := 0 TO 1 DO FOR k:= 0 TO 1 DO
		IF ODD(i+j+k) THEN blox[i,j,k] := v ELSE blox[i,j,k] := w END
	END END END
END fillchequer;

PROCEDURE color(VAR ray: Ray; cube:NCUBE);
VAR
	dot: SREAL;
	nx, ny, nz: SIGNED16;
	inside: BOOLEAN;
BEGIN
	dot := ABS(cube.normal.x*ray.dxyz.x + cube.normal.y*ray.dxyz.y+ cube.normal.z*ray.dxyz.z);
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

PROCEDURE ncolor(VAR ray: Ray; cube:NCUBE);
VAR
	dot: SREAL;

PROCEDURE reflect(VAR m,n:PT);
VAR
	dot: SREAL;
BEGIN
	dot := m.x*n.x+m.y*n.y+m.z*n.z;
	n.x:= 2*n.x*dot; n.y := 2*n.y*dot; n.z := 2*n.z*dot;
	m.x := m.x-n.x; m.y := m.y-n.y; m.z := m.z-n.z;
END reflect;

BEGIN
	IF cube.mirror THEN
		reflect(ray.dxyz,cube.normal);
		ray.a:=ray.a-0.1;
		ray.changed:=TRUE
	ELSE
		dot := ABS(cube.normal.x*ray.dxyz.x + cube.normal.y*ray.dxyz.y+ cube.normal.z*ray.dxyz.z);
		ray.r := ray.r + cube.color.red * ray.ra*dot;
		ray.g := ray.g + cube.color.green * ray.ga*dot;
		ray.b := ray.b + cube.color.blue * ray.ba*dot;
		ray.ra:=0; ray.ga:=0; ray.ba:=0;
		ray.a := 0;
	END
END ncolor;

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
	(*	INC(ray.recursion); *)
		oldxyz := ray.xyz;
		ray.scale := ray.scale/2;
		ray.xyz.x := ray.lxyz.x * 2  - ray.ddxyz.x;
		ray.xyz.y := ray.lxyz.y * 2  - ray.ddxyz.y;
		ray.xyz.z := ray.lxyz.z * 2  - ray.ddxyz.z;
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
				v := twoblox[ijk.i,ijk.j,ijk.k];
				IF v#NIL THEN
				 	ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
					ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
					ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
					v.Shade(ray);
				ELSIF nblox[ijk.i,ijk.j,ijk.k].filled THEN
					ncolor(ray,nblox[ijk.i,ijk.j,ijk.k])
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
						v := twoblox[ijk.i,ijk.j,ijk.k];
						 IF v#NIL THEN
							ray.lxyz.x := ABS(ray.xyz.x - ijk.i);
							ray.lxyz.y := ABS(ray.xyz.y - ijk.j);
							ray.lxyz.z := ABS(ray.xyz.z - ijk.k);
							v.Shade(ray);
						ELSIF nblox[ijk.i,ijk.j,ijk.k].filled THEN
							ncolor(ray,nblox[ijk.i,ijk.j,ijk.k])
						END
					END
				END;
			UNTIL   (ray.a < 0.1) OR out OR ray.changed;
		UNTIL   (ray.a < 0.1) OR out;
		ray.scale := ray.scale*2;
		ray.xyz := oldxyz;
(*		DEC(ray.recursion); *)
	END
END Shade;

PROCEDURE probe*(x,y,z: SREAL):Voxel;
VAR
	X,Y,Z: SREAL;
	i,j,k: SIGNED32;
BEGIN
	srBase.clamp3(x,y,z);
	X := x*2; Y := y*2; Z := z*2;
	i := ENTIER(X);
	j := ENTIER(Y);
	k := ENTIER(Z);
	IF blox[i,j,k]#NIL THEN RETURN(blox[i,j,k].probe(X-i, Y-j, Z-k)) END;
	IF twoblox[i,j,k]#NIL THEN RETURN(twoblox[i,j,k].probe(X-i, Y-j, Z-k)) END;
	IF nblox[i,j,k].filled THEN RETURN(SELF) END;
	RETURN(SELF);
END probe;

PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL);
VAR
	ijk: srBase.IPT;
	out: BOOLEAN;
	v: Voxel;
BEGIN
	ray.xyz.x := ray.lxyz.x * 3;
	ray.xyz.y := ray.lxyz.y * 3;
	ray.xyz.z := ray.lxyz.z * 3;
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
	di, dj, dk: SIGNED16;
	out: BOOLEAN;
	v: Voxel;
	killed: BOOLEAN;
BEGIN
	Out.String('..looking for something to kill..');
	oldxyz := ray.xyz;
	ray.scale := ray.scale/2;
	ray.xyz.x := ray.lxyz.x * 2  - ray.dxyz.x / 1000000 ;
	ray.xyz.y := ray.lxyz.y * 2  - ray.dxyz.y / 1000000 ;
	ray.xyz.z := ray.lxyz.z * 2  - ray.dxyz.z / 1000000 ;
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
	ray.scale := ray.scale*2;
	ray.xyz := oldxyz;
	Out.Ln;
END deathray;

PROCEDURE stroke*( p:PT; level: SIGNED32; normal:PT; color: COLOR; mirror: BOOLEAN);
VAR
	i,j,k: SIGNED32;
BEGIN
	IF level>=1 THEN
		(* top mcell is 1x1x1 by definition *) (*root only*)
		srBase.clamPT(p);
		pdiv(p,1.9999);
		i := ENTIER(p.x); j := ENTIER(p.y); k := ENTIER(p.z);
		IF level=1 THEN
			(* we're here. *)
			nblox[i,j,k].normal:=normal;
			nblox[i,j,k].color:=color;
			nblox[i,j,k].filled:=TRUE;
			IF mirror THEN nblox[i,j,k].mirror:=TRUE END;
		ELSE
			IF twoblox[i,j,k] = NIL THEN
				NEW(twoblox[i,j,k]);
			END;
			p.x:=p.x-i; p.y:=p.y-j; p.z:=p.z-k;
			twoblox[i,j,k].stroke(p, level-1,normal,color,mirror);
		END
	END
END stroke;

PROCEDURE strokevoxel*(p:PT; level: SIGNED32; voxel:Voxel);
VAR
	i,j,k: SIGNED32;
	(*B5: cell;*)

BEGIN
	IF level>=1 THEN
		(* top mcell is 1x1x1 by definition *) (*root only*)
		srBase.clamPT(p);
		pdiv(p,1.9999);
		i := ENTIER(p.x); j := ENTIER(p.y); k := ENTIER(p.z);
		p.x:=p.x-i; p.y:=p.y-j; p.z:=p.z-k;
		IF level=1 THEN
			(* we're here. *)
			blox[i,j,k]:=voxel;
		ELSE
			IF twoblox[i,j,k] = NIL THEN
				NEW(twoblox[i,j,k]);
			END;
			twoblox[i,j,k].strokevoxel(p, level-1,voxel);
		END
	END
END strokevoxel;

PROCEDURE line*(a,b: PT; level: SIGNED32; color:COLOR; mirror:BOOLEAN);
VAR
	tx,ty,tz, dxdt, dydt, dzdt: SREAL;
	t: SIGNED32;
	delta: SREAL;
	n: SIGNED32;
	p, normal: PT;
BEGIN
	CASE level OF
		1: delta := 1/2;
		|2: delta := 1/4;
		| 3: delta := 1/8;
		|4: delta := 1/16;
		|5: delta := 1/32;
		|6: delta := 1/64;
		|7: delta := 1/128;
		|8: delta := 1/256;
		|9: delta := 1/512;
		|10: delta := 1/1024;
		|11: delta := 1/2048;
	ELSE
		delta := 0;
	END;
	normal.x := ABS(a.x - b.x);
	normal.y := ABS(a.y - b.y);
	normal.z := ABS(a.z - b.z);
	srBase.normalizePT(normal);
	IF delta > 0 THEN
		n := ENTIER(srBase.distance(a,b)/delta);
		tx := b.x; ty := b.y; tz := b.z;
		dxdt := (a.x-b.x)/n; dydt := (a.y-b.y)/n; dzdt := (a.z-b.z)/n;
		FOR t := 0 TO n DO
			srBase.setPT(p,tx, ty, tz);
			stroke(p, level,normal,color,FALSE);
			tx := tx + dxdt; ty := ty + dydt; tz := tz+dzdt;
		END
	END
END line;

PROCEDURE nline*(a,b: PT; level: SIGNED32;  normal:PT; color:COLOR; mirror:BOOLEAN);
VAR
	tx,ty,tz, dxdt, dydt, dzdt: SREAL;
	t: SIGNED32;
	delta: SREAL;
	n: SIGNED32;
	p: PT;
BEGIN
	CASE level OF
		1: delta := 1/2;
		|2: delta := 1/4;
		| 3: delta := 1/8;
		|4: delta := 1/16;
		|5: delta := 1/32;
		|6: delta := 1/64;
		|7: delta := 1/128;
		|8: delta := 1/256;
		|9: delta := 1/512;
		|10: delta := 1/1024;
		|11: delta := 1/2048;
	ELSE
		delta := 0;
	END;	IF delta > 0 THEN
		n := ENTIER(srBase.distance(a,b)/delta);
		tx := b.x; ty := b.y; tz := b.z;
		dxdt := (a.x-b.x)/n; dydt := (a.y-b.y)/n; dzdt := (a.z-b.z)/n;
		FOR t := 0 TO n DO
			srBase.setPT(p,tx, ty, tz);
			stroke(p, level,normal,color,mirror);
			tx := tx + dxdt; ty := ty + dydt; tz := tz+dzdt;
		END
	END
END nline;

PROCEDURE linevoxel*(a,b: PT; level: SIGNED32; v: Voxel);
VAR
	tx,ty,tz, dxdt, dydt, dzdt: SREAL;
	t: SIGNED32;
	delta: SREAL;
	n: SIGNED32;
	p: PT;

BEGIN
	CASE level OF
		1: delta := 1/2;
		|2: delta := 1/4;
		| 3: delta := 1/8;
		|4: delta := 1/16;
		|5: delta := 1/32;
		|6: delta := 1/64;
		|7: delta := 1/128;
		|8: delta := 1/256;
		|9: delta := 1/512;
		|10: delta := 1/1024;
		|11: delta := 1/4096;
		|12: delta := 1/8192;
		|13: delta := 1/16484;
		|14: delta := 1/32968;
		|15: delta := 1/65936;
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
END linevoxel;

END cell;

TYPE AR2 = ARRAY 2,2,2 OF Voxel;
TYPE NR2 = ARRAY 2,2,2 OF NCUBE;
TYPE BR2 = ARRAY 2,2,2 OF cell;

PROCEDURE pdiv(VAR p:PT; d:SREAL);
BEGIN
	p.x:=p.x*d;
	p.y:=p.y*d;
	p.z:=p.z*d;
END pdiv;

END srM2Space.

System.Free srM3Space