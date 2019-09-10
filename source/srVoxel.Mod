MODULE srVoxel;
IMPORT srBase, Math, srMath, srE,  srHex,Out := KernelLog;

TYPE SREAL=srBase.SREAL;
TYPE PT=srBase.PT;
TYPE Ray = srBase.Ray;
TYPE Voxel = srBase.Voxel;

TYPE ColoredVox* = OBJECT(Voxel);
VAR
	r, g, b: SREAL;
PROCEDURE SetColor* (red, green, blue : SREAL);
BEGIN
	r := srBase.clamp(red );
	g := srBase.clamp(green );
	b := srBase.clamp(blue );
END SetColor;
PROCEDURE Shade*(VAR ray: Ray);
BEGIN
	ray.r := ray.r + r*ray.ra;
	ray.g := ray.g + g*ray.ga;
	ray.b := ray.b + b*ray.ba;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
END Shade;
END ColoredVox;

TYPE GoorowVox* = OBJECT(Voxel);
VAR
	r, g, b: SREAL;
PROCEDURE Shade*(VAR ray: Ray);
BEGIN
	ray.r := ray.r + ray.lxyz.x*ray.ra;
	ray.g := ray.g + ray.lxyz.y*ray.ga;
	ray.b := ray.b + ray.lxyz.z*ray.ba;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a :=0;
END Shade;
END GoorowVox;

TYPE LitVox* = OBJECT(Voxel);
VAR
	r, g, b, nx, ny, nz: SREAL;
PROCEDURE SetColor* (red, green, blue : SREAL);
BEGIN
	r := srBase.clamp(red);
	g := srBase.clamp(green);
	b := srBase.clamp(blue);
END SetColor;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	x,y,z,dotrl: SREAL;
BEGIN
	x := 1/2 - ray.lxyz.x; y := 1/2 - ray.lxyz.y; z := 1/2 - ray.lxyz.z;
	srBase.normalize(x,y,z);
	dotrl :=x*srBase.light.x + y*srBase.light.y + z*srBase.light.z;
	IF dotrl > 0 THEN
		ray.r := ray.r +(r*dotrl)*ray.ra ;
		ray.g := ray.g + (g*dotrl)*ray.ga;
		ray.b := ray.b + (b*dotrl)*ray.ba;
	END;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END LitVox;

TYPE ColoredMVox* = OBJECT(Voxel); (*NOT CORRECT YET *)
VAR
	r, g, b, mf, a: SREAL;
PROCEDURE SetColor*(red, green, blue, mfraction: SREAL);
BEGIN
	mf := srBase.clamp(mfraction);
	a := mf;
	r := srBase.clamp(red)*a;
	g := srBase.clamp(green)*a;
	b := srBase.clamp(blue)*a;
END SetColor;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	dr, dg, db: SREAL;
BEGIN
	dr :=  r*ray.ra;
	dg :=  g*ray.ga;
	db :=  b*ray.ba;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - a*(dg+db);
	ray.ga := ray.ga - a*(dr+db);
	ray.ba := ray.ba - a*(dr+dg);
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
	mirror(ray);
END Shade;
END ColoredMVox;

TYPE DiffuseMVox* = OBJECT(Voxel);
VAR
	r, g, b, mf, a: SREAL;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	nx, ny, nz: SIGNED16;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
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
	IF inside THEN dot := 0 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END;
	ray.ra := dot*ray.ra- 0.3;
	ray.ga := dot*ray.ga- 0.3;
	ray.ba := dot*ray.ba- 0.3;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
	mirror(ray);
END Shade;
END DiffuseMVox;

TYPE DiffuseSphMVox* = OBJECT(ColoredVox);
VAR
	 mf, a: SREAL;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	nx, ny, nz: SREAL;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
	nx := 1/2 - ray.lxyz.x; ny := 1/2-ray.lxyz.y; nz := 1/2-ray.lxyz.z;
	srBase.normalize(nx,ny, nz);
	IF inside THEN dot := 0 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END;
	ray.a := dot*ray.a/2;
	ray.ra := dot*ray.ra/2;
	ray.ga := dot*ray.ga/2;
	ray.ba := dot*ray.ba/2;
	mirror(ray);
END Shade;
END DiffuseSphMVox;

TYPE DiffuseSphVox* = OBJECT(ColoredVox);
VAR
	 mf, a: SREAL;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	dot: SREAL;
	p: srBase.PT;
BEGIN
	p.x:= 1/2 - ray.lxyz.x; p.y:= 1/2 - ray.lxyz.y; p.z:= 1/2 - ray.lxyz.z;
	srBase.normalizePT(p);
	dot := ABS(p.x*ray.dxyz.x + p.y*ray.dxyz.y+ p.z*ray.dxyz.z);
	ray.r := ray.r + r * ray.ra*dot;
	ray.g := ray.g + g * ray.ga*dot;
	ray.b := ray.b + b * ray.ba*dot;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END DiffuseSphVox;

TYPE AlphaVox* = OBJECT(Voxel);
VAR
	r, g, b, ra, ga, ba: SREAL;
PROCEDURE SetColor* (red, green, blue, alpha  : SREAL);
BEGIN
	r := srBase.clamp(red * alpha);
	g := srBase.clamp(green * alpha);
	b := srBase.clamp(blue * alpha);
END SetColor;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	dr, dg, db: SREAL;
BEGIN
	dr :=  r*ray.ra;
	dg :=  g*ray.ga;
	db :=  b*ray.ba;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - (dg+db)/2;
	ray.ga := ray.ga - (dr+db)/2;
	ray.ba := ray.ba - (dr+dg)/2;
	ray.a := ray.a -(dr+dg+db)/3;
	ray.length := ray.length + ray.scale;
END Shade;
END AlphaVox;

(*TYPE ColoredDetailVox*=OBJECT(ColoredVox);

PROCEDURE Shade (VAR ray: Ray);
VAR
	l, x, y, z: SREAL;
	ecount: SIGNED16;
BEGIN
	ray.r := ray.r + r * ray.a;
	ray.g := ray.g + g * ray.a;
	ray.b := ray.b + b * ray.a;
	ray.a := ray.a - a
END Shade;

END ColoredDetailVox; *)

TYPE TransparaVox*=OBJECT(Voxel);
VAR
	r, g, b, black: SREAL;
PROCEDURE SetColor* (red, green, blue,bl  : SREAL);
BEGIN
	r := red;
	g := green;
	b := blue;
	black:=bl;
	passable := TRUE;
END SetColor;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	depth: SREAL;
	exit:PT;
	dr,dg,db,dblack: SREAL;
BEGIN
	exit:=srBase.Exit(ray);
	depth:=srBase.distsquared(ray.lxyz,exit);
	dr := r*depth;
	dg := g*depth;
	db := b*depth;
	dblack:=black*depth;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - dr-dblack;
	ray.ga := ray.ga - dg-dblack;
	ray.ba := ray.ba - db-dblack;
	srBase.clamp3(ray.ra,ray.ga,ray.ba);
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;
END TransparaVox;

TYPE RainbowVox*=OBJECT(Voxel);
VAR
	r, g, b, black: SREAL;
PROCEDURE SetColor* (red, green, blue,bl  : SREAL);
BEGIN
	r := red;
	g := green;
	b := blue;
	black:=bl;
	passable := TRUE;
END SetColor;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	depth: SREAL;
	exit:PT;
	dr,dg,db,dblack: SREAL;
BEGIN
	exit:=srBase.Exit(ray);
	depth:=srBase.distsquared(ray.lxyz,exit);
	dr := ABS(r*depth*ray.dxyz.x);
	dg := ABS(g*depth*ray.dxyz.y);
	db := ABS(b*depth*ray.dxyz.z);
	dblack:=black*depth;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - dr-dblack;
	ray.ga := ray.ga - dg-dblack;
	ray.ba := ray.ba - db-dblack;
	srBase.clamp3(ray.ra,ray.ga,ray.ba);
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;
END RainbowVox;


TYPE JelloVox*=OBJECT(AlphaVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	x,y,z: SREAL;
	depth: SREAL;
	dr, dg, db: SREAL;
BEGIN
(*	x := ray.lxyz.x-ray.xlx;
	y := ray.lxyz.y-ray.xly;
	z := ray.lxyz.z-ray.xlz;	*)
	depth := Math.sqrt(x*x+y*y+z*z);
	dr :=  r*ray.ra*depth;
	dg :=  g*ray.ga*depth;
	db :=  b*ray.ba*depth;
	ray.ra := ray.ra - dr;
	ray.ga := ray.ga - dg;
	ray.ba := ray.ba - db;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
	ray.length := ray.length + ray.scale;
END Shade;
END JelloVox;

TYPE AirVox*=OBJECT(ColoredVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	x,y,z: SREAL;
	depth: SREAL;
	dr, dg, db: SREAL;

BEGIN
(*	x := ray.lxyz.x-ray.xlx;
	y := ray.lxyz.y-ray.xly;
	z := ray.lxyz.z-ray.xlz;	*)
	depth := Math.sqrt(x*x+y*y+z*z)*srBase.fog;
	dr :=  r*ray.ra*depth;
	dg :=  g*ray.ga*depth;
	db :=  b*ray.ba*depth;
	ray.ra := ray.ra - dr;
	ray.ga := ray.ga - dg;
	ray.ba := ray.ba - db;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
	ray.length := ray.length + ray.scale;
END Shade;
END AirVox;

TYPE InkVox*=OBJECT(ColoredVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	ink: SREAL;
BEGIN
	ink := 0.05*ray.a;
	ray.ra := ray.ra - ink;
	ray.ga := ray.ga - ink;
	ray.ba := ray.ba - ink;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
	ray.length := ray.length + ray.scale;
END Shade;
END InkVox;

TYPE OutlineVox*=OBJECT(ColoredVox);
VAR
	or, og, ob: SREAL;
PROCEDURE SetOutline* (red, green, blue: SREAL);
BEGIN
	or := red ;
	og := green ;
	ob := blue;
END SetOutline;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	ecount: SIGNED16;
BEGIN
	IF (ray.lxyz.x< 0.01) OR (ray.lxyz.x > 0.99) THEN INC(ecount) END;
	IF (ray.lxyz.y <0.01) OR (ray.lxyz.y > 0.99) THEN INC(ecount) END;
	IF (ray.lxyz.z < 0.01) OR (ray.lxyz.z > 0.99) THEN INC(ecount) END;
	IF ecount > 1 THEN
		ray.r := ray.r + or * ray.ra;
		ray.g := ray.g + og * ray.ga;
		ray.b := ray.b + ob * ray.ba;
		ray.ra := 0;
		ray.ga := 0;
		ray.ba := 0;
		ray.a := 0;
	ELSE
		ray.r := ray.r + r * ray.ra;
		ray.g := ray.g + g * ray.ga;
		ray.b := ray.b + b * ray.ba;
		ray.ra := 0;
		ray.ga := 0;
		ray.ba := 0;
		ray.a := 0;
	END
END Shade;
END OutlineVox;

TYPE GoutlineVox*=OBJECT(ColoredVox)
VAR
	tx, ty, tz: SREAL;		(* thickness of outline *)
	or, og, ob: SREAL; 	(* outline color *)
PROCEDURE Shade*(VAR ray: Ray);
VAR
	ecount: SIGNED16;
	l, le, xe, ye, ze: SREAL;
BEGIN
	ecount := 0;
	IF (ray.lxyz.x < 1/100)  THEN
		xe := 100*(1/100-ray.lxyz.x)
	ELSIF (ray.lxyz.x > 99/100) THEN
		xe := 00*(1-ray.lxyz.x)
	END;
	IF (ray.lxyz.y < 1/100)  THEN
		ye := 100*(1/100-ray.lxyz.y)
	ELSIF (ray.lxyz.y > 99/100) THEN
		ye := 100*(1-ray.lxyz.y)
	END;
	IF (ray.lxyz.z < 1/100)  THEN
		ze := 100*(1/100-ray.lxyz.z)
	ELSIF (ray.lxyz.z > 99/100) THEN
		ze := 100*(1-ray.lxyz.z)
	END;
	le := (xe+ye+ze)/3;
	l := (ray.lxyz.x+ray.lxyz.y+ray.lxyz.z)/3;
	ray.r := ray.r + r * ray.ra*l;
	ray.g := ray.g + g * ray.ga*l;
	ray.b := ray.b + b * ray.ba*l;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END GoutlineVox;

TYPE GouraudVox* = OBJECT(ColoredVox);

VAR
	brightness: SIGNED16;

PROCEDURE & init*;
BEGIN
	brightness := 16;
END init;

PROCEDURE tick*;
BEGIN
	IF srBase.rand.Uniform()>1/2 THEN
		brightness := (brightness + 1) MOD 20;
	ELSE
		brightness := (brightness - 1) MOD 20;
	END
END tick;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	l: SREAL;
BEGIN
	l := (ray.lxyz.x+ray.lxyz.y+ray.lxyz.z)/3;
	ray.r := ray.r + r * ray.ra*l;
	ray.g := ray.g + g * ray.ga*l;
	ray.b := ray.b + b * ray.ba*l;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;
END GouraudVox;

TYPE VGouraudVox* = OBJECT(GouraudVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	l: SREAL;
BEGIN
	l := (ray.lxyz.x+ray.lxyz.y)/2;
	ray.r := ray.r + r * ray.ra*l;
	ray.g := ray.g + g * ray.ga*l;
	ray.b := ray.b + b * ray.ba*l;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;
END VGouraudVox;

TYPE HGouraudVox* = OBJECT(GouraudVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	l: SREAL;
BEGIN
	l := (ray.lxyz.x+ray.lxyz.z)/2;
	ray.r := ray.r + r * ray.ra*l;
	ray.g := ray.g + g * ray.ga*l;
	ray.b := ray.b + b * ray.ba*l;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END HGouraudVox;

TYPE NouraudVox* = OBJECT(ColoredVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	l: SREAL;
BEGIN
	l := 2*(ABS(1/2-ray.lxyz.x) + ABS(1/2-ray.lxyz.y) + ABS(1/2-ray.lxyz.z))/3;
	ray.r := ray.r + r * ray.ra*l;
	ray.g := ray.g + g * ray.ga*l;
	ray.b := ray.b + b * ray.ba*l;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END NouraudVox;

TYPE DiffuseVox* = OBJECT(ColoredVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	nx, ny, nz: SIGNED16;
	dot: SREAL;
	inside: BOOLEAN;
BEGIN
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
	IF dot<1/2 THEN dot:=1/2 END;
	ray.r := ray.r + r * ray.ra*dot ;
	ray.g := ray.g + g * ray.ga*dot;
	ray.b := ray.b + b * ray.ba*dot;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;

END DiffuseVox;

TYPE DiffuseNouraudVox* = OBJECT(ColoredVox);

PROCEDURE Shade*(VAR ray: Ray);
VAR
	nx, ny, nz: SIGNED16;
	dot: SREAL;
	inside: BOOLEAN;
	l: SREAL;
BEGIN
	l := 2*(ABS(1/2-ray.lxyz.x) + ABS(1/2-ray.lxyz.y) + ABS(1/2-ray.lxyz.z))/3;
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
	IF inside THEN dot := l ELSE dot := l*(1/3+2*ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z)/2) END;
	ray.r := ray.r + r * ray.ra*dot;
	ray.g := ray.g + g * ray.ga*dot;
	ray.b := ray.b + b * ray.ba*dot;
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;

END DiffuseNouraudVox;

TYPE GridVox* = OBJECT(Voxel);
VAR
	r, g, b, a, gr, gg, gb, ga, Z: SREAL;

PROCEDURE SetColor* (red, green, blue, alpha: SREAL);
BEGIN
	r := red * alpha;
	g := green * alpha;
	b := blue * alpha;
	a := alpha;
END SetColor;

PROCEDURE SetGridColor* (red, green, blue, alpha: SREAL);
BEGIN
	gr := red * alpha;
	gg := green * alpha;
	gb := blue * alpha;
	ga := alpha;
END SetGridColor;

PROCEDURE SetGrid*(z: SREAL);
BEGIN
	Z := z;
END SetGrid;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	lx, ly, x, y: SREAL;
	i, j: SIGNED32;
BEGIN
	CASE ray.face OF
		 1: lx := ray.lxyz.y; ly := ray.lxyz.z;
		|2: lx := ray.lxyz.x; ly := ray.lxyz.z;
		|3: lx := ray.lxyz.x; ly := ray.lxyz.y;
		|4: lx := ray.lxyz.y; ly := ray.lxyz.z;
		|5: lx := ray.lxyz.x; ly := ray.lxyz.z;
		|6: lx := ray.lxyz.x; ly := ray.lxyz.y;
	ELSE
	END;
	x := lx*Z; y := ly*Z;
	i := ENTIER(x); j := ENTIER(y);
	x := x - i; y := y - j;
	IF ((x<0.1) OR (y<0.1)) THEN
		ray.r := ray.r + gr;
		ray.g := ray.g + gg;
		ray.b := ray.b + gb;
		ray.ra := ray.ra - (gg+gb);
		ray.ga := ray.ga - (gr+gb);
		ray.ba := ray.ba - (gr+gg);
	ELSE
		ray.r := ray.r + r;
		ray.g := ray.g + g;
		ray.b := ray.b + b;
		ray.ra := ray.ra - (g+b);
		ray.ga := ray.ga - (r+b);
		ray.ba := ray.ba - (r+g);
	END;
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;
END GridVox;

TYPE GridChirkleVox* = OBJECT(Voxel);
VAR
	r, g, b, a, Z: SREAL;

PROCEDURE SetColor* (red, green, blue, alpha: SREAL);
BEGIN
	r := red * alpha;
	g := green * alpha;
	b := blue * alpha;
	a := alpha;
	register;
END SetColor;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	dx, dy, dz, d2: SREAL;
BEGIN
	dx := (1/2-ray.lxyz.x);
	dy := (1/2-ray.lxyz.y);
	dz := (1/2-ray.lxyz.z);
	d2 := dx*dx+dy+dy+dz+dz;
	IF d2>1 THEN
		ray.r := ray.r + r;
		ray.g := ray.g + g;
		ray.b := ray.b + b;
		ray.ra := ray.ra - (g+b);
		ray.ga := ray.ga - (r+b);
		ray.ba := ray.ba - (r+g);
		ray.a := (ray.ra+ray.ga+ray.ba)/3;
	END
END Shade;

END GridChirkleVox;

TYPE CheckerVox* = OBJECT(Voxel);
VAR
	r, g, b, a, Z: SREAL;
PROCEDURE SetColor* (red, green, blue, alpha: SREAL);
BEGIN
	r := red * alpha;
	g := green * alpha;
	b := blue * alpha;
	a := alpha;
	register;
END SetColor;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	d, x,y,z, dr, dg, db: SREAL;
	ijk: srBase.IPT;
BEGIN
	srE.E(ray.lxyz, ijk);
	x := ray.lxyz.x*2- ijk.i*2;
	y := ray.lxyz.y*2- ijk.j*2;
	z := ray.lxyz.z*2- ijk.k*2;
	d := ABS((1/2-x)*(1/2-x)*(1/2-z)*(Z));
	dr :=  (1- ray.lxyz.x*d)*ray.ra;
	dg :=  (1- ray.lxyz.y*d)*ray.ga;
	db :=  (1 - ray.lxyz.z*d)*ray.ba;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - (dg+db);
	ray.ga := ray.ga - (dr+db);
	ray.ba := ray.ba - (dr+dg);
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;

PROCEDURE tick*;
BEGIN
	Z := 10+(srBase.frame MOD 13);
END tick;

END CheckerVox;

TYPE HexaVox* = OBJECT(Voxel);
VAR
	V: Voxel;
	hhx: SREAL;

PROCEDURE&init*;
BEGIN
	hhx := 6;
END init;

PROCEDURE setVox*(v: Voxel);
BEGIN
	V := v;
END setVox;

PROCEDURE connectmessage*;
BEGIN
	Out.String("HexaVox"); Out.Ln;
END connectmessage;

PROCEDURE talk*(c: CHAR; VAR connection: BOOLEAN);
BEGIN
	CASE c OF
		'+': hhx := hhx + 0.05; Out.String("hhx +."); Out.Ln;
		| 'G': hhx := hhx - 0.05; Out.String("hhx - "); Out.Ln;
	ELSE
		Out.String(".");
	END;
END talk;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	lx,ly: SREAL;
	Q, gray: SREAL;
BEGIN
	CASE ray.face OF
		 1: lx := ray.lxyz.y; ly := ray.lxyz.z;
		|2: lx := ray.lxyz.x; ly := ray.lxyz.z;
		|3: lx := ray.lxyz.x; ly := ray.lxyz.y;
		|4: lx := ray.lxyz.y; ly := ray.lxyz.z;
		|5: lx := ray.lxyz.x; ly := ray.lxyz.z;
		|6: lx := ray.lxyz.x; ly := ray.lxyz.y;
	ELSE
	END;
	Q := srHex.hexize2(50*0.866*lx, 50*0.866*ly);
	IF Q < 1/10 THEN
		gray := (1-Q*10);
		ray.r := ray.r - gray*ray.ra;
		ray.g := ray.g - gray*ray.ga;
		ray.b := ray.b - gray*ray.ba;
		ray.ra := ray.ra-gray;
		ray.ga := ray.ga-gray;
		ray.ba := ray.ba-gray;
		ray.a := (ray.ra+ray.ga+ray.ba)/3;
	END;
	IF V # NIL THEN V.Shade(ray) END;
END Shade;
END HexaVox;

TYPE SPHexaVox*=OBJECT(HexaVox);

PROCEDURE ctop(x,y,z: SREAL; VAR th,ph: SREAL);
BEGIN
	srBase.normalize(x,y,z);
	th := 6.28*srMath.sin(x);
	ph :=  6.28*srMath.cos(y);
END ctop;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	Q, gray: SREAL;
	th,ph: SREAL;
BEGIN
	ctop(ray.lxyz.x,ray.lxyz.y,ray.lxyz.z,th,ph);
	Q := srHex.hexize2(3*0.866*th, 3*0.866*ph);
	IF Q < 1/10 THEN
		gray := (1-Q*10);
		ray.ra := ray.ra - gray;
		ray.ga := ray.ga - gray;
		ray.ba := ray.ba - gray;
		ray.a := (ray.ra+ray.ga+ray.ba)/3;
	END;
	IF V # NIL THEN V.Shade(ray) END;
END Shade;

END SPHexaVox;

TYPE PolkaVox* = OBJECT(Voxel);
VAR
	brightness: SIGNED16;
	r, g, b, rr, gg, bb: SREAL;

PROCEDURE & init*;
BEGIN
	brightness := 16;
END init;

PROCEDURE SetColor* (red, green, blue, r2, g2, b2 : SREAL);
BEGIN
	r := srBase.clamp(red );
	g := srBase.clamp(green );
	b := srBase.clamp(blue );
	rr := srBase.clamp(r2);
	gg := srBase.clamp(g2);
	bb := srBase.clamp(b2);
END SetColor;

PROCEDURE tick*;
BEGIN
	IF srBase.rand.Uniform()>1/2 THEN
		brightness := (brightness + 1) MOD 20;
	ELSE
		brightness := (brightness - 1) MOD 20;
	END
END tick;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	l, x, y, z: SREAL;
	nx, ny, nz: SIGNED16;
		dot: SREAL;
	inside: BOOLEAN;
BEGIN
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
	IF inside THEN dot := 1 ELSE dot := ABS(nx*ray.dxyz.x + ny*ray.dxyz.y+ nz*ray.dxyz.z) END; 	x := 2*ABS(1/2 - ray.lxyz.x);
	y := 2*ABS(1/2 - ray.lxyz.y);
	z := 2*ABS(1/2 - ray.lxyz.z);
	l := (x+y+z)/3;
	dot := dot*brightness;
	ray.r := ray.r + (r * ray.ra*l)*dot + (rr * ray.ra*(1-l))*dot ;
	ray.g := ray.g + g * ray.ga*l *dot+ (gg * ray.ga*(1-l))*dot;
	ray.b := ray.b + b * ray.ba*l*dot + (bb * ray.ba*(1-l)*dot);
	ray.ra := 0;
	ray.ga := 0;
	ray.ba := 0;
	ray.a := 0;
END Shade;
END PolkaVox;

TYPE GeckoVox* = OBJECT(Voxel);
VAR
	r, g, b, a: SREAL;
	ecount: SIGNED16;
PROCEDURE SetColor* (red, green, blue, alpha: SREAL);
BEGIN
	r := red * alpha;
	g := green * alpha;
	b := blue * alpha;
	a := alpha
END SetColor;
PROCEDURE Shade*(VAR ray: Ray);
VAR
	d, dr, dg, db: SREAL;
BEGIN
	d := ABS((1/2-ray.lxyz.x)*(1/2-ray.lxyz.y)*(1/2-ray.lxyz.z)*70);
	dr :=  r*ray.ra*d;
	dg :=  g*ray.ga*d;
	db :=  b*ray.ba*d;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - (dg+db);
	ray.ga := ray.ga - (dr+db);
	ray.ba := ray.ba - (dr+dg);
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;
END GeckoVox;

(*TYPE SerpVox* = OBJECT(Voxel);
VAR
	r1, g1, b1, r2, g2, b2: SREAL;

PROCEDURE SetColor1* (r, g, b: SREAL);
BEGIN
	r1 := r;
	g1 := g;
	b := b
END SetColor1;

PROCEDURE SetColor2* (r, g, b: SREAL);
BEGIN
	r2 := r;
	g2 := g;
	b2 := b
END SetColor2;

PROCEDURE Shade (VAR ray: Ray);
VAR
	i, j, k: SIGNED32;
	sc, d: SIGNED16;
BEGIN
	ray.splitme := TRUE;
	sc := 0;
	d := 3;
	WHILE d > 0 DO
		IF (1 / 3 < ray.lx) & (ray.lx < 2 / 3) THEN INC(sc) END;
		IF (1 / 3 < ray.ly) & (ray.ly < 2 / 3) THEN INC(sc) END;
		IF (1 / 3 < ray.lz) & (ray.lz < 2 / 3) THEN INC(sc) END;
		IF sc < 2 THEN
			sc := 0;
			IF ray.lx >= 2 / 3  THEN
				ray.lx := ray.lx - 2 / 3
			ELSIF ray.lx >= 1 / 3 THEN
				ray.lx := ray.lx - 1 / 3
			END;
			ray.lx := ray.lx * 3;
			IF ray.ly >= 2 / 3  THEN
				ray.ly := ray.ly - 2 / 3
			ELSIF ray.ly >= 1 / 3 THEN
				ray.ly := ray.ly - 1 / 3
			END;
			ray.ly := ray.ly * 3;
			IF ray.lz >= 2 / 3  THEN
				ray.lz := ray.lz - 2 / 3
			ELSIF ray.lz >= 1 / 3 THEN
				ray.lz := ray.lz - 1 / 3
			END;
			ray.lz := ray.lz * 3
		END;
		DEC(d)
	END;
	IF sc > 1 THEN
		ray.r := ray.r + r1 * ray.ra * ray.lx;
		ray.g := ray.g + g1 * ray.ga * ray.ly;
		ray.b := ray.b + b1 * ray.ba * ray.lz;
		ray.ra := 0;
		ray.ga := 0;
		ray.ba := 0;
	ELSE
		ray.r := ray.r + r2 * ray.ra;
		ray.g := ray.g + g2 * ray.ga;
		ray.b := ray.b + b2 * ray.ba;
	END
END Shade;

END SerpVox;
*)

TYPE BiVox* = OBJECT(Voxel);
VAR
	v1, v2: Voxel;

PROCEDURE set*(x,y: Voxel);
BEGIN
	v1 := x;
	v2 := y;
END set;

PROCEDURE probe*(x,y,z: SREAL):Voxel;
VAR
	v: Voxel;
BEGIN
	v := v1.probe(x,y,z);
	v := v2.probe(x,y,z);
	RETURN(SELF);
END probe;

PROCEDURE Shade*(VAR ray: Ray);
BEGIN
 v1.Shade(ray);
 v2.Shade(ray);
END Shade;

END BiVox;

(*
TYPE SphBiVox* = OBJECT(BiVox);
VAR
	cx, cy, cz, R2: SREAL;

PROCEDURE&init;
BEGIN
	cx := 1/2; cy := 1/2; cz :=1/2;
	R2 := 0.3;
END init;

PROCEDURE tick*;
BEGIN
	R2 := 1/3 + ((srBase.frame MOD 10)-4)/450;
END tick;

PROCEDURE Shade (VAR ray: Ray);
VAR
	r2: SREAL;
	x,y,z,ax, ay, az, bx, by, bz : SREAL;
	i: SIGNED16;
BEGIN
	r2 := (cx-ray.lx)*(cx-ray.lx) + (cy-ray.ly)*(cy-ray.ly) + (cz-ray.lz)*(cz-ray.lz);
	IF r2 < R2 THEN (* ray is within sphere *)
		IF v2 # NIL THEN v2.Shade(ray) END;
		IF ray.a > 1/10 THEN
			ax := ray.lx; ay := ray.ly; az := ray.lz;
			bx := ray.lx + ray.dx; by := ray.ly+ ray.dy; bz := ray.lz+ ray.dz;
			x := (ax+bx)/2; y := (ay+by)/2; z := (az + bz)/2;
			FOR i := 0 TO 12 DO
				r2 := (cx-x)*(cx-x) + (cy-y)*(cy-y) + (cz-z)*(cz-z);
				IF r2 > R2 THEN
					bx := x; by := y; bz := z
				ELSE
					ax := x; ay := y; az := z
				END;
				x := (ax+bx)/2; y := (ay+by)/2; z := (az + bz)/2;
			END;
			IF ray.a > 1/10 THEN
				ray.lx := x; ray.ly := y; ray.lz := z;
				IF v1 # NIL THEN v1.Shade(ray) END
			END
		END
	ELSE
		IF v1 # NIL THEN v1.Shade(ray) END
	END;
END Shade;

END SphBiVox;
*)
TYPE FuzzyTVox*=OBJECT(AlphaVox);
VAR
	fuzzdivisor, fuzzsubtract: SREAL;
PROCEDURE & init*;
BEGIN
	passable := TRUE;
	fuzzdivisor := 100;
	fuzzsubtract := 0.005
END init;

PROCEDURE setFuzz*(f: SREAL);
BEGIN
	fuzzdivisor := f;
	fuzzsubtract := 1/(2*fuzzdivisor)
END setFuzz;

PROCEDURE Shade*(VAR ray: Ray);
VAR
	dr, dg, db: SREAL;
BEGIN
	ray.xyz.x := ray.xyz.x + srBase.rand.Uniform()/fuzzdivisor-fuzzsubtract;
	ray.xyz.y := ray.xyz.y + srBase.rand.Uniform()/fuzzdivisor-fuzzsubtract;
	ray.xyz.z:= ray.xyz.z + srBase.rand.Uniform()/fuzzdivisor-fuzzsubtract;
	dr :=  r*ray.ra;
	dg :=  g*ray.ga;
	db :=  b*ray.ba;
	ray.r := ray.r + dr;
	ray.g := ray.g + dg;
	ray.b := ray.b + db;
	ray.ra := ray.ra - (dg+db);
	ray.ga := ray.ga - (dr+db);
	ray.ba := ray.ba - (dr+dg);
	ray.a := (ray.ra+ray.ga+ray.ba)/3;
END Shade;

END FuzzyTVox;

PROCEDURE mirror(VAR ray: Ray);
BEGIN
	CASE ray.face OF
		1: 	 ray.dxyz.x:= -ray.dxyz.x;
		|2:	ray.dxyz.y:= -ray.dxyz.y;
		|3:	ray.dxyz.z:= -ray.dxyz.z;
		|4: 	ray.dxyz.x:= -ray.dxyz.x;
		|5:	ray.dxyz.y:= -ray.dxyz.y;
		|6:	ray.dxyz.z:= -ray.dxyz.z;
	ELSE
	END;
	ray.changed := TRUE;
END mirror;

END srVoxel.