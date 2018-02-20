MODULE srBase;
IMPORT Raster, Math, Random, Out:=KernelLog(* , DebugLog*);

(*	HALFPI* = Math.pi/2; *)

CONST
	TILESIZE*=15;
	LTILESIZE*=30; (*multiple of 3*)
	TILEi*=12;
	TILEj*=9;
	TILES*=TILEi*TILEj;
	W*=TILESIZE*TILEi;
	H*=TILESIZE*TILEj;
	LW*=LTILESIZE*TILEi;
	LH*=LTILESIZE*TILEj;
	LRAYX*=W DIV 2;
	LRAYY*=H DIV 2;
	LLRAYX*=W DIV 2;
	LLRAYY*=H DIV 2;

TYPE Name* = ARRAY 32 OF CHAR;
TYPE SREAL*=REAL;
TYPE PT*= RECORD
	x*,y*,z*: SREAL
END;

TYPE IPT*=RECORD
	i*,j*,k*: INTEGER
END;

TYPE BOX*=RECORD
	p*,q*: PT;
END;

TYPE Aperture* = RECORD
	width*, height*: REAL
END;

TYPE COLOR*=RECORD
	red*,green*,blue*,alpha*: SREAL
END;

TYPE Light=RECORD
	x*,y*,z*: SREAL;
	r*,g*,b*: SREAL;
END;

TYPE V*= OBJECT
PROCEDURE tick*;
END tick;
PROCEDURE register*;
VAR i: INTEGER;
BEGIN
	i := 0;
	WHILE voxelist[i] # NIL DO INC(i) END;
	IF i < 99 THEN voxelist[i] := SELF END;
(*	DebugLog.Int(i,4); DebugLog.Ln; *)
END register;

END V;

TYPE Ray* = RECORD
	theta*, phi*: SREAL;
	xyz*, dxyz*, ddxyz*, lxyz*,origin*: PT;
	r*, g*, b*, ra*, ga*, ba*, a*: SREAL;
	i*, j*, k*, recursion*: INTEGER;
	scale*: SREAL;
	length*: SREAL;
	changed*,traced*: BOOLEAN;
	face*: INTEGER;
	normal*: PT;   (* For lighting/shading; see mcell in srMSpace.Mod *)
END;

TYPE RAYS*= ARRAY W, H OF Ray;
TYPE LRAYS*= ARRAY LW,LH OF Ray;
TYPE IMAGE*= ARRAY W,H OF COLOR;
TYPE LIMAGE*= ARRAY LW+2,LH+2 OF COLOR;

TYPE Voxel*=OBJECT(V)
VAR
	passable*: BOOLEAN;
	rlimit*: INTEGER;
	complex*:BOOLEAN;
PROCEDURE Shade*(VAR ray: Ray);
END Shade;
PROCEDURE SetNormal*(n:PT);
END SetNormal;
PROCEDURE probeShade*(VAR ray: Ray; VAR dx,dy,dz: SREAL); (*camera vector*)
BEGIN
	IF ~passable THEN
		CASE ray.face OF
			0:
			|1: 	 dx:= -dx;
			|2:	  dx:= -dx;
			|3:	dz:= -dz;
			|4: 	dy:= -dy;
			|5:	dx:= -dx;
			|6:	dz := -dz;
			ELSE
		END
	END;
	Out.Int(ray.face, 4);
	Out.Ln;
	ray.a := 0;
END probeShade;
PROCEDURE tick*;

END tick;
PROCEDURE move*(VAR dx, dy, dz: SREAL; VAR blocked: BOOLEAN);
END move;
PROCEDURE probe*(x,y,z: SREAL):Voxel;
BEGIN
	RETURN(SELF);
END probe;
PROCEDURE stroke*( p:PT; level: LONGINT; normal:PT; color: COLOR; mirror: BOOLEAN);
END stroke;
PROCEDURE strokevoxel*(p:PT; level: LONGINT; voxel:Voxel);
END strokevoxel;
PROCEDURE linevoxel*(a,b: PT; level: LONGINT; v: Voxel);
END linevoxel;
PROCEDURE setcamera*(x,y,z: SREAL);
END setcamera;
PROCEDURE deathray*(VAR ray: Ray);
END deathray;
PROCEDURE mutateray*(ray: Ray);
END mutateray;
PROCEDURE connectray*(ray: Ray; VAR connection: BOOLEAN; VAR vox: Voxel);
END connectray;
PROCEDURE start*;
END start;
PROCEDURE camshade*(VAR ray: Ray; camx, camy, camz: SREAL);
END camshade;

PROCEDURE connect*(VAR connection: BOOLEAN; VAR vox: Voxel);
BEGIN
	connection := TRUE;
	vox := SELF;
	connectmessage;
END connect;

PROCEDURE connectmessage*;
BEGIN
	Out.String("Voxel");
END connectmessage;

PROCEDURE talk*(c: CHAR; VAR connection: BOOLEAN);
BEGIN
	Out.String("I do not understand");
	Out.Ln;
	disconnect(connection);
END talk;

PROCEDURE disconnect*(VAR connection: BOOLEAN);
BEGIN
	Out.String("Goodbye");
	Out.Ln;
	connection := FALSE;
END disconnect;

END Voxel;

VAR
	voxelist: ARRAY 100 OF V;
	fog*:REAL;
	rlimit*: INTEGER;
	iterlimit*: LONGINT;
	frame*: LONGINT;
	img*: Raster.Image;
	copy*: Raster.Mode;
	light*: Light;
	rand*: Random.Generator;
	worldalive*: BOOLEAN;
	gravity*, gravUp*,fuzzon*, STOP*: BOOLEAN;
	singleray*: Ray;	(* for when a single ray is most convenient *)
	blankray*: Ray;
	Face*: ARRAY 6 OF PT;
	EMPTY*: Voxel;
	deathflag*:BOOLEAN;
	rays*: RAYS;
	lrays*:LRAYS;
	LOOK*, LLOOK*: Ray;
	image*:IMAGE;
	limage*: LIMAGE;
	world*: Voxel;

PROCEDURE clearvoxelist*;
VAR i: INTEGER;
BEGIN
	FOR i:=0 TO 99 DO voxelist[i]:=NIL END
END clearvoxelist;

PROCEDURE clamp*(x: SREAL): SREAL;
BEGIN
	IF x < 0 THEN x := 0 ELSIF x>1 THEN x := 1 END;
	RETURN(x);
END clamp;

PROCEDURE clamp3*(VAR r,g,b: SREAL);
BEGIN
	IF r < 0 THEN r := 0 ELSIF r>1 THEN r := 0.9999999 END;
	IF g < 0 THEN g := 0 ELSIF g>1 THEN g := 0.9999999 END;
	IF b < 0 THEN b := 0 ELSIF b>1 THEN b := 0.9999999 END;
END clamp3;

PROCEDURE clamPT*(VAR a: PT);
BEGIN
	IF a.x < 0 THEN a.x := 0 ELSIF a.x>=1 THEN a.x := 0.9999999 END;
	IF a.y < 0 THEN a.y := 0 ELSIF a.y>=1 THEN a.y := 0.9999999 END;
	IF a.z < 0 THEN a.z := 0 ELSIF a.z>=1 THEN a.z := 0.9999999 END;
END clamPT;

PROCEDURE addPT*(p,q: PT; VAR r: PT);
BEGIN
	r.x:=p.x+q.x; r.y:=p.y+q.y; r.z:=p.z+q.z;
END addPT;

PROCEDURE clampColor*(VAR a: COLOR);
BEGIN
	IF a.red < 0 THEN a.red := 0 ELSIF a.red>=1 THEN a.red := 0.9999999 END;
	IF a.green < 0 THEN a.green := 0 ELSIF a.green >=1 THEN a.green := 0.9999999 END;
	IF a.blue < 0 THEN a.blue := 0 ELSIF a.blue>=1 THEN a.blue := 0.9999999 END;
END clampColor;

PROCEDURE fuzz3*(VAR x,y,z: SREAL; fuzz: SREAL);
VAR
	q: SREAL;
BEGIN
	q := rand.Uniform()*fuzz - fuzz/2;
	x := x+q; y := y + q; z :=z + q;
	clamp3(x,y,z);
END fuzz3;

PROCEDURE fuzz3noclamp*(VAR x,y,z: SREAL; fuzz: SREAL);
VAR
	q: SREAL;
BEGIN
	q := rand.Uniform()*fuzz - fuzz;
	x := x+q; y := y + q; z :=z + q;
END fuzz3noclamp;

PROCEDURE fuzznorm3*(VAR x,y,z: SREAL; fuzz: SREAL);
VAR
	q: SREAL;
BEGIN
	q := rand.Uniform()*fuzz - fuzz;
	x := x+q; y := y + q; z :=z + q;
	normalize(x,y,z);
END fuzznorm3;

PROCEDURE fzz3*(VAR x,y,z: SREAL; fuzz: SREAL);
VAR
	q: SREAL;
BEGIN
	q := rand.Uniform()*fuzz - fuzz;
	x := x+q; y := y + q; z :=z + q;
END fzz3;

PROCEDURE tick*;
VAR i: INTEGER;
BEGIN
  IF TRUE OR  ~STOP THEN
	i := 0;
	WHILE i < 20 DO
		IF voxelist[i] # NIL THEN voxelist[i].tick END;
		INC(i);
	END;
	INC(frame);
  END;
END tick;

PROCEDURE RESET*;
BEGIN
  frame:=0;
END RESET;

PROCEDURE STOPGO*;
BEGIN
 	STOP := ~STOP;
END STOPGO;

PROCEDURE normalize*(VAR x,y,z: SREAL);
VAR
	d: SREAL;
BEGIN
	d := Math.sqrt(x*x + y*y+z*z);
	IF d = 0 THEN
		x := 1;
		d := 1;
	END;
	x := x/d; y := y/d; z:=z/d
END normalize;

PROCEDURE printPT*(p:PT);
(* Where is KernelLog.Real()? *)
(*
BEGIN
	Out.Real(p.x, 10);
	Out.Real(p.y, 10);
	Out.Real(p.z, 10);
	Out.Ln; *)
END printPT;

PROCEDURE normalizePT*(VAR n:PT);
VAR
	d: SREAL;
BEGIN
	d := Math.sqrt(n.x*n.x + n.y*n.y +n.z*n.z);
	IF d = 0 THEN
		n.x := 1;
		d := 1;
	END;
	n.x := n.x/d; n.y := n.y/d; n.z:=n.z/d
END normalizePT;

PROCEDURE distance*(a,b: PT):SREAL;
VAR
	x,y,z: SREAL;
BEGIN
	x := b.x-a.x;
	y := b.y-a.y;
	z := b.z-a.z;
	RETURN(Math.sqrt(x*x+y*y+z*z));
END distance;

PROCEDURE string*(s: ARRAY OF CHAR);
BEGIN
	Out.String(s); Out.Ln;
END string;

PROCEDURE setPT*(VAR p:PT; x,y,z: SREAL);
BEGIN
	p.x := x;
	p.y := y;
	p.z := z;
END setPT;

PROCEDURE setCOLOR*(VAR p:COLOR; r,g,b: SREAL);
BEGIN
	p.red := r;
	p.green := g;
	p.blue := b;
END setCOLOR;

PROCEDURE randPT*(VAR p:PT);
BEGIN
	p.x := rand.Uniform();
	p.y := rand.Uniform();
	p.z := rand.Uniform();
END randPT;

PROCEDURE randnormPT*(VAR p:PT);
BEGIN
	p.x := (rand.Uniform()*2)-1;
	p.y := (rand.Uniform()*2)-1;
	p.z := (rand.Uniform()*2)-1;
	normalizePT(p);
END randnormPT;

PROCEDURE dist*(a,b:PT):SREAL;
VAR
	dx,dy,dz:SREAL;
BEGIN
	dx := a.x-b.x;
	dy := a.y-b.y;
	dz := a.z-b.z;
	RETURN(Math.sqrt(dx*dx+dy*dy*dz*dz));
END dist;

PROCEDURE distsquared*(a,b:PT):SREAL;
VAR
	dx,dy,dz:SREAL;
BEGIN
	dx := a.x-b.x;
	dy := a.y-b.y;
	dz := a.z-b.z;
	RETURN(dx*dx+dy*dy+dz*dz);
END distsquared;

PROCEDURE midPT*(a,b:PT):PT;
VAR
	m:PT;
BEGIN
	m.x:=(a.x+b.x)/2;
	m.y:=(a.y+b.y)/2;
	m.z:=(a.z+b.z)/2;
	RETURN(m)
END midPT;

PROCEDURE Exit*(ray: Ray):PT;
VAR
	drx, dry, drz: SREAL;
	exit:PT;
BEGIN
	clamPT(ray.lxyz);
	IF ray.dxyz.x>0 THEN
		drx:= (1-ray.lxyz.x)/ ray.dxyz.x
	ELSE
		drx :=  (-ray.lxyz.x) / ray.dxyz.x
	END;
	IF ray.dxyz.y > 0 THEN
		dry := (1 - ray.lxyz.y) / ray.dxyz.y
	ELSE
		dry :=  (-ray.lxyz.y) / ray.dxyz.y
	END;
	IF ray.dxyz.z > 0 THEN
		drz := (1-ray.lxyz.z) / ray.dxyz.z
	ELSE
		drz :=  (-ray.lxyz.z) / ray.dxyz.z
	END;
	IF (drx < dry) THEN
		IF (drx < drz ) THEN
			IF ray.dxyz.x>0 THEN
				exit.x:=1; exit.y:=ray.lxyz.y+drx*ray.dxyz.y; exit.z:=ray.lxyz.z+ drx*ray.dxyz.z;
			ELSE
				exit.x:=0; exit.y:=ray.lxyz.y+drx*ray.dxyz.y; exit.z:=ray.lxyz.z+ drx*ray.dxyz.z;
			END;
		ELSE
			IF ray.dxyz.z>0 THEN
				exit.x:=ray.lxyz.x+drz*ray.dxyz.x; exit.y:=ray.lxyz.y+drz*ray.dxyz.y; exit.z:=1;
			ELSE
				exit.x:=ray.lxyz.x+drz*ray.dxyz.x; exit.y:=ray.lxyz.y+drz*ray.dxyz.y; exit.z:=0;
			END;
		END;
	ELSIF (dry < drz) THEN
		IF ray.dxyz.y>0 THEN
			exit.x:=ray.lxyz.x+dry*ray.dxyz.x; exit.y:=1; exit.z:=ray.lxyz.z+dry*ray.dxyz.z;
		ELSE
			exit.x:=ray.lxyz.x+dry*ray.dxyz.x; exit.y:=0; exit.z:=ray.lxyz.z+dry*ray.dxyz.z;
		END;
	ELSE
		IF ray.dxyz.z>0 THEN
			exit.x:=ray.lxyz.x+drz*ray.dxyz.x; exit.y:=ray.lxyz.y+drz*ray.dxyz.y; exit.z:=1;
		ELSE
			exit.x:=ray.lxyz.x+drz*ray.dxyz.x; exit.y:=ray.lxyz.y+drz*ray.dxyz.y; exit.z:=0;
		END;
	END;
	RETURN(exit);
END Exit;

PROCEDURE filterlinear1*(VAR img:  IMAGE);
VAR
	i,j:LONGINT;
	lr,lg,lb,r,g,b: SREAL;
BEGIN
	FOR i:= 0 TO W-1 DO
		lr:= img[i,0].red; lg:= img[i,0].green; lb:= img[i,0].blue;
		FOR j:= 1 TO H-1 DO
			r:= (img[i,j].red+lr)/2; g:= (img[i,j].green+lg)/2; b:= (img[i,j].blue+lb)/2;
			lr:= img[i,j].red; lg:= img[i,j].green; lb:= img[i,j].blue;
			img[i,j].red:=r; img[i,j].green:=g; img[i,j].blue:=b
		END
	END;
END filterlinear1;

PROCEDURE filterlinear2*(VAR img:  IMAGE);
VAR
	i,j:LONGINT;
	lr,lg,lb,r,g,b: SREAL;
BEGIN
	FOR j:= 0 TO H-1 DO
		lr:=img[0,j].red; lg:= img[0,j].green; lb:= img[0,j].blue;
		FOR i:= 1 TO W-1 DO
			r:= (img[i,j].red+lr)/2; g:= (img[i,j].green+lg)/2; b:= (img[i,j].blue+lb)/2;
			lr:= img[i,j].red; lg:= img[i,j].green; lb:= img[i,j].blue;
			img[i,j].red:=r; img[i,j].green:=g; img[i,j].blue:=b
		END
	END;
END filterlinear2;

PROCEDURE flushworld*;
BEGIN
     world:=EMPTY
END flushworld;

BEGIN
	NEW(rand);
	NEW(EMPTY);
	EMPTY.passable:=TRUE;
	flushworld;
	worldalive := TRUE;
	frame:=0;
	fog := 1/10;
	rlimit := 4;
	iterlimit := 500;
	STOP:=FALSE;
	Raster.InitMode(copy, Raster.srcCopy);
	light.x := 1; light.y := 0; light.z := 0;
	normalize(light.x, light.y, light.z);
	blankray.a := 1;
	blankray.ra := 1;
	blankray.ga := 1;
	blankray.ba := 1;
	blankray.scale := 1;
	blankray.length := 0;
	Face[0].x := 1; Face[0].y := 0; Face[0].z := 0;
	Face[3].x := -1; Face[3].y := 0; Face[3].z := 0;
	Face[1].x := 0; Face[1].y := 1; Face[1].z := 0;
	Face[4].x := 0; Face[4].y := -1; Face[4].z := 0;
	Face[2].x := 0; Face[2].y := 0; Face[2].z := 1;
	Face[5].x := 0; Face[5].y := 0; Face[5].z := -1;
	LOOK:=rays[LRAYX,LRAYY];
	LLOOK:=lrays[LLRAYX,LLRAYY];

END srBase.